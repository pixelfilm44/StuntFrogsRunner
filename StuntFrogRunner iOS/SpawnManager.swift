//
//  SpawnManager.swift (UPDATED)
//  Tadpoles now track their lily pads
//

import SpriteKit

class SpawnManager {
    weak var scene: SKScene?
    weak var worldNode: SKNode?
    
    private var framesSinceLastPathCheck = 0
    private let pathCheckInterval = 20
    
    private var graceEndTime: TimeInterval = 0

    // MARK: - Lily Pad Factory
    private func makeLilyPad(position: CGPoint, radius: CGFloat) -> LilyPad {
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        let type: LilyPadType
        if currentScore < 2000 {
            type = .normal
        } else {
            let r = CGFloat.random(in: 0...1)
            if r < 0.6 { type = .normal }
            else if r < 0.8 { type = .pulsing }
            else { type = .moving }
        }
        let pad = LilyPad(position: position, radius: radius, type: type)
        if type == .moving {
            pad.movementSpeed = 120.0
            pad.refreshMovement()
        }
        return pad
    }
    
    init(scene: SKScene, worldNode: SKNode) {
        self.scene = scene
        self.worldNode = worldNode
    }
    
    func startGracePeriod(duration: TimeInterval) {
        graceEndTime = CACurrentMediaTime() + duration
    }
    
    // MARK: - Helper Functions
    
    private func findFurthestPadAhead(from frogPosition: CGPoint, in pads: [LilyPad]) -> LilyPad? {
        var furthest: LilyPad? = nil
        var maxY: CGFloat = frogPosition.y
        
        for pad in pads {
            if pad.position.y > maxY {
                maxY = pad.position.y
                furthest = pad
            }
        }
        
        return furthest
    }
    
    private func isTooCloseToExisting(position: CGPoint, lilyPads: [LilyPad], minDistance: CGFloat = 100) -> Bool {
        for pad in lilyPads {
            let dx = position.x - pad.position.x
            let dy = position.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < minDistance {
                return true
            }
        }
        return false
    }
    
    private func createReachablePad(from position: CGPoint, targetY: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, tadpoles: inout [Tadpole], forceCreate: Bool = false) {
        let maxDist = GameConfig.maxRegularJumpDistance * 0.65
        let minDist: CGFloat = 100
        
        var bestCandidate: CGPoint? = nil
        var bestDistance: CGFloat = 0
        
        for attempt in 0..<40 {
            let xVariation = CGFloat.random(in: -120...120)
            let x = max(80, min(sceneSize.width - 80, position.x + xVariation))
            let candidate = CGPoint(x: x, y: targetY)
            
            let dx = candidate.x - position.x
            let dy = candidate.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance > minDist && distance < maxDist && dy > 0 {
                if forceCreate || !isTooCloseToExisting(position: candidate, lilyPads: lilyPads, minDistance: 80) {
                    let pad = makeLilyPad(
                        position: candidate,
                        radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
                    )
                    pad.node.position = pad.position
                    pad.node.zPosition = 10
                    worldNode.addChild(pad.node)
                    lilyPads.append(pad)
                    
                    // UPDATED: Associate tadpole with lily pad
                    if CGFloat.random(in: 0...1) < 0.5 {
                        let tadpole = Tadpole(position: pad.position)
                        tadpole.lilyPad = pad  // NEW: Set lily pad reference
                        tadpole.node.position = pad.position
                        tadpole.node.zPosition = 50
                        worldNode.addChild(tadpole.node)
                        tadpoles.append(tadpole)
                    }
                    
                    return
                }
                
                if distance > bestDistance {
                    bestDistance = distance
                    bestCandidate = candidate
                }
            }
        }
        
        let finalPosition = bestCandidate ?? CGPoint(
            x: max(80, min(sceneSize.width - 80, position.x + CGFloat.random(in: -100...100))),
            y: targetY
        )
        
        print("âš ï¸ Using fallback position for lily pad at \(finalPosition)")
        
        let pad = makeLilyPad(
            position: finalPosition,
            radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
        )
        pad.node.position = pad.position
        pad.node.zPosition = 10
        worldNode.addChild(pad.node)
        lilyPads.append(pad)
        
        // UPDATED: Associate tadpole with lily pad
        if CGFloat.random(in: 0...1) < 0.5 {
            let tadpole = Tadpole(position: pad.position)
            tadpole.lilyPad = pad  // NEW: Set lily pad reference
            tadpole.node.position = pad.position
            tadpole.node.zPosition = 50
            worldNode.addChild(tadpole.node)
            tadpoles.append(tadpole)
        }
    }
    
