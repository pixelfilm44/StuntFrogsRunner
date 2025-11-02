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
    private var healthManager: HealthManager!
    private var scoreManager: ScoreManager!
    private var stateManager: GameStateManager!
    private var visualEffectsController: VisualEffectsController!
    var hudController: HUDController!
    private var abilityManager: AbilityManager!
    private var facingDirectionController: FacingDirectionController!
    private var landingController: LandingController!
    private var touchInputController: TouchInputController!
    private var gameLoopCoordinator: GameLoopCoordinator!
    
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
    
    // MARK: - Parallax Background Elements
    private var rightTree: SKSpriteNode?
    private var leftTree: SKSpriteNode?
    
    // MARK: - Game Objects (in world space)
    var enemies: [Enemy] = []
    var tadpoles: [Tadpole] = []
    var lilyPads: [LilyPad] = []
    
    var maxHealth: Int {
        get { healthManager.maxHealth }
        set { healthManager.maxHealth = newValue }
    }

    // Tracks the currently pressed UI button node for press/release animation
    private var currentlyPressedButton: SKNode!
    
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
        scoreManager = ScoreManager()
        stateManager = GameStateManager()
        gameLoopCoordinator = GameLoopCoordinator()
        landingController = LandingController()
        touchInputController = TouchInputController()
        abilityManager = AbilityManager()
        
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
        
        // State Manager Callbacks
        stateManager.onStateChanged = { [weak self] newState, oldState in
            self?.handleStateChange(from: oldState, to: newState)
        }
        
        stateManager.onGameOver = { [weak self] reason in
            guard let self = self else { return }
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

            if self.healthManager.pendingAbilitySelection && self.gameState == .playing {
                // Keep the flag true until the UI actually appears so touches are ignored
                // and lock input during the animation window.
                self.stateManager.lockInput(for: 1.0)
                let vfx = self.visualEffectsController!
                vfx.playUpgradeCue()

                // Pause spawning and clear enemies around the landing pad immediately
                // so the scene is calm while the animation plays.
                self.spawnManager.pauseSpawningAndClearEnemies(around: pad, enemies: &self.enemies, sceneSize: self.size)

                // Delay showing the ability selection to let the animation be seen.
                let delay = SKAction.wait(forDuration: 0.9)
                self.run(delay) { [weak self] in
                    guard let self = self else { return }
                    // Ensure we are still in a valid state to present selection
                    guard self.gameState == .playing else { return }
                    // Now transition into ability selection and consume the pending flag.
                    self.healthManager.pendingAbilitySelection = false
                    self.gameState = .abilitySelection
                    self.uiManager.showAbilitySelection(sceneSize: self.size)
                }
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
            self.healthManager.healHealth()
        }
        
        abilityManager.onSuperJumpSelected = { [weak self] in
            guard let self = self else { return }
            self.frogController.activateSuperJump()
            self.uiManager.showSuperJumpIndicator(sceneSize: self.size)
        }
        
        abilityManager.onRefillHeartsSelected = { [weak self] in
            self?.healthManager.refillHealth()
        }
        
        abilityManager.onLifeVestSelected = { [weak self] in
            guard let self = self else { return }
            self.frogController.lifeVestCharges = min(6, self.frogController.lifeVestCharges + 1)
            self.updateHUD()
        }
        
        abilityManager.onScrollSaverSelected = { [weak self] in
            self?.healthManager.addScrollSaverCharge()
        }
        
        abilityManager.onFlySwatterSelected = { [weak self] in
            self?.healthManager.addFlySwatterCharge()
        }
        
        abilityManager.onHoneyJarSelected = { [weak self] in
            self?.healthManager.addHoneyJarCharge()
        }
        
        abilityManager.onAxeSelected = { [weak self] in
            self?.healthManager.addAxeCharge()
        }
        
        abilityManager.onRocketSelected = { [weak self] in
            guard let self = self else { return }
            self.frogController.activateRocket()
            self.uiManager.showRocketIndicator(sceneSize: self.size)
            
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
        uiManager.hideMenus()
        
        switch newState {
        case .menu:
            uiManager.setUIVisible(false)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 1.0, duration: 0.2))
            worldManager.worldNode.isPaused = true
        case .playing:
            uiManager.setUIVisible(true)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 0.0, duration: 0.2))
            worldManager.worldNode.isPaused = false
        case .paused, .abilitySelection, .gameOver:
          //  menuBackdrop?.run(SKAction.fadeAlpha(to: 0.9, duration: 0.2))
            worldManager.worldNode.isPaused = true
        }
    }
    
    func showMainMenu() {
        // Menu now handles its own dimming and structure. Backdrop fade is kept for consistency.
        menuBackdrop?.alpha = 1.0
        frogContainer.alpha = 1.0
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        healthManager.pendingAbilitySelection = false
        
        // Hide background tree during menu
        rightTree?.alpha = 0.0
        
        // Resume spawning if we're exiting ability selection
        spawnManager.resumeSpawningAfterAbilitySelection()
        
        // Ensure spawn state and pad tadpole flags are reset when returning to menu
        spawnManager.reset(for: &lilyPads, tadpoles: &tadpoles)
        
        gameState = .menu
        uiManager.showMainMenu(sceneSize: size)
    }
    
    // MARK: - Game Start
    func startGame() {
        print("GameScene.startGame() ENTERED")
            uiManager.hideMenus()
            print("After hideMenus()")
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        menuBackdrop?.run(SKAction.fadeOut(withDuration: 0.2))
        
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
        
        stateManager.cancelPendingGameOver()
        gameState = .playing
        stateManager.lockInput(for: 0.2)
        
        slingshotController.cancelCurrentAiming()
        
        // Reset managers
        scoreManager.resetScore()
        uiManager.highlightScore(isHighScore: false)
        healthManager.reset(startingHealth: GameConfig.startingHealth)
        visualEffectsController.stopLowHealthFlash()
        uiManager.updateStarProgress(current: 0, threshold: GameConfig.tadpolesForAbility)
        
        stateManager.splashTriggered = false
        frogController.superJumpActive = false
        uiManager.hideSuperJumpIndicator()
        frogController.rocketActive = false
        uiManager.hideRocketIndicator()
        frogController.invincible = false
        stateManager.hasLandedOnce = false
        isRocketFinalApproach = false
        
        gameLoopCoordinator.reset()
        landingController.reset()
        touchInputController.reset()
        
        frogController.lifeVestCharges = 0
        frogController.rocketFramesRemaining = 0
        frogController.suppressWaterCollisionUntilNextJump = false
        frogController.inWater = false
        
        frogContainer.zPosition = 50
        
        enemies.removeAll()
        tadpoles.removeAll()
        lilyPads.removeAll()
        
        // Reset spawn-related state and clear any lingering pad-tadpole links
        spawnManager.reset(for: &lilyPads, tadpoles: &tadpoles)
        
        worldManager.reset()
        
        // Reset background tree position
        resetBackgroundTree()
        
        // Reset scoring anchor after world reset
        lastWorldYForScore = worldManager.worldNode.position.y
        
        // Ensure spawning is resumed for new game
        spawnManager.resumeSpawningAfterAbilitySelection()
        hasInitializedScoreAnchor = true
        
        let startWorldPos = CGPoint(x: size.width / 2, y: 0)
        
        let startPad = makeLilyPad(position: startWorldPos, radius: 60)
        startPad.node.position = startPad.position
        startPad.node.zPosition = 10
        worldManager.worldNode.addChild(startPad.node)
        lilyPads.append(startPad)
        
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
            worldOffset: worldManager.worldNode.position.y
        )
        
        // Ensure spawning is resumed for new game
        spawnManager.resumeSpawningAfterAbilitySelection()
        
        updateHUD()
        
        print("ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â¸ Game started! Frog world position: \(frogController.position)")
    }
    
    // MARK: - Game Over
    func gameOver(_ reason: GameOverReason) {
        stateManager.triggerGameOver(reason)
    }
    
    // MARK: - Ability Selection
    func selectAbility(_ abilityStr: String) {
        abilityManager.selectAbility(abilityStr)
        healthManager.pendingAbilitySelection = false
        
        // Resume spawning when ability selection ends
        spawnManager.resumeSpawningAfterAbilitySelection()
        
        gameState = .playing
    }
    
    // MARK: - Update Loop
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        
        // PERFORMANCE MONITORING: Log collision stats occasionally
        if gameLoopCoordinator.getFrameCount() % 300 == 0 { // Every 5 seconds at 60fps
            let logCount = enemies.filter { $0.type == .log }.count
            let padCount = lilyPads.count
            print("🔧 Performance: \(logCount) logs, \(padCount) lily pads active")
        }
        
        // Keep background covering the screen
        if let bg = backgroundNode, let texture = bg.texture {
            if bg.parent == nil { addChild(bg) }
            let texSize = texture.size()
            let scaleX = size.width / texSize.width
            let scaleY = size.height / texSize.height
            let scale = max(scaleX, scaleY)
            let desiredSize = CGSize(width: texSize.width * scale, height: texSize.height * scale)
            if bg.size != desiredSize { bg.size = desiredSize }
            let desiredPos = CGPoint(x: size.width/2, y: size.height/2)
            if bg.position != desiredPos { bg.position = desiredPos }
        }
        
        gameLoopCoordinator.incrementFrame()
        let frameCount = gameLoopCoordinator.getFrameCount()
        
        // Debug state every 10 seconds if frog seems stuck
        if frameCount % 600 == 0 { // Every 10 seconds at 60fps
            if !frogController.isGrounded && !frogController.inWater && !frogController.isJumping && !frogController.rocketActive {
                debugFrogState()
                print("🚨 Frog appears to be in stuck state - attempting recovery")
                
                // Force unlock input if it's been locked too long
                if stateManager.inputLocked {
                    stateManager.forceUnlockInput()
                }
                
                // Try to recover the frog state
                _ = attemptStateRecovery()
            }
        }
        
        spawnManager.spawnObjects(
               sceneSize: size,
               lilyPads: &lilyPads,
               enemies: &enemies,
               tadpoles: &tadpoles,
               worldOffset: worldManager.worldNode.position.y,
               frogPosition: frogController.position,
               superJumpActive: frogController.superJumpActive
           )
        
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
        
        // Update parallax background tree for depth effect
        updateBackgroundTreeParallax()
        
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
            _ = landingController.checkLanding(
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
        
        // Update enemies with collision handling
        updateEnemies(frogScreenPoint: frogScreenPoint)
        
        // Update logs movement
        let leftWorldX = convert(CGPoint(x: -100, y: 0), to: worldManager.worldNode).x
        let rightWorldX = convert(CGPoint(x: size.width + 100, y: 0), to: worldManager.worldNode).x
        gameLoopCoordinator.updateEnemies(
            enemies: &enemies,
            lilyPads: &lilyPads,
            frogPosition: frogController.position,
            leftWorldX: leftWorldX,
            rightWorldX: rightWorldX
        )
        
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
        
        collisionManager.updateLilyPads(
            lilyPads: &lilyPads,
            worldOffset: worldManager.worldNode.position.y,
            screenHeight: size.height,
            frogPosition: frogController.position
        )
        
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
    
    private func handleLogBounce(enemy: Enemy) {
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
    
    // MARK: - Tadpole Collection
    private func handleTadpoleCollect() {
        if frogController.rocketActive { return }
        
        let abilityTriggered = healthManager.collectTadpole()
        scoreManager.addScore(100)
        
        showFloatingScore("+100", color: .systemYellow)
        
        if abilityTriggered {
            // Ability selection will be shown on next landing
        }
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
            print("ðŸŒŠ Suppressing water collision until next jump")
            healthManager.pendingAbilitySelection = false
            return
        }
        
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
            print("ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂºÃ…Â¸ Suppressing water collision until next jump")
            healthManager.pendingAbilitySelection = false
            return
        }
        
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
        label.fontName = "Arial-BoldMT"
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
    
    private func showFloatingText(_ text: String, color: UIColor) {
        let label = SKLabelNode(text: text)
        label.fontName = "Arial-BoldMT"
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
        print("  - rocketActive: \(frogController.rocketActive)")
        print("  - currentLilyPad: \(frogController.currentLilyPad != nil ? "YES" : "NO")")
        print("  - inputLocked: \(stateManager.inputLocked)")
        print("  - gameState: \(gameState)")
        print("  - pendingAbilitySelection: \(healthManager.pendingAbilitySelection)")
    }
    
    // Manual recovery function for testing/debugging
    func manualRecovery() {
        debugFrogState()
        stateManager.forceUnlockInput()
        if attemptStateRecovery() {
            print("✅ Manual recovery successful")
        } else {
            print("❌ Manual recovery failed")
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        let nodesAtPoint = nodes(at: location)
        
        // Press feedback for UI buttons (nodes named with known button names or ability_ prefix)
        if let tapped = nodesAtPoint.first(where: { node in
            guard let name = node.name else { return false }
            return name == "playGameButton" ||
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
                    startGame()
                    return
                }
                if nodeName == "profileButton" || nodeName == "leaderboardButton" || nodeName == "settingsButton" || nodeName == "audioButton" {
                    // Placeholder for future navigation, currently just close menu
                    print("Tapped \(nodeName), navigating...")
                    return
                }
                if nodeName == "exitButton" || nodeName == "backToMenuButton" {
                    showMainMenu()
                    return
                }
                if nodeName == "tryAgainButton" || nodeName == "restartButton" {
                    startGame()
                    return
                }
                
                // Ability selection buttons
                if nodeName.contains("ability") {
                    selectAbility(nodeName)
                    return
                }
                // Pause button handler
                           if nodeName == "pauseButton" {
                               gameState = .paused
                               uiManager.showPauseMenu(sceneSize: size)
                               return
                           }
                // Pause menu buttons
                           if nodeName == "continueButton" || nodeName == "resumeButton" {
                               gameState = .playing
                               uiManager.hideMenus()
                               return
                           }
                           
                           if nodeName == "quitButton" || nodeName == "quitToMenuButton" {
                               showMainMenu()
                               return
                           }
                
                // Rocket land button handler
                if nodeName == "rocketLandButton" {
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
            _ = touchInputController.handleTouchBegan(touch, in: self.view!, sceneSize: size, rocketActive: frogController.rocketActive)
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
        print("ÃƒÂ°Ã…Â¸Ã…Â½Ã‚Â¯ Slingshot touch began at: \(location)")
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
            _ = touchInputController.handleTouchEnded(touch, in: self.view!, sceneSize: size, rocketActive: frogController.rocketActive, hudBarHeight: hudBarHeight)
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
    }
    
    private func updateFacingFromAiming(location: CGPoint) {
        if frogController.isGrounded || frogController.inWater {
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

