import SpriteKit
import GameplayKit

class GameScene: SKScene, CollisionManagerDelegate {
    
    // MARK: - Dependencies
    weak var coordinator: GameCoordinator?
    private let collisionManager = CollisionManager()
    var initialUpgrade: String?
    
    // MARK: - Nodes
    private let cam = SKCameraNode()
    private let worldNode = SKNode()
    private let uiNode = SKNode()
    private let trajectoryNode = SKShapeNode()
    private let slingshotNode = SKShapeNode()
    private let slingshotDot = SKShapeNode(circleOfRadius: 8)
    private let crosshairNode = SKShapeNode(circleOfRadius: 10)
    private let weatherNode = SKNode()
    private let waterLinesNode = SKNode()
    
    // Air Jump Direction Arrows
    private let airJumpArrowsNode = SKNode()
    private var airJumpArrows: [String: SKNode] = [:]
    
    // MARK: - HUD Elements
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let coinLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let coinIcon = SKSpriteNode(imageNamed: "star")
    private var heartNodes: [SKSpriteNode] = []
    private let buffsNode = SKNode()
    private let descendButton = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let descendBg = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 30)
    private let pauseBg = SKShapeNode(circleOfRadius: 25)
    private let hudMargin: CGFloat = 20.0
    
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
    
    // MARK: - Challenge Tracking
    private var padsLandedThisRun: Int = 0
    private var consecutiveJumps: Int = 0
    private var bestConsecutiveJumps: Int = 0
    private var crocodilesSpawnedThisRun: Int = 0
    
    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        setupScene()
        setupHUD()
        setupAchievementCard()
        setupInput()
        collisionManager.delegate = self
        startGame()
        if let starter = initialUpgrade { applyUpgrade(id: starter) }
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpgrade(_:)), name: .didSelectUpgrade, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChallengeCompleted(_:)), name: .challengeCompleted, object: nil)
    }

    private func setupScene() {
        backgroundColor = Configuration.Colors.sunny
        addChild(cam)
        camera = cam
        addChild(worldNode)
        waterLinesNode.zPosition = -50
        cam.addChild(waterLinesNode)
        createWaterLines()
        cam.addChild(weatherNode)
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
            ("left", CGPoint(x: -arrowDistance, y: 0), -.pi / 2),
            ("right", CGPoint(x: arrowDistance, y: 0), .pi / 2)
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
    
    // ... (Helper methods: createWaterLines, updateWaterVisuals, setupHUD, drawHearts same as before) ...
    
    private func createWaterLines() {
        let count = 80
        for _ in 0..<count {
            let width = CGFloat.random(in: 10...50)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: -width / 2, y: 0))
            path.addLine(to: CGPoint(x: width / 2, y: 0))
            let line = SKShapeNode(path: path.cgPath)
            line.strokeColor = .white
            line.alpha = CGFloat.random(in: 0.05...0.15)
            line.lineWidth = 2
            line.lineCap = .round
            line.name = "waterLine"
            let randomX = CGFloat.random(in: -size.width/2...size.width/2)
            let randomY = CGFloat.random(in: -size.height/2...size.height/2)
            line.position = CGPoint(x: randomX, y: randomY)
            waterLinesNode.addChild(line)
        }
    }
    
    private func updateWaterVisuals() {
        let flowSpeed: CGFloat = 2.0
        let limitX = size.width / 2 + 50
        let resetX = -size.width / 2 - 50
        waterLinesNode.children.forEach { node in
            node.position.x += flowSpeed
            if node.position.x > limitX {
                node.position.x = resetX
                node.position.y = CGFloat.random(in: -size.height/2...size.height/2)
            }
        }
    }
    
    private func setupHUD() {
        scoreLabel.text = "0m"
        scoreLabel.fontSize = 36
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: 0, y: (size.height / 2) - 110)
        let scoreShadow = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreShadow.fontColor = .black
        scoreShadow.alpha = 0.5
        scoreShadow.position = CGPoint(x: 2, y: -2)
        scoreShadow.zPosition = -1
        scoreLabel.addChild(scoreShadow)
        uiNode.addChild(scoreLabel)
        
        coinIcon.size = CGSize(width: 24, height: 24)
        coinIcon.position = CGPoint(x: (size.width / 2) - hudMargin - 50, y: (size.height / 2) - 100)
        uiNode.addChild(coinIcon)
        
        coinLabel.text = "0"
        coinLabel.fontSize = 24
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
        descendButton.fontSize = 24
        descendButton.verticalAlignmentMode = .center
        descendButton.fontColor = .white
        descendBg.addChild(descendButton)
        
        pauseBg.fillColor = .black.withAlphaComponent(0.5)
        pauseBg.strokeColor = .white
        pauseBg.lineWidth = 2
        pauseBg.position = CGPoint(x: 0, y: -(size.height / 2) + 60)
        let pauseIcon = SKLabelNode(text: "II")
        pauseIcon.fontName = "AvenirNext-Heavy"
        pauseIcon.fontSize = 24
        pauseIcon.verticalAlignmentMode = .center
        pauseIcon.horizontalAlignmentMode = .center
        pauseIcon.fontColor = .white
        pauseBg.addChild(pauseIcon)
        uiNode.addChild(pauseBg)
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
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = "Achievement Unlocked!"
        titleLabel.fontSize = 16
        titleLabel.fontColor = .yellow
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -(size.width / 2) + 100, y: 12)
        titleLabel.name = "achievementTitle"
        achievementCard.addChild(titleLabel)
        
        // Achievement name label
        let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameLabel.text = ""
        nameLabel.fontSize = 18
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
               
               let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
               lbl.text = text
               lbl.fontSize = 14
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
        pads.removeAll()
        enemies.removeAll()
        coins.removeAll()
        crocodiles.removeAll()
        treasureChests.removeAll()
        snakes.removeAll()
        ridingCrocodile = nil
        trajectoryNode.path = nil
        slingshotNode.path = nil
        slingshotDot.isHidden = true
        crosshairNode.isHidden = true
        
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
        SoundManager.shared.playMusic(.gameplay)
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
        
        collisionManager.update(frog: frog, pads: pads, enemies: enemies, coins: coins, crocodiles: crocodiles, treasureChests: treasureChests, snakes: snakes)
        updateWeather(dt: dt)
        updateWaterVisuals()
        
        if frog.rocketState == .landing {
            descendBg.isHidden = false
            let s = 1.0 + sin(currentTime * 5) * 0.05
            descendBg.setScale(s)
        } else {
            descendBg.isHidden = true
        }
        
        // Handle rocket music transitions
        if previousRocketState != .none && frog.rocketState == .none {
            SoundManager.shared.playMusic(.gameplay)
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
    
    private func updateWeather(dt: TimeInterval) {
        weatherTimer += dt
        if weatherTimer >= weatherDuration {
            weatherTimer = 0
            advanceWeather()
        }
        if let currentColor = self.backgroundColor.cgColor.components,
           let targetColor = getTargetColor().cgColor.components {
            let lerp: CGFloat = 0.01
            let r = currentColor[0] + (targetColor[0] - currentColor[0]) * lerp
            let g = currentColor[1] + (targetColor[1] - currentColor[1]) * lerp
            let b = currentColor[2] + (targetColor[2] - currentColor[2]) * lerp
            self.backgroundColor = UIColor(red: r, green: g, blue: b, alpha: 1.0)
        }
    }
    private func advanceWeather() {
        let all = WeatherType.allCases
        guard let idx = all.firstIndex(of: currentWeather) else { return }
        let nextIdx = (idx + 1) % all.count
        setWeather(all[nextIdx], duration: 1.0)
    }
    private func setWeather(_ type: WeatherType, duration: TimeInterval) {
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
            weatherNode.addChild(flies)
            SoundManager.shared.playWeatherSFX(.night)
        case .sunny:
            SoundManager.shared.playWeatherSFX(nil)
        }
        for pad in pads { pad.updateColor(weather: type) }
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
        spawnDrowningRipples(at: frog.position)
        
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
                self.coordinator?.gameDidEnd(score: self.score, coins: self.coinsCollectedThisRun)
            }
            self.run(SKAction.sequence([delay, showGameOver]))
        }
    }
    
    /// Creates expanding concentric ripples at the drowning location
    private func spawnDrowningRipples(at position: CGPoint) {
        let rippleCount = 4
        let delayBetweenRipples: TimeInterval = 0.15
        
        for i in 0..<rippleCount {
            let ripple = SKShapeNode(circleOfRadius: 20)
            ripple.strokeColor = SKColor.white.withAlphaComponent(0.8)
            ripple.fillColor = .clear
            ripple.lineWidth = 3
            ripple.position = position
            ripple.zPosition = Layer.frog - 1
            worldNode.addChild(ripple)
            
            let delay = SKAction.wait(forDuration: delayBetweenRipples * Double(i))
            let expand = SKAction.scale(to: 4.0 + CGFloat(i) * 0.5, duration: 0.8)
            expand.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.8)
            let expandAndFade = SKAction.group([expand, fade])
            let remove = SKAction.removeFromParent()
            
            ripple.run(SKAction.sequence([delay, expandAndFade, remove]))
        }
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
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.heavy)
        frog.currentHealth -= 1
        drawHearts()
        frog.hit()
        if frog.currentHealth <= 0 {
            isGameEnding = true
            reportChallengeProgress()
            coordinator?.gameDidEnd(score: score, coins: coinsCollectedThisRun)
        } else {
            frog.velocity.dx *= -0.7
            frog.velocity.dy *= -0.7
        }
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
        SoundManager.shared.play("hit")
        HapticsManager.shared.playImpact(.heavy)
        frog.currentHealth -= 1
        drawHearts()
        frog.hit()
        if frog.currentHealth <= 0 {
            isGameEnding = true
            reportChallengeProgress()
            coordinator?.gameDidEnd(score: score, coins: coinsCollectedThisRun)
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
        let rewardLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        rewardLabel.text = "\(reward.icon) \(reward.displayName)"
        rewardLabel.fontSize = 24
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
        SoundManager.shared.playMusic(.gameplay)
        
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
            SoundManager.shared.playMusic(.gameplay)
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
            simVel.dy *= superJumpMultiplier
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