    // MARK: - Initial Spawn
    
    func spawnInitialObjects(sceneSize: CGSize, lilyPads: inout [LilyPad], enemies: inout [Enemy], tadpoles: inout [Tadpole], worldOffset: CGFloat) {
        guard let worldNode = worldNode else { return }
        
        var lastPosition = CGPoint(x: sceneSize.width / 2, y: -worldOffset + sceneSize.height * 0.3)
        
        for i in 1..<20 {
            let targetY = lastPosition.y + CGFloat.random(in: 140...180)
            
            let maxDist = GameConfig.maxRegularJumpDistance * 0.65
            var bestCandidate: CGPoint? = nil
            
            for attempt in 0..<50 {
                let x = CGFloat.random(in: 80...sceneSize.width - 80)
                let candidate = CGPoint(x: x, y: targetY)
                
                let dx = candidate.x - lastPosition.x
                let dy = candidate.y - lastPosition.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance < maxDist && distance > 100 {
                    bestCandidate = candidate
                    break
                }
            }
            
            let finalPosition = bestCandidate ?? CGPoint(
                x: lastPosition.x + CGFloat.random(in: -120...120),
                y: targetY
            )
            
            let pad = makeLilyPad(
                position: finalPosition,
                radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
            )
            pad.node.position = pad.position
            pad.node.zPosition = 10
            worldNode.addChild(pad.node)
            lilyPads.append(pad)
            lastPosition = finalPosition
        }
        
        print("ðŸŒ¿ Spawned \(lilyPads.count) initial lily pads")
    }
    
    // MARK: - Continuous Spawn
    
    func spawnObjects(sceneSize: CGSize, lilyPads: inout [LilyPad], enemies: inout [Enemy], tadpoles: inout [Tadpole], worldOffset: CGFloat, frogPosition: CGPoint, superJumpActive: Bool) {
        guard let worldNode = worldNode else { return }
        
        let maxRegular = GameConfig.maxRegularJumpDistance * 0.65
        let desiredPadsAhead = superJumpActive ? 10 : 6
        let maxGapAhead: CGFloat = maxRegular * 0.95

        let padsAheadList = lilyPads.filter { $0.position.y > frogPosition.y }.sorted { $0.position.y < $1.position.y }
        let furthestAhead = padsAheadList.last

        var anchor = furthestAhead?.position ?? frogPosition

        var padsToEnsure = max(0, desiredPadsAhead - padsAheadList.count)

        if let furthest = furthestAhead {
            let dist = furthest.position.y - frogPosition.y
            if superJumpActive && dist < maxRegular * 3.0 {
                padsToEnsure += 3
            }
        } else {
            padsToEnsure = max(padsToEnsure, superJumpActive ? 12 : 8)
        }

        for _ in 0..<padsToEnsure {
            let safeMaxSpacing = max(120, min(maxGapAhead * 0.8, 180))
            let targetY = anchor.y + CGFloat.random(in: 120...safeMaxSpacing)
            createReachablePad(from: anchor, targetY: targetY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles)
            if let newPad = lilyPads.last { anchor = newPad.position }
        }

        let recentPads = lilyPads.filter { $0.position.y >= frogPosition.y - 50 }.sorted { $0.position.y < $1.position.y }
        if recentPads.count >= 2 {
            var prev = recentPads.first!.position
            for pad in recentPads.dropFirst() {
                let dy = pad.position.y - prev.y
                if dy > maxGapAhead {
                    var currentAnchor = prev
                    while (pad.position.y - currentAnchor.y) > maxGapAhead {
                        let safeMaxSpacing = max(120, min(maxGapAhead * 0.8, 180))
                        let nextY = currentAnchor.y + CGFloat.random(in: 120...safeMaxSpacing)
                        createReachablePad(from: currentAnchor, targetY: nextY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles)
                        if let newPad = lilyPads.last { currentAnchor = newPad.position } else { break }
                    }
                }
                prev = pad.position
            }
        }
        
        let spawnWorldY = -worldOffset + sceneSize.height + 100
        
        let inGrace = CACurrentMediaTime() < graceEndTime
        
        // Get current score and calculate dynamic spawn rate
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        let spawnRateMultiplier = getSpawnRateMultiplier(currentScore: currentScore)
        let dynamicEnemySpawnRate = GameConfig.enemySpawnRate * spawnRateMultiplier
        
        // Spawn enemies with score-based population density
        if !inGrace && CGFloat.random(in: 0...1) < dynamicEnemySpawnRate {
            spawnEnemy(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode, lilyPads: lilyPads)
        }
        
        // Only spawn logs when score is above 15000, with increased spawn rate
        let dynamicLogSpawnRate = GameConfig.logSpawnRate * spawnRateMultiplier
        if !inGrace && currentScore > 15000 && CGFloat.random(in: 0...1) < dynamicLogSpawnRate {
            spawnLog(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode)
        }
        
        if CGFloat.random(in: 0...1) < GameConfig.tadpoleSpawnRate {
            spawnTadpole(at: spawnWorldY, sceneSize: sceneSize, lilyPads: lilyPads, tadpoles: &tadpoles, worldNode: worldNode)
        }
    }
    
