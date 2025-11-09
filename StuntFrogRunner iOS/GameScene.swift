//
//  GameScene.swift
//  Complete Top-down lily pad hopping game
//  Refactored for better maintainability with separated concerns
//

import SpriteKit

class GameScene: SKScene {
    
    // Scoring based on upward progress
    private var lastWorldYForScore: CGFloat = 0
    private var hasInitializedScoreAnchor: Bool = false
    
    // MARK: - Core Managers (Existing)
    var frogController: FrogController!
    var slingshotController: SlingshotController!
    var worldManager: WorldManager!
    var spawnManager: SpawnManager!
    var collisionManager: CollisionManager!
    var effectsManager: EffectsManager!
    var uiManager: UIManager!
    
    // MARK: - New Manager Classes (Refactored)
    var healthManager: HealthManager!
    var scoreManager: ScoreManager!
    private var stateManager: GameStateManager!
    private var visualEffectsController: VisualEffectsController!
    var hudController: HUDController!
    private var abilityManager: AbilityManager!
    private var facingDirectionController: FacingDirectionController!
    private var landingController: LandingController!
    private var touchInputController: TouchInputController!
    private var gameLoopCoordinator: GameLoopCoordinator!
    private var soundController: SoundController!
    private var edgeSpikeBushManager: EdgeSpikeBushManager!
    
    var visualFX: VisualEffectsController!
    
    // MARK: - Scene Nodes
    private var menuBackdrop: SKShapeNode?
    private var backgroundNode: SKSpriteNode?
    var frogContainer: SKSpriteNode!
    var hudBar: SKShapeNode!
    var hudBarShadow: SKShapeNode?  // Track the shadow element separately
    let hudBarHeight: CGFloat = 160
    var heartsContainer: SKNode!
    var lifeVestsContainer: SKNode!
    var scrollSaverContainer: SKNode!
    
    // MARK: - Level Management
    private var currentLevel: Int = 1
    private var baseSpawnRateMultiplier: CGFloat = 1.0
    
    // MARK: - Level Timer
    private var levelStartTime: CFTimeInterval = 0
    private var levelTimeRemaining: Double = 0
    private var levelTimerActive: Bool = false
    
    // MARK: - Finish Line
    private var finishLine: FinishLine?
    private var hasSpawnedFinishLine: Bool = false
    private var frogPreviousY: CGFloat = 0
    
    // MARK: - Parallax Background Elements
    private var rightTree: SKSpriteNode?
    private var leftTree: SKSpriteNode?
    
    // MARK: - Game Objects (in world space)
    var enemies: [Enemy] = []
    var tadpoles: [Tadpole] = []
    var bigHoneyPots: [BigHoneyPot] = []
    var lilyPads: [LilyPad] = []
    
    var maxHealth: Int {
        get { healthManager.maxHealth }
        set { healthManager.maxHealth = newValue }
    }

    // Tracks the currently pressed UI button node for press/release animation
    private var currentlyPressedButton: SKNode!
    
    // MARK: - Deinitializer
    deinit {
        print("🧹 GameScene deinitializing - cleaning up resources")
        
        // Clear all callback closures to break retain cycles
        healthManager?.onHealthChanged = nil
        healthManager?.onHealthDepleted = nil
        healthManager?.onTadpolesChanged = nil
        healthManager?.onAbilityChargesChanged = nil
        
        scoreManager?.onScoreChanged = nil
        scoreManager?.onHighScoreAchieved = nil
        scoreManager?.onLevelProgressed = nil
        
        stateManager?.onStateChanged = nil
        stateManager?.onWaterStateChanged = nil
        
        landingController?.onLandingSuccess = nil
        landingController?.onLandingMissed = nil
        
        abilityManager?.onExtraHeartSelected = nil
        abilityManager?.onRefillHeartsSelected = nil
        abilityManager?.onLifeVestSelected = nil
        abilityManager?.onScrollSaverSelected = nil
        abilityManager?.onFlySwatterSelected = nil
        abilityManager?.onHoneyJarSelected = nil
        abilityManager?.onAxeSelected = nil
        abilityManager?.onRocketSelected = nil
        
        hudController?.onScoreGained = nil
        
        finishLine?.onCrossed = nil
        
        // Force cleanup of all game objects
        forceCompleteCleanup()
        
        print("🧹 GameScene deinitialization complete")
    }
    
    // MARK: - Convenience Properties
    private var gameState: GameState {
        get { stateManager.currentState }
        set { stateManager.currentState = newValue }
    }
    
    var score: Int {
        get { scoreManager.score }
        set { scoreManager.score = newValue }
    }
    
    private var highScore: Int {
        scoreManager.highScore
    }
    
    // Glide tuning constants
    private let glideLerp: CGFloat = 0.08
    private let worldGlideLerp: CGFloat = 0.12
    
    // Rocket final approach state
    private var isRocketFinalApproach: Bool = false
    
    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
     
        
        backgroundColor = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
        
        
        
        physicsWorld.gravity = .zero
        
        setupManagers()
        setupGame()
        showMainMenu()
        
        if let shape = menuBackdrop {
            let inset: CGFloat = 24
            let backdropSize = CGSize(width: size.width - inset * 2, height: size.height - 220)
            let rect = CGRect(x: -backdropSize.width/2, y: -backdropSize.height/2, width: backdropSize.width, height: backdropSize.height)
            shape.path = CGPath(roundedRect: rect, cornerWidth: 24, cornerHeight: 24, transform: nil)
            shape.position = CGPoint(x: size.width/2, y: size.height/2 + 20)
        }
        
        
        
