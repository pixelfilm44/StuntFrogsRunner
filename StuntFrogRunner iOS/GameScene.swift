import SpriteKit
import GameplayKit

class GameScene: SKScene, CollisionManagerDelegate {
    
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
    private let trajectoryDotCount = 20 // Number of dots in the trajectory line
    private let slingshotNode = SKShapeNode()
    private let slingshotDot = SKShapeNode(circleOfRadius: 8)
    private let crosshairNode = SKShapeNode(circleOfRadius: 10)
    let weatherNode = SKNode()
    private let leafNode = SKNode()
    private let waterLinesNode = SKNode()
    private let waterTilesNode = SKNode()
    private var waterTileSize = CGSize.zero
    private var waterTilesWide = 0
    private var waterTilesHigh = 0
    private let flotsamNode = SKNode()
    private var moonlightNode: SKSpriteNode?
    
    // --- Performance Improvement: Ripple Pool ---
    // A pool of reusable sprite nodes for water ripples.
    private lazy var rippleTexture: SKTexture = self.createRippleTexture()
    private var ripplePool: [SKSpriteNode] = []
    private let ripplePoolSize = 20
    private var frameCount: Int = 0
    
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
    private var activeFlies: [Fly] = []
    
    // MARK: - State
    private var dragStartOffset: CGPoint?  // Offset from frog position when drag began
    private var dragCurrent: CGPoint?
    private var isDragging = false
    private var lastHapticDragStep: Int = 0
    private var hasTriggeredMaxPullHaptic: Bool = false
    
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
    private var lastKnownRocketTimer: TimeInterval = 0
    private var lastKnownRocketState: RocketState = .none
    
    // MARK: - Cutscene State
    private var isInCutscene = false
    
    // MARK: - Challenge Tracking
    private var padsLandedThisRun: Int = 0
    private var consecutiveJumps: Int = 0
    private var bestConsecutiveJumps: Int = 0
    private var crocodilesSpawnedThisRun: Int = 0
    
    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        setupHUD()
        setupCountdownLabel()
        setupAchievementCard()
        setupInput()
        setupRipplePool()
        startSpawningLeaves()
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
    
    private func setupScene() {
        backgroundColor = .clear  // Transparent background, water tiles will show
        addChild(cam)
        camera = cam
        addChild(worldNode)
        
        // Add tiled water background - attached to worldNode so it moves with the world
        waterTilesNode.zPosition = -100
        worldNode.addChild(waterTilesNode)
        createWaterTiles()
        animateWaterTiles()
        
        // Weather effects (rain, snow, etc.) are parented to the camera for screen-space effects
        weatherNode.zPosition = Layer.overlay - 1 // Just behind the full-screen overlay
        cam.addChild(weatherNode)
        
        // Add leaf effect node, attached to camera for screen-space effect
        leafNode.zPosition = 50 // Above the game world, but below most UI.
        cam.addChild(leafNode)
        
        // Add flotsam node
        flotsamNode.zPosition = Layer.water + 2 // Above leaves, below pads
        worldNode.addChild(flotsamNode)
        
        uiNode.zPosition = Layer.ui
        cam.addChild(uiNode)
        
        // --- Performance Improvement: Hide old trajectory node ---
        // The SKShapeNode for trajectory is inefficient to update every frame.
        // We will use a pool of sprite nodes (trajectoryDots) instead.
        trajectoryNode.strokeColor = .white.withAlphaComponent(0.7)
        trajectoryNode.lineWidth = 4
        trajectoryNode.lineCap = .round
        trajectoryNode.zPosition = Layer.trajectory
        trajectoryNode.isHidden = true // Hide the old node.
        worldNode.addChild(trajectoryNode)
        
        // --- Performance Improvement: Create trajectory dot pool ---
        for _ in 0..<trajectoryDotCount {
            let dot = SKSpriteNode(color: .white, size: CGSize(width: 8, height: 8))
            dot.isHidden = true
            dot.zPosition = Layer.trajectory
            trajectoryDots.append(dot)
            worldNode.addChild(dot)
        }
        
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
    }
    
