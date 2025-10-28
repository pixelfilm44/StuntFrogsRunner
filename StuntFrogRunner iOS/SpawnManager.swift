//
//  SpawnManager.swift (UPDATED)
//  Enhanced lily pad path validation and tadpole distribution
//

import SpriteKit

class SpawnManager {
    weak var scene: SKScene?
    weak var worldNode: SKNode?
    
    private var framesSinceLastPathCheck = 0
    private let pathCheckInterval = 10  // IMPROVED: Check more frequently
    
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
        let maxDist = GameConfig.maxRegularJumpDistance * 0.8  // Slightly more generous reach
        let minDist: CGFloat = 100
        
        var bestCandidate: CGPoint? = nil
        var bestDistance: CGFloat = 0
        
        for attempt in 0..<40 {
            let xVariation = CGFloat.random(in: -120...120)
            let x = max(90, min(sceneSize.width - 90, position.x + xVariation))
            let candidate = CGPoint(x: x, y: targetY)
            
            let dx = candidate.x - position.x
            let dy = candidate.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance > minDist && distance < maxDist && dy > 0 {
                if forceCreate || !isTooCloseToExisting(position: candidate, lilyPads: lilyPads, minDistance: 85) {
                    let pad = makeLilyPad(
                        position: candidate,
                        radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
                    )
                    pad.node.position = pad.position
                    pad.node.zPosition = 10
                    worldNode.addChild(pad.node)
                    lilyPads.append(pad)
                    
                    // Independent tadpole spawner handles tadpole placement
                    return
                }
                
                if distance > bestDistance {
                    bestDistance = distance
                    bestCandidate = candidate
                }
            }
        }
        
        // Fallback: create pad at best available position or forced position
        let finalPosition = bestCandidate ?? CGPoint(
            x: max(90, min(sceneSize.width - 90, position.x + CGFloat.random(in: -80...80))),
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
    }
    
    // MARK: - Initial Spawn
    
