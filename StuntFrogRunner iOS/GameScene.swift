import SpriteKit
import GameplayKit

/// A structure representing a parallax plant decoration
struct ParallaxPlant {
    enum PlantSide {
        case left
        case right
    }
    
    let node: SKSpriteNode
    let worldY: CGFloat
    let side: PlantSide
    let parallaxFactor: CGFloat
}

class GameScene: SKScene, CollisionManagerDelegate, TooltipSafetyChecking {
    
    // MARK: - Dependencies
    weak var coordinator: GameCoordinator?
    private let collisionManager = CollisionManager()
    var initialUpgrade: String?
    
    // MARK: - Game Mode
    var gameMode: GameMode = .endless
    var boatSpeedMultiplier: CGFloat = 1.0
    var raceRewardBonus: Int = 0
    private var raceResult: RaceResult?
    private enum RaceState {
        case none
        case countdown
        case racing
        case finished
    }
    private var raceState: RaceState = .none
    
    // Daily Challenge
    private var currentChallenge: DailyChallenge?
    private var challengeRNG: SeededRandomNumberGenerator?
    // Daily Challenge Timer Properties
    private let timerLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryBold)
    private var challengeStartTime: TimeInterval = 0
    private var challengeElapsedTime: TimeInterval = 0
    
    // MARK: - Race Components
    private var boat: Boat?
    private var finishLineNode = SKShapeNode()
    private let raceProgressNode = SKNode()
    private let raceFrogIcon = SKLabelNode(text: "🐸")
    private let raceBoatIcon = SKLabelNode(text: "⛵️")
    
    // MARK: - Nodes
    private let cam = SKCameraNode()
    let worldNode = SKNode()
    private let uiNode = SKNode()
    private let trajectoryNode = SKShapeNode()
    // --- Performance Improvement: Trajectory Dots ---
    // Use a pool of sprites instead of a shape node for the trajectory.
    private var trajectoryDots: [SKSpriteNode] = []
    // Dot count is now determined by PerformanceSettings based on device capability
    private let slingshotNode = SKShapeNode()
    private let slingshotDot = SKShapeNode(circleOfRadius: 8)
    private let crosshairNode = SKShapeNode(circleOfRadius: 10)
    let weatherNode = SKNode()
    private let leafNode = SKNode()
    private let plantLeftNode = SKNode()
    private let plantRightNode = SKNode()
    
    // MARK: - Parallax Plant System
    private var parallaxPlants: [ParallaxPlant] = []
    private var plantPool: [SKSpriteNode] = []
    private var maxParallaxPlants: Int {
        // iPad needs more plants for larger screen coverage
        // Need enough plants to maintain minimum 3 per side while new ones spawn
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return isIPad ? 16 : 8  // 8 per side on iPad, 4 per side on iPhone
    }
    private var lastPlantSpawnY: CGFloat = 0
    private var plantSpawnInterval: CGFloat {
        // Spawn plants more frequently on iPad to maintain coverage
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return isIPad ? 200 : 300  // Closer spacing on iPad
    }
    
    private let waterLinesNode = SKNode()
    private var waterBackgroundNode: SKSpriteNode?
    
    // MARK: - Water Lines System (Movement Effect)
    private var waterLines: [SKSpriteNode] = []
    private let maxWaterLines: Int = 12  // Limit for performance
    
    // MARK: - Enhanced Water Effects
    private let waterShimmerNode = SKNode()
    private var shimmerParticles: [SKSpriteNode] = []
    private let maxShimmerParticles: Int = 20
    private var waterWaveTimer: TimeInterval = 0
    private var waterLineSpawnTimer: TimeInterval = 0
    private let waterLineSpawnInterval: TimeInterval = 0.8  // Spawn every 0.8 seconds
    
    // PERFORMANCE: Cache water gradient textures to avoid expensive regeneration
    private var cachedWaterTextures: [WeatherType: SKTexture] = [:]
    
    private let flotsamNode = SKNode()
    private var moonlightNode: SKSpriteNode?
    private var spaceGlowNode: SKSpriteNode?
    
    // MARK: - Moonlight Renderer
    private var moonlightRenderer: MoonlightRenderer?
    
    // MARK: - Trajectory Renderer
    private var trajectoryRenderer: TrajectoryRenderer?
    
    // MARK: - Water Stars System (Night)
    private let waterStarsNode = SKNode()
    private var waterStars: [SKSpriteNode] = []
    private let maxWaterStars: Int = 30  // Limit for performance
    private var waterStarsEnabled: Bool = false
    
    // MARK: - Shore System (PNG-based Shores)
    private let leftShoreNode = SKNode()
    private let rightShoreNode = SKNode()
    private var leftShoreSegments: [SKSpriteNode] = []
    private var rightShoreSegments: [SKSpriteNode] = []
    private let shoreSegmentHeight: CGFloat = 1200  // Height of each shore segment
    private let shoreWidth: CGFloat = 1200 // Width of the shore from river edge - MUCH WIDER to fill black areas
    private var lastShoreSpawnY: CGFloat = 0
    
    // --- Performance Improvement: Ripple Pool ---
    // A pool of reusable sprite nodes for water ripples.
    private lazy var rippleTexture: SKTexture = self.createRippleTexture()
    private lazy var cartoonArcTexture: SKTexture = self.createCartoonArcTexture()
    private var ripplePool: [SKSpriteNode] = []
    // Pool size is now determined by PerformanceSettings based on device capability
    private var frameCount: Int = 0
    private var hudUpdateCounter: Int = 0 // For throttling HUD updates
    
    // MARK: - HUD Elements
    private let scoreLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryBold)
    private let coinLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryBold)
    private let coinIcon = SKSpriteNode(imageNamed: "star")
    private var heartNodes: [SKSpriteNode] = []
    private let buffsNode = SKNode()
    private let buffsGridNode = SKNode() // Node for the new grid layout
    // --- Timed/Special Buff Nodes ---
    // These are kept for unique displays (timers, etc.)
    private var rocketBuffNode: SKNode!
    private var superJumpBuffNode: SKNode!
    private var crocRideBuffNode: SKNode!
    private let descendButton = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
    private let descendBg = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 30)
    private let pauseBg = SKShapeNode(circleOfRadius: 25)
    private let hudMargin: CGFloat = 20.0
    private let countdownLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
    private let countdownLabelShadow = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
    private let cannonJumpButton = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
    private let cannonJumpBg = SKShapeNode(rectOf: CGSize(width: 100, height: 60), cornerRadius: 30)
    private let cannonJumpIcon = SKSpriteNode(imageNamed: "cannon")
    private let jumpPromptLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
    private let jumpPromptBg = SKShapeNode(rectOf: CGSize(width: 300, height: 80), cornerRadius: 20)
    
    // MARK: - Debug HUD
    #if DEBUG
    private let fpsLabel = SKLabelNode(fontNamed: "Courier-Bold")
    private let entityCountLabel = SKLabelNode(fontNamed: "Courier-Bold")
    #endif
    
    // Achievement Notification Card
    private let achievementCard = SKNode()
    private let achievementNameLabel = SKLabelNode(fontNamed: Configuration.Fonts.achievementName.name)
    private var achievementQueue: [Challenge] = []
    private var isShowingAchievement = false
    
    // MARK: - Entities
    private let frog = Frog()
    private var pads: [Pad] = []
    private var enemies: [Enemy] = []
    private var coins: [Coin] = []
    private var crocodiles: [Crocodile] = []
    private var treasureChests: [TreasureChest] = []
    private var snakes: [Snake] = []
    private var cacti: [Cactus] = []
    private var flies: [Fly] = []
    private var flotsam: [Flotsam] = []
    
    // MARK: - Performance Optimization: Active Entity Arrays
    // Pre-allocated arrays to hold entities that are currently on-screen.
    // Cleared and re-populated each frame to avoid new array allocations.
    private var activePads: [Pad] = []
    private var activeEnemies: [Enemy] = []
    private var activeCoins: [Coin] = []
    private var activeCrocodiles: [Crocodile] = []
    private var activeTreasureChests: [TreasureChest] = []
    private var activeSnakes: [Snake] = []
    private var activeCacti: [Cactus] = []
    private var activeFlies: [Fly] = []
    
    // MARK: - State
    private var dragStartOffset: CGPoint?  // Offset from frog position when drag began
    private var dragCurrent: CGPoint?
    private var isDragging = false
    private var lastHapticDragStep: Int = 0
    private var hasTriggeredMaxPullHaptic: Bool = false
    
    // Public property to check if player is currently dragging (used by ToolTips to avoid pausing mid-drag)
    var isPlayerDragging: Bool {
        return isDragging
    }
    
    // MARK: - Tooltip Support
    
    /// Public method to check if frog is in a safe state for showing tooltips
    /// Used by ToolTips.swift to determine when it's safe to pause the game
    public func isSafeForTooltip() -> Bool {
        // Don't show if player is dragging the slingshot
        if isDragging {
            return false
        }
        
        // Don't show if frog is in the air (jumping or flying)
        if frog.zHeight > 0 {
            return false
        }
        
        // Don't show if frog is not on a pad (floating in water or in transition)
        if frog.onPad == nil {
            return false
        }
        
        return true
    }
    
    // Slingshot smoothing
    private var smoothedDotPosition: CGPoint = .zero
    private let dotSmoothingFactor: CGFloat = 0.3  // Lower = smoother but slightly laggy, Higher = more responsive
    
    // Rocket steering state
    private var rocketSteeringTouch: UITouch?
    private var rocketSteeringDirection: CGFloat = 0  // -1 for left, 1 for right, 0 for none
    private var lastUpdateTime: TimeInterval = 0
    private var score: Int = 0
    private var totalCoins: Int = 0
    private var coinsCollectedThisRun: Int = 0
    private var isGameEnding: Bool = false
    private var currentWeather: WeatherType = .sunny
    private let weatherChangeInterval: Int = 600 // in meters
    private var nextWeatherChangeScore: Int = 600
    private var isDesertTransitionPending: Bool = false
    private var hasSpawnedLaunchPad: Bool = false
    private var hasHitLaunchPad: Bool = false
    private var launchPadY: CGFloat = 0
    private var isLaunchingToSpace: Bool = false
    private var hasSpawnedWarpPad: Bool = false
    private var hasHitWarpPad: Bool = false
    private var warpPadY: CGFloat = 0
    private let launchPadMissDistance: CGFloat = 300
    private var previousRocketState: RocketState = .none
    private var previousSuperJumpState: Bool = false
    private var ridingCrocodile: Crocodile? = nil  // Currently riding crocodile
    private var crocRideVignetteNode: SKSpriteNode?  // Vignette overlay for croc ride
    private var baseMusic: SoundManager.Music = .gameplay
    private var drowningGracePeriodTimer: TimeInterval?
    private var lastKnownBuffs: Frog.Buffs?
    private var lastKnownBuffsHash: Int = 0  // PERFORMANCE: Cache hash instead of full comparison
    private var lastKnownRocketTimer: TimeInterval = 0
    private var lastKnownRocketState: RocketState = .none
    
    // MARK: - Cutscene State
    private var isInCutscene = false
    
    // MARK: - Tutorial
    private let tutorialOverlay = SKNode()
    private var tutorialFingerSprite: SKSpriteNode?
    
    // MARK: - Performance Optimization: Trajectory Throttling
    private var lastTrajectoryUpdate: TimeInterval = 0
    
    // MARK: - Challenge Tracking
    private var padsLandedThisRun: Int = 0
    private var consecutiveJumps: Int = 0
    private var bestConsecutiveJumps: Int = 0
    private var crocodilesSpawnedThisRun: Int = 0
    
    // MARK: - Hype Combo System
    private var comboCount: Int = 0
    private var maxComboThisRun: Int = 0  // Track the highest combo achieved this run
    private var lastLandTime: TimeInterval = 0
    private var comboMultiplier: Double = 1.0
    private let comboTimeout: TimeInterval = 1.0
    private weak var lastLandedPad: Pad? = nil  // Track last pad for combo validation
    private var comboPausedTime: TimeInterval = 0  // Track when combo was paused for upgrade modal
    private var lastLandingY: CGFloat = 0  // Track Y position of last landing for forward progress check
    private var consecutiveBackwardJumps: Int = 0  // Allow one backward jump, but not more
    
    // MARK: - Jump Meter System
    private let jumpMeterBg = SKShapeNode()
    private let jumpMeterFill = SKShapeNode()
    private var lastJumpTime: TimeInterval = 0
    private let jumpMeterTimeout: TimeInterval = 1.0  // 1 second window
    private var jumpMeterValue: CGFloat = 1.0  // 0.0 to 1.0
    
    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        // Apply device-specific performance optimizations first
        PerformanceSettings.apply(to: self)
        
        // PERFORMANCE: Always enable these optimizations for better performance
        view.ignoresSiblingOrder = true // Enable node reordering optimization
        view.shouldCullNonVisibleNodes = true // Cull offscreen nodes automatically
        
        // PERFORMANCE: ProMotion support for iPhone 15/16 Pro
        if PerformanceSettings.isHighEndDevice {
            view.preferredFramesPerSecond = 120 // Enable 120Hz on ProMotion displays
        } else {
            view.preferredFramesPerSecond = 60 // Standard 60Hz
        }
        
        // PERFORMANCE: Additional Metal rendering optimizations
        // Use asynchronous rendering on high-end devices for better performance
        view.isAsynchronous = PerformanceSettings.isHighEndDevice
        
        // Enable debug stats in development to monitor performance
        #if DEBUG
        view.showsFPS = false
        view.showsNodeCount = false
        view.showsDrawCount = false
        
        // Log performance baseline
        logPerformanceBaseline()
        #endif
        
        setupScene()
        setupHUD()
        setupCountdownLabel()
        setupAchievementCard()
        setupTutorialOverlay() // Setup tutorial overlay for first-time users
        setupInput()
        setupRipplePool()
        HoneyAttackAnimation.initializePool() // PERFORMANCE: Initialize honey projectile pool
        AxeAttackAnimation.initializePool() // PERFORMANCE: Initialize axe projectile pool
        SwatterAttackAnimation.initializePool() // PERFORMANCE: Initialize swatter projectile pool
        CrossAttackAnimation.initializePool() // PERFORMANCE: Initialize cross sprite pool
        preloadTextures() // PERFORMANCE: Preload textures to avoid runtime loading
        startSpawningLeaves()
        //setupPlantDecorations() // Setup decorative plants on screen edges
        //startSpawningFlotsam()
        collisionManager.delegate = self
        startGame()
        if let starter = initialUpgrade { applyUpgrade(id: starter) }
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpgrade(_:)), name: .didSelectUpgrade, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChallengeCompleted(_:)), name: .challengeCompleted, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Performance Monitoring
    
    #if DEBUG
    /// Log performance baseline information for debugging
    private func logPerformanceBaseline() {
        // Performance baseline logging removed
    }
    #endif
    
    // MARK: - Performance Optimization: Texture Preloading
    
    /// Preload commonly used textures to avoid runtime texture loading hitches
    private func preloadTextures() {
        let textureNames = [
            "star", // coin icon
            "cannon",
            "plantLeft", "plantRight" // plant decorations
        ]
        
        // Preload all textures asynchronously
        let textures = textureNames.compactMap { SKTexture(imageNamed: $0) }
        SKTexture.preload(textures) {
            // Textures preloaded
        }
    }
    
    private func setupScene() {
        // FIXED: Slightly brighter clear background allows moonlight to show better
        backgroundColor = .clear  // Transparent background, water gradient will show
        addChild(cam)
        camera = cam
        addChild(worldNode)
        worldNode.name = "GameWorld"
        
        // Add gradient water background - attached to worldNode so it moves with the world
        createWaterBackground()
        
        // Add water stars node (for night effects)
        waterStarsNode.zPosition = Layer.water + 1
        worldNode.addChild(waterStarsNode)
        
        // Add water lines node (movement effect)
        waterLinesNode.zPosition = Layer.water + 0.5  // Between water and stars
        worldNode.addChild(waterLinesNode)
        setupWaterLines()
        
        // Add water shimmer node (enhanced water effects)
        waterShimmerNode.zPosition = Layer.water + 0.3  // Just above water background
        worldNode.addChild(waterShimmerNode)
        setupWaterShimmers()
        
        // Add shore nodes (image-based shores on both sides for iPad)
        // Shores are positioned ABOVE water so they overlay it
        // The PNG files should have transparency to let water show through
        leftShoreNode.zPosition = Layer.water + 0.1  // Just above water background
        rightShoreNode.zPosition = Layer.water + 0.1
        worldNode.addChild(leftShoreNode)
        worldNode.addChild(rightShoreNode)
        setupShores()
        
        // Weather effects (rain, snow, etc.) are parented to the camera for screen-space effects
        weatherNode.zPosition = Layer.overlay - 1 // Just behind the full-screen overlay
        cam.addChild(weatherNode)
        
        // Add leaf effect node, attached to camera for screen-space effect
        leafNode.zPosition = 50 // Above the game world, but below most UI.
        cam.addChild(leafNode)
        
        // Plant decoration nodes will be added by setupPlantDecorations() to worldNode
        // (removed from here to avoid "already has a parent" error)
        
        // Add flotsam node
        flotsamNode.zPosition = Layer.water + 2 // Above leaves, below pads
        worldNode.addChild(flotsamNode)
        
        uiNode.zPosition = Layer.ui
        cam.addChild(uiNode)
        
        // --- Performance Improvement: Smooth Trajectory Renderer ---
        // Use TrajectoryRenderer for smooth curved trajectory visualization
        trajectoryRenderer = TrajectoryRenderer.createOptimized(for: worldNode)

        
        // Hide old trajectory node (kept for compatibility)
        trajectoryNode.strokeColor = .white.withAlphaComponent(0.7)
        trajectoryNode.lineWidth = 4
        trajectoryNode.lineCap = .round
        trajectoryNode.zPosition = Layer.trajectory
        trajectoryNode.isHidden = true
        worldNode.addChild(trajectoryNode)
        
        slingshotNode.strokeColor = .yellow
        slingshotNode.lineWidth = 2
        slingshotNode.alpha = 0.2
        slingshotNode.zPosition = Layer.frog + 1
        worldNode.addChild(slingshotNode)
        
        slingshotDot.fillColor = .yellow
        slingshotDot.strokeColor = .white
        slingshotDot.lineWidth = 2
        slingshotDot.zPosition = Layer.frog + 2
        slingshotDot.isHidden = true
        worldNode.addChild(slingshotDot)
        
        crosshairNode.strokeColor = .yellow
        crosshairNode.lineWidth = 3
        crosshairNode.fillColor = .clear
        crosshairNode.zPosition = Layer.trajectory + 1
        let vLine = SKShapeNode(rectOf: CGSize(width: 2, height: 20))
        vLine.fillColor = .yellow
        vLine.strokeColor = .clear
        crosshairNode.addChild(vLine)
        let hLine = SKShapeNode(rectOf: CGSize(width: 20, height: 2))
        hLine.fillColor = .yellow
        hLine.strokeColor = .clear
        crosshairNode.addChild(hLine)
        crosshairNode.isHidden = true
        worldNode.addChild(crosshairNode)

        // Add moonlight node for night scenes
        let moon = createMoonlightNode()
        self.moonlightNode = moon
        worldNode.addChild(moon)
        
        // Add space glow node for space scenes
        let spaceGlow = createSpaceBackgroundGlow()
        self.spaceGlowNode = spaceGlow
        worldNode.addChild(spaceGlow)
    }
    
    private func startSpawningLeaves() {
        // Skip leaf decorations on low-end devices for better performance
        if !PerformanceSettings.enableLeafDecorations {
            return
        }
        
        if currentWeather != .sunny {
            return
        }
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnLeaf()
        }
        // Spawn leaves more frequently for a wind-blown effect
        let waitAction = SKAction.wait(forDuration: 1.0, withRange: 1.5)
        let sequence = SKAction.sequence([spawnAction, waitAction])
        let repeatForever = SKAction.repeatForever(sequence)
        
        // Run on the scene itself, not the node, to avoid being removed
        run(repeatForever, withKey: "spawnLeaves")
    }

    private func stopSpawningLeaves() {
        removeAction(forKey: "spawnLeaves")
        leafNode.removeAllChildren()
    }

    private func spawnLeaf() {
        // Limit number of active leaves based on device performance
        let maxLeaves = PerformanceSettings.maxLeaves
        guard leafNode.children.count < maxLeaves else { return }
        
        let leafImages = ["leaf1", "leaf2", "leaf3"]
        guard let leafImage = leafImages.randomElement() else { return }

        let leaf = SKSpriteNode(imageNamed: leafImage)

        // --- Visuals ---
        let randomScale = CGFloat.random(in: 0.08...0.2)
        leaf.setScale(randomScale)
        leaf.alpha = 0 // Start invisible, fade in
        leaf.zRotation = CGFloat.random(in: 0...(2 * .pi))
        leaf.zPosition = 0 // Relative to leafNode

        // --- Positioning (in camera coordinates) ---
        let screenWidth = size.width
        let screenHeight = size.height
        
        // Determine start and end points for horizontal drift
        let fromLeft = Bool.random()
        let startX = fromLeft ? -screenWidth / 2 - 50 : screenWidth / 2 + 50
        let endX = fromLeft ? screenWidth / 2 + 50 : -screenWidth / 2 - 50
        
        // Randomize Y position
        let startY = CGFloat.random(in: -screenHeight / 2 ... screenHeight / 2)
        let endY = startY + CGFloat.random(in: -100...100) // Slight vertical drift
        
        let startPos = CGPoint(x: startX, y: startY)
        leaf.position = startPos
        
        leafNode.addChild(leaf)

        // --- Animation for blowing in the wind ---
        let driftDuration = TimeInterval.random(in: 4.0...8.0)

        // Use simplified animation on low-end devices
        if PerformanceSettings.useSimplifiedAnimations {
            // Simplified path: just linear movement with basic rotation
            let endPos = CGPoint(x: endX, y: endY)
            let moveAction = SKAction.move(to: endPos, duration: driftDuration)
            moveAction.timingMode = .easeInEaseOut
            let removeAction = SKAction.removeFromParent()
            
            // Simple rotation
            let rotationAmount = CGFloat.random(in: -2 * .pi...2 * .pi)
            let spinAction = SKAction.rotate(byAngle: rotationAmount, duration: driftDuration)
            
            // Fade in at the start
            let fadeIn = SKAction.fadeAlpha(to: CGFloat.random(in: 0.5...0.8), duration: 1.0)
            
            leaf.run(fadeIn)
            leaf.run(SKAction.sequence([
                SKAction.group([moveAction, spinAction]),
                removeAction
            ]))
        } else {
            // Full quality animation with bezier curve and tumbling
            // 1. Main movement path (Bezier curve for a natural arc)
            let endPos = CGPoint(x: endX, y: endY)
            let path = CGMutablePath()
            path.move(to: startPos)
            let controlPoint1 = CGPoint(x: startX + (endX - startX) * 0.3, y: startY + CGFloat.random(in: -150...150))
            let controlPoint2 = CGPoint(x: startX + (endX - startX) * 0.7, y: endY + CGFloat.random(in: -150...150))
            path.addCurve(to: endPos, control1: controlPoint1, control2: controlPoint2)
            
            let moveAction = SKAction.follow(path, asOffset: false, orientToPath: false, duration: driftDuration)
            let removeAction = SKAction.removeFromParent()

            // 2. Continuous spinning
            let rotationAmount = CGFloat.random(in: -6 * .pi...6 * .pi) // Spin multiple times
            let spinAction = SKAction.rotate(byAngle: rotationAmount, duration: driftDuration)
            spinAction.timingMode = .easeInEaseOut

            // 3. Tumbling effect (scaling on X-axis to simulate 3D rotation)
            let tumbleDuration = TimeInterval.random(in: 0.4...0.8)
            let tumble = SKAction.scaleX(to: 0.1, duration: tumbleDuration / 2)
            tumble.timingMode = .easeInEaseOut
            let tumbleBack = SKAction.scaleX(to: randomScale, duration: tumbleDuration / 2)
            tumbleBack.timingMode = .easeInEaseOut
            let tumbleSequence = SKAction.sequence([tumble, tumbleBack])
            let tumbleForever = SKAction.repeatForever(tumbleSequence)
            
            // Fade in at the start
            let fadeIn = SKAction.fadeAlpha(to: CGFloat.random(in: 0.5...0.8), duration: 1.0)

            // Group and run all actions together
            leaf.run(fadeIn)
            leaf.run(SKAction.sequence([
                SKAction.group([moveAction, spinAction, tumbleForever]),
                removeAction
            ]))
        }
    }
    
    // MARK: - Plant Decoration
    
    // MARK: - Plant Decoration with Parallax
    
    /// Setup the parallax plant decoration system
    private func setupPlantDecorations() {
        // Skip plant decorations on low-end devices for better performance
        if !PerformanceSettings.enablePlantDecorations {
            return
        }
        
        // Parent both plant nodes to camera for screen-space effect (always at edges)
        // Z-position behind most UI elements
        plantLeftNode.zPosition = 45  // Behind leaves, in front of gameplay
        cam.addChild(plantLeftNode)
        
        plantRightNode.zPosition = 45  // Behind leaves, in front of gameplay
        cam.addChild(plantRightNode)
        
        // Initialize the plant pool
        initializePlantPool()
        
        // Set initial spawn position
        lastPlantSpawnY = frog.position.y
        
        // Spawn initial plants around the frog's starting position
        // iPad needs more initial plants for better screen coverage (up to 12 total)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let initialPlantCount = isIPad ? 6 : 2  // 6 per side on iPad = 12 total
        
        for i in 0..<initialPlantCount {
            let offset = CGFloat(i) * (isIPad ? 150 : 200)
            spawnParallaxPlant(side: .left, atY: frog.position.y + offset)
            spawnParallaxPlant(side: .right, atY: frog.position.y + offset)
        }
    }
    
    /// Initialize a pool of reusable plant sprites for performance
    private func initializePlantPool() {
        let poolSize = maxParallaxPlants * 2  // Extra capacity for recycling
        
        for _ in 0..<poolSize {
            let plant = SKSpriteNode(imageNamed: Bool.random() ? "plantLeft" : "plantRight")
            plant.isHidden = true
            plantPool.append(plant)
        }
    }
    
    /// Get a plant sprite from the pool, or create a new one if needed
    private func getPlantFromPool(imageName: String) -> SKSpriteNode {
        // Try to find a hidden plant in the pool
        if let availablePlant = plantPool.first(where: { $0.isHidden }) {
            // Ensure the node is removed from any parent before reusing
            availablePlant.removeFromParent()
            availablePlant.texture = SKTexture(imageNamed: imageName)
            availablePlant.isHidden = false
            return availablePlant
        }
        
        // If no plants available, create a new one (shouldn't happen often)
        let plant = SKSpriteNode(imageNamed: imageName)
        plantPool.append(plant)
        return plant
    }
    
    /// Return a plant sprite to the pool
    private func returnPlantToPool(_ plant: SKSpriteNode) {
        plant.removeAllActions()
        plant.removeFromParent()
        plant.isHidden = true
        plant.alpha = 1.0
        plant.setScale(1.0)
    }
    
    /// Spawn a new parallax plant at a specific Y position
    private func spawnParallaxPlant(side: ParallaxPlant.PlantSide, atY worldY: CGFloat? = nil) {
        // Choose plant image based on side
        let plantImage = side == .left ? "plantLeft" : "plantRight"
        let plant = getPlantFromPool(imageName: plantImage)
        
        // Random scale and appearance - increased size for better visibility
        let randomScale = CGFloat.random(in: 0.6...1.0)
        plant.setScale(randomScale)
        plant.alpha = CGFloat.random(in: 0.85...0.98)
        plant.anchorPoint = CGPoint(x: 0.5, y: 0)
        
        // Parallax factor - plants further back move slower (creates depth)
        let parallaxFactor = CGFloat.random(in: 0.5...0.8)
        
        // World Y position for tracking
        // iPad needs plants spawned further ahead due to larger screen
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let spawnAheadDistance: CGFloat = isIPad ? 400 : 200
        let spawnWorldY = worldY ?? (cam.position.y + size.height / 2 + spawnAheadDistance)
        
        // Calculate initial screen-relative position
        let screenWidth = size.width
        let screenHeight = size.height
        
        // Horizontal position - at screen edges but more visible (camera-relative)
        // Reduced offset to bring plants more into the visible area
        let xOffset = CGFloat.random(in: -15...15)
        let screenX: CGFloat
        if side == .left {
            screenX = -screenWidth / 2  + xOffset // Moved further right
        } else {
            screenX = screenWidth / 2  + xOffset    // Moved further left
        }
        
        // Vertical position - screen-relative with parallax
        let relativeY = spawnWorldY - cam.position.y
        let screenY = relativeY * parallaxFactor
        
        // Position in camera/screen space
        plant.position = CGPoint(x: screenX, y: screenY)
        plant.zPosition = 0  // Relative to parent node's z-position
        
        // Add to appropriate parent node (which is attached to camera)
        let parentNode = side == .left ? plantLeftNode : plantRightNode
        parentNode.addChild(plant)
        
        // Add swaying animation
        addSwayingAnimation(to: plant)
        
        // Store in parallax plants array with world Y for tracking
        let parallaxPlant = ParallaxPlant(
            node: plant,
            worldY: spawnWorldY,
            side: side,
            parallaxFactor: parallaxFactor
        )
        parallaxPlants.append(parallaxPlant)
    }
    
    /// Update parallax plant positions based on camera movement
    private func updateParallaxPlants() {
        guard PerformanceSettings.enablePlantDecorations else { return }
        
        // PERFORMANCE: Throttle plant updates to every 3 frames for smooth but efficient updates
        if frameCount % 3 != 0 { return }
        
        let screenWidth = size.width
        let screenHeight = size.height
        let camY = cam.position.y
        
        // Update positions with parallax effect
        for i in (0..<parallaxPlants.count).reversed() {
            let parallaxPlant = parallaxPlants[i]
            let plant = parallaxPlant.node
            
            // Calculate screen-relative Y position with parallax
            // Plants are in camera space, so we calculate relative to camera position
            let relativeY = parallaxPlant.worldY - camY
            let screenY = relativeY * parallaxPlant.parallaxFactor
            
            // Horizontal position - at screen edges but more visible
            let screenX: CGFloat
            if parallaxPlant.side == .left {
                screenX = -screenWidth / 2   // Moved further right
            } else {
                screenX = screenWidth / 2   // Moved further left
            }
            
            // Update position in camera/screen space
            plant.position = CGPoint(x: screenX, y: screenY)
            
            // Remove plants that have scrolled far off the bottom of the screen
            // On iPad, keep more plants and use a much larger buffer due to larger screen
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            let minPlantsPerSide = isIPad ? 3 : 1  // Keep minimum 3 plants per side on iPad
            let plantsOnThisSide = parallaxPlants.filter { $0.side == parallaxPlant.side }.count
            
            // iPad needs a MUCH larger cull threshold due to:
            // 1. Larger screen (up to 2732 points tall on 12.9" iPad Pro)
            // 2. Parallax effect (plants move 0.5-0.8x camera speed, so they lag behind)
            // This means plants need to stay around much longer to avoid gaps
            let cullBuffer: CGFloat = isIPad ? 1200 : 500  // Much more generous on iPad
            let cullThreshold = -screenHeight / 2 - cullBuffer
            let shouldCull = screenY < cullThreshold && plantsOnThisSide > minPlantsPerSide
            
            if shouldCull {
                returnPlantToPool(plant)
                parallaxPlants.remove(at: i)
            }
        }
        
        // Spawn new plants as camera moves up
        if camY > lastPlantSpawnY + plantSpawnInterval {
            lastPlantSpawnY = camY
            
            // iPad needs more plants spawned for better coverage
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            let spawnRange = isIPad ? 2...3 : 1...2
            let leftCount = Int.random(in: spawnRange)
            let rightCount = Int.random(in: spawnRange)
            
            for _ in 0..<leftCount {
                if parallaxPlants.filter({ $0.side == .left }).count < maxParallaxPlants / 2 {
                    spawnParallaxPlant(side: .left)
                }
            }
            
            for _ in 0..<rightCount {
                if parallaxPlants.filter({ $0.side == .right }).count < maxParallaxPlants / 2 {
                    spawnParallaxPlant(side: .right)
                }
            }
        }
    }
    
    /// Add a subtle swaying animation to a plant sprite
    /// - Parameter plant: The plant sprite to animate
    private func addSwayingAnimation(to plant: SKSpriteNode) {
        // Gentle rotation to simulate wind
        let swayAmount: CGFloat = 0.05 // Small angle in radians (~3 degrees)
        let swayDuration: TimeInterval = 2.0 + TimeInterval.random(in: -0.5...0.5)
        
        let swayRight = SKAction.rotate(toAngle: swayAmount, duration: swayDuration / 2)
        swayRight.timingMode = .easeInEaseOut
        
        let swayLeft = SKAction.rotate(toAngle: -swayAmount, duration: swayDuration / 2)
        swayLeft.timingMode = .easeInEaseOut
        
        let swaySequence = SKAction.sequence([swayRight, swayLeft])
        let swayForever = SKAction.repeatForever(swaySequence)
        
        plant.run(swayForever, withKey: "swayAnimation")
    }
    
    private func startSpawningFlotsam() {
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnFlotsam()
        }
        // Spawn debris less frequently to avoid clutter
        let waitAction = SKAction.wait(forDuration: 12.0, withRange: 5.0)
        let sequence = SKAction.sequence([spawnAction, waitAction])
        run(SKAction.repeatForever(sequence), withKey: "spawnFlotsam")
    }

    private func spawnFlotsam() {
        // Determine spawn edge (left or right, outside main play area)
        let riverEdgeMargin: CGFloat = 40.0
        let spawnX: CGFloat
        if Bool.random() {
            // Left edge
            spawnX = CGFloat.random(in: 0...riverEdgeMargin)
        } else {
            // Right edge
            spawnX = CGFloat.random(in: (Configuration.Dimensions.riverWidth - riverEdgeMargin)...Configuration.Dimensions.riverWidth)
        }
        
        // Spawn ahead of the camera's view
        let spawnY = cam.position.y + (size.height / 2) + 150
        
        let flotsamItem = Flotsam(position: CGPoint(x: spawnX, y: spawnY))
        flotsamNode.addChild(flotsamItem)
        flotsam.append(flotsamItem)
        
        // Start the floating animation
        flotsamItem.float()
    }
    
    // MARK: - Water Background (Gradient-Based)
    
    /// Creates a gradient-based water background that's more performant than tiled textures
    private func createWaterBackground() {
        // PERFORMANCE FIX: Create a smaller texture for better GPU performance
        // The texture will be scaled to fill the screen
        // Extend water to cover under the shores using centralized configuration
        let backgroundSize = CGSize(
            width: Configuration.Dimensions.waterBackgroundWidth,  // riverWidth + (250*2) = 1100
            height: size.height * 1.5 // Reduced from *2 for better performance
        )
        
        // Generate the gradient texture for current weather
        let texture = createWaterGradientTexture(for: currentWeather, size: backgroundSize)
        
        // PERFORMANCE: Use linear filtering for smooth gradients
        texture.filteringMode = .linear
        
        let background = SKSpriteNode(texture: texture, size: backgroundSize)
        background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        background.position = CGPoint(
            x: Configuration.Dimensions.riverWidth / 2,
            y: 0
        )
        background.zPosition = -100
        background.name = "waterBackground"
        
        worldNode.addChild(background)
        self.waterBackgroundNode = background
        
        // Add subtle animated drift to the water
        animateWaterBackground()
    }
    
    /// Creates a gradient texture for water based on weather type
    private func createWaterGradientTexture(for weather: WeatherType, size: CGSize) -> SKTexture {
        // PERFORMANCE FIX: Check cache first to avoid expensive texture regeneration
        if let cachedTexture = cachedWaterTextures[weather] {
            return cachedTexture
        }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Define gradient colors based on weather
            let (topColor, middleColor, bottomColor) = getWaterGradientColors(for: weather)
            
            // PERFORMANCE FIX: Remove random variation - it's unique per call and prevents caching
            // Use consistent colors so the texture can be cached and reused
            
            // Create a simple 3-color gradient
            let colors = [topColor.cgColor, middleColor.cgColor, bottomColor.cgColor]
            let locations: [CGFloat] = [0.0, 0.5, 1.0]
            
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: locations
            ) else {
                return
            }
            
            // Draw the main gradient
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: 0),
                end: CGPoint(x: size.width / 2, y: size.height),
                options: []
            )
            
            // PERFORMANCE FIX: Skip noise generation - it's expensive and texture can be cached without it
            // The gradient alone provides good visual quality
        }
        
        let texture = SKTexture(image: image)
        
        // Cache the texture for future use
        cachedWaterTextures[weather] = texture
        
        return texture
    }
    
    /// Interpolates between two colors
    private func interpolateColor(from: UIColor, to: UIColor, progress: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let t = max(0, min(1, progress)) // Clamp between 0 and 1
        
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
    
    /// Adds random color variation to create light/dark variants
    private func addColorVariation(to color: UIColor, weather: WeatherType, intensity: CGFloat) -> UIColor {
        // Only add variation to water-based weather types
        guard weather == .sunny || weather == .rain || weather == .night || weather == .winter else {
            return color
        }
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Random variation that creates both lighter and darker shades
        let variation = CGFloat.random(in: -intensity...intensity)
        
        // Apply variation with clamping to valid color range
        let newR = max(0, min(1, r + variation))
        let newG = max(0, min(1, g + variation))
        let newB = max(0, min(1, b + variation))
        
        return UIColor(red: newR, green: newG, blue: newB, alpha: a)
    }
    
    /// Adjusts the brightness of a color by a given amount
    private func adjustBrightness(of color: UIColor, by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let newR = max(0, min(1, r + amount))
        let newG = max(0, min(1, g + amount))
        let newB = max(0, min(1, b + amount))
        
        return UIColor(red: newR, green: newG, blue: newB, alpha: a)
    }
    
    /// Returns gradient colors for different weather types
    private func getWaterGradientColors(for weather: WeatherType) -> (top: UIColor, middle: UIColor, bottom: UIColor) {
        switch weather {
        case .sunny:
            // Bright, tropical blue water with enhanced saturation
            let top = UIColor(red: 65/255, green: 180/255, blue: 240/255, alpha: 1.0)
            let middle = UIColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1.0)
            let bottom = UIColor(red: 30/255, green: 115/255, blue: 170/255, alpha: 1.0)
            return (top, middle, bottom)
            
        case .rain:
            // Dark, moody stormy water
            let top = UIColor(red: 50/255, green: 68/255, blue: 85/255, alpha: 1.0)
            let middle = UIColor(red: 38/255, green: 54/255, blue: 68/255, alpha: 1.0)
            let bottom = UIColor(red: 28/255, green: 42/255, blue: 55/255, alpha: 1.0)
            return (top, middle, bottom)
            
        case .night:
            // FIXED: Brighter night water - moonlit dark blue instead of near-black
            // Increased from ~3-8 to 20-45 for better visibility
            let top = UIColor(red: 25/255, green: 35/255, blue: 65/255, alpha: 1.0)
            let middle = UIColor(red: 20/255, green: 30/255, blue: 55/255, alpha: 1.0)
            let bottom = UIColor(red: 15/255, green: 25/255, blue: 45/255, alpha: 1.0)
            return (top, middle, bottom)
            
        case .winter:
            // Crisp, icy blue water
            let top = UIColor(red: 175/255, green: 205/255, blue: 230/255, alpha: 1.0)
            let middle = UIColor(red: 150/255, green: 180/255, blue: 210/255, alpha: 1.0)
            let bottom = UIColor(red: 125/255, green: 160/255, blue: 190/255, alpha: 1.0)
            return (top, middle, bottom)
            
        case .desert:
            // Warm, sandy beige (representing sand)
            let top = UIColor(red: 195/255, green: 160/255, blue: 90/255, alpha: 1.0)
            let middle = UIColor(red: 180/255, green: 145/255, blue: 75/255, alpha: 1.0)
            let bottom = UIColor(red: 160/255, green: 125/255, blue: 60/255, alpha: 1.0)
            return (top, middle, bottom)
            
        case .space:
            // Deep cosmic void with purple tint
            let top = UIColor(red: 18/255, green: 12/255, blue: 40/255, alpha: 1.0)
            let middle = UIColor(red: 12/255, green: 8/255, blue: 28/255, alpha: 1.0)
            let bottom = UIColor(red: 6/255, green: 3/255, blue: 18/255, alpha: 1.0)
            return (top, middle, bottom)
        }
    }
    
    /// Adds subtle noise/texture to the gradient for visual interest
    private func addSubtleNoise(to context: CGContext, size: CGSize, weather: WeatherType) {
        // Only add noise on high-end devices
        guard !PerformanceSettings.isLowEndDevice else { return }
        
        // Set blend mode for subtle overlay
        context.setBlendMode(.overlay)
        
        // Create random noise pattern with optimized density
        let noiseAlpha: CGFloat = weather == .desert ? 0.08 : 0.04 // 0.08 and 0.04 orign
        
        // PERFORMANCE: Reduce noise density calculation - use area-based sampling
        let noiseDensity = size.width * size.height * 0.0001 // Reduced from 0.0001
        
        for _ in 0..<Int(noiseDensity) {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let dotSize = CGFloat.random(in: 1...2) // Smaller dots
            let alpha = CGFloat.random(in: 0...noiseAlpha)
            
            context.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: CGRect(x: x, y: y, width: dotSize, height: dotSize))
        }
        
        // Reset blend mode
        context.setBlendMode(.normal)
    }
    
    /// Animates the water background with subtle drift
    private func animateWaterBackground() {
        guard let background = waterBackgroundNode else { return }
        
        // PERFORMANCE: Skip animation on low quality settings
        if PerformanceSettings.isLowEndDevice {
            return
        }
        
        // Remove any existing animations
        background.removeAction(forKey: "waterAnimation")
        
        // Enhanced: More pronounced drift on high-end devices for dynamic feel
        let driftDistance: CGFloat = PerformanceSettings.isHighEndDevice ? 25.0 : 15.0
        let driftDuration: TimeInterval = PerformanceSettings.isHighEndDevice ? 6.0 : 8.0
        
        let moveUp = SKAction.moveBy(x: 0, y: driftDistance, duration: driftDuration / 2)
        moveUp.timingMode = .easeInEaseOut
        
        let moveDown = SKAction.moveBy(x: 0, y: -driftDistance, duration: driftDuration / 2)
        moveDown.timingMode = .easeInEaseOut
        
        let sequence = SKAction.sequence([moveUp, moveDown])
        let forever = SKAction.repeatForever(sequence)
        
        background.run(forever, withKey: "waterAnimation")
        
        // Add subtle scale pulsing for wave effect on high-end devices
        if PerformanceSettings.isHighEndDevice {
            let scaleUp = SKAction.scaleX(to: 1.01, duration: 4.0)
            scaleUp.timingMode = .easeInEaseOut
            let scaleDown = SKAction.scaleX(to: 1.0, duration: 4.0)
            scaleDown.timingMode = .easeInEaseOut
            let scaleSequence = SKAction.sequence([scaleUp, scaleDown])
            let scaleForever = SKAction.repeatForever(scaleSequence)
            background.run(scaleForever, withKey: "waterWave")
        }
    }
    
    /// Updates the water background position to follow the camera
    private func updateWaterBackground() {
        guard let background = waterBackgroundNode else { return }
        
        // PERFORMANCE FIX: Only update background position if camera moved significantly
        let targetY = cam.position.y
        let currentY = background.position.y
        let deltaY = abs(targetY - currentY)
        
        // Only update if we've moved more than 5 pixels to avoid unnecessary calculations
        if deltaY > 5 {
            // Smooth follow with slight lag for depth effect
            let lerpSpeed: CGFloat = 0.15
            background.position.y += (targetY - background.position.y) * lerpSpeed
        }
    }
    
    /// Transitions the water background to a new weather type
    private func transitionWaterBackground(to weather: WeatherType, duration: TimeInterval) {
        guard let background = waterBackgroundNode else { return }
        
        if duration <= 0 {
            // Instant transition - just replace the texture
            let newTexture = createWaterGradientTexture(for: weather, size: background.size)
            background.texture = newTexture
        } else {
            // Smooth transition using cross-fade
            let newTexture = createWaterGradientTexture(for: weather, size: background.size)
            
            // Create a temporary overlay node with the new texture
            let overlay = SKSpriteNode(texture: newTexture, size: background.size)
            overlay.position = CGPoint.zero
            overlay.zPosition = 1 // Above the current background
            overlay.alpha = 0
            
            background.addChild(overlay)
            
            // Fade in the overlay
            let fadeIn = SKAction.fadeIn(withDuration: duration)
            let updateTexture = SKAction.run { [weak background, weak overlay] in
                guard let background = background, let overlay = overlay else { return }
                background.texture = overlay.texture
                overlay.removeFromParent()
            }
            
            overlay.run(SKAction.sequence([fadeIn, updateTexture]))
        }
    }
    
    /// Recreates the water background from scratch (used for major weather changes)
    private func recreateWaterBackground() {
        waterBackgroundNode?.removeFromParent()
        waterBackgroundNode = nil
        createWaterBackground()
    }
    
    // MARK: - Water Stars System (Night Mode)
    
    /// Creates and displays dynamic stars on the water surface for night weather
    private func createWaterStars() {
        // Skip on low-end devices for performance
        guard PerformanceSettings.showBackgroundEffects else {
            return
        }
        
        guard currentWeather == .night else { return }
        
        // Clear any existing stars
        removeWaterStars()
        
        // PERFORMANCE: Reduce star count for better frame rate
        let starCount: Int
        if PerformanceSettings.isVeryLowEndDevice {
            starCount = 10
        } else if PerformanceSettings.isLowEndDevice {
            starCount = 15
        } else {
            starCount = 20  // Reduced from 30 for better performance
        }
        
        // Get water bounds
        let waterWidth = Configuration.Dimensions.riverWidth
        let viewHeight = size.height
        
        // Create star texture once for efficiency
        let starTexture = createStarTexture()
        
        for i in 0..<starCount {
            let star = SKSpriteNode(texture: starTexture)
            
            // Random position across the water
            let x = CGFloat.random(in: 0...waterWidth)
            
            // Distribute stars across visible area and beyond
            let y = cam.position.y + CGFloat.random(in: -viewHeight...viewHeight * 2)
            
            star.position = CGPoint(x: x, y: y)
            star.size = CGSize(width: 4, height: 4)
            star.alpha = 0
            star.name = "waterStar"
            
            // Random color variations - bluish-white tones
            let colorVariation = CGFloat.random(in: 0.85...1.0)
            star.color = UIColor(white: colorVariation, alpha: 1.0)
            star.colorBlendFactor = 0.3
            
            waterStarsNode.addChild(star)
            waterStars.append(star)
            
            // Stagger the animations for more natural effect
            let delay = Double(i) * 0.05
            animateWaterStar(star, delay: delay)
        }
        
        waterStarsEnabled = true
    }
    
    /// Creates a simple star texture
    private func createStarTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            
            // Create a small radial gradient for the star glow
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor]
            let locations: [CGFloat] = [0.0, 1.0]
            
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: locations
            ) {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: 4,
                    options: []
                )
            }
        }
        
        return SKTexture(image: image)
    }
    
    /// Animates a single water star with twinkling and floating effects
    private func animateWaterStar(_ star: SKSpriteNode, delay: TimeInterval) {
        // Fade in
        let fadeIn = SKAction.fadeIn(withDuration: 1.0)
        fadeIn.timingMode = .easeIn
        
        // Twinkle effect - random brightness changes
        let minAlpha: CGFloat = 0.3
        let maxAlpha: CGFloat = 0.85
        
        let fadeDown = SKAction.fadeAlpha(to: CGFloat.random(in: minAlpha...(minAlpha + 0.2)), 
                                         duration: TimeInterval.random(in: 1.5...3.0))
        fadeDown.timingMode = .easeInEaseOut
        
        let fadeUp = SKAction.fadeAlpha(to: CGFloat.random(in: (maxAlpha - 0.2)...maxAlpha), 
                                       duration: TimeInterval.random(in: 1.5...3.0))
        fadeUp.timingMode = .easeInEaseOut
        
        let twinkle = SKAction.sequence([fadeDown, fadeUp])
        let twinkleForever = SKAction.repeatForever(twinkle)
        
        // Gentle floating motion to simulate water ripples
        let floatDistance: CGFloat = 3.0
        let floatDuration: TimeInterval = TimeInterval.random(in: 2.0...4.0)
        
        let moveX = SKAction.moveBy(x: CGFloat.random(in: -floatDistance...floatDistance), 
                                    y: 0, 
                                    duration: floatDuration / 2)
        moveX.timingMode = .easeInEaseOut
        
        let moveBackX = moveX.reversed()
        
        let floatSequence = SKAction.sequence([moveX, moveBackX])
        let floatForever = SKAction.repeatForever(floatSequence)
        
        // Combine all animations with initial delay
        let initialDelay = SKAction.wait(forDuration: delay)
        let startAnimations = SKAction.group([twinkleForever, floatForever])
        
        star.run(SKAction.sequence([initialDelay, fadeIn]))
        star.run(SKAction.sequence([initialDelay, SKAction.wait(forDuration: 1.0), startAnimations]))
    }
    
    /// Updates water star positions to stay visible as camera moves
    private func updateWaterStars() {
        guard waterStarsEnabled && currentWeather == .night else { return }
        
        let camY = cam.position.y
        let viewHeight = size.height
        let waterWidth = Configuration.Dimensions.riverWidth
        
        // Recycle stars that fall too far behind the camera
        for star in waterStars {
            let distanceBehindCamera = camY - star.position.y
            
            // If star is too far behind (off bottom of screen), move it ahead
            if distanceBehindCamera > viewHeight * 1.5 {
                star.position.y = camY + viewHeight + CGFloat.random(in: 0...viewHeight)
                star.position.x = CGFloat.random(in: 0...waterWidth)
            }
        }
    }
    
    /// Removes all water stars from the scene
    private func removeWaterStars() {
        // Fade out existing stars before removing
        for star in waterStars {
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            star.run(SKAction.sequence([fadeOut, remove]))
        }
        
        waterStars.removeAll()
        waterStarsEnabled = false
    }
    
    // MARK: - Water Lines System (Movement Effect)
    
    /// Creates the initial pool of water lines for the movement effect
    private func setupWaterLines() {
        // Skip on low-end devices for performance
        guard PerformanceSettings.showBackgroundEffects else {
            return
        }
        
        // Enhanced: More lines on high-end devices for richer water effect
        let lineCount = PerformanceSettings.isHighEndDevice ? 18 : maxWaterLines
        
        // Create initial set of water lines
        let waterWidth = Configuration.Dimensions.riverWidth
        let viewHeight = size.height
        let camY = cam.position.y
        
        for i in 0..<lineCount {
            let line = createWaterLine()
            
            // Distribute lines across the visible area and slightly above
            let yPos = camY - viewHeight/2 + CGFloat(i) * (viewHeight * 1.5 / CGFloat(lineCount))
            line.position = CGPoint(
                x: CGFloat.random(in: 0...waterWidth),
                y: yPos
            )
            
            waterLinesNode.addChild(line)
            waterLines.append(line)
            
            // Start with varied animation states for natural look
            animateWaterLine(line, index: i)
        }
    }
    
    /// Creates a single water line sprite with optimized rendering
    private func createWaterLine() -> SKSpriteNode {
        // PERFORMANCE: Create a simple textured line using a small cached texture
        let lineWidth: CGFloat = CGFloat.random(in: 30...80)
        let lineHeight: CGFloat = 2.0
        let lineSize = CGSize(width: lineWidth, height: lineHeight)
        
        // Create texture only once and cache it
        let renderer = UIGraphicsImageRenderer(size: lineSize)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Draw a simple white line with slight gradient for realism
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [
                                         UIColor.white.withAlphaComponent(0.0).cgColor,
                                         UIColor.white.withAlphaComponent(0.6).cgColor,
                                         UIColor.white.withAlphaComponent(0.0).cgColor
                                     ] as CFArray,
                                     locations: [0.0, 0.5, 1.0])!
            
            ctx.drawLinearGradient(gradient,
                                  start: CGPoint(x: 0, y: lineHeight/2),
                                  end: CGPoint(x: lineWidth, y: lineHeight/2),
                                  options: [])
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        
        let line = SKSpriteNode(texture: texture, size: lineSize)
        line.alpha = CGFloat.random(in: 0.3...0.6)
        line.blendMode = .add  // Additive blending for glowing effect
        
        return line
    }
    
    /// Animates a water line with flowing movement
    private func animateWaterLine(_ line: SKSpriteNode, index: Int = 0) {
        // Enhanced: Vary animation parameters based on line index for layered parallax effect
        let speedMultiplier: CGFloat = 1.0 + (CGFloat(index % 3) * 0.3) // Create 3 speed layers
        
        // Random horizontal drift to simulate water current
        let baseDriftDistance: CGFloat = PerformanceSettings.isHighEndDevice ? 40 : 25
        let driftDistance: CGFloat = CGFloat.random(in: (baseDriftDistance * 0.7)...(baseDriftDistance * 1.3)) * speedMultiplier
        let driftDuration: TimeInterval = TimeInterval.random(in: 2.0...4.0) / Double(speedMultiplier)
        
        let moveRight = SKAction.moveBy(x: driftDistance, y: 0, duration: driftDuration)
        moveRight.timingMode = .easeInEaseOut
        
        let moveLeft = SKAction.moveBy(x: -driftDistance, y: 0, duration: driftDuration)
        moveLeft.timingMode = .easeInEaseOut
        
        let drift = SKAction.sequence([moveRight, moveLeft])
        let driftForever = SKAction.repeatForever(drift)
        
        // Enhanced pulsing alpha for more organic feel
        let minAlpha: CGFloat = 0.15
        let maxAlpha: CGFloat = PerformanceSettings.isHighEndDevice ? 0.7 : 0.6
        
        let fadeOut = SKAction.fadeAlpha(to: minAlpha, duration: TimeInterval.random(in: 1.2...2.0))
        fadeOut.timingMode = .easeInEaseOut
        
        let fadeIn = SKAction.fadeAlpha(to: maxAlpha, duration: TimeInterval.random(in: 1.2...2.0))
        fadeIn.timingMode = .easeInEaseOut
        
        let pulse = SKAction.sequence([fadeOut, fadeIn])
        let pulseForever = SKAction.repeatForever(pulse)
        
        // Add subtle vertical wobble on high-end devices
        if PerformanceSettings.isHighEndDevice {
            let wobbleUp = SKAction.moveBy(x: 0, y: 2, duration: TimeInterval.random(in: 1.0...1.5))
            wobbleUp.timingMode = .easeInEaseOut
            let wobbleDown = SKAction.moveBy(x: 0, y: -2, duration: TimeInterval.random(in: 1.0...1.5))
            wobbleDown.timingMode = .easeInEaseOut
            let wobble = SKAction.sequence([wobbleUp, wobbleDown])
            let wobbleForever = SKAction.repeatForever(wobble)
            line.run(wobbleForever, withKey: "wobble")
        }
        
        line.run(driftForever, withKey: "drift")
        line.run(pulseForever, withKey: "pulse")
    }
    
    /// Updates water line positions to follow camera and recycle lines
    private func updateWaterLines(dt: TimeInterval) {
        guard PerformanceSettings.showBackgroundEffects else { return }
        guard !waterLines.isEmpty else { return }
        
        let camY = cam.position.y
        let viewHeight = size.height
        let waterWidth = Configuration.Dimensions.riverWidth
        
        // Recycle lines that fall too far behind the camera
        for line in waterLines {
            let distanceBehindCamera = camY - line.position.y
            
            // If line is too far behind (off bottom of screen), move it ahead
            if distanceBehindCamera > viewHeight * 0.8 {
                // Reposition to top of visible area
                line.position.y = camY + viewHeight * 0.6
                line.position.x = CGFloat.random(in: 0...waterWidth)
                
                // Randomize appearance for variety
                line.alpha = CGFloat.random(in: 0.3...0.6)
                line.size.width = CGFloat.random(in: 30...80)
            }
        }
    }
    
    /// Removes all water lines from the scene (e.g., during desert transition)
    private func removeWaterLines() {
        for line in waterLines {
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            line.run(SKAction.sequence([fadeOut, remove]))
        }
        
        waterLines.removeAll()
    }
    
    /// Restores water lines after returning from desert
    private func restoreWaterLines() {
        guard PerformanceSettings.showBackgroundEffects else { return }
        guard waterLines.isEmpty else { return }  // Already have lines
        
        setupWaterLines()
    }
    
    // MARK: - Water Shimmer Effects (Enhanced Dynamics)
    
    /// Creates shimmering light effects on the water surface
    private func setupWaterShimmers() {
        // Only on high-end devices for best performance
        guard PerformanceSettings.isHighEndDevice else {
            return
        }
        
        let waterWidth = Configuration.Dimensions.riverWidth
        let viewHeight = size.height
        let camY = cam.position.y
        
        for i in 0..<maxShimmerParticles {
            let shimmer = createShimmerParticle()
            
            // Distribute across visible area
            let yPos = camY - viewHeight/2 + CGFloat.random(in: 0...(viewHeight * 1.5))
            shimmer.position = CGPoint(
                x: CGFloat.random(in: 0...waterWidth),
                y: yPos
            )
            
            waterShimmerNode.addChild(shimmer)
            shimmerParticles.append(shimmer)
            
            // Animate with staggered delay
            let delay = Double(i) * 0.1
            animateShimmer(shimmer, delay: delay)
        }
    }
    
    private func updateChallengeTimer() {
        guard currentChallenge != nil else { return }
        
        challengeElapsedTime = CACurrentMediaTime() - challengeStartTime
        
        let minutes = Int(challengeElapsedTime) / 60
        let seconds = Int(challengeElapsedTime) % 60
        let tenths = Int((challengeElapsedTime.truncatingRemainder(dividingBy: 1.0)) * 10)
        
        timerLabel.text = String(format: "Time: %d:%02d.%d", minutes, seconds, tenths)
        
        // Update shadow text to match
        if let shadow = timerLabel.childNode(withName: "timerShadow") as? SKLabelNode {
            shadow.text = timerLabel.text
        }
    }
    /// Creates a single shimmer particle sprite
    private func createShimmerParticle() -> SKSpriteNode {
        let size = CGSize(width: CGFloat.random(in: 8...15), height: CGFloat.random(in: 8...15))
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Create radial gradient for shimmer effect
            let colors = [
                UIColor.white.withAlphaComponent(0.0).cgColor,
                UIColor.white.withAlphaComponent(0.8).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray
            
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0.0, 0.5, 1.0]
            ) else { return }
            
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size.width/2, y: size.height/2),
                startRadius: 0,
                endCenter: CGPoint(x: size.width/2, y: size.height/2),
                endRadius: size.width/2,
                options: []
            )
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        
        let shimmer = SKSpriteNode(texture: texture, size: size)
        shimmer.alpha = 0
        shimmer.blendMode = .add
        
        return shimmer
    }
    
    /// Animates a shimmer particle with twinkling effect
    private func animateShimmer(_ shimmer: SKSpriteNode, delay: TimeInterval) {
        // Wait before starting
        let initialDelay = SKAction.wait(forDuration: delay)
        
        // Quick fade in
        let fadeIn = SKAction.fadeAlpha(to: CGFloat.random(in: 0.4...0.7), duration: 0.3)
        fadeIn.timingMode = .easeOut
        
        // Hold briefly
        let hold = SKAction.wait(forDuration: 0.1)
        
        // Quick fade out
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.3)
        fadeOut.timingMode = .easeIn
        
        // Wait before next shimmer
        let waitBetween = SKAction.wait(forDuration: TimeInterval.random(in: 2.0...5.0))
        
        // Shimmer sequence
        let shimmerSequence = SKAction.sequence([fadeIn, hold, fadeOut, waitBetween])
        let shimmerForever = SKAction.repeatForever(shimmerSequence)
        
        // Gentle drift
        let driftX = CGFloat.random(in: -15...15)
        let driftY = CGFloat.random(in: -10...10)
        let drift = SKAction.moveBy(x: driftX, y: driftY, duration: TimeInterval.random(in: 3.0...6.0))
        drift.timingMode = .easeInEaseOut
        let driftBack = drift.reversed()
        let driftSequence = SKAction.sequence([drift, driftBack])
        let driftForever = SKAction.repeatForever(driftSequence)
        
        shimmer.run(SKAction.sequence([initialDelay, shimmerForever]), withKey: "shimmer")
        shimmer.run(driftForever, withKey: "drift")
    }
    
    /// Updates shimmer particle positions to follow camera
    private func updateWaterShimmers() {
        guard PerformanceSettings.isHighEndDevice else { return }
        guard !shimmerParticles.isEmpty else { return }
        
        let camY = cam.position.y
        let viewHeight = size.height
        let waterWidth = Configuration.Dimensions.riverWidth
        
        for shimmer in shimmerParticles {
            let distanceBehindCamera = camY - shimmer.position.y
            
            // Recycle shimmers that fall too far behind
            if distanceBehindCamera > viewHeight * 1.2 {
                shimmer.position.y = camY + viewHeight * 0.8
                shimmer.position.x = CGFloat.random(in: 0...waterWidth)
            }
        }
    }
    
    /// Removes all shimmer particles from the scene
    private func removeWaterShimmers() {
        for shimmer in shimmerParticles {
            shimmer.removeAllActions()
            shimmer.removeFromParent()
        }
        shimmerParticles.removeAll()
    }
    
    /// Restores water shimmers after returning from desert/space
    private func restoreWaterShimmers() {
        guard PerformanceSettings.isHighEndDevice else { return }
        guard shimmerParticles.isEmpty else { return }
        
        setupWaterShimmers()
    }
    
    // MARK: - Shore System (Zigzag Rugged Shores)
    
    /// Creates the initial shore segments for both left and right sides
    private func setupShores() {
        let camY = cam.position.y
        let viewHeight = size.height
        
        // Create enough shore segments to cover the initial view plus some ahead
        let segmentCount = Int(ceil(viewHeight * 2.5 / shoreSegmentHeight))
        
        for i in 0..<segmentCount {
            let yPos = camY - viewHeight + CGFloat(i) * shoreSegmentHeight
            
            // Create left shore segment
            let leftSegment = createShoreSegment(side: .left, yPosition: yPos)
            leftShoreNode.addChild(leftSegment)
            leftShoreSegments.append(leftSegment)
            
            // Create right shore segment
            let rightSegment = createShoreSegment(side: .right, yPosition: yPos)
            rightShoreNode.addChild(rightSegment)
            rightShoreSegments.append(rightSegment)
        }
        
        // Set lastShoreSpawnY to the position where the NEXT segment should spawn
        // This prevents overlaps by ensuring continuity
        lastShoreSpawnY = camY - viewHeight + CGFloat(segmentCount) * shoreSegmentHeight
    }
    
    /// Enum to specify which shore side to create
    private enum ShoreSegmentSide {
        case left
        case right
    }
    
    /// Creates a single shore segment for the specified side using PNG images
    private func createShoreSegment(side: ShoreSegmentSide, yPosition: CGFloat) -> SKSpriteNode {
        let riverWidth = Configuration.Dimensions.riverWidth
        
        // Determine which image to use based on side
        let imageName: String
        let xPosition: CGFloat
        
        if side == .left {
            imageName = "shoreLeft"
            // Position the left shore at the left edge of the river
            xPosition = 0
        } else {
            imageName = "shoreRight"
            // Position the right shore at the right edge of the river
            xPosition = riverWidth
        }
        
        // Create the sprite node with the appropriate shore image
        let segment = SKSpriteNode(imageNamed: imageName)
        
        // Ensure the shore texture tiles vertically for the segment height
        segment.size = CGSize(width: shoreWidth, height: shoreSegmentHeight)
        
        // Set anchor point based on side for proper alignment
        // Using y: 0.0 means the position.y represents the BOTTOM edge of the segment
        if side == .left {
            segment.anchorPoint = CGPoint(x: 1.0, y: 0.0)  // Right-bottom anchor (aligns to river edge)
        } else {
            segment.anchorPoint = CGPoint(x: 0.0, y: 0.0)  // Left-bottom anchor (aligns to river edge)
        }
        
        // Set the segment's position (bottom edge of the segment)
        segment.position = CGPoint(x: xPosition, y: yPosition)
        
        return segment
    }
    
   
    
    /// Updates shore segments to follow the camera and recycle old segments
    private func updateShores() {
        let camY = cam.position.y
        let viewHeight = size.height
        
        // PROACTIVE GENERATION: Spawn new shore segments ahead of the camera if needed
        // This prevents visible pop-in during fast forward movement (rocket, super jump, etc.)
        // Spawn segments when camera gets within 2 screen heights of the last spawned segment
        let spawnThreshold = viewHeight * 2.0  // Spawn further ahead to prevent pop-in
        if camY + spawnThreshold > lastShoreSpawnY {
            // Create new left shore segment
            let newLeftSegment = createShoreSegment(side: .left, yPosition: lastShoreSpawnY)
            leftShoreNode.addChild(newLeftSegment)
            leftShoreSegments.append(newLeftSegment)
            
            // Create new right shore segment
            let newRightSegment = createShoreSegment(side: .right, yPosition: lastShoreSpawnY)
            rightShoreNode.addChild(newRightSegment)
            rightShoreSegments.append(newRightSegment)
            
            // Update spawn tracker
            lastShoreSpawnY += shoreSegmentHeight
        }
        
        // REACTIVE CLEANUP: Remove shore segments that have fallen far behind the camera
        // Calculate distance from camera to the TOP of the segment
        // Since anchor point is at bottom (y: 0.0), the segment extends upward by shoreSegmentHeight
        
        // Clean up left shore segments
        leftShoreSegments.removeAll { segment in
            let segmentTopY = segment.position.y + shoreSegmentHeight
            let distanceBehindCamera = camY - segmentTopY
            
            if distanceBehindCamera > viewHeight * 2.0 {  // Increased buffer for safety
                segment.removeFromParent()
                return true
            }
            return false
        }
        
        // Clean up right shore segments
        rightShoreSegments.removeAll { segment in
            let segmentTopY = segment.position.y + shoreSegmentHeight
            let distanceBehindCamera = camY - segmentTopY
            
            if distanceBehindCamera > viewHeight * 2.0 {  // Increased buffer for safety
                segment.removeFromParent()
                return true
            }
            return false
        }
    }
    
    /// Removes all shore segments (e.g., during space transition)
    private func removeShores() {
        for segment in leftShoreSegments {
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            segment.run(SKAction.sequence([fadeOut, remove]))
        }
        
        for segment in rightShoreSegments {
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            segment.run(SKAction.sequence([fadeOut, remove]))
        }
        
        leftShoreSegments.removeAll()
        rightShoreSegments.removeAll()
    }
    
    /// Restores shores after returning to normal environment
    private func restoreShores() {
        guard leftShoreSegments.isEmpty else { return }  // Already have shores
        setupShores()
    }
    
    private func createMoonlightNode() -> SKSpriteNode {
        // The node needs to be large enough to cover the screen even with parallax.
        // 2x screen size is a safe bet.
        let nodeSize = CGSize(width: size.width * 4, height: size.height * 4)
        
        // Create the gradient texture programmatically.
        let renderer = UIGraphicsImageRenderer(size: nodeSize)
        let image = renderer.image { context in
            let center = CGPoint(x: nodeSize.width / 2, y: nodeSize.height / 2)
            let radius = nodeSize.width / 2
            
            // FIXED: Much brighter moonlight - increased from 0.28 to 0.6 alpha
            // Soft blue-white glow that actually illuminates the scene
            let colors = [UIColor.blue.withAlphaComponent(0.9).cgColor, UIColor.clear.cgColor]
            let locations: [CGFloat] = [0.0, 1.0]
            
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: colors as CFArray,
                                          locations: locations) {
                context.cgContext.drawRadialGradient(gradient,
                                                      startCenter: center, startRadius: 0,
                                                      endCenter: center, endRadius: radius,
                                                      options: [])
            }
        }
        
        let texture = SKTexture(image: image)
        let node = SKSpriteNode(texture: texture, size: nodeSize)
        
        // Position it above the water tiles (-100) but below everything else on the water.
        node.zPosition = -99
        
        // Additive blending creates a realistic lighting effect.
        node.blendMode = .add
        
        // Start hidden.
        node.isHidden = true
        
        return node
    }
    
    /// Creates a space background glow with purple/blue nebula effect
    private func createSpaceBackgroundGlow() -> SKSpriteNode {
        let nodeSize = CGSize(width: size.width * 2, height: size.height * 2)
        
        let renderer = UIGraphicsImageRenderer(size: nodeSize)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Create multiple gradient overlays for a nebula effect
            
            // Bottom gradient - purple glow
            let bottomCenter = CGPoint(x: nodeSize.width / 2, y: nodeSize.height * 0.3)
            let bottomRadius = nodeSize.height * 0.6
            let purpleColors = [
                UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 0.4).cgColor,
                UIColor(red: 0.2, green: 0.1, blue: 0.3, alpha: 0.2).cgColor,
                UIColor.clear.cgColor
            ]
            let purpleLocations: [CGFloat] = [0.0, 0.5, 1.0]
            
            if let purpleGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                               colors: purpleColors as CFArray,
                                               locations: purpleLocations) {
                ctx.drawRadialGradient(purpleGradient,
                                       startCenter: bottomCenter, startRadius: 0,
                                       endCenter: bottomCenter, endRadius: bottomRadius,
                                       options: [])
            }
            
            // Top gradient - blue glow
            let topCenter = CGPoint(x: nodeSize.width * 0.7, y: nodeSize.height * 0.7)
            let topRadius = nodeSize.height * 0.5
            let blueColors = [
                UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.3).cgColor,
                UIColor(red: 0.1, green: 0.2, blue: 0.4, alpha: 0.15).cgColor,
                UIColor.clear.cgColor
            ]
            let blueLocations: [CGFloat] = [0.0, 0.5, 1.0]
            
            if let blueGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                             colors: blueColors as CFArray,
                                             locations: blueLocations) {
                ctx.drawRadialGradient(blueGradient,
                                       startCenter: topCenter, startRadius: 0,
                                       endCenter: topCenter, endRadius: topRadius,
                                       options: [])
            }
            
            // Add some "stars" (small white dots)
            ctx.setFillColor(UIColor.white.cgColor)
            for _ in 0..<50 {
                let x = CGFloat.random(in: 0...nodeSize.width)
                let y = CGFloat.random(in: 0...nodeSize.height)
                let size = CGFloat.random(in: 1...3)
                let alpha = CGFloat.random(in: 0.3...0.8)
                ctx.setAlpha(alpha)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
            }
        }
        
        let texture = SKTexture(image: image)
        let node = SKSpriteNode(texture: texture, size: nodeSize)
        node.zPosition = -99
        node.blendMode = .add
        node.name = "spaceGlow"
        
        // Start hidden - will be shown when transitioning to space weather
        node.isHidden = true
        
        return node
    }
    
    // MARK: - Legacy Water Methods (Deprecated)
    
    /// Legacy method - replaced by gradient background system
    private func getWaterTextureName() -> String {
        return "deprecated"
    }
    
    /// Legacy method - replaced by updateWaterBackground()
    private func updateWaterVisuals() {
        // Simply update the water background position now
        updateWaterBackground()
    }
    
    // MARK: - Water Ripples (Optimized)
    
    private func createRippleTexture() -> SKTexture {
        let size = CGSize(width: 128, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2
            
            // A soft, white circle that can be tinted to create a shadow.
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
            let locations: [CGFloat] = [0.0, 1.0]
            
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: colors as CFArray,
                                          locations: locations) {
                context.cgContext.drawRadialGradient(gradient,
                                                      startCenter: center, startRadius: 0,
                                                      endCenter: center, endRadius: radius,
                                                      options: [])
            }
        }
        return SKTexture(image: image)
    }
    
    /// Creates a cartoon-style arc ripple texture (half-circle outline)
    private func createCartoonArcTexture() -> SKTexture {
        let size = CGSize(width: 128, height: 64) // Half height for arc
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Draw a thick arc (half circle outline)
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(6)
            ctx.setLineCap(.round)
            
            // Create arc path (bottom half of circle)
            let center = CGPoint(x: size.width / 2, y: size.height)
            let radius: CGFloat = size.width / 2 - 3
            
            ctx.addArc(center: center, radius: radius, startAngle: .pi, endAngle: 0, clockwise: false)
            ctx.strokePath()
        }
        return SKTexture(image: image)
    }
    
    private func setupRipplePool() {
        let poolSize = PerformanceSettings.ripplePoolSize
        for _ in 0..<poolSize {
            let ripple = SKSpriteNode(texture: rippleTexture)
            ripple.isHidden = true
            // Use alpha blending for shadows instead of additive for light.
            ripple.blendMode = .alpha
            ripplePool.append(ripple)
        }
    }
    
    private func spawnRipples(parentedTo node: SKNode, color: UIColor, rippleCount: Int, isDramatic: Bool) {
        // PERFORMANCE: Limit ripple count based on device capability
        let maxRipples = PerformanceSettings.maxRipplesPerImpact
        let actualRippleCount = min(rippleCount, maxRipples)
        
        let delayBetweenRipples = isDramatic ? 0.01 : 0.02
        
        for i in 0..<actualRippleCount {
            if i == 0 {
                // Spawn first ripple immediately for instant feedback
                if isDramatic {
                    spawnSingleDramaticRipple(parentedTo: node, color: color)
                } else {
                    spawnSingleRipple(parentedTo: node, color: color)
                }
            } else {
                // Spawn subsequent ripples with a slight delay
                let delay = (Double(i) * delayBetweenRipples)
                
                run(SKAction.wait(forDuration: delay)) { [weak self] in
                    if isDramatic {
                        self?.spawnSingleDramaticRipple(parentedTo: node, color: color)
                    } else {
                        self?.spawnSingleRipple(parentedTo: node, color: color)
                    }
                }
            }
        }
    }

    private func spawnSingleRipple(parentedTo node: SKNode, color: UIColor) {
        guard let ripple = ripplePool.first(where: { $0.parent == nil }) else { return }
    
        ripple.isHidden = false
        ripple.color = color
        ripple.colorBlendFactor = 1.0
        // Use a lower alpha for a more subtle shadow effect.
        ripple.alpha = 0.2
        ripple.setScale(0.1)
        // Position the ripple at the lilypad's location in the world
        ripple.position = node.position
        // Set zPosition to be below pads but above water
        ripple.zPosition = Layer.water + 1
        
        // Add to the worldNode, not the lilypad node
        worldNode.addChild(ripple)
        
        let scaleUp = SKAction.scale(to: 1.0, duration: 1.5)
        scaleUp.timingMode = .easeOut
        let fadeOut = SKAction.fadeOut(withDuration: 1.5)
        
        let group = SKAction.group([scaleUp, fadeOut])
        ripple.run(SKAction.sequence([group, .removeFromParent()]))
    }

    private func spawnSingleDramaticRipple(parentedTo node: SKNode, color: UIColor) {
        guard let ripple = ripplePool.first(where: { $0.parent == nil }) else { return }
    
        ripple.isHidden = false
        ripple.color = color
        ripple.colorBlendFactor = 1.0
        ripple.alpha = 1.0
        ripple.setScale(0.1)
        // Position the ripple at the parent's location in the world
        ripple.position = node.position
        // Set zPosition to be below pads but above water
        ripple.zPosition = Layer.water + 1
    
        // Add to the worldNode, not the lilypad node
        worldNode.addChild(ripple)
        
        let scaleUp = SKAction.scale(to: 1.2, duration:0.8)
        scaleUp.timingMode = .easeOut
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        
        let group = SKAction.group([scaleUp, fadeOut])
        ripple.run(SKAction.sequence([group, .removeFromParent()]))
    }

    /// Spawns animated water ripples parented to the specified node.
    private func spawnWaterRipple(for node: SKNode) {
        // In space, spawn laser blast instead of ripples
        if currentWeather == .space {
            // Calculate frog's landing position relative to the pad
            let frogOffset = CGPoint(
                x: frog.position.x - node.position.x,
                y: frog.position.y - node.position.y
            )
            spawnLaserBlast(from: node, frogOffset: frogOffset)
            return
        }
        
        // Spawns cartoon-style circle ripples that appear immediately
        spawnCartoonCircleRipples(at: node.position)
    }
    
    // MARK: - Hype Combo Visual Feedback
    
    /// Shows a special popup when combo invincibility mode is activated (25+ combo)
    private func showComboInvincibilityPopup(at position: CGPoint) {
        let comboLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
        comboLabel.text = "⚡ INVINCIBLE! ⚡"
        comboLabel.fontSize = 50
        comboLabel.fontColor = .yellow
        comboLabel.position = CGPoint(x: position.x, y: position.y + 80)
        comboLabel.zPosition = Layer.ui
        comboLabel.alpha = 0
        
        // Add a glowing outline effect
        let outline = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
        outline.text = comboLabel.text
        outline.fontSize = comboLabel.fontSize
        outline.fontColor = .orange
        outline.position = .zero
        outline.zPosition = -1
        outline.setScale(1.15)
        outline.alpha = 0.8
        comboLabel.addChild(outline)
        
        worldNode.addChild(comboLabel)
        
        // Create dramatic animations
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.3, duration: 0.2)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
        let wait = SKAction.wait(forDuration: 1.5)
        let moveUp = SKAction.moveBy(x: 0, y: 100, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        
        let scaleSequence = SKAction.sequence([scaleUp, scaleDown])
        let appearGroup = SKAction.group([fadeIn, scaleSequence])
        let disappearGroup = SKAction.group([moveUp, fadeOut])
        let fullSequence = SKAction.sequence([appearGroup, wait, disappearGroup, .removeFromParent()])
        
        comboLabel.run(fullSequence)
        
        // Add extra sparkle effect
        VFXManager.shared.spawnSparkles(at: position, in: self)
        VFXManager.shared.spawnSparkles(at: CGPoint(x: position.x - 30, y: position.y), in: self)
        VFXManager.shared.spawnSparkles(at: CGPoint(x: position.x + 30, y: position.y), in: self)
    }
    
    /// Shows a combo popup animation at the specified position
    private func showComboPopup(at position: CGPoint, count: Int) {
        // Create the combo label
        let comboLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
        comboLabel.text = "\(count)x COMBO!"
        comboLabel.fontSize = count >= 5 ? 40 : 32
        comboLabel.fontColor = count >= 10 ? .systemPink : count >= 5 ? .systemOrange : .systemYellow
        comboLabel.position = CGPoint(x: position.x, y: position.y + 60)
        comboLabel.zPosition = Layer.ui
        comboLabel.alpha = 0
        
        // Add a glowing outline effect
        let outline = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
        outline.text = comboLabel.text
        outline.fontSize = comboLabel.fontSize
        outline.fontColor = .white
        outline.position = .zero
        outline.zPosition = -1
        outline.setScale(1.1)
        outline.alpha = 0.5
        comboLabel.addChild(outline)
        
        worldNode.addChild(comboLabel)
        
        // Create animations
        let fadeIn = SKAction.fadeIn(withDuration: 0.15)
        let scaleUp = SKAction.scale(to: 1.3, duration: 0.2)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        scaleDown.timingMode = .easeIn
        let wait = SKAction.wait(forDuration: 0.4)
        let moveUp = SKAction.moveBy(x: 0, y: 40, duration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        
        // Combine animations
        let scaleSequence = SKAction.sequence([scaleUp, scaleDown])
        let appearGroup = SKAction.group([fadeIn, scaleSequence])
        let disappearGroup = SKAction.group([moveUp, fadeOut])
        let fullSequence = SKAction.sequence([appearGroup, wait, disappearGroup, .removeFromParent()])
        
        comboLabel.run(fullSequence)
        
        // Add sparkle effect for high combos
        if count >= 3 {
            VFXManager.shared.spawnSparkles(at: position, in: self)
        }
    }
    
    /// Spawns a laser blast from the edge of the lily pad that shoots across the screen (space weather only)
    private func spawnLaserBlast(from node: SKNode, frogOffset: CGPoint) {
        // Get the lily pad's radius to calculate relative position
        let padRadius: CGFloat
        if let pad = node as? Pad {
            padRadius = pad.scaledRadius
        } else {
            padRadius = 30  // Default fallback
        }
        
        // Calculate the distance from center as a ratio (0 = center, 1 = edge)
        let distanceFromCenter = sqrt(frogOffset.x * frogOffset.x + frogOffset.y * frogOffset.y)
        let normalizedDistance = min(distanceFromCenter / padRadius, 1.0)
        
        // Define center threshold - within 20% of radius is considered center
        let centerThreshold: CGFloat = 0.2
        
        // Determine laser angle based on frog landing position
        let angle: CGFloat
        if normalizedDistance <= centerThreshold {
            // Frog landed near center - choose random direction
            angle = CGFloat.random(in: 0..<(.pi * 2))
        } else {
            // Calculate angle from pad center to frog landing position
            // Use the raw angle directly - no snapping to increments
            angle = atan2(frogOffset.y, frogOffset.x)
        }
        
        // Calculate the starting position at the edge of the lily pad
        let edgeOffsetX = cos(angle) * padRadius
        let edgeOffsetY = sin(angle) * padRadius
        let startPosition = CGPoint(
            x: node.position.x + edgeOffsetX,
            y: node.position.y + edgeOffsetY
        )
        
        // Create a short red laser bolt
        let laserLength: CGFloat = 40  // Short bolt
        let laserWidth: CGFloat = 6
        
        let laser = SKShapeNode(rectOf: CGSize(width: laserLength, height: laserWidth))
        laser.fillColor = .red
        laser.strokeColor = UIColor(red: 1.0, green: 0.3, blue: 0.0, alpha: 1.0)  // Orange-red outline
        laser.lineWidth = 2
        laser.position = startPosition
        laser.zPosition = Layer.pad + 1 // Above the lily pad
        laser.zRotation = angle
        laser.name = "spaceLaser" // Tag for collision detection
        
        // Add a bright glowing core
        let core = SKShapeNode(rectOf: CGSize(width: laserLength * 0.6, height: laserWidth * 0.5))
        core.fillColor = UIColor(red: 1.0, green: 0.9, blue: 0.8, alpha: 1.0)  // Bright yellow-white core
        core.strokeColor = .clear
        core.zPosition = 1
        laser.addChild(core)
        
        worldNode.addChild(laser)
        
        // Calculate travel distance based on angle direction
        let travelDistance: CGFloat = 1000  // Fixed distance for all lasers
        let speed: CGFloat = 800  // pixels per second
        let travelDuration = TimeInterval(travelDistance / speed)
        
        // Animate: move in the direction of the angle
        let moveX = cos(angle) * travelDistance
        let moveY = sin(angle) * travelDistance
        let move = SKAction.moveBy(x: moveX, y: moveY, duration: travelDuration)
        move.timingMode = SKActionTimingMode.linear
        
        let remove = SKAction.removeFromParent()
        
        // Check for collisions during travel
        let checkCollisions = SKAction.run { [weak self, weak laser] in
            guard let self = self, let laser = laser else { return }
            self.checkLaserCollisions(laser: laser, direction: angle, length: laserLength)
        }
        
        // Check collisions every 0.05 seconds during travel
        let collisionCheck = SKAction.sequence([
            checkCollisions,
            SKAction.wait(forDuration: 0.05)
        ])
        let repeatCollisionCheck = SKAction.repeat(collisionCheck, count: Int(travelDuration / 0.05))
        
        laser.run(SKAction.group([move, repeatCollisionCheck]))
        laser.run(SKAction.sequence([SKAction.wait(forDuration: travelDuration), remove]))
        
        // Play laser sound
        SoundManager.shared.play("laser")
        
        // Light haptic feedback
        HapticsManager.shared.playImpact(.light)
    }
    
    /// Checks if the laser beam hits any enemies and destroys them
    private func checkLaserCollisions(laser: SKNode, direction angle: CGFloat, length: CGFloat) {
        // Calculate the laser's endpoint based on its direction
        let startPos = laser.position
        let endX = startPos.x + cos(angle) * length
        let endY = startPos.y + sin(angle) * length
        let endPos = CGPoint(x: endX, y: endY)
        
        // Check all active enemies
        var enemiesToDestroy: [Enemy] = []
        
        for enemy in activeEnemies {
            // Check if enemy is within the laser's path (line segment collision)
            if isPoint(enemy.position, nearLineFrom: startPos, to: endPos, tolerance: 20) {
                enemiesToDestroy.append(enemy)
            }
        }
        
        // Destroy hit enemies with dramatic effects
        for enemy in enemiesToDestroy {
            // Remove from scene
            enemy.removeFromParent()
            if let idx = enemies.firstIndex(of: enemy) {
                enemies.remove(at: idx)
            }
            
            // Visual feedback - different colors based on enemy type
            let debrisColor: UIColor
            switch enemy.type {
            case "BEE":
                debrisColor = UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)  // Yellow
            case "DRAGONFLY":
                debrisColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)  // Blue
            case "GHOST":
                debrisColor = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)  // Pale ghostly
            default:
                debrisColor = .cyan
            }
            
            // Spawn debris explosion
            VFXManager.shared.spawnDebris(at: enemy.position, in: self, color: debrisColor, intensity: 1.2)
            
            // Spawn sparkles for extra sci-fi effect
            VFXManager.shared.spawnSparkles(at: enemy.position, in: self)
            
            // Audio and haptic feedback
            SoundManager.shared.play("hit")
            HapticsManager.shared.playImpact(.medium)
            
            // Track for challenges
            ChallengeManager.shared.recordEnemyDefeated()
        }
    }
    
    /// Checks if a point is near a line segment (for laser collision detection)
    private func isPoint(_ point: CGPoint, nearLineFrom start: CGPoint, to end: CGPoint, tolerance: CGFloat) -> Bool {
        // Vector from start to end
        let lineVec = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let lineLength = sqrt(lineVec.x * lineVec.x + lineVec.y * lineVec.y)
        
        // Normalize the line vector
        let lineDir = CGPoint(x: lineVec.x / lineLength, y: lineVec.y / lineLength)
        
        // Vector from start to point
        let startToPoint = CGPoint(x: point.x - start.x, y: point.y - start.y)
        
        // Project point onto line
        let projection = startToPoint.x * lineDir.x + startToPoint.y * lineDir.y
        
        // Clamp projection to line segment
        let clampedProjection = max(0, min(lineLength, projection))
        
        // Find closest point on line segment
        let closestPoint = CGPoint(
            x: start.x + lineDir.x * clampedProjection,
            y: start.y + lineDir.y * clampedProjection
        )
        
        // Calculate distance from point to closest point on line
        let dx = point.x - closestPoint.x
        let dy = point.y - closestPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        
        return distance <= tolerance
    }
    
    /// Spawns cartoon-style circle ripples (3 concentric circles) at the specified position
    private func spawnCartoonCircleRipples(at position: CGPoint) {
        let circleCount = 2
        let delayBetweenCircles: TimeInterval = 0.04
        
        for i in 0..<circleCount {
            if i == 0 {
                // Spawn first ripple immediately for instant feedback
                spawnSingleCartoonCircle(at: position, index: i)
            } else {
                // Spawn subsequent ripples with a slight delay
                let delay = Double(i) * delayBetweenCircles
                
                run(SKAction.wait(forDuration: delay)) { [weak self] in
                    self?.spawnSingleCartoonCircle(at: position, index: i)
                }
            }
        }
    }
    
    /// Spawns a single cartoon circle ripple
    private func spawnSingleCartoonCircle(at position: CGPoint, index: Int) {
        // Start slightly larger for each successive circle
        let startRadius: CGFloat = 5.0 + (CGFloat(index) * 10.0)
        
        // Create a circle shape node with stroke (no fill for a ring effect)
        let circle = SKShapeNode(circleOfRadius: startRadius)
        circle.strokeColor = .white
        circle.lineWidth = 2
        circle.fillColor = .clear
        circle.alpha = 0.7
        circle.position = position
        circle.zPosition = Layer.water + 1
        
        worldNode.addChild(circle)
        
        // Animate: expand outward and fade
        let duration: TimeInterval = 0.8
        let finalRadius: CGFloat = 60.0 + (CGFloat(index) * 20.0)
        
        // Create scaling animation
        let scaleRatio = finalRadius / startRadius
        let scaleUp = SKAction.scale(to: scaleRatio, duration: duration)
        scaleUp.timingMode = .easeOut
        
        let fadeOut = SKAction.fadeOut(withDuration: duration)
        fadeOut.timingMode = .easeIn
        
        let group = SKAction.group([scaleUp, fadeOut])
        let remove = SKAction.removeFromParent()
        
        circle.run(SKAction.sequence([group, remove]))
    }
    
    private func setupHUD() {
        scoreLabel.text = "0m"
        scoreLabel.fontSize = Configuration.Fonts.hudScore.size
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: 0, y: (size.height / 2) - 110)
        let scoreShadow = SKLabelNode(fontNamed: Configuration.Fonts.primaryBold)
        scoreShadow.fontColor = .black
        scoreShadow.alpha = 0.5
        scoreShadow.position = CGPoint(x: 2, y: -2)
        scoreShadow.zPosition = -1
        scoreLabel.addChild(scoreShadow)
        uiNode.addChild(scoreLabel)
        
        // Daily Challenge Timer (positioned below distance)
        // Always set up the timer label, will be shown/hidden based on game mode
        timerLabel.text = "Time: 0:00.0"
        timerLabel.fontSize = 18
        timerLabel.fontColor = .white
        timerLabel.position = CGPoint(x: 0, y: (size.height / 2) - 140)
        timerLabel.horizontalAlignmentMode = .center
        timerLabel.verticalAlignmentMode = .baseline
        let timerShadow = SKLabelNode(fontNamed: Configuration.Fonts.primaryBold)
        timerShadow.text = "Time: 0:00.0"
        timerShadow.fontSize = 18
        timerShadow.fontColor = .black
        timerShadow.alpha = 0.5
        timerShadow.position = CGPoint(x: 2, y: -2)
        timerShadow.zPosition = -1
        timerShadow.horizontalAlignmentMode = .center
        timerShadow.verticalAlignmentMode = .baseline
        timerShadow.name = "timerShadow"
        timerLabel.addChild(timerShadow)
        timerLabel.isHidden = true // Hidden by default, will be shown when challenge starts
        uiNode.addChild(timerLabel)
        
        coinIcon.size = CGSize(width: 24, height: 24)
        coinIcon.position = CGPoint(x: (size.width / 2) - hudMargin - 50, y: (size.height / 2) - 90)
        uiNode.addChild(coinIcon)
        
        coinLabel.text = "0"
        coinLabel.fontSize = Configuration.Fonts.hudCoins.size
        coinLabel.fontColor = .yellow
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: (size.width / 2) - hudMargin - 30, y: (size.height / 2) - 100)
        uiNode.addChild(coinLabel)
        
        // MARK: - Jump Meter Setup
        setupJumpMeter()
        
        drawHearts()
        buffsNode.position = CGPoint(x: -(size.width / 2) + hudMargin, y: (size.height / 2) - 140)
        uiNode.addChild(buffsNode)
        
        // --- Create timed/special buff indicators ---
        // This helper creates the vertical list of timed buffs (Rocket, Super Jump, etc.)
        func createTimedBuffIndicator(color: UIColor, iconName: String? = nil) -> SKNode {
            let node = SKNode()
            let bg = SKShapeNode(rectOf: CGSize(width: 120, height: 24), cornerRadius: 12)
            bg.fillColor = .black.withAlphaComponent(0.5)
            bg.strokeColor = color
            bg.lineWidth = 2
            bg.position = CGPoint(x: 60, y: 0)
            bg.name = "background"

            let lbl = SKLabelNode(fontNamed: Configuration.Fonts.buffIndicator.name)
            lbl.text = ""
            lbl.fontSize = Configuration.Fonts.buffIndicator.size
            lbl.fontColor = .white
            lbl.verticalAlignmentMode = .center
            lbl.name = "label"
            lbl.zPosition = 1 // Ensure the label is drawn on top of the icon.
            bg.addChild(lbl)

            if let iconName = iconName {
                let icon = SKSpriteNode(imageNamed: iconName)
                icon.size = CGSize(width: 16, height: 16)
                icon.name = "icon"
                bg.addChild(icon)
                icon.position = CGPoint(x: -45, y: 0)
                lbl.horizontalAlignmentMode = .left
                lbl.position = CGPoint(x: -30, y: 0)
            } else {
                lbl.horizontalAlignmentMode = .center
                lbl.position = CGPoint(x: 0, y: 0)
            }

            node.addChild(bg)
            node.isHidden = true
            return node
        }

        rocketBuffNode = createTimedBuffIndicator(color: .red, iconName: "rocket")
        superJumpBuffNode = createTimedBuffIndicator(color: .cyan, iconName:  "lightning")
        crocRideBuffNode = createTimedBuffIndicator(color: .green)
        
        buffsNode.addChild(buffsGridNode) // Add container for grid items
        buffsNode.addChild(rocketBuffNode)
        buffsNode.addChild(superJumpBuffNode)
        buffsNode.addChild(crocRideBuffNode)
        
        // All bottom-anchored UI should respect the safe area.
        let bottomSafeArea = view?.safeAreaInsets.bottom ?? 0
        let screenBottomY = -(size.height / 2)
        
        pauseBg.fillColor = .black.withAlphaComponent(0.5)
        pauseBg.strokeColor = .white
        pauseBg.lineWidth = 2
        pauseBg.position = CGPoint(x: 0, y: screenBottomY + bottomSafeArea + 60)
        let pauseIcon = SKLabelNode(text: "II")
        pauseIcon.fontName = Configuration.Fonts.pauseIcon.name
        pauseIcon.fontSize = Configuration.Fonts.pauseIcon.size
        pauseIcon.verticalAlignmentMode = .center
        pauseIcon.horizontalAlignmentMode = .center
        pauseIcon.fontColor = .white
        pauseBg.addChild(pauseIcon)
        uiNode.addChild(pauseBg)
        
        descendBg.fillColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1)
        descendBg.strokeColor = .white
        descendBg.lineWidth = 3
        descendBg.position = CGPoint(x: 0, y: screenBottomY + bottomSafeArea + 140)
        descendBg.isHidden = true
        uiNode.addChild(descendBg)
        descendButton.text = "DESCEND!"
        descendButton.fontSize = Configuration.Fonts.descendButton.size
        descendButton.verticalAlignmentMode = .center
        descendButton.fontColor = .white
        descendBg.addChild(descendButton)

        // Cannon Jump Button
        cannonJumpBg.fillColor = UIColor(red: 142/255, green: 68/255, blue: 173/255, alpha: 1.0) // Purple
        cannonJumpBg.strokeColor = .white
        cannonJumpBg.lineWidth = 3
        cannonJumpBg.position = CGPoint(x: 100, y: screenBottomY + bottomSafeArea + 60)
        
        cannonJumpBg.isHidden = true // Hide until unlocked
        uiNode.addChild(cannonJumpBg)
        cannonJumpButton.fontSize = Configuration.Fonts.descendButton.size
        cannonJumpButton.verticalAlignmentMode = .center
        cannonJumpButton.fontColor = .white
        cannonJumpBg.addChild(cannonJumpButton)
        cannonJumpIcon.size = CGSize(width: 30, height: 30)
        cannonJumpBg.addChild(cannonJumpIcon)
        
        setupRaceHUD()
        
        // Drowning Grace Period Prompt
        jumpPromptBg.fillColor = .black.withAlphaComponent(0.7)
        jumpPromptBg.strokeColor = .red
        jumpPromptBg.lineWidth = 3
        jumpPromptBg.position = CGPoint(x: 0, y: 0) // Centered
        jumpPromptBg.isHidden = true
        uiNode.addChild(jumpPromptBg)
        
        jumpPromptLabel.text = "JUMP NOW!"
        jumpPromptLabel.fontSize = 32
        jumpPromptLabel.fontColor = .white
        jumpPromptLabel.verticalAlignmentMode = .center
        jumpPromptBg.addChild(jumpPromptLabel)
        
        // MARK: - Debug FPS Display
       // #if DEBUG
      //  setupDebugHUD()
     //   #endif
    }
    
    #if DEBUG
    private func setupDebugHUD() {
        // FPS Counter
        fpsLabel.fontSize = 16
        fpsLabel.fontColor = .green
        fpsLabel.text = "FPS: --"
        fpsLabel.horizontalAlignmentMode = .left
        fpsLabel.position = CGPoint(x: -(size.width / 2) + hudMargin, y: (size.height / 2) - 40)
        fpsLabel.zPosition = 1000
        uiNode.addChild(fpsLabel)
        
        // Entity Count Display
        entityCountLabel.fontSize = 14
        entityCountLabel.fontColor = .yellow
        entityCountLabel.text = "Entities: --"
        entityCountLabel.horizontalAlignmentMode = .left
        entityCountLabel.position = CGPoint(x: -(size.width / 2) + hudMargin, y: (size.height / 2) - 65)
        entityCountLabel.zPosition = 1000
        uiNode.addChild(entityCountLabel)
    }
    #endif
    
    // MARK: - Jump Meter
    
    private func setupJumpMeter() {
        // Dimensions
        let meterWidth: CGFloat = 12
        let meterHeight: CGFloat = 200
        let cornerRadius: CGFloat = 6
        
        // Position on right side of screen, vertically centered
        let xPos = (size.width / 2) - hudMargin - meterWidth / 2
        let yPos: CGFloat = 0  // Centered vertically
        
        // Background (empty/gray bar)
        let bgRect = CGRect(x: -meterWidth / 2, y: -meterHeight / 2, width: meterWidth, height: meterHeight)
        jumpMeterBg.path = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        jumpMeterBg.fillColor = .black.withAlphaComponent(0.5)
        jumpMeterBg.strokeColor = .white.withAlphaComponent(0.3)
        jumpMeterBg.lineWidth = 2
        jumpMeterBg.position = CGPoint(x: xPos, y: yPos)
        jumpMeterBg.zPosition = 0
        uiNode.addChild(jumpMeterBg)
        
        // Fill (green bar that drains)
        let fillRect = CGRect(x: -meterWidth / 2, y: -meterHeight / 2, width: meterWidth, height: meterHeight)
        jumpMeterFill.path = CGPath(roundedRect: fillRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        jumpMeterFill.fillColor = .green
        jumpMeterFill.strokeColor = .clear
        jumpMeterFill.position = CGPoint(x: xPos, y: yPos)
        jumpMeterFill.zPosition = 1
        jumpMeterFill.yScale = 1.0  // Start full
        uiNode.addChild(jumpMeterFill)
        
        // Add a subtle pulse animation to make it more noticeable (only on Y-axis to avoid horizontal drift)
        let pulseUp = SKAction.scaleY(to: 1.05, duration: 0.5)
        pulseUp.timingMode = .easeInEaseOut
        let pulseDown = SKAction.scaleY(to: 1.0, duration: 0.5)
        pulseDown.timingMode = .easeInEaseOut
        let pulse = SKAction.sequence([pulseUp, pulseDown])
        jumpMeterBg.run(SKAction.repeatForever(pulse))
    }
    
    /// Updates the jump meter based on time since last jump
    private func updateJumpMeter(currentTime: TimeInterval) {
        // Calculate time since last jump
        let timeSinceJump = currentTime - lastJumpTime
        
        // Calculate meter value (1.0 = full, 0.0 = empty)
        // Drains linearly over 1 second
        jumpMeterValue = max(0.0, 1.0 - CGFloat(timeSinceJump / jumpMeterTimeout))
        
        // Update visual - scale the fill bar from bottom
        // To keep the fill aligned with the background, we need to adjust position as we scale
        let meterHeight: CGFloat = 200
        jumpMeterFill.yScale = jumpMeterValue
        
        // Keep X position locked to background to prevent horizontal drift
        jumpMeterFill.position.x = jumpMeterBg.position.x
        
        // Adjust y position to keep the bottom edge fixed (scale from bottom instead of center)
        let yOffset = (meterHeight / 2) * (1.0 - jumpMeterValue)
        jumpMeterFill.position.y = jumpMeterBg.position.y - yOffset
        
        // Change color based on how full it is
        if jumpMeterValue > 0.66 {
            // Full/High - bright green
            jumpMeterFill.fillColor = UIColor(red: 0.2, green: 1.0, blue: 0.2, alpha: 1.0)
        } else if jumpMeterValue > 0.33 {
            // Medium - yellow-green
            jumpMeterFill.fillColor = UIColor(red: 0.8, green: 1.0, blue: 0.2, alpha: 1.0)
        } else if jumpMeterValue > 0 {
            // Low - orange
            jumpMeterFill.fillColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        } else {
            // Empty - red
            jumpMeterFill.fillColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
        }
    }
    
    /// Resets the jump meter (called when jumping or landing)
    private func resetJumpMeter() {
        lastJumpTime = CACurrentMediaTime()
        jumpMeterValue = 1.0
        
        // Remove any existing animations
        jumpMeterFill.removeAction(forKey: "meterFlash")
        
        // Brief flash effect when resetting
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.05),
            SKAction.fadeAlpha(to: 0.8, duration: 0.05)
        ])
        jumpMeterFill.run(flash, withKey: "meterFlash")
    }
    
    /// Depletes the jump meter instantly (called on damage or water fall)
    private func depletJumpMeter() {
        jumpMeterValue = 0.0
        jumpMeterFill.yScale = 0.0
        jumpMeterFill.fillColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
        
        // Keep X position locked to background to prevent horizontal drift
        jumpMeterFill.position.x = jumpMeterBg.position.x
        
        // Adjust position to keep aligned with background (scale from bottom)
        let meterHeight: CGFloat = 200
        let yOffset = (meterHeight / 2) * (1.0 - jumpMeterValue)
        jumpMeterFill.position.y = jumpMeterBg.position.y - yOffset
        
        // Visual feedback - shake animation
        let shakeLeft = SKAction.moveBy(x: -5, y: 0, duration: 0.05)
        let shakeRight = SKAction.moveBy(x: 10, y: 0, duration: 0.05)
        let shakeBack = SKAction.moveBy(x: -5, y: 0, duration: 0.05)
        let shake = SKAction.sequence([shakeLeft, shakeRight, shakeLeft, shakeRight, shakeBack])
        jumpMeterBg.run(shake)
    }
    
    // MARK: - Combo Timer Management
    
    /// Pauses the combo timer when the upgrade modal appears
    /// This prevents the combo from breaking while the player makes a selection
    private func pauseComboTimer() {
        // Store the current time so we can calculate the pause duration later
        comboPausedTime = Date().timeIntervalSince1970
    }
    
    /// Resumes the combo timer after the upgrade modal is dismissed
    /// Adjusts lastLandTime to account for the pause duration, maintaining the combo
    private func resumeComboTimer() {
        guard comboPausedTime > 0 else { return }
        
        // Calculate how long the upgrade modal was open
        let currentTime = Date().timeIntervalSince1970
        let pauseDuration = currentTime - comboPausedTime
        
        // Adjust lastLandTime to effectively "pause" the combo timer
        // by adding the pause duration back
        if lastLandTime > 0 {
            lastLandTime += pauseDuration
        }
        
        // Reset the paused time tracker
        comboPausedTime = 0
    }
    
  
    
    private func setupRaceHUD() {
        guard gameMode == .beatTheBoat else { return }
        
        // Position the race progress bar at the bottom of the screen,
        // respecting the safe area.
        let bottomSafeArea = view?.safeAreaInsets.bottom ?? 0
        let verticalMargin: CGFloat = 20.0 // Padding from the safe area edge
        let yPosition = -(size.height / 2) + bottomSafeArea + verticalMargin
        
        raceProgressNode.position = CGPoint(x: 0, y: yPosition)
        uiNode.addChild(raceProgressNode)
        
        let barWidth: CGFloat = 200
        let bar = SKShapeNode(rectOf: CGSize(width: barWidth, height: 8), cornerRadius: 4)
        bar.fillColor = .black.withAlphaComponent(0.5)
        bar.strokeColor = .white
        bar.lineWidth = 1
        raceProgressNode.addChild(bar)
        
        // Finish line icon on the bar
        let finishIcon = SKLabelNode(text: "🏁")
        finishIcon.fontSize = 16
        finishIcon.position = CGPoint(x: barWidth / 2 + 10, y: 0)
        finishIcon.verticalAlignmentMode = .center
        raceProgressNode.addChild(finishIcon)
        
        raceFrogIcon.fontSize = 20
        raceFrogIcon.position = CGPoint(x: -barWidth / 2, y: 0)
        raceFrogIcon.verticalAlignmentMode = .center
        raceFrogIcon.zPosition = 1
        raceProgressNode.addChild(raceFrogIcon)
        
        raceBoatIcon.fontSize = 20
        raceBoatIcon.position = CGPoint(x: -barWidth / 2, y: 0)
        raceBoatIcon.verticalAlignmentMode = .center
        raceBoatIcon.zPosition = 1
        raceProgressNode.addChild(raceBoatIcon)
    }

    private func setupCountdownLabel() {
        countdownLabel.fontSize = 200
        countdownLabel.fontColor = .white
        countdownLabel.position = CGPoint(x: 0, y: 100) // A bit above center
        countdownLabel.zPosition = Layer.ui + 100
        countdownLabel.isHidden = true
        
        // Add a shadow for better visibility
        countdownLabelShadow.fontSize = countdownLabel.fontSize
        countdownLabelShadow.fontColor = .black.withAlphaComponent(0.7)
        countdownLabelShadow.position = CGPoint(x: 5, y: -5)
        countdownLabelShadow.zPosition = -1
        countdownLabel.addChild(countdownLabelShadow)
        
        uiNode.addChild(countdownLabel)
    }

    private func setupAchievementCard() {
        // Card starts off-screen at the bottom
        let cardHeight: CGFloat = 80
        achievementCard.position = CGPoint(x: 0, y: -(size.height / 2) - cardHeight)
        achievementCard.zPosition = Layer.ui + 10
        
        // Background
        let cardBg = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: cardHeight), cornerRadius: 16)
        cardBg.fillColor = UIColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 0.95)
        cardBg.strokeColor = .yellow
        cardBg.lineWidth = 3
        achievementCard.addChild(cardBg)
        
        // Trophy icon
        let trophySprite = SKSpriteNode(imageNamed: "trophy")
        trophySprite.size = CGSize(width: 50, height: 50)
        trophySprite.position = CGPoint(x: -(size.width / 2) + 60, y: 0)
        achievementCard.addChild(trophySprite)
        
        // Title label
        let titleLabel = SKLabelNode(fontNamed: Configuration.Fonts.achievementTitle.name)
        titleLabel.text = "Achievement Unlocked!"
        titleLabel.fontSize = Configuration.Fonts.achievementTitle.size
        titleLabel.fontColor = .yellow
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -(size.width / 2) + 100, y: 12)
        achievementCard.addChild(titleLabel)
        
        // Achievement name label
        achievementNameLabel.text = ""
        achievementNameLabel.fontSize = Configuration.Fonts.achievementName.size
        achievementNameLabel.fontColor = .white
        achievementNameLabel.horizontalAlignmentMode = .left
        achievementNameLabel.position = CGPoint(x: -(size.width / 2) + 100, y: -12)
        achievementCard.addChild(achievementNameLabel)
        
        uiNode.addChild(achievementCard)
    }
    
    private func showAchievementNotification(for challenge: Challenge) {
        // Add to queue
        achievementQueue.append(challenge)
        
        // If not currently showing, start showing
        if !isShowingAchievement {
            displayNextAchievement()
        }
    }
    
    private func displayNextAchievement() {
        guard !achievementQueue.isEmpty else {
            isShowingAchievement = false
            return
        }
        
        isShowingAchievement = true
        let challenge = achievementQueue.removeFirst()
        
        // Update the achievement name
        achievementNameLabel.text = challenge.title
        
        // Play sound and haptic
        SoundManager.shared.play("coin")  // Or a dedicated achievement sound
        HapticsManager.shared.playNotification(.success)
        
        // Slide up animation
        let cardHeight: CGFloat = 80
        let showPosition = CGPoint(x: 0, y: -(size.height / 2) + cardHeight / 2 + 20)
        let hidePosition = CGPoint(x: 0, y: -(size.height / 2) - cardHeight)
        
        let slideUp = SKAction.move(to: showPosition, duration: 0.3)
        slideUp.timingMode = .easeOut
        
        let wait = SKAction.wait(forDuration: 3.0)
        
        let slideDown = SKAction.move(to: hidePosition, duration: 0.3)
        slideDown.timingMode = .easeIn
        
        let showNext = SKAction.run { [weak self] in
            self?.displayNextAchievement()
        }
        
        achievementCard.run(SKAction.sequence([slideUp, wait, slideDown, showNext]))
    }
    
    @objc private func handleChallengeCompleted(_ notification: Notification) {
        guard let challenge = notification.userInfo?["challenge"] as? Challenge else { return }
        showAchievementNotification(for: challenge)
    }
    
    // MARK: - Tutorial Overlay
    
    private func setupTutorialOverlay() {
        // Semi-transparent dark overlay
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.fillColor = .black.withAlphaComponent(0.7)
        overlay.strokeColor = .clear
        overlay.zPosition = 0
        tutorialOverlay.addChild(overlay)
        
        // Load and position the finger image
        let fingerSprite = SKSpriteNode(imageNamed: "finger")
        fingerSprite.name = "finger"
        
        // Scale down the finger to 40% of its original size
        fingerSprite.setScale(0.6)
        
        // Set anchor point to top center (0.5, 1.0) so the top of the finger is the reference point
        fingerSprite.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        
        // Position the finger so its top is directly over the frog (at position 0, 0 relative to camera)
        fingerSprite.position = CGPoint(x: 0, y: -180)
        fingerSprite.zPosition = 1
        tutorialOverlay.addChild(fingerSprite)
        tutorialFingerSprite = fingerSprite
        
        // Add a "Drag to Fling!" instruction text
        let instructionLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
        instructionLabel.text = "Drag to Fling!"
        instructionLabel.fontSize = 36
        instructionLabel.fontColor = .white
        instructionLabel.position = CGPoint(x: 0, y: 150)
        instructionLabel.zPosition = 1
        tutorialOverlay.addChild(instructionLabel)
        
        // Animate the finger: slide down to simulate dragging, then fade out and repeat
        // Frog is at camera position (0, 0), but we need the finger tip to touch it
        // With anchor at top (1.0), we need to move the finger down slightly
        let startPosition = CGPoint(x: 0, y: -180)  // Top tip of finger touching the frog
        let endPosition = CGPoint(x: 0, y: -240) // Slide down 150 points from start
        
        let wait1 = SKAction.wait(forDuration: 0.5)
        let slideDown = SKAction.move(to: endPosition, duration: 1.0)
        slideDown.timingMode = .easeInEaseOut
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        
        let reset = SKAction.run { [weak fingerSprite] in
            fingerSprite?.position = startPosition
            fingerSprite?.alpha = 1.0
        }
        
        let wait2 = SKAction.wait(forDuration: 0.5)
        
        let sequence = SKAction.sequence([wait1, slideDown, fadeOut, reset, wait2])
        fingerSprite.run(SKAction.repeatForever(sequence))
        
        // Position the tutorial overlay at camera position (screen space)
        tutorialOverlay.zPosition = Layer.overlay
        tutorialOverlay.isHidden = true
        cam.addChild(tutorialOverlay)
    }
    
    private func showTutorialOverlay() {
        // Only show if the user hasn't seen it before
        guard !PersistenceManager.shared.hasSeenTutorial else { return }
        
        tutorialOverlay.isHidden = false
        tutorialOverlay.alpha = 0
        
        // Fade in the tutorial
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        tutorialOverlay.run(fadeIn)
    }
    
    private func hideTutorialOverlay() {
        guard !tutorialOverlay.isHidden else { return }
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let hide = SKAction.run { [weak self] in
            self?.tutorialOverlay.isHidden = true
        }
        tutorialOverlay.run(SKAction.sequence([fadeOut, hide]))
        
        // Mark as seen so it won't show again
        PersistenceManager.shared.markTutorialAsSeen()
    }
    
    private func drawHearts() {
        heartNodes.forEach { $0.removeFromParent() }
        heartNodes.removeAll()
        let startX = -(size.width / 2) + hudMargin + 10
        let yPos = (size.height / 2) - 100
        for i in 0..<frog.maxHealth {
            let heart = SKSpriteNode(imageNamed: "heart")
            heart.size = CGSize(width: 16, height: 16)
            heart.position = CGPoint(x: startX + (CGFloat(i) * 20), y: yPos)
            if i < frog.currentHealth {
                heart.alpha = 1.0
            } else {
                heart.alpha = 0.3
                heart.colorBlendFactor = 1.0
                heart.color = .black
            }
            uiNode.addChild(heart)
            heartNodes.append(heart)
        }
    }

    /// Calculates the required width for a buff item display node.
    private func calculateBuffItemWidth(count: Int) -> CGFloat {
        let iconWidth: CGFloat = 24
        let horizontalPadding: CGFloat = 8
        let spacing: CGFloat = 4
        
        var totalWidth = horizontalPadding + iconWidth + horizontalPadding
        
        if count > 1 {
            let label = SKLabelNode(fontNamed: Configuration.Fonts.buffIndicator.name)
            label.fontSize = Configuration.Fonts.buffIndicator.size
            label.text = "x\(count)"
            totalWidth += spacing + label.frame.width
        }
        
        return totalWidth
    }

    /// Creates a complete visual node for a buff item, including icon, count, and background.
    private func createBuffItemNode(iconName: String, count: Int, borderColor: UIColor) -> SKNode {
        let node = SKNode()
        let itemHeight: CGFloat = 34
        
        // 1. Calculate width and create background
        let totalWidth = calculateBuffItemWidth(count: count)
        let bg = SKShapeNode(rectOf: CGSize(width: totalWidth, height: itemHeight), cornerRadius: 12)
        bg.fillColor = .black.withAlphaComponent(0.5)
        bg.strokeColor = borderColor
        bg.lineWidth = 2
        bg.position = CGPoint(x: totalWidth / 2, y: 0) // Center the background shape in its frame
        node.addChild(bg)
        
        // 2. Create and position icon
        let icon = SKSpriteNode(imageNamed: iconName)
        icon.size = CGSize(width: 24, height: 24)
        let horizontalPadding: CGFloat = 8
        icon.position = CGPoint(x: horizontalPadding + icon.size.width / 2, y: 0)
        node.addChild(icon)
        
        // 3. Create and position count label if needed
        if count > 1 {
            let label = SKLabelNode(fontNamed: Configuration.Fonts.buffIndicator.name)
            label.text = "x\(count)"
            label.fontSize = Configuration.Fonts.buffIndicator.size
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .left
            
            let spacing: CGFloat = 4
            label.position = CGPoint(x: icon.position.x + icon.size.width / 2 + spacing, y: 0)
            node.addChild(label)
        }
        
        return node
    }

    private func updateBuffsHUD() {
        // 1. Hide timed/special buff nodes initially. They will be re-enabled and positioned later if active.
        rocketBuffNode.isHidden = true
        superJumpBuffNode.isHidden = true
        crocRideBuffNode.isHidden = true
        
        // 2. Define the buffs to be displayed in the grid.
        struct BuffDisplayInfo {
            let count: Int
            let iconName: String
            let specialState: SpecialState?
            
            enum SpecialState {
                case bootsActive
                case bootsInactive
            }
        }

        var gridBuffs: [BuffDisplayInfo] = []
        
        if frog.buffs.vest > 0 {
            gridBuffs.append(.init(count: frog.buffs.vest, iconName: "lifevest", specialState: nil))
        }
        if frog.buffs.honey > 0 {
            gridBuffs.append(.init(count: frog.buffs.honey, iconName: "honeyPot", specialState: nil))
        }
        if frog.buffs.axe > 0 {
            gridBuffs.append(.init(count: frog.buffs.axe, iconName: "ax", specialState: nil))
        }
        if frog.buffs.swatter > 0 {
            gridBuffs.append(.init(count: frog.buffs.swatter, iconName: "swatter", specialState: nil))
        }
        if frog.buffs.cross > 0 {
            gridBuffs.append(.init(count: frog.buffs.cross, iconName: "cross", specialState: nil))
        }
        if frog.buffs.bootsCount > 0 {
            let state: BuffDisplayInfo.SpecialState = frog.isWearingBoots ? .bootsActive : .bootsInactive
            gridBuffs.append(.init(count: frog.buffs.bootsCount, iconName: "rainboots", specialState: state))
        }
        
        // 3. Clear and rebuild the grid.
        buffsGridNode.removeAllChildren()

        let itemHeight: CGFloat = 34
        let rowSpacing: CGFloat = 6
        let columnSpacing: CGFloat = 6
        let itemsPerRow = 2
        var lastItemWidth: CGFloat = 0

        for (index, buffInfo) in gridBuffs.enumerated() {
            let borderColor: UIColor
            if let state = buffInfo.specialState {
                switch state {
                case .bootsActive: borderColor = .green
                case .bootsInactive: borderColor = .blue
                }
            } else {
                borderColor = .orange
            }
            
            let node = createBuffItemNode(
                iconName: buffInfo.iconName,
                count: buffInfo.count,
                borderColor: borderColor
            )
            
            let row = index / itemsPerRow
            let col = index % itemsPerRow
            
            let xPos = (col == 0) ? 0 : lastItemWidth + columnSpacing
            let yPos = -CGFloat(row) * (itemHeight + rowSpacing)
            
            node.position = CGPoint(x: xPos, y: yPos)
            buffsGridNode.addChild(node)
            
            if col == 0 {
                lastItemWidth = node.calculateAccumulatedFrame().width
            } else {
                lastItemWidth = 0 // Reset for the next row
            }
        }

        // 4. Position the timed buffs below the grid.
        let gridHeight = buffsGridNode.calculateAccumulatedFrame().height
        var yOffset: CGFloat = gridBuffs.isEmpty ? 0 : -(gridHeight + 10)
        
        // Rocket
        if frog.rocketTimer > 0 {
            if let bg = rocketBuffNode.childNode(withName: "background"),
               let label = bg.childNode(withName: "label") as? SKLabelNode {
                label.text = "\(Int(ceil(frog.rocketTimer)))s"
                if let icon = bg.childNode(withName: "icon") { icon.isHidden = false }
                label.horizontalAlignmentMode = .left
                label.position = CGPoint(x: -30, y: 0)
            }
            rocketBuffNode.position.y = yOffset
            rocketBuffNode.isHidden = false
            yOffset -= 30
        } else if frog.rocketState == .landing {
            if let bg = rocketBuffNode.childNode(withName: "background"),
               let label = bg.childNode(withName: "label") as? SKLabelNode {
                label.text = "⚠ DESCEND"
                if let icon = bg.childNode(withName: "icon") { icon.isHidden = true }
                label.horizontalAlignmentMode = .center
                label.position = CGPoint(x: 0, y: 0)
            }
            rocketBuffNode.position.y = yOffset
            rocketBuffNode.isHidden = false
            yOffset -= 30
        }
        
        // Super Jump
        if frog.buffs.superJumpTimer > 0 {
            if let bg = superJumpBuffNode.childNode(withName: "background"),
               let label = bg.childNode(withName: "label") as? SKLabelNode {
                label.text = "\(Int(ceil(frog.buffs.superJumpTimer)))s"
                if let icon = bg.childNode(withName: "icon") { icon.isHidden = false }
            }
            superJumpBuffNode.position.y = yOffset
            superJumpBuffNode.isHidden = false
            yOffset -= 30
        }
        
        // Croc Ride
        if let croc = ridingCrocodile, croc.isCarryingFrog {
            if let bg = crocRideBuffNode.childNode(withName: "background"),
               let label = bg.childNode(withName: "label") as? SKLabelNode {
                let remaining = Int(ceil(croc.remainingRideTime()))
                label.text = "🐊 RIDE \(remaining)s"
            }
            crocRideBuffNode.position.y = yOffset
            crocRideBuffNode.isHidden = false
            yOffset -= 30
        }
    }
    
    private func updateHUDVisuals() {
        // PERFORMANCE: Throttle HUD updates based on device capability
        let hudUpdateInterval = PerformanceSettings.hudUpdateInterval
        if hudUpdateInterval > 1 && frameCount % hudUpdateInterval != 0 {
            // Only update critical buffs that have timers, skip score/coin updates
            // Use hash comparison instead of full struct comparison for better performance
            let currentBuffsHash = frog.buffs.hashValue
            let buffsChanged = currentBuffsHash != lastKnownBuffsHash
            let rocketChanged = frog.rocketTimer != lastKnownRocketTimer || frog.rocketState != lastKnownRocketState
            
            if buffsChanged || rocketChanged {
                updateBuffsHUD()
                lastKnownBuffsHash = currentBuffsHash
                lastKnownBuffs = frog.buffs
                lastKnownRocketTimer = frog.rocketTimer
                lastKnownRocketState = frog.rocketState
            }
            return
        }
        
        let currentScore = Int(frog.position.y / 10)
        if currentScore > score {
            score = currentScore
            scoreLabel.text = "\(score)m"
            
            // Real-time challenge update for score milestones
            ChallengeManager.shared.recordScoreUpdate(currentScore: score)
        }
        coinLabel.text = "\(totalCoins)"
        
        // --- Performance Optimization: Conditional HUD Update ---
        // Only rebuild the buff display if the buffs, rocket timer, or rocket state have changed.
        let currentBuffsHash = frog.buffs.hashValue
        let buffsChanged = currentBuffsHash != lastKnownBuffsHash
        let rocketChanged = frog.rocketTimer != lastKnownRocketTimer || frog.rocketState != lastKnownRocketState
        
        if buffsChanged || rocketChanged {
            updateBuffsHUD()
            lastKnownBuffsHash = currentBuffsHash
            lastKnownBuffs = frog.buffs
            lastKnownRocketTimer = frog.rocketTimer
            lastKnownRocketState = frog.rocketState
        }

        // Update Cannon Jump Button
        if PersistenceManager.shared.hasCannonJump {
            cannonJumpBg.isHidden = false
            let count = frog.buffs.cannonJumps
            
            let canUse = count > 0 && frog.onPad != nil && !isDragging
            cannonJumpBg.alpha = canUse ? 1.0 : 0.5
            
            if frog.isCannonJumpArmed {
                cannonJumpBg.fillColor = .yellow
                cannonJumpButton.fontColor = .black
                cannonJumpButton.text = "ARMED!"
                
                // When ARMED, hide the icon and center the text
                cannonJumpIcon.isHidden = true
                cannonJumpButton.position = .zero
                cannonJumpButton.horizontalAlignmentMode = .center
            } else {
                cannonJumpBg.fillColor = UIColor(red: 142/255, green: 68/255, blue: 173/255, alpha: 1.0) // Purple
                cannonJumpButton.fontColor = .white
                cannonJumpButton.text = "(\(count))"
                
                // When not armed, show icon and position it and text
                cannonJumpIcon.isHidden = false
                cannonJumpIcon.position = CGPoint(x: -24, y: 0)
                
                cannonJumpButton.horizontalAlignmentMode = .left
                cannonJumpButton.position = CGPoint(x: -1, y: 0)
            }
        } else {
            cannonJumpBg.isHidden = true
        }
    }
    
    // ... (startGame, update, weather, camera, cleanup, generate, collision same as previous) ...
    
    private func startGame() {
        isGameEnding = false
        pads.forEach { $0.removeFromParent() }
        enemies.forEach { $0.removeFromParent() }
        coins.forEach { $0.removeFromParent() }
        crocodiles.forEach { $0.removeFromParent() }
        treasureChests.forEach { $0.removeFromParent() }
        snakes.forEach { $0.removeFromParent() }
        cacti.forEach { $0.removeFromParent() }
        flies.forEach { $0.removeFromParent() }
        flotsam.forEach { $0.removeFromParent() }
        pads.removeAll()
        enemies.removeAll()
        coins.removeAll()
        crocodiles.removeAll()
        treasureChests.removeAll()
        snakes.removeAll()
        cacti.removeAll()
        flies.removeAll()
        flotsam.removeAll()
        ridingCrocodile = nil
        trajectoryNode.path = nil
        slingshotNode.path = nil
        slingshotDot.isHidden = true
        crosshairNode.isHidden = true
        
        // Reset rocket steering state
        rocketSteeringTouch = nil
        rocketSteeringDirection = 0
        
        // Reset race-specific elements
        boat?.removeFromParent()
        boat = nil
        finishLineNode.removeFromParent()
        raceResult = nil
        raceState = .none
        
        frog.position = CGPoint(x: Configuration.Dimensions.riverWidth / 2, y: 0)
        frog.zHeight = 0
        frog.velocity = .zero
        frog.maxHealth = 2 + PersistenceManager.shared.healthLevel
        frog.currentHealth = frog.maxHealth
        frog.rocketState = .none
        frog.buffs = Frog.Buffs()
        
        // Apply starting consumables from inventory (one 4-pack of each type owned)
        // Lifevests
        for _ in 0..<4 {
            if PersistenceManager.shared.useVestItem() {
                frog.buffs.vest += 1
            }
        }
        // Honey Pots
        for _ in 0..<4 {
            if PersistenceManager.shared.useHoneyItem() {
                frog.buffs.honey += 1
            }
        }
        // Crosses
        for _ in 0..<4 {
            if PersistenceManager.shared.useCrossItem() {
                frog.buffs.cross += 1
            }
        }
        // Fly Swatters
        for _ in 0..<4 {
            if PersistenceManager.shared.useSwatterItem() {
                frog.buffs.swatter += 1
            }
        }
        // Axes
        for _ in 0..<4 {
            if PersistenceManager.shared.useAxeItem() {
                frog.buffs.axe += 1
            }
        }
        
        // Grant cannon jumps if purchased
        if PersistenceManager.shared.hasCannonJump {
            frog.buffs.cannonJumps = Configuration.GameRules.cannonJumpsPerRun
        }
        frog.isCannonJumpArmed = false
        frog.isCannonJumping = false
        
        frog.isFloating = false
        frog.isWearingBoots = false
        frog.canJumpLogs = PersistenceManager.shared.hasLogJumper
        frog.rocketTimer = 0
        frog.resetPullOffset()
        
        worldNode.addChild(frog)
        
        // MARK: - Initialize Moonlight Renderer
        // Setup moonlight effect for night scenes, aimed at screen center
        moonlightRenderer = MoonlightRenderer.createOptimized(for: worldNode, target: frog, camera: cam)
        moonlightRenderer?.deactivate(animated: false)
        
        // TrajectoryRenderer is initialized in setupScene() - just reset if needed
        trajectoryRenderer?.hide()
        
        // MARK: - Debug Starting Score
        // For testing different biomes (desert, space, etc.)
        if Configuration.Debug.debugMode && Configuration.Debug.startingScore > 0 {
            score = Configuration.Debug.startingScore
            // Move frog to match the debug starting score so distance increments properly
            frog.position.y = CGFloat(Configuration.Debug.startingScore * 10)
            // Update the HUD to show the debug starting score immediately
            scoreLabel.text = "\(score)m"
        } else {
            score = 0
        }
        
        coinsCollectedThisRun = 0
        padsLandedThisRun = 0
        consecutiveJumps = 0
        bestConsecutiveJumps = 0
        crocodilesSpawnedThisRun = 0
        
        // Reset combo system
        comboCount = 0
        maxComboThisRun = 0
        comboMultiplier = 1.0
        lastLandTime = 0
        lastLandedPad = nil
        lastLandingY = 0
        consecutiveBackwardJumps = 0
        comboPausedTime = 0  // Reset combo pause timer
        frog.isComboInvincible = false  // Deactivate combo invincibility
        
        // Initialize jump meter
        lastJumpTime = CACurrentMediaTime()
        jumpMeterValue = 1.0
        jumpMeterFill.yScale = 1.0
        
        previousRocketState = .none
        previousSuperJumpState = false
        nextWeatherChangeScore = weatherChangeInterval
        spawnInitialPads()
        drawHearts()
        updateBuffsHUD()
        lastKnownBuffs = frog.buffs // Initialize buff state for comparison
        descendBg.isHidden = true
        
        // MARK: - Initialize Weather Based on Starting Score
        if Configuration.Debug.debugMode && Configuration.Debug.startingScore > 0 {
            // Determine the correct weather based on the starting score
            let startWeather = weatherForScore(Configuration.Debug.startingScore)
            setWeather(startWeather, duration: 0.0)
            // Calculate the next weather change point
            let weatherIndex = WeatherType.allCases.firstIndex(of: startWeather) ?? 0
            nextWeatherChangeScore = (weatherIndex + 1) * weatherChangeInterval
        } else {
            setWeather(.sunny, duration: 0.0)
        }
        
        stopDrowningGracePeriod()
        
        // Reset cutscene state for a new game
        isInCutscene = false
        isDesertTransitionPending = false
        hasSpawnedLaunchPad = false
        hasHitLaunchPad = false
        launchPadY = 0
        isLaunchingToSpace = false
        hasSpawnedWarpPad = false
        hasHitWarpPad = false
        warpPadY = 0

        if gameMode == .beatTheBoat {
            raceState = .countdown
            isUserInteractionEnabled = false
            setupRace()
            baseMusic = .race
            SoundManager.shared.playMusic(baseMusic)
        } else if case .dailyChallenge(let challenge) = gameMode {
            // Daily Challenge Mode Setup
            currentChallenge = challenge
            challengeRNG = SeededRandomNumberGenerator(seed: UInt64(abs(challenge.seed)))
            
            // Lock weather to challenge climate
            // Use a short duration instead of 0 to ensure particles are created properly
            setWeather(challenge.climate, duration: 0.1)
            
            baseMusic = .gameplay
            SoundManager.shared.playMusic(baseMusic)
            
            // Show and start the challenge timer
            timerLabel.isHidden = false
            challengeStartTime = CACurrentMediaTime()
            
            // Show challenge info banner
            showDailyChallengeBanner(challenge)
            
            // Show tutorial overlay for first-time players
            showTutorialOverlay()
        } else {
            // Not a daily challenge - hide the timer
            timerLabel.isHidden = true
            
            baseMusic = .gameplay
            SoundManager.shared.playMusic(baseMusic)
            
            // Show tutorial overlay for first-time players
            showTutorialOverlay()
        }
    }
    
    private func setupRace() {
        // Spawn the boat just behind the starting line
        ToolTips.showToolTip(forKey: "race", in: self)

        let boatInstance = Boat(position: CGPoint(x: Configuration.Dimensions.riverWidth / 2 - 250, y: -50), wakeTargetNode: worldNode)
        boatInstance.speedMultiplier = self.boatSpeedMultiplier
        worldNode.addChild(boatInstance)
        self.boat = boatInstance
        
        // Create the finish line
        
        let finishY = Configuration.GameRules.boatRaceFinishY + CGFloat(ChallengeManager.shared.stats.currentWinningStreak * 1000)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: finishY))
        path.addLine(to: CGPoint(x: Configuration.Dimensions.riverWidth, y: finishY))
        
        let lineNode = SKShapeNode(path: path)
        lineNode.strokeColor = .yellow
        lineNode.lineWidth = 15
        lineNode.zPosition = Layer.pad - 1 // Below pads
        
        // Add checkered flag pattern if the texture exists
        if let texture = SKTexture(imageNamed: "finishLine") as SKTexture? {
            texture.filteringMode = .nearest
            lineNode.strokeTexture = texture
            lineNode.strokeColor = .white
        }
        
        self.finishLineNode = lineNode
        worldNode.addChild(finishLineNode)
        
        startRaceCountdown()
    }

    private func startRaceCountdown() {
        countdownLabel.isHidden = false

        func updateLabelText(text: String, color: UIColor = .white) {
            self.countdownLabel.text = text
            self.countdownLabel.fontColor = color
            self.countdownLabelShadow.text = text
        }

        let pulseAction = SKAction.sequence([
            SKAction.group([.scale(to: 1.0, duration: 0.2), .fadeIn(withDuration: 0.2)]),
            SKAction.wait(forDuration: 0.6),
            SKAction.fadeOut(withDuration: 0.2)
        ])
        pulseAction.timingMode = .easeInEaseOut

        func stepAction(text: String, sound: String, color: UIColor = .white) -> SKAction {
            return SKAction.run {
                updateLabelText(text: text, color: color)
                self.countdownLabel.setScale(2.0)
                self.countdownLabel.alpha = 0.0
                self.countdownLabel.run(pulseAction)
                SoundManager.shared.play(sound)
            }
        }

        let wait = SKAction.wait(forDuration: 1.0)

        let beginRace = SKAction.run {
            self.countdownLabel.isHidden = true
            self.raceState = .racing
            self.isUserInteractionEnabled = true
        }

        let sequence = SKAction.sequence([
            stepAction(text: "3", sound: "hit"), wait,
            stepAction(text: "2", sound: "hit"), wait,
            stepAction(text: "1", sound: "hit"), wait,
            stepAction(text: "GO!", sound: "coin", color: .green), wait,
            beginRace
        ])

        run(sequence)
    }

    private func spawnInitialPads() {
        // Start spawning pads at the frog's current Y position (accounts for debug mode)
        var yPos: CGFloat = frog.position.y
        for _ in 0..<5 {
            let pad = Pad(type: .normal, position: CGPoint(x: size.width / 2, y: yPos))
            worldNode.addChild(pad)
            pads.append(pad)
            yPos += 100
        }
        if let firstPad = pads.first {
            frog.position = firstPad.position
            frog.land(on: firstPad, weather: currentWeather)
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        frameCount += 1
        
        guard coordinator?.currentState == .playing && !isGameEnding && !isInCutscene else { return }
        
        // Update daily challenge timer
        if currentChallenge != nil {
            updateChallengeTimer()
        }
        
        if let challenge = currentChallenge, finishLineNode == nil, score >= 800 {
            spawnFinishLine()
        }
        // Check for daily challenge completion (1000m = score of 1000)
        if let challenge = currentChallenge, score >= 1000 {
            
            handleDailyChallengeComplete()
            return
        }
        
        // Update moonlight renderer to aim at screen center
        moonlightRenderer?.update(currentTime)
        
        // Apply continuous rocket steering while touch is held
        if frog.rocketState != .none && rocketSteeringTouch != nil && rocketSteeringDirection != 0 {
            frog.steerRocket(rocketSteeringDirection)
        }
        
        checkPendingDesertTransition()
        
        // PERFORMANCE: Cache frequently used values to avoid repeated property access
        let camY = cam.position.y
        let viewHeight = size.height
        // Expand active bounds slightly to allow for smooth spawn/despawn
        let activeLowerBound = camY - viewHeight * 0.6
        let activeUpperBound = camY + viewHeight * 0.6
        
        // --- Performance Optimization: Clear active entity arrays ---
        // Use removeAll with keepingCapacity to avoid de-allocating the array's buffer.
        activePads.removeAll(keepingCapacity: true)
        activeEnemies.removeAll(keepingCapacity: true)
        activeCoins.removeAll(keepingCapacity: true)
        activeCrocodiles.removeAll(keepingCapacity: true)
        activeTreasureChests.removeAll(keepingCapacity: true)
        activeSnakes.removeAll(keepingCapacity: true)
        activeCacti.removeAll(keepingCapacity: true)
        activeFlies.removeAll(keepingCapacity: true)
        
        // --- Main Entity Update Loop ---
        frog.update(dt: dt, weather: currentWeather)
        
        // --- Performance Optimization: Single-pass filtering and updating ---
        // Iterate through each entity list once to update it and determine if it's "active" (on-screen).
        // PERFORMANCE: Most entities are sorted by Y position, so we can break early once we're past active range
        
        for pad in pads {
            let padY = pad.position.y
            // PERFORMANCE: Early exit optimization
            // Since pads are sorted by Y position, we can stop checking once we've gone too far ahead
            if padY > activeUpperBound + viewHeight { break }
            
            // PERFORMANCE: Skip pads that are behind the camera by too much
            if padY < activeLowerBound - viewHeight { continue }
            
            if padY > activeLowerBound && padY < activeUpperBound {
                // Only update pads that have logic (e.g., moving, shrinking)
                if pad.type == .moving || pad.type == .log || pad.type == .shrinking || pad.type == .waterLily {
                    pad.update(dt: dt)
                }
                activePads.append(pad)
            }
        }
        
        for enemy in enemies {
            let enemyY = enemy.position.y
            // PERFORMANCE: Early exit for sorted arrays
            if enemyY > activeUpperBound + viewHeight { break }
            // PERFORMANCE: Skip enemies far behind camera
            if enemyY < activeLowerBound - viewHeight { continue }
            
            if enemyY > activeLowerBound && enemyY < activeUpperBound {
                enemy.update(dt: dt, target: frog.position)
                activeEnemies.append(enemy)
            }
        }
        
        for crocodile in crocodiles {
            let crocY = crocodile.position.y
            // PERFORMANCE: Early exit for sorted arrays
            if crocY > activeUpperBound + viewHeight { break }
            // PERFORMANCE: Skip entities far behind camera
            if crocY < activeLowerBound - viewHeight { continue }
            
            if crocY > activeLowerBound && crocY < activeUpperBound {
                crocodile.update(dt: dt, frogPosition: frog.position, frogZHeight: frog.zHeight)
                activeCrocodiles.append(crocodile)
            }
        }
        
        for fly in flies {
            let flyY = fly.position.y
            // PERFORMANCE: Early exit for sorted arrays
            if flyY > activeUpperBound + viewHeight { break }
            // PERFORMANCE: Skip entities far behind camera
            if flyY < activeLowerBound - viewHeight { continue }
            
            if flyY > activeLowerBound && flyY < activeUpperBound {
                fly.update(dt: dt)
                activeFlies.append(fly)
            }
        }
        
        for coin in coins {
            let coinY = coin.position.y
            // PERFORMANCE: Early exit for sorted arrays
            if coinY > activeUpperBound + viewHeight { break }
            // PERFORMANCE: Skip entities far behind camera
            if coinY < activeLowerBound - viewHeight { continue }
            
            if coinY > activeLowerBound && coinY < activeUpperBound {
                activeCoins.append(coin)
            }
        }
        
        for chest in treasureChests {
            let chestY = chest.position.y
            // PERFORMANCE: Early exit for sorted arrays
            if chestY > activeUpperBound + viewHeight { break }
            // PERFORMANCE: Skip entities far behind camera
            if chestY < activeLowerBound - viewHeight { continue }
            
            if chestY > activeLowerBound && chestY < activeUpperBound {
                activeTreasureChests.append(chest)
            }
        }

        for snake in snakes {
            // Snakes move horizontally across the entire river width
            // Check if snake is in the vertical range of the camera
            let verticalDistance = abs(snake.position.y - camY)
            let isInVerticalRange = verticalDistance < viewHeight * 1.5
            
            // Snakes need a VERY wide horizontal range since they:
            // 1. Spawn off-screen to the left (X = -50)
            // 2. Travel all the way across the river (X = 0 to 600)
            // Give them the full river width + generous buffer on both sides
            let riverWidth = Configuration.Dimensions.riverWidth
            let isInHorizontalRange = snake.position.x >= -200 && snake.position.x <= riverWidth + 200
            
            if isInVerticalRange && isInHorizontalRange {
                // Update the snake (returns true if it moved off screen, but we don't respawn)
                _ = snake.update(dt: dt, pads: activePads)
                activeSnakes.append(snake)
            }
        }
        
        // Cacti are stationary (attached to pads), so they don't need updating
        // Just check if they're on-screen by checking their parent pad
        for cactus in cacti where !cactus.isDestroyed && cactus.parent != nil {
            // Cacti positions are relative to their parent pad, so check parent position
            if let parentPad = cactus.parent as? Pad {
                if parentPad.position.y > activeLowerBound && parentPad.position.y < activeUpperBound {
                    activeCacti.append(cactus)
                }
            }
        }
        
        // Ride Logic
        if let croc = ridingCrocodile, croc.isCarryingFrog {
            frog.position = croc.position
            frog.velocity = .zero
        }
        
        // --- Optimized Collision Detection ---
        // Pass only the active entities to the collision manager.
        collisionManager.update(
            frog: frog,
            pads: activePads,
            enemies: activeEnemies,
            coins: activeCoins,
            crocodiles: activeCrocodiles,
            treasureChests: activeTreasureChests,
            snakes: activeSnakes,
            cacti: activeCacti,
            flies: activeFlies,
            boat: boat
        )
        
        // --- Visuals & Logic ---
        checkWeatherChange()
        checkLaunchPadInteraction()
        updateWaterVisuals()
        updateWaterStars() // Update star positions for night mode
        updateWaterLines(dt: dt) // Update water line positions for movement effect
        updateWaterShimmers() // Update shimmer particles for enhanced water dynamics
        updateShores() // Update shore segments to follow camera
        updateRaceState(dt: dt)
        updateDrowningGracePeriod(dt: dt)
        
        // UI Updates
        if frog.rocketState == .flying {
            descendBg.isHidden = false
        } else if frog.rocketState == .landing {
            descendBg.isHidden = false
            // PERFORMANCE FIX: Removed expensive sin() calculation
            // Pulsing animation now handled by SKAction in setupHUD()
        } else {
            descendBg.isHidden = true
            descendBg.setScale(1.0) // Reset scale when hidden
        }
        
        if previousRocketState != .none && frog.rocketState == .none {
            SoundManager.shared.playMusic(baseMusic)
        }
        previousRocketState = frog.rocketState
        
        // Super Jump music management
        let currentSuperJumpState = frog.isSuperJumping
        if previousSuperJumpState && !currentSuperJumpState {
            // Super jump just ended, resume gameplay music
            SoundManager.shared.playMusic(baseMusic)
        }
        previousSuperJumpState = currentSuperJumpState
        
        updateMoonlightPosition()
        updateSpaceGlowPosition()
        updateCamera()
       // updateParallaxPlants()  // Update parallax plant positions
        
        // Update jump meter
        updateJumpMeter(currentTime: currentTime)
        
        updateHUDVisuals()
        
        // MARK: - Entity Tooltips
        // Check for first-time entity encounters and show contextual tooltips
        checkEntityTooltips()
        
        // MARK: - Debug Performance Monitoring
        #if DEBUG
        updateDebugHUD(dt: dt)
        #endif
        
        // --- Generation & Cleanup ---
        // OVERJUMP FIX: Spawn pads much further ahead to prevent jumping beyond spawn range
        // Previous: size.height (1x screen ahead)
        // New: size.height * 2.0 (2x screen ahead) - ensures fast jumps always have pads ready
        // This has minimal performance impact since we already cull entities efficiently
        if let lastPad = pads.last, lastPad.position.y < cam.position.y + (size.height * 2.0) {
            generateNextLevelSlice(lastPad: lastPad)
        }
        
        // THROTTLED CLEANUP: Only run cleanup every N frames (device-dependent)
        let cleanupInterval = PerformanceSettings.cleanupInterval
        if frameCount % cleanupInterval == 0 {
            cleanupOffscreenEntities()
        }
    }
    
    #if DEBUG
    private func updateDebugHUD(dt: TimeInterval) {
        // Update FPS counter every 30 frames (~0.5 seconds at 60fps)
        if frameCount % 30 == 0 {
            let fps = 1.0 / dt
            let fpsColor: UIColor
            if fps >= 110 {
                fpsColor = .green  // Excellent
            } else if fps >= 90 {
                fpsColor = .cyan   // Good
            } else if fps >= 55 {
                fpsColor = .yellow // OK
            } else {
                fpsColor = .red    // Poor
            }
            fpsLabel.fontColor = fpsColor
            fpsLabel.text = String(format: "FPS: %.0f", fps)
            
            // Update entity counts
            let totalEntities = pads.count + enemies.count + coins.count + 
                               snakes.count + crocodiles.count + flies.count
            entityCountLabel.text = String(format: "P:%d E:%d C:%d [%d]", 
                                          pads.count, enemies.count, coins.count, totalEntities)
            
            // OVERJUMP DEBUG: Log pad spawning distance
            if let lastPad = pads.last {
                let spawnDistance = lastPad.position.y - cam.position.y
                let frogDistance = frog.position.y - cam.position.y
                // Warn if frog is getting too close to spawn boundary
                if spawnDistance < size.height * 1.5 {
                    // Pad spawn getting close
                }
            }
        }
        
        // OVERJUMP DEBUG: Log frame drops with frog velocity
        // DISABLED: Excessive logging can itself cause frame drops
        // if dt > 0.025 {  // More than 25ms = below 40 FPS
        //     let velocity = sqrt(frog.velocity.dx * frog.velocity.dx + frog.velocity.dy * frog.velocity.dy)
        //     print("⚠️ FRAME DROP: dt=\(dt*1000)ms, velocity=\(velocity), frogY=\(frog.position.y)")
        // }
    }
    
    // MARK: - Debug Tooltip Utilities
    
    /// Debug function to reset all tooltips (useful during development)
    func debugResetAllTooltips() {
        ToolTips.resetToolTipHistory()
    }
    
    /// Debug function to check which entities have been seen
    func debugPrintTooltipStatus() {
        let entityTypes = ["FLY", "BEE", "GHOST", "DRAGONFLY", "LOG", "tadpole", "treasure"]
        for type in entityTypes {
            let seen = ToolTips.hasSeenEntity(type)
            _ = "\(type): \(seen ? "✅ Seen" : "❌ Not seen")"
        }
    }
    #endif

    private func updateRaceState(dt: TimeInterval) {
        guard gameMode == .beatTheBoat, raceState == .racing, let boat = boat, !isGameEnding else { return }
        
        boat.update(dt: dt)
        checkBoatCollisions()
        
        // Update HUD
        let finishY = Configuration.GameRules.boatRaceFinishY
        let frogProgress = min(1.0, frog.position.y / finishY)
        let boatProgress = min(1.0, boat.position.y / finishY)
        
        let barWidth: CGFloat = 200
        raceFrogIcon.position.x = (-barWidth / 2) + (barWidth * frogProgress)
        raceBoatIcon.position.x = (-barWidth / 2) + (barWidth * boatProgress)
        
        // Check for winner
        if frog.position.y >= finishY {
            endRace(result: .win)
        } else if boat.position.y >= finishY {
            endRace(result: .lose(reason: .outrun))
        }
    }
    
    private func checkBoatCollisions() {
        guard let boat = boat else { return }

        // PERFORMANCE FIX: Only check collision with active pads, not all pads
        for pad in activePads {
            // The boat only interacts with circular lily pads, not logs or graves.
            guard pad.type != .log && pad.type != .grave else { continue }
            
            // More precise circle-rectangle collision check
            if boatCollidesWithPad(boat: boat, pad: pad) {
                boatDidCollide(with: pad, boat: boat)
            }
        }
    }

    /// Checks for collision between a rectangular boat and a circular lily pad.
    private func boatCollidesWithPad(boat: Boat, pad: Pad) -> Bool {
        // Boat properties
        let boatCenter = boat.position
        let boatHalfWidth = boat.size.width / 3
        let boatHalfHeight = boat.size.height / 3
        
        // Pad properties
        let padCenter = pad.position
        let padRadius = pad.scaledRadius
        
        // Find the closest point on the boat's rectangle to the pad's center
        let closestX = max(boatCenter.x - boatHalfWidth, min(padCenter.x, boatCenter.x + boatHalfWidth))
        let closestY = max(boatCenter.y - boatHalfHeight, min(padCenter.y, boatCenter.y + boatHalfHeight))
        
        // Calculate the distance squared between the closest point and the pad's center
        let distanceX = padCenter.x - closestX
        let distanceY = padCenter.y - closestY
        let distanceSquared = (distanceX * distanceX) + (distanceY * distanceY)
        
        // If the distance is less than the pad's radius, they are colliding
        return distanceSquared < (padRadius * padRadius)
    }

    private func boatDidCollide(with pad: Pad, boat: Boat) {
        // Calculate push direction away from the boat's center
        let pushDx = pad.position.x - boat.position.x
        let pushDy = pad.position.y - boat.position.y
        let distance = sqrt(pushDx * pushDx + pushDy * pushDy)
        
        let pushStrength: CGFloat = 2.0 // A moderate push force

        if distance > 0 {
            let normalizedPush = CGVector(dx: pushDx / distance, dy: pushDy / distance)
            // Add velocity to the pad. This will be handled in Pad.update()
            pad.velocity.dx += normalizedPush.dx * pushStrength
            pad.velocity.dy += normalizedPush.dy * pushStrength
        } else {
            // If somehow they are at the exact same spot, push upwards.
            pad.velocity.dy += pushStrength
        }

        // Play sound and haptic feedback for the nudge
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.light) // Lighter impact for a nudge
    }
    
    // MARK: - 4-Pack Carryover System
    
    /// Restores unused items from 4-packs back to inventory
    /// This should be called when a run ends to ensure remaining items carry over
    private func restoreUnusedPackItems() {
        PersistenceManager.shared.restoreCarryoverItems()
    }
    
    private func endRace(result: RaceResult) {
        guard !isGameEnding else { return }
        isGameEnding = true
        
        // Stop weather sound effects when the race ends
        SoundManager.shared.stopWeatherSFX(fadeDuration: 0.5)
        
        var coinsWon = coinsCollectedThisRun
        self.raceResult = result
        
        switch result {
        case .win:
            coinsWon += Configuration.GameRules.boatRaceReward + self.raceRewardBonus
            SoundManager.shared.play("coin") // TODO: Add a proper victory sound
        case .lose(let reason):
            // If the frog died from health loss, play the death animation
            if reason == .outOfHealth {
                SoundManager.shared.play("gameOver")
                isUserInteractionEnabled = false
                
                // Stop all frog movement immediately
                frog.velocity = .zero
                frog.zVelocity = 0
                
                // Play the frog's death animation (spins and falls)
                frog.playDeathAnimation { [weak self] in
                    guard let self = self else { return }
                    
                    // Small delay after frog disappears before showing game over
                    let delay = SKAction.wait(forDuration: 0.4)
                    let showGameOver = SKAction.run { [weak self] in
                        guard let self = self else { return }
                        self.reportChallengeProgress()
                        self.restoreUnusedPackItems()
                        self.coordinator?.gameDidEnd(score: self.score, coins: coinsWon, raceResult: self.raceResult)
                    }
                    self.run(SKAction.sequence([delay, showGameOver]))
                }
                return
            } else {
                SoundManager.shared.play("gameOver")
            }
        }
        
        isUserInteractionEnabled = false
        
        let delay = SKAction.wait(forDuration: 1.5)
        let showGameOver = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.reportChallengeProgress()
            self.restoreUnusedPackItems()
            self.coordinator?.gameDidEnd(score: self.score, coins: coinsWon, raceResult: self.raceResult)
        }
        run(SKAction.sequence([delay, showGameOver]))
    }
    
    // MARK: - Launch Pad Detection
    
    /// Checks if the frog has interacted with the launch pad or missed it
    private func checkLaunchPadInteraction() {
        // Check launch pad interaction
        if hasSpawnedLaunchPad && !hasHitLaunchPad {
            // Check if frog is using rocket and passes over/near the launch pad
            if frog.rocketState == .flying {
                let distanceFromLaunchPad = abs(frog.position.y - launchPadY)
                let horizontalDistance = abs(frog.position.x - (Configuration.Dimensions.riverWidth / 2))
                
                // If rocket passes near the launch pad (within reasonable distance)
                if frog.position.y >= launchPadY && 
                   distanceFromLaunchPad < 150 && 
                   horizontalDistance < 150 {
                    hasHitLaunchPad = true
                    
                    // Find the launch pad and trigger the sequence
                    if let launchPad = pads.first(where: { $0.type == .launchPad }) {
                        isLaunchingToSpace = true
                        launchToSpace(from: launchPad)
                    }
                    return
                }
            }
            
            // Check if frog has passed the launch pad without hitting it
            if frog.position.y > launchPadY + launchPadMissDistance {
                // Game over - missed the launch pad!
                handleMissedLaunchPad()
                return
            }
        }
        
        // Check warp pad interaction
        if hasSpawnedWarpPad && !hasHitWarpPad {
            // Check if frog is using rocket and passes over/near the warp pad
            if frog.rocketState == .flying {
                let distanceFromWarpPad = abs(frog.position.y - warpPadY)
                let horizontalDistance = abs(frog.position.x - (Configuration.Dimensions.riverWidth / 2))
                
                // If rocket passes near the warp pad (within reasonable distance)
                if frog.position.y >= warpPadY && 
                   distanceFromWarpPad < 150 && 
                   horizontalDistance < 150 {
                    hasHitWarpPad = true
                    
                    // Find the warp pad and trigger the sequence
                    if let warpPad = pads.first(where: { $0.type == .warp }) {
                        warpBackToDay(from: warpPad)
                    }
                    return
                }
            }
        }
    }
    
    private func handleMissedLaunchPad() {
        // Prevent multiple game overs
        guard !isGameEnding else { return }
        
        // In endless mode, this is just a regular game over
        if gameMode == .endless {
            playEnemyDeathSequence()
        }
        // In race mode, this is a specific race loss
        else if gameMode == .beatTheBoat {
            raceResult = .lose(reason: .missedLaunchPad)
            playEnemyDeathSequence()
        }
    }
    
    // MARK: - Weather Helper for Debug Mode
    /// Determines the correct weather type for a given score value
    private func weatherForScore(_ score: Int) -> WeatherType {
        let weatherIndex = score / weatherChangeInterval
        let allWeathers = WeatherType.allCases
        
        // Clamp to valid weather index
        let clampedIndex = min(weatherIndex, allWeathers.count - 1)
        return allWeathers[clampedIndex]
    }
    
    private func checkWeatherChange() {
        // Don't change weather in daily challenges - it's locked!
        if currentChallenge != nil {
            return
        }
        
        // Don't change weather while in space - warp pad is the only way out!
        if currentWeather == .space {
            return
        }
        
        if score >= nextWeatherChangeScore {
            advanceWeather()
            nextWeatherChangeScore += weatherChangeInterval
        }
    }

    private func advanceWeather() {
        // Don't advance weather if we're already in space - warp pad is the only way out!
        if currentWeather == .space {
            return
        }
        
        let all = WeatherType.allCases
        guard let idx = all.firstIndex(of: currentWeather) else { return }
        let nextIdx = (idx + 1) % all.count
        let nextWeather = all[nextIdx]

        if nextWeather == .desert {
            // The cutscene should not start mid-jump.
            // Set a flag to trigger it once the frog has landed safely.
            isDesertTransitionPending = true
        } else if nextWeather == .space {
            // Space weather should be instant, no gradual transition
            // It's triggered by the launch pad cutscene, not by weather cycling
            // Don't auto-transition to space - skip it and stay in desert
            // Player MUST use the launch pad to enter space
            return
        } else {
            // For all other weather types, use the gradual transition
            setWeather(nextWeather, duration: 60.0)
        }
    }

    private func setWeather(_ type: WeatherType, duration: TimeInterval) {
        let oldWeather = self.currentWeather
        // Force instant transitions for space weather
        var actualDuration = duration
        if type == .space || oldWeather == .space {
            actualDuration = 0.0
        }
        
        // No change if weather is the same, unless it's an instant setup (duration 0)
        if oldWeather == type && actualDuration > 0 { return }

        // --- Game Logic ---
        if oldWeather == .rain {
            frog.isWearingBoots = false
            frog.isRainEffectActive = false
        }
        
        // Show rain tooltip early when leaving night weather to give player time to prepare
        // This shows BEFORE the rain actually starts, during the transition
        if oldWeather == .night && type == .rain {
            ToolTips.showToolTip(forKey: "rain", in: self)
        }
        
        // For rain transitions, delay the slippery mechanics to allow rain to visually fall first
        let rainSlipperyDelay: TimeInterval = (type == .rain && actualDuration > 0) ? 2.5 : 0
        
        self.currentWeather = type
        if type == .rain {
            // Rain tooltip is now shown earlier (during night → rain transition)
            
            // If instant transition (duration 0), activate rain effect immediately
            if rainSlipperyDelay == 0 {
                frog.isRainEffectActive = true
                if frog.buffs.bootsCount > 0 {
                    frog.buffs.bootsCount -= 1
                    frog.isWearingBoots = true
                    HapticsManager.shared.playNotification(.success)
                }
            } else {
                // Delay applying boots/slippery mechanics when transitioning to rain
                let applyRainEffects = SKAction.sequence([
                    SKAction.wait(forDuration: rainSlipperyDelay),
                    SKAction.run { [weak self] in
                        guard let self = self else { return }
                        self.frog.isRainEffectActive = true
                        if self.frog.buffs.bootsCount > 0 {
                            self.frog.buffs.bootsCount -= 1
                            self.frog.isWearingBoots = true
                            HapticsManager.shared.playNotification(.success)
                        }
                    }
                ])
                run(applyRainEffects, withKey: "applyRainEffects")
            }
        }
        
        // --- Clear old weather particles immediately when switching to desert ---
        if type == .desert {
            weatherNode.removeAllChildren()
        }
        
        // --- Convert Incompatible Pads ---
        // Transform pads that aren't allowed in the new weather (e.g., logs/ice pads in desert)
        for pad in pads {
            pad.convertToNormalIfIncompatible(weather: type)
        }
        
        // --- Update Enemy Visuals ---
        // Update enemy appearances for the new weather (e.g., bees become space bees, dragonflies become asteroids)
        for enemy in enemies {
            enemy.updateWeather(type)
        }
        
        // --- Visual & Audio Transitions ---
        VFXManager.shared.transitionWeather(from: oldWeather, to: type, in: self, duration: actualDuration)
        
        // MARK: - Moonlight Renderer Control
        // Activate moonlight during night and rain scenes (both are dark), deactivate for all other weather
        if type == .night || type == .rain {
            moonlightRenderer?.activate(animated: true)
            moonlightRenderer?.startPulseAnimation(duration: 3.0)
        } else {
            moonlightRenderer?.deactivate(animated: true)
            moonlightRenderer?.stopPulseAnimation()
        }
        
        // Handle leaf spawning based on weather change
        if type == .sunny && oldWeather != .sunny {
            startSpawningLeaves()
        } else if type != .sunny && oldWeather == .sunny {
            stopSpawningLeaves()
        }
        
        let sfx: SoundManager.WeatherSFX? = switch type {
        case .rain: .rain
        case .winter: .winter
        case .night: .night
        case .sunny: nil
        case .desert: .desert
        case .space: .space
                }
        
        if type == .space {
            SoundManager.shared.stopMusic()
        }
        
        // Stop previous weather SFX before starting new one
        // Always stop, regardless of duration (for instant transitions too)
        SoundManager.shared.stopWeatherSFX(fadeDuration: actualDuration > 0 ? actualDuration : 0.0)
        SoundManager.shared.playWeatherSFX(sfx, fadeDuration: actualDuration)
        
        // --- In-World Object Transitions ---
        // CRITICAL FIX: Batch pad updates to prevent creating hundreds of sprites/actions at once
        let batchSize = 10  // Process 10 pads at a time
        let batchDelay: TimeInterval = 0.016  // ~1 frame delay between batches (60fps)
        
        for (batchIndex, batch) in stride(from: 0, to: pads.count, by: batchSize).enumerated() {
            let endIndex = min(batch + batchSize, pads.count)
            let padBatch = Array(pads[batch..<endIndex])
            
            let delay = batchDelay * Double(batchIndex)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                for pad in padBatch {
                    pad.updateColor(weather: type, duration: actualDuration)
                }
            }
        }

        // Update water background with new gradient
        transitionWaterBackground(to: type, duration: actualDuration)
        
        // Handle water stars for night mode
        if type == .night {
            createWaterStars()
        } else if oldWeather == .night {
            removeWaterStars()
        }
        
        // Handle water lines - hide in desert/space, show in water biomes
        if type == .desert || type == .space {
            removeWaterLines()
            removeWaterShimmers()  // Also remove shimmers
            removeShores()  // Also hide shores in desert/space
        } else if (oldWeather == .desert || oldWeather == .space) && (type != .desert && type != .space) {
            restoreWaterLines()
            restoreWaterShimmers()  // Restore shimmers
            restoreShores()  // Restore shores when returning to water biomes
        } else {
            // No water line changes needed
        }

        // Handle moonlight visibility with a fade for smooth transitions.
        if let moon = moonlightNode {
            // Show moonlight during both night and rain scenes (both are dark)
            if type == .night || type == .rain {
                moon.isHidden = false
                if actualDuration > 0 {
                    moon.run(SKAction.fadeAlpha(to: 1.0, duration: actualDuration))
                } else {
                    moon.alpha = 1.0
                }
            } else if oldWeather == .night || oldWeather == .rain {
                if actualDuration > 0 {
                    // Hide after fade out to stop processing it.
                    let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: actualDuration)
                    let hide = SKAction.run { moon.isHidden = true }
                    moon.run(SKAction.sequence([fadeOut, hide]))
                } else {
                    moon.alpha = 0.0
                    moon.isHidden = true
                }
            }
        }
        
        // Handle space glow visibility
        if let spaceGlow = spaceGlowNode {
            if type == .space {
                spaceGlow.isHidden = false
                if actualDuration > 0 {
                    spaceGlow.run(SKAction.fadeAlpha(to: 1.0, duration: actualDuration))
                } else {
                    spaceGlow.alpha = 1.0
                }
            } else if oldWeather == .space {
                if actualDuration > 0 {
                    let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: actualDuration)
                    let hide = SKAction.run { spaceGlow.isHidden = true }
                    spaceGlow.run(SKAction.sequence([fadeOut, hide]))
                } else {
                    spaceGlow.alpha = 0.0
                    spaceGlow.isHidden = true
                }
            }
        }
    }
    
    // MARK: - Desert Cutscene
    
    private func checkPendingDesertTransition() {
        // Start the desert cutscene only if the transition is pending
        // and the frog is safely on a pad (not mid-air).
        if isDesertTransitionPending && frog.onPad != nil {
            isDesertTransitionPending = false // Consume the flag
            startDesertCutscene()
        }
    }
    
    private func startDesertCutscene() {
        isInCutscene = true
        isUserInteractionEnabled = false
        ToolTips.showToolTip(forKey: "desert", in: self)
            
        frog.velocity = .zero // Stop frog movement
        SoundManager.shared.stopMusic(fadeDuration: 1.0)
        
        let cutsceneDuration: TimeInterval = 4.0
        
        playDesertTransition(duration: cutsceneDuration)
        
        // After the animation duration, end the cutscene
        let wait = SKAction.wait(forDuration: cutsceneDuration)
        let end = SKAction.run { [weak self] in
            self?.endDesertCutscene()
        }
        run(SKAction.sequence([wait, end]))
    }

    private func playDesertTransition(duration: TimeInterval) {
        let oldWeather = self.currentWeather
        let newWeather: WeatherType = .desert

        // --- Visual & Audio Transitions ---
        // IMPORTANT: Remove all existing weather particles FIRST before transitioning
        weatherNode.removeAllChildren()
        
        VFXManager.shared.transitionWeather(from: oldWeather, to: newWeather, in: self, duration: duration)
        SoundManager.shared.stopWeatherSFX(fadeDuration: duration)
        SoundManager.shared.playWeatherSFX(.desert, fadeDuration: duration)

        // --- In-World Object Transitions ---
        for pad in pads {
            pad.transformToDesert(duration: duration)
        }

        // --- Water to Sand Transition ---
        // Fade out and scale down the water background to simulate evaporation
        if let waterBackground = waterBackgroundNode {
            let evaporationDuration = duration * 0.8
            let evaporateAction = SKAction.group([
                SKAction.scaleY(to: 0.05, duration: evaporationDuration),
                SKAction.fadeOut(withDuration: evaporationDuration)
            ])
            evaporateAction.timingMode = .easeIn
            waterBackground.run(evaporateAction)
        }
    }

    private func endDesertCutscene() {
        // Officially set the game state to desert. This updates logic like instant-death water.
        // Use setWeather to ensure pads are converted properly
        setWeather(.desert, duration: 0.0)
        
        // Recreate the water background as sand
        recreateWaterBackground()
        
        isInCutscene = false
        isUserInteractionEnabled = true
        
        // Resume music.
        SoundManager.shared.playMusic(baseMusic)
    }
    
    // MARK: - Space Launch
    
    private func launchToSpace(from pad: Pad) {
        // Disable user interaction during the launch sequence
        isUserInteractionEnabled = false
        isInCutscene = true
        
        // Stop all frog movement
        frog.velocity = .zero
        frog.onPad = pad
        
        // Play launch sound
        SoundManager.shared.play("rocket")
        SoundManager.shared.stopMusic(fadeDuration: 1.0)
        
        // Haptic feedback for launch
        HapticsManager.shared.playNotification(.success)
        
        // Create sparkle effects around the launch pad
        VFXManager.shared.spawnSparkles(at: pad.position, in: self)
        
        // Animate the frog shooting upward
        let launchHeight: CGFloat = 800
        let launchDuration: TimeInterval = 2.0
        
        let shootUp = SKAction.moveBy(x: 0, y: launchHeight, duration: launchDuration)
        shootUp.timingMode = .easeIn
        
        let spinAction = SKAction.rotate(byAngle: .pi * 4, duration: launchDuration)
        
        let launchGroup = SKAction.group([shootUp, spinAction])
        
        frog.run(launchGroup) { [weak self] in
            guard let self = self else { return }
            
            // Start fading to black
            self.fadeToBlackAndTransitionToSpace()
        }
    }
    
    private func fadeToBlackAndTransitionToSpace() {
        // Instant transition to space - no fade to black
        transitionToSpace()
        
        // Ensure space glow is visible and at full brightness
        if let spaceGlow = self.spaceGlowNode {
            spaceGlow.isHidden = false
            spaceGlow.alpha = 1.0
        }
    }
    
    private func transitionToSpace() {
        
        // IMPORTANT: Remove the launch pad from the scene
        if let launchPadIndex = pads.firstIndex(where: { $0.type == .launchPad }) {
            pads[launchPadIndex].removeFromParent()
            pads.remove(at: launchPadIndex)
        }
        
        // Set the weather to space - INSTANT transition (duration: 0)
        setWeather(.space, duration: 0.0)
        
        // The space glow is already created and managed by setWeather()
        // Just ensure its position is updated immediately
        if let spaceGlow = spaceGlowNode {
            spaceGlow.position = CGPoint(
                x: cam.position.x * 0.85,
                y: cam.position.y * 0.85
            )
        }
        
        // Instantly update all existing pads to space appearance
        for pad in pads {
            pad.updateColor(weather: .space, duration: 0.0)
        }
        
        // Reset launch flags - allow warp pad to potentially spawn later
        hasSpawnedLaunchPad = false
        hasHitLaunchPad = false
        launchPadY = 0
        isLaunchingToSpace = false
        
        // Find a safe landing pad ahead of the frog's current position
        var landingPad: Pad?
        
        // Look for the nearest pad ahead of the frog (prefer normal pads)
        for pad in pads.sorted(by: { $0.position.y < $1.position.y }) {
            if pad.position.y > frog.position.y && pad.type == .normal {
                landingPad = pad
                break
            }
        }
        
        // If no normal pad found, just use any pad ahead
        if landingPad == nil {
            landingPad = pads.first(where: { $0.position.y > frog.position.y && $0.type != .log })
        }
        
        // If still no pad (shouldn't happen), create one
        if landingPad == nil {
            let newPad = Pad(
                type: .normal,
                position: CGPoint(
                    x: Configuration.Dimensions.riverWidth / 2,
                    y: frog.position.y + 200
                )
            )
            newPad.updateColor(weather: .space, duration: 0.0)
            worldNode.addChild(newPad)
            pads.append(newPad)
            landingPad = newPad
        }
        
        // Land the frog safely on the pad
        if let pad = landingPad {
            frog.position = pad.position
            frog.zHeight = 0
            frog.velocity = .zero
            frog.zVelocity = 0
            frog.land(on: pad, weather: .space)
            
            // Spawn a ripple effect for dramatic landing
            spawnWaterRipple(for: pad)
        }
        
        // Re-enable user interaction
        isInCutscene = false
        isUserInteractionEnabled = true
        
        // Play space music (you'll need to add this to SoundManager)
        SoundManager.shared.playMusic(.gameplay) // Use gameplay for now, or create a new space track
        
        // Optional: Show a "WELCOME TO SPACE" message
        showSpaceWelcomeMessage()
    }
    
    private func showSpaceWelcomeMessage() {
        let welcomeLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
        welcomeLabel.text = "SPACE"
        welcomeLabel.fontSize = 60
        welcomeLabel.fontColor = .white
        welcomeLabel.position = .zero
        welcomeLabel.zPosition = Layer.ui + 50
        welcomeLabel.alpha = 0
        
        cam.addChild(welcomeLabel)
        
        // Fade in, hold, then fade out
        let fadeIn = SKAction.fadeIn(withDuration: 1.0)
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let remove = SKAction.removeFromParent()
        
        welcomeLabel.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }
    
    // MARK: - Warp Back to Day
    
    private func warpBackToDay(from pad: Pad) {
        // Disable user interaction during the warp sequence
        isUserInteractionEnabled = false
        isInCutscene = true
        
        // Stop all frog movement
        frog.velocity = .zero
        frog.onPad = pad
        
        // Play warp sound - using rocket sound as placeholder until warp sound is added
        SoundManager.shared.play("rocket")
        SoundManager.shared.stopMusic(fadeDuration: 1.0)
        
        // Haptic feedback for warp
        HapticsManager.shared.playNotification(.success)
        
        // Create sparkle/portal effects around the warp pad
        VFXManager.shared.spawnSparkles(at: pad.position, in: self)
        
        // Animate the warp pad spinning faster
        let spinAction = SKAction.rotate(byAngle: .pi * 8, duration: 2.0)
        pad.run(spinAction)
        
        // Start the fade immediately
        fadeToBlackAndWarp()
    }
    
    private func fadeToBlackAndWarp() {
        // Create a black overlay that covers the entire screen
        let blackOverlay = SKSpriteNode(color: .black, size: self.size)
        blackOverlay.position = .zero
        blackOverlay.zPosition = Layer.overlay + 100 // Above everything
        blackOverlay.alpha = 0
        
        cam.addChild(blackOverlay)
        
        // Fade to black
        let fadeOut = SKAction.fadeIn(withDuration: Configuration.GameRules.warpFadeOutDuration)
        
        blackOverlay.run(fadeOut) { [weak self] in
            guard let self = self else { return }
            
            // After fade is complete, reset to day weather
            self.resetToDay()
            
            // Wait a moment then fade back in
            let wait = SKAction.wait(forDuration: Configuration.GameRules.warpBlackScreenDuration)
            let fadeIn = SKAction.fadeOut(withDuration: Configuration.GameRules.warpFadeInDuration)
            let remove = SKAction.removeFromParent()
            
            blackOverlay.run(SKAction.sequence([wait, fadeIn, remove]))
        }
    }
    
    private func resetToDay() {
        
        // 1. Change weather to sunny
        setWeather(.sunny, duration: 0.0)
        
        // 2. Clear all existing entities except frog
        // Remove all pads
        pads.forEach { $0.removeFromParent() }
        pads.removeAll()
        
        // Remove all enemies
        enemies.forEach { $0.removeFromParent() }
        enemies.removeAll()
        
        // Remove all coins
        coins.forEach { $0.removeFromParent() }
        coins.removeAll()
        
        // Remove all snakes
        snakes.forEach { $0.removeFromParent() }
        snakes.removeAll()
        
        // Remove all cacti
        cacti.forEach { $0.removeFromParent() }
        cacti.removeAll()
        
        // Remove all crocodiles
        crocodiles.forEach { $0.removeFromParent() }
        crocodiles.removeAll()
        
        // Remove all treasure chests
        treasureChests.forEach { $0.removeFromParent() }
        treasureChests.removeAll()
        
        // Remove all flies
        flies.forEach { $0.removeFromParent() }
        flies.removeAll()
        
        // Remove all flotsam
        flotsam.forEach { $0.removeFromParent() }
        flotsam.removeAll()
        
        // 3. Create a new starting pad for the frog
        let startPadY = frog.position.y + 200
        let startPad = Pad(
            type: .normal,
            position: CGPoint(x: Configuration.Dimensions.riverWidth / 2, y: startPadY),
            radius: 60
        )
        startPad.updateColor(weather: .sunny)
        worldNode.addChild(startPad)
        pads.append(startPad)
        
        // 4. Reset frog to the new pad
        frog.position = startPad.position
        frog.zHeight = 0
        frog.velocity = .zero
        frog.zVelocity = 0
        frog.onPad = startPad
        
        // 5. Spawn new pads ahead (simple initial generation)
        var lastY = startPad.position.y
        for i in 1...15 {
            let padY = lastY + CGFloat.random(in: 100...140)
            let padX = CGFloat.random(in: 80...Configuration.Dimensions.riverWidth - 80)
            
            let newPad = Pad(
                type: .normal,
                position: CGPoint(x: padX, y: padY),
                radius: Configuration.Dimensions.randomPadRadius()
            )
            newPad.updateColor(weather: .sunny)
            worldNode.addChild(newPad)
            pads.append(newPad)
            lastY = padY
        }
        
        // 6. Reset warp pad tracker so it can spawn again if player reaches space again
        hasSpawnedWarpPad = false
        hasHitWarpPad = false
        warpPadY = 0
        
        // 7. Reset launch pad tracker for potential future space trips
        hasSpawnedLaunchPad = false
        hasHitLaunchPad = false
        launchPadY = 0
        isLaunchingToSpace = false
        
        // 8. Re-enable user interaction
        isInCutscene = false
        isUserInteractionEnabled = true
        
        // 9. Play normal music
        SoundManager.shared.playMusic(baseMusic)
        
        // 10. Show a "RETURNED TO EARTH" message
        showWarpReturnMessage()
    }
    
    private func showWarpReturnMessage() {
        let returnLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
        returnLabel.text = "☀️ BACK TO EARTH ☀️"
        returnLabel.fontSize = 40
        returnLabel.fontColor = .white
        returnLabel.position = .zero
        returnLabel.zPosition = Layer.ui + 50
        returnLabel.alpha = 0
        
        cam.addChild(returnLabel)
        
        // Fade in, hold, then fade out
        let fadeIn = SKAction.fadeIn(withDuration: 1.0)
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let remove = SKAction.removeFromParent()
        
        returnLabel.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }
    
    private func updateCamera() {
        let targetX = frog.position.x
        let targetY = frog.position.y + (size.height * 0.2)
        let lerpSpeed: CGFloat = (frog.rocketState != .none) ? 0.2 : 0.1
        cam.position.x += (targetX - cam.position.x) * lerpSpeed
        cam.position.y += (targetY - cam.position.y) * 0.1
    }
    
    // MARK: - Entity Tooltips
    
    /// Efficiently checks if any new entity types are visible and triggers tooltips
    /// This method is designed for performance with early exits and visibility culling
    private func checkEntityTooltips() {
        // Don't check during pauses, transitions, or if no view
        guard !isPaused, let view = view else { return }
        
        // Calculate the visible rect for culling entities outside the camera view
        let visibleRect = calculateVisibleRect()
        
        // Check enemies (bees, dragonflies, ghosts) - they have a 'type' property
        if !enemies.isEmpty {
            ToolTips.checkForEntityEncounters(
                entities: enemies,
                scene: self,
                visibleRect: visibleRect,
                entityTypeGetter: { enemy in enemy.type },
                entityPositionGetter: { enemy in enemy.position }
            )
        }
        
        // Check for logs (they're in the pads array with type == .log)
        if !pads.isEmpty {
            let logs = pads.filter { $0.type == .log }
            if !logs.isEmpty {
                ToolTips.checkForEntityEncounters(
                    entities: logs,
                    scene: self,
                    visibleRect: visibleRect,
                    entityTypeGetter: { _ in "LOG" }, // All logs use the same tooltip
                    entityPositionGetter: { pad in pad.position }
                )
            }
            
            // Check for grave lilypads - show ghost tooltip when first grave appears
            let gravePads = pads.filter { $0.type == .grave }
            if !gravePads.isEmpty {
                for gravePad in gravePads {
                    // Check if this grave is visible on screen
                    if visibleRect.contains(gravePad.position) {
                        // Trigger the ghost tooltip when first grave appears
                        ToolTips.onGraveLilypadAppeared(in: self)
                        break // Only show once per frame
                    }
                }
            }
        }
        
        // Check for flies
        if !flies.isEmpty {
            ToolTips.checkForEntityEncounters(
                entities: flies,
                scene: self,
                visibleRect: visibleRect,
                entityTypeGetter: { _ in "FLY" }, // All flies use the same tooltip
                entityPositionGetter: { fly in fly.position }
            )
        }
    }
    
    /// Calculates the visible rectangle based on camera position and view size
    /// Adds padding to trigger tooltips slightly before entities are fully visible
    private func calculateVisibleRect() -> CGRect {
        if let view = view {
            let cameraPos = cam.position
            let viewSize = view.bounds.size
            
            // Add padding to trigger tooltips slightly before entities are fully on-screen
            // This gives players a moment to react to the tooltip before the threat arrives
            let padding: CGFloat = 100
            
            return CGRect(
                x: cameraPos.x - viewSize.width / 2 - padding,
                y: cameraPos.y - viewSize.height / 2 - padding,
                width: viewSize.width + padding * 2,
                height: viewSize.height + padding * 2
            )
        } else {
            // Fallback - use entire scene (shouldn't happen in practice)
            return CGRect(origin: .zero, size: size)
        }
    }
    
    private func updateMoonlightPosition() {
        guard let moonlightNode = moonlightNode, !moonlightNode.isHidden else { return }
        
        // PERFORMANCE: Throttle moonlight updates to every 2 frames
        if frameCount % 2 != 0 { return }
        
        // Create a parallax effect by moving the light source slower than the camera.
        // This gives the illusion of a distant moon.
        // A slight horizontal offset suggests the moon is off to one side.
        let parallaxFactor: CGFloat = 0.9
        let horizontalOffset: CGFloat = 200
        moonlightNode.position = CGPoint(
            x: cam.position.x * parallaxFactor + horizontalOffset,
            y: cam.position.y * parallaxFactor
        )
    }
    
    private func updateSpaceGlowPosition() {
        guard let spaceGlowNode = spaceGlowNode, !spaceGlowNode.isHidden else { return }
        
        // PERFORMANCE: Throttle space glow updates to every 2 frames
        if frameCount % 2 != 0 { return }
        
        // Similar parallax effect for space glow, but even slower for a distant nebula feel
        let parallaxFactor: CGFloat = 0.85
        spaceGlowNode.position = CGPoint(
            x: cam.position.x * parallaxFactor,
            y: cam.position.y * parallaxFactor
        )
    }
    private func cleanupOffscreenEntities() {
        // CRITICAL PERFORMANCE FIX: Enforce maximum entity counts
        // Prevents unbounded array growth that kills frame rate
        let maxTotalPads: Int = 50
        let maxTotalEnemies: Int = 30
        let maxTotalCoins: Int = 40
        let maxTotalSnakes: Int = 10
        let maxTotalCrocodiles: Int = 8
        
        // Aggressively remove oldest entities if we exceed limits
        while pads.count > maxTotalPads {
            if let oldestPad = pads.first {
                oldestPad.removeFromParent()
                pads.removeFirst()
            }
        }
        
        while enemies.count > maxTotalEnemies {
            if let oldestEnemy = enemies.first {
                oldestEnemy.removeFromParent()
                enemies.removeFirst()
            }
        }
        
        while coins.count > maxTotalCoins {
            if let oldestCoin = coins.first {
                oldestCoin.removeFromParent()
                coins.removeFirst()
            }
        }
        
        while snakes.count > maxTotalSnakes {
            if let oldestSnake = snakes.first {
                oldestSnake.removeFromParent()
                snakes.removeFirst()
            }
        }
        
        while crocodiles.count > maxTotalCrocodiles {
            // Don't remove the crocodile the frog is riding
            if let oldestCroc = crocodiles.first, oldestCroc !== ridingCrocodile {
                oldestCroc.removeFromParent()
                crocodiles.removeFirst()
            } else {
                break  // Can't remove first one, stop trying
            }
        }
        
        // Now do normal position-based cleanup
        let thresholdY = cam.position.y - (size.height / 2) - 200
        pads.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        enemies.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        coins.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        treasureChests.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        flies.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        flotsam.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        
        // Cacti are children of pads, so they're already removed when pads are removed
        // But we need to clean up destroyed cacti from the array
        cacti.removeAll { $0.isDestroyed || $0.parent == nil }
        
        // Cleanup snakes that have fallen behind the frog OR moved off screen
        // Snakes move horizontally (left to right), so we need to check both Y and X positions
        // IMPORTANT: Give snakes a MUCH larger Y threshold since they move horizontally
        let snakeThresholdY = cam.position.y - (size.height / 2) - 1000  // Much more generous!
        var i = 0
        while i < snakes.count {
            let snake = snakes[i]
            let isBelowCamera = snake.position.y < snakeThresholdY
            let isOffScreenRight = snake.position.x > Configuration.Dimensions.riverWidth + 300  // Increased buffer
            let isOffScreenLeft = snake.position.x < -300  // Also check if stuck off left edge
            
            if isBelowCamera || isOffScreenRight || isOffScreenLeft || snake.isDestroyed {
                snake.removeFromParent()
                snakes.remove(at: i)
            } else {
                i += 1
            }
        }
        
        crocodiles.removeAll { croc in
            // Don't remove the crocodile the frog is riding
            if croc === ridingCrocodile { return false }
            if croc.position.y < thresholdY { 
                croc.removeFromParent()
                return true 
            }
            return false
        }
    }
    private func generateNextLevelSlice(lastPad: Pad) {
        // Don't spawn new pads if we're waiting for the player to hit the warp pad
        if hasSpawnedWarpPad && !hasHitWarpPad {
            return
        }
        
        // Don't spawn new pads if we're waiting for the player to hit the launch pad
        if hasSpawnedLaunchPad && !hasHitLaunchPad && currentWeather == .desert {
            return
        }
        
        var newY: CGFloat = 0
        var newX: CGFloat = 0
        var attempts = 0
        
        // Pre-generate a random radius for the new pad
        let newPadRadius = Configuration.Dimensions.randomPadRadius()
        
        // Minimum distance accounts for both pad radii plus spacing
        let minDistance = lastPad.scaledRadius + newPadRadius + Configuration.Dimensions.padSpacing
        
        repeat {
            let distY = CGFloat.random(in: 80...140)
            newY = lastPad.position.y + distY
            let maxDeviationX: CGFloat = 150
            // Account for the new pad's radius when constraining to river bounds
            let minX = max(newPadRadius + Configuration.Dimensions.padSpacing, lastPad.position.x - maxDeviationX)
            let maxX = min(Configuration.Dimensions.riverWidth - newPadRadius - Configuration.Dimensions.padSpacing, lastPad.position.x + maxDeviationX)
            newX = CGFloat.random(in: minX...maxX)
            let dx = newX - lastPad.position.x
            let dy = newY - lastPad.position.y
            let dist = sqrt(dx*dx + dy*dy)
            attempts += 1
            if attempts > 15 || dist >= minDistance { break }
        } while true
        
        var type: Pad.PadType = .normal
        let scoreVal = Int(frog.position.y / 10)
        let difficultyLevel = Configuration.Difficulty.level(forScore: scoreVal)
        
        // Check if we should spawn the launch pad (end of desert, before space)
        if currentWeather == .desert && !hasSpawnedLaunchPad && scoreVal >= Configuration.GameRules.launchPadSpawnScore {
            type = .launchPad
            hasSpawnedLaunchPad = true
            
            // Center the launch pad in the river for dramatic effect
            newX = Configuration.Dimensions.riverWidth / 2
            launchPadY = newY
        }
        // Check if we should spawn the warp pad (end of space, return to day)
        else if currentWeather == .space && !hasSpawnedWarpPad && scoreVal >= Configuration.GameRules.warpPadSpawnScore {
            type = .warp
            hasSpawnedWarpPad = true
            
            // Center the warp pad in the river for dramatic effect
            newX = Configuration.Dimensions.riverWidth / 2
            warpPadY = newY
        } else {
            // Normal pad type selection based on difficulty level
            if let challenge = currentChallenge {
                // Daily challenge mode - respect pad focus
                if challenge.focusPadTypes.contains(.moving) {
                    let moveProb = DailyChallenges.shared.getPadSpawnProbability(for: .moving, in: challenge)
                    if Double.random(in: 0...1) < moveProb {
                        type = .moving
                    }
                } else if challenge.focusPadTypes.contains(.shrinking) {
                    let shrinkProb = DailyChallenges.shared.getPadSpawnProbability(for: .shrinking, in: challenge)
                    if Double.random(in: 0...1) < shrinkProb {
                        type = .shrinking
                    }
                } else if challenge.focusPadTypes.contains(.ice) {
                    let iceProb = DailyChallenges.shared.getPadSpawnProbability(for: .ice, in: challenge)
                    if Double.random(in: 0...1) < iceProb && currentWeather != .desert {
                        type = .ice
                    }
                } else {
                    // Mixed mode - use normal probabilities but scaled down
                    if difficultyLevel >= Configuration.Difficulty.movingPadStartLevel && Double.random(in: 0...1) < 0.15 {
                        type = .moving
                    } else if difficultyLevel >= Configuration.Difficulty.shrinkingPadStartLevel && Double.random(in: 0...1) < 0.15 {
                        type = .shrinking
                    } else if currentWeather != .desert && difficultyLevel >= Configuration.Difficulty.icePadStartLevel && Double.random(in: 0...1) < 0.10 {
                        type = .ice
                    }
                }
            } else {
                // Normal endless mode - use standard difficulty scaling
                if difficultyLevel >= Configuration.Difficulty.movingPadStartLevel && Double.random(in: 0...1) < Configuration.Difficulty.movingPadProbability {
                    type = .moving
                } else if currentWeather != .desert && difficultyLevel >= Configuration.Difficulty.icePadStartLevel && Double.random(in: 0...1) < Configuration.Difficulty.icePadProbability {
                    // Ice pads don't spawn in desert
                    type = .ice
                }
            }
            
            if scoreVal > 150 && Double.random(in: 0...1) < 0.15 { type = .waterLily }
            if currentWeather == .night && Double.random(in: 0...1) < 0.15 { type = .grave }
            
            // Shrinking pads - apply in both challenge and normal mode
            if let challenge = currentChallenge {
                if challenge.focusPadTypes.contains(.shrinking) {
                    let shrinkProb = DailyChallenges.shared.getPadSpawnProbability(for: .shrinking, in: challenge)
                    if Double.random(in: 0...1) < shrinkProb && type != .moving && type != .ice {
                        type = .shrinking
                    }
                }
            } else {
                let shrinkingChance = Configuration.Difficulty.shrinkingProbability(forLevel: difficultyLevel)
                if Double.random(in: 0...1) < shrinkingChance { type = .shrinking }
            }
        }
        
        let pad = Pad(type: type, position: CGPoint(x: newX, y: newY), radius: newPadRadius)
        pad.updateColor(weather: currentWeather)
        worldNode.addChild(pad)
        pads.append(pad)
        
        // Don't spawn anything on special pads (launch pad, warp pad) - they're special!
        if type == .launchPad || type == .warp {
            return
        }
        
        // Spawn crocodile near water lily pads
        // Only spawn if: score >= 2500 and we haven't reached max crocodiles this run
        let canSpawnCrocodile = scoreVal >= Configuration.Difficulty.crocodileMinScore &&
                                crocodilesSpawnedThisRun < Configuration.Difficulty.crocodileMaxPerRun
        if type == .waterLily && currentWeather != .space && canSpawnCrocodile && Double.random(in: 0...1) < Configuration.Difficulty.crocodileSpawnProbability(for: currentWeather) {
            // Find a valid spawn position in the water (not overlapping any pads/logs)
            if let crocPosition = findCrocodileSpawnPosition(nearY: newY) {
                // Random delay before rising (1-4 seconds)
                let riseDelay = TimeInterval.random(in: 1.0...4.0)
                let crocodile = Crocodile(position: crocPosition, riseDelay: riseDelay)
                worldNode.addChild(crocodile)
                crocodiles.append(crocodile)
                crocodilesSpawnedThisRun += 1
            }
        }
        
        // Spawn additional lily pads in a chain (each within 50 pixels of another)
        // This applies to normal pads only, not on water lilies
        if type == .normal {
            spawnLilyPadChain(startingAt: pad.position, count: Int.random(in: 2...4))
        }
        
        // Ghost spawning moved to didLand - ghost only appears when frog disturbs the grave
        
        // MARK: - Log Spawning with Collision Detection
        // Logs spawn based on difficulty and move horizontally across the river.
        // Three safety checks ensure logs don't collide with lilypads:
        // 1. Don't overlap with the newly spawned pad at this position
        // 2. Horizontal path must be clear of ALL lilypads at this Y level
        // 3. Y position must be far enough from other logs/moving pads
        let logChance = Configuration.Difficulty.logProbability(forLevel: difficultyLevel)
        if currentWeather != .desert && logChance > 0 && Double.random(in: 0...1) < logChance {
            let logX = CGFloat.random(in: 100...500)
            let proposedLogPosition = CGPoint(x: logX, y: newY)
            
            // CHECK 1: Ensure logs don't overlap with the newly spawned pad
            let minLogDistance = 60.0 + pad.scaledRadius + Configuration.Dimensions.padSpacing
            let doesntOverlapNewPad = abs(logX - newX) > minLogDistance
            
            // CHECK 2: Ensure log's horizontal path is clear of existing lilypads
            // (Logs move left-right, so any lilypad at this Y level would cause collision)
            let pathIsClear = Pad.isLogPathClear(at: proposedLogPosition, existingPads: pads)
            
            // CHECK 3: Ensure Y position is safe from other moving elements
            let yPositionIsSafe = Pad.isYPositionSafeForLog(newY, existingPads: pads)
            
            if doesntOverlapNewPad && pathIsClear && yPositionIsSafe {
                let log = Pad(type: .log, position: proposedLogPosition)
                worldNode.addChild(log)
                pads.append(log)
            } else {
                // Debug: Log why spawn was rejected (helpful for tuning difficulty)
                // Log spawn rejected
            }
        }
        
        // Snake spawning based on difficulty (mirrors log spawning logic)
        let snakeChance = Configuration.Difficulty.snakeProbability(forScore: scoreVal, weather: currentWeather)
        let activeSnakesCount = snakes.filter { !$0.isDestroyed }.count
        
        // DEBUG MODE: Force higher spawn rate for testing (remove this for production)
        let debugSnakeChance = max(snakeChance, scoreVal >= 2400 ? 0.8 : 0.0)  // 80% chance when score >= 2400
        
        if debugSnakeChance > 0 && Double.random(in: 0...1) < debugSnakeChance && activeSnakesCount < Configuration.Difficulty.snakeMaxOnScreen {
            // IMPORTANT: Spawn snake closer to the camera, not at the edge of generation
            // Snakes move horizontally and need to be visible for ~3-4 seconds to cross the screen
            // So spawn them within the visible range, not at the far edge where pads generate
            let snakeX: CGFloat = -50  // Start off-screen to the left
            
            // Spawn snake in the MIDDLE of the screen vertically, relative to camera
            // This ensures the player can see it crossing
            let screenHeight = self.size.height
            let snakeY = cam.position.y + CGFloat.random(in: -screenHeight/4...screenHeight/4)
            
            let snake = Snake(position: CGPoint(x: snakeX, y: snakeY))
            snake.zPosition = Layer.item + 2  // Above coins and other items (Layer.item is 20, so this is 22)
            
            worldNode.addChild(snake)
            snakes.append(snake)
        }
        if Double.random(in: 0...1) < 0.5 {
            let coin = Coin(position: pad.position)
            coin.zHeight = 20
            worldNode.addChild(coin)
            coins.append(coin)
        }
        
        // Fly spawning - 5% chance on normal lily pads
        // Flies buzz around the pad and heal the frog when collected
        let canSpawnFly = (type == .normal || type == .moving || type == .waterLily)
        if canSpawnFly && Double.random(in: 0...1) < 0.05 {
            let fly = Fly(position: pad.position)
            worldNode.addChild(fly)
            flies.append(fly)
        }
        
        // Treasure Chest spawning - rare but valuable!
        // ~8% chance on normal/moving lilypads, not on logs, ice, graves, or shrinking pads
        let canSpawnChest = (type == .normal || type == .moving || type == .waterLily)
        if canSpawnChest && Double.random(in: 0...1) < 0.01 {
            let chest = TreasureChest(position: pad.position)
            worldNode.addChild(chest)
            treasureChests.append(chest)
        }
        
        // Cactus spawning (Desert Only) - stationary hazards on lily pad centers
        let cactusProb = Configuration.Difficulty.cactusProbability(forScore: scoreVal, weather: currentWeather)
        
        // Cacti can spawn on normal, moving, and water lily pads in the desert
        // They should NOT spawn on shrinking pads, graves, logs, ice, or special pads
        // Check BOTH the score threshold AND weather to handle the desert cutscene transition
        let isInDesertScore = scoreVal >= Configuration.Weather.desertStart && scoreVal < Configuration.Weather.spaceStart
        let canSpawnCactus = (type == .normal || type == .moving || type == .waterLily) && 
                             (currentWeather == .desert || isInDesertScore)
        
        if canSpawnCactus && cactusProb > 0 && Double.random(in: 0...1) < cactusProb {
            // Spawn cactus at the center of the pad (position relative to pad is 0,0)
            let cactus = Cactus(position: CGPoint(x: 0, y: 0), weather: currentWeather)
            pad.addChild(cactus)  // Add as child of pad so it moves with the pad
            cacti.append(cactus)
        }
        
        // Enemy spawning based on difficulty - enemies spawn on lily pads
        let enemyProb: Double
        if let challenge = currentChallenge {
            // Daily challenge mode - use challenge-specific probability
            let distanceMeters = scoreVal / 10
            enemyProb = DailyChallenges.shared.getEnemySpawnProbability(for: challenge, distance: distanceMeters)
        } else {
            // Normal mode - use difficulty scaling
            enemyProb = Configuration.Difficulty.enemyProbability(forLevel: difficultyLevel, weather: currentWeather)
        }
        
        // Enemies can spawn on normal, moving, ice, and water lily pads.
        // They should NOT spawn on shrinking pads, graves (which spawn ghosts), or logs.
        let canSpawnEnemy = (type == .normal || type == .moving || type == .ice || type == .waterLily)
        
        if canSpawnEnemy && Double.random(in: 0...1) < enemyProb {
            // Enemy type selection
            var enemyType: String
            if let challenge = currentChallenge {
                // Daily challenge - respect enemy focus
                if challenge.focusEnemyTypes.contains(.bee) {
                    enemyType = "BEE"
                } else if challenge.focusEnemyTypes.contains(.dragonfly) {
                    enemyType = "DRAGONFLY"
                } else {
                    // Mixed - use normal difficulty scaling
                    let dragonflyChance = Configuration.Difficulty.dragonflyProbability(forLevel: difficultyLevel, weather: currentWeather)
                    enemyType = (Double.random(in: 0...1) < dragonflyChance) ? "DRAGONFLY" : "BEE"
                }
            } else {
                // Normal mode - use difficulty scaling
                let dragonflyChance = Configuration.Difficulty.dragonflyProbability(forLevel: difficultyLevel, weather: currentWeather)
                enemyType = (Double.random(in: 0...1) < dragonflyChance) ? "DRAGONFLY" : "BEE"
            }
            
            // Spawn enemy directly above the pad's position
            let enemy = Enemy(position: CGPoint(x: newX, y: newY + 50), type: enemyType, weather: currentWeather)
            worldNode.addChild(enemy)
            enemies.append(enemy)
        }

    }
    
    /// Spawns a chain of normal lily pads, each within 50 pixels of another
    private func spawnLilyPadChain(startingAt origin: CGPoint, count: Int) {
        var lastPosition = origin
        
        for _ in 0..<count {
            // Pre-generate radius for the new pad
            let newPadRadius = Configuration.Dimensions.randomPadRadius()
            
            // Minimum distance accounts for max pad radius (assuming origin pad could be max size) plus spacing
            let minDistance = Configuration.Dimensions.maxPadRadius + newPadRadius + Configuration.Dimensions.padSpacing
            let maxDistance: CGFloat = 160.0 // Maximum to ensure reachability
            
            // Generate a random position - close enough to jump to, far enough to not overlap
            let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
            let distance = CGFloat.random(in: minDistance...max(minDistance, maxDistance))
            
            var newX = lastPosition.x + cos(angle) * distance
            var newY = lastPosition.y + sin(angle) * distance
            
            // Constrain to river bounds, accounting for pad radius
            let padding = newPadRadius + Configuration.Dimensions.padSpacing
            newX = max(padding, min(Configuration.Dimensions.riverWidth - padding, newX))
            newY = max(lastPosition.y - 30, newY) // Prevent going too far backwards
            
            // Check we're not overlapping existing pads too closely
            let tooClose = pads.contains { pad in
                let dx = pad.position.x - newX
                let dy = pad.position.y - newY
                let minSeparation = pad.scaledRadius + newPadRadius + Configuration.Dimensions.padSpacing
                return sqrt(dx*dx + dy*dy) < minSeparation
            }
            
            guard !tooClose else { continue }
            
            let lilyPad = Pad(type: .normal, position: CGPoint(x: newX, y: newY), radius: newPadRadius)
            lilyPad.updateColor(weather: currentWeather)
            worldNode.addChild(lilyPad)
            pads.append(lilyPad)
            
            lastPosition = CGPoint(x: newX, y: newY)
        }
    }
    
    /// Finds a valid spawn position for a crocodile in the water (not overlapping pads/logs)
    private func findCrocodileSpawnPosition(nearY: CGFloat) -> CGPoint? {
        let crocodileHalfWidth: CGFloat = 150  // Half of 300 width
        let crocodileHalfHeight: CGFloat = 60  // Half of 120 height
        let minPadDistance: CGFloat = 120  // Minimum distance from any pad center
        
        // Try multiple random positions
        for _ in 0..<10 {
            let crocX = CGFloat.random(in: (crocodileHalfWidth + 20)...(Configuration.Dimensions.riverWidth - crocodileHalfWidth - 20))
            let crocY = nearY + CGFloat.random(in: 50...150)
            
            // Check if this position overlaps with any pads or logs
            var overlaps = false
            for pad in pads {
                let padRadius: CGFloat = (pad.type == .log) ? 80 : 60
                let dx = abs(pad.position.x - crocX)
                let dy = abs(pad.position.y - crocY)
                
                // Check rectangular overlap with some padding
                if dx < (crocodileHalfWidth + padRadius) && dy < (crocodileHalfHeight + padRadius) {
                    overlaps = true
                    break
                }
            }
            
            if !overlaps {
                return CGPoint(x: crocX, y: crocY)
            }
        }
        
        // Couldn't find a valid position
        return nil
    }

    
    func didHitObstacle(pad: Pad) {
        if frog.isCannonJumping && pad.type == .log {
            pad.removeFromParent()
            if let idx = pads.firstIndex(of: pad) { pads.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            VFXManager.shared.spawnDebris(at: pad.position, in: self, color: .brown, intensity: 1.5)
            SoundManager.shared.play("hit")
            return
        }
        
        // Super jump destroys logs (chopped) without using axes
        if frog.isSuperJumping && pad.type == .log {
            pad.removeFromParent()
            if let idx = pads.firstIndex(of: pad) { pads.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            VFXManager.shared.spawnDebris(at: pad.position, in: self, color: .brown, intensity: 1.5)
            SoundManager.shared.play("hit")
            return
        }
        
        if pad.type == .log && frog.buffs.axe > 0 {
            frog.buffs.axe -= 1
            pad.removeFromParent()
            if let idx = pads.firstIndex(of: pad) { pads.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            updateBuffsHUD()
            VFXManager.shared.spawnSplash(at: pad.position, in: self)
            return
        }
        HapticsManager.shared.playImpact(.heavy)
        SoundManager.shared.play("hit")
        frog.velocity.dx *= -0.8
        frog.velocity.dy *= -0.8
        frog.position.y -= 10
        frog.zVelocity = 0
        frog.zHeight = 0
    }
    func didLand(on pad: Pad) {
        // Stop the drowning grace period if it was active
        if drowningGracePeriodTimer != nil {
            stopDrowningGracePeriod()
        }
        
        // Check if landed on launch pad - trigger space transition!
        if pad.type == .launchPad && !isLaunchingToSpace {
            hasHitLaunchPad = true
            isLaunchingToSpace = true
            launchToSpace(from: pad)
            return
        }
        
        // Check if landed on warp pad - trigger return to day!
        if pad.type == .warp && !hasHitWarpPad {
            hasHitWarpPad = true
            warpBackToDay(from: pad)
            return
        }
        
        // Check for cannon jump landing BEFORE landing logic
        if frog.isCannonJumping {
            frog.isCannonJumping = false
            triggerCannonJumpLandingWave()
        }
        
        // Transition frog to idle/landed state on the pad
        frog.land(on: pad, weather: currentWeather)
        
        // Visual and haptic feedback
        pad.playLandingSquish()
        spawnWaterRipple(for: pad)  // Ripples now parent to pad and follow it!
        HapticsManager.shared.playImpact(.light)
        
        // Reset jump meter on successful landing
        resetJumpMeter()
        
        // MARK: - Hype Combo Logic
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastLand = currentTime - lastLandTime
        
        // Only award combo if landing on a DIFFERENT pad (use reference equality for performance)
        let isDifferentPad = lastLandedPad !== pad
        
        // Check if frog is moving forward by comparing Y positions (higher Y = forward progress)
        // Allow a small tolerance for landing on pads at similar heights
        let currentY = pad.position.y
        let isMovingForward = currentY > lastLandingY - 10.0  // 10-point tolerance for near-horizontal jumps
        
        if lastLandTime > 0 && timeSinceLastLand < comboTimeout && isDifferentPad {
            // Check forward momentum
            if isMovingForward {
                // Moving forward - award combo and reset backward jump counter
                comboCount += 1
                comboMultiplier = 1.0 + (Double(comboCount) * 0.1)
                consecutiveBackwardJumps = 0  // Reset backward jump counter on forward progress
                
                // Track the maximum combo achieved this run
                if comboCount > maxComboThisRun {
                    maxComboThisRun = comboCount
                }
                
                // Real-time combo challenge tracking
                ChallengeManager.shared.recordComboStreak(comboCount)
                
                // MARK: - Activate Combo Invincibility Mode at 25+ combo
                if comboCount >= 25 && !frog.isComboInvincible {
                    frog.isComboInvincible = true
                    // Play special sound and haptic feedback
                    SoundManager.shared.play("powerup")
                    HapticsManager.shared.playNotification(.success)
                    // Show special popup
                    showComboInvincibilityPopup(at: frog.position)
                }
                
                // Show visual feedback for combo
                showComboPopup(at: frog.position, count: comboCount)
                
                // Extra haptic feedback for combo
                HapticsManager.shared.playNotification(.success)
            } else {
                // Moving backward - allow ONE backward jump without breaking combo
                consecutiveBackwardJumps += 1
                
                if consecutiveBackwardJumps >= 2 {
                    // Second consecutive backward jump breaks the combo
                    comboCount = 0
                    comboMultiplier = 1.0
                    consecutiveBackwardJumps = 0
                    frog.isComboInvincible = false
                }
                // If it's the first backward jump, combo continues but doesn't increment
            }
        } else if !isDifferentPad {
            // Jumped on the same pad - don't break combo, just don't increment
            // Keep existing combo count and multiplier intact
        } else {
            // Combo broken (timeout or first jump)
            comboCount = 0
            comboMultiplier = 1.0
            consecutiveBackwardJumps = 0
            // Deactivate combo invincibility mode when combo is broken
            frog.isComboInvincible = false
        }
        
        lastLandTime = currentTime
        lastLandedPad = pad  // Update last landed pad reference
        lastLandingY = currentY  // Update last landing Y position for next combo check
        
        // Track for challenges
        padsLandedThisRun += 1
        consecutiveJumps += 1
        if consecutiveJumps > bestConsecutiveJumps {
            bestConsecutiveJumps = consecutiveJumps
        }
        
        // Real-time challenge updates
        ChallengeManager.shared.recordPadLanded(totalThisRun: padsLandedThisRun)
        ChallengeManager.shared.recordConsecutiveJumps(count: consecutiveJumps)
        
       
        // Spawn ghost when frog disturbs a grave
        if pad.type == .grave && !pad.hasSpawnedGhost {
            pad.hasSpawnedGhost = true
            
            let waitAction = SKAction.wait(forDuration: 2.0)
            let spawnAction = SKAction.run { [weak self, weak pad] in
                guard let self = self, let pad = pad, pad.parent != nil else { return }
                
                SoundManager.shared.play("ghost")
                HapticsManager.shared.playNotification(.warning)
                
                let ghost = Enemy(position: CGPoint(x: pad.position.x, y: pad.position.y + 40), type: "GHOST")
                self.worldNode.addChild(ghost)
                self.enemies.append(ghost)
            }
            
            self.run(SKAction.sequence([waitAction, spawnAction]))
        }
    }
    
    func didFallIntoWater() {
        guard !isGameEnding, !frog.isFloating else { return }
        
        // BUGFIX: If the frog is grounded (not airborne) and on a pad, they're sliding off.
        // Clear onPad reference to prevent re-landing loop on icy/rainy pads
        if frog.zHeight <= 0 && frog.onPad != nil {
            frog.onPad = nil
        }
        
        // Deplete jump meter immediately
        depletJumpMeter()
        
        // Reset combo on water fall
        comboCount = 0
        comboMultiplier = 1.0
        lastLandedPad = nil
        lastLandingY = 0
        consecutiveBackwardJumps = 0
        frog.isComboInvincible = false  // Deactivate combo invincibility
        
        // Show tooltip on first water encounter
        ToolTips.onFrogFellIntoWater(in: self)

        // Instant game over in desert, regardless of vests
        if currentWeather == .desert {
            isGameEnding = true
            frog.playWailingAnimation()
            playDrowningSequence()
            return
        }

        // If the frog was riding a crocodile, this shouldn't happen, but handle it.
        if let croc = ridingCrocodile {
            _ = croc.stopCarrying()
            ridingCrocodile = nil
        }
        
        // A fall always resets consecutive jumps.
        consecutiveJumps = 0

        // Vest has priority in all weather types: consumes a vest and makes the frog float safely.
        if frog.buffs.vest > 0 {
            frog.buffs.vest -= 1
            
            // In space, no splash - just show sparkles
            if currentWeather == .space {
                VFXManager.shared.spawnSparkles(at: frog.position, in: self)
                SoundManager.shared.play("coin") // Different sound for space
            } else {
                VFXManager.shared.spawnSplash(at: frog.position, in: self)
                SoundManager.shared.play("splash")
            }
            
            HapticsManager.shared.playNotification(.warning)
            frog.velocity = .zero
            frog.zHeight = 0
            frog.zVelocity = 0
            frog.onPad = nil
            frog.isFloating = true // Start floating safely, allowing a jump out.
            updateBuffsHUD()
            return
        }
        
        // In space, float away instead of drowning
        if currentWeather == .space {
            playSpaceFloatSequence()
            return
        }

        // No vest. Start the grace period drowning sequence.
        SoundManager.shared.play("splash")
        VFXManager.shared.spawnSplash(at: frog.position, in: self)
        
        // Lose a heart
        frog.playWailingAnimation()
        frog.currentHealth -= 1
        drawHearts()
        HapticsManager.shared.playNotification(.warning)
        
        if frog.currentHealth <= 0 {
            // No hearts left, game over.
            isGameEnding = true
            playDrowningSequence()
        } else {
            // Hearts remain, start grace period.
            frog.velocity = .zero
            frog.zHeight = 0
            frog.zVelocity = 0
            frog.onPad = nil
            frog.isFloating = true // Allow jumping from water
            startDrowningGracePeriod()
        }
    }
    
    private func startDrowningGracePeriod() {
        drowningGracePeriodTimer = 3.0
        jumpPromptBg.isHidden = false
        jumpPromptBg.run(SKAction.repeatForever(
            SKAction.sequence([
                .fadeAlpha(to: 1.0, duration: 0.3),
                .fadeAlpha(to: 0.7, duration: 0.3)
            ])
        ), withKey: "promptPulse")
    }

    private func stopDrowningGracePeriod() {
        drowningGracePeriodTimer = nil
        jumpPromptBg.isHidden = true
        jumpPromptBg.removeAction(forKey: "promptPulse")
    }
    
    private func updateDrowningGracePeriod(dt: TimeInterval) {
        guard var timer = drowningGracePeriodTimer else { return }
        
        timer -= dt
        drowningGracePeriodTimer = timer
        
        jumpPromptLabel.text = "JUMP! \(Int(ceil(timer)))"
        
        if timer <= 0 {
            // Timer ran out, lose another heart.
            HapticsManager.shared.playNotification(.error)
            SoundManager.shared.play("ouch") // A sound to indicate damage
            
            frog.currentHealth -= 1
            drawHearts()
            
            if frog.currentHealth <= 0 {
                // Out of hearts, game over.
                isGameEnding = true
                stopDrowningGracePeriod()
                playDrowningSequence()
            } else {
                // Reset timer for another chance.
                drowningGracePeriodTimer = 3.0
            }
        }
    }
    
    /// Plays the dramatic drowning sequence with splash and frog sinking underwater
    private func playDrowningSequence() {
        // Stop all frog movement immediately
        frog.velocity = .zero
        frog.zVelocity = 0
        frog.zHeight = 0
        frog.isFloating = false // Stop floating to allow sinking animation
        
        // Create expanding water ripples at the splash point
        spawnDrowningRipples()  // Ripples now parent to frog
        
        // Create water splash particles going upward
        spawnDrowningSplash(at: frog.position)
        
        // Stop weather sound effects
        SoundManager.shared.stopWeatherSFX(fadeDuration: 0.5)
        
        // Play the frog's drowning animation (sinks and disappears)
        frog.playDrowningAnimation { [weak self] in
            guard let self = self else { return }
            
            // Small delay after frog disappears before showing game over
            let delay = SKAction.wait(forDuration: 0.4)
            let showGameOver = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.reportChallengeProgress()
                if self.gameMode == .beatTheBoat && self.raceResult == nil {
                    self.raceResult = .lose(reason: .drowned)
                }
                self.restoreUnusedPackItems()
                self.coordinator?.gameDidEnd(score: self.score, coins: self.coinsCollectedThisRun, raceResult: self.raceResult)
            }
            self.run(SKAction.sequence([delay, showGameOver]))
        }
    }
    
    /// Plays the space floating sequence - frog slowly floats to the nearest edge
    private func playSpaceFloatSequence() {
        
        // Lose a heart first
        frog.playWailingAnimation()
        frog.currentHealth -= 1
        drawHearts()
        HapticsManager.shared.playNotification(.warning)
        
        // Check if game over due to no hearts
        if frog.currentHealth <= 0 {
            isGameEnding = true
            
            // Stop all frog movement
            frog.velocity = .zero
            frog.zVelocity = 0
            frog.zHeight = 0
            frog.isFloating = false
            
            // Determine which side of the screen is closer
            let riverWidth = Configuration.Dimensions.riverWidth
            let distanceToLeft = frog.position.x
            let distanceToRight = riverWidth - frog.position.x
            let targetX = distanceToLeft < distanceToRight ? -50 : riverWidth + 50
            
            // Slow floating motion to the edge
            let floatDuration: TimeInterval = 2.0
            let floatAction = SKAction.moveTo(x: targetX, duration: floatDuration)
            floatAction.timingMode = .easeOut
            
            // Add a slight rotation for space tumbling effect
            let rotation = SKAction.rotate(byAngle: .pi * 2, duration: floatDuration)
            
            // Fade out slightly
            let fadeOut = SKAction.fadeAlpha(to: 0.6, duration: floatDuration)
            
            let group = SKAction.group([floatAction, rotation, fadeOut])
            
            // Stop weather sound effects
            SoundManager.shared.stopWeatherSFX(fadeDuration: 0.5)
            
            frog.run(group) { [weak self] in
                guard let self = self else { return }
                
                // Small delay after frog disappears before showing game over
                let delay = SKAction.wait(forDuration: 0.4)
                let showGameOver = SKAction.run { [weak self] in
                    guard let self = self else { return }
                    self.reportChallengeProgress()
                    if self.gameMode == .beatTheBoat && self.raceResult == nil {
                        self.raceResult = .lose(reason: .drowned)
                    }
                    self.restoreUnusedPackItems()
                    self.coordinator?.gameDidEnd(score: self.score, coins: self.coinsCollectedThisRun, raceResult: self.raceResult)
                }
                self.run(SKAction.sequence([delay, showGameOver]))
            }
        } else {
            // Hearts remain, start grace period with jump prompt
            frog.velocity = .zero
            frog.zHeight = 0
            frog.zVelocity = 0
            frog.onPad = nil
            frog.isFloating = true // Allow jumping from space
            startDrowningGracePeriod()
        }
    }
    
    /// Plays the dramatic enemy death sequence with spinning and falling off screen
    private func playEnemyDeathSequence() {
        // Stop all frog movement immediately
        frog.velocity = .zero
        frog.zVelocity = 0
        
        // Stop weather sound effects
        SoundManager.shared.stopWeatherSFX(fadeDuration: 0.5)
        
        // Play the game over sound
        SoundManager.shared.play("gameOver")
        
        // Play the frog's death animation (spins and falls)
        frog.playDeathAnimation { [weak self] in
            guard let self = self else { return }
            
            // Small delay after frog disappears before showing game over
            let delay = SKAction.wait(forDuration: 0.4)
            let showGameOver = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.reportChallengeProgress()
                self.restoreUnusedPackItems()
                self.coordinator?.gameDidEnd(score: self.score, coins: self.coinsCollectedThisRun, raceResult: self.raceResult)
            }
            self.run(SKAction.sequence([delay, showGameOver]))
        }
    }
    
    /// Makes an enemy fly away when destroyed by super jump
    private func makeEnemyFlyAway(_ enemy: SKNode) {
        // Create a fly-away animation
        let moveUp = SKAction.moveBy(x: CGFloat.random(in: -100...100), y: 300, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.4)
        let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -CGFloat.pi...CGFloat.pi) * 2, duration: 0.6)
        let scale = SKAction.scale(to: 0.3, duration: 0.6)
        
        // Combine all animations
        let flyAway = SKAction.group([moveUp, fadeOut, rotate, scale])
        let remove = SKAction.removeFromParent()
        
        enemy.run(SKAction.sequence([flyAway, remove]))
    }
    
    /// Creates expanding concentric ripples at the drowning location
    private func spawnDrowningRipples() {
        if (currentWeather == .desert){ return }
        spawnRipples(parentedTo: frog, color: .white, rippleCount: 4, isDramatic: true)
    }
    
    /// Creates upward splash particles when frog hits the water
    private func spawnDrowningSplash(at position: CGPoint) {
        let dropletCount = 12
        
        for _ in 0..<dropletCount {
            let droplet = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            droplet.fillColor = SKColor.white.withAlphaComponent(0.9)
            droplet.strokeColor = .clear
            droplet.position = position
            droplet.zPosition = Layer.frog + 1
            worldNode.addChild(droplet)
            
            // Random upward/outward trajectory
            let angle = CGFloat.random(in: CGFloat.pi * 0.2...CGFloat.pi * 0.8) // Upper arc
            let speed = CGFloat.random(in: 80...160)
            let dx = cos(angle) * speed * (Bool.random() ? 1 : -1)
            let dy = sin(angle) * speed
            
            let duration: TimeInterval = Double.random(in: 0.4...0.7)
            
            // Move up then fall back down (parabolic motion)
            let moveUp = SKAction.moveBy(x: dx * 0.5, y: dy, duration: duration * 0.4)
            moveUp.timingMode = .easeOut
            let moveDown = SKAction.moveBy(x: dx * 0.5, y: -dy * 0.5, duration: duration * 0.6)
            moveDown.timingMode = .easeIn
            let movement = SKAction.sequence([moveUp, moveDown])
            
            // Fade out
            let fade = SKAction.fadeOut(withDuration: duration)
            
            // Scale down
            let scale = SKAction.scale(to: 0.3, duration: duration)
            
            let animation = SKAction.group([movement, fade, scale])
            let remove = SKAction.removeFromParent()
            
            droplet.run(SKAction.sequence([animation, remove]))
        }
        
        // Add a few bubbles rising up after the splash
        let bubbleDelay = SKAction.wait(forDuration: 0.3)
        run(bubbleDelay) { [weak self] in
            self?.spawnDrowningBubbles(at: position)
        }
    }
    
    /// Creates small bubbles rising from where the frog sank
    private func spawnDrowningBubbles(at position: CGPoint) {
        let bubbleCount = 6
        
        for i in 0..<bubbleCount {
            let bubble = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            bubble.fillColor = SKColor.white.withAlphaComponent(0.6)
            bubble.strokeColor = SKColor.white.withAlphaComponent(0.3)
            bubble.lineWidth = 1
            bubble.position = CGPoint(
                x: position.x + CGFloat.random(in: -15...15),
                y: position.y
            )
            bubble.zPosition = Layer.frog - 1
            bubble.alpha = 0
            worldNode.addChild(bubble)
            
            let delay = SKAction.wait(forDuration: Double(i) * 0.12)
            let fadeIn = SKAction.fadeIn(withDuration: 0.1)
            let rise = SKAction.moveBy(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: 30...60), duration: Double.random(in: 0.5...0.9))
            rise.timingMode = .easeOut
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let riseAndFade = SKAction.sequence([rise, fadeOut])
            let animation = SKAction.sequence([delay, fadeIn, riseAndFade])
            let remove = SKAction.removeFromParent()
            
            bubble.run(SKAction.sequence([animation, remove]))
        }
    }
    
    /// Bounces the frog up with velocity aimed toward the nearest lilypad
    private func bounceTowardNearestPad() {
        // Find the nearest reachable pad (prefer pads ahead, skip logs)
        var nearestPad: Pad? = nil
        var nearestScore: CGFloat = .greatestFiniteMagnitude
        
        for pad in pads {
            // Skip logs - we want lily pads the frog can land on
            if pad.type == .log { continue }
            
            let dx = pad.position.x - frog.position.x
            let dy = pad.position.y - frog.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Only consider pads within reasonable bounce range
            guard distance < 400 else { continue }
            
            // Score pads: prefer closer ones, and slightly prefer those ahead (upstream)
            var score = distance
            if dy > 0 {
                score *= 0.7  // 30% bonus for pads ahead
            }
            
            if score < nearestScore {
                nearestScore = score
                nearestPad = pad
            }
        }
        
        // Apply the bounce
        frog.bounce(weather: currentWeather, comboCount: comboCount)
        
        // If we found a nearby pad, nudge velocity toward it
        if let targetPad = nearestPad {
            let dx = targetPad.position.x - frog.position.x
            let dy = targetPad.position.y - frog.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Normalize direction
            let dirX = dx / distance
            let dirY = dy / distance
            
            // Calculate velocity needed to reach the pad with current bounce height
            // The bounce gives zVelocity of 22, which means ~1.5 seconds of air time
            // We want to add horizontal velocity to guide toward the pad
            let guidanceStrength: CGFloat = 2.5  // How strongly to guide toward pad
            
            // Blend the bounce's reversed velocity with guidance toward the pad
            // 60% guidance, 40% original bounce direction
            frog.velocity.dx = frog.velocity.dx * 0.4 + dirX * guidanceStrength * 0.6
            frog.velocity.dy = frog.velocity.dy * 0.4 + dirY * guidanceStrength * 0.6
        }
    }
    func didCrash(into enemy: Enemy) {
        guard !isGameEnding else { return }
        
        // DON'T check isBeingDestroyed here - it's already set in CollisionManager
        // and we need to process the collision once
        
        // Combo Invincibility Mode (25+ combo) - destroy enemies like crocodile mode!
        if frog.isComboInvincible {
            enemy.removeFromParent()
            if let idx = enemies.firstIndex(of: enemy) { enemies.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: enemy.position, in: self, color: .yellow, intensity: 1.2)
            SoundManager.shared.play("hit")
            // Show sparkles for extra flair
            VFXManager.shared.spawnSparkles(at: enemy.position, in: self)
            return
        }
        
        if frog.isCannonJumping {
            enemy.removeFromParent()
            if let idx = enemies.firstIndex(of: enemy) { enemies.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: enemy.position, in: self, color: .red, intensity: 1.0)
            SoundManager.shared.play("hit")
            return
        }
        
        // Super jump destroys enemies by making them fly away
        if frog.isSuperJumping {
            // Make enemy fly away with animation
            makeEnemyFlyAway(enemy)
            
            // Remove from array
            if let idx = enemies.firstIndex(of: enemy) { enemies.remove(at: idx) }
            
            // Play feedback
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            SoundManager.shared.play("hit")
            return
        }
        
        // IMPORTANT: Check GHOST + CROSS first, BEFORE invincibility check
        // This way the cross protects the frog from taking damage
        if enemy.type == "GHOST" && frog.buffs.cross > 0 {
            
            // Use animated cross banishment instead of instant removal
            CrossAttackAnimation.executeAttack(frog: frog, ghost: enemy) { [weak self] in
                guard let self = self else { return }
                // Remove enemy from array after animation completes
                if let idx = self.enemies.firstIndex(of: enemy) {
                    self.enemies.remove(at: idx)
                }
            }
            
            // Decrement cross count
            frog.buffs.cross -= 1
            
            // Play feedback
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            updateBuffsHUD()
            return  // IMPORTANT: Return here so frog doesn't take damage!
        }
        
        if frog.isInvincible { return }
        
        // NOTE: Swatter, Honey, Axe, and Cross attacks are handled by CollisionManager
        // and should never reach here. This is only for direct collisions.
        
        // Deplete jump meter on taking damage
        depletJumpMeter()
        
        // Reset combo on taking damage
        comboCount = 0
        comboMultiplier = 1.0
        lastLandedPad = nil
        lastLandingY = 0
        consecutiveBackwardJumps = 0
        frog.isComboInvincible = false  // Deactivate combo invincibility
        
        // If we reach here with a bee/dragonfly/ghost, the frog takes damage
        SoundManager.shared.play("ouch")
        HapticsManager.shared.playImpact(.heavy)
        frog.currentHealth -= 1
        drawHearts()
        frog.hit()
        if frog.currentHealth <= 0 {
            if gameMode == .beatTheBoat {
                endRace(result: .lose(reason: .outOfHealth))
                return
            }
            isGameEnding = true
            
            // Play dramatic death animation with spinning and falling
            playEnemyDeathSequence()
        } else {
            frog.velocity.dx *= -0.7
            frog.velocity.dy *= -0.7
        }
    }
    
    func didCrash(into boat: Boat) {
        guard !isGameEnding, !frog.isInvincible else { return }
        
        // Trigger the boat's veering behavior
        boat.hitByFrog(frogPosition: frog.position)
        
        // Play feedback
        HapticsManager.shared.playImpact(.heavy)
        SoundManager.shared.play("hit")
        
        // Put frog into a "hit" state (for invincibility frames)
        frog.hit()
        
        // Move the frog to the right away from the boat
        let pushDistance: CGFloat = 80
        frog.position.x += pushDistance
        
        // Constrain to river bounds
        let rightEdge = Configuration.Dimensions.riverWidth - 30
        frog.position.x = min(frog.position.x, rightEdge)
    }
    
    func didCrash(into snake: Snake) {
        guard !isGameEnding else { return }
        guard !snake.isDestroyed else { return }
        
        // Combo Invincibility Mode (25+ combo) - destroy snakes like crocodile mode!
        if frog.isComboInvincible {
            snake.isDestroyed = true
            // Make snake fly away with animation
            makeEnemyFlyAway(snake)
            // Remove from array
            if let idx = snakes.firstIndex(of: snake) { snakes.remove(at: idx) }
            // Play feedback
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: snake.position, in: self, color: .yellow, intensity: 1.2)
            SoundManager.shared.play("hit")
            // Show sparkles for extra flair
            VFXManager.shared.spawnSparkles(at: snake.position, in: self)
            return
        }
        
        if frog.isCannonJumping {
            snake.destroy()
            if let idx = snakes.firstIndex(of: snake) { snakes.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: snake.position, in: self, color: .green, intensity: 1.0)
            SoundManager.shared.play("hit")
            return
        }
        
        // Super jump destroys snakes by making them fly away
        if frog.isSuperJumping {
            snake.isDestroyed = true
            
            // Make snake fly away with animation
            makeEnemyFlyAway(snake)
            
            // Remove from array
            if let idx = snakes.firstIndex(of: snake) { snakes.remove(at: idx) }
            
            // Play feedback
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            SoundManager.shared.play("hit")
            return
        }
        
        // Combo Invincibility Mode (25+ combo) - destroy snakes like crocodile mode!
        if frog.isComboInvincible {
            snake.isDestroyed = true
            // Make snake fly away with animation
            makeEnemyFlyAway(snake)
            // Remove from array
            if let idx = snakes.firstIndex(of: snake) { snakes.remove(at: idx) }
            // Play feedback
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: snake.position, in: self, color: .yellow, intensity: 1.2)
            SoundManager.shared.play("hit")
            // Show sparkles for extra flair
            VFXManager.shared.spawnSparkles(at: snake.position, in: self)
            return
        }
        
        if frog.isInvincible { return }
        
        // Axe can destroy snakes
        if frog.buffs.axe > 0 {
            frog.buffs.axe -= 1
            snake.destroy()
            if let idx = snakes.firstIndex(of: snake) { snakes.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            updateBuffsHUD()
            VFXManager.shared.spawnSplash(at: snake.position, in: self)
            SoundManager.shared.play("hit")
            return
        }
        
        // Snake hits the frog - damage!
        SoundManager.shared.play("ouch")
        HapticsManager.shared.playImpact(.heavy)
        
        // Deplete jump meter on taking damage
        depletJumpMeter()
        
        // Reset combo on taking damage
        comboCount = 0
        comboMultiplier = 1.0
        lastLandedPad = nil
        lastLandingY = 0
        consecutiveBackwardJumps = 0
        frog.isComboInvincible = false  // Deactivate combo invincibility
        
        frog.currentHealth -= 1
        drawHearts()
        frog.hit()
        if frog.currentHealth <= 0 {
            if gameMode == .beatTheBoat {
                endRace(result: .lose(reason: .outOfHealth))
                return
            }
            isGameEnding = true
            
            // Play dramatic death animation with spinning and falling
            playEnemyDeathSequence()
        } else {
            frog.velocity.dx *= -0.7
            frog.velocity.dy *= -0.7
        }
    }
    
    func didCrash(into cactus: Cactus) {
        guard !isGameEnding else { return }
        guard !cactus.isDestroyed else { return }
        
        // Get cactus world position for visual effects (since it's a child of a pad)
        let cactusWorldPos: CGPoint
        if let parent = cactus.parent {
            cactusWorldPos = parent.convert(cactus.position, to: worldNode)
        } else {
            cactusWorldPos = cactus.position
        }
        
        // Cannon jump destroys cacti
        if frog.isCannonJumping {
            cactus.destroy()
            if let idx = cacti.firstIndex(of: cactus) { cacti.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: cactusWorldPos, in: self, color: .green, intensity: 1.0)
            SoundManager.shared.play("hit")
            return
        }
        
        // Super jump destroys cacti (chopped) without using axes
        if frog.isSuperJumping {
            cactus.isDestroyed = true
            cactus.destroy()
            
            // Remove from array
            if let idx = cacti.firstIndex(of: cactus) { cacti.remove(at: idx) }
            
            // Play feedback with brown debris (chopped effect)
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: cactusWorldPos, in: self, color: .brown, intensity: 0.8)
            SoundManager.shared.play("hit")
            return
        }
        
        // Combo Invincibility Mode (25+ combo) - destroy cacti like crocodile mode!
        if frog.isComboInvincible {
            cactus.isDestroyed = true
            cactus.destroy()
            // Remove from array
            if let idx = cacti.firstIndex(of: cactus) { cacti.remove(at: idx) }
            // Play feedback with yellow debris for combo mode
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: cactusWorldPos, in: self, color: .yellow, intensity: 1.2)
            SoundManager.shared.play("hit")
            // Show sparkles for extra flair
            VFXManager.shared.spawnSparkles(at: cactusWorldPos, in: self)
            return
        }
        
        if frog.isInvincible { return }
        
        // Axe can destroy cacti
        if frog.buffs.axe > 0 {
            frog.buffs.axe -= 1
            cactus.destroy()
            if let idx = cacti.firstIndex(of: cactus) { cacti.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            updateBuffsHUD()
            VFXManager.shared.spawnDebris(at: cactusWorldPos, in: self, color: .brown, intensity: 0.8)
            SoundManager.shared.play("hit")
            return
        }
        
        // Cactus hits the frog - damage!
        SoundManager.shared.play("ouch")
        HapticsManager.shared.playImpact(.heavy)
        
        // Deplete jump meter on taking damage
        depletJumpMeter()
        
        // Reset combo on taking damage
        comboCount = 0
        comboMultiplier = 1.0
        lastLandedPad = nil
        lastLandingY = 0
        consecutiveBackwardJumps = 0
        frog.isComboInvincible = false  // Deactivate combo invincibility
        
        frog.currentHealth -= 1
        drawHearts()
        frog.hit()
        if frog.currentHealth <= 0 {
            if gameMode == .beatTheBoat {
                endRace(result: .lose(reason: .outOfHealth))
                return
            }
            isGameEnding = true
            
            // Play dramatic death animation with spinning and falling
            playEnemyDeathSequence()
        } else {
            frog.velocity.dx *= -0.7
            frog.velocity.dy *= -0.7
        }
    }
    
    func didCollect(coin: Coin) {
        guard !isGameEnding else { return }
        SoundManager.shared.play("coin")
        HapticsManager.shared.playNotification(.success)
        
        // Apply combo multiplier to coin collection
        let coinsToAdd = Int(Double(1) * comboMultiplier)
        totalCoins += coinsToAdd
        coinsCollectedThisRun += coinsToAdd
        
        coin.removeFromParent()
        if let idx = coins.firstIndex(of: coin) { coins.remove(at: idx) }
        
        // Trigger tadpole tooltip on first coin collection
        ToolTips.onItemCollected("tadpole", in: self)
        
        // Real-time challenge update
        ChallengeManager.shared.recordCoinsCollected(totalThisRun: coinsCollectedThisRun, totalOverall: PersistenceManager.shared.totalCoins + coinsCollectedThisRun)
        
        if coinsCollectedThisRun > 0 && coinsCollectedThisRun % Configuration.GameRules.coinsForUpgradeTrigger == 0 {
            let wait = SKAction.wait(forDuration: 0.2)
            let trigger = SKAction.run { [weak self] in
                guard let self = self else { return }
                
                // PERFORMANCE: Pause combo timer when upgrade modal appears
                self.pauseComboTimer()
                
                let hasFullHealth = self.frog.currentHealth >= self.frog.maxHealth
                self.coordinator?.triggerUpgradeMenu(hasFullHealth: hasFullHealth, distanceTraveled: self.score, currentWeather: self.currentWeather, currentMaxHealth: self.frog.maxHealth)
            }
            run(SKAction.sequence([wait, trigger]))
        }
    }
    
    func didCollect(fly: Fly) {
        guard !isGameEnding else { return }
        
        // Play eating animation
        frog.playEatingAnimation()
        
        // Only heal if the frog has an empty heart slot
        if frog.currentHealth < frog.maxHealth {
            frog.currentHealth += 1
            drawHearts()
            
           
            HapticsManager.shared.playNotification(.success)
            
            // Show healing indicator
            showHealingIndicator(at: fly.position)
        } else {
            // Already at full health - still play feedback but no heal
            HapticsManager.shared.playNotification(.success)
        }
        
        // Animate the fly collection and remove it
        fly.collect { [weak self] in
            guard let self = self else { return }
            if let idx = self.flies.firstIndex(of: fly) {
                self.flies.remove(at: idx)
            }
        }
    }
    
    /// Shows a floating "+❤️" indicator when the frog is healed by a fly
    private func showHealingIndicator(at position: CGPoint) {
        let healLabel = SKLabelNode(fontNamed: Configuration.Fonts.healingIndicator.name)
        healLabel.text = "+❤️"
        healLabel.fontSize = Configuration.Fonts.healingIndicator.size
        healLabel.fontColor = .red
        healLabel.position = CGPoint(x: position.x, y: position.y + 20)
        healLabel.zPosition = Layer.ui
        
        worldNode.addChild(healLabel)
        
        // Animate: float up and fade out
        let moveUp = SKAction.moveBy(x: 0, y: 60, duration: 1.0)
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let scale = SKAction.scale(to: 1.3, duration: 0.3)
        let scaleBack = SKAction.scale(to: 1.0, duration: 0.7)
        let scaleSequence = SKAction.sequence([scale, scaleBack])
        
        let group = SKAction.group([moveUp, fadeOut, scaleSequence])
        let remove = SKAction.removeFromParent()
        healLabel.run(SKAction.sequence([group, remove]))
    }
    
    func didCollect(treasureChest: TreasureChest) {
        guard !isGameEnding else { return }
        guard !treasureChest.isCollected else { return }
        
        // Open the chest and get the reward
        let reward = treasureChest.open()
        
        // Remove from tracking array
        if let idx = treasureChests.firstIndex(of: treasureChest) {
            treasureChests.remove(at: idx)
        }
        
        // Apply the reward
        applyTreasureChestReward(reward)
        
        // Play celebration effects
        SoundManager.shared.play("treasure")  // TODO: Add a unique chest sound if desired
        HapticsManager.shared.playNotification(.success)
        
        // Show floating reward notification
        showTreasureChestReward(reward, at: treasureChest.position)
        
        // Check for special tooltips (e.g., if this chest contains a tadpole in future)
        // Uncomment when you add tadpoles:
        // if reward == .tadpole {
        //     ToolTips.onItemCollected("tadpole", in: self)
        // }
        
        // Trigger treasure tooltip on first collection
        ToolTips.onItemCollected("treasure", in: self)
        
        // Update HUD to reflect new buffs
        updateBuffsHUD()
        drawHearts()
    }
    
    /// Call this when a tadpole is collected (for when you add tadpole entities)
    /// This is a helper method you can call from any collection handler
    private func onTadpoleCollected() {
        ToolTips.onItemCollected("tadpole", in: self)
    }
    
    private func applyTreasureChestReward(_ reward: TreasureChest.Reward) {
        switch reward {
        case .heartsRefill:
            frog.currentHealth = frog.maxHealth
        case .lifevest4Pack:
            frog.buffs.vest += 4
        case .cross4Pack:
            frog.buffs.cross += 4
        case .axe4Pack:
            frog.buffs.axe += 4
        case .swatter4Pack:
            frog.buffs.swatter += 4
        }
    }
    
    private func showTreasureChestReward(_ reward: TreasureChest.Reward, at position: CGPoint) {
        // Create reward notification label
        let rewardLabel = SKLabelNode(fontNamed: Configuration.Fonts.treasureReward.name)
        rewardLabel.text = "\(reward.icon) \(reward.displayName)"
        rewardLabel.fontSize = Configuration.Fonts.treasureReward.size
        rewardLabel.fontColor = .yellow
        rewardLabel.position = CGPoint(x: position.x + 10, y: position.y + 30)
        rewardLabel.zPosition = Layer.ui
        
        // Add background using treasureBackdrop.png
        let bgNode = SKSpriteNode(imageNamed: "treasureBackdrop.png")
        bgNode.zPosition = -1
        
        // Limit the modal width to fit on screen (max 80% of screen width)
        let maxWidth = size.width * 0.8
        let labelWidth = rewardLabel.frame.width + 40 // Add some padding
        
        // Scale the background to fit the label with constraints
        let targetWidth = min(labelWidth, maxWidth)
        let scaleX = targetWidth / bgNode.size.width
        
        // Keep aspect ratio for height, but limit it too
        let maxHeight = size.height * 0.3
        let targetHeight = min(bgNode.size.height * scaleX, maxHeight)
        let scaleY = targetHeight / bgNode.size.height
        
        bgNode.xScale = scaleX
        bgNode.yScale = scaleY
        
        rewardLabel.addChild(bgNode)
        
        worldNode.addChild(rewardLabel)
        
        // Animate: float up and fade out
        let moveUp = SKAction.moveBy(x: 0, y: 100, duration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 2.0)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()
        rewardLabel.run(SKAction.sequence([group, remove]))
        
        // Spawn sparkle particles
        VFXManager.shared.spawnSparkles(at: position, in: self)
    }
    
    func didLand(on crocodile: Crocodile) {
        guard !isGameEnding else { return }
        
        // Stop riding any previous crocodile
        if let previousCroc = ridingCrocodile, previousCroc !== crocodile {
            _ = previousCroc.stopCarrying()
        }
        
        // Start riding this crocodile
        ridingCrocodile = crocodile
        crocodile.startCarrying()
        SoundManager.shared.playMusic(.crocRomp)

        
        // Land the frog on the crocodile
        frog.zVelocity = 0
        frog.zHeight = 0
        frog.velocity = .zero
        frog.onPad = nil
        frog.isFloating = false
        frog.position = crocodile.position
        
        // Visual and audio feedback
        spawnWaterRipple(for: crocodile)  // Ripples parent to crocodile and follow it!
        SoundManager.shared.play("crocodileRide")
        HapticsManager.shared.playImpact(.medium)
        
        // Show vignette effect for dramatic croc ride atmosphere
        showCrocRideVignette()
        
        // Track for challenges
        padsLandedThisRun += 1
        consecutiveJumps += 1
        if consecutiveJumps > bestConsecutiveJumps {
            bestConsecutiveJumps = consecutiveJumps
        }
    }
    
    func didCompleteCrocodileRide(crocodile: Crocodile) {
        guard crocodile === ridingCrocodile else { return }
        
        // Give reward for completing the ride with combo multiplier
        let baseReward = Crocodile.carryReward
        let reward = Int(Double(baseReward) * comboMultiplier)
        totalCoins += reward
        coinsCollectedThisRun += reward
        
        // Track challenge progress
        ChallengeManager.shared.recordCrocodileRideCompleted()
        
        // Show reward notification
        SoundManager.shared.play("coin")
        HapticsManager.shared.playNotification(.success)
        
        // Create floating reward text
        let rewardLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        rewardLabel.text = "+\(reward) ⭐️"
        rewardLabel.fontSize = 28
        rewardLabel.fontColor = .yellow
        rewardLabel.position = frog.position
        rewardLabel.zPosition = Layer.ui
        worldNode.addChild(rewardLabel)
        
        // Animate the reward text
        let moveUp = SKAction.moveBy(x: 0, y: 80, duration: 1.0)
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()
        rewardLabel.run(SKAction.sequence([group, remove]))
        
        // Stop the ride and make crocodile submerge
        _ = crocodile.stopCarrying()
        crocodile.submergeAndDisappear()
        
        // Remove from crocodiles array
        if let idx = crocodiles.firstIndex(where: { $0 === crocodile }) {
            crocodiles.remove(at: idx)
        }
        ridingCrocodile = nil
        
        // Hide the vignette effect
        hideCrocRideVignette()
        
        // Resume gameplay music
        SoundManager.shared.playMusic(baseMusic)
        
        // Find the nearest lily pad and fling the frog to it
        flingFrogToNearestPad(from: frog.position)
    }
    
    /// Finds the nearest pad and flings the frog toward it
    private func flingFrogToNearestPad(from position: CGPoint) {
        // Find the nearest pad (prefer pads ahead of the frog, not logs)
        var nearestPad: Pad? = nil
        var nearestDistance: CGFloat = .greatestFiniteMagnitude
        
        for pad in pads {
            // Skip logs - we want lily pads
            if pad.type == .log { continue }
            
            let dx = pad.position.x - position.x
            let dy = pad.position.y - position.y
            
            // Prefer pads that are ahead (upstream) or nearby
            // Give slight preference to pads ahead by reducing their effective distance
            let distanceMultiplier: CGFloat = dy > 0 ? 0.8 : 1.2
            let distance = sqrt(dx * dx + dy * dy) * distanceMultiplier
            
            if distance < nearestDistance {
                nearestDistance = distance
                nearestPad = pad
            }
        }
        
        if let targetPad = nearestPad {
            // Calculate velocity to reach the target pad
            let dx = targetPad.position.x - position.x
            let dy = targetPad.position.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Normalize and scale for a nice arc
            let power: CGFloat = min(distance * 0.015, 8.0)  // Cap the power
            let normalizedDx = dx / distance
            let normalizedDy = dy / distance
            
            frog.velocity = CGVector(dx: normalizedDx * power, dy: normalizedDy * power)
            frog.zVelocity = 12.0  // Good arc height
            frog.onPad = nil
            frog.isFloating = false
            
            SoundManager.shared.play("jump")
            HapticsManager.shared.playImpact(.medium)
        } else {
            // No pad found - just bounce up
            frog.zVelocity = 10.0
            frog.velocity.dy = 3.0
        }
    }
    
    // MARK: - Croc Ride Vignette
    
    /// Creates a radial vignette texture that darkens the edges of the screen
    private func createCrocRideVignette() -> SKSpriteNode {
        let vignetteSize = self.size
        
        let renderer = UIGraphicsImageRenderer(size: vignetteSize)
        let image = renderer.image { context in
            let center = CGPoint(x: vignetteSize.width / 2, y: vignetteSize.height / 2)
            let radius = max(vignetteSize.width, vignetteSize.height) * 0.7
            
            let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
            let locations: [CGFloat] = [0.4, 1.0]
            
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: colors as CFArray,
                                          locations: locations) {
                context.cgContext.drawRadialGradient(gradient,
                                                      startCenter: center, startRadius: 0,
                                                      endCenter: center, endRadius: radius,
                                                      options: .drawsAfterEndLocation)
            }
        }
        
        let texture = SKTexture(image: image)
        let node = SKSpriteNode(texture: texture, size: vignetteSize)
        node.zPosition = Layer.ui - 1  // Just below UI elements
        node.alpha = 0
        node.blendMode = .alpha
        return node
    }
    
    private func showCrocRideVignette() {
        if crocRideVignetteNode == nil {
            crocRideVignetteNode = createCrocRideVignette()
            cam.addChild(crocRideVignetteNode!)
        }
        crocRideVignetteNode?.run(SKAction.fadeAlpha(to: 1.0, duration: 0.3))
    }
    
    private func hideCrocRideVignette() {
        crocRideVignetteNode?.run(SKAction.fadeAlpha(to: 0.0, duration: 0.5))
    }
    
    func crocodileDidDestroy(pad: Pad) {
        // Remove the pad/log that the crocodile destroyed
        pad.removeFromParent()
        if let idx = pads.firstIndex(of: pad) {
            pads.remove(at: idx)
        }
        
        // Visual and audio feedback with debris effect
        // Use different colors based on what was destroyed
        let debrisColor: UIColor
        let intensity: CGFloat
        
        if pad.type == .log {
            debrisColor = UIColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1.0)  // Brown for logs
            intensity = 1.5  // Bigger explosion for logs
        } else {
            debrisColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)  // Green for lily pads
            intensity = 1.0
        }
        
        // Spawn dramatic debris explosion
        VFXManager.shared.spawnDebris(at: pad.position, in: self, color: debrisColor, intensity: intensity)
        
        // Also spawn chomp debris in the crocodile's movement direction
        if let croc = ridingCrocodile {
            let movementDir = CGVector(dx: 0, dy: 1)  // Crocodile moves upstream
            VFXManager.shared.spawnChompDebris(at: croc.position, in: self, movementDirection: movementDir)
        }
        
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.heavy)
    }
    
    func crocodileDidDestroy(enemy: Enemy) {
        // Remove the enemy that the crocodile destroyed
        enemy.removeFromParent()
        if let idx = enemies.firstIndex(of: enemy) {
            enemies.remove(at: idx)
        }
        
        // Visual and audio feedback with debris effect
        // Yellow/orange debris for bees, blue for dragonflies
        let debrisColor: UIColor
        switch enemy.type {
        case "BEE":
            debrisColor = UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)  // Yellow
        case "DRAGONFLY":
            debrisColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)  // Blue
        case "GHOST":
            debrisColor = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)  // Pale ghostly
        default:
            debrisColor = .white
        }
        
        // Spawn debris at the enemy position
        VFXManager.shared.spawnDebris(at: enemy.position, in: self, color: debrisColor, intensity: 0.8)
        
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.medium)
        
        // Track for challenges
        ChallengeManager.shared.recordEnemyDefeated()
    }
    
    func didDestroyEnemyWithHoney(_ enemy: Enemy) {
        // Remove the enemy from the array (visual removal happens in animation)
        if let idx = enemies.firstIndex(of: enemy) {
            enemies.remove(at: idx)
        }
        
        // Update the buffs HUD to reflect the honey count change
        updateBuffsHUD()
        
        // Play honey impact sound and haptics
        SoundManager.shared.play("splat") // Use collect sound for honey hit
        HapticsManager.shared.playImpact(.medium)
        
        // Track for challenges
        ChallengeManager.shared.recordEnemyDefeated()
        
        // Optional: Spawn honey-colored debris/particles
        let honeyColor = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        VFXManager.shared.spawnDebris(at: enemy.position, in: self, color: honeyColor, intensity: 0.6)
    }
    
    func didDestroyDragonflyWithSwatter(_ dragonfly: Enemy) {
        // Remove the dragonfly from the array (visual removal happens in animation)
        if let idx = enemies.firstIndex(of: dragonfly) {
            enemies.remove(at: idx)
        }
        
        // Update the buffs HUD to reflect the swatter count change
        updateBuffsHUD()
        
        // Play swatter impact sound and haptics
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.medium)
        
        // Track for challenges
        ChallengeManager.shared.recordEnemyDefeated()
        
        // Spawn dragonfly-colored debris/particles
        let dragonflyColor = UIColor(red: 0.2, green: 0.6, blue: 0.8, alpha: 1.0) // Blue-ish
        VFXManager.shared.spawnDebris(at: dragonfly.position, in: self, color: dragonflyColor, intensity: 0.6)
    }
    
    // MARK: - Axe Attack Delegate Methods
    
    func didDestroySnakeWithAxe(_ snake: Snake) {
        // Remove from array
        if let idx = snakes.firstIndex(of: snake) {
            snakes.remove(at: idx)
        }
        
        // Audio & haptics
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.medium)
        
        // Spawn green debris
        let snakeColor = UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)
        VFXManager.shared.spawnDebris(at: snake.position, in: self, color: snakeColor, intensity: 0.8)
        
        // Track for challenges
        ChallengeManager.shared.recordEnemyDefeated()
    }
    
    func didDestroyCactusWithAxe(_ cactus: Cactus) {
        // Remove from array
        if let idx = cacti.firstIndex(of: cactus) {
            cacti.remove(at: idx)
        }
        
        // Audio & haptics
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.medium)
        
        // Spawn light green debris (get world position from parent)
        if let parentPad = cactus.parent as? SKNode {
            let worldPos = parentPad.convert(cactus.position, to: self)
            let cactusColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
            VFXManager.shared.spawnDebris(at: worldPos, in: self, color: cactusColor, intensity: 0.8)
        }
        
        // Track for challenges (optional - if you track cactus destruction)
        // ChallengeManager.shared.recordCactusDestroyed()
    }
    
    func didDestroyLogWithAxe(_ log: Pad) {
        // Remove from array
        if let idx = pads.firstIndex(of: log) {
            pads.remove(at: idx)
        }
        
        // Audio & haptics (heavier for logs)
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.heavy)
        
        // Spawn brown debris
        let logColor = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
        VFXManager.shared.spawnDebris(at: log.position, in: self, color: logColor, intensity: 0.9)
        
        // Track for challenges (optional - if you track log destruction)
        // ChallengeManager.shared.recordLogDestroyed()
    }
    
    func crocodileDidDestroy(snake: Snake) {
        // Remove the snake that the crocodile destroyed
        snake.destroy()
        if let idx = snakes.firstIndex(of: snake) {
            snakes.remove(at: idx)
        }
        
        // Visual and audio feedback - green debris for snakes
        let debrisColor = UIColor(red: 0.3, green: 0.7, blue: 0.2, alpha: 1.0)  // Green
        VFXManager.shared.spawnDebris(at: snake.position, in: self, color: debrisColor, intensity: 0.8)
        
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.medium)
        
        // Track for challenges
        ChallengeManager.shared.recordEnemyDefeated()
    }
    
    private func setupInput() { isUserInteractionEnabled = true }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameEnding, let touch = touches.first else { return }
        let location = touch.location(in: self)
        let locationInUI = touch.location(in: uiNode)
        
        if pauseBg.contains(locationInUI) {
            HapticsManager.shared.playImpact(.light)
            coordinator?.pauseGame()
            return
        }
        if (frog.rocketState == .flying || frog.rocketState == .landing) && descendBg.contains(locationInUI) && !descendBg.isHidden {
            // Stop the rocket timer and initiate descent
            frog.rocketTimer = 0
            frog.descend()
            HapticsManager.shared.playImpact(.heavy)
            return
        }
        if cannonJumpBg.contains(locationInUI) && !cannonJumpBg.isHidden {
            // Toggle armed state if usable
            if frog.buffs.cannonJumps > 0 && frog.onPad != nil {
                frog.isCannonJumpArmed.toggle()
                HapticsManager.shared.playImpact(.light)
            }
            return // Prevent starting a drag
        }
        
        if frog.rocketState != .none {
            // Store the touch and determine which side was touched
            rocketSteeringTouch = touch
            let touchX = touch.location(in: self).x
            let screenMidpoint = cam.position.x
            rocketSteeringDirection = touchX < screenMidpoint ? -1 : 1
            
            // Apply initial steering
            frog.steerRocket(rocketSteeringDirection)
            return
        }
        
        // Crocodile steering - tap left or right side of screen to steer
        if let croc = ridingCrocodile, croc.isCarryingFrog {
            let dir: CGFloat = location.x < cam.position.x ? -1 : 1
            croc.steer(dir)
            HapticsManager.shared.playImpact(.light)
            return
        }
        
        // Allow slingshot aiming when grounded OR floating (e.g., after falling in water/space)
        if frog.zHeight <= 0.1 || frog.isFloating {
            // Hide tutorial on first interaction
            hideTutorialOverlay()
            
            // Dismiss daily challenge banner when player starts jumping
            dismissDailyChallengeBanner()
            
            isDragging = true
            // Store offset from frog, so slingshot follows moving platforms
            dragStartOffset = CGPoint(x: location.x - frog.position.x, y: location.y - frog.position.y)
            dragCurrent = location
            
            // Reset haptics for new drag
            lastHapticDragStep = 0
            hasTriggeredMaxPullHaptic = false
            
            // Reset smoothed position to prevent overshoot from previous drag
            smoothedDotPosition = .zero
            
            // Smooth fade-in for slingshot visuals
            showSlingshotVisualsWithAnimation()
            
            updateTrajectoryVisuals()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameEnding else { return }
        
        
        // Handle rocket steering if in rocket mode
        if frog.rocketState != .none, let steeringTouch = rocketSteeringTouch, touches.contains(steeringTouch) {
            let touchX = steeringTouch.location(in: self).x
            let screenMidpoint = cam.position.x
            let newDirection: CGFloat = touchX < screenMidpoint ? -1 : 1
            
            // Only update if direction changed
            if newDirection != rocketSteeringDirection {
                rocketSteeringDirection = newDirection
                frog.steerRocket(rocketSteeringDirection)
            }
            return
        }
        
        // Handle normal drag for jump trajectory
        guard isDragging, let touch = touches.first else { return }
        dragCurrent = touch.location(in: self)
        updateTrajectoryVisuals()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle rocket steering release
        if let steeringTouch = rocketSteeringTouch, touches.contains(steeringTouch) {
            rocketSteeringTouch = nil
            rocketSteeringDirection = 0
            frog.steerRocket(0)  // Stop steering
            return
        }
        
        guard isDragging, let offset = dragStartOffset, let touch = touches.first else {
            if frog.rocketState == .none {
                isDragging = false
            }
            // Smooth fade-out animation for slingshot visuals
            hideSlingshotVisualsWithAnimation()
            return
        }
        
        // CRITICAL FIX: Use the EXACT touch location at release time
        // Don't rely on dragCurrent which may be outdated from touchesMoved
        let releaseLocation = touch.location(in: self)
        
        // Update dragCurrent for the final trajectory visualization
        dragCurrent = releaseLocation
        
        // Force one final trajectory update to show exactly where frog will land
        updateTrajectoryVisuals(forceUpdate: true)
        
        isDragging = false
        // Reset haptics state
        lastHapticDragStep = 0
        hasTriggeredMaxPullHaptic = false

        // Smooth fade-out animation for slingshot visuals AFTER calculating trajectory
        hideSlingshotVisualsWithAnimation()

        if isGameEnding || frog.rocketState != .none { return }
        
        // Calculate start relative to frog's current position
        let start = CGPoint(x: frog.position.x + offset.x, y: frog.position.y + offset.y)
        var dx = start.x - releaseLocation.x
        var dy = start.y - releaseLocation.y
        let dist = sqrt(dx*dx + dy*dy)
        if dist < 10 {
            // If jump was cancelled, and cannon was armed, de-arm it.
            if frog.isCannonJumpArmed {
                frog.isCannonJumpArmed = false
            }
            return
        }
        
        let maxDist = Configuration.Physics.maxDragDistance
        
        // Clamp the drag vector to max distance to prevent super-long pulls
        if dist > maxDist {
            let clampRatio = maxDist / dist
            dx *= clampRatio
            dy *= clampRatio
        }
        
        let ratio = min(dist, maxDist) / maxDist
        let power = Configuration.Physics.dragPower(level: PersistenceManager.shared.jumpLevel)
        
        // FIX: Apply SuperJump logic
        var launchVector = CGVector(dx: dx * power, dy: dy * power)
        let isSuperjumping = frog.buffs.superJumpTimer > 0
        if isSuperjumping {
            launchVector.dx *= 2.0
            launchVector.dy *= 2.0
        }
        
        // OVERJUMP FIX: Clamp velocity to prevent physics instability during frame drops
        // When frame rate dips, larger dt values can cause the frog to jump farther than intended
        // Max velocity tuned to match the maximum expected jump distance
        // Superjump gets 2x the cap to allow full 2x distance
        let maxVelocity: CGFloat = isSuperjumping ? 70.0 : 35.0
        let velocityMagnitude = sqrt(launchVector.dx * launchVector.dx + launchVector.dy * launchVector.dy)
        if velocityMagnitude > maxVelocity {
            let clampRatio = maxVelocity / velocityMagnitude
            launchVector.dx *= clampRatio
            launchVector.dy *= clampRatio
        }
        
        if frog.isCannonJumpArmed {
            frog.isCannonJumpArmed = false
            frog.isCannonJumping = true
            frog.buffs.cannonJumps -= 1
            VFXManager.shared.spawnSparkles(at: frog.position, in: self)
            SoundManager.shared.play("rocket")
        }
        
        // If jumping off a crocodile, stop the ride (no reward for early jump)
        if let croc = ridingCrocodile {
            _ = croc.stopCarrying()
            ridingCrocodile = nil
            hideCrocRideVignette()
            SoundManager.shared.playMusic(baseMusic)
        }
        
        // Normal grounded jump only - air jumps are handled in touchesBegan as directional taps
        frog.jump(vector: launchVector, intensity: ratio, weather: currentWeather, comboCount: comboCount)
        // If we just jumped out of the water, stop the grace period.
        if frog.isFloating {
            frog.isFloating = false
            stopDrowningGracePeriod()
        }
        

    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Handle rocket steering cancellation
        if let steeringTouch = rocketSteeringTouch, touches.contains(steeringTouch) {
            rocketSteeringTouch = nil
            rocketSteeringDirection = 0
            frog.steerRocket(0)  // Stop steering
        }
        
        isDragging = false
        lastHapticDragStep = 0
        hasTriggeredMaxPullHaptic = false
        hideSlingshotVisualsWithAnimation()
    }
    
    // MARK: - Slingshot Visual Helpers
    
    /// Smoothly shows slingshot visuals with a fade-in animation
    private func showSlingshotVisualsWithAnimation() {
        // Make sure visuals are visible but transparent initially
        slingshotNode.alpha = 0
        slingshotDot.alpha = 0
        slingshotDot.isHidden = false
        crosshairNode.alpha = 0
        crosshairNode.isHidden = false
        
        // Smooth fade-in
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.12)
        fadeIn.timingMode = .easeOut
        
        slingshotDot.run(fadeIn)
        crosshairNode.run(fadeIn)
        
        // Slingshot line fades to its default alpha (0.2)
        let lineFadeIn = SKAction.fadeAlpha(to: 0.2, duration: 0.12)
        lineFadeIn.timingMode = .easeOut
        slingshotNode.run(lineFadeIn)
    }
    
    /// Smoothly hides slingshot visuals with a fade-out animation
    /// Smoothly hides slingshot visuals with a fade-out animation
        private func hideSlingshotVisualsWithAnimation() {
            // Reset smoothed position for next drag
            smoothedDotPosition = .zero
            
            // Animate slingshot elements fading out
            let fadeOut = SKAction.sequence([
                SKAction.fadeAlpha(to: 0, duration: 0.15),
                SKAction.run { [weak self] in
                    self?.slingshotNode.path = nil
                    self?.slingshotNode.alpha = 0.2
                    self?.slingshotDot.isHidden = true
                    self?.slingshotDot.alpha = 1.0
                    self?.slingshotDot.setScale(1.0)
                    self?.crosshairNode.isHidden = true
                    self?.crosshairNode.alpha = 1.0
                }
            ])
            
            slingshotNode.run(fadeOut)
            slingshotDot.run(fadeOut.copy() as! SKAction)
            crosshairNode.run(fadeOut.copy() as! SKAction)
            
            // --- NEW FIX: Hide the Sprite-based Trajectory Renderer ---
            trajectoryRenderer?.hide()
            // ----------------------------------------------------------
            
            // Instantly hide old legacy trajectory dots (if any still exist)
            trajectoryDots.forEach { $0.isHidden = true }
            
            // Reset frog's pull offset with smooth animation
            frog.resetPullOffset()
        }
    // MARK: - Trajectory Optimization Cache
    private let trajectoryUpdateInterval: TimeInterval = 0.033 // ~30 FPS for trajectory updates
    
    // --- Performance Improvement: Use sprite pool for trajectory ---
    // This function now updates the positions of a pre-allocated array of sprites
    // instead of regenerating a complex SKShapeNode path every frame.
    private func updateTrajectoryVisuals(forceUpdate: Bool = false) {
        guard let offset = dragStartOffset, let current = dragCurrent else { return }
        
        // PERFORMANCE FIX: Throttle trajectory calculations to 30 FPS max (unless forced)
        let currentTime = CACurrentMediaTime()
        let shouldUpdateTrajectory = forceUpdate || (currentTime - lastTrajectoryUpdate) >= trajectoryUpdateInterval
        
        // Calculate dragStart relative to frog's current position (follows moving platforms)
        let start = CGPoint(x: frog.position.x + offset.x, y: frog.position.y + offset.y)
        var dx = start.x - current.x
        var dy = start.y - current.y
        let dist = sqrt(dx*dx + dy*dy)
        
        // Hide visuals if drag is too small
        if dist < 10 {
            trajectoryRenderer?.hide()
            slingshotNode.path = nil
            slingshotDot.isHidden = true
            crosshairNode.isHidden = true
            frog.resetPullOffset()
            smoothedDotPosition = .zero  // Reset to prevent overshoot on next drag
            return
        }
        
        let maxDist = Configuration.Physics.maxDragDistance
        
        // Clamp the drag vector to max distance to prevent super-long pulls
        if dist > maxDist {
            let clampRatio = maxDist / dist
            dx *= clampRatio
            dy *= clampRatio
        }
        

        
        let ratio = min(dist, maxDist) / maxDist
        let power = Configuration.Physics.dragPower(level: PersistenceManager.shared.jumpLevel)
        let isSuperJumping = frog.buffs.superJumpTimer > 0
        
        // Visual Drag Line (Slingshot) - Always update for smooth feel
        let dragVector = CGPoint(x: current.x - start.x, y: current.y - start.y)
        frog.setPullOffset(dragVector)
        
        var clampedDrag = dragVector
        let visualDragDist = sqrt(dragVector.x*dragVector.x + dragVector.y*dragVector.y)
        if visualDragDist > maxDist {
            clampedDrag.x *= (maxDist / visualDragDist)
            clampedDrag.y *= (maxDist / visualDragDist)
        }
        
        let targetDotPos = CGPoint(x: frog.position.x + clampedDrag.x, y: frog.position.y + clampedDrag.y)
        
        // Smooth interpolation for dot position (reduces jitter)
        if smoothedDotPosition == .zero {
            smoothedDotPosition = targetDotPos
        } else {
            smoothedDotPosition.x += (targetDotPos.x - smoothedDotPosition.x) * dotSmoothingFactor
            smoothedDotPosition.y += (targetDotPos.y - smoothedDotPosition.y) * dotSmoothingFactor
        }
        
        // Always update slingshot dot position for responsive feel
        slingshotDot.position = smoothedDotPosition
        
        // Scale the dot based on pull strength for visual feedback
        let dotScale = 1.0 + (ratio * 0.5) // Scale from 1.0 to 1.5
        slingshotDot.setScale(dotScale)
        
        // Update slingshot line smoothly
        let slingPath = CGMutablePath()
        slingPath.move(to: frog.position)
        slingPath.addLine(to: smoothedDotPosition)
        slingshotNode.path = slingPath
        
        // Skip expensive trajectory simulation if we recently updated
        if !shouldUpdateTrajectory {
            return
        }
        
        lastTrajectoryUpdate = currentTime
        slingshotDot.isHidden = false
        
        // Visual styling based on jump type
        let trajectoryColor: UIColor
        let slingshotColor: UIColor
        if isSuperJumping {
            trajectoryColor = .cyan.withAlphaComponent(0.8)
            slingshotColor = .cyan
        } else if frog.isCannonJumpArmed {
            trajectoryColor = UIColor.purple.withAlphaComponent(0.9)
            slingshotColor = .purple
        } else {
            trajectoryColor = .white.withAlphaComponent(0.7)
            slingshotColor = .yellow
        }
        
        slingshotDot.fillColor = slingshotColor
        slingshotNode.strokeColor = slingshotColor
        crosshairNode.strokeColor = slingshotColor
        (crosshairNode.children.first as? SKShapeNode)?.fillColor = slingshotColor
        (crosshairNode.children.last as? SKShapeNode)?.fillColor = slingshotColor
        
        // Calculate initial velocity for trajectory
        var simVel = CGVector(dx: dx * power, dy: dy * power)
        var simZVel: CGFloat = Configuration.Physics.baseJumpZ * (0.5 + (ratio * 0.5))
        if isSuperJumping {
            simVel.dx *= 2.0
            simVel.dy *= 2.0
        }
        
        // CRITICAL: Apply the same velocity clamp as the actual jump!
        let maxVelocity: CGFloat = isSuperJumping ? 70.0 : 35.0
        let velocityMagnitude = sqrt(simVel.dx * simVel.dx + simVel.dy * simVel.dy)
        if velocityMagnitude > maxVelocity {
            let clampRatio = maxVelocity / velocityMagnitude
            simVel.dx *= clampRatio
            simVel.dy *= clampRatio
        }
        
        // Use the same gravity as actual physics - reduced in space!
        let gravity = currentWeather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ
        
        // Update trajectory renderer with smooth curve
        if let renderer = trajectoryRenderer {
            // Convert frog position to worldNode coordinates (in case frog was re-parented)
            // Even though frog should always be a child of worldNode, this ensures we use the correct coordinates
            let worldPosition: CGPoint
            if frog.parent === worldNode {
                // Frog is a direct child of worldNode - use position directly
                worldPosition = frog.position
            } else if let parent = frog.parent {
                // Frog has been re-parented - convert to worldNode space
                worldPosition = worldNode.convert(frog.position, from: parent)
            } else {
                // Frog has no parent - use scene coordinates
                worldPosition = convert(frog.position, to: worldNode)
            }
            
            renderer.updateTrajectory(
                startPosition: worldPosition,
                startVelocity: simVel,
                startZ: 0,
                startVZ: simZVel,
                gravity: gravity,
                friction: Configuration.Physics.frictionAir,
                dt: 1.0/60.0
            )
            
            // Update trajectory appearance based on jump type and intensity
            // Force solid red, full alpha, thick line for debugging
                renderer.updateAppearance(color: .yellow, width: 5.0, alpha: 1.0)
                renderer.updateForDragIntensity(1.0)
        } else {
            // TrajectoryRenderer is nil
        }
        
        // Calculate landing point for crosshair (simple simulation)
        var simPos = frog.position
        var simZ: CGFloat = 0
        var landingPoint = simPos
        let simulationSteps = isSuperJumping ? 45 : 30
        
        var tempVel = simVel
        var tempZVel = simZVel
        
        for _ in 0..<simulationSteps {
            simPos.x += tempVel.dx
            simPos.y += tempVel.dy
            simZ += tempZVel
            
            if simZ > 0 {
                tempZVel -= gravity
                tempVel.dx *= Configuration.Physics.frictionAir
                tempVel.dy *= Configuration.Physics.frictionAir
            } else {
                simZ = 0
                landingPoint = simPos
                break
            }
            
            landingPoint = simPos
        }
        
        // Position crosshairs at the landing position
        crosshairNode.isHidden = false
        crosshairNode.position = landingPoint
    }
    
    @objc func handleUpgrade(_ notification: Notification) {
        guard let id = notification.userInfo?["id"] as? String else { return }
        
        // PERFORMANCE: Resume combo timer and reset jump meter after upgrade selection
        resumeComboTimer()
        resetJumpMeter()
        
        applyUpgrade(id: id)
        // No need to call updateBuffsHUD directly, the main loop will catch the change.
    }
    private func applyUpgrade(id: String) {
        switch id {
        case "HEART":
            if frog.maxHealth == 6 {
                ToolTips.showToolTip(forKey: "heartOverload", in: self)
                return
            }
            frog.maxHealth += 1
            frog.currentHealth += 1
            drawHearts()
        case "HEARTBOOST":
            frog.currentHealth = frog.maxHealth
            drawHearts()
        case "HONEY":
            frog.buffs.honey += 1
            // Track carryover: deduct from inventory and save 3 for later
            PersistenceManager.shared.usePackItem(type: "HONEY")
        case "VEST":
            frog.buffs.vest += 1
            PersistenceManager.shared.usePackItem(type: "VEST")
        case "AXE":
            frog.buffs.axe += 1
            PersistenceManager.shared.usePackItem(type: "AXE")
        case "SWATTER":
            frog.buffs.swatter += 1
            PersistenceManager.shared.usePackItem(type: "SWATTER")
        case "CROSS":
            frog.buffs.cross += 1
            PersistenceManager.shared.usePackItem(type: "CROSS")
        case "BOOTS":
            frog.buffs.bootsCount += 1
            if currentWeather == .rain && !frog.isWearingBoots {
                frog.buffs.bootsCount -= 1
                frog.isWearingBoots = true
            }
        case "ROCKET":
            frog.rocketState = .flying
            let baseDuration = Configuration.GameRules.rocketDuration
            frog.rocketTimer = PersistenceManager.shared.hasDoubleRocketTime ? baseDuration * 2 : baseDuration
            frog.zHeight = max(frog.zHeight, 40)
            SoundManager.shared.play("rocket")
            SoundManager.shared.playMusic(.rocketFlight)
            ChallengeManager.shared.recordRocketUsed()
        case "SUPERJUMP":
            let baseDuration = Configuration.GameRules.superJumpDuration
            frog.buffs.superJumpTimer = PersistenceManager.shared.hasDoubleSuperJumpTime ? baseDuration * 2 : baseDuration
            SoundManager.shared.playMusic(.superJump)
        case "CANNONBALL":
            frog.buffs.cannonJumps += 1
        case "DOUBLESUPERJUMPTIME":
            // Permanent upgrade - unlock double super jump time for this and all future games
            PersistenceManager.shared.unlockDoubleSuperJumpTime()
            // Also extend the current super jump if active
            if frog.buffs.superJumpTimer > 0 {
                frog.buffs.superJumpTimer *= 2
            }
        case "DOUBLEROCKETTIME":
            // Permanent upgrade - unlock double rocket time for this and all future games
            PersistenceManager.shared.unlockDoubleRocketTime()
            // Also extend the current rocket if active
            if frog.rocketState == .flying {
                frog.rocketTimer *= 2
            }
        default: break
        }
    }
    
    // MARK: - Cannon Jump
    
    private func triggerCannonJumpLandingWave() {
        VFXManager.shared.spawnImpactWave(at: frog.position, in: self)
        SoundManager.shared.play("gameOver") // A big boom sound
        HapticsManager.shared.playNotification(.error)
        
        let cameraRect = cam.calculateAccumulatedFrame()
        
        // Use a copy of the arrays to avoid mutation issues while iterating
        let allEnemies = self.enemies
        let allSnakes = self.snakes
        
        for enemy in allEnemies {
            if cameraRect.contains(enemy.position) {
                // Destroy enemy
                enemy.removeFromParent()
                if let idx = self.enemies.firstIndex(of: enemy) {
                    self.enemies.remove(at: idx)
                }
                VFXManager.shared.spawnDebris(at: enemy.position, in: self, color: .red, intensity: 1.0)
                ChallengeManager.shared.recordEnemyDefeated()
            }
        }
        
        for snake in allSnakes {
            if cameraRect.contains(snake.position) && !snake.isDestroyed {
                // Destroy snake
                snake.destroy()
                if let idx = self.snakes.firstIndex(of: snake) {
                    self.snakes.remove(at: idx)
                }
                VFXManager.shared.spawnDebris(at: snake.position, in: self, color: .green, intensity: 1.0)
                ChallengeManager.shared.recordEnemyDefeated()
            }
        }
    }
    
    // MARK: - Challenge Progress
    
    private func reportChallengeProgress() {
        ChallengeManager.shared.recordGameEnd(
            score: score,
            coinsCollected: coinsCollectedThisRun,
            padsLanded: padsLandedThisRun,
            consecutiveJumps: bestConsecutiveJumps,
            consecutiveRaces:ChallengeManager.shared.stats.currentWinningStreak
        )
        
        // Save the best combo from this run
        let isNewRecord = PersistenceManager.shared.saveCombo(maxComboThisRun)
        
        if isNewRecord {
            // New combo record
        }
    }
    
    // MARK: - Daily Challenge
    
    /// Shows a banner at the start with challenge info
    private func showDailyChallengeBanner(_ challenge: DailyChallenge) {
        let banner = SKSpriteNode(color: .black.withAlphaComponent(0.85), size: CGSize(width: size.width * 0.9, height: 180))
        banner.name = "dailyChallengeBanner"
        banner.position = CGPoint(x: 0, y: 0)  // Centered on camera (uiNode is camera-relative)
        banner.zPosition = Layer.overlay
        
        let titleLabel = SKLabelNode(fontNamed: "Fredoka-Bold")
        titleLabel.text = challenge.name
        titleLabel.fontSize = 24
        titleLabel.fontColor = UIColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1)
        titleLabel.position = CGPoint(x: 0, y: 50)
        banner.addChild(titleLabel)
        
        let descLabel = SKLabelNode(fontNamed: "Nunito-Bold")
        descLabel.text = challenge.description
        descLabel.fontSize = 16
        descLabel.fontColor = .white
        descLabel.position = CGPoint(x: 0, y: -10)
        descLabel.preferredMaxLayoutWidth = size.width * 0.8
        descLabel.numberOfLines = 2
        banner.addChild(descLabel)
        
        let goalLabel = SKLabelNode(fontNamed: "Nunito-Bold")
        goalLabel.text = "Goal: Reach 1000m for Best Time!"
        goalLabel.fontSize = 14
        goalLabel.fontColor = .yellow
        goalLabel.position = CGPoint(x: 0, y: -45)
        banner.addChild(goalLabel)
        
        uiNode.addChild(banner)
        
        // Fade out after 4 seconds
        let sequence = SKAction.sequence([
            SKAction.wait(forDuration: 4.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        banner.run(sequence)
    }
    
    /// Dismisses the daily challenge banner immediately
    private func dismissDailyChallengeBanner() {
        if let banner = uiNode.childNode(withName: "dailyChallengeBanner") {
            banner.removeAllActions()
            banner.removeFromParent()
        }
    }
    
    
    private func spawnFinishLine() {
        guard currentChallenge != nil else { return }
        
        let finishLine = SKNode()
        finishLine.name = "finishLine"
        
        // Calculate world position for 2000m mark
        let finishY = frog.position.y + (2000 - CGFloat(score))
        
        // Create checkered pattern banner
        let bannerWidth: CGFloat = size.width * 1.2
        let bannerHeight: CGFloat = 60
        let squareSize: CGFloat = 30
        
        // Background banner
        let banner = SKSpriteNode(color: .white, size: CGSize(width: bannerWidth, height: bannerHeight))
        banner.position = CGPoint(x: size.width / 2, y: 0)
        banner.zPosition = Layer.pad + 5 // Behind player but in front of pads
        
        // Add checkered pattern
        let squaresAcross = Int(bannerWidth / squareSize) + 1
        for i in 0..<squaresAcross {
            let x = CGFloat(i) * squareSize - bannerWidth / 2 + squareSize / 2
            
            // Top row
            let topSquare = SKSpriteNode(color: i % 2 == 0 ? .black : .white,
                                         size: CGSize(width: squareSize, height: squareSize))
            topSquare.position = CGPoint(x: x, y: squareSize / 2)
            banner.addChild(topSquare)
            
            // Bottom row (inverse pattern)
            let bottomSquare = SKSpriteNode(color: i % 2 == 0 ? .white : .black,
                                            size: CGSize(width: squareSize, height: squareSize))
            bottomSquare.position = CGPoint(x: x, y: -squareSize / 2)
            banner.addChild(bottomSquare)
        }
        
        finishLine.addChild(banner)
        
        // Add "FINISH" text
        let finishLabel = SKLabelNode(fontNamed: "Fredoka-Bold")
        finishLabel.text = "FINISH"
        finishLabel.fontSize = 36
        finishLabel.fontColor = .cyan
        finishLabel.position = CGPoint(x: size.width / 2, y: 5)
        finishLabel.zPosition = Layer.pad + 6
        
        // Add outline/stroke effect
        let outlineLabel = SKLabelNode(fontNamed: "Fredoka-Bold")
        outlineLabel.text = "FINISH"
        outlineLabel.fontSize = 36
        outlineLabel.fontColor = .black
        outlineLabel.position = CGPoint(x: 0, y: 0)
        outlineLabel.zPosition = -1
        for xOffset in [-2.0, 2.0] {
            for yOffset in [-2.0, 2.0] {
                let shadow = SKLabelNode(fontNamed: "Fredoka-Bold")
                shadow.text = "FINISH"
                shadow.fontSize = 36
                shadow.fontColor = .black
                shadow.position = CGPoint(x: xOffset, y: yOffset)
                shadow.zPosition = -1
                finishLabel.addChild(shadow)
            }
        }
        
        finishLine.addChild(finishLabel)
        
        // Add distance marker
        let distanceLabel = SKLabelNode(fontNamed: "Nunito-Bold")
        distanceLabel.text = "2000m"
        distanceLabel.fontSize = 18
        distanceLabel.fontColor = .yellow
        distanceLabel.position = CGPoint(x: size.width / 2, y: -40)
        distanceLabel.zPosition = Layer.pad + 6
        finishLine.addChild(distanceLabel)
        
        // Position the entire finish line node
        finishLine.position = CGPoint(x: 0, y: finishY)
        
        // Add pulsing animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        finishLabel.run(SKAction.repeatForever(pulse))
        
        // Add shimmer effect to banner
        let shimmer = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        ])
        banner.run(SKAction.repeatForever(shimmer))
        
        finishLineNode = finishLine as! SKShapeNode
        addChild(finishLine)
        
        print("🏁 Finish line spawned at \(finishY)")
    }

    /// Called when the frog reaches 2000m in a daily challenge
    private func handleDailyChallengeComplete() {
        guard !isGameEnding else { return }
        isGameEnding = true
        
        // Record the completion time
        let finalTime = challengeElapsedTime
        DailyChallenges.shared.recordRun(timeInSeconds: finalTime, completed: true)
        
        // Play success sound
        SoundManager.shared.play("coin")
        HapticsManager.shared.playNotification(.success)
        
        // Show completion effect
        VFXManager.shared.spawnSparkles(at: frog.position, in: self)
        
        // End the game after a brief celebration
        let wait = SKAction.wait(forDuration: 1.0)
        let endGame = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.reportChallengeProgress()
            self.restoreUnusedPackItems()
            self.coordinator?.gameDidEnd(score: self.score, coins: 0, raceResult: nil)
        }
        run(SKAction.sequence([wait, endGame]))
    }
}

