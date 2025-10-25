//
//  GameScene.swift
//  Complete Top-down lily pad hopping game
//

import SpriteKit

class GameScene: SKScene {
    
    // Tracks the frog's last known facing angle (radians), used to smooth rotation
    private var frogFacingAngle: CGFloat = 0
    private var lockedFacingAngle: CGFloat? = nil
    private let artCorrection: CGFloat = .pi  // Flip 180ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°

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
    private var backgroundNode: SKSpriteNode?
    
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
        willSet {
            // CRITICAL: Ensure health never goes below 0 or above maxHealth
            // This prevents display bugs and ensures consistent game state
            if newValue < 0 {
                print("⚠️ Warning: Health would go below 0, clamping to 0")
            }
            if newValue > maxHealth {
                print("⚠️ Warning: Health would exceed maxHealth (\(maxHealth)), clamping to maxHealth")
            }
        }
        didSet {
            // Clamp health to valid range [0, maxHealth]
            if health < 0 {
                health = 0
                return
            }
            if health > maxHealth {
                health = maxHealth
                return
            }
            
            // Trigger heavy haptic only when losing health (not when increasing)
            if health < oldValue {
                HapticFeedbackManager.shared.impact(.heavy)
                // Make the frog invincible for 3 seconds after losing a heart
                frogController.activateInvincibility(seconds: 3.0)
                // Start a brief flicker to signal invincibility
                startInvincibilityFlicker()
            }
            
            updateBottomHUD()

            // Start flashing when only 1 heart remains; stop when health recovers to 2 or more
            if health == 1 {
                startLowHealthFlash()
            } else {
                stopLowHealthFlash()
            }

            if health <= 0 {
                stopLowHealthFlash()
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
            if tadpolesCollected >= GameConfig.tadpolesForAbility && !pendingAbilitySelection {
                pendingAbilitySelection = true
                tadpolesCollected = 0
                uiManager.updateStarProgress(current: tadpolesCollected, threshold: GameConfig.tadpolesForAbility)
                updateBottomHUD()
            }
        }
    }
    
    var pendingAbilitySelection: Bool = false
    
    // New property added per instructions:
    private var hasLandedOnce: Bool = false
    
    // MARK: - Game Objects (in world space)
    var enemies: [Enemy] = []
    var tadpoles: [Tadpole] = []
    var lilyPads: [LilyPad] = []
    
    var frameCount: Int = 0
    
    var lastGameOverReason: GameOverReason? = nil
    
    // Tracks any pending delayed game over so we can cancel it when restarting
    var pendingGameOverWorkItem: DispatchWorkItem?
    
    // Prevent stray touches from previous UI taps
    private var inputLocked = false
    
    private var splashTriggered = false
    private var scrollSaverCharges: Int = 0
    private var flySwatterCharges: Int = 0
    private var honeyJarCharges: Int = 0
    private var axeCharges: Int = 0
    
    // Grace period to prevent "too slow" detection after rocket landing
    private var rocketLandingGraceFrames: Int = 0
    
    // Pause vertical scrolling briefly after a successful landing (in frames)
    private var landingPauseFrames: Int = 0
    
    // Glide steering target position
    private var glideTargetScreenX: CGFloat? = nil
    
    // Rocket/Glide hold controls
    private var touchSideMap: [ObjectIdentifier: Bool] = [:] // true = right, false = left
    private var leftHoldCount: Int = 0
    private var rightHoldCount: Int = 0
    private let holdNudgePerFrame: CGFloat = 3.0
    private let holdMargin: CGFloat = 40.0
    
    // Instant nudge applied on tap when entering/using glide
    private let tapNudgeAmount: CGFloat = 12.0
    
    // Sidecar storage for per-log direction since Enemy doesn't expose userData
    private var logDirection: [ObjectIdentifier: CGFloat] = [:]
    
    // Glide tuning constants
    private let glideLerp: CGFloat = 0.08
    private let worldGlideLerp: CGFloat = 0.12
    private let glideSlowfallFactor: CGFloat = 0.10  // Dramatically slow: 75% speed reduction
    
    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
        print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ GameScene didMove - Top-Down View!")
        print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ Scene size: \(size)")
        
        backgroundColor = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
        
        // Ensure persistent water background
        if backgroundNode == nil {
            if let texture = SKTexture(imageNamed: "water.png") as SKTexture? {
                let bg = SKSpriteNode(texture: texture)
                bg.name = "waterBackground"
                bg.zPosition = -1000 // behind everything
                bg.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                bg.position = CGPoint(x: size.width/2, y: size.height/2)
                // Aspect fill to cover the whole scene
                let texSize = texture.size()
                let scaleX = size.width / texSize.width
                let scaleY = size.height / texSize.height
                let scale = max(scaleX, scaleY)
                bg.size = CGSize(width: texSize.width * scale, height: texSize.height * scale)
                addChild(bg)
                backgroundNode = bg
            }
        }
        
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
        
        // Resize background to always cover scene
        if let bg = backgroundNode, let texture = bg.texture {
            let texSize = texture.size()
            let scaleX = size.width / texSize.width
            let scaleY = size.height / texSize.height
            let scale = max(scaleX, scaleY)
            bg.size = CGSize(width: texSize.width * scale, height: texSize.height * scale)
            bg.position = CGPoint(x: size.width/2, y: size.height/2)
        }
        
