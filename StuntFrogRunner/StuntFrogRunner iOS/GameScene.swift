//
//  GameScene.swift
//  Top-down lily pad hopping game
//

import SpriteKit

class GameScene: SKScene {
    
    enum GameOverReason {
        case splash
        case healthDepleted
        case scrolledOffScreen
        case tooSlow
    }
    
    // MARK: - Managers
    var frogController: FrogController!
    var slingshotController: SlingshotController!
    var worldManager: WorldManager!
    var spawnManager: SpawnManager!
    var collisionManager: CollisionManager!
    var effectsManager: EffectsManager!
    var uiManager: UIManager!
    
    private var menuBackdrop: SKShapeNode?
    
    // Frog container node (used for UI layering; frog moves with world scrolling)
    var frogContainer: SKNode!
    
    // Bottom HUD bar to avoid system-edge swipes
    var hudBar: SKShapeNode!
    let hudBarHeight: CGFloat = 110
    
    // Hearts container node for multiple heart icons
    var heartsContainer: SKNode!
    var lifeVestsContainer: SKNode!
    var scrollSaverContainer: SKNode!
    var starIconLabel: SKLabelNode!
    var starProgressBG: SKShapeNode!
    var starProgressFill: SKShapeNode!
    
    // MARK: - Game State
    var gameState: GameState = .menu {
        didSet {
            handleStateChange()
        }
    }
    