//
//  GameScene+Tooltips.swift
//
//  Example extension showing how to add entity tooltip support to your GameScene
//


// MARK: - Tooltip Support Extension
extension GameScene {
    
    /// Call this from your main update() method to check for entity tooltips
    /// This method is designed for performance - it exits early and only shows one tooltip per frame
    ///
    /// Note: You need to add helper methods in your main GameScene.swift file to access private properties:
    /// ```
    /// func getEnemiesForTooltips() -> [Enemy] { return enemies }
    /// func getPadsForTooltips() -> [Pad] { return pads }
    /// func getFliesForTooltips() -> [Coin] { return flies } // or whatever type flies are
    /// ```
    
    // MARK: - Helper Methods (Implement these in your main GameScene.swift)
    // These methods allow the extension to access private properties
    // Add these to your main GameScene class:
    /*
    func getEnemiesForTooltips() -> [Enemy] { return enemies }
    func getPadsForTooltips() -> [Pad] { return pads }
    func getFliesForTooltips() -> [Coin] { return flies } // Adjust type as needed
    */
    
    /// Calculates the visible rectangle based on camera position and view size
    /// Adds padding to trigger tooltips slightly before entities are fully visible
}

// MARK: - Collection-Based Tooltips
extension GameScene {
    
    /// Call this when a tadpole is collected to trigger the tadpole tooltip
    /// This can be called from your CollisionManagerDelegate implementation
    