    func spawnInitialObjects(sceneSize: CGSize, lilyPads: inout [LilyPad], enemies: inout [Enemy], tadpoles: inout [Tadpole], worldOffset: CGFloat) {
        guard let worldNode = worldNode else { return }
        
        var lastPosition = CGPoint(x: sceneSize.width / 2, y: -worldOffset + sceneSize.height * 0.3)
        
        // IMPROVED: Spawn even more initial lily pads (40 instead of 30) for abundant starting coverage
        for i in 1..<40 {
            let targetY = lastPosition.y + CGFloat.random(in: 130...170)
            
            let maxDist = GameConfig.maxRegularJumpDistance * 0.8
            var bestCandidate: CGPoint? = nil
            
            for attempt in 0..<50 {
                let x = CGFloat.random(in: 100...sceneSize.width - 100)
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
        
        print("🎮 Spawned \(lilyPads.count) initial lily pads for abundant coverage")
    }
    
    // MARK: - Continuous Spawn
    
    func spawnObjects(sceneSize: CGSize, lilyPads: inout [LilyPad], enemies: inout [Enemy], tadpoles: inout [Tadpole], worldOffset: CGFloat, frogPosition: CGPoint, superJumpActive: Bool) {
        guard let worldNode = worldNode else { return }
        
        // Calculate the spawn point (where new objects appear ahead of the player)
        let spawnWorldY = -worldOffset + sceneSize.height + 100
        
        // Calculate dynamic scroll speed for adaptive spawning
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        let dynamicScrollSpeed = calculateCurrentScrollSpeed(score: currentScore, superJumpActive: superJumpActive)
        
        let maxRegular = GameConfig.maxRegularJumpDistance * 0.85
        
        // CRITICAL: Much more aggressive pad counts to ensure continuous coverage
        let baseDesiredPads = superJumpActive ? 25 : 20  // Increased from 15/12
        let speedMultiplier = max(1.5, dynamicScrollSpeed / GameConfig.scrollSpeed)  // Minimum 1.5x
        let desiredPadsAhead = Int(CGFloat(baseDesiredPads) * speedMultiplier)
        
        // VERY generous lookahead - we want pads WAY ahead
        let lookaheadDistance = maxRegular * 2.0 * speedMultiplier  // Increased multiplier
        
        let padsAheadList = lilyPads.filter { $0.position.y > frogPosition.y }.sorted { $0.position.y < $1.position.y }
        let furthestAhead = padsAheadList.last
        
        // Calculate how far ahead we have coverage
        let currentCoverage = (furthestAhead?.position.y ?? frogPosition.y) - frogPosition.y
        
        // MUCH MORE AGGRESSIVE emergency spawn thresholds
        let criticalPadThreshold = max(8, desiredPadsAhead / 2)  // Trigger at 50% instead of 33%
        let criticalCoverageThreshold = lookaheadDistance * 0.5  // Trigger at 50% instead of 30%
        
        if padsAheadList.count < criticalPadThreshold || currentCoverage < criticalCoverageThreshold {
            print("⚠️ EMERGENCY SPAWN: Only \(padsAheadList.count) pads ahead, coverage: \(Int(currentCoverage))px")
            let emergencyPads = max(15, desiredPadsAhead - padsAheadList.count)  // More emergency pads
            spawnPadChain(count: emergencyPads, startingFrom: furthestAhead?.position ?? frogPosition, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, maxRegular: maxRegular)
        }
        
        // CRITICAL FIX: Always ensure pads exist at the spawn point for enemies/tadpoles
        ensurePadsAtSpawnPoint(spawnWorldY: spawnWorldY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, maxRegular: maxRegular)
        
        var anchor = furthestAhead?.position ?? frogPosition
        var padsToEnsure = max(0, desiredPadsAhead - padsAheadList.count)
        
        // Always spawn at least a few pads per frame to maintain continuous coverage
        padsToEnsure = max(padsToEnsure, 3)
        
        // Additional pads during super jump
        if superJumpActive && currentCoverage < lookaheadDistance * 0.6 {
            padsToEnsure += 8
        }
        
        // If we have NO pads ahead at all, spawn a generous initial set
        if padsAheadList.isEmpty {
            padsToEnsure = max(padsToEnsure, desiredPadsAhead + 10)
        }
        
        // Create forward pads with horizontal variation for multiple paths
        for i in 0..<padsToEnsure {
            let minSpacing: CGFloat = 125
            let maxSpacing = min(maxRegular * 0.9, 190)
            let targetY = anchor.y + CGFloat.random(in: minSpacing...maxSpacing)
            
            // Add horizontal variation to create left/center/right path options
            var targetAnchor = anchor
            if i % 3 == 0 {
                targetAnchor.x = max(100, anchor.x - CGFloat.random(in: 30...80))
            } else if i % 3 == 2 {
                targetAnchor.x = min(sceneSize.width - 100, anchor.x + CGFloat.random(in: 30...80))
            } else {
                targetAnchor.x = anchor.x + CGFloat.random(in: -40...40)
            }
            
            createReachablePad(from: targetAnchor, targetY: targetY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles)
            if let newPad = lilyPads.last {
                anchor = newPad.position
            }
        }
        
        // More frequent gap checking
        framesSinceLastPathCheck += 1
        if framesSinceLastPathCheck >= 5 {  // Check every 5 frames instead of 10
            framesSinceLastPathCheck = 0
            fillLargeGaps(frogPosition: frogPosition, maxRegular: maxRegular, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles)
        }
        
        // Spawn enemies, tadpoles, and logs
        let inGrace = CACurrentMediaTime() < graceEndTime
        
        // ALWAYS spawn enemies and tadpoles - remove spawn rate multiplier restrictions
        // This ensures bees and tadpoles appear at all score levels
        
        // Spawn enemies more frequently throughout all levels
        let enemySpawnChance = GameConfig.enemySpawnRate * 2.0  // Double the spawn rate
        if !inGrace && CGFloat.random(in: 0...1) < enemySpawnChance {
            spawnEnemy(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode, lilyPads: lilyPads)
        }
        
        // Spawn tadpoles more frequently throughout all levels
        let tadpoleSpawnChance = GameConfig.tadpoleSpawnRate * 1.5  // 50% more tadpoles
        if CGFloat.random(in: 0...1) < tadpoleSpawnChance {
            spawnTadpole(at: spawnWorldY, sceneSize: sceneSize, lilyPads: lilyPads, tadpoles: &tadpoles, worldNode: worldNode)
        }
        
        // Only spawn logs when score is above 15000
        if !inGrace && currentScore > 15000 && CGFloat.random(in: 0...1) < GameConfig.logSpawnRate {
            spawnLog(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode)
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
        // Consider pads near the target Y and within horizontal bounds
        // IMPROVED: Wider search range (400 pixels instead of 200) to find more pads
        let nearbyPads = lilyPads.filter { pad in
            let yDist = abs(pad.position.y - worldY)
            let xOk = pad.position.x > 80 && pad.position.x < sceneSize.width - 80
            return yDist < 400 && xOk  // Increased from 200 to 400
        }
        
        // IMPROVED: More lenient bee spawning - allow 2 bees per pad if needed
        let suitablePads = nearbyPads.filter { pad in
            if enemyType == .bee {
                // Count how many bees are already on this pad
                let beeCount = pad.occupyingEnemyTypes.filter { $0 == .bee }.count
                // Allow up to 2 bees per pad for better distribution
                return beeCount < 2
            } else {
                return pad.canAccommodateEnemyType(enemyType)
            }
        }
        
        // If no suitable pads with the strict rules, try again with more lenient rules
        if suitablePads.isEmpty && enemyType == .bee {
            // Just find any pad that's not completely full
            return nearbyPads.randomElement()
        }
        
        return suitablePads.randomElement()
    }
    
    private func spawnEnemy(at worldY: CGFloat, sceneSize: CGSize, enemies: inout [Enemy], worldNode: SKNode, lilyPads: [LilyPad]) {
        // Get current score from the game scene
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        
        // Determine which enemy types are allowed based on score
        // CRITICAL: Bees appear at ALL levels for continuous gameplay
        var allowedTypes: [EnemyType] = []
        
        if currentScore < 4000 {
            // Score < 4000: Only bees (60% of spawns are bees)
            allowedTypes = [.bee, .bee, .bee]  // Weight towards bees
        } else if currentScore < 10000 {
            // Score 4000-10000: Bees (60%) and dragonflies (40%)
            allowedTypes = [.bee, .bee, .bee, .dragonfly, .dragonfly]
        } else if currentScore < 15000 {
            // Score 10000-15000: Balanced mix
            allowedTypes = [.bee, .bee, .dragonfly, .dragonfly, .snake]
        } else {
            // Score > 15000: All enemy types with bee emphasis
            allowedTypes = [.bee, .bee, .dragonfly, .dragonfly, .snake, .snake]
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
            // IMPROVED: More flexible bee spawning - try harder to find a pad
            if let targetPad = findSuitableLilyPad(for: selectedType, near: worldY, sceneSize: sceneSize, lilyPads: lilyPads) {
                enemy = Enemy(
                    type: selectedType,
                    position: targetPad.position,
                    speed: GameConfig.beeSpeed
                )
                enemy.targetLilyPad = targetPad
                targetPad.addEnemyType(.bee)
            } else {
                // If no suitable pad found, spawn bee anyway at a reasonable position
                // This ensures bees always appear even if pads are temporarily limited
                enemy = Enemy(
                    type: selectedType,
                    position: CGPoint(
                        x: CGFloat.random(in: 100...sceneSize.width - 100),
                        y: worldY
                    ),
                    speed: GameConfig.beeSpeed
                )
                print("⚠️ Spawned bee without lily pad at worldY: \(Int(worldY))")
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
        // IMPROVED: Find ALL pads in a reasonable range (not just nearby)
        let suitablePads = lilyPads.filter { pad in
            let yDist = abs(pad.position.y - worldY)
            let xOk = pad.position.x > 80 && pad.position.x < sceneSize.width - 80
            // Accept pads within a much wider range for better distribution
            return yDist < 400 && xOk
        }
        
        // IMPROVED: Filter out pads that already have tadpoles to ensure even distribution
        let existingTadpolePositions = Set(tadpoles.map { "\(Int($0.position.x))_\(Int($0.position.y))" })
        let padsWithoutTadpoles = suitablePads.filter { pad in
            let posKey = "\(Int(pad.position.x))_\(Int(pad.position.y))"
            return !existingTadpolePositions.contains(posKey)
        }
        
        // IMPROVED: Prefer pads without tadpoles, but fall back to any suitable pad
        let candidates = padsWithoutTadpoles.isEmpty ? suitablePads : padsWithoutTadpoles
        
        guard let pad = candidates.randomElement() else {
            // If no suitable pad found in range, try the most recent pads
            guard let pad = lilyPads.suffix(15).randomElement() else { return }
            let posKey = "\(Int(pad.position.x))_\(Int(pad.position.y))"
            // Don't double-spawn on the same pad
            if existingTadpolePositions.contains(posKey) { return }
            
            let tadpole = Tadpole(position: pad.position)
            tadpole.lilyPad = pad
            tadpole.node.position = pad.position
            tadpole.node.zPosition = 50
            worldNode.addChild(tadpole.node)
            tadpoles.append(tadpole)
            return
        }

        // Spawn the tadpole on the selected pad
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
    
    // MARK: - Helper Methods for Improved Spawning
    
    /// CRITICAL: Ensure there are always lily pads at the spawn point where enemies/tadpoles appear
    private func ensurePadsAtSpawnPoint(spawnWorldY: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, maxRegular: CGFloat) {
        // Check how many pads exist near the spawn point
        let padsNearSpawnPoint = lilyPads.filter { pad in
            let yDist = abs(pad.position.y - spawnWorldY)
            return yDist < 300  // Within 300 pixels of spawn point
        }
        
        // We want at least 5-8 pads near the spawn point for enemies/tadpoles to use
        let minPadsAtSpawn = 5
        
        if padsNearSpawnPoint.count < minPadsAtSpawn {
            let padsToCreate = minPadsAtSpawn - padsNearSpawnPoint.count
            
            // Create pads directly at spawn height with horizontal variation
            for i in 0..<padsToCreate {
                let xPosition: CGFloat
                if i % 3 == 0 {
                    xPosition = CGFloat.random(in: 100...sceneSize.width/3)  // Left third
                } else if i % 3 == 1 {
                    xPosition = CGFloat.random(in: sceneSize.width/3...2*sceneSize.width/3)  // Middle third
                } else {
                    xPosition = CGFloat.random(in: 2*sceneSize.width/3...sceneSize.width-100)  // Right third
                }
                
                let yOffset = CGFloat.random(in: -100...100)  // Slight vertical variation
                let padPosition = CGPoint(x: xPosition, y: spawnWorldY + yOffset)
                
                // Create the pad
                let pad = makeLilyPad(
                    position: padPosition,
                    radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
                )
                pad.node.position = pad.position
                pad.node.zPosition = 10
                worldNode.addChild(pad.node)
                lilyPads.append(pad)
            }
        }
    }
    
    /// Calculate current scroll speed based on score and active abilities
    private func calculateCurrentScrollSpeed(score: Int, superJumpActive: Bool) -> CGFloat {
        // Base scroll speed increases with score
        let scoreMultiplier = CGFloat(score / GameConfig.scoreIntervalForSpeedIncrease)
        let baseSpeed = min(GameConfig.scrollSpeed + (scoreMultiplier * GameConfig.scrollSpeedIncrement), GameConfig.maxScrollSpeed)
        
        // Check if rocket is active by examining the scene
        if let gameScene = scene as? GameScene {
            if gameScene.frogController.rocketActive {
                return GameConfig.rocketScrollSpeed
            }
        }
        
        // During super jump, scroll is faster
        return superJumpActive ? GameConfig.scrollSpeedWhileJumping : baseSpeed
    }
    
    /// Spawn a chain of lily pads quickly
    private func spawnPadChain(count: Int, startingFrom position: CGPoint, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, maxRegular: CGFloat) {
        var anchor = position
        
        for i in 0..<count {
            let minSpacing: CGFloat = 130
            let maxSpacing = min(maxRegular * 0.85, 180)
            let targetY = anchor.y + CGFloat.random(in: minSpacing...maxSpacing)
            
            // Alternate between left, center, and right paths
            var targetX = anchor.x
            if i % 3 == 0 {
                targetX = max(90, anchor.x - CGFloat.random(in: 20...70))
            } else if i % 3 == 2 {
                targetX = min(sceneSize.width - 90, anchor.x + CGFloat.random(in: 20...70))
            } else {
                targetX = anchor.x + CGFloat.random(in: -30...30)
            }
            
            let finalX = max(90, min(sceneSize.width - 90, targetX))
            let padPosition = CGPoint(x: finalX, y: targetY)
            
            // Create the pad directly without complex validation (for emergency spawning)
            let pad = makeLilyPad(
                position: padPosition,
                radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
            )
            pad.node.position = pad.position
            pad.node.zPosition = 10
            worldNode.addChild(pad.node)
            lilyPads.append(pad)
            
            anchor = padPosition
        }
    }
    
    /// Fill only genuinely large gaps that would be unjumpable
    private func fillLargeGaps(frogPosition: CGPoint, maxRegular: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, tadpoles: inout [Tadpole]) {
        let recentPads = lilyPads.filter { $0.position.y >= frogPosition.y - 100 }.sorted { $0.position.y < $1.position.y }
        
        guard recentPads.count >= 2 else { return }
        
        var prev = recentPads.first!.position
        for pad in recentPads.dropFirst() {
            let dy = pad.position.y - prev.y
            
            // Only fill truly unjumpable gaps (significantly larger than max jump range)
            if dy > maxRegular * 1.15 {
                var currentAnchor = prev
                
                while (pad.position.y - currentAnchor.y) > maxRegular * 0.9 {
                    let nextY = currentAnchor.y + CGFloat.random(in: 140...170)
                    createReachablePad(from: currentAnchor, targetY: nextY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, forceCreate: true)
                    
                    if let newPad = lilyPads.last {
                        currentAnchor = newPad.position
                    } else {
                        break
                    }
                }
            }
            prev = pad.position
        }
    }
}