        // Pre-warm all haptic types
        HapticFeedbackManager.shared.impact(.light)
        HapticFeedbackManager.shared.impact(.medium)
        HapticFeedbackManager.shared.impact(.heavy)
        HapticFeedbackManager.shared.selectionChanged()
        HapticFeedbackManager.shared.notification(.success)
        HapticFeedbackManager.shared.notification(.warning)
        HapticFeedbackManager.shared.notification(.error)
        print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ Setup complete!")
    }
    
    func setupManagers() {
        frogController = FrogController(scene: self)
        slingshotController = SlingshotController(scene: self)
        worldManager = WorldManager(scene: self)
        effectsManager = EffectsManager(scene: self)
        uiManager = UIManager(scene: self)
        collisionManager = CollisionManager(scene: self, uiManager: nil, frogController: frogController)
        collisionManager.effectsManager = effectsManager
        collisionManager.uiManager = uiManager
    }
    
    func setupGame() {
        // Setup world (scrolls down)
        // Ensure background is behind world and UI
        if let bg = backgroundNode {
            bg.removeFromParent()
            bg.zPosition = -1000
            addChild(bg)
        }
        
        let world = worldManager.setupWorld(sceneSize: size)
        addChild(world)
        
        // Setup spawn manager
        spawnManager = SpawnManager(scene: self, worldNode: worldManager.worldNode)
        spawnManager.startGracePeriod(duration: 1.5)
        
        // Setup frog container
        frogContainer = frogController.setupFrog(sceneSize: size)
        frogContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.4)
        frogContainer.zPosition = 110
        addChild(frogContainer)
        
        // Setup UI
        uiManager.setupUI(sceneSize: size)
        
        // Create menu backdrop
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
        
        // Create bottom HUD bar
        hudBar = SKShapeNode(rectOf: CGSize(width: size.width, height: hudBarHeight), cornerRadius: 12)
        hudBar.fillColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 0.95)
        hudBar.strokeColor = UIColor.white.withAlphaComponent(0.25)
        hudBar.lineWidth = 2.0
        hudBar.zPosition = 1000  // Above everything else including temporary labels
        hudBar.position = CGPoint(x: size.width/2, y: hudBarHeight/2)
        hudBar.isUserInteractionEnabled = false
        addChild(hudBar)
        
        // Hearts container
        heartsContainer = SKNode()
        heartsContainer.position = CGPoint(x: -size.width/2 + 20, y: 14)
        hudBar.addChild(heartsContainer)
        
        // Life vests container
        lifeVestsContainer = SKNode()
        lifeVestsContainer.position = CGPoint(x: -size.width/2 + 20, y: -14)
        hudBar.addChild(lifeVestsContainer)
        
        // Scroll saver container
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
        uiManager.hideMenus()
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
        
        pendingGameOverWorkItem?.cancel()
        pendingGameOverWorkItem = nil
        
        gameState = .playing
        
        inputLocked = true
        print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ Input locked for 0.2 seconds")
        
        let unlockTime = DispatchTime.now() + 0.2
        DispatchQueue.main.asyncAfter(deadline: unlockTime) {
            self.inputLocked = false
            print("Input unlocked")
        }

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
        
        // Reset hasLandedOnce flag on new game start
        hasLandedOnce = false
        
        frameCount = 0
        rocketLandingGraceFrames = 0
        // Removed: postRocketGlideFrames = 0
        glideTargetScreenX = nil
        
        frogController.lifeVestCharges = 0
        frogController.rocketFramesRemaining = 0
        scrollSaverCharges = 0
        flySwatterCharges = 0
        honeyJarCharges = 0
        axeCharges = 0
        frogController.suppressWaterCollisionUntilNextJump = false
        frogController.inWater = false
        
        frogContainer.zPosition = 50
        
        enemies.removeAll()
        tadpoles.removeAll()
        lilyPads.removeAll()
        
        worldManager.reset()
        
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
        
        frogFacingAngle = .pi / 4
        frogController.frog.zRotation = frogFacingAngle
        
        frogContainer.alpha = 1.0
        frogController.frog.alpha = 1.0
        frogController.frogShadow.alpha = 0.3
        
        spawnManager.spawnInitialObjects(sceneSize: size, lilyPads: &lilyPads, enemies: &enemies, tadpoles: &tadpoles, worldOffset: worldManager.worldNode.position.y)
        
        updateBottomHUD()
        
        print("Game started! Frog world position: \(frogController.position)")
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
        // Facing direction updated later in update()
        guard gameState == .playing else { return }
        
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
            if bg.zPosition != -1000 { bg.zPosition = -1000 }
        }
        
        frameCount += 1
        
        if rocketLandingGraceFrames > 0 {
            rocketLandingGraceFrames -= 1
        }
        // Removed: if postRocketGlideFrames > 0 { postRocketGlideFrames -= 1 }
        if landingPauseFrames > 0 {
            landingPauseFrames -= 1
        }
        
        if inputLocked && frameCount > 60 {
            print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Force unlocking input after \(frameCount) frames")
            inputLocked = false
        }
        
        // Dynamic scroll speed calculation
        var dynamicScroll: CGFloat
        if frogController.rocketActive {
            dynamicScroll = GameConfig.rocketScrollSpeed
            frogController.position.y += dynamicScroll
            
            let rocketScore = Int(dynamicScroll * 3)
            score += rocketScore
            
            if frameCount % 20 == 0 {
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
            // Replaced else-branch with hasLandedOnce logic per instructions
            if !hasLandedOnce {
                dynamicScroll = GameConfig.driftScrollSpeed
            } else {
                // Calculate scroll speed based on score milestones
                let speedTiers = score / GameConfig.scoreIntervalForSpeedIncrease
                let calculatedSpeed = GameConfig.scrollSpeed + (CGFloat(speedTiers) * GameConfig.scrollSpeedIncrement)
                dynamicScroll = min(GameConfig.maxScrollSpeed, calculatedSpeed)
            }

            // Debug logging every 60 frames (once per second)
            if frameCount % 60 == 0 {
                print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â  Score: \(score), Speed tier: \(score / GameConfig.scoreIntervalForSpeedIncrease), Current scroll speed: \(String(format: "%.2f", dynamicScroll))")
            }
        }
        
        // Removed: CRITICAL: Apply dramatic slowdown during glide (75% reduction!)

        // Apply vertical scroll unless we're in a landing pause
        if landingPauseFrames == 0 {
            worldManager.worldNode.position.y -= dynamicScroll
        }

        // Horizontal movement during rocket only (glide removed)
        if frogController.rocketActive {
            // Apply continuous hold-based nudges to the horizontal target
            if rightHoldCount > 0 || leftHoldCount > 0 {
                let currentTarget = glideTargetScreenX ?? frogContainer.position.x
                var nextTarget = currentTarget
                if rightHoldCount > 0 { nextTarget += holdNudgePerFrame }
                if leftHoldCount > 0 { nextTarget -= holdNudgePerFrame }
                let clamped = max(holdMargin, min(size.width - holdMargin, nextTarget))
                glideTargetScreenX = clamped
                
                if frameCount % 15 == 0 {
                    print("ÃƒÂ°Ã…Â¸Ã‚ÂªÃ¢â‚¬Å¡ Hold nudge - Left: \(leftHoldCount), Right: \(rightHoldCount), Target: \(currentTarget) -> \(clamped)")
                }
            }

            // Ensure we have a target so taps can steer immediately
            if glideTargetScreenX == nil {
                glideTargetScreenX = frogContainer.position.x
            }

            // Steer the frogContainer toward the target X on screen (same for rocket)
            if let targetX = glideTargetScreenX {
                let currentX = frogContainer.position.x
                frogContainer.position.x = currentX + (targetX - currentX) * glideLerp

                let newWorld = convert(CGPoint(x: frogContainer.position.x, y: frogContainer.position.y),
                                       to: worldManager.worldNode)
                frogController.position.x = newWorld.x
            }

            // World positioning to allow horizontal movement (rocket)
            let offsetFromCenter = frogContainer.position.x - (size.width / 2)
            let desiredWorldX = -offsetFromCenter * 0.4
            worldManager.worldNode.position.x += (desiredWorldX - worldManager.worldNode.position.x) * worldGlideLerp
        }
        
        if !frogController.rocketActive {
            worldManager.worldNode.position.x = (size.width / 2) - frogController.position.x
        }
        
        let frogWorldPoint = frogController.position
        let frogScreenPoint = convert(frogWorldPoint, from: worldManager.worldNode)
        let frogScreenY = frogScreenPoint.y
        let failThreshold: CGFloat = -40
        
        // Update frogContainer position based on game mode (glide removed)
        if frogController.rocketActive {
            frogContainer.position = CGPoint(x: frogContainer.position.x, y: size.height / 2)
        } else {
            frogContainer.position = frogScreenPoint
        }
        
        if frogScreenY < failThreshold && gameState == .playing && !frogController.rocketActive && rocketLandingGraceFrames <= 0 {
            if scrollSaverCharges > 0 {
                scrollSaverCharges -= 1
                updateBottomHUD()
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
        
        frogController.updateJump()
        
        // Update the frog's facing direction based on movement/state
        updateFrogFacingDirection()
        
        let scrollScore = worldManager.updateScrolling(isJumping: frogController.isJumping)
        score += scrollScore
        
        if !frogController.isJumping && !frogController.isGrounded {
            checkLanding()
        }
        
        if frogController.isGrounded, let pad = frogController.currentLilyPad, pad.type == .pulsing, !pad.isSafeToLand {
            if frogController.suppressWaterCollisionUntilNextJump {
            } else {
                triggerSplashOnce(gameOverDelay: 1.5)
            }
            return
        }
        
        // Update enemies with collision handling
        collisionManager.updateEnemies(
            enemies: &enemies,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            rocketActive: frogController.rocketActive,
            frogIsJumping: frogController.isJumping,
            worldOffset: worldManager.worldNode.position.y,
            lilyPads: &lilyPads,
            onHit: { [weak self] enemy -> HitOutcome in
                guard let self = self else { return .destroyed(cause: nil) }
                
                var consumedProtection = false
                var destroyCause: AbilityType? = nil
                
                if enemy.type == EnemyType.bee && self.honeyJarCharges > 0 {
                    self.honeyJarCharges -= 1
                    consumedProtection = true
                    destroyCause = .honeyJar
                    self.updateBottomHUD()
                    
                    let label = SKLabelNode(text: "Yum Yum!")
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
                    self.axeCharges -= 1
                    consumedProtection = true
                    destroyCause = .axe
                    self.updateBottomHUD()

                    let label = SKLabelNode(text: "Chop!")
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
                    self.flySwatterCharges -= 1
                    consumedProtection = true
                    destroyCause = nil
                    self.updateBottomHUD()
                    
                    let label = SKLabelNode(text: "Swat!")
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

                // Logs: if we have an axe, chop and pass through; otherwise, bonk/bounce without losing a heart
                if enemy.type == EnemyType.log {
                    if consumedProtection, destroyCause == .axe {
                        return .destroyed(cause: .axe)
                    } else {
                        return .hitOnly
                    }
                }

                if !consumedProtection {
                    self.health -= 1
                }

                self.frogController.activateInvincibility()

                // Always remove bees, dragonflies, and snakes when they hit the frog
                if enemy.type == EnemyType.bee || enemy.type == EnemyType.dragonfly || enemy.type == EnemyType.snake {
                    // If a protection was consumed, pass through the cause; otherwise nil
                    return .destroyed(cause: destroyCause)
                }

                // If a protection was consumed against other enemy types, destroy them too
                if consumedProtection {
                    return .destroyed(cause: destroyCause)
                } else {
                    return .hitOnly
                }
            },
            onLogBounce: { [weak self] (enemy: Enemy) in
                guard let self = self else { return }
                let dx = self.frogController.position.x - enemy.position.x
                let dy = self.frogController.position.y - enemy.position.y
                let len = max(0.001, sqrt(dx*dx + dy*dy))
                let nx = dx / len
                let ny = dy / len

                let v = self.frogController.velocity
                let dot = v.dx * nx + v.dy * ny
                var reflected = CGVector(dx: v.dx - 2 * dot * nx,
                                         dy: v.dy - 2 * dot * ny)
                reflected.dx *= 0.7
                reflected.dy *= 0.7

                let separation: CGFloat = 8
                let sepPos = CGPoint(x: self.frogController.position.x + nx * separation,
                                     y: self.frogController.position.y + ny * separation)
                self.frogController.position = sepPos

                let reflLen = max(0.001, sqrt(reflected.dx * reflected.dx + reflected.dy * reflected.dy))
                let rnx = reflected.dx / reflLen
                let rny = reflected.dy / reflLen
                let reboundDistance: CGFloat = 120
                let reboundTarget = CGPoint(x: sepPos.x + rnx * reboundDistance,
                                            y: sepPos.y + rny * reboundDistance)

                self.frogController.startJump(to: reboundTarget)

                // End super jump on log bounce, but do NOT stop rocket launches
                self.frogController.superJumpActive = false
                self.uiManager.hideSuperJumpIndicator()
                
                // Preserve rocket if it's active; do not disable it on log bounce
                // (Previously: self.frogController.rocketActive = false)
                // (Previously: self.uiManager.hideRocketIndicator())

                self.effectsManager?.createBonkLabel(at: self.frogContainer.position)
                HapticFeedbackManager.shared.impact(.heavy)
            }
        )

        // Ensure logs are constantly moving and push nearby lily pads
        // 1) Move logs horizontally until they go off-screen, then remove
        // 2) Apply a small push to lily pads intersecting with a log's radius
        do {
            // Parameters for log behavior
            let logSpeed: CGFloat = 10   // points/sec equivalent; we convert per-frame below
            let perFrame: CGFloat = logSpeed / 60.0

            let logRadius: CGFloat = 48.0   // approximate collision radius for pushing pads
            let padPushStrength: CGFloat = 22.0 // how much to nudge pads per frame when overlapping

            // Screen bounds in world coordinates for off-screen culling
            let leftWorldX = convert(CGPoint(x: -100, y: 0), to: worldManager.worldNode).x
            let rightWorldX = convert(CGPoint(x: size.width + 100, y: 0), to: worldManager.worldNode).x

            // Move each log and mark for removal if off-screen
            var indicesToRemove: [Int] = []
            for (i, enemy) in enemies.enumerated() {
                if enemy.type == EnemyType.log {
                    // Determine or retrieve the horizontal direction for this log
                    let key = ObjectIdentifier(enemy)
                    var dir: CGFloat
                    if let stored = logDirection[key] {
                        dir = stored
                    } else {
                        // Choose direction based on initial position: if left of center, move right; else left
                        let moveRight: Bool = enemy.position.x < frogController.position.x
                        dir = moveRight ? 1.0 : -1.0
                        logDirection[key] = dir
                    }

                    // Apply horizontal movement per frame
                    enemy.position.x += dir * perFrame

                    // Push nearby lily pads away horizontally
                    for pad in lilyPads {
                        let dx = pad.position.x - enemy.position.x
                        let dy = pad.position.y - enemy.position.y
                        let dist = sqrt(dx*dx + dy*dy)
                        if dist < (logRadius + pad.radius * 0.6) { // overlap threshold
                            // Push direction is away from the log's center
                            let pushDir: CGFloat = dx >= 0 ? 1.0 : -1.0
                            let newX = pad.position.x + (pushDir * (padPushStrength / 60.0))
                            pad.position.x = newX
                            pad.node.position.x = newX
                        }
                    }

                    // If the log has gone off-screen horizontally, mark for removal
                    if enemy.position.x < min(leftWorldX, rightWorldX) - 200 || enemy.position.x > max(leftWorldX, rightWorldX) + 200 {
                        indicesToRemove.append(i)
                    }
                }
            }

            // Remove off-screen logs (from both array and node tree)
            if !indicesToRemove.isEmpty {
                // Remove higher indices first to avoid reindexing issues
                for i in indicesToRemove.sorted(by: >) {
                    let e = enemies.remove(at: i)
                    // Clean up sidecar direction state
                    let key = ObjectIdentifier(e)
                    logDirection.removeValue(forKey: key)
                    e.node.removeFromParent()
                }
            }
        }

        collisionManager.updateTadpoles(
            tadpoles: &tadpoles,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            worldOffset: worldManager.worldNode.position.y,
            screenHeight: size.height,
            rocketActive: frogController.rocketActive,
            onCollect: { [weak self] in
                guard let self = self else { return }
                // Prevent collecting tadpoles (stars) while in rocket flight
                if self.frogController.rocketActive { return }
                self.tadpolesCollected += 1
                self.score += 100
                
                // Show +100 overlay near the frog when collecting a tadpole
                let plusLabel = SKLabelNode(text: "+100")
                plusLabel.fontName = "Arial-BoldMT"
                plusLabel.fontSize = 22
                plusLabel.fontColor = .systemYellow
                plusLabel.verticalAlignmentMode = .center
                plusLabel.horizontalAlignmentMode = .center
                plusLabel.position = CGPoint(
                    x: self.frogContainer.position.x + CGFloat.random(in: -20...20),
                    y: self.frogContainer.position.y + CGFloat.random(in: 20...40)
                )
                plusLabel.zPosition = 999
                self.addChild(plusLabel)

                let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
                rise.timingMode = .easeOut
                let fade = SKAction.fadeOut(withDuration: 0.8)
                let scale = SKAction.scale(to: 1.2, duration: 0.8)
                plusLabel.run(SKAction.sequence([
                    SKAction.group([rise, fade, scale]),
                    SKAction.removeFromParent()
                ]))
            }
        )
        
        collisionManager.updateLilyPads(
            lilyPads: &lilyPads,
            worldOffset: worldManager.worldNode.position.y,
            screenHeight: size.height,
            frogPosition: frogController.position
        )
        
        frogController.updateInvincibility()
        // Stop flicker once invincibility ends (if a flicker is running)
        if !frogController.invincible {
            stopInvincibilityFlicker()
        }
        frogController.updateSuperJump(indicator: uiManager.superJumpIndicator)
        if !frogController.superJumpActive {
            uiManager.hideSuperJumpIndicator()
        }
        
        frogController.updateRocket(indicator: uiManager.rocketIndicator)
        
        // Check if rocket just ended: decide landing outcome
        if !frogController.rocketActive && frogContainer.zPosition > 50 {
            frogContainer.zPosition = 50
            
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
            if padUnderFrog == nil {
                padUnderFrog = findOrCreateCenterPad()
            }
            
            if let pad = padUnderFrog {
                if pad.type != .pulsing || pad.isSafeToLand {
                    // CRITICAL FIX: Properly sync frog world position, screen position, and world offset
                    // to prevent the frog from jumping on the next frame
                    
                    // 1. Set frog's world position to the pad
                    frogController.position = pad.position
                    
                    // 2. Adjust world offset so the pad appears where we want the frog on screen
                    // We want the frog to stay at its current screen Y position
                    let desiredScreenY = frogContainer.position.y
                    let padWorldY = pad.position.y
                    // World offset formula: screenY = -worldOffset + worldY
                    // So: worldOffset = worldY - screenY
                    worldManager.worldNode.position.y = -(padWorldY - desiredScreenY)
                    
                    // 3. Also sync the X position properly
                    worldManager.worldNode.position.x = (size.width / 2) - pad.position.x
                    
                    // 4. Update screen position to match the desired location
                    let screenPos = convert(pad.position, from: worldManager.worldNode)
                    frogContainer.position = screenPos
                    
                    // 5. Complete the landing
                    frogController.landOnPad(pad)
                    effectsManager?.createLandingEffect(at: screenPos)
                    HapticFeedbackManager.shared.impact(.medium)
                    rocketLandingGraceFrames = 120
                    landingPauseFrames = max(landingPauseFrames, 60)
                    hasLandedOnce = true
                    uiManager.hideRocketIndicator()
                    
                    lockedFacingAngle = nil
                    
                    // Clear any glide target
                    glideTargetScreenX = nil
                    
                    return
                } else {
                    triggerSplashOnce(gameOverDelay: 0.6)
                    uiManager.hideRocketIndicator()
                    return
                }
            } else {
                frogController.inWater = true
                if frogController.lifeVestCharges > 0 {
                    frogController.lifeVestCharges -= 1
                    updateBottomHUD()
                    frogController.suppressWaterCollisionUntilNextJump = true
                    
                    let label = SKLabelNode(text: "Life Vest -1")
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
                    
                    effectsManager?.createSplashEffect(at: frogContainer.position)
                    HapticFeedbackManager.shared.notification(.warning)
                } else {
                    triggerSplashOnce(gameOverDelay: 0.6)
                }
                return
            }
        }
        
        // Removed entire glide mode block
        
        // Ensure ability selection appears as soon as we're grounded (not only via checkLanding)
        if pendingAbilitySelection && gameState == .playing && frogController.isGrounded {
            pendingAbilitySelection = false
            gameState = .abilitySelection
            uiManager.showAbilitySelection(sceneSize: size)
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
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if gameState == .playing && frogController.rocketActive {
            print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂªÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ Touch detected! Rocket: \(frogController.rocketActive), Location: \(location)")
            
            if location.y > hudBarHeight {
                let centerX = size.width / 2
                let isRight = location.x >= centerX
                print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂªÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ Touch side: \(isRight ? "RIGHT" : "LEFT"), centerX: \(centerX), touch X: \(location.x)")

                // Track this touch's side
                let key = ObjectIdentifier(touch)
                touchSideMap[key] = isRight
                if isRight { rightHoldCount += 1 } else { leftHoldCount += 1 }
                print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂªÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ Hold counts - Left: \(leftHoldCount), Right: \(rightHoldCount)")

                // Ignore HUD area for glide steering
                if location.y > hudBarHeight {
                    // Initialize/adjust target immediately for responsiveness
                    let startTarget = glideTargetScreenX ?? frogContainer.position.x
                    let nudge = isRight ? tapNudgeAmount : -tapNudgeAmount
                    let clamped = max(holdMargin, min(size.width - holdMargin, startTarget + nudge))
                    glideTargetScreenX = clamped
                    print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂªÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ Updated glideTargetScreenX from \(startTarget) to \(clamped) (nudge: \(nudge))")
                }

                HapticFeedbackManager.shared.selectionChanged()
            }
            return
        }
        
        // Replaced block as per instructions:
        if location.y <= hudBarHeight && !frogController.rocketActive {
            // Debug: if aiming is blocked while touching above HUD, log why
            if gameState == .playing {
                if pendingAbilitySelection {
                    print("Aiming blocked: pendingAbilitySelection is true")
                } else if frogController.rocketActive {
                    print("Aiming blocked: rocketActive is true")
                } else if !(frogController.isGrounded || frogController.inWater) {
                    print("Aiming blocked: frog is not grounded or in water")
                }
            }
            if gameState == .playing && !pendingAbilitySelection && !frogController.rocketActive {
                if frogController.isGrounded || frogController.inWater {
                    let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
                    let clampedStart = CGPoint(x: location.x, y: hudBarHeight + 1)
                    slingshotController.handleTouchBegan(at: clampedStart, frogScreenPosition: frogScreenPoint)
                    // Set facing opposite of pull direction during aim start
                    let start = frogScreenPoint
                    let pull = CGPoint(x: clampedStart.x - start.x, y: clampedStart.y - start.y)
                    if pull.x != 0 || pull.y != 0 {
                        // Face opposite the pull: pull left => face right, pull right => face left
                        let desired = atan2(-pull.y, -pull.x) + .pi/2
                        frogFacingAngle = desired + artCorrection
                        frogController.frog.zRotation = frogFacingAngle
                        lockedFacingAngle = frogFacingAngle
                    }
                } else if frogController.isJumping {
                    frogController.isJumping = false
                    slingshotController.cancelCurrentAiming()
                    lockedFacingAngle = nil
                }
            }
            // Do not early-return; allow gesture to continue through moved/ended
        }
        
        let nodes = self.nodes(at: location)
        for node in nodes {
            var current: SKNode? = node
            while let n = current {
                if let name = n.name {
                    if name.hasPrefix("ability_") {
                        let abilityStr = name.replacingOccurrences(of: "ability_", with: "")
                        selectAbility(abilityStr)
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
        
        if gameState == .playing && (frogController.isGrounded || frogController.inWater) && !pendingAbilitySelection && !frogController.rocketActive {
            let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
            slingshotController.handleTouchBegan(at: location, frogScreenPosition: frogScreenPoint)
            // Set facing opposite of pull direction during aim start
            let start = frogScreenPoint
            let pull = CGPoint(x: location.x - start.x, y: location.y - start.y)
            if pull.x != 0 || pull.y != 0 {
                let desired = atan2(-pull.y, -pull.x) + .pi/2
                frogFacingAngle = desired + artCorrection
                frogController.frog.zRotation = frogFacingAngle
                lockedFacingAngle = frogFacingAngle
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if gameState == .playing && frogController.rocketActive {
            // Update side map if finger crosses center (rarely needed, but keeps intent consistent)
            let key = ObjectIdentifier(touch)
            if touchSideMap[key] != nil {
                let isRight = location.x >= size.width / 2
                touchSideMap[key] = isRight
            }

            // Apply continuous steering while holding during rocket
            if location.y > hudBarHeight {
                if rightHoldCount > 0 || leftHoldCount > 0 {
                    let currentTarget = glideTargetScreenX ?? frogContainer.position.x
                    var nextTarget = currentTarget
                    if rightHoldCount > 0 { nextTarget += holdNudgePerFrame }
                    if leftHoldCount > 0 { nextTarget -= holdNudgePerFrame }
                    let clamped = max(holdMargin, min(size.width - holdMargin, nextTarget))
                    glideTargetScreenX = clamped
                }
            }
        }
        
        // Replaced block as per instructions:
        if location.y <= hudBarHeight && !frogController.rocketActive {
            // Debug: if aiming is blocked while touching above HUD, log why
            if gameState == .playing {
                if pendingAbilitySelection {
                    print("Aiming blocked: pendingAbilitySelection is true")
                } else if frogController.rocketActive {
                    print("Aiming blocked: rocketActive is true")
                } else if !(frogController.isGrounded || frogController.inWater) {
                    print("Aiming blocked: frog is not grounded or in water")
                }
            }
            if gameState == .playing && !pendingAbilitySelection && !frogController.rocketActive {
                if frogController.isGrounded || frogController.inWater {
                    let clampedPoint = CGPoint(x: location.x, y: hudBarHeight + 1)
                    slingshotController.handleTouchMoved(to: clampedPoint)
                    // Update facing opposite of current pull while aiming
                    if frogController.isGrounded || frogController.inWater {
                        let start = convert(frogController.position, from: worldManager.worldNode)
                        let pull = CGPoint(x: clampedPoint.x - start.x, y: clampedPoint.y - start.y)
                        if pull.x != 0 || pull.y != 0 {
                            let desired = atan2(-pull.y, -pull.x) + .pi/2
                            frogFacingAngle = desired + artCorrection
                            frogController.frog.zRotation = frogFacingAngle
                            lockedFacingAngle = frogFacingAngle
                        }
                    }
                } else if frogController.isJumping {
                    frogController.isJumping = false
                    slingshotController.cancelCurrentAiming()
                    lockedFacingAngle = nil
                }
            }
            return
        }
        
        if inputLocked { return }
        
        if gameState == .playing && !pendingAbilitySelection && !frogController.rocketActive {
            slingshotController.handleTouchMoved(to: location)
            // Update facing opposite of current pull while aiming
            if frogController.isGrounded || frogController.inWater {
                let start = convert(frogController.position, from: worldManager.worldNode)
                let pull = CGPoint(x: location.x - start.x, y: location.y - start.y)
                if pull.x != 0 || pull.y != 0 {
                    let desired = atan2(-pull.y, -pull.x) + .pi/2
                    frogFacingAngle = desired + artCorrection
                    frogController.frog.zRotation = frogFacingAngle
                    lockedFacingAngle = frogFacingAngle
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if gameState == .playing && frogController.rocketActive {
            let key = ObjectIdentifier(touch)
            if let isRight = touchSideMap.removeValue(forKey: key) {
                if isRight { rightHoldCount = max(0, rightHoldCount - 1) }
                else { leftHoldCount = max(0, leftHoldCount - 1) }
            }
        }
        
        // Existing block (kept as-is per instructions):
        if location.y <= hudBarHeight && !frogController.rocketActive {
            // Debug: if aiming is blocked while touching above HUD, log why
            if gameState == .playing {
                if pendingAbilitySelection {
                    print("Aiming blocked: pendingAbilitySelection is true")
                } else if frogController.rocketActive {
                    print("Aiming blocked: rocketActive is true")
                } else if !(frogController.isGrounded || frogController.inWater) {
                    print("Aiming blocked: frog is not grounded or in water")
                }
            }
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
                        lockedFacingAngle = frogFacingAngle
                    }
                    slingshotController.cancelCurrentAiming()
                } else if frogController.isJumping {
                    frogController.isJumping = false
                    slingshotController.cancelCurrentAiming()
                    lockedFacingAngle = nil
                }
            }
            return
        }
        
        if inputLocked { return }
        
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
                lockedFacingAngle = frogFacingAngle
            }
        }
    }
    
    // MARK: - Helper Methods
    func checkLanding() {
        var landedOnPad = false
        
        for pad in lilyPads {
            let dx = frogController.position.x - pad.position.x
            let dy = frogController.position.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            let threshold = pad.radius * 1.15
            let epsilon: CGFloat = 6.0 // small forgiveness to account for motion/scrolling
            if distance <= threshold + epsilon {
                if pad.type == .pulsing && !pad.isSafeToLand {
                    triggerSplashOnce(gameOverDelay: 1.5)
                    return
                }
                
                frogController.landOnPad(pad)
                
                // Removed angle adjustment here to preserve last facing (no change)
                // let angleToPad = atan2(pad.position.y - frogController.position.y, pad.position.x - frogController.position.x)
                // frogFacingAngle = angleToPad
                // frogController.frog.zRotation = frogFacingAngle
                
                frogController.isJumping = false
                frogController.isGrounded = true
                frogController.inWater = false
                frogController.suppressWaterCollisionUntilNextJump = false
                
                effectsManager?.createLandingEffect(at: frogContainer.position)
                HapticFeedbackManager.shared.impact(.medium)
                
                // Add extra pause after successful landing (1 second at 60 fps)
                landingPauseFrames = max(landingPauseFrames, 60)
                
                // Set hasLandedOnce true after normal landing
                hasLandedOnce = true
                
                // Clear locked facing on landing so frog can turn freely after this
                lockedFacingAngle = nil
                
                let bounceAction = SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
                ])
                pad.node.run(bounceAction)
                
                landedOnPad = true
                self.splashTriggered = false
                
                if pendingAbilitySelection && gameState == .playing {
                    pendingAbilitySelection = false
                    gameState = .abilitySelection
                    uiManager.showAbilitySelection(sceneSize: size)
                }
                
                break
            }
        }
        
        if !landedOnPad {
            if splashTriggered { return }
            splashTriggered = true
            
            if frogController.suppressWaterCollisionUntilNextJump {
                print("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â  Suppressing water collision until next jump")
                pendingAbilitySelection = false
                return
            }

            frogController.splash()
            lockedFacingAngle = nil
            HapticFeedbackManager.shared.notification(.error)
            effectsManager?.createSplashEffect(at: frogContainer.position)
            
            if frogController.inWater {
                if frogController.lifeVestCharges > 0 {
                    pendingGameOverWorkItem?.cancel()
                    
                    frogController.lifeVestCharges -= 1
                    updateBottomHUD()
                    pendingGameOverWorkItem?.cancel()
                    pendingAbilitySelection = false
                    frogController.suppressWaterCollisionUntilNextJump = true
                    self.splashTriggered = false
                    
                    let label = SKLabelNode(text: "Life Vest -1")
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
                } else {
                    pendingAbilitySelection = false
                    pendingGameOverWorkItem?.cancel()
                    let work = DispatchWorkItem { [weak self] in
                        self?.gameOver(.splash)
                    }
                    pendingGameOverWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
                }
            } else {
                pendingAbilitySelection = false
                pendingGameOverWorkItem?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    self?.gameOver(.splash)
                }
                pendingGameOverWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
            }
        }
    }
    
    private func makeLilyPad(position: CGPoint, radius: CGFloat) -> LilyPad {
        let type: LilyPadType
        if score < 2000 {
            type = .normal
        } else {
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
        if type == .moving {
            pad.screenWidthProvider = { [weak self] in self?.size.width ?? 1024 }
            pad.movementSpeed = 120.0
            pad.refreshMovement()
        }
        return pad
    }
    
    // Finds a safe lilypad near the middle of the screen (in view). If none exists, spawns one and returns it.
    private func findOrCreateCenterPad() -> LilyPad? {
        // Define a target screen point near center-top third to keep it well in view
        let targetScreen = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
        let targetWorld = convert(targetScreen, to: worldManager.worldNode)
        let maxSearchRadius: CGFloat = 220
        var best: (pad: LilyPad, dist: CGFloat)? = nil
        for pad in lilyPads {
            // Only consider pads that will be on-screen
            let padScreen = convert(pad.position, from: worldManager.worldNode)
            if padScreen.x >= 40 && padScreen.x <= size.width - 40 && padScreen.y >= hudBarHeight + 40 && padScreen.y <= size.height - 40 {
                let dx = pad.position.x - targetWorld.x
                let dy = pad.position.y - targetWorld.y
                let d = sqrt(dx*dx + dy*dy)
                if d <= maxSearchRadius {
                    if best == nil || d < best!.dist {
                        best = (pad, d)
                    }
                }
            }
        }
        if let candidate = best?.pad {
            return candidate
        }
        // None found: create a new safe pad centered in view
        let radius: CGFloat = 60
        let newPadPos = CGPoint(x: targetWorld.x, y: targetWorld.y)
        // Create a guaranteed-safe pad by forcing a normal type
        let pad = LilyPad(position: newPadPos, radius: radius, type: .normal)
        pad.node.position = pad.position
        pad.node.zPosition = 10
        worldManager.worldNode.addChild(pad.node)
        lilyPads.append(pad)
        return pad
    }
    
    private func triggerSplashOnce(gameOverDelay: TimeInterval) {
        if splashTriggered { return }
        splashTriggered = true
        
        frogController.splash()
        lockedFacingAngle = nil
        HapticFeedbackManager.shared.notification(.error)
        effectsManager?.createSplashEffect(at: frogContainer.position)
        
        pendingAbilitySelection = false
        pendingGameOverWorkItem?.cancel()
        
        let work = DispatchWorkItem { [weak self] in
            self?.gameOver(.splash)
        }
        pendingGameOverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + gameOverDelay, execute: work)
    }
    
    private func updateBottomHUD() {
        let maxDisplayHearts = 6
        heartsContainer.removeAllChildren()
        let heartSize: CGFloat = 20  // Size of heart images (renamed from heartSize)
        let spacing: CGFloat = 12  // Increased spacing
        let totalHearts = min(maxDisplayHearts, maxHealth)
        
        // CRITICAL FIX: Ensure health is within valid bounds for display
        let currentHealth = max(0, min(health, maxHealth))
        
        for i in 0..<totalHearts {
            // A heart is filled if its index is less than current health
            let isFilled = i < currentHealth
            
            // Try to load heart.png, fall back to emoji if not found
            let heartTexture = SKTexture(imageNamed: "heart.png")
            if heartTexture.size().width > 0 && heartTexture.size().height > 0 {
                let heartSprite = SKSpriteNode(texture: heartTexture)
                heartSprite.size = CGSize(width: heartSize, height: heartSize)
                heartSprite.position = CGPoint(x: CGFloat(i) * (heartSize + spacing), y: 0)
                heartSprite.zPosition = 1
                
                // For empty hearts, make them semi-transparent and grayscale
                if !isFilled {
                    heartSprite.alpha = 0.3
                    heartSprite.colorBlendFactor = 1.0
                    heartSprite.color = .gray
                }
                
                heartsContainer.addChild(heartSprite)
            } else {
                // Fallback to emoji if heart.png is not found
                let heart = SKLabelNode(text: isFilled ? "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¤ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â" : "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â")
                heart.fontName = "Arial-BoldMT"
                heart.fontSize = heartSize
                heart.verticalAlignmentMode = .center
                heart.horizontalAlignmentMode = .left
                heart.position = CGPoint(x: CGFloat(i) * (heartSize + spacing), y: 0)
                heart.zPosition = 1
                heartsContainer.addChild(heart)
            }
        }
        
        lifeVestsContainer.removeAllChildren()
        let vestIconSize: CGFloat = 20
        let vestSpacing: CGFloat = 8
        let vestCount = max(0, frogController.lifeVestCharges)
        let vestTexture = SKTexture(imageNamed: "lifevest.png")
        let useVestTexture = vestTexture.size().width > 0 && vestTexture.size().height > 0
        for i in 0..<vestCount {
            if useVestTexture {
                let vestSprite = SKSpriteNode(texture: vestTexture)
                vestSprite.size = CGSize(width: vestIconSize, height: vestIconSize)
                vestSprite.position = CGPoint(x: CGFloat(i) * (vestIconSize + vestSpacing), y: 0)
                vestSprite.zPosition = 1
                lifeVestsContainer.addChild(vestSprite)
            } else {
                let vest = SKLabelNode(text: "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âº")
                vest.fontSize = vestIconSize
                vest.verticalAlignmentMode = .center
                vest.horizontalAlignmentMode = .left
                vest.position = CGPoint(x: CGFloat(i) * (vestIconSize + vestSpacing), y: 0)
                vest.zPosition = 1
                lifeVestsContainer.addChild(vest)
            }
        }
        
        scrollSaverContainer.removeAllChildren()
        let saverIconSize: CGFloat = 20
        let saverSpacing: CGFloat = 8
        let saverTexture = SKTexture(imageNamed: "scrollsaver.png")
        let useSaverTexture = saverTexture.size().width > 0 && saverTexture.size().height > 0
        for i in 0..<scrollSaverCharges {
            if useSaverTexture {
                let saverSprite = SKSpriteNode(texture: saverTexture)
                saverSprite.size = CGSize(width: saverIconSize, height: saverIconSize)
                saverSprite.position = CGPoint(x: CGFloat(i) * (saverIconSize + saverSpacing), y: 0)
                saverSprite.zPosition = 1
                scrollSaverContainer.addChild(saverSprite)
            } else {
                let saver = SKLabelNode(text: "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±")
                saver.fontSize = saverIconSize
                saver.verticalAlignmentMode = .center
                saver.horizontalAlignmentMode = .left
                saver.position = CGPoint(x: CGFloat(i) * (saverIconSize + saverSpacing), y: 0)
                saver.zPosition = 1
                scrollSaverContainer.addChild(saver)
            }
        }
        
        if let existing = hudBar.childNode(withName: "flySwatterContainer") {
            if flySwatterCharges <= 0 {
                existing.removeFromParent()
            } else if let flyContainer = existing as? SKNode {
                flyContainer.removeAllChildren()
                let flyTexture = SKTexture(imageNamed: "flySwatter.png")
                let useFlyTexture = flyTexture.size().width > 0 && flyTexture.size().height > 0
                let flyIconSize: CGFloat = 20
                let flySpacing: CGFloat = 8
                for i in 0..<min(6, flySwatterCharges) {
                    if useFlyTexture {
                        let swatSprite = SKSpriteNode(texture: flyTexture)
                        swatSprite.size = CGSize(width: flyIconSize, height: flyIconSize)
                        swatSprite.position = CGPoint(x: CGFloat(i) * (flyIconSize + flySpacing), y: 0)
                        swatSprite.zPosition = 1
                        flyContainer.addChild(swatSprite)
                    } else {
                        let swat = SKLabelNode(text: "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂªÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°")
                        swat.fontSize = flyIconSize
                        swat.verticalAlignmentMode = .center
                        swat.horizontalAlignmentMode = .left
                        swat.position = CGPoint(x: CGFloat(i) * (flyIconSize + flySpacing), y: 0)
                        swat.zPosition = 1
                        flyContainer.addChild(swat)
                    }
                }
            }
        } else {
            if flySwatterCharges > 0 {
                let flyContainer = SKNode()
                flyContainer.name = "flySwatterContainer"
                flyContainer.position = CGPoint(x: scrollSaverContainer.position.x + 150, y: scrollSaverContainer.position.y)
                hudBar.addChild(flyContainer)
                let flyTexture = SKTexture(imageNamed: "flySwatter.png")
                let useFlyTexture = flyTexture.size().width > 0 && flyTexture.size().height > 0
                let flyIconSize: CGFloat = 20
                let flySpacing: CGFloat = 8
                for i in 0..<min(6, flySwatterCharges) {
                    if useFlyTexture {
                        let swatSprite = SKSpriteNode(texture: flyTexture)
                        swatSprite.size = CGSize(width: flyIconSize, height: flyIconSize)
                        swatSprite.position = CGPoint(x: CGFloat(i) * (flyIconSize + flySpacing), y: 0)
                        swatSprite.zPosition = 1
                        flyContainer.addChild(swatSprite)
                    } else {
                        let swat = SKLabelNode(text: "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂªÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°")
                        swat.fontSize = flyIconSize
                        swat.verticalAlignmentMode = .center
                        swat.horizontalAlignmentMode = .left
                        swat.position = CGPoint(x: CGFloat(i) * (flyIconSize + flySpacing), y: 0)
                        swat.zPosition = 1
                        flyContainer.addChild(swat)
                    }
                }
            }
        }

        if let existing = hudBar.childNode(withName: "honeyJarContainer") {
            if honeyJarCharges <= 0 {
                existing.removeFromParent()
            } else if let honeyContainer = existing as? SKNode {
                honeyContainer.removeAllChildren()
                let honeyTexture = SKTexture(imageNamed: "honeyPot.png")
                let useHoneyTexture = honeyTexture.size().width > 0 && honeyTexture.size().height > 0
                let iconSize: CGFloat = 20
                let spacing: CGFloat = 8
                for i in 0..<min(6, honeyJarCharges) {
                    if useHoneyTexture {
                        let jarSprite = SKSpriteNode(texture: honeyTexture)
                        jarSprite.size = CGSize(width: iconSize, height: iconSize)
                        jarSprite.position = CGPoint(x: CGFloat(i) * (iconSize + spacing), y: 0)
                        jarSprite.zPosition = 1
                        honeyContainer.addChild(jarSprite)
                    } else {
                        let jar = SKLabelNode(text: "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¯")
                        jar.fontSize = iconSize
                        jar.verticalAlignmentMode = .center
                        jar.horizontalAlignmentMode = .left
                        jar.position = CGPoint(x: CGFloat(i) * (iconSize + spacing), y: 0)
                        jar.zPosition = 1
                        honeyContainer.addChild(jar)
                    }
                }
            }
        } else {
            if honeyJarCharges > 0 {
                let honeyContainer = SKNode()
                honeyContainer.name = "honeyJarContainer"
                honeyContainer.position = CGPoint(x: lifeVestsContainer.position.x + 150, y: lifeVestsContainer.position.y)
                hudBar.addChild(honeyContainer)
                let honeyTexture = SKTexture(imageNamed: "honeyPot.png")
                let useHoneyTexture = honeyTexture.size().width > 0 && honeyTexture.size().height > 0
                let iconSize: CGFloat = 20
                let spacing: CGFloat = 8
                for i in 0..<min(6, honeyJarCharges) {
                    if useHoneyTexture {
                        let jarSprite = SKSpriteNode(texture: honeyTexture)
                        jarSprite.size = CGSize(width: iconSize, height: iconSize)
                        jarSprite.position = CGPoint(x: CGFloat(i) * (iconSize + spacing), y: 0)
                        jarSprite.zPosition = 1
                        honeyContainer.addChild(jarSprite)
                    } else {
                        let jar = SKLabelNode(text: "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¯")
                        jar.fontSize = iconSize
                        jar.verticalAlignmentMode = .center
                        jar.horizontalAlignmentMode = .left
                        jar.position = CGPoint(x: CGFloat(i) * (iconSize + spacing), y: 0)
                        jar.zPosition = 1
                        honeyContainer.addChild(jar)
                    }
                }
            }
        }
        
        if let existing = hudBar.childNode(withName: "axeContainer") {
            if axeCharges <= 0 {
                existing.removeFromParent()
            } else if let axeContainer = existing as? SKNode {
                axeContainer.removeAllChildren()
                let axeTexture = SKTexture(imageNamed: "ax.png")
                let useAxeTexture = axeTexture.size().width > 0 && axeTexture.size().height > 0
                let iconSize: CGFloat = 20
                let spacing: CGFloat = 8
                for i in 0..<min(6, axeCharges) {
                    if useAxeTexture {
                        let axeSprite = SKSpriteNode(texture: axeTexture)
                        axeSprite.size = CGSize(width: iconSize, height: iconSize)
                        axeSprite.position = CGPoint(x: CGFloat(i) * (iconSize + spacing), y: 0)
                        axeSprite.zPosition = 1
                        axeContainer.addChild(axeSprite)
                    } else {
                        let axe = SKLabelNode(text: "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂªÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“")
                        axe.fontSize = iconSize
                        axe.verticalAlignmentMode = .center
                        axe.horizontalAlignmentMode = .left
                        axe.position = CGPoint(x: CGFloat(i) * (iconSize + spacing), y: 0)
                        axe.zPosition = 1
                        axeContainer.addChild(axe)
                    }
                }
            }
        } else {
            if axeCharges > 0 {
                let axeContainer = SKNode()
                axeContainer.name = "axeContainer"
                let baseX = scrollSaverContainer.position.x + 300
                axeContainer.position = CGPoint(x: baseX, y: scrollSaverContainer.position.y)
                hudBar.addChild(axeContainer)
                let axeTexture = SKTexture(imageNamed: "ax.png")
                let useAxeTexture = axeTexture.size().width > 0 && axeTexture.size().height > 0
                let iconSize: CGFloat = 20
                let spacing: CGFloat = 8
                for i in 0..<min(6, axeCharges) {
                    if useAxeTexture {
                        let axeSprite = SKSpriteNode(texture: axeTexture)
                        axeSprite.size = CGSize(width: iconSize, height: iconSize)
                        axeSprite.position = CGPoint(x: CGFloat(i) * (iconSize + spacing), y: 0)
                        axeSprite.zPosition = 1
                        axeContainer.addChild(axeSprite)
                    } else {
                        let axe = SKLabelNode(text: "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂªÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“")
                        axe.fontSize = iconSize
                        axe.verticalAlignmentMode = .center
                        axe.horizontalAlignmentMode = .left
                        axe.position = CGPoint(x: CGFloat(i) * (iconSize + spacing), y: 0)
                        axe.zPosition = 1
                        axeContainer.addChild(axe)
                    }
                }
            }
        }
    }
    
    func showMainMenu() {
        menuBackdrop?.alpha = 1.0
        frogContainer.alpha = 1.0
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        pendingAbilitySelection = false
        gameState = .menu
        uiManager.showMainMenu(sceneSize: size)
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
        } else if abilityStr.contains("flySwatter") {
            flySwatterCharges = min(6, flySwatterCharges + 1)
            updateBottomHUD()
        } else if abilityStr.contains("honeyJar") {
            honeyJarCharges = min(6, honeyJarCharges + 1)
            updateBottomHUD()
        } else if abilityStr.contains("axe") {
            axeCharges = min(6, axeCharges + 1)
            updateBottomHUD()
        } else if abilityStr.contains("rocket") {
            frogController.activateRocket()
            uiManager.showRocketIndicator(sceneSize: size)

            glideTargetScreenX = frogContainer.position.x

            let centerX = size.width / 2
            let centerY = size.height / 2

            let moveToCenter = SKAction.move(to: CGPoint(x: centerX, y: centerY), duration: 0.5)
            moveToCenter.timingMode = .easeInEaseOut
            frogContainer.run(moveToCenter)

            frogContainer.zPosition = 100
            
            if let bg = backgroundNode { bg.zPosition = -1000 }
        }
        
        pendingAbilitySelection = false
        gameState = .playing
    }
    
    private func startLowHealthFlash() {
        frogController.frog.removeAction(forKey: "lowHealthFlash")
        frogController.frogShadow.removeAction(forKey: "lowHealthFlash")
        frogContainer.removeAction(forKey: "lowHealthFlash")
        
        let flashRed = SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.4)
        let flashNormal = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.4)
        let pulseSequence = SKAction.sequence([flashRed, flashNormal])
        let repeatFlash = SKAction.repeatForever(pulseSequence)
        
        frogController.frog.run(repeatFlash, withKey: "lowHealthFlash")
        
        let shadowDim = SKAction.fadeAlpha(to: 0.15, duration: 0.4)
        let shadowBright = SKAction.fadeAlpha(to: 0.3, duration: 0.4)
        let shadowPulse = SKAction.sequence([shadowDim, shadowBright])
        let repeatShadow = SKAction.repeatForever(shadowPulse)
        
        frogController.frogShadow.run(repeatShadow, withKey: "lowHealthFlash")
        
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.4)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.4)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let scalePulse = SKAction.sequence([scaleUp, scaleDown])
        let repeatScale = SKAction.repeatForever(scalePulse)
        
        frogContainer.run(repeatScale, withKey: "lowHealthFlash")
    }

    private func stopLowHealthFlash() {
        frogController.frog.removeAction(forKey: "lowHealthFlash")
        frogController.frogShadow.removeAction(forKey: "lowHealthFlash")
        frogContainer.removeAction(forKey: "lowHealthFlash")
        
        frogController.frogSprite.colorBlendFactor = 0.0
        frogController.frogShadow.alpha = 0.3
        frogContainer.setScale(1.0)
    }
    
    // MARK: - Invincibility Flicker
    private func startInvincibilityFlicker() {
        // Clear any previous flicker
        frogController.frog.removeAction(forKey: "invincibleFlicker")
        frogController.frogShadow.removeAction(forKey: "invincibleFlicker")

        // Quick alpha flicker on the frog sprite
        let fadeDown = SKAction.fadeAlpha(to: 0.4, duration: 0.08)
        let fadeUp = SKAction.fadeAlpha(to: 1.0, duration: 0.08)
        let flicker = SKAction.sequence([fadeDown, fadeUp])
        let repeatFlicker = SKAction.repeat(flicker, count: 12) // ~2 seconds total

        // Optional: subtle color tint to reinforce state
        let tintOn = SKAction.colorize(with: .yellow, colorBlendFactor: 0.35, duration: 0.0)
        let tintOff = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.0)
        let tintSeq = SKAction.sequence([tintOn, repeatFlicker, tintOff])

        frogController.frog.run(tintSeq, withKey: "invincibleFlicker")

        // Slight shadow pulsing for extra clarity
        let shadowDim = SKAction.fadeAlpha(to: 0.15, duration: 0.08)
        let shadowBright = SKAction.fadeAlpha(to: 0.3, duration: 0.08)
        let shadowPulse = SKAction.sequence([shadowDim, shadowBright])
        frogController.frogShadow.run(SKAction.repeat(shadowPulse, count: 12), withKey: "invincibleFlicker")
    }

    private func stopInvincibilityFlicker() {
        frogController.frog.removeAction(forKey: "invincibleFlicker")
        frogController.frogShadow.removeAction(forKey: "invincibleFlicker")
        frogController.frog.alpha = 1.0
        frogController.frogSprite.colorBlendFactor = 0.0
        frogController.frogShadow.alpha = 0.3
    }
    
    // MARK: - Facing Direction Handling
    private func updateFrogFacingDirection() {
        // Only rotate while actually playing
        guard gameState == .playing else { return }

        // If we have a locked facing (from aiming), keep it while jumping and until next explicit change
        if let locked = lockedFacingAngle {
            // Apply the locked angle and smooth toward it
            let lerpFactor: CGFloat = 0.18
            var delta = locked - frogFacingAngle
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
           
            frogFacingAngle = frogFacingAngle + delta * lerpFactor
            frogController.frog.zRotation = frogFacingAngle
            return
        }

        // Choose an orientation source:
        // 1) If rocket is active, use horizontal steering (screen-space) combined with upward motion
        // 2) Else if the frog has meaningful velocity while jumping, use velocity vector
        // 3) Else keep the last angle
        var desiredAngle: CGFloat? = nil

        if frogController.rocketActive {
            let currentScreen = frogContainer.position
            let targetX = glideTargetScreenX ?? currentScreen.x
            let targetScreen = CGPoint(x: targetX, y: currentScreen.y + 60)
            let dx = targetScreen.x - currentScreen.x
            let dy = targetScreen.y - currentScreen.y
            if dx != 0 || dy != 0 {
                desiredAngle = atan2(dy, dx)
            }
        } else {
            let v = frogController.velocity
            if abs(v.dx) + abs(v.dy) > 1.0 {
                desiredAngle = atan2(v.dy, v.dx)
            }
        }

        if let base = desiredAngle { desiredAngle = base + artCorrection }

        let targetAngle = desiredAngle ?? frogFacingAngle
        let lerpFactor: CGFloat = 0.18
        let current = frogFacingAngle
        var delta = targetAngle - current
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        let newAngle = current + delta * lerpFactor
        frogFacingAngle = newAngle
        frogController.frog.zRotation = newAngle
    }
}