    /// Call this when a treasure chest is collected to trigger the treasure tooltip
    /// Add this to your didCollect(treasureChest:) delegate method
    func checkTreasureTooltip(_ chest: TreasureChest) {
        // Trigger the treasure tooltip
        // Note: Based on the TreasureChest enum, it doesn't specifically contain tadpoles
        // If you need tadpole-specific logic, you'll need to adjust this
        ToolTips.onItemCollected("treasure", in: self)
    }
    
    /// Call this when a specific reward from a treasure chest is a tadpole
    /// Use this if your treasure rewards can include tadpoles
    func onTreasureRewardIsTadpole() {
        ToolTips.onItemCollected("tadpole", in: self)
    }
}

// MARK: - Usage Example
/*
 
 In your GameScene class:
 
 override func update(_ currentTime: TimeInterval) {
     let dt = currentTime - lastUpdateTime
     lastUpdateTime = currentTime
     
     // ... your existing update logic ...
     
     // Check for entity tooltips (add at the end of your update method)
     checkEntityTooltips()
 }
 
 
 In your CollisionManagerDelegate implementation:
 
 func didCollect(treasureChest: TreasureChest) {
     treasureChest.isCollected = true
     
     // ... your existing collection logic (sounds, animations, rewards, etc.) ...
     
     // Check if this triggers any tooltips
     checkTreasureTooltip(treasureChest)
 }
 
 // Or if you have a separate Tadpole entity:
 func didCollect(tadpole: Tadpole) {
     tadpole.isCollected = true
     
     // ... your existing collection logic ...
     
     // Trigger tadpole tooltip
     onTadpoleCollected()
 }
 
 */