        // Pre-warm all haptic types
        HapticFeedbackManager.shared.impact(.light)
        HapticFeedbackManager.shared.impact(.medium)
        HapticFeedbackManager.shared.impact(.heavy)
        HapticFeedbackManager.shared.selectionChanged()
        HapticFeedbackManager.shared.notification(.success)
        HapticFeedbackManager.shared.notification(.warning)
        HapticFeedbackManager.shared.notification(.error)
  
    }
    
    // MARK: - Background Setup
  
    
    
    // MARK: - Managers Setup
    func setupManagers() {
        // Initialize existing managers
        frogController = FrogController(scene: self)
        slingshotController = SlingshotController(scene: self)

        worldManager = WorldManager(scene: self)
        effectsManager = EffectsManager(scene: self)
        uiManager = UIManager(scene: self)
        collisionManager = CollisionManager(scene: self, uiManager: nil, frogController: frogController)
        collisionManager.effectsManager = effectsManager
        collisionManager.uiManager = uiManager
        
        // Initialize new refactored managers
        healthManager = HealthManager(startingHealth: GameConfig.startingHealth)
        scoreManager = ScoreManager.shared
        stateManager = GameStateManager()
        soundController = SoundController.shared
        gameLoopCoordinator = GameLoopCoordinator()
        landingController = LandingController()
        touchInputController = TouchInputController()
        abilityManager = AbilityManager()
        edgeSpikeBushManager = EdgeSpikeBushManager(worldNode: worldManager.worldNode, scene: self)
        
        setupManagerCallbacks()
    }
    
    // MARK: - Manager Callbacks Setup
    private func setupManagerCallbacks() {
        // Health Manager Callbacks
        healthManager.onHealthChanged = { [weak self] newHealth, oldHealth in
            guard let self = self else { return }
            
            // Trigger heavy haptic only when losing health
            if newHealth < oldHealth {
                HapticFeedbackManager.shared.impact(.heavy)
                self.frogController.activateInvincibility(seconds: 3.0)
                self.visualEffectsController?.startInvincibilityFlicker()
            }
            
            self.updateHUD()
            
            // Start flashing when only 1 heart remains; stop when health recovers to 2 or more
            if newHealth == 1 {
                self.visualEffectsController?.startLowHealthFlash()
            } else {
                self.visualEffectsController?.stopLowHealthFlash()
            }
        }
        
        healthManager.onHealthDepleted = { [weak self] in
            guard let self = self else { return }
            self.visualEffectsController?.stopLowHealthFlash()
            self.playScaredSpinDropAndGameOver(reason: .healthDepleted)
        }
        
        healthManager.onMaxHealthChanged = { [weak self] _ in
            self?.updateHUD()
        }
        
        healthManager.onTadpolesChanged = { [weak self] tadpoles in
            guard let self = self else { return }
            self.uiManager.updateTadpoles(tadpoles)
            self.uiManager.updateStarProgress(current: tadpoles, threshold: GameConfig.tadpolesForAbility)
            self.updateHUD()
        }
        
        healthManager.onAbilityChargesChanged = { [weak self] in
            self?.updateHUD()
        }
        
        // Score Manager Callbacks
        scoreManager.onScoreChanged = { [weak self] score in
            self?.uiManager.updateScore(score)
        }
        
        scoreManager.onHighScoreAchieved = { [weak self] highScore in
            self?.uiManager.highlightScore(isHighScore: true)
        }
        
        scoreManager.onHighScoreChanged = { [weak self] _ in
            if self?.scoreManager.isHighScore() == false {
                self?.uiManager.highlightScore(isHighScore: false)
            }
        }
        
        scoreManager.onLevelProgressed = { [weak self] newLevel in
            print("🎮 ScoreManager reported level progression to Level \(newLevel)")
            // Update local level tracking to match ScoreManager
            self?.currentLevel = newLevel
        }
        
        // State Manager Callbacks
        stateManager.onStateChanged = { [weak self] newState, oldState in
            self?.handleStateChange(from: oldState, to: newState)
        }
        
        stateManager.onInputLocked = { [weak self] in
            // Cancel slingshot aiming when input gets locked
            if self?.slingshotController.slingshotActive == true {
                print("🎯 Input locked - automatically canceling slingshot aiming")
                self?.slingshotController.cancelCurrentAiming()
            }
        }
        
        stateManager.onWaterStateChanged = { [weak self] newState, oldState in
            self?.handleWaterStateChange(from: oldState, to: newState)
        }
        
        stateManager.onGameOver = { [weak self] reason in
            guard let self = self else { return }
            self.stopLevelTimer()  // Stop timer when game is over
            self.uiManager.hideSuperJumpIndicator()
            self.uiManager.hideRocketIndicator()
            self.healthManager.pendingAbilitySelection = false
            self.uiManager.showGameOverMenu(
                sceneSize: self.size,
                score: self.score,
                highScore: self.highScore,
                isNewHighScore: self.score == self.highScore && self.score > 0,
                reason: reason
            )
        }
        
        // Landing Controller Callbacks
        landingController.onLandingSuccess = { [weak self] pad in
            guard let self = self else { return }

            // Instrumentation and safety: clear actions/velocity and log positions

            self.frogController.frog.removeAllActions()
            self.frogController.frogShadow.removeAllActions()
            self.frogContainer.removeAllActions()
            self.frogController.velocity = .zero

            let frogWorldBefore = self.frogController.position
            let frogScreenBefore = self.convert(frogWorldBefore, from: self.worldManager.worldNode)
            let padWorld = pad.position
            let padScreen = self.convert(padWorld, from: self.worldManager.worldNode)

          

            // Perform land logic; snapping now done inside FrogController.landOnPad
            self.frogController.landOnPad(pad)

            let frogScreenAfter = self.convert(self.frogController.position, from: self.worldManager.worldNode)

            // Update grounded/water/jump state
            self.frogController.isJumping = false
            self.frogController.isGrounded = true
            self.frogController.inWater = false
            self.frogController.suppressWaterCollisionUntilNextJump = false

            // Effects and haptics at final screen position
            // Prefer slingshot pull magnitude for ripple intensity; fall back to distance if unavailable
            var intensity = self.slingshotController.lastPullIntensity
            if intensity <= 0.0 {
                // Fallback: compute from jump distance
                let jumpDistance = hypot(self.frogController.jumpTargetPos.x - self.frogController.jumpStartPos.x,
                                         self.frogController.jumpTargetPos.y - self.frogController.jumpStartPos.y)
                let maxDist = max(1.0, GameConfig.maxRegularJumpDistance)
                intensity = min(1.0, max(0.0, jumpDistance / maxDist))
            }
            self.effectsManager?.createLandingEffect(at: frogScreenAfter, intensity: intensity, lilyPad: pad)

            HapticFeedbackManager.shared.impact(.medium)

            // Set hasLandedOnce true after normal landing
            self.stateManager.hasLandedOnce = true

            // Clear locked facing on landing
            self.facingDirectionController?.clearLockedFacing()

            self.stateManager.splashTriggered = false

            // PERFORMANCE IMPROVEMENT: Spawn new objects only after successful jumps
            // This is much more efficient than spawning every few frames
            self.spawnManager.spawnObjects(
                sceneSize: self.size,
                lilyPads: &self.lilyPads,
                enemies: &self.enemies,
                tadpoles: &self.tadpoles,
                bigHoneyPots: &self.bigHoneyPots,
                worldOffset: self.worldManager.worldNode.position.y,
                frogPosition: self.frogController.position,
                superJumpActive: self.frogController.superJumpActive
            )
            
            // PERFORMANCE IMPROVEMENT: Run cleanup after landing too
            // Clean up objects that are now behind the frog's new position
            self.spawnManager.performCleanup(
                lilyPads: &self.lilyPads,
                enemies: &self.enemies,
                frogPosition: self.frogController.position,
                sceneSize: self.size,
                worldNode: self.worldManager.worldNode
            )

            if self.healthManager.pendingAbilitySelection && self.gameState == .playing {
                // Keep the flag true until the UI actually appears so touches are ignored
                // and lock input during the animation window.
                self.stateManager.lockInput(for:1.0)
                let vfx = self.visualEffectsController!
                vfx.playUpgradeCue()

                // Pause spawning and clear enemies around the landing pad immediately
                // so the scene is calm while the animation plays.
                self.spawnManager.pauseSpawningAndClearEnemies(around: pad, enemies: &self.enemies, sceneSize: self.size)

                // Delay showing the ability selection to let the animation be seen.
                let delay = SKAction.wait(forDuration: 0.9)
                let abilitySelectionAction = SKAction.run { [weak self] in
                    guard let self = self else { 
                        // If self is nil, we can't clear the flag, but this shouldn't happen in normal gameplay
                        return 
                    }
                    
                    // IMPORTANT: Always clear the pending flag, even if we can't show UI
                    self.healthManager.pendingAbilitySelection = false
                    
                    // Only show ability selection if we're still in a valid state
                    if self.gameState == .playing {
                        self.gameState = .abilitySelection
                        self.uiManager.showAbilitySelection(sceneSize: self.size)
                    } else {
                        print("🚨 Ability selection cancelled due to game state change: \(self.gameState)")
                    }
                }
                
                // Store the action with a key so we can cancel it if needed
                let sequence = SKAction.sequence([delay, abilitySelectionAction])
                self.run(sequence, withKey: "abilitySelectionDelay")
            }
        }
        
        landingController.onLandingMissed = { [weak self] in
            self?.handleMissedLanding()
        }
        
        landingController.onUnsafePadLanding = { [weak self] in
            self?.handleUnsafePadLanding()
        }
        
        // Ability Manager Callbacks
        setupAbilityManagerCallbacks()
    }
    
    private func setupAbilityManagerCallbacks() {
        abilityManager.onExtraHeartSelected = { [weak self] in
            guard let self = self else { return }
            self.healthManager.increaseMaxHealth()
        }
        
        abilityManager.onSuperJumpSelected = { [weak self] in
            guard let self = self else { return }
            self.frogController.activateSuperJump()
            self.uiManager.showSuperJumpIndicator(sceneSize: self.size)
            
            // Start super jump music
            self.soundController.handleSuperJumpAbilityActivated()
        }
        
        abilityManager.onRefillHeartsSelected = { [weak self] in
            self?.healthManager.refillHealth()
        }
        
        abilityManager.onLifeVestSelected = { [weak self] in
            guard let self = self else { return }
            print("🦺 Life Vest ability selected - adding charge")
            self.frogController.lifeVestCharges = min(6, self.frogController.lifeVestCharges + 1)
            print("🦺 Life Vest charges now: \(self.frogController.lifeVestCharges)")
            self.updateHUD()
        }
        
        abilityManager.onScrollSaverSelected = { [weak self] in
            print("📜 Scroll Saver ability selected")
            self?.healthManager.addScrollSaverCharge()
        }
        
        abilityManager.onFlySwatterSelected = { [weak self] in
            print("🪰 Fly Swatter ability selected")
            self?.healthManager.addFlySwatterCharge()
        }
        
        abilityManager.onHoneyJarSelected = { [weak self] in
            print("🍯 Honey Jar ability selected")
            self?.healthManager.addHoneyJarCharge()
        }
        
        abilityManager.onAxeSelected = { [weak self] in
            print("🪓 Axe ability selected")
            self?.healthManager.addAxeCharge()
        }
        
        abilityManager.onRocketSelected = { [weak self] in
            guard let self = self else { return }
            self.frogController.activateRocket()
            self.uiManager.showRocketIndicator(sceneSize: self.size)
            
            // Start rocket flight music
            self.soundController.handleRocketAbilityActivated()
            
            self.touchInputController.initializeRocketTarget(frogContainerX: self.frogContainer.position.x)
            
            let centerX = self.size.width / 2
            let centerY = self.size.height / 2
            
            let moveToCenter = SKAction.move(to: CGPoint(x: centerX, y: centerY), duration: 0.5)
            moveToCenter.timingMode = .easeInEaseOut
            self.frogContainer.run(moveToCenter)
            
            self.frogContainer.zPosition = 100
            
            if let bg = self.backgroundNode { bg.zPosition = -1000 }
        }
    }
    
    // MARK: - Game Setup
        func setupGame() {
            // Setup world (scrolls down)
            if let bg = backgroundNode {
                bg.removeFromParent()
                bg.zPosition = -1000
                addChild(bg)
            }
            
            let world = worldManager.setupWorld(sceneSize: size)
            addChild(world)
            
            // Setup parallax background tree
            setupBackgroundTree()
            
            // Initialize scoring anchor based on initial world Y
            lastWorldYForScore = worldManager.worldNode.position.y
            hasInitializedScoreAnchor = true
            
            // Setup spawn manager
            spawnManager = SpawnManager(scene: self, worldNode: worldManager.worldNode)
            spawnManager.startGracePeriod(duration: 1.5)
            
            // Note: Enemy spawning now uses a pending array to avoid simultaneous access issues
            // Enemies are flushed to the main array safely in the update loop
            
            // Setup frog container
            let frogRootNode = frogController.setupFrog(sceneSize: size)
            let frogContainerSprite = SKSpriteNode(color: .clear, size: .zero)
            frogContainerSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            frogContainerSprite.zPosition = 110
            frogContainerSprite.position = CGPoint(x: size.width / 2, y: size.height * 0.4)
            frogRootNode.position = .zero
            frogContainerSprite.addChild(frogRootNode)
            frogContainer = frogContainerSprite
            addChild(frogContainerSprite)
            
            // Initialize visual effects controller now that frog is set up
            visualEffectsController = VisualEffectsController(
                frogContainer: frogContainer,
                frogSprite: frogController.frog as! SKSpriteNode,
                frogShadow: frogController.frogShadow  // ✅ FIXED: Now passing actual shadow reference instead of nil
            )
            
            // Initialize facing direction controller
            facingDirectionController = FacingDirectionController(frogNode: frogController.frog)
            
            // Setup UI
            uiManager.setupUI(sceneSize: size)
            
            // Create menu backdrop
            setupMenuBackdrop()
            
            // Create bottom HUD bar
            setupHUDBar()
        }
    private func setupMenuBackdrop() {
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
            menuBackdrop = shape
            addChild(shape)
        }
    }
    
    private func setupHUDBar() {
        // Glassy oval tray centered above the bottom
        let trayWidth = size.width * 0.86
        let trayHeight: CGFloat = 160
        let trayRect = CGRect(x: -trayWidth/2, y: -trayHeight/2, width: trayWidth, height: trayHeight)
        let corner = trayHeight/2

        // Drop shadow (separate node so it doesn't clip the blur look)
        let shadow = SKShapeNode(path: CGPath(roundedRect: trayRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.35)
        shadow.strokeColor = .clear
        shadow.zPosition = 999
        shadow.position = CGPoint(x: size.width/2, y: trayHeight/2 - 6)
        hudBarShadow = shadow  // Store reference for visibility control
        addChild(shadow)

        // Main tray
        hudBar = SKShapeNode(path: CGPath(roundedRect: trayRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
        hudBar.fillColor = UIColor(red: 0.05, green: 0.35, blue: 0.32, alpha: 0.80)
        hudBar.strokeColor = UIColor.white.withAlphaComponent(0.45)
        hudBar.lineWidth = 2.0
        hudBar.zPosition = 1000
        hudBar.position = CGPoint(x: size.width/2, y: trayHeight/2)

       

        // Light bottom glow to suggest elevation
        let glow = SKShapeNode(ellipseOf: CGSize(width: trayWidth * 0.9, height: 40))
        glow.fillColor = UIColor.black.withAlphaComponent(0.25)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: -trayHeight/2 - 14)
        glow.zPosition = -1
        hudBar.addChild(glow)

        addChild(hudBar)

        // Containers layout: hearts top center, two ability rows beneath
        let contentTopY: CGFloat = trayHeight/2 - 28

        heartsContainer = SKNode()
        heartsContainer.position = CGPoint(x: 0, y: contentTopY)
        heartsContainer.name = "heartsContainer"
        hudBar.addChild(heartsContainer)

        // First ability row (left cluster)
        lifeVestsContainer = SKNode()
        lifeVestsContainer.position = CGPoint(x: -trayWidth * 0.28, y: contentTopY - 52)
        lifeVestsContainer.name = "lifeVestsContainer"
        hudBar.addChild(lifeVestsContainer)

        // Middle-left cluster: scroll saver
        scrollSaverContainer = SKNode()
        scrollSaverContainer.position = CGPoint(x: -trayWidth * 0.02, y: contentTopY - 52)
        scrollSaverContainer.name = "scrollSaverContainer"
        hudBar.addChild(scrollSaverContainer)

        // Initialize HUD controller
        hudController = HUDController()
        // Configure HUD controller with required references
        if let configurable = hudController as? HUDConfigurable {
            configurable.configure(
                gameScene: self,
                hudBar: hudBar,
                hudBarShadow: hudBarShadow,
                heartsContainer: heartsContainer,
                lifeVestsContainer: lifeVestsContainer,
                scrollSaverContainer: scrollSaverContainer
            )
        } else {
            // Fallback: try setting properties directly if exposed
            hudController.hudBar = hudBar
            hudController.hudBarShadow = hudBarShadow
            hudController.heartsContainer = heartsContainer
            hudController.lifeVestsContainer = lifeVestsContainer
            hudController.scrollSaverContainer = scrollSaverContainer
        }

        // Forward distance-based score gains from HUD to the single score source (ScoreManager)
        hudController.onScoreGained = { [weak self] gained in
            self?.scoreManager.addScore(gained)
        }
        
        // Handle rocket final approach state changes (last 3 seconds of rocket ride)
        hudController.onRocketFinalApproachChanged = { [weak self] inFinalApproach in
            self?.isRocketFinalApproach = inFinalApproach
        }

        updateHUD()
    }
    
    // MARK: - Background Tree Setup
    private func setupBackgroundTree() {
        
        // Create the right side tree aligned to the right edge of screen
        // First, try to load the treeRight.png image
        let treeTexture = SKTexture(imageNamed: "treeRight")
        
        // Check if we have a valid tree image, otherwise use placeholder
        if treeTexture.size().width > 1 && treeTexture.size().height > 1 {
            rightTree = SKSpriteNode(texture: treeTexture)
        }
        
        if let tree = rightTree {
            // Scale appropriately for the scene first so we can calculate proper position
            tree.setScale(0.3)
            
            // Position the tree aligned to the right edge of the screen
            // Using the tree's scaled width to position it properly at the edge
            let treeWidth = tree.size.width
            tree.position = CGPoint(
                x: size.width - (treeWidth * 0.9), // Right edge minus half tree width
                y: size.height * 0.3
            )
            
            // Layer behind the world but in front of background for depth
            tree.zPosition = 100  // Between background (-1000) and world (0)
            
            // Make it slightly transparent to emphasize it's in the background
            tree.alpha = 0.8
            
            addChild(tree)
            
        }
        // Create the left side tree aligned to the left edge of screen
        let leftTexture = SKTexture(imageNamed: "treeLeft")
        if leftTexture.size().width > 1 && leftTexture.size().height > 1 {
            leftTree = SKSpriteNode(texture: leftTexture)
        }
        if let ltree = leftTree {
            ltree.setScale(0.3)
            let treeWidth = ltree.size.width
            ltree.position = CGPoint(
                x: (treeWidth * 0.9),
                y: size.height * 0.3
            )
            ltree.zPosition = 100
            ltree.alpha = 0.8
            addChild(ltree)
        }
    }
    

    
    // MARK: - Background Tree Parallax Update
    private func updateBackgroundTreeParallax() {
        // Update both background trees if present
        let baseY = size.height * 0.3
        let parallaxFactor: CGFloat = 0.3
        let parallaxOffsetY = -frogController.position.y * parallaxFactor
        let currentTime = CFAbsoluteTimeGetCurrent()
        let swayY = cos(currentTime * 0.3) * 4.0
        let finalY = baseY + parallaxOffsetY + swayY

        if let rtree = rightTree {
            let treeWidth = rtree.size.width
            let fixedX = size.width - (treeWidth * 0.5)
            let margin: CGFloat = rtree.size.height * 0.5
            let clampedY = max(-margin, min(size.height + margin, finalY))
            rtree.position = CGPoint(x: fixedX, y: clampedY)
        }

        if let ltree = leftTree {
            let treeWidth = ltree.size.width
            let fixedX = (treeWidth * 0.5)
            let margin: CGFloat = ltree.size.height * 0.5
            let clampedY = max(-margin, min(size.height + margin, finalY))
            ltree.position = CGPoint(x: fixedX, y: clampedY)
        }
    }
    
    // MARK: - Background Tree Reset
    private func resetBackgroundTree() {
        // Reset right tree to its initial position at the right edge
        if let rtree = rightTree {
            let treeWidth = rtree.size.width
            let baseX = size.width - (treeWidth * 0.5)
            let baseY = size.height * 0.6
            rtree.position = CGPoint(x: baseX, y: baseY)
            rtree.alpha = 0.8
        }

        // Reset left tree to its initial position at the left edge
        if let ltree = leftTree {
            let treeWidth = ltree.size.width
            let baseX = (treeWidth * 0.5)
            let baseY = size.height * 0.6
            ltree.position = CGPoint(x: baseX, y: baseY)
            ltree.alpha = 0.8
        }

        print("🌳 Background trees reset. Right: \(String(describing: rightTree?.position)) Left: \(String(describing: leftTree?.position))")
    }
    
    // MARK: - HUD Update
    private func updateHUD() {
        hudController?.updateHUD(
            health: healthManager.health,
            maxHealth: healthManager.maxHealth,
            lifeVestCharges: frogController.lifeVestCharges,
            scrollSaverCharges: healthManager.scrollSaverCharges,
            flySwatterCharges: healthManager.flySwatterCharges,
            honeyJarCharges: healthManager.honeyJarCharges,
            axeCharges: healthManager.axeCharges,
            tadpolesCollected: healthManager.tadpolesCollected,
            tadpolesThreshold: GameConfig.tadpolesForAbility
        )
    }
    
    // MARK: - Game State Management
    private func handleStateChange(from oldState: GameState, to newState: GameState) {
        print("🎮 Game state changed from \(oldState) to \(newState)")
        uiManager.hideMenus()
        
        // Cancel any active slingshot aiming when state changes
        if slingshotController.slingshotActive && newState != .playing {
            print("🎯 Game state changed to \(newState) - canceling slingshot aiming")
            slingshotController.cancelCurrentAiming()
        }
        
        // Cancel pending ability selection if game state changes away from playing
        if newState != .playing && newState != .abilitySelection {
            if let _ = action(forKey: "abilitySelectionDelay") {
                print("🚨 Cancelling pending ability selection action due to state change to \(newState)")
                removeAction(forKey: "abilitySelectionDelay")
                healthManager.forceClearAbilitySelection(reason: "state change to \(newState)")
            }
        }
        
        // Handle audio state changes
        print("🎵 Calling soundController.handleGameStateChange(to: \(newState))")
        soundController.handleGameStateChange(to: newState)
        
        switch newState {
        case .menu:
            uiManager.setUIVisible(false)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 1.0, duration: 0.2))
            worldManager.worldNode.isPaused = true
        case .initialUpgradeSelection:
            uiManager.setUIVisible(false)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 0.9, duration: 0.2))
            worldManager.worldNode.isPaused = true
        case .playing:
            uiManager.setUIVisible(true)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 0.0, duration: 0.2))
            worldManager.worldNode.isPaused = false
            
            // If returning from ability selection, restore normal audio
            if oldState == .abilitySelection {
                soundController.resumeFromAbilitySelection()
            }
        case .paused, .abilitySelection, .gameOver:
          //  menuBackdrop?.run(SKAction.fadeAlpha(to: 0.9, duration: 0.2))
            worldManager.worldNode.isPaused = true
        }
    }
    
    private func handleWaterStateChange(from oldState: WaterState, to newState: WaterState) {
        // Visual or audio feedback when water state changes
        switch newState {
        case .water:
            showFloatingText("Water Mode: Watch for splashes!", color: .systemBlue)
            print("💧 Water state changed to WATER - frog can drown")
        case .ice:
            showFloatingText("Ice Mode: Slide to safety!", color: .systemCyan)
            SoundController.shared.playIceCrack()
            print("🧊 Water state changed to ICE - frog will slide")
        }
        
        // Reset frog state when switching water modes
        if frogController.onIce && newState == .water {
            frogController.forceStopSliding()
        }
    }
    
    func showMainMenu() {
        // Menu now handles its own dimming and structure. Backdrop fade is kept for consistency.
        stopLevelTimer()  // Stop timer when going to main menu
        menuBackdrop?.alpha = 1.0
        frogContainer.alpha = 1.0
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        healthManager.pendingAbilitySelection = false
        
        // Hide level indicator during menu
        childNode(withName: "levelIndicator")?.removeFromParent()
        
        // Hide background tree during menu
        rightTree?.alpha = 0.0
        
        // Resume spawning if we're exiting ability selection
        spawnManager.resumeSpawningAfterAbilitySelection()
        
        // Ensure spawn state and pad tadpole flags are reset when returning to menu
        spawnManager.reset(for: &lilyPads, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots)
        
        gameState = .menu
        uiManager.showMainMenu(sceneSize: size)
    }
    
    // MARK: - Game Start
    func startNewGame() {
        print("🎮 Starting completely new game - resetting all progress")
        // Force reset all progress for a brand new game
        scoreManager.resetScore()
        startGame()
    }
    
    func startGame() {
        print("GameScene.startGame() ENTERED")
        print("🔍 Current gameState: \(gameState)")
        
        // Reset level system only for completely new games (not level progression)
        if gameState == .menu || gameState == .gameOver {
            // Sync currentLevel with ScoreManager's level
            currentLevel = scoreManager.getCurrentLevel()
            baseSpawnRateMultiplier = 1.0 + (CGFloat(currentLevel - 1) * 0.1)
            print("🎮 Starting game at Level \(currentLevel) (from ScoreManager)")
            print("🎮 Base spawn rate multiplier: \(String(format: "%.2f", baseSpawnRateMultiplier))x")
            print("🎮 This should show initial upgrade selection")
        } else {
            print("🎮 Continuing from state \(gameState) - no level reset")
        }
        
        healthManager.reset(startingHealth: GameConfig.startingHealth)
        visualEffectsController.stopLowHealthFlash()
        uiManager.updateStarProgress(current: 0, threshold: GameConfig.tadpolesForAbility)
        
        stateManager.cancelPendingGameOver()
        
        // Cancel any pending ability selection actions from previous game
        if let _ = action(forKey: "abilitySelectionDelay") {
            print("🚨 Cancelling pending ability selection action from previous game")
            removeAction(forKey: "abilitySelectionDelay")
        }
        
        frogController.lifeVestCharges = 0
        uiManager.hideMenus()  // Clear any special track state that might be lingering from previous game
        soundController.handleSpecialAbilityEnded()
        
        gameLoopCoordinator.reset()
        landingController.reset()
        touchInputController.reset()
        
        // Reset spawn-related state and clear any lingering pad-tadpole links
        spawnManager.reset(for: &lilyPads, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots)
        
        // Reset edge spike bushes
        edgeSpikeBushManager.reset()
        
        // Reset finish line
        finishLine?.node.removeFromParent()
        finishLine = nil
        hasSpawnedFinishLine = false
        frogPreviousY = 0
        
        worldManager.reset()
        
        // Reset background tree position
        resetBackgroundTree()
        
        // Reset scoring anchor after world reset
        lastWorldYForScore = worldManager.worldNode.position.y
        
        // Update spawn manager with current level's spawn rate multiplier
        spawnManager.updateSpawnRateMultiplier(baseSpawnRateMultiplier)
        
        // Ensure spawning is resumed for new game
        spawnManager.resumeSpawningAfterAbilitySelection()
        hasInitializedScoreAnchor = true
        // First show the initial upgrade selection
        gameState = .initialUpgradeSelection
        uiManager.showInitialUpgradeSelection(sceneSize: size)
    }
    
    // This method is called after the player selects their initial upgrade
    func proceedToGameplay() {
        print("GameScene.proceedToGameplay() ENTERED")
        
        print("After hideMenus()")
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        menuBackdrop?.run(SKAction.fadeOut(withDuration: 0.2))
       // stateManager.createIceLevel()
        
        // CRITICAL FIX: Reset audio state and start gameplay music immediately
        // This ensures music plays even when coming from game over screen
        soundController.stopBackgroundMusic(fadeOut: false)
        soundController.startGameplayMusic()
        print("🎵 Gameplay music started immediately in startGame()")
        
        // Make sure background is present and sized
        if let bg = backgroundNode, let texture = bg.texture {
            if bg.parent == nil { addChild(bg) }
            bg.zPosition = -1000
            let texSize = texture.size()
            let scaleX = size.width / texSize.width
            let scaleY = size.height / texSize.height
            let scale = max(scaleX, scaleY)
            bg.size = CGSize(width: texSize.width * scale, height: texSize.height * scale)
            bg.position = CGPoint(x: size.width/2, y: size.height/2)
        }
        
       
        
        gameState = .playing
        stateManager.lockInput(for: 0.2)
        
        // Show current level indicator
        showLevelIndicator()
        
        slingshotController.cancelCurrentAiming()
        
        // Reset managers
        // Don't reset score here - it should be managed by the caller
        // proceedToGameplay is used for both new games and level progression
        uiManager.highlightScore(isHighScore: false)
       
        
        stateManager.splashTriggered = false
        frogController.superJumpActive = false
        uiManager.hideSuperJumpIndicator()
        frogController.rocketActive = false
        uiManager.hideRocketIndicator()
        frogController.invincible = false
        stateManager.hasLandedOnce = false
        isRocketFinalApproach = false
        
      
        
        frogController.rocketFramesRemaining = 0
        frogController.suppressWaterCollisionUntilNextJump = false
        frogController.inWater = false
        
        frogContainer.zPosition = 50
        
        // COMPREHENSIVE CLEANUP: Remove all existing nodes before clearing arrays
        print("🧹 Removing all existing world nodes from proceedToGameplay...")
        for enemy in enemies {
            enemy.node.removeFromParent()
        }
        for tadpole in tadpoles {
            tadpole.node.removeFromParent()
        }
        for lilyPad in lilyPads {
            lilyPad.node.removeFromParent()
        }
        
        enemies.removeAll()
        tadpoles.removeAll()
        lilyPads.removeAll()
        
        // CRITICAL FIX: Clear spatial grid after clearing lily pads array
        // This prevents old lily pads from blocking new spawns
        spawnManager.clearSpatialGrid()
        print("🧹 Spatial grid cleared in proceedToGameplay")
        
        
        
        let startWorldPos = CGPoint(x: size.width / 2, y: 0)
        
        let startPad = makeLilyPad(position: startWorldPos, radius: 60)
        startPad.node.position = startPad.position
        startPad.node.zPosition = 10
        worldManager.worldNode.addChild(startPad.node)
        lilyPads.append(startPad)
        
        // CRITICAL FIX: Add starting pad to spatial grid
        spawnManager.addToSpatialGrid(startPad)
        
        let desiredScreenPos = CGPoint(x: size.width / 2, y: size.height * 0.4)
        worldManager.worldNode.position = CGPoint(
            x: desiredScreenPos.x - startWorldPos.x,
            y: desiredScreenPos.y - startWorldPos.y
        )
        frogContainer.position = desiredScreenPos
        
        frogController.frog.removeAllActions()
        frogController.frogShadow.removeAllActions()
        frogContainer.removeAllActions()
        
        frogController.resetToStartPad(startPad: startPad, sceneSize: size)
        
        facingDirectionController.resetFacing()
        
        frogContainer.alpha = 1.0
        frogController.frog.alpha = 1.0
        frogController.frogShadow.alpha = 0.3
        
        // Show background tree during gameplay with gentle fade-in
        rightTree?.alpha = 0.0
        rightTree?.run(SKAction.fadeAlpha(to: 0.8, duration: 1.0))
        
        spawnManager.spawnInitialObjects(
            sceneSize: size,
            lilyPads: &lilyPads,
            enemies: &enemies,
            tadpoles: &tadpoles,
            bigHoneyPots: &bigHoneyPots,
            worldOffset: worldManager.worldNode.position.y
        )
        
        // Ensure spawning is resumed for new game
        spawnManager.resumeSpawningAfterAbilitySelection()
        
        // Initialize level timer
        startLevelTimer()
        
        //updateHUD()
        
        print("Game started! Frog world position: \(frogController.position)")
    }
    
    // MARK: - Game Over
    func gameOver(_ reason: GameOverReason) {
        stateManager.triggerGameOver(reason)
    }
    
    // MARK: - Level Timer Management
    
    private func startLevelTimer() {
        levelStartTime = CACurrentMediaTime()
        levelTimeRemaining = GameConfig.levelTimeLimit
        levelTimerActive = true
        print("⏱️ Started level timer: \(GameConfig.levelTimeLimit) seconds")
    }
    
    private func updateLevelTimer() {
        guard levelTimerActive else { return }
        
        let currentTime = CACurrentMediaTime()
        let elapsedTime = currentTime - levelStartTime
        levelTimeRemaining = max(0, GameConfig.levelTimeLimit - elapsedTime)
        
        // Update timer display
        hudController.updateTimer(timeRemaining: levelTimeRemaining)
        
        // Check if time is up
        if levelTimeRemaining <= 0 {
            levelTimerActive = false
            hudController.hideTimer()
            print("⏱️ Time's up! Game over.")
            gameOver(.timeUp)
        }
    }
    
    private func stopLevelTimer() {
        levelTimerActive = false
        hudController.hideTimer()
        print("⏱️ Level timer stopped")
    }
    
    private func calculateTimeBonus() -> Int {
        guard levelTimeRemaining > 0 else { return 0 }
        
        let secondsRemaining = Int(ceil(levelTimeRemaining))
        let bonus = secondsRemaining * GameConfig.timeBonus
        
        print("⏱️ Time bonus: \(secondsRemaining) seconds × \(GameConfig.timeBonus) points = \(bonus) points")
        return bonus
    }
    
    // MARK: - Ability Selection
    func selectAbility(_ abilityStr: String) {
        print("🎯 Selecting ability: \(abilityStr)")
        abilityManager.selectAbility(abilityStr)
        healthManager.pendingAbilitySelection = false
        
        // Show visual feedback for the selected ability
        if abilityStr.contains("extraHeart") {
            showFloatingText("Extra Heart!", color: .systemRed)
        } else if abilityStr.contains("superJump") {
            showFloatingText("Super Jump!", color: .systemYellow)
        } else if abilityStr.contains("refillHearts") {
            showFloatingText("Hearts Restored!", color: .systemGreen)
        } else if abilityStr.contains("lifeVest") {
            showFloatingText("Life Vest!", color: .systemBlue)
        } else if abilityStr.contains("scrollSaver") {
            showFloatingText("Scroll Saver!", color: .systemCyan)
        } else if abilityStr.contains("flySwatter") {
            showFloatingText("Fly Swatter!", color: .systemOrange)
        } else if abilityStr.contains("honeyJar") {
            showFloatingText("Honey Protection!", color: .systemYellow)
        } else if abilityStr.contains("axe") {
            showFloatingText("Axe!", color: .systemBrown)
        } else if abilityStr.contains("rocket") {
            showFloatingText("Rocket Boost!", color: .systemPurple)
        }
        
        // Update HUD to reflect the new ability/upgrade
        print("🔄 Updating HUD after ability selection")
        updateHUD()
        
        // Resume spawning when ability selection ends
        spawnManager.resumeSpawningAfterAbilitySelection()
        
        // Hide the ability selection menu
        uiManager.hideMenus()
        
        gameState = .playing
        print("✅ Ability selection complete, game state: \(gameState)")
    }
    
    // MARK: - Initial Upgrade Selection
    func handleInitialUpgradeSelection(_ buttonName: String) {
        // Parse the upgrade type from button name
        let upgradeString = buttonName.replacingOccurrences(of: "initialUpgrade_", with: "")
        
        print("🎯 Selecting initial upgrade: \(upgradeString)")
        
        // Apply the selected upgrade using the same ability manager system as selectAbility
        // Match the AbilityType enum values used in UIManager
        switch upgradeString {
        case "lifeVest":  // Fixed: was "lifeVests" (plural)
            abilityManager.onLifeVestSelected?()
            showFloatingText("Life Vest Added!", color: .systemYellow)
        case "honeyJar":  // Fixed: was "honeypot"
            abilityManager.onHoneyJarSelected?()
            showFloatingText("Honey Protection Added!", color: .systemOrange)
        case "extraHeart":
            abilityManager.onExtraHeartSelected?()
            showFloatingText("Extra Heart Added!", color: .systemRed)
        default:
            print("Unknown initial upgrade: \(upgradeString)")
        }
        
        // Update HUD to reflect the new upgrade (same as selectAbility)
        print("🔄 Updating HUD after initial upgrade selection")
        updateHUD()
        
        // Hide the upgrade selection and proceed to gameplay
        uiManager.hideMenus()
        
        

        proceedToGameplay()
    }
    
    // MARK: - Performance Tracking
    private var lastFrameTime: TimeInterval = 0
    private var frameTimes: [TimeInterval] = []
    private let maxFrameTimesSamples = 60  // Track last 60 frames
    
    // MARK: - Cached Values for Performance
    private var cachedLeftWorldX: CGFloat = -100
    private var cachedRightWorldX: CGFloat = 100
    
    // MARK: - Update Loop
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        
        // PERFORMANCE: Track frame times to identify stutters
        if lastFrameTime > 0 {
            let deltaTime = currentTime - lastFrameTime
            frameTimes.append(deltaTime)
            if frameTimes.count > maxFrameTimesSamples {
                frameTimes.removeFirst()
            }
            
            // Alert on frame drops (> 20ms = < 50 FPS)
            if deltaTime > 0.020 && gameLoopCoordinator.getFrameCount() % 60 == 0 {
                let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
                let fps = 1.0 / avgFrameTime
                print("⚠️  Frame drop detected: \(String(format: "%.1f", deltaTime * 1000))ms (Avg FPS: \(String(format: "%.1f", fps)))")
            }
        }
        lastFrameTime = currentTime
        
        // PERFORMANCE MONITORING: Log object counts occasionally
        if gameLoopCoordinator.getFrameCount() % 600 == 0 { // Every 10 seconds at 60fps
            // OPTIMIZED: Count types in single pass instead of multiple filters
            var logCount = 0, beeCount = 0, snakeCount = 0, dragonflyCount = 0, spikeBushCount = 0
            for enemy in enemies {
                switch enemy.type {
                case .log: logCount += 1
                case .bee: beeCount += 1  
                case .snake: snakeCount += 1
                case .dragonfly: dragonflyCount += 1
                case .spikeBush: spikeBushCount += 1
                case .edgeSpikeBush: break // Counted separately
                case .chaser: break
        
                }
            }
            let padCount = lilyPads.count
            let tadpoleCount = tadpoles.count
            let totalNodes = scene?.children.count ?? 0
            
            print("🔧 Performance Snapshot:")
            print("   - Total scene nodes: \(totalNodes)")
            print("   - Lily pads: \(padCount)")
            print("   - Logs: \(logCount), Bees: \(beeCount), Snakes: \(snakeCount)")
            print("   - Dragonflies: \(dragonflyCount), Spike bushes: \(spikeBushCount)")
            print("   - Tadpoles: \(tadpoleCount)")
            print("   - Frame: \(gameLoopCoordinator.getFrameCount())")
            
            // Alert if object counts are getting excessive
            if totalNodes > 200 {
                print("⚠️  HIGH NODE COUNT: \(totalNodes) nodes in scene")
            }
            if logCount > 15 {
                print("⚠️  HIGH LOG COUNT: \(logCount) logs active")
            }
            
            // CRITICAL: Emergency cleanup if we have way too many objects
            if padCount > 50 || logCount > 25 || totalNodes > 400 {
                print("🚨 EMERGENCY: Object count dangerously high - triggering force cleanup")
                print("   - Pads: \(padCount), Logs: \(logCount), Total nodes: \(totalNodes)")
                forceCompleteCleanup()
                
                // Respawn essential objects
                spawnManager.spawnInitialObjects(
                    sceneSize: size,
                    lilyPads: &lilyPads,
                    enemies: &enemies,
                    tadpoles: &tadpoles,
                    bigHoneyPots: &bigHoneyPots,
                    worldOffset: worldManager.worldNode.position.y
                )
            }
        }
        
        // PERFORMANCE: Only update background if it's not already configured
        if let bg = backgroundNode, bg.parent == nil {
            addChild(bg)
            if let texture = bg.texture {
                let texSize = texture.size()
                let scaleX = size.width / texSize.width
                let scaleY = size.height / texSize.height
                let scale = max(scaleX, scaleY)
                bg.size = CGSize(width: texSize.width * scale, height: texSize.height * scale)
                bg.position = CGPoint(x: size.width/2, y: size.height/2)
            }
        }
        
        gameLoopCoordinator.incrementFrame()
        let frameCount = gameLoopCoordinator.getFrameCount()
        
        // Update level timer
        updateLevelTimer()
        
        // Debug state every 10 seconds if frog seems stuck
        if frameCount % 600 == 0 { // Every 10 seconds at 60fps
            if !frogController.isGrounded && !frogController.inWater && !frogController.isJumping && !frogController.rocketActive {
                debugFrogState()
                print("🚨 Frog appears to be in stuck state - attempting recovery")
                
                // Force unlock input if it's been locked too long
                if stateManager.inputLocked {
                    stateManager.forceUnlockInput()
                }
                
                // Also cancel any stuck slingshot aiming
                if slingshotController.slingshotActive {
                    print("🎯 Found stuck slingshot during recovery - canceling")
                    slingshotController.cancelCurrentAiming()
                }
                
                // Try to recover the frog state
                _ = attemptStateRecovery()
            }
            
            // Check for stuck ability selection state
            if healthManager.pendingAbilitySelection && gameState == .playing && 
               frogController.isGrounded && !frogController.isJumping {
                print("🚨 Detected stuck pendingAbilitySelection - clearing")
                
                // Cancel any pending ability selection actions
                if let _ = action(forKey: "abilitySelectionDelay") {
                    print("🚨 Also cancelling stuck ability selection action")
                    removeAction(forKey: "abilitySelectionDelay")
                }
                
                healthManager.forceClearAbilitySelection(reason: "periodic stuck detection")
            }
        }
        
        // PERFORMANCE: Spawn objects only after successful jumps (handled in landing callback)
        // Removed frequent spawn calls from update loop for better performance
           
        // PERFORMANCE: Cleanup now handled on landing events instead of time-based
        // This is much more efficient than running cleanup every N frames
        
        if stateManager.inputLocked { return }
        
        // Dynamic scroll speed calculation
        var dynamicScroll: CGFloat = 0
        if frogController.rocketActive {
            // Check if we're in the final approach (last 3 seconds of rocket ride)
            if isRocketFinalApproach {
                // Slow down to 50% speed during final approach to help user find a lilypad
                dynamicScroll = GameConfig.rocketFinalApproachScrollSpeed
            } else {
                dynamicScroll = GameConfig.rocketScrollSpeed
            }
            
            // If we're within the rocket landing grace period after landing, slow even more
            if landingController.rocketLandingGraceFrames > 0 {
                dynamicScroll = GameConfig.rocketLandingSlowScrollSpeed
            }
            
            frogController.position.y += dynamicScroll

            let rocketScore = Int(dynamicScroll * 3)
            scoreManager.addScore(rocketScore)

            if frameCount % 20 == 0 {
                showFloatingScore("+\(rocketScore)", color: .orange)
            }
        } else {
            // No auto-scroll until the player has made and completed the first landing
            // Also stop auto-scroll while grounded/idle (not jumping)
            if stateManager.hasLandedOnce && !(frogController.isGrounded && !frogController.isJumping) {
                let speedTiers = score / GameConfig.scoreIntervalForSpeedIncrease
                let calculatedSpeed = GameConfig.scrollSpeed + (CGFloat(speedTiers) * GameConfig.scrollSpeedIncrement)
                dynamicScroll = min(GameConfig.maxScrollSpeed, calculatedSpeed)
            } else {
                dynamicScroll = 0
            }
        }
        
        // No automatic vertical scroll; world y is derived from frog centering
        
        // Keep frog centered on screen; move world around it
        let screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        frogContainer.position = screenCenter
        // Position world so that frog's world position maps to the screen center
        worldManager.worldNode.position.x = screenCenter.x - frogController.position.x
        worldManager.worldNode.position.y = screenCenter.y - frogController.position.y
        
        // PERFORMANCE: Update parallax background every 3 frames for smoother but efficient motion
        if frameCount % 3 == 0 {
            updateBackgroundTreeParallax()
        }
        
        // Distance-based scoring: when the world moves downward relative to the screen, the frog advanced upward in world space.
        if hasInitializedScoreAnchor {
            // World node y decreases as we move "forward" (frog up). Compute positive progress.
            let prev = lastWorldYForScore
            let curr = worldManager.worldNode.position.y
            let deltaWorldY = prev - curr // positive when world moved down
            if deltaWorldY > 0 {
                hudController?.updateScoreForVerticalScroll(deltaY: deltaWorldY)
            }
            lastWorldYForScore = curr
        } else {
            lastWorldYForScore = worldManager.worldNode.position.y
            hasInitializedScoreAnchor = true
        }
        
        // Replace scroll score add with no double scoring
        _ = worldManager.updateScrolling(isJumping: frogController.isJumping)
        
        // Horizontal movement during rocket only
        if frogController.rocketActive {
            touchInputController.updateRocketSteering(
                frogContainerX: frogContainer.position.x,
                sceneWidth: size.width
            )
            
            if let targetX = touchInputController.glideTargetScreenX {
                let currentX = frogContainer.position.x
                frogContainer.position.x = currentX + (targetX - currentX) * glideLerp
                
                let newWorld = convert(CGPoint(x: frogContainer.position.x, y: frogContainer.position.y),
                                       to: worldManager.worldNode)
                frogController.position.x = newWorld.x
            }
            
            // World positioning to allow horizontal movement
            let offsetFromCenter = frogContainer.position.x - (size.width / 2)
            let desiredWorldX = -offsetFromCenter * 0.4
            worldManager.worldNode.position.x += (desiredWorldX - worldManager.worldNode.position.x) * worldGlideLerp
        }
        
        let frogScreenPoint = frogContainer.position
        let frogScreenY = frogContainer.position.y
        let failThreshold: CGFloat = -40
        
        // Check for scrolled off screen
        if frogScreenY < failThreshold && gameState == .playing && !frogController.rocketActive && landingController.rocketLandingGraceFrames <= 0 {
            handleScrolledOffScreen(frogScreenPoint: frogScreenPoint)
        }
        
        frogController.updateJump()
        
        // Update ice sliding if active
        if frogController.onIce {
            frogController.updateSliding()
            
            // OPTIMIZED: Only check lily pad collision every 3 frames during sliding to reduce overhead
            if frameCount % 3 == 0 {
                let slideCollisionDistance: CGFloat = 60
                let slideCollisionDistanceSq = slideCollisionDistance * slideCollisionDistance // Avoid sqrt
                
                for pad in lilyPads {
                    let dx = frogController.position.x - pad.position.x
                    let dy = frogController.position.y - pad.position.y
                    let distanceSq = dx*dx + dy*dy // Use squared distance to avoid expensive sqrt
                    
                    if distanceSq < slideCollisionDistanceSq {
                        // Stop sliding and land on the pad
                        frogController.forceStopSliding()
                        frogController.landOnPad(pad)
                        
                        // Play landing sound and effect
                        SoundController.shared.playFrogLand()
                        effectsManager?.createLandingEffect(at: convert(frogController.position, from: worldManager.worldNode), intensity: 0.5, lilyPad: pad)
                        HapticFeedbackManager.shared.impact(.light)
                        
                        showFloatingText("Landed!", color: .systemGreen)
                        print("🧊 Frog slid into lily pad and stopped")
                        break
                    }
                }
            }
        }
        
        // Update the frog's facing direction based on movement/state
        facingDirectionController.updateFacingDirection(
            isPlaying: gameState == .playing,
            rocketActive: frogController.rocketActive,
            frogContainerPosition: frogContainer.position,
            glideTargetScreenX: touchInputController.glideTargetScreenX,
            frogVelocity: frogController.velocity
        )
        
