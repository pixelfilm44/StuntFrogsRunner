import SpriteKit
import GameplayKit

class GameScene: SKScene, CollisionManagerDelegate {
    
    // MARK: - Dependencies
    weak var coordinator: GameCoordinator?
    private let collisionManager = CollisionManager()
    var initialUpgrade: String?
    
    // MARK: - Game Mode
    var gameMode: GameMode = .endless
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
    
    // MARK: - Nodes
    private let cam = SKCameraNode()
    private let worldNode = SKNode()
    private let uiNode = SKNode()
    private let trajectoryNode = SKShapeNode()
    private let slingshotNode = SKShapeNode()
    private let slingshotDot = SKShapeNode(circleOfRadius: 8)
    private let crosshairNode = SKShapeNode(circleOfRadius: 10)
    private let weatherNode = SKNode()
    private let leafNode = SKNode()
    private let waterLinesNode = SKNode()
    private let waterTilesNode = SKNode()
    private let flotsamNode = SKNode()
    
    // Air Jump Direction Arrows
    private let airJumpArrowsNode = SKNode()
    private var airJumpArrows: [String: SKNode] = [:]
    
    // MARK: - HUD Elements
    private let scoreLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryBold)
    private let coinLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryBold)
    private let coinIcon = SKSpriteNode(imageNamed: "star")
    private var heartNodes: [SKSpriteNode] = []
    private let buffsNode = SKNode()
    private let descendButton = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
    private let descendBg = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 30)
    private let pauseBg = SKShapeNode(circleOfRadius: 25)
    private let hudMargin: CGFloat = 20.0
    private let countdownLabel = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
    
    // Achievement Notification Card
    private let achievementCard = SKNode()
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
    
    // MARK: - State
    private var dragStartOffset: CGPoint?  // Offset from frog position when drag began
    private var dragCurrent: CGPoint?
    private var isDragging = false
    private var lastUpdateTime: TimeInterval = 0
    private var score: Int = 0
    private var totalCoins: Int = 0
    private var coinsCollectedThisRun: Int = 0
    private var isGameEnding: Bool = false
    private var currentWeather: WeatherType = .sunny
    private var weatherTimer: TimeInterval = 0
    private let weatherDuration: TimeInterval = 60.0
    private var previousRocketState: RocketState = .none
    private var ridingCrocodile: Crocodile? = nil  // Currently riding crocodile
    private var crocRideVignetteNode: SKSpriteNode?  // Vignette overlay for croc ride
    private var baseMusic: SoundManager.Music = .gameplay
    
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
        startSpawningLeaves()
        //startSpawningFlotsam()
        collisionManager.delegate = self
        startGame()
        if let starter = initialUpgrade { applyUpgrade(id: starter) }
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpgrade(_:)), name: .didSelectUpgrade, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChallengeCompleted(_:)), name: .challengeCompleted, object: nil)
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
        
        // Weather effects (rain, snow, etc.)
        cam.addChild(weatherNode)
        
        // Add leaf effect node
        leafNode.zPosition = Layer.water + 1 // Float on water, below pads
        worldNode.addChild(leafNode)
        
        // Add flotsam node
        flotsamNode.zPosition = Layer.water + 2 // Above leaves, below pads
        worldNode.addChild(flotsamNode)
        
        uiNode.zPosition = Layer.ui
        cam.addChild(uiNode)
        
        trajectoryNode.strokeColor = .white.withAlphaComponent(0.7)
        trajectoryNode.lineWidth = 4
        trajectoryNode.lineCap = .round
        trajectoryNode.zPosition = Layer.trajectory
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
        
        // Setup air jump direction arrows
        setupAirJumpArrows()
    }
    
    private func setupAirJumpArrows() {
        airJumpArrowsNode.zPosition = Layer.ui - 1
        airJumpArrowsNode.isHidden = true
        worldNode.addChild(airJumpArrowsNode)
        
        let arrowDistance: CGFloat = 60
        let directions: [(String, CGPoint, CGFloat)] = [
            ("up", CGPoint(x: 0, y: arrowDistance), 0),
            ("down", CGPoint(x: 0, y: -arrowDistance), .pi),
            ("left", CGPoint(x: arrowDistance, y: 0), -.pi / 2),
            ("right", CGPoint(x: -arrowDistance, y: 0), .pi / 2)
        ]
        
        for (name, offset, rotation) in directions {
            let arrow = createArrowNode()
            arrow.position = offset
            arrow.zRotation = rotation
            arrow.name = name
            airJumpArrowsNode.addChild(arrow)
            airJumpArrows[name] = arrow
        }
    }
    
    private func createArrowNode() -> SKNode {
        let arrowNode = SKNode()
        
        // Arrow shape (pointing up by default)
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 0, y: 15))      // Top point
        arrowPath.addLine(to: CGPoint(x: -12, y: -5)) // Bottom left
        arrowPath.addLine(to: CGPoint(x: -4, y: -5))  // Inner left
        arrowPath.addLine(to: CGPoint(x: -4, y: -15)) // Stem bottom left
        arrowPath.addLine(to: CGPoint(x: 4, y: -15))  // Stem bottom right
        arrowPath.addLine(to: CGPoint(x: 4, y: -5))   // Inner right
        arrowPath.addLine(to: CGPoint(x: 12, y: -5))  // Bottom right
        arrowPath.closeSubpath()
        
        let arrowShape = SKShapeNode(path: arrowPath)
        arrowShape.fillColor = .orange
        arrowShape.strokeColor = .white
        arrowShape.lineWidth = 2
        arrowShape.alpha = 0.9
        arrowNode.addChild(arrowShape)
        
        // Pulsing animation
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.4)
        let scaleDown = SKAction.scale(to: 0.9, duration: 0.4)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        arrowNode.run(SKAction.repeatForever(pulse))
        
        return arrowNode
    }
    
    private func startSpawningLeaves() {
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnLeaf()
        }
        // Spawn a leaf on average every 1.5 seconds
        let waitAction = SKAction.wait(forDuration: 9.5, withRange: 1.0)
        let sequence = SKAction.sequence([spawnAction, waitAction])
        let repeatForever = SKAction.repeatForever(sequence)
        
        // Run on the scene itself, not the node, to avoid being removed
        run(repeatForever, withKey: "spawnLeaves")
    }

    private func spawnLeaf() {
        let leafImages = ["leaf1", "leaf2", "leaf3"]
        guard let leafImage = leafImages.randomElement() else { return }

        let leaf = SKSpriteNode(imageNamed: leafImage)

        // --- Visuals ---
        let randomScale = CGFloat.random(in: 0.1...0.3)
        leaf.setScale(randomScale)
        leaf.alpha = CGFloat.random(in: 0.6...0.9)
        leaf.zRotation = CGFloat.random(in: 0...(2 * .pi))
        leaf.zPosition = 0 // Relative to leafNode

        // --- Positioning (in world coordinates) ---
        // Spawn ahead of the camera's view and within river bounds
        let spawnY = cam.position.y + (size.height / 2) + 100
        let spawnX = CGFloat.random(in: 20...(Configuration.Dimensions.riverWidth - 20))
        leaf.position = CGPoint(x: spawnX, y: spawnY)

        // Destination is behind the camera's current view
        let endY = cam.position.y - (size.height / 2) - 100
        let endX = spawnX + CGFloat.random(in: -150...150)
        let endPos = CGPoint(x: endX, y: endY)
        
        leafNode.addChild(leaf)

        // --- Animation for floating on water ---
        let driftDuration = TimeInterval.random(in: 15.0...25.0)

        // 1. Main drift action
        let moveAction = SKAction.move(to: endPos, duration: driftDuration)
        let removeAction = SKAction.removeFromParent()

        // 2. Gentle rotation (rocking)
        let rotationAmount = CGFloat.random(in: -0.5...0.5)
        let rotationDuration = TimeInterval.random(in: 2.0...4.0)
        let rotate1 = SKAction.rotate(byAngle: rotationAmount, duration: rotationDuration)
        rotate1.timingMode = .easeInEaseOut
        let rotate2 = rotate1.reversed()
        let rockSequence = SKAction.sequence([rotate1, rotate2])
        let rockForever = SKAction.repeatForever(rockSequence)

        // 3. Gentle swaying (side-to-side drift)
        let swayAmount = CGFloat.random(in: 20...50)
        let swayDuration = TimeInterval.random(in: 2.5...4.0)
        let swayLeft = SKAction.moveBy(x: -swayAmount, y: 0, duration: swayDuration)
        swayLeft.timingMode = .easeInEaseOut
        let swayRight = swayLeft.reversed()
        let swaySequence = SKAction.sequence([swayLeft, swayRight])
        let swayForever = SKAction.repeatForever(swaySequence)

        // Group and run all actions together
        leaf.run(SKAction.sequence([
            SKAction.group([moveAction, rockForever, swayForever]),
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
    
    private func updateAirJumpArrows() {
        if frog.canPerformAirJump() && !isDragging {
            airJumpArrowsNode.isHidden = false
            airJumpArrowsNode.position = frog.position
            // Offset vertically to account for frog's height in the air
            airJumpArrowsNode.position.y += frog.zHeight
        } else {
            airJumpArrowsNode.isHidden = true
        }
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
        
        // Assume water.png is reasonably sized (e.g., 128x128, 256x256, etc.)
        let tileSize = CGSize(width: waterTexture.size().width, height: waterTexture.size().height)
        
        // Calculate how many tiles we need to cover the screen + buffer for scrolling
        let bufferMultiplier: CGFloat = 3.0  // Extra tiles for smooth scrolling
        let tilesWide = Int(ceil(size.width / tileSize.width * bufferMultiplier))
        let tilesHigh = Int(ceil(size.height / tileSize.height * bufferMultiplier))
        
        // Create a grid of water tiles
        for row in 0..<tilesHigh {
            for col in 0..<tilesWide {
                let tile = SKSpriteNode(texture: waterTexture)
                tile.size = tileSize
                
                // Position tiles in a grid, centered around origin
                let xPos = (CGFloat(col) * tileSize.width) - (size.width * bufferMultiplier / 2)
                let yPos = (CGFloat(row) * tileSize.height) - (size.height * bufferMultiplier / 2)
                tile.position = CGPoint(x: xPos, y: yPos)
                tile.anchorPoint = CGPoint(x: 0, y: 0)
                tile.name = "waterTile"
                tile.colorBlendFactor = 0.3  // Allow weather tinting
                
                // Set initial color based on current weather
                tile.color = getTargetColor()
                
                waterTilesNode.addChild(tile)
            }
        }
    }
    
    /// Returns the appropriate water texture name based on current weather
    private func getWaterTextureName() -> String {
        switch currentWeather {
        case .night:
            return "waterNight"
        default:
            return "water"
        }
    }
    
    /// Updates water tiles to match current weather with smooth color transition
    private func updateWaterTilesColor() {
        let targetColor = getTargetColor()
        
        waterTilesNode.enumerateChildNodes(withName: "waterTile") { node, _ in
            guard let tile = node as? SKSpriteNode else { return }
            
            // Smoothly transition tile color
            if tile.color != targetColor {
                let colorAction = SKAction.colorize(with: targetColor, colorBlendFactor: 0.3, duration: 2.0)
                tile.run(colorAction)
            }
        }
    }
    
    private func updateWaterVisuals() {
        // Update water tile positions to follow camera (infinite tiling effect)
        // Get all water tiles from the waterTilesNode
        var tiles: [SKSpriteNode] = []
        waterTilesNode.enumerateChildNodes(withName: "waterTile") { node, _ in
            if let tile = node as? SKSpriteNode {
                tiles.append(tile)
            }
        }
        
        guard !tiles.isEmpty, let firstTile = tiles.first else { return }
        
        let tileSize = firstTile.size
        let cameraPos = cam.position
        
        // Calculate the grid dimensions (should match createWaterTiles)
        let tilesWide = Int(ceil(size.width / tileSize.width)) + 4
        let tilesHigh = Int(ceil(size.height / tileSize.height)) + 4
        
        // Calculate the top-left corner of the tile grid relative to camera
        let startX = floor((cameraPos.x - size.width / 2 - tileSize.width * 2) / tileSize.width) * tileSize.width
        let startY = floor((cameraPos.y - size.height / 2 - tileSize.height * 2) / tileSize.height) * tileSize.height
        
        // Position each tile in the grid
        for (index, tile) in tiles.enumerated() {
            let col = index % tilesWide
            let row = index / tilesWide
            
            let xPos = startX + (CGFloat(col) * tileSize.width) + tileSize.width / 2
            let yPos = startY + (CGFloat(row) * tileSize.height) + tileSize.height / 2
            
            tile.position = CGPoint(x: xPos, y: yPos)
        }
    }
    
    /// Spawns animated water ripples at the specified position
    /// Spawns water ripples parented to a pad so they follow moving pads
    /// Uses GPU-accelerated SKAction animations for optimal performance
    private func spawnWaterRipple(for pad: Pad) {
        // Adjust color based on weather
        let rippleColor: UIColor = switch currentWeather {
        case .sunny: .white.withAlphaComponent(0.7)
        case .rain: .cyan.withAlphaComponent(0.8)
        case .night: .cyan.withAlphaComponent(0.5)
        case .winter: .white.withAlphaComponent(0.6)
        }
        
        // Use the new parented ripple effect from VFXManager
        // Ripples are now children of the pad, so they follow moving pads automatically
        VFXManager.shared.spawnRippleEffect(
            parentedTo: pad,
            color: rippleColor,
            rippleCount: 3
        )
    }
    
    /// Spawns water ripples parented to any node (for crocodiles, etc.)
    private func spawnWaterRipple(for node: SKNode) {
        // Adjust color based on weather
        let rippleColor: UIColor = switch currentWeather {
        case .sunny: .white.withAlphaComponent(0.7)
        case .rain: .cyan.withAlphaComponent(0.8)
        case .night: .cyan.withAlphaComponent(0.5)
        case .winter: .white.withAlphaComponent(0.6)
        }
        
        // Use the new parented ripple effect from VFXManager
        VFXManager.shared.spawnRippleEffect(
            parentedTo: node,
            color: rippleColor,
            rippleCount: 3
        )
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
        
        descendBg.fillColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1)
        descendBg.strokeColor = .white
        descendBg.lineWidth = 3
        descendBg.position = CGPoint(x: 0, y: -(size.height / 2) + 100)
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
        pauseBg.position = CGPoint(x: 0, y: -(size.height / 2) + 60)
        let pauseIcon = SKLabelNode(text: "II")
        pauseIcon.fontName = Configuration.Fonts.pauseIcon.name
        pauseIcon.fontSize = Configuration.Fonts.pauseIcon.size
        pauseIcon.verticalAlignmentMode = .center
        pauseIcon.horizontalAlignmentMode = .center
        pauseIcon.fontColor = .white
        pauseBg.addChild(pauseIcon)
        uiNode.addChild(pauseBg)

        setupRaceHUD()
    }
    
    private func setupRaceHUD() {
        guard gameMode == .beatTheBoat else { return }
        
        raceProgressNode.position = CGPoint(x: 0, y: scoreLabel.position.y - 600)
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
        
        let frogIcon = SKLabelNode(text: "🐸")
        frogIcon.fontSize = 20
        frogIcon.name = "frogIcon"
        frogIcon.position = CGPoint(x: -barWidth / 2, y: 0)
        frogIcon.verticalAlignmentMode = .center
        frogIcon.zPosition = 1
        raceProgressNode.addChild(frogIcon)
        
        let boatIcon = SKLabelNode(text: "⛵️")
        boatIcon.fontSize = 20
        boatIcon.name = "boatIcon"
        boatIcon.position = CGPoint(x: -barWidth / 2, y: 0)
        boatIcon.verticalAlignmentMode = .center
        boatIcon.zPosition = 1
        raceProgressNode.addChild(boatIcon)
    }

    private func setupCountdownLabel() {
        countdownLabel.fontSize = 200
        countdownLabel.fontColor = .white
        countdownLabel.position = CGPoint(x: 0, y: 100) // A bit above center
        countdownLabel.zPosition = Layer.ui + 100
        countdownLabel.isHidden = true
        
        // Add a shadow for better visibility
        let shadow = SKLabelNode(fontNamed: Configuration.Fonts.primaryHeavy)
        shadow.fontSize = countdownLabel.fontSize
        shadow.fontColor = .black.withAlphaComponent(0.7)
        shadow.position = CGPoint(x: 5, y: -5)
        shadow.zPosition = -1
        shadow.name = "shadow" // To update text
        countdownLabel.addChild(shadow)
        
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
        cardBg.name = "achievementBg"
        achievementCard.addChild(cardBg)
        
        // Trophy icon
        let trophySprite = SKSpriteNode(imageNamed: "trophy")
        trophySprite.size = CGSize(width: 50, height: 50)
        trophySprite.position = CGPoint(x: -(size.width / 2) + 60, y: 0)
        trophySprite.name = "achievementTrophy"
        achievementCard.addChild(trophySprite)
        
        // Title label
        let titleLabel = SKLabelNode(fontNamed: Configuration.Fonts.achievementTitle.name)
        titleLabel.text = "Achievement Unlocked!"
        titleLabel.fontSize = Configuration.Fonts.achievementTitle.size
        titleLabel.fontColor = .yellow
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -(size.width / 2) + 100, y: 12)
        titleLabel.name = "achievementTitle"
        achievementCard.addChild(titleLabel)
        
        // Achievement name label
        let nameLabel = SKLabelNode(fontNamed: Configuration.Fonts.achievementName.name)
        nameLabel.text = ""
        nameLabel.fontSize = Configuration.Fonts.achievementName.size
        nameLabel.fontColor = .white
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -(size.width / 2) + 100, y: -12)
        nameLabel.name = "achievementName"
        achievementCard.addChild(nameLabel)
        
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
        if let nameLabel = achievementCard.childNode(withName: "achievementName") as? SKLabelNode {
            nameLabel.text = challenge.title
        }
        
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

    private func updateBuffsHUD() {
           buffsNode.removeAllChildren()
           var yOffset: CGFloat = 0
           
           func addBuffLabel(text: String, color: UIColor) {
               // ... (same label style) ...
               let bg = SKShapeNode(rectOf: CGSize(width: 120, height: 24), cornerRadius: 12)
               bg.fillColor = .black.withAlphaComponent(0.5)
               bg.strokeColor = color
               bg.lineWidth = 2
               bg.position = CGPoint(x: 60, y: yOffset)
               
               let lbl = SKLabelNode(fontNamed: Configuration.Fonts.buffIndicator.name)
               lbl.text = text
               lbl.fontSize = Configuration.Fonts.buffIndicator.size
               lbl.fontColor = .white
               lbl.verticalAlignmentMode = .center
               lbl.position = CGPoint(x: 0, y: 0)
               bg.addChild(lbl)
               
               buffsNode.addChild(bg)
               yOffset -= 30
           }
           
           // Air Jump indicator - show when available
           if frog.canPerformAirJump() {
               addBuffLabel(text: "🦘 AIR JUMP!", color: .orange)
           }
           
           if frog.buffs.vest > 0 { addBuffLabel(text: "VEST x\(frog.buffs.vest)", color: .orange) }
           if frog.buffs.honey > 0 { addBuffLabel(text: "HONEY x\(frog.buffs.honey)", color: .yellow) }
           if frog.buffs.axe > 0 { addBuffLabel(text: "🪓 AXE x\(frog.buffs.axe)", color: .brown) }
           if frog.buffs.swatter > 0 { addBuffLabel(text: "🏸 SWAT x\(frog.buffs.swatter)", color: .green) }
           if frog.buffs.cross > 0 { addBuffLabel(text: "✝️ CROSS x\(frog.buffs.cross)", color: .white) }
           
           if frog.rocketTimer > 0 {
               let sec = Int(ceil(Double(frog.rocketTimer) / 60.0)) // FIX: Round Up
               addBuffLabel(text: "🚀 \(sec)s", color: .red)
           } else if frog.rocketState == .landing {
                addBuffLabel(text: "⚠ DESCEND", color: .red)
           }
           
           // FIX: SuperJump Timer with rounding
           if frog.buffs.superJumpTimer > 0 {
               let sec = Int(ceil(Double(frog.buffs.superJumpTimer) / 60.0))
               addBuffLabel(text: "⚡️ \(sec)s", color: .cyan)
           }
           
           if frog.buffs.bootsCount > 0 {
               let label = frog.isWearingBoots ? "👢 ACTIVE" : "👢 x\(frog.buffs.bootsCount)"
               let color: UIColor = frog.isWearingBoots ? .green : .blue
               addBuffLabel(text: label, color: color)
           }
           
           // Crocodile ride timer
           if let croc = ridingCrocodile, croc.isCarryingFrog {
               let remaining = Int(ceil(croc.remainingRideTime()))
               addBuffLabel(text: "🐊 RIDE \(remaining)s", color: .green)
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
        updateBuffsHUD()
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
        frog.isFloating = false
        frog.isWearingBoots = false
        frog.canJumpLogs = PersistenceManager.shared.hasLogJumper
        frog.rocketTimer = 0
        frog.resetPullOffset()
        
        worldNode.addChild(frog)
        coinsCollectedThisRun = 0
        padsLandedThisRun = 0
        consecutiveJumps = 0
        bestConsecutiveJumps = 0
        crocodilesSpawnedThisRun = 0
        previousRocketState = .none
        spawnInitialPads()
        drawHearts()
        updateBuffsHUD()
        descendBg.isHidden = true
        setWeather(.sunny, duration: 0.0)

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
        let boatInstance = Boat(position: CGPoint(x: Configuration.Dimensions.riverWidth / 2 - 250, y: -50), wakeTargetNode: worldNode)
        worldNode.addChild(boatInstance)
        self.boat = boatInstance
        
        // Create the finish line
        let finishY = Configuration.GameRules.boatRaceFinishY
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: finishY))
        path.addLine(to: CGPoint(x: Configuration.Dimensions.riverWidth, y: finishY))
        
        let lineNode = SKShapeNode(path: path)
        lineNode.strokeColor = .yellow
        lineNode.lineWidth = 15
        lineNode.zPosition = Layer.pad - 1 // Below pads
        
        // Add checkered flag pattern if the texture exists
        if let texture = SKTexture(imageNamed: "checkered") as SKTexture? {
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
            if let shadow = self.countdownLabel.childNode(withName: "shadow") as? SKLabelNode {
                shadow.text = text
            }
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
        var yPos: CGFloat = 0
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
        guard coordinator?.currentState == .playing && !isGameEnding else { return }
        
        frog.update(dt: dt, weather: currentWeather)
        for pad in pads { pad.update(dt: dt) }
        for enemy in enemies { enemy.update(dt: dt, target: frog.position) }
        for crocodile in crocodiles { 
            crocodile.update(dt: dt, frogPosition: frog.position, frogZHeight: frog.zHeight)
        }
        for fly in flies { fly.update(dt: dt) }
        
        // Update snakes - check if any reached the right edge and need respawning
        var snakesToRespawn: [Snake] = []
        for snake in snakes {
            let reachedEnd = snake.update(dt: dt, pads: pads)
            if reachedEnd && !snake.isDestroyed {
                snakesToRespawn.append(snake)
            }
        }
        // Respawn snakes that reached the right edge
        for snake in snakesToRespawn {
            respawnSnake(snake)
        }
        
        // Update frog position if riding a crocodile
        if let croc = ridingCrocodile, croc.isCarryingFrog {
            frog.position = croc.position
            frog.velocity = .zero
        }
        
        collisionManager.update(frog: frog, pads: pads, enemies: enemies, coins: coins, crocodiles: crocodiles, treasureChests: treasureChests, snakes: snakes, flies: flies, boat: boat)
        updateWeather(dt: dt)
        updateWaterVisuals()
        updateRaceState(dt: dt)
        
        if frog.rocketState == .landing {
            descendBg.isHidden = false
            let s = 1.0 + sin(currentTime * 5) * 0.05
            descendBg.setScale(s)
        } else {
            descendBg.isHidden = true
        }
        
        // Handle rocket music transitions
        if previousRocketState != .none && frog.rocketState == .none {
            SoundManager.shared.playMusic(baseMusic)
        }
        previousRocketState = frog.rocketState
        
        updateCamera()
        updateHUDVisuals()
        updateAirJumpArrows()
        
        if let lastPad = pads.last, lastPad.position.y < cam.position.y + size.height {
            generateNextLevelSlice(lastPad: lastPad)
        }
        cleanupOffscreenEntities()
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
        if let frogIcon = raceProgressNode.childNode(withName: "frogIcon") {
            frogIcon.position.x = (-barWidth / 2) + (barWidth * frogProgress)
        }
        if let boatIcon = raceProgressNode.childNode(withName: "boatIcon") {
            boatIcon.position.x = (-barWidth / 2) + (barWidth * boatProgress)
        }
        
        // Check for winner
        if frog.position.y >= finishY {
            endRace(didWin: true)
        } else if boat.position.y >= finishY {
            endRace(didWin: false)
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
    
    private func endRace(didWin: Bool) {
        guard !isGameEnding else { return }
        isGameEnding = true
        
        var coinsWon = coinsCollectedThisRun
        if didWin {
            raceResult = .win
            coinsWon += Configuration.GameRules.boatRaceReward
            SoundManager.shared.play("coin") // TODO: Add a proper victory sound
        } else {
            raceResult = .lose
            SoundManager.shared.play("gameOver")
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
    
    private func updateWeather(dt: TimeInterval) {
        weatherTimer += dt
        if weatherTimer >= weatherDuration {
            weatherTimer = 0
            advanceWeather()
        }
        
        // Update water tiles color smoothly (called every frame for smooth transitions)
        updateWaterTilesColor()
    }
    private func advanceWeather() {
        let all = WeatherType.allCases
        guard let idx = all.firstIndex(of: currentWeather) else { return }
        let nextIdx = (idx + 1) % all.count
        setWeather(all[nextIdx], duration: 1.0)
    }
    private func setWeather(_ type: WeatherType, duration: TimeInterval) {
        // Check if we need to swap water textures (when switching to/from night)
        let needsWaterTextureSwap = (currentWeather == .night && type != .night) || 
                                     (currentWeather != .night && type == .night)
        
        if currentWeather == .rain {
            frog.isWearingBoots = false
            VFXManager.shared.stopThunderCycle()
        }
        currentWeather = type
        if type == .rain {
            if frog.buffs.bootsCount > 0 {
                frog.buffs.bootsCount -= 1
                frog.isWearingBoots = true
                HapticsManager.shared.playNotification(.success)
            }
        }
        
        // If we need to swap water textures, recreate the tiles
        if needsWaterTextureSwap {
            recreateWaterTiles()
        }
        
        weatherNode.removeAllChildren()
        let w = size.width
        let h = size.height
        let pos = CGPoint(x: 0, y: h/2 + 50)
        switch type {
        case .rain:
            let rain = VFXManager.shared.createRainEmitter(width: w)
            rain.position = pos
            weatherNode.addChild(rain)
            SoundManager.shared.playWeatherSFX(.rain)
            VFXManager.shared.startThunderCycle(in: self)
        case .winter:
            let snow = VFXManager.shared.createSnowEmitter(width: w)
            snow.position = pos
            weatherNode.addChild(snow)
            SoundManager.shared.playWeatherSFX(.winter)
        case .night:
            let flies = VFXManager.shared.createFirefliesEmitter(width: w, height: h)
            flies.position = .zero
            flies.zPosition = 11
            weatherNode.addChild(flies)
            SoundManager.shared.playWeatherSFX(.night)
        case .sunny:
            SoundManager.shared.playWeatherSFX(nil)
        }
        for pad in pads { pad.updateColor(weather: type) }
        
        // Update water tiles to match new weather (color tint)
        updateWaterTilesColor()
    }
    
    /// Recreates water tiles with the appropriate texture for current weather
    private func recreateWaterTiles() {
        // Remove all existing water tiles
        waterTilesNode.removeAllChildren()
        
        // Recreate with the new texture
        createWaterTiles()
    }
    private func getTargetColor() -> UIColor {
        switch currentWeather {
        case .sunny: return Configuration.Colors.sunny
        case .rain: return Configuration.Colors.rain
        case .night: return Configuration.Colors.night
        case .winter: return Configuration.Colors.winter
        }
    }
    private func updateCamera() {
        let targetX = frog.position.x
        let targetY = frog.position.y + (size.height * 0.2)
        let lerpSpeed: CGFloat = (frog.rocketState != .none) ? 0.2 : 0.1
        cam.position.x += (targetX - cam.position.x) * lerpSpeed
        cam.position.y += (targetY - cam.position.y) * 0.1
    }
    private func cleanupOffscreenEntities() {
        let thresholdY = cam.position.y - (size.height / 2) - 200
        pads.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        enemies.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        coins.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        treasureChests.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        flies.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        flotsam.removeAll { if $0.position.y < thresholdY { $0.removeFromParent(); return true }; return false }
        // Cleanup snakes that have fallen behind the frog (passed/despawned)
        snakes.removeAll { snake in
            if snake.position.y < thresholdY || snake.isDestroyed {
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
        
        // Pad type selection based on difficulty level
        if difficultyLevel >= Configuration.Difficulty.movingPadStartLevel && Double.random(in: 0...1) < Configuration.Difficulty.movingPadProbability {
            type = .moving
        } else if difficultyLevel >= Configuration.Difficulty.icePadStartLevel && Double.random(in: 0...1) < Configuration.Difficulty.icePadProbability {
            type = .ice
        }
        if scoreVal > 150 && Double.random(in: 0...1) < 0.15 { type = .waterLily }
        if currentWeather == .night && Double.random(in: 0...1) < 0.15 { type = .grave }
        let shrinkingChance = Configuration.Difficulty.shrinkingProbability(forLevel: difficultyLevel)
        if Double.random(in: 0...1) < shrinkingChance { type = .shrinking }
        
        let pad = Pad(type: type, position: CGPoint(x: newX, y: newY), radius: newPadRadius)
        pad.updateColor(weather: currentWeather)
        worldNode.addChild(pad)
        pads.append(pad)
        
        // Spawn crocodile near water lily pads
        // Only spawn if: score >= 2500 and we haven't reached max crocodiles this run
        let canSpawnCrocodile = scoreVal >= Configuration.Difficulty.crocodileMinScore &&
                                crocodilesSpawnedThisRun < Configuration.Difficulty.crocodileMaxPerRun
        if type == .waterLily && canSpawnCrocodile && Double.random(in: 0...1) < Configuration.Difficulty.crocodileSpawnProbability {
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
        // This applies to normal pads only, not water lilies
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
        if Double.random(in: 0...1) < enemyProb {
            if type != .grave {
                // Enemy type selection based on difficulty
                let dragonflyChance = Configuration.Difficulty.dragonflyProbability(forLevel: difficultyLevel)
                let enemyType = (Double.random(in: 0...1) < dragonflyChance) ? "DRAGONFLY" : "BEE"
                // Spawn enemy directly above the pad's position
                let enemy = Enemy(position: CGPoint(x: newX, y: newY + 50), type: enemyType)
                worldNode.addChild(enemy)
                enemies.append(enemy)
            }
        }
        
        // Snake spawning - snakes appear after difficulty level 2 (1000m)
        // They move from left to right across the screen
        let snakeProb = Configuration.Difficulty.snakeProbability(forLevel: difficultyLevel)
        if Double.random(in: 0...1) < snakeProb && snakes.count < Configuration.Difficulty.snakeMaxOnScreen {
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
        
        let snake = Snake(position: CGPoint(x: snakeX, y: snakeY))
        worldNode.addChild(snake)
        snakes.append(snake)
    }
    
    /// Respawns a snake that has reached the right edge of the screen
    private func respawnSnake(_ oldSnake: Snake) {
        // Remove the old snake
        oldSnake.removeFromParent()
        if let idx = snakes.firstIndex(of: oldSnake) {
            snakes.remove(at: idx)
        }
        
        // Spawn a new snake on the left at a similar Y position (adjusted for camera movement)
        let newSnakeX: CGFloat = -30
        // Spawn ahead of the current camera position
        let newSnakeY = cam.position.y + CGFloat.random(in: 0...size.height * 0.5)
        
        let newSnake = Snake(position: CGPoint(x: newSnakeX, y: newSnakeY))
        worldNode.addChild(newSnake)
        snakes.append(newSnake)
    }
    
    func didHitObstacle(pad: Pad) {
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
            SoundManager.shared.play("ghost")
            HapticsManager.shared.playNotification(.warning)
            
            let ghost = Enemy(position: CGPoint(x: pad.position.x, y: pad.position.y + 40), type: "GHOST")
            worldNode.addChild(ghost)
            enemies.append(ghost)
        }
    }
    func didFallIntoWater() {
        guard !isGameEnding else { return }
        if frog.isFloating { return }
        
        // If frog was riding a crocodile, this shouldn't happen, but handle it
        if let croc = ridingCrocodile {
            _ = croc.stopCarrying()
            ridingCrocodile = nil
        }
        
        // Reset consecutive jumps on fall
        consecutiveJumps = 0
        
        if frog.buffs.vest > 0 {
            frog.buffs.vest -= 1
            VFXManager.shared.spawnSplash(at: frog.position, in: self)
            HapticsManager.shared.playNotification(.warning)
            frog.velocity = .zero
            frog.zHeight = 0
            frog.zVelocity = 0
            frog.onPad = nil
            frog.isFloating = true
            updateBuffsHUD()
            return
        }
        SoundManager.shared.play("splash")
        VFXManager.shared.spawnSplash(at: frog.position, in: self)
        HapticsManager.shared.playNotification(.error)
        frog.currentHealth -= 1
        drawHearts()
        frog.hit()
        if frog.currentHealth <= 0 {
            if gameMode == .beatTheBoat {
                endRace(didWin: false)
                return
            }
            isGameEnding = true
            
            // Create dramatic drowning sequence before game over
            playDrowningSequence()
        } else {
            // Bounce with guidance toward nearest lilypad
            bounceTowardNearestPad()
        }
    }
    
    /// Plays the dramatic drowning sequence with splash and frog sinking underwater
    private func playDrowningSequence() {
        // Stop all frog movement immediately
        frog.velocity = .zero
        frog.zVelocity = 0
        frog.zHeight = 0
        
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
    /// Ripples are parented to the frog node so they stay at the drowning location
    private func spawnDrowningRipples() {
        // Use the new parented dramatic ripples from VFXManager
        // Parent to frog so ripples stay at drowning location even if frog node moves during animation
        VFXManager.shared.spawnDramaticRipples(
            parentedTo: frog,
            color: .white,
            rippleCount: 4
        )
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
                endRace(didWin: false)
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
        
        // Bounce the frog toward the nearest safe lilypad, just like falling in water.
        // This gives the player a chance to recover instead of getting stuck.
        bounceTowardNearestPad()
    }
    
    func didCrash(into snake: Snake) {
        guard !isGameEnding else { return }
        guard !snake.isDestroyed else { return }
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
                endRace(didWin: false)
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
                self.coordinator?.triggerUpgradeMenu(hasFullHealth: hasFullHealth)
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
        if frog.rocketState != .none {
            let dir: CGFloat = location.x < cam.position.x ? -1 : 1
            frog.velocity.dx += dir * 0.8
            return
        }
        
        // Crocodile steering - tap left or right side of screen to steer
        if let croc = ridingCrocodile, croc.isCarryingFrog {
            let dir: CGFloat = location.x < cam.position.x ? -1 : 1
            croc.steer(dir)
            HapticsManager.shared.playImpact(.light)
            return
        }
        
        // Air jump - directional tap control (not slingshot)
        if frog.canPerformAirJump() {
            let direction = calculateAirJumpDirection(from: location)
            frog.airJump(direction: direction)
            airJumpArrowsNode.isHidden = true
            return
        }
        
        // Normal slingshot for grounded jumps only
        if frog.zHeight <= 0.1 {
            isDragging = true
            // Store offset from frog, so slingshot follows moving platforms
            dragStartOffset = CGPoint(x: location.x - frog.position.x, y: location.y - frog.position.y)
            dragCurrent = location
            updateTrajectoryVisuals()
        }
    }
    
    /// Calculate the direction for air jump based on where the player tapped relative to the frog
    private func calculateAirJumpDirection(from tapLocation: CGPoint) -> CGVector {
        let frogScreenPos = frog.position
        let dx = tapLocation.x - frogScreenPos.x
        let dy = tapLocation.y - frogScreenPos.y
        
        // Normalize the direction
        let length = sqrt(dx * dx + dy * dy)
        if length > 0 {
            return CGVector(dx: dx / length, dy: dy / length)
        }
        // Default to upward if tap is exactly on frog
        return CGVector(dx: 0, dy: 1)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameEnding, isDragging, let touch = touches.first else { return }
        dragCurrent = touch.location(in: self)
        updateTrajectoryVisuals()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        trajectoryNode.path = nil
        slingshotNode.path = nil
        slingshotDot.isHidden = true
        crosshairNode.isHidden = true
        frog.resetPullOffset()
        if isGameEnding || frog.rocketState != .none { return }
        guard isDragging, let offset = dragStartOffset, let current = dragCurrent else { return }
        isDragging = false
        // Calculate start relative to frog's current position
        let start = CGPoint(x: frog.position.x + offset.x, y: frog.position.y + offset.y)
        let dx = start.x - current.x
        let dy = start.y - current.y
        let dist = sqrt(dx*dx + dy*dy)
        if dist < 10 { return }
        
        let maxDist = Configuration.Physics.maxDragDistance
        let ratio = min(dist, maxDist) / maxDist
        let power = Configuration.Physics.dragPower(level: PersistenceManager.shared.jumpLevel)
        
        // FIX: Apply SuperJump logic
        var launchVector = CGVector(dx: dx * power, dy: dy * power)
        if frog.buffs.superJumpTimer > 0 {
            launchVector.dx *= 2.0
            launchVector.dy *= 2.0
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
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false
        trajectoryNode.path = nil
        slingshotNode.path = nil
        slingshotDot.isHidden = true
        crosshairNode.isHidden = true
        frog.resetPullOffset()
    }
    private func updateTrajectoryVisuals() {
        guard let offset = dragStartOffset, let current = dragCurrent else { return }
        // Calculate dragStart relative to frog's current position (follows moving platforms)
        let start = CGPoint(x: frog.position.x + offset.x, y: frog.position.y + offset.y)
        let dx = start.x - current.x
        let dy = start.y - current.y
        let dist = sqrt(dx*dx + dy*dy)
        if dist < 10 {
            trajectoryNode.path = nil
            slingshotNode.path = nil
            slingshotDot.isHidden = true
            crosshairNode.isHidden = true
            frog.resetPullOffset()
            return
        }
        
        let maxDist = Configuration.Physics.maxDragDistance
        let ratio = min(dist, maxDist) / maxDist
        let power = Configuration.Physics.dragPower(level: PersistenceManager.shared.jumpLevel)
        
        // Check if SuperJump is active
        let isSuperJumping = frog.buffs.superJumpTimer > 0
        let superJumpMultiplier: CGFloat = isSuperJumping ? 2.0 : 1.0
        
        // Slingshot is only for grounded jumps now (air jumps use directional taps)
        
        // Visual Drag Line (Slingshot)
        let dragVector = CGPoint(x: current.x - start.x, y: current.y - start.y)
        frog.setPullOffset(dragVector)
        
        let visualDragDist = sqrt(dragVector.x*dragVector.x + dragVector.y*dragVector.y)
        var clampedDrag = dragVector
        if visualDragDist > maxDist {
            let s = maxDist / visualDragDist
            clampedDrag.x *= s
            clampedDrag.y *= s
        }
        
        let dotPos = CGPoint(x: frog.position.x + clampedDrag.x, y: frog.position.y + clampedDrag.y)
        slingshotDot.position = dotPos
        slingshotDot.isHidden = false
        
        // Visual styling based on jump type
        let trajectoryColor: UIColor
        let slingshotColor: UIColor
        if isSuperJumping {
            trajectoryColor = .cyan.withAlphaComponent(0.8)
            slingshotColor = .cyan
        } else {
            trajectoryColor = .white.withAlphaComponent(0.7)
            slingshotColor = .yellow
        }
        
        slingshotDot.fillColor = slingshotColor
        slingshotNode.strokeColor = slingshotColor
        trajectoryNode.strokeColor = trajectoryColor
        crosshairNode.strokeColor = slingshotColor
        
        let slingPath = CGMutablePath()
        slingPath.move(to: frog.position)
        slingPath.addLine(to: dotPos)
        slingshotNode.path = slingPath
        
        // Trajectory Line - must match EXACTLY what touchesEnded will produce
        var simPos = frog.position
        
        // Calculate launch vector exactly as touchesEnded does
        var simVel = CGVector(dx: dx * power, dy: dy * power)
        
        // Apply SuperJump multiplier (same as touchesEnded)
        if isSuperJumping {
            simVel.dx *= superJumpMultiplier
        }
        
        // Start from ground level for grounded jumps
        var simZ: CGFloat = 0
        var simZVel: CGFloat = Configuration.Physics.baseJumpZ * (0.5 + (ratio * 0.5))
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: simPos.x, y: simPos.y + simZ))
        var landingPoint = CGPoint(x: simPos.x, y: simPos.y + simZ)
        
        // Simulate the jump physics - match frog.update() physics exactly
        for _ in 0..<120 {  // More iterations for longer SuperJumps
            simPos.x += simVel.dx
            simPos.y += simVel.dy
            simZ += simZVel
            simZVel -= Configuration.Physics.gravityZ
            simVel.dx *= Configuration.Physics.frictionAir
            simVel.dy *= Configuration.Physics.frictionAir
            
            let visualPoint = CGPoint(x: simPos.x, y: simPos.y + simZ)
            path.addLine(to: visualPoint)
            
            if simZ <= 0 {
                // Landing point is at ground level (simZ = 0)
                landingPoint = CGPoint(x: simPos.x, y: simPos.y)
                break
            }
            landingPoint = CGPoint(x: simPos.x, y: simPos.y)
        }
        trajectoryNode.path = path
        
        // Position crosshairs at the exact landing position
        crosshairNode.isHidden = false
        crosshairNode.position = landingPoint
    }
    @objc func handleUpgrade(_ notification: Notification) {
        guard let id = notification.userInfo?["id"] as? String else { return }
        applyUpgrade(id: id)
        updateBuffsHUD()
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
            frog.rocketTimer = Int(Configuration.GameRules.rocketDuration * 60)
            frog.zHeight = max(frog.zHeight, 40)
            SoundManager.shared.play("rocket")
            SoundManager.shared.playMusic(.rocketFlight)
            ChallengeManager.shared.recordRocketUsed()
        case "SUPERJUMP":
            frog.buffs.superJumpTimer = Int(Configuration.GameRules.superJumpDuration * 60)
        default: break
        }
    }
    
    // MARK: - Challenge Progress
    
    private func reportChallengeProgress() {
        ChallengeManager.shared.recordGameEnd(
            score: score,
            coinsCollected: coinsCollectedThisRun,
            padsLanded: padsLandedThisRun,
            consecutiveJumps: bestConsecutiveJumps
        )
    }
}
