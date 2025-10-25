//
//  SpawnManager.swift (BALANCED VERSION)
//  Prevents gaps without over-spawning
//

import SpriteKit

class SpawnManager {
    weak var scene: SKScene?
    weak var worldNode: SKNode?
    
    // Throttle to prevent over-spawning
    private var framesSinceLastPathCheck = 0
    private let pathCheckInterval = 20 // Check every 20 frames (~0.33 seconds)
    
    private var graceEndTime: TimeInterval = 0

    // MARK: - Lily Pad Factory
    private func makeLilyPad(position: CGPoint, radius: CGFloat) -> LilyPad {
        // Determine score if available from GameScene
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
            // Configure movement for moving pads
            pad.screenWidthProvider = { [weak self] in self?.scene?.size.width ?? 1024 }
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
    
    /// Finds the furthest lily pad ahead of the frog
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
    
    /// Checks if a position is too close to existing lily pads
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
    
    /// Creates a single lily pad within reach of a position
    private func createReachablePad(from position: CGPoint, targetY: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, tadpoles: inout [Tadpole], forceCreate: Bool = false) {
        let maxDist = GameConfig.maxRegularJumpDistance * 0.65
        let minDist: CGFloat = 100  // Reduced from 120 to be safer
        
        var bestCandidate: CGPoint? = nil
        var bestDistance: CGFloat = 0
        
        for attempt in 0..<40 {
            let xVariation = CGFloat.random(in: -120...120)  // Increased variation range
            let x = max(80, min(sceneSize.width - 80, position.x + xVariation))
            let candidate = CGPoint(x: x, y: targetY)
            
            // Check distance from anchor
            let dx = candidate.x - position.x
            let dy = candidate.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Check if valid and not overlapping
            if distance > minDist && distance < maxDist && dy > 0 {
                if forceCreate || !isTooCloseToExisting(position: candidate, lilyPads: lilyPads, minDistance: 80) {
                    // Found a good spot!
                    let pad = makeLilyPad(
                        position: candidate,
                        radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
                    )
                    pad.node.position = pad.position
                    pad.node.zPosition = 10
                    worldNode.addChild(pad.node)
                    lilyPads.append(pad)
                    
                    // SPAWN TADPOLE: 40% chance on newly created pads
                    if CGFloat.random(in: 0...1) < 0.4 {
                        let tadpole = Tadpole(position: pad.position)
                        tadpole.node.position = pad.position
                        tadpole.node.zPosition = 50
                        worldNode.addChild(tadpole.node)
                        tadpoles.append(tadpole)
                    }
                    
                    return
                }
                
                // Track best candidate in case we need fallback
                if distance > bestDistance {
                    bestDistance = distance
                    bestCandidate = candidate
                }
            }
        }
        
        // FALLBACK: If no perfect spot found, use best candidate or force create
        let finalPosition = bestCandidate ?? CGPoint(
            x: max(80, min(sceneSize.width - 80, position.x + CGFloat.random(in: -100...100))),
            y: targetY
        )
        
        print("⚠️ Using fallback position for lily pad at \(finalPosition)")
        
        let pad = makeLilyPad(
            position: finalPosition,
            radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
        )
        pad.node.position = pad.position
        pad.node.zPosition = 10
        worldNode.addChild(pad.node)
        lilyPads.append(pad)
        
        // Spawn tadpole even on fallback pads
        if CGFloat.random(in: 0...1) < 0.4 {
            let tadpole = Tadpole(position: pad.position)
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
        
        // Create initial path with better spacing
        for i in 1..<20 {
            let targetY = lastPosition.y + CGFloat.random(in: 140...180)  // Adjusted to safer range
            
            let maxDist = GameConfig.maxRegularJumpDistance * 0.65
            var bestCandidate: CGPoint? = nil
            
            for attempt in 0..<50 {
                let x = CGFloat.random(in: 80...sceneSize.width - 80)
                let candidate = CGPoint(x: x, y: targetY)
                
                let dx = candidate.x - lastPosition.x
                let dy = candidate.y - lastPosition.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance < maxDist && distance > 100 {  // Reduced minimum to be safer
                    bestCandidate = candidate
                    break
                }
            }
            
            let finalPosition = bestCandidate ?? CGPoint(
                x: lastPosition.x + CGFloat.random(in: -120...120),  // Increased variation
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
        
        print("🌿 Spawned \(lilyPads.count) initial lily pads")
        
        // Removed initial enemy spawn block as per instructions
    }
    
    // MARK: - Continuous Spawn
    
    func spawnObjects(sceneSize: CGSize, lilyPads: inout [LilyPad], enemies: inout [Enemy], tadpoles: inout [Tadpole], worldOffset: CGFloat, frogPosition: CGPoint, superJumpActive: Bool) {
        guard let worldNode = worldNode else { return }
        
        // Proactively ensure a continuous chain of reachable lily pads ahead of the frog
        let maxRegular = GameConfig.maxRegularJumpDistance * 0.65
        let desiredPadsAhead = superJumpActive ? 10 : 6
        let maxGapAhead: CGFloat = maxRegular * 0.95 // keep gaps comfortably within regular jump

        // Find pads ahead and the furthest one
        let padsAheadList = lilyPads.filter { $0.position.y > frogPosition.y }.sorted { $0.position.y < $1.position.y }
        let furthestAhead = padsAheadList.last

        // Starting anchor: if we have a pad ahead use its position, otherwise start from frog
        var anchor = furthestAhead?.position ?? frogPosition

        // Ensure there are at least `desiredPadsAhead` pads ahead with gaps <= maxGapAhead
        var padsToEnsure = max(0, desiredPadsAhead - padsAheadList.count)

        // If superjump is active and the distance to the furthest pad is too small, add more
        if let furthest = furthestAhead {
            let dist = furthest.position.y - frogPosition.y
            if superJumpActive && dist < maxRegular * 3.0 {
                padsToEnsure += 3
            }
        } else {
            // No pads ahead at all: emergency ensure more pads
            padsToEnsure = max(padsToEnsure, superJumpActive ? 12 : 8)
        }

        // Build the chain forward with improved spacing
        for _ in 0..<padsToEnsure {
            let safeMaxSpacing = max(120, min(maxGapAhead * 0.8, 180))  // Ensure at least 120
            let targetY = anchor.y + CGFloat.random(in: 120...safeMaxSpacing)
            createReachablePad(from: anchor, targetY: targetY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles)
            if let newPad = lilyPads.last { anchor = newPad.position }
        }

        // Safety: verify the gaps between the last few pads are within maxGapAhead; if not, insert bridging pads
        let recentPads = lilyPads.filter { $0.position.y >= frogPosition.y - 50 }.sorted { $0.position.y < $1.position.y }
        if recentPads.count >= 2 {
            var prev = recentPads.first!.position
            for pad in recentPads.dropFirst() {
                let dy = pad.position.y - prev.y
                if dy > maxGapAhead {
                    // Insert bridging pads until the gap is within range
                    var currentAnchor = prev
                    while (pad.position.y - currentAnchor.y) > maxGapAhead {
                        let safeMaxSpacing = max(120, min(maxGapAhead * 0.8, 180))  // Ensure at least 120
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
        
        // Spawn enemies
        if !inGrace && CGFloat.random(in: 0...1) < GameConfig.enemySpawnRate {
            spawnEnemy(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode, lilyPads: lilyPads)
        }
        
        // Spawn logs
        if !inGrace && CGFloat.random(in: 0...1) < GameConfig.logSpawnRate {
            spawnLog(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode)
        }
        
        // Spawn tadpoles on existing pads near spawn area
        if CGFloat.random(in: 0...1) < GameConfig.tadpoleSpawnRate {
            spawnTadpole(at: spawnWorldY, sceneSize: sceneSize, lilyPads: lilyPads, tadpoles: &tadpoles, worldNode: worldNode)
        }
    }
    
    // MARK: - Individual Spawners
    
    /// Find a suitable lily pad for the given enemy type, considering occupancy rules
    private func findSuitableLilyPad(for enemyType: EnemyType, near worldY: CGFloat, sceneSize: CGSize, lilyPads: [LilyPad]) -> LilyPad? {
        // Filter lily pads that are near the spawn area
        let nearbyPads = lilyPads.filter { pad in
            let yDist = abs(pad.position.y - worldY)
            let xOk = pad.position.x > 80 && pad.position.x < sceneSize.width - 80
            return yDist < 200 && xOk
        }
        
        // Filter pads that can accommodate this enemy type
        let suitablePads = nearbyPads.filter { pad in
            pad.canAccommodateEnemyType(enemyType)
        }
        
        return suitablePads.randomElement()
    }
    
    private func spawnEnemy(at worldY: CGFloat, sceneSize: CGSize, enemies: inout [Enemy], worldNode: SKNode, lilyPads: [LilyPad]) {
        let rand = CGFloat.random(in: 0...1)
        let enemy: Enemy
        
        if rand < 0.5 {
            // Snake - tries to target a lily pad (but doesn't stay on it, just swims over it)
            let enemyType: EnemyType = .snake
            
            if let targetPad = findSuitableLilyPad(for: enemyType, near: worldY, sceneSize: sceneSize, lilyPads: lilyPads) {
                // Spawn snake targeting the lily pad
                let fromLeft = targetPad.position.x < sceneSize.width / 2
                enemy = Enemy(
                    type: enemyType,
                    position: CGPoint(
                        x: fromLeft ? -30 : sceneSize.width + 30,
                        y: targetPad.position.y
                    ),
                    speed: fromLeft ? GameConfig.snakeSpeed : -GameConfig.snakeSpeed
                )
                enemy.targetLilyPad = targetPad
                targetPad.addEnemyType(enemyType)
            } else {
                // No suitable lily pad found, spawn snake normally across the screen
                let fromLeft = Bool.random()
                enemy = Enemy(
                    type: enemyType,
                    position: CGPoint(
                        x: fromLeft ? -30 : sceneSize.width + 30,
                        y: worldY
                    ),
                    speed: fromLeft ? GameConfig.snakeSpeed : -GameConfig.snakeSpeed
                )
            }
        } else if rand < 0.75 {
            // Bee - tries to target a lily pad
            let enemyType: EnemyType = .bee
            
            if let targetPad = findSuitableLilyPad(for: enemyType, near: worldY, sceneSize: sceneSize, lilyPads: lilyPads) {
                enemy = Enemy(
                    type: enemyType,
                    position: targetPad.position,
                    speed: GameConfig.beeSpeed
                )
                enemy.targetLilyPad = targetPad
                targetPad.addEnemyType(enemyType)
            } else {
                // No suitable lily pad found, spawn bee at random position
                enemy = Enemy(
                    type: enemyType,
                    position: CGPoint(
                        x: CGFloat.random(in: 60...sceneSize.width - 60),
                        y: worldY
                    ),
                    speed: GameConfig.beeSpeed
                )
            }
        } else {
            // Dragonfly - doesn't target lily pads, flies freely
            enemy = Enemy(
                type: .dragonfly,
                position: CGPoint(
                    x: CGFloat.random(in: 60...sceneSize.width - 60),
                    y: worldY
                ),
                speed: GameConfig.dragonflySpeed
            )
        }
        
        enemy.node.position = enemy.position
        enemy.node.zPosition = 50
        worldNode.addChild(enemy.node)
        enemies.append(enemy)
    }
    
    private func spawnTadpole(at worldY: CGFloat, sceneSize: CGSize, lilyPads: [LilyPad], tadpoles: inout [Tadpole], worldNode: SKNode) {
        let nearbyPads = lilyPads.filter { pad in
            let yDist = abs(pad.position.y - worldY)
            let xOk = pad.position.x > 80 && pad.position.x < sceneSize.width - 80
            return yDist < 150 && xOk
        }
        
        guard let pad = nearbyPads.randomElement() ?? lilyPads.suffix(10).randomElement() else {
            return
        }
        
        let tadpole = Tadpole(position: pad.position)
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
