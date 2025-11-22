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
    
    // Visuals
    private let slingshotNode = SKShapeNode()
    private let slingshotDot = SKShapeNode(circleOfRadius: 8)
    private let crosshairNode = SKShapeNode(circleOfRadius: 10)
    
    private let weatherNode = SKNode()
    private let waterLinesNode = SKNode()
    
    // MARK: - HUD Elements
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let coinLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var heartNodes: [SKShapeNode] = []
    private let buffsNode = SKNode()
    private let descendButton = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let descendBg = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 30)
    private let pauseBg = SKShapeNode(circleOfRadius: 25)
    
    private let hudMargin: CGFloat = 20.0
    
    // MARK: - Entities
    private let frog = Frog()
    private var pads: [Pad] = []
    private var enemies: [Enemy] = []
    private var coins: [Coin] = []
    
    // MARK: - State
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var isDragging = false
    private var lastUpdateTime: TimeInterval = 0
    private var score: Int = 0
    private var totalCoins: Int = 0
    private var coinsCollectedThisRun: Int = 0
    private var isGameEnding: Bool = false
    
    private var currentWeather: WeatherType = .sunny
    private var weatherTimer: TimeInterval = 0
    private let weatherDuration: TimeInterval = 30.0
    private var waterOffset: CGFloat = 0.0
    
    // MARK: - Lifecycle
    
    override func didMove(to view: SKView) {
        setupScene()
        setupHUD()
        setupInput()
        collisionManager.delegate = self
        startGame()
        if let starter = initialUpgrade { applyUpgrade(id: starter) }
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpgrade(_:)), name: .didSelectUpgrade, object: nil)
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
        
        // Trajectory Setup
        trajectoryNode.strokeColor = .white.withAlphaComponent(0.7)
        trajectoryNode.lineWidth = 4
        trajectoryNode.lineCap = .round
        trajectoryNode.zPosition = Layer.trajectory
        worldNode.addChild(trajectoryNode)
        
        // Slingshot Visuals
        slingshotNode.strokeColor = .yellow
        slingshotNode.lineWidth = 3
        slingshotNode.zPosition = Layer.frog + 1
        worldNode.addChild(slingshotNode)
        
        slingshotDot.fillColor = .yellow
        slingshotDot.strokeColor = .white
        slingshotDot.lineWidth = 2
        slingshotDot.zPosition = Layer.frog + 2
        slingshotDot.isHidden = true
        worldNode.addChild(slingshotDot)
        
        // Crosshair
        crosshairNode.strokeColor = .red
        crosshairNode.lineWidth = 3
        crosshairNode.fillColor = .clear
        crosshairNode.zPosition = Layer.trajectory + 1
        
        let vLine = SKShapeNode(rectOf: CGSize(width: 2, height: 20))
        vLine.fillColor = .red
        vLine.strokeColor = .clear
        crosshairNode.addChild(vLine)
        let hLine = SKShapeNode(rectOf: CGSize(width: 20, height: 2))
        hLine.fillColor = .red
        hLine.strokeColor = .clear
        crosshairNode.addChild(hLine)
        
        crosshairNode.isHidden = true
        worldNode.addChild(crosshairNode)
    }
    
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
        
        coinLabel.text = "🪙 0"
        coinLabel.fontSize = 24
        coinLabel.fontColor = .yellow
        coinLabel.horizontalAlignmentMode = .right
        coinLabel.position = CGPoint(x: (size.width / 2) - hudMargin, y: (size.height / 2) - 100)
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
    
    private func drawHearts() {
        heartNodes.forEach { $0.removeFromParent() }
        heartNodes.removeAll()
        
        let startX = -(size.width / 2) + hudMargin + 15
        let yPos = (size.height / 2) - 100
        
        for i in 0..<frog.maxHealth {
            let heart = SKShapeNode(circleOfRadius: 12)
            heart.position = CGPoint(x: startX + (CGFloat(i) * 30), y: yPos)
            
            if i < frog.currentHealth {
                heart.fillColor = .red
                heart.strokeColor = .white
                heart.alpha = 1.0
            } else {
                heart.fillColor = .black
                heart.strokeColor = .white
                heart.alpha = 0.3
            }
            heart.lineWidth = 2
            uiNode.addChild(heart)
            heartNodes.append(heart)
        }
    }
    
    private func updateBuffsHUD() {
        buffsNode.removeAllChildren()
        var yOffset: CGFloat = 0
        
        func addBuffLabel(text: String, color: UIColor) {
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
        
        if frog.buffs.vest > 0 { addBuffLabel(text: "🦺 VEST x\(frog.buffs.vest)", color: .orange) }
        if frog.buffs.honey > 0 { addBuffLabel(text: "🍯 HONEY x\(frog.buffs.honey)", color: .yellow) }
        
        if frog.buffs.axe > 0 { addBuffLabel(text: "🪓 AXE x\(frog.buffs.axe)", color: .brown) }
        if frog.buffs.swatter > 0 { addBuffLabel(text: "🏸 SWAT x\(frog.buffs.swatter)", color: .green) }
        if frog.buffs.cross > 0 { addBuffLabel(text: "✝️ CROSS x\(frog.buffs.cross)", color: .white) }
        
        if frog.rocketTimer > 0 {
            let sec = frog.rocketTimer / 60
            addBuffLabel(text: "🚀 \(sec)s", color: .red)
        } else if frog.rocketState == .landing {
             addBuffLabel(text: "⚠ DESCEND", color: .red)
        }
        
        if frog.buffs.bootsCount > 0 {
            let label = frog.isWearingBoots ? "👢 ACTIVE" : "👢 x\(frog.buffs.bootsCount)"
            let color: UIColor = frog.isWearingBoots ? .green : .blue
            addBuffLabel(text: label, color: color)
        }
    }
    
    private func updateHUDVisuals() {
        let currentScore = Int(frog.position.y / 10)
        if currentScore > score {
            score = currentScore
            scoreLabel.text = "\(score)m"
        }
        coinLabel.text = "🪙 \(totalCoins)"
        updateBuffsHUD()
    }
    
    private func startGame() {
        isGameEnding = false
        pads.forEach { $0.removeFromParent() }
        enemies.forEach { $0.removeFromParent() }
        coins.forEach { $0.removeFromParent() }
        pads.removeAll()
        enemies.removeAll()
        coins.removeAll()
        trajectoryNode.path = nil
        slingshotNode.path = nil
        slingshotDot.isHidden = true
        crosshairNode.isHidden = true
        
        frog.canJumpLogs = PersistenceManager.shared.hasLogJumper
        
        frog.position = CGPoint(x: Configuration.Dimensions.riverWidth / 2, y: 0)
        frog.zHeight = 0
        frog.velocity = .zero
        frog.maxHealth = 2 + PersistenceManager.shared.healthLevel
        frog.currentHealth = frog.maxHealth
        frog.rocketState = .none
        frog.buffs = Frog.Buffs()
        frog.isFloating = false
        frog.isWearingBoots = false
        frog.rocketTimer = 0
        frog.resetPullOffset()
        
        worldNode.addChild(frog)
        coinsCollectedThisRun = 0
        spawnInitialPads()
        drawHearts()
        updateBuffsHUD()
        descendBg.isHidden = true
        
        setWeather(.sunny, duration: 0.0)
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
        
        collisionManager.update(frog: frog, pads: pads, enemies: enemies, coins: coins)
        
        updateWeather(dt: dt)
        updateWaterVisuals()
        
        if frog.rocketState == .landing {
            descendBg.isHidden = false
            let s = 1.0 + sin(currentTime * 5) * 0.05
            descendBg.setScale(s)
        } else {
            descendBg.isHidden = true
        }
        
        updateCamera()
        updateHUDVisuals()
        
        if let lastPad = pads.last, lastPad.position.y < cam.position.y + size.height {
            generateNextLevelSlice(lastPad: lastPad)
        }
        cleanupOffscreenEntities()
    }
    
    // MARK: - Weather Logic
    
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
        case .winter:
            let snow = VFXManager.shared.createSnowEmitter(width: w)
            snow.position = pos
            weatherNode.addChild(snow)
        case .night:
            let flies = VFXManager.shared.createFirefliesEmitter(width: w, height: h)
            flies.position = .zero
            weatherNode.addChild(flies)
        case .sunny:
            break
        }
        
        for pad in pads {
            pad.updateColor(weather: type)
        }
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
    }
    
    private func generateNextLevelSlice(lastPad: Pad) {
        var newY: CGFloat = 0
        var newX: CGFloat = 0
        var dist: CGFloat = 0
        let minDistance: CGFloat = 120.0
        
        var attempts = 0
        repeat {
            let distY = CGFloat.random(in: 80...140)
            newY = lastPad.position.y + distY
            
            let maxDeviationX: CGFloat = 150
            let minX = max(Configuration.Dimensions.frogRadius * 2, lastPad.position.x - maxDeviationX)
            let maxX = min(Configuration.Dimensions.riverWidth - (Configuration.Dimensions.frogRadius * 2), lastPad.position.x + maxDeviationX)
            newX = CGFloat.random(in: minX...maxX)
            
            let dx = newX - lastPad.position.x
            let dy = newY - lastPad.position.y
            dist = sqrt(dx*dx + dy*dy)
            attempts += 1
            if attempts > 15 { break }
        } while dist < minDistance
        
        var type: Pad.PadType = .normal
        let scoreVal = Int(frog.position.y / 10)
        
        // FIX: Do NOT set 'type' to .log in the primary pad chain
        // This ensures the main path is always landable
        
        if scoreVal > 500 && Double.random(in: 0...1) < 0.2 {
            type = .moving
        } else if scoreVal > 1000 && Double.random(in: 0...1) < 0.1 {
            type = .ice
        }
        
        if scoreVal > 150 && Double.random(in: 0...1) < 0.15 {
            type = .waterLily
        }
        
        if currentWeather == .night && Double.random(in: 0...1) < 0.15 { type = .grave }
        
        let shrinkingChance = min(0.4, Double(scoreVal) / 5000.0)
        if Double.random(in: 0...1) < shrinkingChance {
            type = .shrinking
        }
        
        let pad = Pad(type: type, position: CGPoint(x: newX, y: newY))
        pad.updateColor(weather: currentWeather)
        worldNode.addChild(pad)
        pads.append(pad)
        
        if type == .grave {
            let ghost = Enemy(position: CGPoint(x: newX, y: newY + 40), type: "GHOST")
            worldNode.addChild(ghost)
            enemies.append(ghost)
        }
        
        // FIX: Spawn logs as SEPARATE Obstacles
        if scoreVal > 200 && Double.random(in: 0...1) < 0.25 {
            let logX = CGFloat.random(in: 100...500)
            // Ensure log doesn't overlap the safe pad
            if abs(logX - newX) > 120 {
                let log = Pad(type: .log, position: CGPoint(x: logX, y: newY))
                worldNode.addChild(log)
                pads.append(log)
            }
        }
        
        if Double.random(in: 0...1) < 0.3 {
            let coin = Coin(position: pad.position)
            coin.zHeight = 20
            worldNode.addChild(coin)
            coins.append(coin)
        }
        
        let enemyProb = 0.2 + (Double(scoreVal) / 5000.0)
        if Double.random(in: 0...1) < enemyProb {
            if type != .grave {
                let enemyType = (scoreVal > 400 && Double.random(in: 0...1) < 0.4) ? "DRAGONFLY" : "BEE"
                let ex = CGFloat.random(in: 50...550)
                let enemy = Enemy(position: CGPoint(x: ex, y: newY + 50), type: enemyType)
                worldNode.addChild(enemy)
                enemies.append(enemy)
            }
        }
    }
    
    // MARK: - Collision Delegate
    
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
        frog.land(on: pad, weather: currentWeather)
        HapticsManager.shared.playImpact(.light)
    }
    
    func didFallIntoWater() {
        guard !isGameEnding else { return }
        if frog.isFloating { return }
        
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
            coordinator?.gameDidEnd(score: score, coins: coinsCollectedThisRun)
        } else {
            frog.bounce()
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
            updateBuffsHUD()
            return
        }
        
        if enemy.type == "GHOST" && frog.buffs.cross > 0 {
            frog.buffs.cross -= 1
            enemy.removeFromParent()
            if let idx = enemies.firstIndex(of: enemy) { enemies.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
            updateBuffsHUD()
            return
        }
        
        if enemy.type == "BEE" && frog.buffs.honey > 0 {
            frog.buffs.honey -= 1
            enemy.removeFromParent()
            if let idx = enemies.firstIndex(of: enemy) { enemies.remove(at: idx) }
            HapticsManager.shared.playNotification(.success)
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
            coordinator?.gameDidEnd(score: score, coins: coinsCollectedThisRun)
        } else {
            frog.velocity.dx *= -1
            frog.velocity.dy *= -1
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
        
        if coinsCollectedThisRun > 0 && coinsCollectedThisRun % Configuration.GameRules.coinsForUpgradeTrigger == 0 {
            let wait = SKAction.wait(forDuration: 0.2)
            let trigger = SKAction.run { [weak self] in self?.coordinator?.triggerUpgradeMenu() }
            run(SKAction.sequence([wait, trigger]))
        }
    }
    
    // MARK: - Input
    
    private func setupInput() {
        isUserInteractionEnabled = true
    }
    
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
        
        if frog.zHeight <= 0.1 {
            isDragging = true
            dragStart = location
            dragCurrent = location
            updateTrajectoryVisuals()
        }
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
        
        guard isDragging, let start = dragStart, let current = dragCurrent else { return }
        isDragging = false
        
        let dx = start.x - current.x
        let dy = start.y - current.y
        let dist = sqrt(dx*dx + dy*dy)
        
        if dist < 10 { return }
        
        let maxDist = Configuration.Physics.maxDragDistance
        let ratio = min(dist, maxDist) / maxDist
        let power = Configuration.Physics.dragPower(level: PersistenceManager.shared.jumpLevel)
        let launchVector = CGVector(dx: dx * power, dy: dy * power)
        
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
        guard let start = dragStart, let current = dragCurrent else { return }
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
        let launchVector = CGVector(dx: dx * power, dy: dy * power)
        
        // Visual Offset
        let dragVector = CGPoint(x: current.x - start.x, y: current.y - start.y)
        frog.setPullOffset(dragVector)
        
        // Slingshot UI
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
        let slingPath = CGMutablePath()
        slingPath.move(to: frog.position)
        slingPath.addLine(to: dotPos)
        slingshotNode.path = slingPath
        
        // Trajectory
        var simPos = frog.position
        var simVel = launchVector
        var simZ = frog.zHeight
        var simZVel = Configuration.Physics.baseJumpZ * (0.5 + (ratio * 0.5))
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: simPos.x, y: simPos.y + simZ))
        for _ in 0..<60 {
            simPos.x += simVel.dx
            simPos.y += simVel.dy
            simZ += simZVel
            simZVel -= Configuration.Physics.gravityZ
            simVel.dx *= Configuration.Physics.frictionAir
            simVel.dy *= Configuration.Physics.frictionAir
            let visualPoint = CGPoint(x: simPos.x, y: simPos.y + simZ)
            path.addLine(to: visualPoint)
            if simZ <= 0 { break }
        }
        trajectoryNode.path = path
        crosshairNode.isHidden = false
        crosshairNode.position = path.currentPoint
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
        default: break
        }
    }
}