    var score: Int = 0 {
        didSet {
            uiManager.updateScore(score)
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "HighScore")
                uiManager.highlightScore(isHighScore: true)
            } else {
                uiManager.highlightScore(isHighScore: false)
            }
        }
    }
    
    var highScore: Int = UserDefaults.standard.integer(forKey: "HighScore")
    
    var health: Int = GameConfig.startingHealth {
        didSet {
            updateBottomHUD()
            
            // Start flashing when only 1 heart remains
            if health == 1 {
                startLowHealthFlash()
            } else {
                // Stop flashing when health recovers or reaches 0
                stopLowHealthFlash()
            }
            
            if health <= 0 {
                gameOver(.healthDepleted)
            }
        }
    }
    var maxHealth: Int = GameConfig.startingHealth {
        didSet {
            updateBottomHUD()
        }
    }
    
    var tadpolesCollected: Int = 0 {
        didSet {
            uiManager.updateTadpoles(tadpolesCollected)
            uiManager.updateStarProgress(current: tadpolesCollected, threshold: GameConfig.tadpolesForAbility)
            updateBottomHUD()
            // FIX: Immediately trigger ability selection when threshold reached
            if tadpolesCollected >= GameConfig.tadpolesForAbility && !pendingAbilitySelection {
                pendingAbilitySelection = true
                // Reset counter immediately to prevent going over
                tadpolesCollected = 0
                uiManager.updateStarProgress(current: tadpolesCollected, threshold: GameConfig.tadpolesForAbility)
                updateBottomHUD()
            }
        }
    }
    
    var pendingAbilitySelection: Bool = false
    
    // MARK: - Game Objects (in world space)
    var enemies: [Enemy] = []
    var tadpoles: [Tadpole] = []
    var lilyPads: [LilyPad] = []
    
    var frameCount: Int = 0
    
    var lastGameOverReason: GameOverReason? = nil
    
    // Tracks any pending delayed game over so we can cancel it when restarting
    var pendingGameOverWorkItem: DispatchWorkItem?
    
    // Prevent stray touches from previous UI taps (e.g., Try Again) from triggering actions in the new run
    private var inputLocked = false
    
    private var splashTriggered = false
    private var scrollSaverCharges: Int = 0
    private var flySwatterCharges: Int = 0
    private var honeyJarCharges: Int = 0
    private var axeCharges: Int = 0
    
    // Grace period to prevent "too slow" detection after rocket landing
    private var rocketLandingGraceFrames: Int = 0
    private var postRocketGlideFrames: Int = 0

    // Smooth glide steering targets and tuning
    private var glideTargetScreenX: CGFloat? = nil
    private let glideLerp: CGFloat = 0.15           // how quickly the frog eases toward target X
    private let worldGlideLerp: CGFloat = 0.12      // how quickly background eases for parallax
    private let glideSlowfallFactor: CGFloat = 0.9  // slightly slower vertical descent during glide
    
    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
        print("🐸 GameScene didMove - Top-Down View!")
        print("🐸 Scene size: \(size)")
        
        backgroundColor = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
        physicsWorld.gravity = .zero
        
        setupManagers()
        setupGame()
        showMainMenu()
        
        // Ensure HUD bar matches scene width if resized
        if let hudBar = hudBar {
            hudBar.path = CGPath(roundedRect: CGRect(x: -size.width/2, y: -hudBarHeight/2, width: size.width, height: hudBarHeight), cornerWidth: 12, cornerHeight: 12, transform: nil)
        }
        
        if let shape = menuBackdrop {
            let inset: CGFloat = 24
            let backdropSize = CGSize(width: size.width - inset * 2, height: size.height - 220)
            let rect = CGRect(x: -backdropSize.width/2, y: -backdropSize.height/2, width: backdropSize.width, height: backdropSize.height)
            shape.path = CGPath(roundedRect: rect, cornerWidth: 24, cornerHeight: 24, transform: nil)
            shape.position = CGPoint(x: size.width/2, y: size.height/2 + 20)
        }
        
        // Pre-warm all haptic types used in the game to avoid first-use hitch
        HapticFeedbackManager.shared.impact(.light)
        HapticFeedbackManager.shared.impact(.medium)
        HapticFeedbackManager.shared.impact(.heavy)
        HapticFeedbackManager.shared.selectionChanged()
        HapticFeedbackManager.shared.notification(.success)
        HapticFeedbackManager.shared.notification(.warning)
        HapticFeedbackManager.shared.notification(.error)
        print("🐸 Setup complete!")
    }
    
    func setupManagers() {
        frogController = FrogController(scene: self)
        slingshotController = SlingshotController(scene: self)
        worldManager = WorldManager(scene: self)
        effectsManager = EffectsManager(scene: self)
        uiManager = UIManager(scene: self)
        collisionManager = CollisionManager(scene: self)
        collisionManager.effectsManager = effectsManager
    }
    
    func setupGame() {
        // Setup world (scrolls down)
        let world = worldManager.setupWorld(sceneSize: size)
        addChild(world)
        
        // Setup spawn manager
        spawnManager = SpawnManager(scene: self, worldNode: worldManager.worldNode)
        // Start a short grace period to prevent early enemy/log spawns
        spawnManager.startGracePeriod(duration: 1.5)
        
        // Setup frog container (used for UI layering; frog moves with world scrolling)
        frogContainer = frogController.setupFrog(sceneSize: size)
        frogContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.4)
        frogContainer.zPosition = 110  // Above everything!
        addChild(frogContainer)
        
        // Setup UI
        uiManager.setupUI(sceneSize: size)
        
        // Create a semi-opaque backdrop for menus to improve readability
        if menuBackdrop == nil {
            let inset: CGFloat = 24
            let backdropSize = CGSize(width: size.width - inset * 2, height: size.height - 220)
            let rect = CGRect(x: -backdropSize.width/2, y: -backdropSize.height/2, width: backdropSize.width, height: backdropSize.height)
            let shape = SKShapeNode(rect: rect, cornerRadius: 24)
            shape.fillColor = UIColor(white: 0.05, alpha: 0.88)
            shape.strokeColor = UIColor.white.withAlphaComponent(0.12)
            shape.lineWidth = 1.0
            shape.zPosition = 190
            shape.position = CGPoint(x: size.width/2, y: size.height/2 + 20)
            shape.isUserInteractionEnabled = false
            shape.alpha = 0.0
            // subtle inner highlights via blur-like rings
            menuBackdrop = shape
            addChild(shape)
        }
        
        // Create bottom HUD bar (non-interactive overlay)
        hudBar = SKShapeNode(rectOf: CGSize(width: size.width, height: hudBarHeight), cornerRadius: 12)
        hudBar.fillColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 0.9)
        hudBar.strokeColor = UIColor.white.withAlphaComponent(0.15)
        hudBar.lineWidth = 1.0
        hudBar.zPosition = 200 // above world and frog, below menus
        hudBar.position = CGPoint(x: size.width/2, y: hudBarHeight/2)
        hudBar.isUserInteractionEnabled = false
        addChild(hudBar)
        
        // Hearts container (row of up to 6 hearts)
        heartsContainer = SKNode()
        heartsContainer.position = CGPoint(x: -size.width/2 + 20, y: 14)
        hudBar.addChild(heartsContainer)
        
        // Life vests container (row of vests)
        lifeVestsContainer = SKNode()
        lifeVestsContainer.position = CGPoint(x: -size.width/2 + 20, y: -14)
        hudBar.addChild(lifeVestsContainer)
        
        // Scroll saver container (row of ⏱ icons)
        scrollSaverContainer = SKNode()
        scrollSaverContainer.position = CGPoint(x: -size.width/2 + 20, y: -40)
        hudBar.addChild(scrollSaverContainer)
        
        updateBottomHUD()
    }
    
    // MARK: - Game State Management
    func handleStateChange() {
        uiManager.hideMenus()
        
        switch gameState {
        case .menu:
            uiManager.setUIVisible(false)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 1.0, duration: 0.2))
            worldManager.worldNode.isPaused = true
        case .playing:
            uiManager.setUIVisible(true)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 0.0, duration: 0.2))
            worldManager.worldNode.isPaused = false
        case .paused, .abilitySelection, .gameOver:
            menuBackdrop?.run(SKAction.fadeAlpha(to: 0.9, duration: 0.2))
            worldManager.worldNode.isPaused = true
        }
    }
    
    func startGame() {
        // Ensure any existing menus are removed immediately and UI is enabled
        uiManager.hideMenus()
        menuBackdrop?.run(SKAction.fadeOut(withDuration: 0.2))
        
        // Cancel any pending delayed game over so Try Again works immediately
        pendingGameOverWorkItem?.cancel()
        pendingGameOverWorkItem = nil
        
        gameState = .playing
        
        // Briefly lock input to avoid stray touch-up from menus causing an immediate jump
        inputLocked = true
        print("🔒 Input locked for 0.2 seconds")
        
        // Primary unlock mechanism with explicit self capture
        let unlockTime = DispatchTime.now() + 0.2
        DispatchQueue.main.asyncAfter(deadline: unlockTime) {
            print("🔓 Primary unlock executing...")
            self.inputLocked = false
            print("🔓 Input unlocked - frog should be controllable now")
        }
        
        // Backup unlock mechanism in case the primary one fails
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔓 Backup unlock checking... inputLocked=\(self.inputLocked)")
            if self.inputLocked {
                print("⚠️ Backup input unlock triggered - input was still locked after 1 second")
                self.inputLocked = false
            }
        }

        // Clear any lingering slingshot visuals/state by forcing a redraw at neutral state
        slingshotController.cancelCurrentAiming()
        
        score = 0
        uiManager.highlightScore(isHighScore: false)
        health = GameConfig.startingHealth
        stopLowHealthFlash()
        maxHealth = GameConfig.startingHealth
        tadpolesCollected = 0
        uiManager.updateStarProgress(current: tadpolesCollected, threshold: GameConfig.tadpolesForAbility)
        pendingAbilitySelection = false
        self.splashTriggered = false
        frogController.superJumpActive = false
        uiManager.hideSuperJumpIndicator()
        frogController.rocketActive = false
        uiManager.hideRocketIndicator()
        frogController.invincible = false
        frameCount = 0 // Reset frame counter for input unlock safety check
        rocketLandingGraceFrames = 0  // Reset rocket landing grace period
        postRocketGlideFrames = 0  // Reset post-rocket glide window
        glideTargetScreenX = nil
        
        // Reset all abilities and temporary states
        frogController.lifeVestCharges = 0
        frogController.rocketFramesRemaining = 0
        scrollSaverCharges = 0
        flySwatterCharges = 0
        honeyJarCharges = 0
        axeCharges = 0
        frogController.suppressWaterCollisionUntilNextJump = false
        frogController.inWater = false
        
        // Reset frog z-position to normal
        frogContainer.zPosition = 50
        
        // Clear objects
        enemies.removeAll()
        tadpoles.removeAll()
        lilyPads.removeAll()
        
        // Reset world
        worldManager.reset()
        
        // Frog's world position starts at center
        let startWorldPos = CGPoint(x: size.width / 2, y: 0)
        
        let startPad = makeLilyPad(position: startWorldPos, radius: 60)
        startPad.node.position = startPad.position
        startPad.node.zPosition = 10
        worldManager.worldNode.addChild(startPad.node)
        lilyPads.append(startPad)
        
        // Align the world so the frog's starting world position appears at a comfortable on-screen position
        let desiredScreenPos = CGPoint(x: size.width / 2, y: size.height * 0.4)
        worldManager.worldNode.position = CGPoint(
            x: desiredScreenPos.x - startWorldPos.x,
            y: desiredScreenPos.y - startWorldPos.y
        )
        // Also set the visual container to that screen position initially
        frogContainer.position = desiredScreenPos
        
        // Stop any lingering actions on frog visuals
        frogController.frog.removeAllActions()
        frogController.frogShadow.removeAllActions()
        frogContainer.removeAllActions()
        
        // Reset frog to start pad
        frogController.resetToStartPad(startPad: startPad, sceneSize: size)
        
        // CRITICAL: Reset frog visibility (both container and emoji)
        frogContainer.alpha = 1.0
        frogController.frog.alpha = 1.0
        frogController.frogShadow.alpha = 0.3
        
        // Spawn initial lily pads ahead
        spawnManager.spawnInitialObjects(sceneSize: size, lilyPads: &lilyPads, enemies: &enemies, tadpoles: &tadpoles, worldOffset: worldManager.worldNode.position.y)
        
        updateBottomHUD()
        
        // gameState already set to .playing above
        
        print("🎮 Game started! Frog world position: \(frogController.position)")
    }
    
    func gameOver(_ reason: GameOverReason) {
        lastGameOverReason = reason
        gameState = .gameOver
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        pendingAbilitySelection = false
        uiManager.showGameOverMenu(sceneSize: size, score: score, highScore: highScore, isNewHighScore: score == highScore && score > 0, reason: reason)
    }
    
    // MARK: - Update Loop
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        
        frameCount += 1
        
        // Decrement rocket landing grace period
        if rocketLandingGraceFrames > 0 {
            rocketLandingGraceFrames -= 1
        }
        if postRocketGlideFrames > 0 {
            postRocketGlideFrames -= 1
        }
        
        // Safety: Force unlock input if it's been locked for more than 60 frames (~1 second at 60fps)
        if inputLocked && frameCount > 60 {
            print("⚠️ Force unlocking input after \(frameCount) frames")
            inputLocked = false
        }
        
        // Dynamic scroll speed: smoothly increase +0.1 per 2000 points, capped at 1.4
        var dynamicScroll: CGFloat
        if frogController.rocketActive {
            // Use fast rocket scroll speed during rocket flight
            dynamicScroll = GameConfig.rocketScrollSpeed
            // Update frog's world position to keep up with the fast scrolling world
            frogController.position.y += dynamicScroll
            
            // Add score based on rocket flight distance (generous scoring for the exciting rocket trip!)
            let rocketScore = Int(dynamicScroll * 3) // 3x multiplier for rocket flight
            score += rocketScore
            
            // Show floating score indicators occasionally during rocket flight
            if frameCount % 20 == 0 { // Every 20 frames (roughly 3 times per second)
                let scoreLabel = SKLabelNode(text: "+\(rocketScore)")
                scoreLabel.fontSize = 18
                scoreLabel.fontColor = .orange
                scoreLabel.fontName = "Arial-BoldMT"
                scoreLabel.position = CGPoint(
                    x: frogContainer.position.x + CGFloat.random(in: -40...40),
                    y: frogContainer.position.y + CGFloat.random(in: 30...60)
                )
                scoreLabel.zPosition = 90
                addChild(scoreLabel)
                
                let scoreAction = SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: 0, y: 50, duration: 1.0),
                        SKAction.fadeOut(withDuration: 1.0),
                        SKAction.scale(to: 0.5, duration: 1.0)
                    ]),
                    SKAction.removeFromParent()
                ])
                scoreLabel.run(scoreAction)
            }
        } else {
            dynamicScroll = min(1.5, GameConfig.scrollSpeed + (0.1 * CGFloat(score) / 2000.0))
        }
        if postRocketGlideFrames > 0 {
            dynamicScroll *= glideSlowfallFactor
        }
        worldManager.worldNode.position.y -= dynamicScroll

        // Smooth horizontal easing during rocket or post-rocket glide
        if frogController.rocketActive || postRocketGlideFrames > 0 {
            // 1) Ease frog’s screen X toward the most recent tap target
            if let targetX = glideTargetScreenX {
                let currentX = frogContainer.position.x
                frogContainer.position.x = currentX + (targetX - currentX) * glideLerp

                // Keep frog’s world-space X in sync
                let newWorld = convert(CGPoint(x: frogContainer.position.x, y: frogContainer.position.y),
                                       to: worldManager.worldNode)
                frogController.position.x = newWorld.x
            }

            // 2) Subtle parallax (already present) still applies here
            let offsetFromCenter = frogContainer.position.x - (size.width / 2)
            let desiredWorldX = -offsetFromCenter * 0.4
            worldManager.worldNode.position.x += (desiredWorldX - worldManager.worldNode.position.x) * worldGlideLerp
        }
           
        
        
        // Pan the world horizontally to keep the frog centered on screen (unless rocket is active or post-rocket glide is active)
        if !frogController.rocketActive && postRocketGlideFrames == 0 {
            worldManager.worldNode.position.x = (size.width / 2) - frogController.position.x
        }
        // During rocket flight, the frog stays centered and the world doesn't pan horizontally
        
        // Compute frog's on-screen Y by converting its world position through the world node transform
        let frogWorldPoint = frogController.position
        let frogScreenPoint = convert(frogWorldPoint, from: worldManager.worldNode)
        let frogScreenY = frogScreenPoint.y
        let failThreshold: CGFloat = -40 // allow a bit of slack below the bottom edge
        
        // Keep the frog's visual container in sync with its current screen position
        // EXCEPT during rocket flight, when it stays centered
        if !frogController.rocketActive {
            frogContainer.position = frogScreenPoint
        }
        // During rocket flight, the frogContainer position is controlled by the rocket animation
        
        if frogScreenY < failThreshold && gameState == .playing && !frogController.rocketActive && postRocketGlideFrames == 0 && rocketLandingGraceFrames <= 0 {
            if scrollSaverCharges > 0 {
                // Consume a scroll saver to rescue the frog
                scrollSaverCharges -= 1
                updateBottomHUD()
                // Compute a safe world Y slightly below the spawn top
                let targetWorldY = -worldManager.worldNode.position.y + size.height * 0.75
                let safeX = max(80, min(size.width - 80, frogController.position.x))
                let newPadPos = CGPoint(x: safeX, y: targetWorldY)
                // Create a new lily pad at the target position
                let rescuePad = makeLilyPad(position: newPadPos, radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius))
                rescuePad.node.position = rescuePad.position
                rescuePad.node.zPosition = 10
                worldManager.worldNode.addChild(rescuePad.node)
                lilyPads.append(rescuePad)
                // Snap frog to the new pad and land
                frogController.position = newPadPos
                frogController.landOnPad(rescuePad)
                // Visual and haptic feedback
                effectsManager?.createLandingEffect(at: convert(newPadPos, from: worldManager.worldNode))
                let label = SKLabelNode(text: "Scroll Saver -1")
                label.fontName = "Arial-BoldMT"
                label.fontSize = 20
                label.fontColor = .systemYellow
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = frogContainer.position
                label.zPosition = 999
                addChild(label)
                let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
                rise.timingMode = .easeOut
                let fade = SKAction.fadeOut(withDuration: 0.8)
                let group = SKAction.group([rise, fade])
                let remove = SKAction.removeFromParent()
                label.run(SKAction.sequence([group, remove]))
                HapticFeedbackManager.shared.notification(.success)
            } else {
                HapticFeedbackManager.shared.notification(.error)
                gameOver(.tooSlow)
            }
            return
        }
        
        // Update frog jump
        frogController.updateJump()
        
        // Frog is not fixed to screen center in this mode; no re-centering of the world on jump.
        
        // Update world scrolling (only when jumping)
        let scrollScore = worldManager.updateScrolling(isJumping: frogController.isJumping)
        score += scrollScore
        
        // Check if frog completed jump
        if !frogController.isJumping && !frogController.isGrounded {
            checkLanding()
        }
        
        // While grounded: if standing on a pulsing (shrinking) pad that is ≤ 40% size, drown
        if frogController.isGrounded, let pad = frogController.currentLilyPad, pad.type == .pulsing, !pad.isSafeToLand {
            // Trigger drown behavior consistent with splash flow
            if frogController.suppressWaterCollisionUntilNextJump {
                // If suppression is active (vest rescue), do nothing
            } else {
                // Immediate splash/drown from unsafe pad — centralized
                triggerSplashOnce(gameOverDelay: 1.5)
            }
            // Ensure we don’t process further this frame after splash scheduling
            return
        }
        
        // Update game objects
        collisionManager.updateEnemies(
            enemies: &enemies,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            invincible: frogController.invincible,
            rocketActive: frogController.rocketActive,
            worldOffset: worldManager.worldNode.position.y,
            onHit: { [weak self] enemy -> HitOutcome in
                guard let self = self else { return .destroyed(cause: nil) }
                
                var consumedProtection = false
                var destroyCause: AbilityType? = nil
                
                if enemy.type == EnemyType.bee && self.honeyJarCharges > 0 {
                    // Honey jar specifically protects against bees - bee disappears, no damage
                    self.honeyJarCharges -= 1
                    consumedProtection = true
                    destroyCause = .honeyJar
                    self.updateBottomHUD()
                    
                    // Show "Yum Yum!" message for bee with honey jar
                    let label = SKLabelNode(text: "Yum Yum! 🍯")
                    label.fontName = "Arial-BoldMT"
                    label.fontSize = 24
                    label.fontColor = .systemYellow
                    label.verticalAlignmentMode = .center
                    label.horizontalAlignmentMode = .center
                    label.position = self.frogContainer.position
                    label.zPosition = 999
                    self.addChild(label)
                    let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
                    rise.timingMode = .easeOut
                    let fade = SKAction.fadeOut(withDuration: 0.8)
                    let group = SKAction.group([rise, fade])
                    let remove = SKAction.removeFromParent()
                    label.run(SKAction.sequence([group, remove]))
                } else if enemy.type == EnemyType.log && self.axeCharges > 0 {
                    // Axe specifically chops down logs - log disappears, no damage
                    self.axeCharges -= 1
                    consumedProtection = true
                    destroyCause = .axe
                    self.updateBottomHUD()

                    // Show "Chop!" message for axe
                    let label = SKLabelNode(text: "Chop! 🪓")
                    label.fontName = "Arial-BoldMT"
                    label.fontSize = 24
                    label.fontColor = .systemGreen
                    label.verticalAlignmentMode = .center
                    label.horizontalAlignmentMode = .center
                    label.position = self.frogContainer.position
                    label.zPosition = 999
                    self.addChild(label)
                    let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
                    rise.timingMode = .easeOut
                    let fade = SKAction.fadeOut(withDuration: 0.8)
                    let group = SKAction.group([rise, fade])
                    let remove = SKAction.removeFromParent()
                    label.run(SKAction.sequence([group, remove]))
                } else if self.flySwatterCharges > 0 {
                    // Fly swatter protects against any enemy - enemy disappears, no damage
                    self.flySwatterCharges -= 1
                    consumedProtection = true
                    destroyCause = nil
                    self.updateBottomHUD()
                    
                    // Show "Swat!" message for fly swatter
                    let label = SKLabelNode(text: "Swat! 🪰")
                    label.fontName = "Arial-BoldMT"
                    label.fontSize = 24
                    label.fontColor = .systemOrange
                    label.verticalAlignmentMode = .center
                    label.horizontalAlignmentMode = .center
                    label.position = self.frogContainer.position
                    label.zPosition = 999
                    self.addChild(label)
                    let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
                    rise.timingMode = .easeOut
                    let fade = SKAction.fadeOut(withDuration: 0.8)
                    let group = SKAction.group([rise, fade])
                    let remove = SKAction.removeFromParent()
                    label.run(SKAction.sequence([group, remove]))
                }

                if !consumedProtection {
                    // No protection used - take damage and enemy disappears normally
                    self.health -= 1
                }
                
                if consumedProtection {
                    // Protection was used - no damage, but enemy may or may not disappear based on protection type
                    // (Currently both protections make the enemy disappear, but this structure allows flexibility)
                }
                
                self.frogController.activateInvincibility()
                if consumedProtection {
                    return .destroyed(cause: destroyCause)
                } else {
                    return .hitOnly
                }
            },
            onLogBounce: { [weak self] (enemy: Enemy) in
                guard let self = self else { return }
                // Collision normal from log to frog
                let dx = self.frogController.position.x - enemy.position.x
                let dy = self.frogController.position.y - enemy.position.y
                let len = max(0.001, sqrt(dx*dx + dy*dy))
                let nx = dx / len
                let ny = dy / len

                // Reflect current velocity across the normal and dampen
                let v = self.frogController.velocity
                let dot = v.dx * nx + v.dy * ny
                var reflected = CGVector(dx: v.dx - 2 * dot * nx,
                                         dy: v.dy - 2 * dot * ny)
                reflected.dx *= 0.7
                reflected.dy *= 0.7

                // Add a tiny positional separation to avoid immediate re-collision
                let separation: CGFloat = 8
                let sepPos = CGPoint(x: self.frogController.position.x + nx * separation,
                                     y: self.frogController.position.y + ny * separation)
                self.frogController.position = sepPos

                // Compute a short rebound target ahead along the reflected direction
                let reflLen = max(0.001, sqrt(reflected.dx * reflected.dx + reflected.dy * reflected.dy))
                let rnx = reflected.dx / reflLen
                let rny = reflected.dy / reflLen
                let reboundDistance: CGFloat = 120
                let reboundTarget = CGPoint(x: sepPos.x + rnx * reboundDistance,
                                            y: sepPos.y + rny * reboundDistance)

                // Start a short rebound jump
                self.frogController.startJump(to: reboundTarget)

                // End superjump immediately and hide indicator
                self.frogController.superJumpActive = false
                self.uiManager.hideSuperJumpIndicator()
                // End rocket immediately and hide indicator
                self.frogController.rocketActive = false
                self.uiManager.hideRocketIndicator()

                // Visual and haptic feedback
                self.effectsManager?.createBonkLabel(at: self.frogContainer.position)
                HapticFeedbackManager.shared.impact(.heavy)
            }
        )
        
        collisionManager.updateTadpoles(
            tadpoles: &tadpoles,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            worldOffset: worldManager.worldNode.position.y,
            rocketActive: frogController.rocketActive,
            onCollect: { [weak self] in
                self?.tadpolesCollected += 1
            }
        )
        
        collisionManager.updateLilyPads(
            lilyPads: &lilyPads,
            worldOffset: worldManager.worldNode.position.y,
            screenHeight: size.height,
            frogPosition: frogController.position  // ✅ Add frog position
        )
        
        frogController.updateInvincibility()
        frogController.updateSuperJump(indicator: uiManager.superJumpIndicator)
        if !frogController.superJumpActive {
            uiManager.hideSuperJumpIndicator()
        }
        
        frogController.updateRocket(indicator: uiManager.rocketIndicator)
        
        // Check if rocket just ended: decide landing outcome
        if !frogController.rocketActive && frogContainer.zPosition > 50 {
            frogContainer.zPosition = 50
            // Determine if frog is above a lily pad; if yes, land, else drown
            var padUnderFrog: LilyPad? = nil
            let frogWorldX = frogController.position.x
            let frogWorldY = frogController.position.y
            for pad in lilyPads {
                let dx = frogWorldX - pad.position.x
                let dy = frogWorldY - pad.position.y
                let dist = sqrt(dx*dx + dy*dy)
                if dist < pad.radius * 1.15 {
                    padUnderFrog = pad
                    break
                }
            }
            if let pad = padUnderFrog {
                // If pad is pulsing and unsafe (≤ 40%), treat as water (drown)
                if pad.type == .pulsing && !pad.isSafeToLand {
                    triggerSplashOnce(gameOverDelay: 0.6)
                    uiManager.hideRocketIndicator()
                } else {
                    // Land safely on the existing pad under the frog
                    frogController.landOnPad(pad)
                    // Sync visual container to the frog's screen position
                    let screenPos = convert(pad.position, from: worldManager.worldNode)
                    frogContainer.position = screenPos
                    effectsManager?.createLandingEffect(at: screenPos)
                    HapticFeedbackManager.shared.impact(.medium)
                    // Small grace against too-slow after landing
                    rocketLandingGraceFrames = 120
                    uiManager.hideRocketIndicator()
                }
            } else {
                // No pad under frog: enter a brief glide window to allow steering to a pad
                postRocketGlideFrames = 180 // ~3 seconds at 60fps
                uiManager.hideRocketIndicator()
                glideTargetScreenX = frogContainer.position.x

                // Small visual cue
                let label = SKLabelNode(text: "Glide! ⏳")
                label.fontName = "Arial-BoldMT"
                label.fontSize = 22
                label.fontColor = .systemYellow
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.position = frogContainer.position
                label.zPosition = 999
                addChild(label)
                let rise = SKAction.moveBy(x: 0, y: 30, duration: 0.8)
                rise.timingMode = .easeOut
                let fade = SKAction.fadeOut(withDuration: 0.8)
                label.run(SKAction.sequence([.group([rise, fade]), .removeFromParent()]))

                // Haptic feedback for entering glide
                HapticFeedbackManager.shared.selectionChanged()

                // Do not splash now; allow update() to attempt landing during the glide window
                frogContainer.removeAction(forKey: "rocketStrafe")
                return
            }
            return
        }

        // During post-rocket glide, allow a short window to find a pad and land safely
        if postRocketGlideFrames > 0 {
            // Check again if there's a pad under the frog now
            var padUnderFrog: LilyPad? = nil
            let frogWorldX = frogController.position.x
            let frogWorldY = frogController.position.y
            for pad in lilyPads {
                let dx = frogWorldX - pad.position.x
                let dy = frogWorldY - pad.position.y
                let dist = sqrt(dx*dx + dy*dy)
                if dist < pad.radius * 1.15 {
                    padUnderFrog = pad
                    break
                }
            }

            if let pad = padUnderFrog {
                // If pad is unsafe (shrunk pulsing), keep gliding until time expires or a safe pad appears
                if pad.type != .pulsing || pad.isSafeToLand {
                    frogController.landOnPad(pad)
                    let screenPos = convert(pad.position, from: worldManager.worldNode)
                    frogContainer.position = screenPos
                    effectsManager?.createLandingEffect(at: screenPos)
                    HapticFeedbackManager.shared.impact(.medium)
                    // Provide a brief grace period after landing
                    rocketLandingGraceFrames = 120
                    // End the glide window
                    postRocketGlideFrames = 0
                    glideTargetScreenX = nil
                }
            } else if postRocketGlideFrames == 1 {
                // Glide time is expiring without finding a pad — splash now
                triggerSplashOnce(gameOverDelay: 0.6)
                glideTargetScreenX = nil
            }
        }
        
        // Spawn new objects at top of screen
        spawnManager.spawnObjects(
            sceneSize: size,
            lilyPads: &lilyPads,
            enemies: &enemies,
            tadpoles: &tadpoles,
            worldOffset: worldManager.worldNode.position.y,
            frogPosition: frogController.position,
            superJumpActive: frogController.superJumpActive
        )
        
        // Draw slingshot aiming (visible when grounded or floating after vest save). The frog moves with the scrolling world.
        print("DEBUG: Attempt aim - grounded=\(frogController.isGrounded), inWater=\(frogController.inWater), pendingAbilitySelection=\(pendingAbilitySelection), gameState=\(gameState), inputLocked=\(inputLocked)")
        if gameState == .playing && (frogController.isGrounded || frogController.inWater) && !pendingAbilitySelection {
            let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
            slingshotController.drawSlingshot(
                frogScreenPosition: frogScreenPoint,
                frogWorldPosition: frogController.position,
                superJumpActive: frogController.superJumpActive,
                lilyPads: lilyPads,
                worldNode: worldManager.worldNode,
                scene: self,
                worldOffset: worldManager.worldNode.position.y
            )
        }
    }
    
    private func startLowHealthFlash() {
        // Avoid stacking multiple flash actions
        frogController.frog.removeAction(forKey: "lowHealthFlash")
        frogController.frogShadow.removeAction(forKey: "lowHealthFlash")
        frogContainer.removeAction(forKey: "lowHealthFlash")
        
        // Flash the frog emoji/sprite red
        let flashRed = SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.4)
        let flashNormal = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.4)
        let pulseSequence = SKAction.sequence([flashRed, flashNormal])
        let repeatFlash = SKAction.repeatForever(pulseSequence)
        
        frogController.frog.run(repeatFlash, withKey: "lowHealthFlash")
        
        // Also pulse the frog's shadow alpha for added urgency
        let shadowDim = SKAction.fadeAlpha(to: 0.15, duration: 0.4)
        let shadowBright = SKAction.fadeAlpha(to: 0.3, duration: 0.4)
        let shadowPulse = SKAction.sequence([shadowDim, shadowBright])
        let repeatShadow = SKAction.repeatForever(shadowPulse)
        
        frogController.frogShadow.run(repeatShadow, withKey: "lowHealthFlash")
        
        // Optional: Add a subtle scale pulse to the entire frog container
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.4)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.4)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let scalePulse = SKAction.sequence([scaleUp, scaleDown])
        let repeatScale = SKAction.repeatForever(scalePulse)
        
        frogContainer.run(repeatScale, withKey: "lowHealthFlash")
    }

    private func stopLowHealthFlash() {
        // Remove all flashing actions
        frogController.frog.removeAction(forKey: "lowHealthFlash")
        frogController.frogShadow.removeAction(forKey: "lowHealthFlash")
        frogContainer.removeAction(forKey: "lowHealthFlash")
        
        // Reset to default appearance
        frogController.frogSprite.colorBlendFactor = 0.0
        frogController.frogShadow.alpha = 0.3
        frogContainer.setScale(1.0)
    }

    
    
    func checkLanding() {
        // Check if frog landed on a lily pad
        var landedOnPad = false
        
        for pad in lilyPads {
            let dx = frogController.position.x - pad.position.x
            let dy = frogController.position.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < pad.radius * 1.15 {
                // Before accepting landing, check pulsing/shrinking safety
                if pad.type == .pulsing && !pad.isSafeToLand {
                    // Unsafe landing: centralized splash
                    triggerSplashOnce(gameOverDelay: 1.5)
                    // Do not set landedOnPad; exit early
                    return
                }
                
                // Safe landing!
                frogController.landOnPad(pad)
                
                // Safety: ensure controllable grounded state after landing
                frogController.isJumping = false
                frogController.isGrounded = true
                frogController.inWater = false
                frogController.suppressWaterCollisionUntilNextJump = false
                print("DEBUG: After land - isGrounded=\(frogController.isGrounded), isJumping=\(frogController.isJumping), inWater=\(frogController.inWater), suppress=\(frogController.suppressWaterCollisionUntilNextJump)")
                
                effectsManager?.createLandingEffect(at: frogContainer.position)
                
                // For frog landing impact
                HapticFeedbackManager.shared.impact(.medium)
                
                // Bounce pad
                let bounceAction = SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
                ])
                pad.node.run(bounceAction)
                
                landedOnPad = true

                self.splashTriggered = false
                
                // FIX: Show ability selection immediately if pending
                if pendingAbilitySelection && gameState == .playing {
                    pendingAbilitySelection = false
                    gameState = .abilitySelection
                    uiManager.showAbilitySelection(sceneSize: size)
                }
                
                break
            }
        }
        
        if !landedOnPad {
            // Prevent triggering splash multiple times for a single fall
            if splashTriggered { return }
            splashTriggered = true
            
            // If life vest already saved the frog and we are suppressing water collision,
            // do not trigger another splash/game over. Allow the player to aim and jump.
            if frogController.suppressWaterCollisionUntilNextJump {
                print("🌊 Suppressing water collision until next jump")
                // Keep allowing slingshot from water; no ability selection while floating
                pendingAbilitySelection = false
                return
            }

            // SPLASH! Fell in water (centralized flow but we need vest logic here)
            frogController.splash()
            HapticFeedbackManager.shared.notification(.error)
            effectsManager?.createSplashEffect(at: frogContainer.position)
            print("💧 Splash occurred: inWater=\(frogController.inWater), vestCharges=\(frogController.lifeVestCharges)")

            // If the frog has a life vest, consume one charge and allow a rescue jump; otherwise proceed to game over
            if frogController.inWater {
                if frogController.lifeVestCharges > 0 {
                    // Cancel any previously scheduled drown/game over immediately
                    pendingGameOverWorkItem?.cancel()
                    print("🦺 Using life vest to rescue. Cancelling pending game over.")
                    
                    frogController.lifeVestCharges -= 1
                    updateBottomHUD()
                    pendingGameOverWorkItem?.cancel()
                    // Allow slingshot from water; no pending ability selection
                    pendingAbilitySelection = false
                    // Ensure we suppress immediate water collision until the next jump
                    frogController.suppressWaterCollisionUntilNextJump = true
                    self.splashTriggered = false
                    print("🦺 Life vest consumed. Remaining=\(frogController.lifeVestCharges). Suppression active.")
                    // Visual cue for consuming a life vest
                    let label = SKLabelNode(text: "Life Vest -1")
                    label.fontName = "Arial-BoldMT"
                    label.fontSize = 20
                    label.fontColor = .systemYellow
                    label.verticalAlignmentMode = .center
                    label.horizontalAlignmentMode = .center
                    // Add at frog's screen position (frogContainer is already in screen space)
                    label.position = frogContainer.position
                    label.zPosition = 999
                    addChild(label)

                    let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
                    rise.timingMode = .easeOut
                    let fade = SKAction.fadeOut(withDuration: 0.8)
                    let group = SKAction.group([rise, fade])
                    let remove = SKAction.removeFromParent()
                    label.run(SKAction.sequence([group, remove]))
                } else {
                    // No remaining vest charges: proceed to game over after delay (cancellable)
                    pendingAbilitySelection = false
                    pendingGameOverWorkItem?.cancel()
                    print("☠️ Scheduling game over due to splash")
                    let work = DispatchWorkItem { [weak self] in
                        self?.gameOver(.splash)
                    }
                    pendingGameOverWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
                }
            } else {
                // Not in water (should be rare here), ensure normal game over
                pendingAbilitySelection = false
                pendingGameOverWorkItem?.cancel()
                print("☠️ Scheduling game over due to splash")
                let work = DispatchWorkItem { [weak self] in
                    self?.gameOver(.splash)
                }
                pendingGameOverWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
            }
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Rocket lateral control: tap left/right half to nudge frog during rocket or post-rocket glide
        if gameState == .playing && (frogController.rocketActive || postRocketGlideFrames > 0) {
            // Ignore taps on HUD bar area for rocket control
            if location.y > hudBarHeight {
                let centerX = size.width / 2
                let isRight = location.x >= centerX

                let screenNudge: CGFloat = 18       // slightly smaller for smoother feel
                // Determine new desired screen X and clamp it within margins
                let margin: CGFloat = 20
                let proposedX = frogContainer.position.x + (isRight ? screenNudge : -screenNudge)
                let clamped = max(margin, min(size.width - margin, proposedX))
                // Set glide target; update() will ease toward it
                glideTargetScreenX = clamped

                // Update frog’s intended world X based on target screen position as a hint.
                // (The authoritative sync happens each frame in update())
                let hintWorld = convert(CGPoint(x: clamped, y: frogContainer.position.y), to: worldManager.worldNode)
                frogController.position.x = hintWorld.x

                // Clear any prior strafing actions to avoid competing motion
                frogContainer.removeAction(forKey: "rocketStrafe")
                worldManager.worldNode.removeAction(forKey: "worldStrafe")

                // Haptic feedback
                HapticFeedbackManager.shared.selectionChanged()
            }
            return
        }
        // If tapped inside bottom HUD bar area, release/cancel an in-progress jump and ignore input
        if location.y <= hudBarHeight {
            if gameState == .playing {
                // If the player is mid-jump, cancel the jump immediately
                if frogController.isJumping {
                    // End current jump so the frog will transition to landing/fall logic
                    frogController.isJumping = false
                    // Clear any slingshot visuals just in case
                    slingshotController.cancelCurrentAiming()
                }
            }
            return
        }
        
        let nodes = self.nodes(at: location)
        
        // Handle menu buttons (walk up parent chain to find a named button)
        for node in nodes {
            var current: SKNode? = node
            while let n = current {
                if let name = n.name {
                    if name.hasPrefix("ability_") {
                        let abilityStr = name.replacingOccurrences(of: "ability_", with: "")
                        selectAbility(abilityStr)
                        // For button taps or ability selections
                        HapticFeedbackManager.shared.selectionChanged()
                        return
                    }
                    switch name {
                    case "startButton":
                        self.inputLocked = false
                        uiManager.hideMenus()
                        startGame()
                        return
                    case "tryAgainButton":
                        self.inputLocked = false
                        uiManager.hideMenus()
                        startGame()
                        return
                    case "quitButton", "backToMenuButton":
                        uiManager.hideMenus()
                        showMainMenu()
                        return
                    case "continueButton":
                        uiManager.hideMenus()
                        gameState = .playing
                        return
                    case "pauseButton" where gameState == .playing:
                        gameState = .paused
                        uiManager.hideSuperJumpIndicator()
                        uiManager.hideRocketIndicator()
                        uiManager.showPauseMenu(sceneSize: size)
                        return
                    default:
                        break
                    }
                }
                current = n.parent
            }
        }
        
        if inputLocked { return }
        
        // Handle slingshot (only when actively playing and no upgrade selection pending, and not during rocket flight)
        if gameState == .playing && (frogController.isGrounded || frogController.inWater) && !pendingAbilitySelection && !frogController.rocketActive {
            let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
            slingshotController.handleTouchBegan(at: location, frogScreenPosition: frogScreenPoint)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // If moving inside bottom HUD bar area, release the slingshot immediately (if aiming), or cancel an in-progress jump
        if location.y <= hudBarHeight {
            if gameState == .playing && !pendingAbilitySelection && !frogController.rocketActive {
                // If the player is currently aiming (grounded or in water), simulate a release just above the HUD
                if frogController.isGrounded || frogController.inWater {
                    let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
                    // Clamp end point to just above the HUD to produce a reasonable shot
                    let clampedEnd = CGPoint(x: location.x, y: hudBarHeight + 1)
                    if let targetWorldPos = slingshotController.handleTouchEnded(
                        at: clampedEnd,
                        frogScreenPosition: frogScreenPoint,
                        frogWorldPosition: frogController.position,
                        worldOffset: worldManager.worldNode.position.y,
                        superJumpActive: frogController.superJumpActive
                    ) {
                        frogController.startJump(to: targetWorldPos)
                    }
                    // Clear any slingshot visuals
                    slingshotController.cancelCurrentAiming()
                } else if frogController.isJumping {
                    // If already mid-jump, cancel the jump to avoid a frozen state
                    frogController.isJumping = false
                    slingshotController.cancelCurrentAiming()
                }
            }
            return
        }
        
        if inputLocked { return }
        
        // Only handle slingshot movement during valid gameplay states
        if gameState == .playing && !pendingAbilitySelection && !frogController.rocketActive {
            slingshotController.handleTouchMoved(to: location)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // If ending inside bottom HUD bar area, release the slingshot immediately (if aiming), or cancel an in-progress jump
        if location.y <= hudBarHeight {
            if gameState == .playing && !pendingAbilitySelection && !frogController.rocketActive {
                if frogController.isGrounded || frogController.inWater {
                    let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
                    let clampedEnd = CGPoint(x: location.x, y: hudBarHeight + 1)
                    if let targetWorldPos = slingshotController.handleTouchEnded(
                        at: clampedEnd,
                        frogScreenPosition: frogScreenPoint,
                        frogWorldPosition: frogController.position,
                        worldOffset: worldManager.worldNode.position.y,
                        superJumpActive: frogController.superJumpActive
                    ) {
                        frogController.startJump(to: targetWorldPos)
                    }
                    slingshotController.cancelCurrentAiming()
                } else if frogController.isJumping {
                    frogController.isJumping = false
                    slingshotController.cancelCurrentAiming()
                }
            }
            return
        }
        
        if inputLocked { return }
        
        // Ignore touches inside bottom HUD bar area (already handled above)
        
        if gameState == .playing && (frogController.isGrounded || frogController.inWater) && !pendingAbilitySelection && !frogController.rocketActive {
            let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
            
            if let targetWorldPos = slingshotController.handleTouchEnded(
                at: location,
                frogScreenPosition: frogScreenPoint,
                frogWorldPosition: frogController.position,
                worldOffset: worldManager.worldNode.position.y,
                superJumpActive: frogController.superJumpActive
            ) {
                frogController.startJump(to: targetWorldPos)
            }
        }
    }
    
    // MARK: - Menus
    func showMainMenu() {
        menuBackdrop?.alpha = 1.0
        frogContainer.alpha = 1.0
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        pendingAbilitySelection = false
        gameState = .menu
        uiManager.showMainMenu(sceneSize: size)
    }
    
    func showAbilitySelection() {
        gameState = .abilitySelection
        uiManager.showAbilitySelection(sceneSize: size)
    }
    
    func selectAbility(_ abilityStr: String) {
        if abilityStr.contains("extraHeart") {
            maxHealth += 1
            health += 1
        } else if abilityStr.contains("superJump") {
            frogController.activateSuperJump()
            uiManager.showSuperJumpIndicator(sceneSize: size)
        } else if abilityStr.contains("refillHearts") {
            health = maxHealth
        } else if abilityStr.contains("lifeVest") {
            frogController.lifeVestCharges = min(6, frogController.lifeVestCharges + 1)
            updateBottomHUD()
        } else if abilityStr.contains("scrollSaver") {
            scrollSaverCharges = min(6, scrollSaverCharges + 1)
            updateBottomHUD()
            // Optionally, show a tiny feedback label
            let label = SKLabelNode(text: "Scroll Saver +1")
            label.fontName = "Arial-BoldMT"
            label.fontSize = 18
            label.fontColor = .systemYellow
            label.position = CGPoint(x: size.width/2, y: size.height - 140)
            label.zPosition = 400
            addChild(label)
            label.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 0, y: 20, duration: 0.8),
                    SKAction.fadeOut(withDuration: 0.8)
                ]),
                SKAction.removeFromParent()
            ]))
        } else if abilityStr.contains("flySwatter") {
            flySwatterCharges = min(6, flySwatterCharges + 1)
            updateBottomHUD()
            let label = SKLabelNode(text: "Fly Swatter +1")
            label.fontName = "Arial-BoldMT"
            label.fontSize = 18
            label.fontColor = .systemYellow
            label.position = CGPoint(x: size.width/2, y: size.height - 170)
            label.zPosition = 400
            addChild(label)
            label.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 0, y: 20, duration: 0.8),
                    SKAction.fadeOut(withDuration: 0.8)
                ]),
                SKAction.removeFromParent()
            ]))
        } else if abilityStr.contains("honeyJar") {
            honeyJarCharges = min(6, honeyJarCharges + 1)
            updateBottomHUD()
            let label = SKLabelNode(text: "Honey Jar +1")
            label.fontName = "Arial-BoldMT"
            label.fontSize = 18
            label.fontColor = .systemYellow
            label.position = CGPoint(x: size.width/2, y: size.height - 200)
            label.zPosition = 400
            addChild(label)
            label.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 0, y: 20, duration: 0.8),
                    SKAction.fadeOut(withDuration: 0.8)
                ]),
                SKAction.removeFromParent()
            ]))
        } else if abilityStr.contains("axe") {
            axeCharges = min(6, axeCharges + 1)
            updateBottomHUD()
            let label = SKLabelNode(text: "Axe +1")
            label.fontName = "Arial-BoldMT"
            label.fontSize = 18
            label.fontColor = .systemYellow
            label.position = CGPoint(x: size.width/2, y: size.height - 230)
            label.zPosition = 400
            addChild(label)
            label.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 0, y: 20, duration: 0.8),
                    SKAction.fadeOut(withDuration: 0.8)
                ]),
                SKAction.removeFromParent()
            ]))
        } else if abilityStr.contains("rocket") {
            frogController.activateRocket()
            uiManager.showRocketIndicator(sceneSize: size)

            glideTargetScreenX = nil // clear any prior target before rocket flight

            // During rocket flight, we don't need to move the frog controller position
            // The frog container will be positioned manually and the world won't pan
            // Keep the frog's world position where it is, but elevate it visually

            // Move frog container to center of screen for rocket flight
            let centerX = size.width / 2
            let centerY = size.height / 2

            // Animate frog moving to center
            let moveToCenter = SKAction.move(to: CGPoint(x: centerX, y: centerY), duration: 0.5)
            moveToCenter.timingMode = .easeInEaseOut
            frogContainer.run(moveToCenter)

            // Elevate frog z-position to fly above everything
            frogContainer.zPosition = 100
        }
        
        // FIX: Don't reset tadpoles here since we already did it when reaching threshold
        pendingAbilitySelection = false
        gameState = .playing
    }
    
    // MARK: - Lily Pad Factory
    /// Creates and returns a LilyPad at a world-space position with radius, automatically
    /// picking a type based on current score.
    /// - Behavior:
    ///   - Before 2000 points: always `.normal`.
    ///   - After 2000 points: weighted random among `.normal` (0.6), `.pulsing` (0.2), `.moving` (0.2).
    private func makeLilyPad(position: CGPoint, radius: CGFloat) -> LilyPad {
        let type: LilyPadType
        if score < 2000 {
            type = .normal
        } else {
            // Weighted random: 60% normal, 20% pulsing, 20% moving
            let r = CGFloat.random(in: 0...1)
            if r < 0.3 {
                type = .normal
            } else if r < 0.5 {
                type = .pulsing
            } else {
                type = .moving
            }
        }
        let pad = LilyPad(position: position, radius: radius, type: type)
        // Configure moving pads to know the screen width and a consistent speed
        if type == .moving {
            pad.screenWidthProvider = { [weak self] in self?.size.width ?? 1024 }
            pad.movementSpeed = 120.0
            pad.refreshMovement()
        }
        return pad
    }
    
    // MARK: - Private Helpers
    private func updateBottomHUD() {
        // Render hearts: show up to 6 in a row, filled for current health, outlined for the rest up to maxHealth
        let maxDisplayHearts = 6
        heartsContainer.removeAllChildren()
        let heartFontSize: CGFloat = 28
        let spacing: CGFloat = 8
        let totalHearts = min(maxDisplayHearts, maxHealth)
        for i in 0..<totalHearts {
            let isFilled = i < min(health, totalHearts)
            let heart = SKLabelNode(text: isFilled ? "\u{2764}\u{FE0F}" : "\u{1F90D}");
            heart.fontName = "Arial-BoldMT"
            heart.fontSize = heartFontSize
            heart.verticalAlignmentMode = .center
            heart.horizontalAlignmentMode = .left
            heart.position = CGPoint(x: CGFloat(i) * (heartFontSize + spacing), y: 0)
            heartsContainer.addChild(heart)
        }
        
        // Render life vests as a row of 🦺 icons matching current charges
        lifeVestsContainer.removeAllChildren()
        let vestFontSize: CGFloat = 22
        let vestSpacing: CGFloat = 6
        let vestCount = max(0, frogController.lifeVestCharges)
        for i in 0..<vestCount {
            let vest = SKLabelNode(text: "🦺")
            vest.fontSize = vestFontSize
            vest.verticalAlignmentMode = .center
            vest.horizontalAlignmentMode = .left
            vest.position = CGPoint(x: CGFloat(i) * (vestFontSize + vestSpacing), y: 0)
            lifeVestsContainer.addChild(vest)
        }
        
        // Render scroll savers as ⏱ icons in their container
        scrollSaverContainer.removeAllChildren()
        let saverFontSize: CGFloat = 22
        let saverSpacing: CGFloat = 6
        for i in 0..<scrollSaverCharges {
            let saver = SKLabelNode(text: "⏱")
            saver.fontSize = saverFontSize
            saver.verticalAlignmentMode = .center
            saver.horizontalAlignmentMode = .left
            saver.position = CGPoint(x: CGFloat(i) * (saverFontSize + saverSpacing), y: 0)
            scrollSaverContainer.addChild(saver)
        }
        
        // Render fly swatters as 🪰 icons only when there are charges
        // Position: On the third row, starting after scroll savers
        if let existing = hudBar.childNode(withName: "flySwatterContainer") {
            if flySwatterCharges <= 0 {
                existing.removeFromParent()
            } else if let flyContainer = existing as? SKNode {
                flyContainer.removeAllChildren()
                let flyFont: CGFloat = 22
                let flySpacing: CGFloat = 6
                for i in 0..<min(6, flySwatterCharges) {
                    let swat = SKLabelNode(text: "🪰")
                    swat.fontSize = flyFont
                    swat.verticalAlignmentMode = .center
                    swat.horizontalAlignmentMode = .left
                    swat.position = CGPoint(x: CGFloat(i) * (flyFont + flySpacing), y: 0)
                    flyContainer.addChild(swat)
                }
            }
        } else {
            if flySwatterCharges > 0 {
                let flyContainer = SKNode()
                flyContainer.name = "flySwatterContainer"
                // Position after scroll savers with some spacing
                flyContainer.position = CGPoint(x: scrollSaverContainer.position.x + 150, y: scrollSaverContainer.position.y)
                hudBar.addChild(flyContainer)
                let flyFont: CGFloat = 22
                let flySpacing: CGFloat = 6
                for i in 0..<min(6, flySwatterCharges) {
                    let swat = SKLabelNode(text: "🪰")
                    swat.fontSize = flyFont
                    swat.verticalAlignmentMode = .center
                    swat.horizontalAlignmentMode = .left
                    swat.position = CGPoint(x: CGFloat(i) * (flyFont + flySpacing), y: 0)
                    flyContainer.addChild(swat)
                }
            }
        }

        // Render honey jars as 🍯 icons only when there are charges
        // Position: Above fly swatters on row 2 (life vest row)
        if let existing = hudBar.childNode(withName: "honeyJarContainer") {
            if honeyJarCharges <= 0 {
                existing.removeFromParent()
            } else if let honeyContainer = existing as? SKNode {
                honeyContainer.removeAllChildren()
                let font: CGFloat = 22
                let spacing: CGFloat = 6
                for i in 0..<min(6, honeyJarCharges) {
                    let jar = SKLabelNode(text: "🍯")
                    jar.fontSize = font
                    jar.verticalAlignmentMode = .center
                    jar.horizontalAlignmentMode = .left
                    jar.position = CGPoint(x: CGFloat(i) * (font + spacing), y: 0)
                    honeyContainer.addChild(jar)
                }
            }
        } else {
            if honeyJarCharges > 0 {
                let honeyContainer = SKNode()
                honeyContainer.name = "honeyJarContainer"
                // Position: Same row as life vests, but after them with spacing
                honeyContainer.position = CGPoint(x: lifeVestsContainer.position.x + 150, y: lifeVestsContainer.position.y)
                hudBar.addChild(honeyContainer)
                let font: CGFloat = 22
                let spacing: CGFloat = 6
                for i in 0..<min(6, honeyJarCharges) {
                    let jar = SKLabelNode(text: "🍯")
                    jar.fontSize = font
                    jar.verticalAlignmentMode = .center
                    jar.horizontalAlignmentMode = .left
                    jar.position = CGPoint(x: CGFloat(i) * (font + spacing), y: 0)
                    honeyContainer.addChild(jar)
                }
            }
        }
        
        // Render axes as 🪓 icons only when there are charges
        if let existing = hudBar.childNode(withName: "axeContainer") {
            if axeCharges <= 0 {
                existing.removeFromParent()
            } else if let axeContainer = existing as? SKNode {
                axeContainer.removeAllChildren()
                let font: CGFloat = 22
                let spacing: CGFloat = 6
                for i in 0..<min(6, axeCharges) {
                    let axe = SKLabelNode(text: "🪓")
                    axe.fontSize = font
                    axe.verticalAlignmentMode = .center
                    axe.horizontalAlignmentMode = .left
                    axe.position = CGPoint(x: CGFloat(i) * (font + spacing), y: 0)
                    axeContainer.addChild(axe)
                }
            }
        } else {
            if axeCharges > 0 {
                let axeContainer = SKNode()
                axeContainer.name = "axeContainer"
                // Position: same row as scroll savers, after fly swatters
                let baseX = scrollSaverContainer.position.x + 300
                axeContainer.position = CGPoint(x: baseX, y: scrollSaverContainer.position.y)
                hudBar.addChild(axeContainer)
                let font: CGFloat = 22
                let spacing: CGFloat = 6
                for i in 0..<min(6, axeCharges) {
                    let axe = SKLabelNode(text: "🪓")
                    axe.fontSize = font
                    axe.verticalAlignmentMode = .center
                    axe.horizontalAlignmentMode = .left
                    axe.position = CGPoint(x: CGFloat(i) * (font + spacing), y: 0)
                    axeContainer.addChild(axe)
                }
            }
        }
    }
    
  
    // MARK: - Rocket Landing
    private func handleRocketLanding() {
        // NOTE: This method is currently unused by the rocket end flow; landing is now decided by proximity to a lily pad.
        // Reset frog z-position to normal
        frogContainer.zPosition = 50
        frogController.frog.alpha = 1.0  // Restore full visibility
        
        // Instead of looking for existing lily pads (which might be off-screen),
        // create a new lily pad in the visible area where the player can control the frog
        
        // Calculate a good landing position in world coordinates
        // We want it in the upper part of the visible screen area
        let screenLandingY = size.height * 0.75  // 75% up the screen
        let screenLandingX = size.width / 2 + CGFloat.random(in: -100...100) // Near center with some variation
        
        // Convert screen coordinates to world coordinates
        let landingWorldPos = convert(CGPoint(x: screenLandingX, y: screenLandingY), to: worldManager.worldNode)
        
        let landingPad = makeLilyPad(position: landingWorldPos, radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius))
        landingPad.node.position = landingPad.position
        landingPad.node.zPosition = 10
        worldManager.worldNode.addChild(landingPad.node)
        lilyPads.append(landingPad)
        
        print("🚀 Created landing pad at world position: \(landingWorldPos), screen position: (\(screenLandingX), \(screenLandingY))")
        
        // Animate frog landing to the screen position
        let landingAction = SKAction.move(to: CGPoint(x: screenLandingX, y: screenLandingY), duration: 0.8)
        landingAction.timingMode = .easeIn
        frogContainer.run(landingAction) { [weak self] in
            guard let self = self else { return }
            // After animation completes, update frog controller to world coordinates
            self.frogController.position = landingWorldPos
            self.frogController.isJumping = false
            self.frogController.isGrounded = true
            self.frogController.velocity = CGVector.zero
            
            // Properly land on the lily pad
            self.frogController.currentLilyPad = landingPad
            self.frogController.landOnPad(landingPad)
            
            // IMPORTANT: Ensure rocket state is fully cleared
            self.frogController.rocketActive = false
            self.frogController.rocketFramesRemaining = 0
            
            // Hide rocket indicator now that landing is complete
            self.uiManager.hideRocketIndicator()
            
            // Reset any rocket visual effects
            self.frogController.rocketSprite?.removeFromParent()
            self.frogController.rocketSprite = nil
            self.frogController.rocketTrail?.removeFromParent()
            self.frogController.rocketTrail = nil
            
            // Set grace period to prevent immediate "too slow" detection
            self.rocketLandingGraceFrames = 120  // 2 seconds at 60fps
            
            print("🚀 Rocket landing complete: grounded=\(self.frogController.isGrounded), position=\(self.frogController.position), rocketActive=\(self.frogController.rocketActive)")
            print("🚀 Landing pad screen position should be: (\(screenLandingX), \(screenLandingY))")
            
            // Verify the frog is visible by checking its screen position
            let finalScreenPos = self.convert(self.frogController.position, from: self.worldManager.worldNode)
            print("🚀 Frog final screen position: \(finalScreenPos)")
        }
        
        // Show visual feedback for the rocket landing at screen position
        let landingEffect = SKLabelNode(text: "🚀💥")
        landingEffect.fontSize = 32
        landingEffect.position = CGPoint(x: screenLandingX, y: screenLandingY)
        landingEffect.zPosition = 80
        addChild(landingEffect)
        
        let landingEffectAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.5, duration: 0.3),
                SKAction.fadeOut(withDuration: 0.5)
            ]),
            SKAction.removeFromParent()
        ])
        landingEffect.run(landingEffectAction)
        
        // Haptic feedback for landing
        HapticFeedbackManager.shared.impact(.medium)
    }
    
    // MARK: - Centralized Splash Trigger
    private func triggerSplashOnce(gameOverDelay: TimeInterval) {
        // If we've already triggered a splash for this fall/condition, do nothing.
        if splashTriggered { return }
        splashTriggered = true
        
        // Perform splash behavior
        frogController.splash()
        HapticFeedbackManager.shared.notification(.error)
        effectsManager?.createSplashEffect(at: frogContainer.position)
        
        // Cancel any previously scheduled game over
        pendingAbilitySelection = false
        pendingGameOverWorkItem?.cancel()
        
        // Schedule game over after delay
        let work = DispatchWorkItem { [weak self] in
            self?.gameOver(.splash)
        }
        pendingGameOverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + gameOverDelay, execute: work)
    }
}