    // MARK: - Individual Spawners
    
    /// Calculate spawn rate multiplier based on current score to increase enemy population over time
    private func getSpawnRateMultiplier(currentScore: Int) -> CGFloat {
        if currentScore < 4000 {
            // Early game: Baseline spawn rate (only bees)
            return 1.0
        } else if currentScore < 10000 {
            // Mid-early: Moderate increase (bees + dragonflies)
            return 1.4
        } else if currentScore < 15000 {
            // Mid-late: Significant increase (bees + dragonflies + snakes)
            return 1.8
        } else {
            // Late game: Maximum population density (all enemies + logs)
            return 2.2
        }
    }
    
    private func findSuitableLilyPad(for enemyType: EnemyType, near worldY: CGFloat, sceneSize: CGSize, lilyPads: [LilyPad]) -> LilyPad? {
        let nearbyPads = lilyPads.filter { pad in
            let yDist = abs(pad.position.y - worldY)
            let xOk = pad.position.x > 80 && pad.position.x < sceneSize.width - 80
            return yDist < 200 && xOk
        }
        
        let suitablePads = nearbyPads.filter { pad in
            pad.canAccommodateEnemyType(enemyType)
        }
        
        return suitablePads.randomElement()
    }
    
    private func spawnEnemy(at worldY: CGFloat, sceneSize: CGSize, enemies: inout [Enemy], worldNode: SKNode, lilyPads: [LilyPad]) {
        // Get current score from the game scene
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        
        // Determine which enemy types are allowed based on score
        var allowedTypes: [EnemyType] = []
        
        if currentScore < 4000 {
            // Score < 4000: Only bees
            allowedTypes = [.bee]
        } else if currentScore < 10000 {
            // Score 4000-10000: Bees and dragonflies
            allowedTypes = [.bee, .dragonfly]
        } else if currentScore < 15000 {
            // Score 10000-15000: Bees, dragonflies, and snakes
            allowedTypes = [.bee, .dragonfly, .snake]
        } else {
            // Score > 15000: All enemy types
            allowedTypes = [.bee, .dragonfly, .snake]
        }
        
        // Randomly select an enemy type from the allowed types
        guard let selectedType = allowedTypes.randomElement() else { return }
        
        let enemy: Enemy
        
        // Spawn the selected enemy type with appropriate behavior
        switch selectedType {
        case .snake:
            if let targetPad = findSuitableLilyPad(for: selectedType, near: worldY, sceneSize: sceneSize, lilyPads: lilyPads) {
                let fromLeft = targetPad.position.x < sceneSize.width / 2
                enemy = Enemy(
                    type: selectedType,
                    position: CGPoint(
                        x: fromLeft ? -30 : sceneSize.width + 30,
                        y: targetPad.position.y
                    ),
                    speed: fromLeft ? GameConfig.snakeSpeed : -GameConfig.snakeSpeed
                )
                enemy.targetLilyPad = targetPad
                targetPad.addEnemyType(selectedType)
            } else {
                let fromLeft = Bool.random()
                enemy = Enemy(
                    type: selectedType,
                    position: CGPoint(
                        x: fromLeft ? -30 : sceneSize.width + 30,
                        y: worldY
                    ),
                    speed: fromLeft ? GameConfig.snakeSpeed : -GameConfig.snakeSpeed
                )
            }
            
        case .bee:
            if let targetPad = findSuitableLilyPad(for: selectedType, near: worldY, sceneSize: sceneSize, lilyPads: lilyPads) {
                enemy = Enemy(
                    type: selectedType,
                    position: targetPad.position,
                    speed: GameConfig.beeSpeed
                )
                enemy.targetLilyPad = targetPad
                targetPad.addEnemyType(selectedType)
            } else {
                enemy = Enemy(
                    type: selectedType,
                    position: CGPoint(
                        x: CGFloat.random(in: 60...sceneSize.width - 60),
                        y: worldY
                    ),
                    speed: GameConfig.beeSpeed
                )
            }
            
        case .dragonfly:
            enemy = Enemy(
                type: selectedType,
                position: CGPoint(
                    x: CGFloat.random(in: 60...sceneSize.width - 60),
                    y: worldY
                ),
                speed: GameConfig.dragonflySpeed
            )
            
        case .log:
            // Logs are spawned separately, not through this method
            return
        }
        
        enemy.node.position = enemy.position
        enemy.node.zPosition = 50
        worldNode.addChild(enemy.node)
        enemies.append(enemy)
    }
    