//        let scrollScore = worldManager.updateScrolling(isJumping: frogController.isJumping)
//        scoreManager.addScore(scrollScore)
        
        if !frogController.isJumping && !frogController.isGrounded {
            let landingResult = landingController.checkLanding(
                frogPosition: frogController.position,
                lilyPads: lilyPads,
                isJumping: frogController.isJumping,
                isGrounded: frogController.isGrounded
            )
        }
        
        if frogController.isGrounded, let pad = frogController.currentLilyPad, pad.type == .pulsing, !pad.isSafeToLand {
            if frogController.suppressWaterCollisionUntilNextJump {
            } else {
                handleUnsafePadLanding()
            }
            return
        }
        
        // PERFORMANCE: Reduce frequency of expensive collision updates  
        if frameCount % 2 == 0 {  // Run collision updates every other frame
            // Update enemies with collision handling
            updateEnemies(frogScreenPoint: frogScreenPoint)
        }
        
        // PERFORMANCE: Update edge spike bushes less frequently to reduce overhead
        if frameCount % 4 == 0 {  // Every 4th frame instead of every other frame
            // Update and check collisions with edge spike bushes
            edgeSpikeBushManager.updateAndSpawn(
                worldOffset: worldManager.worldNode.position.y,
                sceneSize: size,
                frogPosition: frogController.position
            )
            
            // Check collisions with edge spike bushes using the collision manager
            let edgeSpikeBushes = edgeSpikeBushManager.getAllEdgeSpikeBushes()
            for bush in edgeSpikeBushes {
                if collisionManager.checkCollision(enemy: bush, frogPosition: frogController.position, frogIsJumping: frogController.isJumping) {
                    if !frogController.invincible && !frogController.rocketActive {
                        handleEdgeSpikeBushCollision()
                        break // Only process one collision per frame
                    }
                }
            }
        }
        
        // PERFORMANCE: Cache coordinate conversions to avoid expensive matrix math every frame
        if frameCount % 5 == 0 {  // Update world bounds every 5 frames instead of every frame
            cachedLeftWorldX = convert(CGPoint(x: -100, y: 0), to: worldManager.worldNode).x
            cachedRightWorldX = convert(CGPoint(x: size.width + 100, y: 0), to: worldManager.worldNode).x
        }
        
        gameLoopCoordinator.updateEnemies(
            enemies: &enemies,
            lilyPads: &lilyPads,
            frogPosition: frogController.position,
            leftWorldX: cachedLeftWorldX,
            rightWorldX: cachedRightWorldX,
            worldOffset: worldManager.worldNode.position.y,
            sceneHeight: size.height
        )
        
        // THREAD SAFETY: Flush any pending enemies to avoid simultaneous access issues
        spawnManager.flushPendingEnemies(to: &enemies)
        
        // Update tadpoles
        collisionManager.updateTadpoles(
            tadpoles: &tadpoles,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            worldOffset: worldManager.worldNode.position.y,
            screenHeight: size.height,
            rocketActive: frogController.rocketActive,
            onCollect: { [weak self] in
                self?.handleTadpoleCollect()
            }
        )
        
        // Update big honey pots
        collisionManager.updateBigHoneyPots(
            bigHoneyPots: &bigHoneyPots,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            worldOffset: worldManager.worldNode.position.y,
            screenHeight: size.height,
            rocketActive: frogController.rocketActive,
            onCollect: { [weak self] in
                self?.handleBigHoneyPotCollect()
            }
        )
        
        // PERFORMANCE: Update lily pads every other frame to reduce overhead
        if frameCount % 2 == 1 {  // Alternate with enemy updates
            collisionManager.updateLilyPads(
                lilyPads: &lilyPads,
                worldOffset: worldManager.worldNode.position.y,
                screenHeight: size.height,
                frogPosition: frogController.position
            )
        }
        
        // MARK: - Finish Line Logic
        // Check if score has reached threshold and spawn finish line if not already spawned
        // Level-based finish line scoring: each level requires 25,000 points
        let finishLineThreshold = currentLevel * 25000 // Level 1: 25,000, Level 2: 50,000, Level 3: 75,000, etc.
        if score >= finishLineThreshold && !hasSpawnedFinishLine {
            print("🏁 Spawning finish line at score \(score) (threshold: \(finishLineThreshold)) for Level \(currentLevel)")
            spawnFinishLine()
        }
        
        // Check for finish line crossing
        if let finishLine = finishLine {
            // CRITICAL: Only check for crossing if we haven't already triggered level completion
            if action(forKey: "levelTransition") == nil {
                let crossed = finishLine.checkCrossing(frogPosition: frogController.position, frogPreviousY: frogPreviousY)
                
                // PERFORMANCE: Only do debug output every 180 frames (3 seconds) when near finish line
                if crossed {
                    print("🏁 Finish line crossed detected in update loop")
                    handleFinishLineCrossed()
                } else if gameLoopCoordinator.getFrameCount() % 180 == 0 {
                    let currentY = frogController.position.y
                    let finishY = finishLine.position.y
                    if abs(currentY - finishY) < 200 {
                        print("🏁 Near finish line: frogY=\(Int(currentY)), finishY=\(Int(finishY)), distance=\(Int(finishY - currentY))")
                    }
                }
            }
        }
        
        // Store frog's current Y position for next frame's finish line crossing detection
        frogPreviousY = frogController.position.y
        
        frogController.updateInvincibility()
        if !frogController.invincible {
            visualEffectsController.stopInvincibilityFlicker()
        }
        
        frogController.updateSuperJump(indicator: uiManager.superJumpIndicator)
        if !frogController.superJumpActive {
            uiManager.hideSuperJumpIndicator()
        }
        
        frogController.updateRocket(indicator: uiManager.rocketIndicator)
        
        // Update HUD for rocket final approach (last 3 seconds)
        if frogController.rocketActive {
            let timeRemaining = TimeInterval(frogController.rocketFramesRemaining) / 60.0
            hudController?.updateRocketFinalApproach(timeRemaining: timeRemaining)
            
            // Show land button when 4 seconds or less remain (240 frames at 60 fps)
            if frogController.rocketFramesRemaining <= 240 {
                if uiManager.rocketLandButton == nil {
                    uiManager.showRocketLandButton(sceneSize: size)
                }
            } else {
                uiManager.hideRocketLandButton()
            }
        } else {
            // Clear the banner when rocket is not active
            hudController?.updateRocketFinalApproach(timeRemaining: nil)
            uiManager.hideRocketLandButton()
        }
        
        // Check if rocket just ended: decide landing outcome
        if !frogController.rocketActive && frogContainer.zPosition > 50 {
            handleRocketEnd()
        }
        
        landingController.updatePauseFrames()
    }
    
    // MARK: - Enemy Update
    private func updateEnemies(frogScreenPoint: CGPoint) {
        collisionManager.updateEnemies(
            enemies: &enemies,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            rocketActive: frogController.rocketActive,
            frogIsJumping: frogController.isJumping,
            worldOffset: worldManager.worldNode.position.y,
            lilyPads: &lilyPads,
            onHit: { [weak self] enemy -> HitOutcome in
                return self?.handleEnemyHit(enemy: enemy) ?? .hitOnly
            },
            onLogBounce: { [weak self] enemy in
                self?.handleLogBounce(enemy: enemy)
            }
        )
    }
    
    private func handleEnemyHit(enemy: Enemy) -> HitOutcome {
        var consumedProtection = false
        var destroyCause: AbilityType? = nil
        
        if enemy.type == EnemyType.bee && healthManager.useHoneyJarCharge() {
            consumedProtection = true
            destroyCause = .honeyJar
            showFloatingText("Yum Yum!", color: .systemYellow)
            // Honey jar protects fully from bees: remove bee, no heart lost, no invincibility side effects.
            return .destroyed(cause: .honeyJar)
        } else if enemy.type == EnemyType.log && healthManager.useAxeCharge() {
            consumedProtection = true
            destroyCause = .axe
            showFloatingText("Chop!", color: .systemGreen)
        } else if enemy.type == EnemyType.dragonfly && healthManager.useFlySwatterCharge() {
            consumedProtection = true
            destroyCause = nil
            showFloatingText("Swat!", color: .systemOrange)
        }
        
        // Logs: if we have an axe, chop and pass through; otherwise, bonk/bounce without losing a heart
        if enemy.type == EnemyType.log {
            if consumedProtection, destroyCause == .axe {
                return .destroyed(cause: .axe)
            } else {
                return .hitOnly
            }
        }
        
        if !consumedProtection {
            healthManager.damageHealth()
            // Show scared reaction on the frog for a brief moment
            frogController.showScared(duration: 1.0)
        }
        
        frogController.activateInvincibility()
        
        // Handle spike bushes - they damage the frog but remain in place
        if enemy.type == EnemyType.spikeBush || enemy.type == EnemyType.edgeSpikeBush {
            // Spike bushes damage frog but don't get destroyed
            return .hitOnly
        }
        
        // Always remove bees, dragonflies, and snakes when they hit the frog
        if enemy.type == EnemyType.bee || enemy.type == EnemyType.dragonfly || enemy.type == EnemyType.snake {
            return .destroyed(cause: destroyCause)
        }
        
        if consumedProtection {
            return .destroyed(cause: destroyCause)
        } else {
            return .hitOnly
        }
    }
    
 func handleLogBounce(enemy: Enemy) {
        let dx = frogController.position.x - enemy.position.x
        let dy = frogController.position.y - enemy.position.y
        let len = max(0.001, sqrt(dx*dx + dy*dy))
        let nx = dx / len
        let ny = dy / len
        
        let v = frogController.velocity
        let dot = v.dx * nx + v.dy * ny
        var reflected = CGVector(dx: v.dx - 2 * dot * nx,
                                 dy: v.dy - 2 * dot * ny)
        reflected.dx *= 0.7
        reflected.dy *= 0.7
        
        let separation: CGFloat = 8
        let sepPos = CGPoint(x: frogController.position.x + nx * separation,
                             y: frogController.position.y + ny * separation)
        frogController.position = sepPos
        
        let reflLen = max(0.001, sqrt(reflected.dx * reflected.dx + reflected.dy * reflected.dy))
        let rnx = reflected.dx / reflLen
        let rny = reflected.dy / reflLen
        let reboundDistance: CGFloat = 120
        let reboundTarget = CGPoint(x: sepPos.x + rnx * reboundDistance,
                                    y: sepPos.y + rny * reboundDistance)
        
        frogController.startJump(to: reboundTarget)
        
        frogController.superJumpActive = false
        uiManager.hideSuperJumpIndicator()
        
        effectsManager?.createBonkLabel(at: frogContainer.position)
        HapticFeedbackManager.shared.impact(.heavy)
    }
    
    private func handleEdgeSpikeBushCollision() {
        // Damage the frog's health
        healthManager.damageHealth()
        
        // Show scared reaction on the frog
        frogController.showScared(duration: 1.0)
        
        // Activate invincibility frames
        frogController.activateInvincibility()
        
        // Play ice crack sound to indicate hitting the spike bushes
        soundController.playIceCrack()
        
        // Add some visual feedback
        showFloatingText("Ouch!", color: .systemRed)
        
        // Heavy haptic feedback
        HapticFeedbackManager.shared.impact(.heavy)
    }
    
    // MARK: - Tadpole Collection
    private func handleTadpoleCollect() {
        if frogController.rocketActive { return }
        
        let abilityTriggered = healthManager.collectTadpole()
        scoreManager.addScore(100)
        soundController.playCollectSound()
        soundController.playScoreSound(scoreValue: 100)
        
        showFloatingScore("+100", color: .systemYellow)
        
        if abilityTriggered {
            // Ability selection will be shown on next landing
        }
    }
    
    // MARK: - Big Honey Pot Collection
    private func handleBigHoneyPotCollect() {
        if frogController.rocketActive { return }
        
        // Max out honey jar charges (set to 4 as specified)
        healthManager.maxOutHoneyJarCharges()
        
        // Give significant score bonus for collecting big honey pot
        scoreManager.addScore(500)
        soundController.playCollectSound()
        soundController.playScoreSound(scoreValue: 500)
        
        showFloatingScore("+500 - Honey Maxed!", color: .systemOrange)
        
        // Visual feedback
        showFloatingText("Honey Pot Maxed!", color: .systemOrange)
        
        // Light haptic feedback for positive collection
        HapticFeedbackManager.shared.impact(.medium)
    }
    
    // MARK: - Scrolled Off Screen
    private func handleScrolledOffScreen(frogScreenPoint: CGPoint) {
        if healthManager.useScrollSaverCharge() {
            let targetWorldY = -worldManager.worldNode.position.y + size.height * 0.75
            let safeX = max(80, min(size.width - 80, frogController.position.x))
            let newPadPos = CGPoint(x: safeX, y: targetWorldY)
            let rescuePad = makeLilyPad(position: newPadPos, radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius))
            rescuePad.node.position = rescuePad.position
            rescuePad.node.zPosition = 10
            worldManager.worldNode.addChild(rescuePad.node)
            lilyPads.append(rescuePad)
            frogController.position = newPadPos
            frogController.landOnPad(rescuePad)
            // Rescue pad landing: small-to-medium ripple to feel gentle
            effectsManager?.createLandingEffect(at: convert(newPadPos, from: worldManager.worldNode), intensity: 0.4, lilyPad: rescuePad)
            showFloatingText("Scroll Saver -1", color: .systemYellow)
        } else {
            HapticFeedbackManager.shared.notification(.error)
            gameOver(.tooSlow)
        }
    }
    
    // MARK: - Rocket End
    private func handleRocketEnd() {
        frogContainer.zPosition = 50
        
        if let padUnderFrog = landingController.checkRocketLanding(
            frogPosition: frogController.position,
            lilyPads: lilyPads
        ) {
            // Successful landing
            frogController.landOnPad(padUnderFrog)
            frogController.isGrounded = true
            frogController.inWater = false
            // Rocket landings use a medium-high intensity ripple
            effectsManager?.createLandingEffect(at: frogContainer.position, intensity: 0.75, lilyPad: padUnderFrog)
            HapticFeedbackManager.shared.impact(.medium)
            landingController.setRocketGracePeriod(frames: 180) // 3 seconds of slow scroll grace
            facingDirectionController.clearLockedFacing()
            
            // PERFORMANCE IMPROVEMENT: Spawn new objects after rocket landing too
            spawnManager.spawnObjects(
                sceneSize: size,
                lilyPads: &lilyPads,
                enemies: &enemies,
                tadpoles: &tadpoles,
                bigHoneyPots: &bigHoneyPots,
                worldOffset: worldManager.worldNode.position.y,
                frogPosition: frogController.position,
                superJumpActive: frogController.superJumpActive
            )
            
            // PERFORMANCE IMPROVEMENT: Cleanup after rocket landing
            spawnManager.performCleanup(
                lilyPads: &lilyPads,
                enemies: &enemies,
                frogPosition: frogController.position,
                sceneSize: size,
                worldNode: worldManager.worldNode
            )
        } else {
            // Missed landing
            handleMissedLanding()
        }
    }
    
    // MARK: - Rocket Land Button Handler
    private func handleRocketLandButtonTap() {
        guard frogController.rocketActive else { return }
        
        // Check if there's a lily pad nearby to land on
        if let padUnderFrog = landingController.checkRocketLanding(
            frogPosition: frogController.position,
            lilyPads: lilyPads
        ) {
            // Successful landing - force end the rocket ride
            frogController.forceRocketLanding()
            frogContainer.zPosition = 50
            frogController.landOnPad(padUnderFrog)
            frogController.isGrounded = true
            frogController.inWater = false
            // Rocket land button landings use a medium-high intensity ripple
            effectsManager?.createLandingEffect(at: frogContainer.position, intensity: 0.75, lilyPad: padUnderFrog)
            HapticFeedbackManager.shared.impact(.medium)
            landingController.setRocketGracePeriod(frames: 180)
            facingDirectionController.clearLockedFacing()
            
            // Hide the land button
            uiManager.hideRocketLandButton()
            
            // Show success feedback
            showFloatingText("Nice Landing!", color: .systemGreen)
            
            // PERFORMANCE IMPROVEMENT: Spawn new objects after manual rocket landing
            spawnManager.spawnObjects(
                sceneSize: size,
                lilyPads: &lilyPads,
                enemies: &enemies,
                tadpoles: &tadpoles,
                bigHoneyPots: &bigHoneyPots,
                worldOffset: worldManager.worldNode.position.y,
                frogPosition: frogController.position,
                superJumpActive: frogController.superJumpActive
            )
            
            // PERFORMANCE IMPROVEMENT: Cleanup after manual rocket landing
            spawnManager.performCleanup(
                lilyPads: &lilyPads,
                enemies: &enemies,
                frogPosition: frogController.position,
                sceneSize: size,
                worldNode: worldManager.worldNode
            )
        } else {
            // No lily pad nearby - show feedback but don't land
            showFloatingText("No lily pad nearby!", color: .systemRed)
        }
    }
    
    // MARK: - Landing Helpers
    private func handleUnsafePadLanding() {
        if stateManager.splashTriggered { return }
        stateManager.splashTriggered = true
        
        if frogController.suppressWaterCollisionUntilNextJump {
            print("🌊 Suppressing water collision until next jump")
            healthManager.pendingAbilitySelection = false
            return
        }
        
        // Check water state to determine behavior
        switch stateManager.waterState {
        case .ice:
            handleIceLanding()
        case .water:
            handleUnsafePadWaterSplash()
        }
    }
    
    private func handleUnsafePadWaterSplash() {
        frogController.splash()
        facingDirectionController.clearLockedFacing()
        HapticFeedbackManager.shared.notification(.error)
        effectsManager?.createSplashEffect(at: frogContainer.position)
        
        // Check for life vest charges (same logic as handleMissedLanding)
        if frogController.lifeVestCharges > 0 {
            frogController.lifeVestCharges -= 1
            updateHUD()
            stateManager.cancelPendingGameOver()
            healthManager.pendingAbilitySelection = false
            frogController.suppressWaterCollisionUntilNextJump = true
            stateManager.splashTriggered = false
            showFloatingText("Life Vest -1", color: .systemYellow)
            
            // CRITICAL FIX: After life vest rescue, place frog on nearest safe lily pad
            // Find nearest safe lily pad to land on
            var nearestPad: LilyPad?
            var nearestDist: CGFloat = .infinity
            for pad in lilyPads where pad.type != .pulsing || pad.isSafeToLand {
                let dx = frogController.position.x - pad.position.x
                let dy = frogController.position.y - pad.position.y
                let dist = sqrt(dx*dx + dy*dy)
                if dist < nearestDist {
                    nearestDist = dist
                    nearestPad = pad
                }
            }
            
            // Replaced block as per instructions:
            // Life vest rescue: keep frog floating at current position; do not snap to a pad
            frogController.inWater = true
            frogController.isGrounded = false
            frogController.isJumping = false
            // Position remains unchanged; player can slingshot to safety
            print("🦎 Life vest rescue: Keeping frog at splash position (no teleport)")
        } else {
            healthManager.pendingAbilitySelection = false
            self.playScaredSpinDropAndGameOver(reason: .splash)
        }
    }
    
    private func handleMissedLanding() {
        if stateManager.splashTriggered { return }
        stateManager.splashTriggered = true
        
        if frogController.suppressWaterCollisionUntilNextJump {
            print("🌊 Suppressing water collision until next jump")
            healthManager.pendingAbilitySelection = false
            return
        }
        
        print("🔍 handleMissedLanding - waterState: \(stateManager.waterState)")
        
        // Check water state to determine behavior
        switch stateManager.waterState {
        case .ice:
            print("🧊 Routing to ice landing")
            handleIceLanding()
        case .water:
            print("💧 Routing to water splash")
            handleWaterSplash()
        }
    }
    
    private func handleWaterSplash() {
        frogController.splash()
        facingDirectionController.clearLockedFacing()
        HapticFeedbackManager.shared.notification(.error)
        effectsManager?.createSplashEffect(at: frogContainer.position)
        
        if frogController.inWater {
            if frogController.lifeVestCharges > 0 {
                frogController.lifeVestCharges -= 1
                updateHUD()
                stateManager.cancelPendingGameOver()
                healthManager.pendingAbilitySelection = false
                frogController.suppressWaterCollisionUntilNextJump = true
                stateManager.splashTriggered = false
                showFloatingText("Life Vest -1", color: .systemYellow)
                
                // CRITICAL FIX: After life vest rescue, try to find a nearby lily pad
                // Removed the search and landing code, replaced with stays in water:
                // Life vest water rescue: keep frog floating; do not move position or land on a pad
                frogController.inWater = true
                frogController.isGrounded = false
                frogController.isJumping = false
                print("🦎 Life vest water rescue: Keeping frog at splash position (no teleport)")
            } else {
                healthManager.pendingAbilitySelection = false
                self.playScaredSpinDropAndGameOver(reason: .splash)
            }
        } else {
            healthManager.pendingAbilitySelection = false
            self.playScaredSpinDropAndGameOver(reason: .splash)
        }
    }
    
    private func handleIceLanding() {
        print("🧊 handleIceLanding CALLED")
        
        // Reset splash trigger since ice doesn't cause drowning
        stateManager.splashTriggered = false
        
        // Return to idle pose on land - use the frog controller's methods
        frogController.setToIdlePose()
        
        // Start sliding on ice with velocity based on slingshot pull intensity
        let pullIntensity = self.slingshotController.lastPullIntensity
        let baseSlideSpeed: CGFloat = 15.0 // Base sliding speed
        let slideSpeed = pullIntensity * baseSlideSpeed
        
        // Use the frog's current velocity direction, but scale by pull intensity
        let currentVel = frogController.velocity
        let velMagnitude = sqrt(currentVel.dx * currentVel.dx + currentVel.dy * currentVel.dy)
        
        let slideVelocity: CGVector
        if velMagnitude > 0 {
            // Normalize current velocity and scale by slide speed
            let normalizedVel = CGVector(dx: currentVel.dx / velMagnitude, dy: currentVel.dy / velMagnitude)
            slideVelocity = CGVector(dx: normalizedVel.dx * slideSpeed, dy: normalizedVel.dy * slideSpeed)
        } else {
            // Fallback: slide forward with pull intensity
            slideVelocity = CGVector(dx: 0, dy: slideSpeed)
        }
        
        frogController.startSlidingOnIce(initialVelocity: slideVelocity)
        facingDirectionController.clearLockedFacing()
        
        // Create ice crack effect instead of splash
        effectsManager?.createIceEffect(at: frogController.position)
        
        // Play ice sounds
        SoundController.shared.playIceCrack()
        
        // Light haptic feedback for ice landing
        HapticFeedbackManager.shared.impact(.light)
        
        
        
    }
    
    private func triggerSplashOnce(gameOverDelay: TimeInterval) {
        if stateManager.splashTriggered { return }
        stateManager.splashTriggered = true
        
        frogController.splash()
        facingDirectionController.clearLockedFacing()
        HapticFeedbackManager.shared.notification(.error)
        effectsManager?.createSplashEffect(at: frogContainer.position)
        
        healthManager.pendingAbilitySelection = false
        self.playScaredSpinDropAndGameOver(reason: .splash)
    }
    
    // MARK: - Lily Pad Creation (for special cases only)
    private func makeLilyPad(position: CGPoint, radius: CGFloat) -> LilyPad {
        // For start pad and rescue pad, always create normal pads
        return LilyPad(position: position, radius: radius, type: .normal)
    }
    
    // MARK: - UI Helpers
    private func showFloatingScore(_ text: String, color: UIColor) {
        let label = SKLabelNode(text: text)
        label.fontName = "ArialRoundedMTBold"
        label.fontSize = 22
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(
            x: frogContainer.position.x + CGFloat.random(in: -20...20),
            y: frogContainer.position.y + CGFloat.random(in: 20...40)
        )
        label.zPosition = 999
        addChild(label)
        
        let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.8)
        let scale = SKAction.scale(to: 1.2, duration: 0.8)
        label.run(SKAction.sequence([
            SKAction.group([rise, fade, scale]),
            SKAction.removeFromParent()
        ]))
    }
    
    private func showLevelIndicator() {
        // Create a small level indicator in the top-left corner
        let levelLabel = SKLabelNode(text: "Level \(currentLevel)")
        levelLabel.fontName = "ArialRoundedMT"
        levelLabel.fontSize = 18
        levelLabel.fontColor = .white
        levelLabel.position = CGPoint(x: 50, y: size.height - 50)
        levelLabel.zPosition = 1001
        levelLabel.name = "levelIndicator"
        
        // Remove any existing level indicator
        childNode(withName: "levelIndicator")?.removeFromParent()
        
        addChild(levelLabel)
    }
    
    // MARK: - Finish Line Management
    
    private func spawnFinishLine() {
        hasSpawnedFinishLine = true
        
        print("🏁 Spawning finish line - current frog position: (\(Int(frogController.position.x)), \(Int(frogController.position.y)))")
        
        // Find the highest lily pad that's still accessible to the frog
        var bestPads: [LilyPad] = []
        let searchRange = frogController.position.y + 200 ... frogController.position.y + 600
        
        for pad in lilyPads {
            if searchRange.contains(pad.position.y) {
                bestPads.append(pad)
            }
        }
        
        print("🏁 Found \(bestPads.count) lily pads in range \(Int(searchRange.lowerBound))...\(Int(searchRange.upperBound))")
        
        // Sort by distance from frog and pick a good candidate
        bestPads.sort { pad1, pad2 in
            let dist1 = abs(pad1.position.y - (frogController.position.y + 400))
            let dist2 = abs(pad2.position.y - (frogController.position.y + 400))
            return dist1 < dist2
        }
        
        // Position the finish line
        let finishLineY: CGFloat
        let finishLineX: CGFloat
        
        if let bestPad = bestPads.first {
            // Place finish line above the lily pad
            finishLineY = bestPad.position.y + 80
            finishLineX = bestPad.position.x
            print("🏁 Placing finish line near lily pad at (\(Int(bestPad.position.x)), \(Int(bestPad.position.y)))")
        } else {
            // Default position if no suitable lily pad is found
            finishLineY = frogController.position.y + 400
            finishLineX = frogController.position.x
            print("🏁 No suitable lily pad found, placing finish line at default position")
        }
        
        let finishLinePosition = CGPoint(x: finishLineX, y: finishLineY)
        
        // Create the finish line
        finishLine = FinishLine(
            position: finishLinePosition,
            width: GameConfig.finishLineWidth
        )
        
        // Set up crossing callback (this is redundant with the checkCrossing method but kept for safety)
        finishLine?.onCrossed = { [weak self] in
            print("🏁 onCrossed callback triggered!")
            self?.handleFinishLineCrossed()
        }
        
        // Add to world node so it moves with the world
        if let finishLineNode = finishLine?.node {
            worldManager.worldNode.addChild(finishLineNode)
            print("🏁 Finish line node added to world at position: \(finishLinePosition)")
        } else {
            print("🚨 ERROR: Failed to create finish line node!")
        }
        
        // Show a message to the player
        showFloatingScore("🏁 FINISH LINE!", color: .systemGreen)
        
        // Play a special sound (if available)
        soundController.playCollectSound()
        
        print("🏁 Finish line spawned successfully!")
        print("🏁 Final position: (\(Int(finishLinePosition.x)), \(Int(finishLinePosition.y)))")
        print("🏁 Distance from frog: \(Int(finishLinePosition.y - frogController.position.y)) units")
    }
    
    private func handleFinishLineCrossed() {
        // CRITICAL: Prevent multiple triggers of finish line crossing
        guard let finishLine = finishLine else {
            print("🚨 handleFinishLineCrossed called but no finish line exists!")
            return
        }
        
        print("🏁 Frog crossed the finish line! Level \(currentLevel) complete!")
        print("🏁 Current score: \(score)")
        
        // Calculate and award time bonus
        let timeBonus = calculateTimeBonus()
        if timeBonus > 0 {
            scoreManager.addScore(timeBonus)
            showFloatingScore("+\(timeBonus) TIME BONUS", color: .cyan)
        }
        
        // Stop the level timer
        stopLevelTimer()
        
        // IMMEDIATELY remove the finish line to prevent multiple triggers
        finishLine.node.removeFromParent()
        self.finishLine = nil
        hasSpawnedFinishLine = true // Keep this true until we start the next level
        
        // Complete level in ScoreManager (this handles level progression and bonus scoring)
        scoreManager.completeLevel()
        
        // Show completion message and updated score
        showFloatingScore("LEVEL COMPLETE!", color: .systemGreen)
        showFloatingScore("+\(GameConfig.levelCompletionBonus) BONUS", color: .systemYellow)
        
        // Play completion sound
        soundController.playCollectSound()
        
        // Heavy haptic feedback
        HapticFeedbackManager.shared.impact(.heavy)
        
        // Transition to next level after a short delay
        let delay = SKAction.wait(forDuration: 0.5)
        let nextLevel = SKAction.run { [weak self] in
            print("🏁 About to start next level from Level \(self?.scoreManager.getCurrentLevel() ?? -1)")
            self?.startNextLevel()
        }
        run(SKAction.sequence([delay, nextLevel]), withKey: "levelTransition")
    }
    
    private func startNextLevel() {
        print("🎮 Starting next level...")
        
       
        
        let oldLevel = currentLevel
        
        // Get current level from ScoreManager (it was already incremented in completeLevel())
        currentLevel = scoreManager.getCurrentLevel()
        baseSpawnRateMultiplier = 1.0 + (CGFloat(currentLevel - 1) * 0.1)
        
        print("🎯 Advanced from Level \(oldLevel) to Level \(currentLevel)")
        print("📈 Enemy spawn rate multiplier: \(String(format: "%.1f", baseSpawnRateMultiplier))x (base + \(String(format: "%.0f", (baseSpawnRateMultiplier - 1.0) * 100))%)")
        
        // Remove finish line
        finishLine?.node.removeFromParent()
        finishLine = nil
        hasSpawnedFinishLine = false
        
        // Cancel any pending level transitions
        removeAction(forKey: "levelTransition")
        
        // Remove any existing level labels to prevent overlap
        enumerateChildNodes(withName: "levelLabel") { node, _ in
            node.removeFromParent()
        }
        enumerateChildNodes(withName: "difficultyLabel") { node, _ in
            node.removeFromParent()
        }
        
        // Show level advancement message
        let levelLabel = SKLabelNode(text: "LEVEL \(currentLevel)")
        levelLabel.fontName = "ArialRoundedMTBold"
        levelLabel.fontSize = 48
        levelLabel.fontColor = .systemYellow
        levelLabel.position = CGPoint(x: size.width/2, y: size.height/2 + 30 + 100)
        levelLabel.zPosition = 1000
        levelLabel.name = "levelLabel" // Add name for easy removal
        addChild(levelLabel)
        
        // Show difficulty increase subtitle
        let difficultyLabel = SKLabelNode(text: "Enemy spawn rate +10%")
        difficultyLabel.fontName = "ArialRoundedMTBold"
        difficultyLabel.fontSize = 24
        difficultyLabel.fontColor = .systemOrange
        difficultyLabel.position = CGPoint(x: size.width/2, y: size.height/2 - 20 + 70)
        difficultyLabel.zPosition = 1000
        difficultyLabel.name = "difficultyLabel" // Add name for easy removal
        addChild(difficultyLabel)
        
        // Animate the level labels
        for label in [levelLabel, difficultyLabel] {
            label.setScale(0)
            let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
            let scaleNormal = SKAction.scale(to: 1.0, duration: 0.2)
            let wait = SKAction.wait(forDuration: 1.5)
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            
            label.run(SKAction.sequence([
                scaleUp, scaleNormal, wait, fadeOut, remove
            ]))
        }
        
        // Update spawn manager with new level's spawn rate multiplier
        spawnManager.updateSpawnRateMultiplier(baseSpawnRateMultiplier)
        
        // Update the level indicator in the corner
        showLevelIndicator()
        
        // Continue playing without resetting the game completely
        // Just reset necessary game objects while preserving level progression
        continueLevelProgression()
    }
    
    // MARK: - Level Progression Helper
    private func continueLevelProgression() {
        print("🎮 Continuing level progression...")
        print("🧹 Starting comprehensive cleanup for Level \(currentLevel)...")
        
        // STEP 1: Complete visual cleanup - remove all existing nodes from world
        print("🧹 Removing all existing world nodes...")
        for enemy in enemies {
            enemy.node.removeFromParent()
        }
        for tadpole in tadpoles {
            tadpole.node.removeFromParent()
        }
        for lilyPad in lilyPads {
            lilyPad.node.removeFromParent()
        }
        
        // STEP 2: Clear game object arrays
        print("🧹 Clearing object arrays...")
        enemies.removeAll()
        tadpoles.removeAll()
        lilyPads.removeAll()
        
        // STEP 3: Clear spatial grid after clearing lily pads array
        print("🧹 Clearing spatial grid...")
        spawnManager.clearSpatialGrid()
        
        // STEP 4: Reset world manager completely
        print("🧹 Resetting world manager...")
        worldManager.reset()
        
        // STEP 5: Reset all level-specific state
        print("🧹 Resetting level state...")
        hasSpawnedFinishLine = false
        frogPreviousY = 0
        isRocketFinalApproach = false
        
        // STEP 6: Reset spawn manager state for new level
        print("🧹 Resetting spawn manager state...")
        spawnManager.reset(for: &lilyPads, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots)
        
        // STEP 7: Reset frog state for new level
        print("🐸 Resetting frog state for new level...")
        frogController.superJumpActive = false
        frogController.rocketActive = false
        frogController.invincible = false
        frogController.inWater = false
        frogController.onIce = false
        frogController.isJumping = false
        frogController.suppressWaterCollisionUntilNextJump = false
        frogController.velocity = .zero
        frogController.slideVelocity = .zero
        
        // Hide all ability indicators
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        uiManager.hideRocketLandButton()
        
        // STEP 8: Create fresh starting pad at current position
        print("🪷 Creating new starting pad...")
        let startWorldPos = CGPoint(x: size.width / 2, y: frogController.position.y)
        let startPad = makeLilyPad(position: startWorldPos, radius: 60)
        startPad.node.position = startPad.position
        startPad.node.zPosition = 10
        worldManager.worldNode.addChild(startPad.node)
        lilyPads.append(startPad)
        
        // STEP 9: Add starting pad to spatial grid
        spawnManager.addToSpatialGrid(startPad)
        print("🪷 Starting pad added to spatial grid at: \(startWorldPos)")
        
        // STEP 10: Land frog on the new starting pad
        frogController.landOnPad(startPad)
        frogController.isGrounded = true
        print("🐸 Frog landed on new starting pad")
        
        // STEP 11: Spawn fresh initial objects for the new level
        print("🎯 Spawning initial objects for Level \(currentLevel)...")
        spawnManager.spawnInitialObjects(
            sceneSize: size,
            lilyPads: &lilyPads,
            enemies: &enemies,
            tadpoles: &tadpoles,
            bigHoneyPots: &bigHoneyPots,
            worldOffset: worldManager.worldNode.position.y
        )
        
        // STEP 12: Resume spawning with new level parameters
        spawnManager.resumeSpawningAfterAbilitySelection()
        print("🎯 Spawning resumed with \(String(format: "%.1f", baseSpawnRateMultiplier))x rate multiplier")
        
        // STEP 13: Start timer for new level
        startLevelTimer()
        
        // STEP 13.5: Advance the finish line for the next level
        spawnManager.advanceToNextLevel(currentScore: score)

        // STEP 14: Show initial upgrade selection for new level
        gameState = .initialUpgradeSelection
        uiManager.showInitialUpgradeSelection(sceneSize: size)
        
        print("✅ Level \(currentLevel) progression complete!")
        print("📊 Final state: \(lilyPads.count) lily pads, \(enemies.count) enemies, \(tadpoles.count) tadpoles")
        
        // Verify cleanup was successful
        let cleanupSuccessful = verifyLevelCleanup()
        if !cleanupSuccessful {
            print("🚨 WARNING: Level cleanup verification failed!")
        }
    }
    
    private func showFloatingText(_ text: String, color: UIColor) {
        let label = SKLabelNode(text: text)
        label.fontName = "ArialRoundedMTBold"
        label.fontSize = 24
        label.fontColor = color
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
    }
    
    // MARK: - Recovery Helpers
    private func findNearbyLilyPad() -> LilyPad? {
        let frogPos = frogController.position
        let maxDistance: CGFloat = 100 // Search within 100 units
        
        return lilyPads.first { pad in
            let dx = frogPos.x - pad.position.x
            let dy = frogPos.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            return distance <= maxDistance
        }
    }
    
    private func attemptStateRecovery() -> Bool {
        // Only attempt recovery if frog is not jumping and not in rocket mode
        guard !frogController.isJumping && !frogController.rocketActive else {
            return false
        }
        
        print("⚠️ Attempting state recovery - checking for nearby lily pad")
        
        if let nearbyPad = findNearbyLilyPad() {
            print("✅ Recovery: Found nearby lily pad, setting grounded state")
            frogController.landOnPad(nearbyPad)
            return true
        } else {
            print("❌ Recovery: No nearby lily pad found")
            return false
        }
    }
    
    private func debugFrogState() {
        print("🐸 DEBUG - Frog State:")
        print("  - isGrounded: \(frogController.isGrounded)")
        print("  - isJumping: \(frogController.isJumping)")
        print("  - inWater: \(frogController.inWater)")
        print("  - onIce: \(frogController.onIce)")
        print("  - slideVelocity: \(frogController.slideVelocity)")
        print("  - rocketActive: \(frogController.rocketActive)")
        print("  - currentLilyPad: \(frogController.currentLilyPad != nil ? "YES" : "NO")")
        print("  - inputLocked: \(stateManager.inputLocked)")
        print("  - waterState: \(stateManager.waterState)")
        print("  - gameState: \(gameState)")
        print("  - pendingAbilitySelection: \(healthManager.pendingAbilitySelection)")
    }
    
    // MARK: - Debug Methods
    
    // Debug function specifically for slingshot input blocking
    func debugSlingshotBlocking() {
        print("🔍 SLINGSHOT DEBUG:")
        print("  - gameState: \(gameState)")
        print("  - inputLocked: \(stateManager.inputLocked)")
        print("  - pendingAbilitySelection: \(healthManager.pendingAbilitySelection)")
        print("  - isGrounded: \(frogController.isGrounded)")
        print("  - isJumping: \(frogController.isJumping)")
        print("  - inWater: \(frogController.inWater)")
        print("  - onIce: \(frogController.onIce)")
        print("  - rocketActive: \(frogController.rocketActive)")
        print("  - currentLilyPad: \(frogController.currentLilyPad != nil ? "YES" : "NO")")
        print("  - canAcceptSlingshotInput: \(canAcceptSlingshotInput())")
        print("  - currentLevel: \(currentLevel)")
        print("  - spawnRateMultiplier: \(String(format: "%.2f", baseSpawnRateMultiplier))x")
        
        // Additional detailed checks
        if gameState != .playing {
            print("  ❌ BLOCKED: Game not in playing state")
        }
        if stateManager.inputLocked {
            print("  ❌ BLOCKED: Input is locked")
        }
        if healthManager.pendingAbilitySelection {
            print("  ❌ BLOCKED: Ability selection pending")
            
            // SAFETY CHECK: If we've been pending for too long and game state is normal, force clear it
            if gameState == .playing && frogController.isGrounded && !frogController.isJumping {
                print("  🚨 SAFETY: Clearing stuck pendingAbilitySelection")
                healthManager.forceClearAbilitySelection(reason: "stuck detection in debug")
            }
        }
        if frogController.rocketActive {
            print("  ❌ BLOCKED: Rocket is active")
        }
        if !frogController.isGrounded && !frogController.inWater && !frogController.onIce {
            print("  ❌ BLOCKED: Frog not grounded/inWater/onIce")
        }
        if canAcceptSlingshotInput() {
            print("  ✅ Slingshot input should be ALLOWED")
        } else {
            print("  ❌ Slingshot input is BLOCKED")
        }
    }
    
    // MARK: - Input Validation Helpers
    private func canAcceptSlingshotInput() -> Bool {
        return frogController.isGrounded || frogController.inWater || frogController.onIce
    }
    
    private func debugWaterStateAndTouch() {
        print("🔍 WATER STATE DEBUG:")
        print("  - waterState: \(stateManager.waterState)")
        print("  - isGrounded: \(frogController.isGrounded)")
        print("  - isJumping: \(frogController.isJumping)")
        print("  - inWater: \(frogController.inWater)")
        print("  - onIce: \(frogController.onIce)")
        print("  - slideVelocity: \(frogController.slideVelocity)")
        print("  - canAcceptInput: \(canAcceptSlingshotInput())")
    }
    
    // Manual recovery function for testing/debugging
    func manualRecovery() {
        debugFrogState()
        debugSlingshotBlocking()  // Also call the new debug function
        stateManager.forceUnlockInput()
        
        // Clear stuck ability selection state
        if healthManager.pendingAbilitySelection {
            print("🚨 Manual recovery: Clearing stuck pendingAbilitySelection")
            healthManager.forceClearAbilitySelection(reason: "manual recovery")
        }
        
        if attemptStateRecovery() {
            print("✅ Manual recovery successful")
        } else {
            print("❌ Manual recovery failed")
        }
    }
    
    // MARK: - Ice Testing Methods
    func testIceMode() {
        print("🧊 TESTING ICE MODE")
        stateManager.createIceLevel()
        debugWaterStateAndTouch()
    }
    
    func forceIceSliding() {
        print("🧊 FORCING ICE SLIDING")
        let testVelocity = CGVector(dx: 5.0, dy: 2.0)
        frogController.startSlidingOnIce(initialVelocity: testVelocity)
        debugWaterStateAndTouch()
    }
    
    // Call this method to test ice sliding directly
    func quickIceTest() {
        print("🧊 QUICK ICE TEST")
        stateManager.setWaterState(.ice)
        print("🧊 Water state set to ice: \(stateManager.waterState)")
        
        // Force the frog into a sliding state
        let slideVelocity = CGVector(dx: 4.0, dy: -2.0)
        frogController.startSlidingOnIce(initialVelocity: slideVelocity)
        
        print("🧊 Frog should now be sliding - onIce: \(frogController.onIce)")
        print("🧊 Slide velocity: \(frogController.slideVelocity)")
    }
    
    // Check and fix stuck ability selection
    func checkAndFixAbilitySelection() {
        print("🔧 ABILITY SELECTION CHECK:")
        print("  - pendingAbilitySelection: \(healthManager.pendingAbilitySelection)")
        print("  - gameState: \(gameState)")
        print("  - isGrounded: \(frogController.isGrounded)")
        print("  - isJumping: \(frogController.isJumping)")
        print("  - spawningPaused: \(spawnManager.isSpawningPaused)")  // Fixed property access
        
        if healthManager.pendingAbilitySelection && gameState == .playing && 
           frogController.isGrounded && !frogController.isJumping {
            print("🚨 FIXING: Clearing stuck pendingAbilitySelection")
            healthManager.forceClearAbilitySelection(reason: "manual check and fix")
        } else {
            print("✅ Ability selection state looks normal")
        }
    }
    
    // Test method to check current ice/spawn state
    func debugIceSpawnState() {
        print("🧊 ICE SPAWN STATE DEBUG:")
        print("  - waterState: \(stateManager.waterState)")
        print("  - frog onIce: \(frogController.onIce)")
        print("  - slide velocity: \(frogController.slideVelocity)")
        print("  - frog position: \(frogController.position)")
        print("  - lily pads ahead count: \(lilyPads.filter { $0.position.y > frogController.position.y }.count)")
    }
    
    // MARK: - Level Testing Methods
    
    /// Verify level cleanup was successful
    func verifyLevelCleanup() -> Bool {
        print("🔍 LEVEL CLEANUP VERIFICATION:")
        
        var allClear = true
        
        // Check arrays are empty
        if !enemies.isEmpty {
            print("  ❌ Enemies array not empty: \(enemies.count) remaining")
            allClear = false
        }
        if !tadpoles.isEmpty {
            print("  ❌ Tadpoles array not empty: \(tadpoles.count) remaining")
            allClear = false
        }
        if !lilyPads.isEmpty {
            print("  ❌ LilyPads array not empty: \(lilyPads.count) remaining")
            allClear = false
        }
        
        // Check world node has no orphaned children
        let worldChildren = worldManager.worldNode.children
        let enemyNodes = worldChildren.filter { $0.name?.contains("enemy") == true || $0.name?.contains("log") == true || $0.name?.contains("bee") == true }
        let tadpoleNodes = worldChildren.filter { $0.name?.contains("tadpole") == true }
        let padNodes = worldChildren.filter { $0.name?.contains("lilypad") == true || $0.name?.contains("pad") == true }
        
        if !enemyNodes.isEmpty {
            print("  ❌ Orphaned enemy nodes in world: \(enemyNodes.count)")
            allClear = false
        }
        if !tadpoleNodes.isEmpty {
            print("  ❌ Orphaned tadpole nodes in world: \(tadpoleNodes.count)")
            allClear = false
        }
        if padNodes.count > 1 { // Allow 1 for the starting pad
            print("  ❌ Too many lily pad nodes in world: \(padNodes.count) (expected 1 starting pad)")
            allClear = false
        }
        
        // Check finish line state
        if finishLine != nil {
            print("  ❌ Finish line not cleared")
            allClear = false
        }
        if hasSpawnedFinishLine && currentLevel > 1 {
            print("  ❌ hasSpawnedFinishLine not reset for new level")
            allClear = false
        }
        
        if allClear {
            print("  ✅ Level cleanup verification PASSED")
        } else {
            print("  ❌ Level cleanup verification FAILED")
        }
        
        return allClear
    }
    
    /// Force cleanup all game objects (emergency method)
    func forceCompleteCleanup() {
        print("🚨 FORCE CLEANUP: Removing ALL game objects")
        
        // Remove all nodes from world that might be game objects
        let worldChildren = worldManager.worldNode.children
        for child in worldChildren {
            if let name = child.name,
               name.contains("enemy") || name.contains("log") || name.contains("bee") || 
               name.contains("snake") || name.contains("dragonfly") || name.contains("bush") ||
               name.contains("tadpole") || name.contains("lilypad") || name.contains("pad") ||
               name.contains("finish") {
                child.removeFromParent()
                print("  🗑️ Removed orphaned node: \(name)")
            }
        }
        
        // Clear all arrays
        enemies.removeAll()
        tadpoles.removeAll()
        lilyPads.removeAll()
        
        // Clear spatial grid
        spawnManager.clearSpatialGrid()
        
        // Reset finish line
        finishLine?.node.removeFromParent()
        finishLine = nil
        hasSpawnedFinishLine = false
        
        print("🚨 Force cleanup complete")
    }
    
    /// Test method to manually advance to next level (for debugging)
    func testAdvanceLevel() {
        print("🧪 TESTING: Manually advancing to next level")
        handleFinishLineCrossed()
    }
    
    /// Test method to manually spawn finish line (for debugging)
    func testSpawnFinishLine() {
        print("🧪 TESTING: Manually spawning finish line")
        spawnFinishLine()
    }
    
    /// Debug finish line state
    func debugFinishLineState() {
        print("🏁 FINISH LINE DEBUG:")
        print("   - Score: \(score)")
        print("   - Current Level: \(currentLevel)")
        print("   - Threshold: \(currentLevel * 25000)")
        print("   - Has spawned: \(hasSpawnedFinishLine)")
        print("   - Finish line exists: \(finishLine != nil)")
        print("   - Frog position Y: \(Int(frogController.position.y))")
        print("   - Previous frog Y: \(Int(frogPreviousY))")
        
        if let finishLine = finishLine {
            print("   - Finish line Y: \(Int(finishLine.position.y))")
            print("   - Finish line X: \(Int(finishLine.position.x))")
            print("   - Distance to finish: \(Int(finishLine.position.y - frogController.position.y))")
        }
        
        if let levelTransitionAction = action(forKey: "levelTransition") {
            print("   - Level transition in progress: YES")
        } else {
            print("   - Level transition in progress: NO")
        }
    }
    
    /// Test method to get current level info
    func debugLevelInfo() {
        print("🎯 LEVEL INFO:")
        print("  - Current Level: \(currentLevel)")
        print("  - Base Spawn Rate Multiplier: \(String(format: "%.2f", baseSpawnRateMultiplier))x")
        print("  - Increase from Level 1: +\(String(format: "%.0f", (baseSpawnRateMultiplier - 1.0) * 100))%")
        print("  - SpawnManager Multiplier: \(String(format: "%.2f", spawnManager.levelSpawnRateMultiplier))x")
    }
    
    // TEMPORARY: Override input validation to allow ice sliding
    private func shouldAllowSlingshotInput() -> Bool {
        let result = frogController.isGrounded || frogController.inWater || frogController.onIce
        if !result {
            print("🚫 Input blocked - isGrounded: \(frogController.isGrounded), inWater: \(frogController.inWater), onIce: \(frogController.onIce)")
        }
        return result
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Debug water state when touches begin
        if gameState == .playing {
            debugWaterStateAndTouch()
        }
        
        let nodesAtPoint = nodes(at: location)
        
        // Press feedback for UI buttons (nodes named with known button names or ability_ prefix)
        if let tapped = nodesAtPoint.first(where: { node in
            guard let name = node.name else { return false }
            return name == "playGameButton" ||
                   name == "leaderboardButton" ||
                   name == "tutorialButton" ||
                   name == "closeTutorialButton" ||
                   name == "pauseButton" ||
                   name == "continueButton" ||
                   name == "resumeButton" ||
                   name == "quitButton" ||
                   name == "quitToMenuButton" ||
                   name == "tryAgainButton" ||
                   name == "restartButton" ||
                   name == "backToMenuButton" ||
                   name == "rocketLandButton" ||
                   name.hasPrefix("ability_")
        }) {
            // Animate press on the button's root node (use parent if label/sprite was hit)
            let buttonRoot = tapped.name == "tapTarget" ? tapped.parent ?? tapped : tapped
            currentlyPressedButton = buttonRoot
            uiManager.handleButtonPress(node: buttonRoot)
        }
        
        // Check for UI button taps FIRST
        for node in nodesAtPoint {
            if let nodeName = node.name {
                // Main Menu Buttons
                if nodeName == "playGameButton" {
                    soundController.playSoundEffect(.buttonTap)
                    startNewGame()
                    return
                }
                if nodeName == "leaderboardButton" {
                    soundController.playSoundEffect(.buttonTap)
                    // Present Game Center leaderboard via UIManager
                    uiManager.presentLeaderboard(leaderboardID: uiManager.leaderboardID)
                    return
                }
                if nodeName == "tutorialButton" {
                    soundController.playSoundEffect(.buttonTap)
                    // Show tutorial modal via UIManager
                    uiManager.showTutorialModal(sceneSize: size)
                    return
                }
                if nodeName == "closeTutorialButton" {
                    soundController.playSoundEffect(.buttonTap)
                    // Close tutorial modal via UIManager
                    uiManager.hideTutorialModal()
                    return
                }
                if nodeName == "profileButton" || nodeName == "settingsButton" || nodeName == "audioButton" {
                    soundController.playSoundEffect(.buttonTap)
                    // Placeholder for future navigation
                    print("Tapped \(nodeName), navigating...")
                    return
                }
                if nodeName == "exitButton" || nodeName == "backToMenuButton" {
                    soundController.playSoundEffect(.buttonTap)
                    showMainMenu()
                    return
                }
                if nodeName == "tryAgainButton" || nodeName == "restartButton" {
                    soundController.playSoundEffect(.buttonTap)
                    startNewGame()
                    return
                }
                
                // Ability selection buttons
                if nodeName.contains("ability") {
                    soundController.playSoundEffect(.buttonTap)
                    print("🎯 Ability button tapped: \(nodeName)")
                    selectAbility(nodeName)
                    return
                }
                
                // Initial upgrade selection buttons
                if nodeName.hasPrefix("initialUpgrade_") {
                    soundController.playSoundEffect(.buttonTap)
                    handleInitialUpgradeSelection(nodeName)
                    return
                }
                // Pause button handler
                           if nodeName == "pauseButton" {
                               soundController.playSoundEffect(.buttonTap)
                               gameState = .paused
                               uiManager.showPauseMenu(sceneSize: size)
                               return
                           }
                // Pause menu buttons
                           if nodeName == "continueButton" || nodeName == "resumeButton" {
                               soundController.playSoundEffect(.buttonTap)
                               gameState = .playing
                               uiManager.hideMenus()
                               return
                           }
                           
                           if nodeName == "quitButton" || nodeName == "quitToMenuButton" {
                               soundController.playSoundEffect(.buttonTap)
                               showMainMenu()
                               return
                           }
                
                // Rocket land button handler
                if nodeName == "rocketLandButton" {
                    soundController.playSoundEffect(.buttonTap)
                    handleRocketLandButtonTap()
                    return
                }
            }
        }
        
        // Only check gameplay touches if we're in playing state
        guard gameState == .playing else {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: gameState=\(gameState)")
            return
        }
        
        // Rocket steering
        if frogController.rocketActive {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch routed to rocket steering")
            let screenCenter = size.width / 2
            if location.x > screenCenter + 40 {
                touchInputController.applyTapNudge(isRightSide: true, sceneWidth: size.width)
            } else if location.x < screenCenter - 40 {
                touchInputController.applyTapNudge(isRightSide: false, sceneWidth: size.width)
            }
            _ = touchInputController.handleTouchBegan(touch, in: self.view, sceneSize: size, rocketActive: frogController.rocketActive)
            return
        }
        
        if stateManager.inputLocked {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: inputLocked")
            return
        }
        
        if healthManager.pendingAbilitySelection {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: ability selection pending")
            return
        }
        
        if !(frogController.isGrounded || frogController.inWater) {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: not grounded/inWater (isGrounded=\(frogController.isGrounded), isJumping=\(frogController.isJumping))")
            return
        }
        
        // Slingshot handling - only if grounded or in water
        print("🎯 Slingshot touch began at: \(location)")
        let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
        slingshotController.handleTouchBegan(at: location, frogScreenPosition: frogScreenPoint)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // If finger moves significantly, cancel press state
        if let pressed = currentlyPressedButton {
            let pressedFrame = pressed.calculateAccumulatedFrame()
            if !pressedFrame.insetBy(dx: -20, dy: -20).contains(location) {
                uiManager.handleButtonRelease(node: pressed)
                currentlyPressedButton = nil
            }
        }
        
        guard gameState == .playing else {
            return
        }
        
        if stateManager.inputLocked {
            return
        }
        
        if healthManager.pendingAbilitySelection {
            return
        }
        
        if frogController.rocketActive {
            return
        }
        
        if !(frogController.isGrounded || frogController.inWater) {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: not grounded/inWater (isGrounded=\(frogController.isGrounded), isJumping=\(frogController.isJumping))")
            return
        }
        
        let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
        slingshotController.handleTouchMoved(to: location)
        // ADD THIS: Draw the slingshot visuals
              slingshotController.drawSlingshot(
                  frogScreenPosition: frogScreenPoint,
                  frogWorldPosition: frogController.position,
                  superJumpActive: frogController.superJumpActive,
                  lilyPads: lilyPads,
                  worldNode: worldManager.worldNode,
                  scene: self,
                  worldOffset: worldManager.worldNode.position.y
              )
        updateFacingFromAiming(location: location)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Release visual for any pressed button
        if let pressed = currentlyPressedButton {
            uiManager.handleButtonRelease(node: pressed)
            currentlyPressedButton = nil
        }
        
        if gameState == .playing && frogController.rocketActive {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch routed to rocket steering")
            _ = touchInputController.handleTouchEnded(touch, in: self.view, sceneSize: size, rocketActive: frogController.rocketActive, hudBarHeight: hudBarHeight)
            return
        }
        
        guard gameState == .playing else {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: gameState=\(gameState)")
            return
        }
        
        if stateManager.inputLocked {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: inputLocked")
            return
        }
        
        if healthManager.pendingAbilitySelection {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: ability selection pending")
            return
        }
        
        if !(frogController.isGrounded || frogController.inWater) {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: not grounded/inWater (isGrounded=\(frogController.isGrounded), isJumping=\(frogController.isJumping))")
            return
        }
        
        if frogController.isGrounded || frogController.inWater {
            let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
            
            if let targetWorldPos = slingshotController.handleTouchEnded(
                at: location,
                frogScreenPosition: frogScreenPoint,
                frogWorldPosition: frogController.position,
                worldOffset: worldManager.worldNode.position.y,
                superJumpActive: frogController.superJumpActive
            ) {
                print("ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â¸ Jumping to: \(targetWorldPos)")
                frogController.startJump(to: targetWorldPos)
                facingDirectionController?.lockCurrentFacing()
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let pressed = currentlyPressedButton {
            uiManager.handleButtonRelease(node: pressed)
            currentlyPressedButton = nil
        }
        
        // IMPORTANT: Cancel any active slingshot aiming when touches are cancelled
        if slingshotController.slingshotActive {
            print("🎯 Touch cancelled - canceling slingshot aiming")
            slingshotController.cancelCurrentAiming()
        }
    }
    
    private func updateFacingFromAiming(location: CGPoint) {
        if canAcceptSlingshotInput() {
            let start = convert(frogController.position, from: worldManager.worldNode)
            let pull = CGPoint(x: location.x - start.x, y: location.y - start.y)
            if pull.x != 0 || pull.y != 0 {
                facingDirectionController.setFacingFromPull(pullDirection: pull)
            }
        }
    }
    
    // MARK: - Game Over Animation Helper
    private func playScaredSpinDropAndGameOver(reason: GameOverReason) {
        // Prevent duplicate triggers
        guard gameState == .playing else {
            gameOver(reason)
            return
        }

        stateManager.lockInput(for: 0.5)  // Reduced from 2.0 to 0.5 seconds to prevent extended input loss
        frogController.showScared(duration: 2.0)

        frogController.frog.removeAllActions()
        frogController.frogShadow.removeAllActions()
        frogContainer.removeAllActions()

        frogContainer.zPosition = max(frogContainer.zPosition, 500)

        let spin = SKAction.rotate(byAngle: .pi * 2.0, duration: 0.5)
        spin.timingMode = .easeInEaseOut
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.2)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        scaleDown.timingMode = .easeIn
        let wobble = SKAction.sequence([scaleUp, scaleDown])

        let dropTarget = CGPoint(x: frogContainer.position.x, y: -size.height * 0.4)
        let drop = SKAction.move(to: dropTarget, duration: 0.6)
        drop.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: 0.5)
        let groupSpinWobble = SKAction.group([spin, wobble])

        HapticFeedbackManager.shared.notification(.error)

        let sequence = SKAction.sequence([
            groupSpinWobble,
            SKAction.group([drop, fade])
        ])

        frogContainer.run(sequence) { [weak self] in
            guard let self = self else { return }
            self.frogController.frog.alpha = 1.0
            self.frogController.frogShadow.alpha = 0.0
            self.gameOver(reason)
        }
    }
}