    private func startSpawningLeaves() {
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
    
    /// Creates a seamless tiled water background using water.png (or waterNight.png for night weather)
    private func createWaterTiles() {
        // Choose texture based on current weather
        let textureName = getWaterTextureName()
        let waterTexture = SKTexture(imageNamed: textureName)
        
        // Check if the texture is valid (has non-zero size)
        if waterTexture.size().width == 0 || waterTexture.size().height == 0 {
            print("Warning: \(textureName) not found, falling back to solid color")
            backgroundColor = Configuration.Colors.sunny
            return
        }
        
        let tileSize = waterTexture.size()
        self.waterTileSize = tileSize
        
        // Calculate how many tiles we need to cover the screen + buffer for scrolling
        let bufferMultiplier: CGFloat = 3.0
        let tilesWide = Int(ceil(size.width / tileSize.width * bufferMultiplier))
        let tilesHigh = Int(ceil(size.height / tileSize.height * bufferMultiplier))
        self.waterTilesWide = tilesWide
        self.waterTilesHigh = tilesHigh
        
        // Center the grid of tiles
        let gridWidth = CGFloat(tilesWide) * tileSize.width
        let gridHeight = CGFloat(tilesHigh) * tileSize.height
        
        for row in 0..<tilesHigh {
            for col in 0..<tilesWide {
                let tile = SKSpriteNode(texture: waterTexture)
                tile.size = tileSize
                
                // Flip every other tile horizontally in a checkerboard pattern
                // to create a more seamless, less repetitive texture.
                if (row + col) % 2 == 1 {
                    tile.xScale = -1.0
                }
                
                let xPos = (CGFloat(col) * tileSize.width) - (gridWidth / 2) + (tileSize.width / 2)
                let yPos = (CGFloat(row) * tileSize.height) - (gridHeight / 2) + (tileSize.height / 2)
                tile.position = CGPoint(x: xPos, y: yPos)
                tile.name = "waterTile"
                tile.colorBlendFactor = 0.3
                
                tile.color = getTargetColor()
                
                waterTilesNode.addChild(tile)
            }
        }
    }
    
    /// Animates the water tile container for a gentle ebb and flow effect.
    /// This is performant as it only animates one node.
    private func animateWaterTiles() {
        // To ensure we don't add multiple animations if this were ever called again
        waterTilesNode.removeAction(forKey: "waterAnimation")
        
        let horizontalDrift: CGFloat = 8.0
        let verticalDrift: CGFloat = 4.0
        let driftDuration: TimeInterval = 6.0

        let moveRightUp = SKAction.moveBy(x: horizontalDrift, y: verticalDrift, duration: driftDuration / 2)
        moveRightUp.timingMode = .easeInEaseOut

        let moveLeftDown = SKAction.moveBy(x: -horizontalDrift, y: -verticalDrift, duration: driftDuration / 2)
        moveLeftDown.timingMode = .easeInEaseOut

        let moveSequence = SKAction.sequence([moveRightUp, moveLeftDown])
        let moveBackAndForth = SKAction.repeatForever(moveSequence)
        
        waterTilesNode.run(moveBackAndForth, withKey: "waterAnimation")
    }
    
    private func createMoonlightNode() -> SKSpriteNode {
        // The node needs to be large enough to cover the screen even with parallax.
        // 2x screen size is a safe bet.
        let nodeSize = CGSize(width: size.width * 2, height: size.height * 2)
        
        // Create the gradient texture programmatically.
        let renderer = UIGraphicsImageRenderer(size: nodeSize)
        let image = renderer.image { context in
            let center = CGPoint(x: nodeSize.width / 2, y: nodeSize.height / 2)
            let radius = nodeSize.width / 2
            
            // A soft, bluish-white light. Increased alpha for more visibility.
            let colors = [UIColor.blue.withAlphaComponent(0.28).cgColor, UIColor.clear.cgColor]
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
    
    /// Returns the appropriate water texture name based on current weather
    private func getWaterTextureName() -> String {
        switch currentWeather {
        case .night:
            return "waterNight"
        case .desert:
            return "waterSand"
        case .space:
            return "waterSpace" // You'll need to create this asset
        default:
            return "water"
        }
    }
    
    private func updateWaterVisuals() {
        guard waterTileSize != .zero else { return }

        let cameraPosition = cam.position
        
        let totalWidth = CGFloat(waterTilesWide) * waterTileSize.width
        let totalHeight = CGFloat(waterTilesHigh) * waterTileSize.height
        
        waterTilesNode.enumerateChildNodes(withName: "waterTile") { node, _ in
            // Both node.position and cameraPosition are in the same (world) coordinate space
            
            // Check vertical wrapping
            if node.position.y < cameraPosition.y - totalHeight / 2 {
                node.position.y += totalHeight
            } else if node.position.y > cameraPosition.y + totalHeight / 2 {
                node.position.y -= totalHeight
            }
            
            // Check horizontal wrapping
            if node.position.x < cameraPosition.x - totalWidth / 2 {
                node.position.x += totalWidth
            } else if node.position.x > cameraPosition.x + totalWidth / 2 {
                node.position.x -= totalWidth
            }
        }
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
    
    private func setupRipplePool() {
        for _ in 0..<ripplePoolSize {
            let ripple = SKSpriteNode(texture: rippleTexture)
            ripple.isHidden = true
            // Use alpha blending for shadows instead of additive for light.
            ripple.blendMode = .alpha
            ripplePool.append(ripple)
        }
    }
    
    private func spawnRipples(parentedTo node: SKNode, color: UIColor, rippleCount: Int, isDramatic: Bool) {
        let delayBetweenRipples = isDramatic ? 0.01 : 0.02
        
        for i in 0..<rippleCount {
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
        // Spawns a single, subtle black shadow instead of a bright ripple.
        let shadowColor: UIColor = .white
        spawnRipples(parentedTo: node, color: shadowColor, rippleCount: 1, isDramatic: true)
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
        
        coinIcon.size = CGSize(width: 24, height: 24)
        coinIcon.position = CGPoint(x: (size.width / 2) - hudMargin - 50, y: (size.height / 2) - 90)
        uiNode.addChild(coinIcon)
        
        coinLabel.text = "0"
        coinLabel.fontSize = Configuration.Fonts.hudCoins.size
        coinLabel.fontColor = .yellow
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: (size.width / 2) - hudMargin - 30, y: (size.height / 2) - 100)
        uiNode.addChild(coinLabel)
        
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
        
        descendBg.fillColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1)
        descendBg.strokeColor = .white
        descendBg.lineWidth = 3
        descendBg.position = CGPoint(x: 0, y: screenBottomY + bottomSafeArea + 100)
        descendBg.isHidden = true
        uiNode.addChild(descendBg)
        descendButton.text = "DESCEND!"
        descendButton.fontSize = Configuration.Fonts.descendButton.size
        descendButton.verticalAlignmentMode = .center
        descendButton.fontColor = .white
        descendBg.addChild(descendButton)
        
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
        let buffsChanged = frog.buffs != lastKnownBuffs
        let rocketChanged = frog.rocketTimer != lastKnownRocketTimer || frog.rocketState != lastKnownRocketState
        
        if buffsChanged || rocketChanged {
            updateBuffsHUD()
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
        flies.forEach { $0.removeFromParent() }
        flotsam.forEach { $0.removeFromParent() }
        pads.removeAll()
        enemies.removeAll()
        coins.removeAll()
        crocodiles.removeAll()
        treasureChests.removeAll()
        snakes.removeAll()
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

        if gameMode == .beatTheBoat {
            raceState = .countdown
            isUserInteractionEnabled = false
            setupRace()
            baseMusic = .race
            SoundManager.shared.playMusic(baseMusic)
        } else {
            baseMusic = .gameplay
            SoundManager.shared.playMusic(baseMusic)
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
        
        // Apply continuous rocket steering while touch is held
        if frog.rocketState != .none && rocketSteeringTouch != nil && rocketSteeringDirection != 0 {
            frog.steerRocket(rocketSteeringDirection)
        }
        
        checkPendingDesertTransition()
        
        let camY = cam.position.y
        let viewHeight = size.height
        let activeLowerBound = camY - viewHeight
        let activeUpperBound = camY + viewHeight
        
        // --- Performance Optimization: Clear active entity arrays ---
        // Use removeAll with keepingCapacity to avoid de-allocating the array's buffer.
        activePads.removeAll(keepingCapacity: true)
        activeEnemies.removeAll(keepingCapacity: true)
        activeCoins.removeAll(keepingCapacity: true)
        activeCrocodiles.removeAll(keepingCapacity: true)
        activeTreasureChests.removeAll(keepingCapacity: true)
        activeSnakes.removeAll(keepingCapacity: true)
        activeFlies.removeAll(keepingCapacity: true)
        
        // --- Main Entity Update Loop ---
        frog.update(dt: dt, weather: currentWeather)
        
        // --- Performance Optimization: Single-pass filtering and updating ---
        // Iterate through each entity list once to update it and determine if it's "active" (on-screen).
        
        for pad in pads {
            if pad.position.y > activeLowerBound && pad.position.y < activeUpperBound {
                // Only update pads that have logic (e.g., moving, shrinking)
                if pad.type == .moving || pad.type == .log || pad.type == .shrinking || pad.type == .waterLily {
                    pad.update(dt: dt)
                }
                activePads.append(pad)
            }
        }
        
        for enemy in enemies {
            if enemy.position.y > activeLowerBound && enemy.position.y < activeUpperBound {
                enemy.update(dt: dt, target: frog.position)
                activeEnemies.append(enemy)
            }
        }
        
        for crocodile in crocodiles {
            if crocodile.position.y > activeLowerBound && crocodile.position.y < activeUpperBound {
                crocodile.update(dt: dt, frogPosition: frog.position, frogZHeight: frog.zHeight)
                activeCrocodiles.append(crocodile)
            }
        }
        
        for fly in flies {
            if fly.position.y > activeLowerBound && fly.position.y < activeUpperBound {
                fly.update(dt: dt)
                activeFlies.append(fly)
            }
        }
        
        for coin in coins {
            if coin.position.y > activeLowerBound && coin.position.y < activeUpperBound {
                activeCoins.append(coin)
            }
        }
        
        for chest in treasureChests {
            if chest.position.y > activeLowerBound && chest.position.y < activeUpperBound {
                activeTreasureChests.append(chest)
            }
        }

        for snake in snakes {
            // Snakes are wide, so give them a larger vertical activity window
            if abs(snake.position.y - camY) < viewHeight * 1.5 {
                // Update the snake (returns true if it moved off screen, but we don't respawn)
                _ = snake.update(dt: dt, pads: activePads)
                activeSnakes.append(snake)
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
            flies: activeFlies,
            boat: boat
        )
        
        // --- Visuals & Logic ---
        checkWeatherChange()
        checkLaunchPadInteraction()
        updateWaterVisuals()
        updateRaceState(dt: dt)
        updateDrowningGracePeriod(dt: dt)
        
        // UI Updates
        if frog.rocketState == .landing {
            descendBg.isHidden = false
            let s = 1.0 + sin(currentTime * 5) * 0.05
            descendBg.setScale(s)
        } else {
            descendBg.isHidden = true
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
        updateCamera()
        updateHUDVisuals()
        
        // --- Generation & Cleanup ---
        if let lastPad = pads.last, lastPad.position.y < cam.position.y + size.height {
            generateNextLevelSlice(lastPad: lastPad)
        }
        
        // THROTTLED CLEANUP: Only run cleanup every 30 frames
        if frameCount % 30 == 0 {
            cleanupOffscreenEntities()
        }
    }

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

        for pad in pads {
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
    
    private func endRace(result: RaceResult) {
        guard !isGameEnding else { return }
        isGameEnding = true
        
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
            self.coordinator?.gameDidEnd(score: self.score, coins: coinsWon, raceResult: self.raceResult)
        }
        run(SKAction.sequence([delay, showGameOver]))
    }
    
    // MARK: - Launch Pad Detection
    
    /// Checks if the frog has interacted with the launch pad or missed it
    private func checkLaunchPadInteraction() {
        // Only check if launch pad has spawned and hasn't been hit yet
        guard hasSpawnedLaunchPad && !hasHitLaunchPad else { return }
        
        // Check if frog is using rocket and passes over/near the launch pad
        if frog.rocketState == .flying {
            let distanceFromLaunchPad = abs(frog.position.y - launchPadY)
            let horizontalDistance = abs(frog.position.x - (Configuration.Dimensions.riverWidth / 2))
            
            // If rocket passes near the launch pad (within reasonable distance)
            if frog.position.y >= launchPadY && 
               distanceFromLaunchPad < 150 && 
               horizontalDistance < 150 {
                print("🚀 Frog passed over launch pad with rocket!")
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
            print("❌ Frog missed the launch pad! Game Over.")
            handleMissedLaunchPad()
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
        if score >= nextWeatherChangeScore {
            advanceWeather()
            nextWeatherChangeScore += weatherChangeInterval
        }
    }

    private func advanceWeather() {
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
            // This branch shouldn't normally be hit, but handle it just in case
            setWeather(nextWeather, duration: 0.0)
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
        }
        self.currentWeather = type
        if type == .rain {
            if frog.buffs.bootsCount > 0 {
                frog.buffs.bootsCount -= 1
                frog.isWearingBoots = true
                HapticsManager.shared.playNotification(.success)
            }
        }
        
        // --- Visual & Audio Transitions ---
        VFXManager.shared.transitionWeather(from: oldWeather, to: type, in: self, duration: actualDuration)
        
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
        SoundManager.shared.playWeatherSFX(sfx)

        // --- In-World Object Transitions ---
        for pad in pads {
            pad.updateColor(weather: type, duration: actualDuration)
        }

        let needsWaterTextureSwap = (oldWeather == .night && type != .night) || (oldWeather != .night && type == .night) || (oldWeather == .desert && type != .desert) || (oldWeather != .desert && type == .desert) || (oldWeather == .space && type != .space) || (oldWeather != .space && type == .space)
        transitionWaterColor(needsTextureSwap: needsWaterTextureSwap, duration: actualDuration)

        // Handle moonlight visibility with a fade for smooth transitions.
        if let moon = moonlightNode {
            if type == .night {
                moon.isHidden = false
                if actualDuration > 0 {
                    moon.run(SKAction.fadeAlpha(to: 1.0, duration: actualDuration))
                } else {
                    moon.alpha = 1.0
                }
            } else if oldWeather == .night {
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
    }
    
    private func transitionWaterColor(needsTextureSwap: Bool, duration: TimeInterval) {
        if duration <= 0 {
            if needsTextureSwap {
                recreateWaterTiles()
            } else {
                let targetColor = getTargetColor()
                waterTilesNode.enumerateChildNodes(withName: "waterTile") { node, _ in
                    node.run(SKAction.colorize(with: targetColor, colorBlendFactor: 0.3, duration: 0))
                }
            }
        } else {
            if needsTextureSwap {
                let halfDuration = duration / 2.0
                
                // 1. Create an action to fade out all current tiles.
                let fadeOutAction = SKAction.run { [weak self] in
                    guard let self = self else { return }
                    // We use the 'sunny' color as a neutral intermediate color for the transition.
                    let colorize = SKAction.colorize(with: self.getTargetColor(for: .sunny), colorBlendFactor: 0.3, duration: halfDuration)
                    self.waterTilesNode.enumerateChildNodes(withName: "waterTile") { node, _ in
                        node.run(colorize)
                    }
                }

                // 2. Wait for the fade-out animation to finish.
                let waitAction = SKAction.wait(forDuration: halfDuration)

                // 3. Swap the textures by recreating the tile nodes.
                let swapTextureAction = SKAction.run { [weak self] in
                    self?.recreateWaterTiles()
                }

                // 4. Fade the new tiles from the intermediate color to their final target color.
                let fadeInAction = SKAction.run { [weak self] in
                    guard let self = self else { return }
                    let targetColor = self.getTargetColor()
                    let colorize = SKAction.colorize(with: targetColor, colorBlendFactor: 0.3, duration: halfDuration)
                    
                    self.waterTilesNode.enumerateChildNodes(withName: "waterTile") { node, _ in
                        // Set the starting color to the intermediate color before animating.
                        if let tile = node as? SKSpriteNode {
                            tile.color = self.getTargetColor(for: .sunny)
                            tile.run(colorize)
                        }
                    }
                }
                
                // Run the full sequence.
                waterTilesNode.run(SKAction.sequence([fadeOutAction, waitAction, swapTextureAction, fadeInAction]))

            } else {
                let targetColor = getTargetColor()
                let colorAction = SKAction.colorize(with: targetColor, colorBlendFactor: 0.3, duration: duration)
                waterTilesNode.enumerateChildNodes(withName: "waterTile") { node, _ in
                    node.run(colorAction)
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
        VFXManager.shared.transitionWeather(from: oldWeather, to: newWeather, in: self, duration: duration)
        SoundManager.shared.playWeatherSFX(.desert, fadeDuration: duration)

        // --- In-World Object Transitions ---
        for pad in pads {
            pad.transformToDesert(duration: duration)
        }

        // --- Custom Water Evaporation Animation ---
        let evaporationDuration = duration * 0.8
        let evaporateAction = SKAction.group([
            SKAction.scaleY(to: 0.05, duration: evaporationDuration),
            SKAction.fadeOut(withDuration: evaporationDuration)
        ])
        evaporateAction.timingMode = .easeIn
        
        self.waterTilesNode.enumerateChildNodes(withName: "waterTile") { node, _ in
            node.run(evaporateAction)
        }
    }

    private func endDesertCutscene() {
        // Officially set the game state to desert. This updates logic like instant-death water.
        self.currentWeather = .desert
        
        // Replace the evaporated water tiles with permanent sand tiles
        recreateWaterTiles()
        
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
        
        print("🚀 Launch to space initiated!")
        
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
        // Create a black overlay that covers the entire screen
        let blackOverlay = SKSpriteNode(color: .black, size: self.size)
        blackOverlay.position = .zero
        blackOverlay.zPosition = Layer.overlay + 100 // Above everything
        blackOverlay.alpha = 0
        
        cam.addChild(blackOverlay)
        
        // Fade to black
        let fadeOut = SKAction.fadeIn(withDuration: 2.0)
        
        blackOverlay.run(fadeOut) { [weak self] in
            guard let self = self else { return }
            
            // After fade is complete, transition to space weather
            self.transitionToSpace()
            
            // Wait a moment then fade back in
            let wait = SKAction.wait(forDuration: 0.5)
            let fadeIn = SKAction.fadeOut(withDuration: 2.0)
            let remove = SKAction.removeFromParent()
            
            blackOverlay.run(SKAction.sequence([wait, fadeIn, remove]))
        }
    }
    
    private func transitionToSpace() {
        print("🌌 Transitioning to space weather!")
        
        // Set the weather to space - INSTANT transition (duration: 0)
        setWeather(.space, duration: 0.0)
        
        // Instantly update all existing pads to space appearance
        for pad in pads {
            pad.updateColor(weather: .space, duration: 0.0)
        }
        
        // Reset launch flags - allow warp pad to potentially spawn later
        hasSpawnedLaunchPad = false
        hasHitLaunchPad = false
        launchPadY = 0
        isLaunchingToSpace = false
        
        // Position frog at a new starting point
        if let firstPad = pads.first {
            frog.position = CGPoint(x: Configuration.Dimensions.riverWidth / 2, y: firstPad.position.y + 100)
            frog.zHeight = 0
            frog.velocity = .zero
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
        welcomeLabel.text = "🌌 SPACE 🌌"
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
    
    /// Recreates water tiles with the appropriate texture for current weather
    private func recreateWaterTiles() {
        waterTilesNode.removeAllChildren()
        createWaterTiles()
    }
    
    private func getTargetColor(for weather: WeatherType? = nil) -> UIColor {
        switch weather ?? currentWeather {
        case .sunny: return Configuration.Colors.sunny
        case .rain: return Configuration.Colors.rain
        case .night: return Configuration.Colors.night
        case .winter: return Configuration.Colors.winter
        case .desert: return Configuration.Colors.desert
        case .space: return Configuration.Colors.space
        }
    }
    
    private func updateCamera() {
        let targetX = frog.position.x
        let targetY = frog.position.y + (size.height * 0.2)
        let lerpSpeed: CGFloat = (frog.rocketState != .none) ? 0.2 : 0.1
        cam.position.x += (targetX - cam.position.x) * lerpSpeed
        cam.position.y += (targetY - cam.position.y) * 0.1
    }
    
    private func updateMoonlightPosition() {
        guard let moonlightNode = moonlightNode, !moonlightNode.isHidden else { return }
        
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
    private func cleanupOffscreenEntities() {
        let thresholdY = cam.position.y - (size.height / 2) - 200
        pads.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        enemies.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        coins.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        treasureChests.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        flies.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        flotsam.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        
        // Cleanup snakes that have fallen behind the frog OR moved off screen
        // Snakes move horizontally (left to right), so we need to check both Y and X positions
        snakes.removeAll { snake in
            let isBelowCamera = snake.position.y < thresholdY
            let isOffScreenRight = snake.position.x > Configuration.Dimensions.riverWidth + 100
            
            if isBelowCamera || isOffScreenRight || snake.isDestroyed {
                snake.removeFromParent()
                return true
            }
            return false
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
        
        // DEBUG: Log when we reach snake spawn threshold
        if scoreVal == 3000 {
            print("🎯 Reached snake spawn threshold! Score: \(scoreVal)")
        }
        
        // Check if we should spawn the launch pad (end of desert, before space)
        if currentWeather == .desert && !hasSpawnedLaunchPad && scoreVal >= Configuration.GameRules.launchPadSpawnScore {
            type = .launchPad
            hasSpawnedLaunchPad = true
            
            // Center the launch pad in the river for dramatic effect
            newX = Configuration.Dimensions.riverWidth / 2
            launchPadY = newY
            
            print("🚀 Spawning launch pad at score: \(scoreVal), Y position: \(newY)")
        } else {
            // Normal pad type selection based on difficulty level
            if difficultyLevel >= Configuration.Difficulty.movingPadStartLevel && Double.random(in: 0...1) < Configuration.Difficulty.movingPadProbability {
                type = .moving
            } else if difficultyLevel >= Configuration.Difficulty.icePadStartLevel && Double.random(in: 0...1) < Configuration.Difficulty.icePadProbability {
                type = .ice
            }
            if scoreVal > 150 && Double.random(in: 0...1) < 0.15 { type = .waterLily }
            if currentWeather == .night && Double.random(in: 0...1) < 0.15 { type = .grave }
            let shrinkingChance = Configuration.Difficulty.shrinkingProbability(forLevel: difficultyLevel)
            if Double.random(in: 0...1) < shrinkingChance { type = .shrinking }
        }
        
        let pad = Pad(type: type, position: CGPoint(x: newX, y: newY), radius: newPadRadius)
        pad.updateColor(weather: currentWeather)
        worldNode.addChild(pad)
        pads.append(pad)
        
        // Don't spawn anything on launch pads - they're special!
        if type == .launchPad {
            return
        }
        
        // Spawn crocodile near water lily pads
        // Only spawn if: score >= 2500 and we haven't reached max crocodiles this run
        let canSpawnCrocodile = scoreVal >= Configuration.Difficulty.crocodileMinScore &&
                                crocodilesSpawnedThisRun < Configuration.Difficulty.crocodileMaxPerRun
        if type == .waterLily && canSpawnCrocodile && Double.random(in: 0...1) < Configuration.Difficulty.crocodileSpawnProbability(for: currentWeather) {
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
        
        // Log spawning based on difficulty
        let logChance = Configuration.Difficulty.logProbability(forLevel: difficultyLevel)
        if logChance > 0 && Double.random(in: 0...1) < logChance {
            let logX = CGFloat.random(in: 100...500)
            // Ensure logs don't overlap with the newly spawned pad (log radius ~60 + pad radius + spacing)
            let minLogDistance = 60.0 + pad.scaledRadius + Configuration.Dimensions.padSpacing
            if abs(logX - newX) > minLogDistance {
                let log = Pad(type: .log, position: CGPoint(x: logX, y: newY))
                worldNode.addChild(log)
                pads.append(log)
            }
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
        
        // Enemy spawning based on difficulty - enemies spawn on lily pads
        let enemyProb = Configuration.Difficulty.enemyProbability(forLevel: difficultyLevel)
        
        // Enemies can spawn on normal, moving, ice, and water lily pads.
        // They should NOT spawn on shrinking pads, graves (which spawn ghosts), or logs.
        let canSpawnEnemy = (type == .normal || type == .moving || type == .ice || type == .waterLily)
        
        if canSpawnEnemy && Double.random(in: 0...1) < enemyProb {
            // Enemy type selection based on difficulty
            let dragonflyChance = Configuration.Difficulty.dragonflyProbability(forLevel: difficultyLevel)
            let enemyType = (Double.random(in: 0...1) < dragonflyChance) ? "DRAGONFLY" : "BEE"
            // Spawn enemy directly above the pad's position
            let enemy = Enemy(position: CGPoint(x: newX, y: newY + 50), type: enemyType)
            worldNode.addChild(enemy)
            enemies.append(enemy)
        }
        
        // Snake spawning - snakes appear after 3000m
        // They move from left to right across the screen
        let snakeProb = Configuration.Difficulty.snakeProbability(forScore: scoreVal)
        
        // Count only active (visible) snakes on screen
        let activeSnakesCount = snakes.filter { !$0.isDestroyed }.count
        
        if Double.random(in: 0...1) < snakeProb && activeSnakesCount < Configuration.Difficulty.snakeMaxOnScreen {
            print("🐍 Snake spawn triggered! Score: \(scoreVal), Probability: \(snakeProb), Active snakes: \(activeSnakesCount)")
            spawnSnake(nearY: newY)
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
    
    /// Spawns a new snake on the left side of the screen at the given Y position
    private func spawnSnake(nearY: CGFloat) {
        // Spawn snake on the left edge, at a Y position near the new pad
        let snakeX: CGFloat = -30  // Start just off the left edge
        let snakeY = nearY + CGFloat.random(in: -50...50)
        
        print("🐍 Spawning snake at position: (\(snakeX), \(snakeY)), Camera Y: \(cam.position.y)")
        
        let snake = Snake(position: CGPoint(x: snakeX, y: snakeY))
        worldNode.addChild(snake)
        snakes.append(snake)
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

        // Vest has priority: consumes a vest and makes the frog float safely.
        if frog.buffs.vest > 0 {
            frog.buffs.vest -= 1
            VFXManager.shared.spawnSplash(at: frog.position, in: self)
            HapticsManager.shared.playNotification(.warning)
            frog.velocity = .zero
            frog.zHeight = 0
            frog.zVelocity = 0
            frog.onPad = nil
            frog.isFloating = true // Start floating safely, allowing a jump out.
            updateBuffsHUD()
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
                self.coordinator?.gameDidEnd(score: self.score, coins: self.coinsCollectedThisRun, raceResult: self.raceResult)
            }
            self.run(SKAction.sequence([delay, showGameOver]))
        }
    }
    
    /// Plays the dramatic enemy death sequence with spinning and falling off screen
    private func playEnemyDeathSequence() {
        // Stop all frog movement immediately
        frog.velocity = .zero
        frog.zVelocity = 0
        
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
                self.coordinator?.gameDidEnd(score: self.score, coins: self.coinsCollectedThisRun, raceResult: self.raceResult)
            }
            self.run(SKAction.sequence([delay, showGameOver]))
        }
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
        frog.bounce()
        
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
        
        if frog.isCannonJumping {
            enemy.removeFromParent()
            if let idx = enemies.firstIndex(of: enemy) { enemies.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: enemy.position, in: self, color: .red, intensity: 1.0)
            SoundManager.shared.play("hit")
            return
        }
        
        if frog.isInvincible { return }
        if enemy.type == "DRAGONFLY" && frog.buffs.swatter > 0 {
            frog.buffs.swatter -= 1
            enemy.removeFromParent()
            if let idx = enemies.firstIndex(of: enemy) { enemies.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            updateBuffsHUD()
            return
        }
        if enemy.type == "GHOST" && frog.buffs.cross > 0 {
            frog.buffs.cross -= 1
            enemy.removeFromParent()
            if let idx = enemies.firstIndex(of: enemy) { enemies.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            updateBuffsHUD()
            return
        }
        if enemy.type == "BEE" && frog.buffs.honey > 0 {
            frog.buffs.honey -= 1
            enemy.removeFromParent()
            if let idx = enemies.firstIndex(of: enemy) { enemies.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            updateBuffsHUD()
            return
        }
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
        
        if frog.isCannonJumping {
            snake.destroy()
            if let idx = snakes.firstIndex(of: snake) { snakes.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            ChallengeManager.shared.recordEnemyDefeated()
            VFXManager.shared.spawnDebris(at: snake.position, in: self, color: .green, intensity: 1.0)
            SoundManager.shared.play("hit")
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
        totalCoins += 1
        coinsCollectedThisRun += 1
        coin.removeFromParent()
        if let idx = coins.firstIndex(of: coin) { coins.remove(at: idx) }
        
        // Real-time challenge update
        ChallengeManager.shared.recordCoinsCollected(totalThisRun: coinsCollectedThisRun, totalOverall: PersistenceManager.shared.totalCoins + coinsCollectedThisRun)
        
        if coinsCollectedThisRun > 0 && coinsCollectedThisRun % Configuration.GameRules.coinsForUpgradeTrigger == 0 {
            let wait = SKAction.wait(forDuration: 0.2)
            let trigger = SKAction.run { [weak self] in
                guard let self = self else { return }
                let hasFullHealth = self.frog.currentHealth >= self.frog.maxHealth
                self.coordinator?.triggerUpgradeMenu(hasFullHealth: hasFullHealth, distanceTraveled: self.score)
            }
            run(SKAction.sequence([wait, trigger]))
        }
    }
    
    func didCollect(fly: Fly) {
        guard !isGameEnding else { return }
        
        // Only heal if the frog has an empty heart slot
        if frog.currentHealth < frog.maxHealth {
            frog.currentHealth += 1
            drawHearts()
            
            // Play healing sound and haptics
            SoundManager.shared.play("coin")  // Use coin sound or create a unique "heal" sound
            HapticsManager.shared.playNotification(.success)
            
            // Show healing indicator
            showHealingIndicator(at: fly.position)
        } else {
            // Already at full health - still play feedback but no heal
            SoundManager.shared.play("coin")
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
        SoundManager.shared.play("coin")  // TODO: Add a unique chest sound if desired
        HapticsManager.shared.playNotification(.success)
        
        // Show floating reward notification
        showTreasureChestReward(reward, at: treasureChest.position)
        
        // Update HUD to reflect new buffs
        updateBuffsHUD()
        drawHearts()
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
        rewardLabel.position = CGPoint(x: position.x, y: position.y + 30)
        rewardLabel.zPosition = Layer.ui
        
        // Add background for readability
        let bgSize = CGSize(width: 180, height: 40)
        let bgNode = SKShapeNode(rectOf: bgSize, cornerRadius: 10)
        bgNode.fillColor = .black.withAlphaComponent(0.7)
        bgNode.strokeColor = .yellow
        bgNode.lineWidth = 2
        bgNode.zPosition = -1
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
        
        // Give reward for completing the ride
        let reward = Crocodile.carryReward
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
        if frog.rocketState == .landing && descendBg.contains(locationInUI) && !descendBg.isHidden {
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
        
        // Normal slingshot for grounded jumps only
        if frog.zHeight <= 0.1 {
            isDragging = true
            // Store offset from frog, so slingshot follows moving platforms
            dragStartOffset = CGPoint(x: location.x - frog.position.x, y: location.y - frog.position.y)
            dragCurrent = location
            
            // Reset haptics for new drag
            lastHapticDragStep = 0
            hasTriggeredMaxPullHaptic = false
            
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
        
        trajectoryDots.forEach { $0.isHidden = true }
        slingshotNode.path = nil
        slingshotDot.isHidden = true
        crosshairNode.isHidden = true
        frog.resetPullOffset()
        
        guard isDragging, let offset = dragStartOffset, let current = dragCurrent else {
            if frog.rocketState == .none {
                isDragging = false
            }
            return
        }
        
        isDragging = false
        // Reset haptics state
        lastHapticDragStep = 0
        hasTriggeredMaxPullHaptic = false

        if isGameEnding || frog.rocketState != .none { return }
        
        // Calculate start relative to frog's current position
        let start = CGPoint(x: frog.position.x + offset.x, y: frog.position.y + offset.y)
        let dx = start.x - current.x
        let dy = start.y - current.y
        let dist = sqrt(dx*dx + dy*dy)
        if dist < 10 {
            // If jump was cancelled, and cannon was armed, de-arm it.
            if frog.isCannonJumpArmed {
                frog.isCannonJumpArmed = false
            }
            return
        }
        
        let maxDist = Configuration.Physics.maxDragDistance
        let ratio = min(dist, maxDist) / maxDist
        let power = Configuration.Physics.dragPower(level: PersistenceManager.shared.jumpLevel)
        
        // FIX: Apply SuperJump logic
        var launchVector = CGVector(dx: dx * power, dy: dy * power)
        if frog.buffs.superJumpTimer > 0 {
            launchVector.dx *= 2.0
            launchVector.dy *= 2.0
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
        frog.jump(vector: launchVector, intensity: ratio)
        
        // If we just jumped out of the water, stop the grace period.
        if frog.isFloating {
            frog.isFloating = false
            stopDrowningGracePeriod()
        }
        
        // Play release haptic based on power
        if ratio >= 0.95 {
            HapticsManager.shared.playImpact(.heavy)
        } else if ratio > 0.5 {
            HapticsManager.shared.playImpact(.medium)
        } else {
            HapticsManager.shared.playImpact(.light)
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
        trajectoryDots.forEach { $0.isHidden = true }
        slingshotNode.path = nil
        slingshotDot.isHidden = true
        crosshairNode.isHidden = true
        frog.resetPullOffset()
    }
    
    // --- Performance Improvement: Use sprite pool for trajectory ---
    // This function now updates the positions of a pre-allocated array of sprites
    // instead of regenerating a complex SKShapeNode path every frame.
    private func updateTrajectoryVisuals() {
        guard let offset = dragStartOffset, let current = dragCurrent else { return }
        
        // Calculate dragStart relative to frog's current position (follows moving platforms)
        let start = CGPoint(x: frog.position.x + offset.x, y: frog.position.y + offset.y)
        let dx = start.x - current.x
        let dy = start.y - current.y
        let dist = sqrt(dx*dx + dy*dy)
        
        // Hide visuals if drag is too small
        if dist < 10 {
            trajectoryDots.forEach { $0.isHidden = true }
            slingshotNode.path = nil
            slingshotDot.isHidden = true
            crosshairNode.isHidden = true
            frog.resetPullOffset()
            return
        }
        
        let maxDist = Configuration.Physics.maxDragDistance
        
        // Haptic feedback for pulling back
        let hapticStepThreshold: CGFloat = 30.0
        let currentStep = Int(dist / hapticStepThreshold)

        if dist < maxDist {
            if currentStep > self.lastHapticDragStep {
                HapticsManager.shared.playImpact(.light)
                self.lastHapticDragStep = currentStep
            }
        } else {
            if !hasTriggeredMaxPullHaptic {
                HapticsManager.shared.playImpact(.medium)
                hasTriggeredMaxPullHaptic = true
            }
        }
        
        let ratio = min(dist, maxDist) / maxDist
        let power = Configuration.Physics.dragPower(level: PersistenceManager.shared.jumpLevel)
        let isSuperJumping = frog.buffs.superJumpTimer > 0
        
        // Visual Drag Line (Slingshot)
        let dragVector = CGPoint(x: current.x - start.x, y: current.y - start.y)
        frog.setPullOffset(dragVector)
        
        var clampedDrag = dragVector
        let visualDragDist = sqrt(dragVector.x*dragVector.x + dragVector.y*dragVector.y)
        if visualDragDist > maxDist {
            clampedDrag.x *= (maxDist / visualDragDist)
            clampedDrag.y *= (maxDist / visualDragDist)
        }
        
        let dotPos = CGPoint(x: frog.position.x + clampedDrag.x, y: frog.position.y + clampedDrag.y)
        slingshotDot.position = dotPos
        slingshotDot.isHidden = false
        
        let slingPath = CGMutablePath()
        slingPath.move(to: frog.position)
        slingPath.addLine(to: dotPos)
        slingshotNode.path = slingPath
        
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
        
        // Simulate jump physics to position trajectory dots
        var simPos = frog.position
        var simVel = CGVector(dx: dx * power, dy: dy * power)
        if isSuperJumping {
            simVel.dx *= 2.0
            simVel.dy *= 2.0
        }
        var simZ: CGFloat = 0
        var simZVel: CGFloat = Configuration.Physics.baseJumpZ * (0.5 + (ratio * 0.5))
        
        var landingPoint = simPos
        var dotsUsed = 0

        // Simulate physics and place dots along the arc
        let simulationSteps = isSuperJumping ? 120 : 60
        for i in 0..<simulationSteps {
            simPos.x += simVel.dx
            simPos.y += simVel.dy
            simZ += simZVel
            simZVel -= Configuration.Physics.gravityZ
            simVel.dx *= Configuration.Physics.frictionAir
            simVel.dy *= Configuration.Physics.frictionAir
            
            // Show a dot every few simulation steps
            if i % (simulationSteps / trajectoryDotCount) == 0 {
                if dotsUsed < trajectoryDotCount {
                    let dot = trajectoryDots[dotsUsed]
                    dot.position = CGPoint(x: simPos.x, y: simPos.y + simZ)
                    dot.color = trajectoryColor
                    dot.isHidden = false
                    dotsUsed += 1
                }
            }
            
            if simZ <= 0 {
                landingPoint = simPos
                break
            }
            landingPoint = simPos
        }
        
        // Hide any unused dots from the pool
        for i in dotsUsed..<trajectoryDotCount {
            trajectoryDots[i].isHidden = true
        }
        
        // Position crosshairs at the landing position
        crosshairNode.isHidden = false
        crosshairNode.position = landingPoint
    }
    
    @objc func handleUpgrade(_ notification: Notification) {
        guard let id = notification.userInfo?["id"] as? String else { return }
        applyUpgrade(id: id)
        // No need to call updateBuffsHUD directly, the main loop will catch the change.
    }
    private func applyUpgrade(id: String) {
        switch id {
        case "HEART":
            frog.maxHealth += 1
            frog.currentHealth += 1
            drawHearts()
        case "HEARTBOOST":
            frog.currentHealth = frog.maxHealth
            drawHearts()
        case "HONEY": frog.buffs.honey += 1
        case "VEST": frog.buffs.vest += 1
        case "AXE": frog.buffs.axe += 1
        case "SWATTER": frog.buffs.swatter += 1
        case "CROSS": frog.buffs.cross += 1
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
    }
}