    private func spawnTadpole(at worldY: CGFloat, sceneSize: CGSize, lilyPads: [LilyPad], tadpoles: inout [Tadpole], worldNode: SKNode) {
        // Find pads near the spawn Y, within horizontal bounds
        let nearbyPads = lilyPads.filter { pad in
            let yDist = abs(pad.position.y - worldY)
            let xOk = pad.position.x > 80 && pad.position.x < sceneSize.width - 80
            return yDist < 150 && xOk
        }

        // Avoid clustering: skip pads too close (vertically) to recently spawned stars
        let recent = tadpoles.suffix(10)
        let minVerticalSeparation: CGFloat = 120
        let candidates = nearbyPads.filter { pad in
            for t in recent {
                if abs(t.position.y - pad.position.y) < minVerticalSeparation {
                    return false
                }
            }
            return true
        }

        guard let pad = (candidates.randomElement() ?? nearbyPads.randomElement() ?? lilyPads.suffix(10).randomElement()) else {
            return
        }

        let tadpole = Tadpole(position: pad.position)
        tadpole.lilyPad = pad
        tadpole.node.position = pad.position
        tadpole.node.zPosition = 50
        worldNode.addChild(tadpole.node)
        tadpoles.append(tadpole)
    }
    
    private func spawnLog(at worldY: CGFloat, sceneSize: CGSize, enemies: inout [Enemy], worldNode: SKNode) {
        let fromLeft = Bool.random()
        let log = Enemy(
            type: .log,
            position: CGPoint(
                x: fromLeft ? -GameConfig.logWidth : sceneSize.width + GameConfig.logWidth,
                y: worldY
            ),
            speed: fromLeft ? GameConfig.logSpeed : -GameConfig.logSpeed
        )
        log.node.position = log.position
        log.node.zPosition = 50
        worldNode.addChild(log.node)
        enemies.append(log)
    }
}