// MARK: - Performance Notes
/*
 
 Performance Characteristics:
 
 1. Early Exit Optimization:
    - If scene is paused → immediate return
    - If entity type already seen → skip to next entity
    - If entity not in visible rect → skip to next entity
    
 2. One Tooltip Per Frame:
    - After showing one tooltip, the function exits
    - Prevents tooltip spam and ensures smooth experience
    
 3. Set-Based Tracking:
    - Uses Set<String> for O(1) lookup
    - After first encounter, overhead is minimal (just a set lookup)
    
 4. Memory Efficient:
    - Only stores entity type strings (10-20 bytes total)
    - No retain cycles or entity references
    
 5. Frame Budget:
    - First encounter: ~0.5-1ms (depends on entity count)
    - After encounter: <0.1ms (just set lookup and early return)
    - Worst case (many entities, none seen): ~2-3ms for 100+ entities
 
 Optimization Tips:
 
 - If you have 100+ entities, consider throttling checks:
   ```swift
   private var tooltipCheckTimer: TimeInterval = 0
   
   func checkEntityTooltips() {
       tooltipCheckTimer += deltaTime
       guard tooltipCheckTimer >= 0.5 else { return } // Check every 0.5s
       tooltipCheckTimer = 0
       // ... rest of check logic ...
   }
   ```
 
 - Filter arrays before checking:
   ```swift
   // Instead of:
   ToolTips.checkForEntityEncounters(entities: allPads, ...)
   
   // Do:
   let logs = pads.filter { $0.type == .log }
   ToolTips.checkForEntityEncounters(entities: logs, ...)
   ```
 
 */

// MARK: - Debugging
extension GameScene {
    
    /// Debug function to reset all tooltips (useful during development)
    /// You can call this from a debug menu or button
    func resetAllTooltips() {
        ToolTips.resetToolTipHistory()
    }
    
    /// Debug function to check which entities have been seen
    func printSeenEntities() {
        let entityTypes = ["FLY", "BEE", "GHOST", "DRAGONFLY", "LOG", "tadpole"]
        for type in entityTypes {
            let seen = ToolTips.hasSeenEntity(type)
            _ = "\(type): \(seen ? "✅ Seen" : "❌ Not seen")"
        }
    }
}


