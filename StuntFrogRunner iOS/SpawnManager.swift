//
//  SpawnManager.swift (UPDATED)
//  Enhanced lily pad path validation and tadpole distribution
//

import SpriteKit

class SpawnManager {
    weak var scene: SKScene?
    weak var worldNode: SKNode?
    
    // Pads that have already spawned a tadpole; prevents repeat spawns on the same pad
    private var padsThatSpawnedTadpoles = Set<ObjectIdentifier>()
    
    // PERFORMANCE OPTIMIZED: Spatial grid for fast overlap detection
    private var spatialGrid: SpatialGrid = SpatialGrid(cellSize: 200)
    
    // Maximum number of bees allowed within the current visible screen window
    // Adjust as needed or expose via GameConfig if desired
    private let maxBeesPerScreen: Int = 4
    
    // PERFORMANCE OPTIMIZED: Increased log limits with smart culling
    private let maxLogsPerScreen: Int = 12  // Increased from 8 to 12
    private let maxTotalLogs: Int = 18      // Increased from 12 to 18
    private var lastLogCount = 0

    // Tadpole pacing
    private var framesSinceLastTadpole: Int = 0
    private let tadpoleForceSpawnFrameThreshold: Int = 120 // ~2 seconds at 60fps
    private var lastTadpoleWorldY: CGFloat = -CGFloat.greatestFiniteMagnitude
    private let minTadpoleSpacingY: CGFloat = 180

    // Probability to attach a tadpole to a newly spawned lily pad
    private var tadpolePerPadProbability: CGFloat {
        return GameConfig.tadpolePerPadProbability
    }

    /// Resets all spawn-related state so a new run starts fresh
    func reset(for lilyPads: inout [LilyPad], tadpoles: inout [Tadpole]) {
        // Clear global tracking
        padsThatSpawnedTadpoles.removeAll()
        framesSinceLastTadpole = 0
        lastTadpoleWorldY = -CGFloat.greatestFiniteMagnitude
        frameCount = 0
        lastBeeCount = 0
        lastLogCount = 0
        spawningPaused = false
        graceEndTime = 0
        
        // Clear spatial grid
        spatialGrid.clear()
        
        // Clear existing tadpoles from scene and detach from pads
        for t in tadpoles {
            t.lilyPad?.clearTadpoles()
            t.node.removeFromParent()
        }
        tadpoles.removeAll()
        
        // Reset tadpole-related state on existing lily pads
        for pad in lilyPads {
            pad.clearTadpoles()
        }
        
        // Rebuild spatial grid with existing pads
        for pad in lilyPads {
            spatialGrid.insert(pad)
        }
    }

    /// Counts logs within the current visible screen window in world coordinates.
    private func countLogsInVisibleWindow(enemies: [Enemy], worldOffset: CGFloat, sceneSize: CGSize) -> Int {
        let minVisibleY = -worldOffset - 100  // Slightly larger margin for better accuracy
        let maxVisibleY = -worldOffset + sceneSize.height + 100
        return enemies.reduce(0) { acc, e in
            guard e.type == .log else { return acc }
            return (e.position.y >= minVisibleY && e.position.y <= maxVisibleY) ? acc + 1 : acc
        }
    }
    
    /// Removes logs that are far off-screen to improve performance
    private func cullDistantLogs(enemies: inout [Enemy], worldOffset: CGFloat, sceneSize: CGSize) {
        let cullBelowY = -worldOffset - sceneSize.height * 1.2  // More aggressive culling below
        let cullAboveY = -worldOffset + sceneSize.height * 2.5  // Allow logs further ahead
        
        let indicesToRemove = enemies.enumerated().compactMap { index, enemy in
            guard enemy.type == .log else { return nil }
            return (enemy.position.y < cullBelowY || enemy.position.y > cullAboveY) ? index : nil
        }.sorted(by: >)
        
        for index in indicesToRemove {
            enemies[index].node.removeFromParent()
            enemies.remove(at: index)
        }
        
        // Performance optimization: Log culling stats occasionally
        if !indicesToRemove.isEmpty && frameCount % 120 == 0 {
            print("🪵 Culled \(indicesToRemove.count) distant logs for performance")
        }
    }
    
    /// Counts bees within the current visible screen window in world coordinates.
    /// - Parameters:
    ///   - enemies: Current enemies array
    ///   - worldOffset: Current worldNode.position.y
    ///   - sceneSize: Scene size (to compute visible Y range)
    private func countBeesInVisibleWindow(enemies: [Enemy], worldOffset: CGFloat, sceneSize: CGSize) -> Int {
        let minVisibleY = -worldOffset - 50 // small margin below screen
        let maxVisibleY = -worldOffset + sceneSize.height + 50 // small margin above screen
        return enemies.reduce(0) { acc, e in
            guard e.type == .bee else { return acc }
            return (e.position.y >= minVisibleY && e.position.y <= maxVisibleY) ? acc + 1 : acc
        }
    }
    
    private var framesSinceLastPathCheck = 0
    private let pathCheckInterval = 10  // IMPROVED: Check more frequently
    
    private var graceEndTime: TimeInterval = 0
    
    // MARK: - Spawning Control
    private var spawningPaused: Bool = false
    var pauseSpawning: (() -> Void)?
    var resumeSpawning: (() -> Void)?

    // MARK: - Lily Pad Factory
    private func makeLilyPad(position: CGPoint, radius: CGFloat, frogPosition: CGPoint, tadpoles: inout [Tadpole], worldNode: SKNode) -> LilyPad {
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        print("🎯 Creating lily pad with current score: \(currentScore)")
        
        let type: LilyPadType
        // TEMPORARY DEBUG: Force more moving lily pads for testing
        let debugTestMoving = true
        
        if debugTestMoving && currentScore >= 500 {
            // Test mode: Once score hits 500, create more moving pads
            let r = CGFloat.random(in: 0...1)
            if r < 0.4 { type = .normal }
            else if r < 0.6 { type = .pulsing }
            else { type = .moving }
            print("🧪 DEBUG TEST MODE: Created \(type) lily pad (score: \(currentScore))")
        } else if currentScore < 2000 {
            type = .normal
        } else if currentScore < 8000 {
            // 2000-7999 points: 60% normal, 20% pulsing, 20% moving
            let r = CGFloat.random(in: 0...1)
            if r < 0.6 { type = .normal }
            else if r < 0.8 { type = .pulsing }
            else { type = .moving }
        } else {
            // 8000+ points: 30% normal, 20% pulsing, 50% moving
            let r = CGFloat.random(in: 0...1)
            if r < 0.3 { type = .normal }
            else if r < 0.5 { type = .pulsing }
            else { type = .moving }
        }
        let pad = LilyPad(position: position, radius: radius, type: type)
        if type == .moving {
            pad.screenWidthProvider = { [weak self] in 
                return (self?.scene as? GameScene)?.size.width ?? 1024 
            }
            pad.movementSpeed = 120.0
            // Make sure moving is properly initialized
            pad.startMovingIfNeeded()
           
        } 
        // Attempt to attach a tadpole to this new pad
        maybeAttachTadpole(to: pad, frogPosition: frogPosition, tadpoles: &tadpoles, worldNode: worldNode)
        return pad
    }
    
    /// Attempts to spawn a tadpole on a newly created pad based on probability.
    /// Ensures we never spawn behind the frog and never reuse the same pad twice.
    private func maybeAttachTadpole(to pad: LilyPad, frogPosition: CGPoint, tadpoles: inout [Tadpole], worldNode: SKNode) {
        // Do not spawn if pad is at or behind the frog
        guard pad.position.y > frogPosition.y + 40 else { return }
        
        // Only if pad does not already have tadpoles and has never spawned one
        let id = ObjectIdentifier(pad)
     //   guard !pad.hasTadpoles && !padsThatSpawnedTadpoles.contains(id) else { return }
        
        // Probability gate
        if CGFloat.random(in: 0...1) > tadpolePerPadProbability { return }
        
      
        let tadpole = Tadpole(position: pad.position)
        tadpole.lilyPad = pad
        padsThatSpawnedTadpoles.insert(id)
        
        tadpole.node.position = pad.position
        tadpole.node.zPosition = 50
        worldNode.addChild(tadpole.node)
        tadpoles.append(tadpole)
        
        // Reset forced spawn timer since we just spawned a tadpole
        framesSinceLastTadpole = 0
        lastTadpoleWorldY = pad.position.y
        print("ðŸ¸ (auto) Spawned tadpole on new pad at \(Int(pad.position.x)), \(Int(pad.position.y))")
    }
    
    init(scene: SKScene, worldNode: SKNode) {
        self.scene = scene
        self.worldNode = worldNode
        
        // Set up spawning control callbacks
        pauseSpawning = { [weak self] in
            self?.spawningPaused = true
        }
        
        resumeSpawning = { [weak self] in
            self?.spawningPaused = false
        }
    }
    
    func startGracePeriod(duration: TimeInterval) {
        graceEndTime = CACurrentMediaTime() + duration
    }
    
    // MARK: - Spawning Control Methods
    
    /// Pauses enemy spawning and clears enemies from around the specified lily pad
    func pauseSpawningAndClearEnemies(around landingPad: LilyPad, enemies: inout [Enemy], sceneSize: CGSize) {
        spawningPaused = true
        
        // Define clear radius around the landing pad
        let clearRadius: CGFloat = 150.0
        let padPosition = landingPad.position
        
        // Find and remove enemies within the clear radius
        let indicesToRemove = enemies.enumerated().compactMap { index, enemy in
            let distance = sqrt(pow(enemy.position.x - padPosition.x, 2) + pow(enemy.position.y - padPosition.y, 2))
            return distance <= clearRadius ? index : nil
        }.reversed() // Reverse to remove from back to front
        
        for index in indicesToRemove {
            let enemy = enemies[index]
            
            // Remove enemy from its target lily pad if it has one
            if let targetPad = enemy.targetLilyPad {
                targetPad.removeEnemyType(enemy.type)
            }
            
            // Remove the enemy node from the scene
            enemy.node.removeFromParent()
            
            // Remove from enemies array
            enemies.remove(at: index)
            
        }
    }
    
    /// Resumes enemy spawning
    func resumeSpawningAfterAbilitySelection() {
        spawningPaused = false
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
    
    // REPLACED FUNCTION: Optimized overlap check using spatial grid
    private func isOverlappingExisting(position: CGPoint, candidateRadius: CGFloat, lilyPads: [LilyPad], extraPadding: CGFloat = 12) -> Bool {
        // Use spatial grid for O(1) average case lookup instead of O(n) linear search
        let nearbyPads = spatialGrid.query(position: position, radius: candidateRadius + extraPadding + GameConfig.maxLilyPadRadius)
        
        for pad in nearbyPads {
            let dx = position.x - pad.position.x
            let dy = position.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            let minSeparation = pad.radius + candidateRadius + extraPadding
            if distance < minSeparation { return true }
        }
        return false
    }
    
    private func createReachablePad(from position: CGPoint, targetY: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, tadpoles: inout [Tadpole], forceCreate: Bool = false) {
        let maxDist = GameConfig.maxRegularJumpDistance * 0.85  // Ensure it's definitely reachable
        let minDist: CGFloat = 80  // Reduced minimum distance for easier placement
        
        var bestCandidate: CGPoint? = nil
        var bestDistance: CGFloat = 0
        
        // Try to find a good position
        for attempt in 0..<20 {  // More attempts for better placement
            let xVariation = CGFloat.random(in: -100...100)
            let x = max(90, min(sceneSize.width - 90, position.x + xVariation))
            let candidate = CGPoint(x: x, y: targetY)
            
            let dx = candidate.x - position.x
            let dy = candidate.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance > minDist && distance < maxDist && dy > 0 {
                let candidateRadius = CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
                if forceCreate || !isOverlappingExisting(position: candidate, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                    if let gs = scene as? GameScene, let wn = self.worldNode {
                        let pad = makeLilyPad(
                            position: candidate,
                            radius: candidateRadius,
                            frogPosition: gs.frogController.position,
                            tadpoles: &tadpoles,
                            worldNode: wn
                        )
                        pad.node.position = pad.position
                        pad.node.zPosition = 10
                        worldNode.addChild(pad.node)
                        lilyPads.append(pad)
                        
                        // Register with spatial grid for fast overlap detection
                        spatialGrid.insert(pad)
                        
                        print("✅ Created reachable pad at distance \(Int(distance)) from \(Int(position.y)) to \(Int(candidate.y))")
                        return
                    }
                }
                
                // Track the best valid position even if it overlaps
                if distance > bestDistance {
                    bestDistance = distance
                    bestCandidate = candidate
                }
            }
        }
        
        // Fallback: Force create at best position or safe default
        let candidateRadius = CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
        var final = bestCandidate ?? CGPoint(
            x: max(90, min(sceneSize.width - 90, position.x + CGFloat.random(in: -60...60))),
            y: targetY
        )
        
        // If forcing creation or this is an emergency, allow some overlap
        if forceCreate {
            var tries = 0
            while isOverlappingExisting(position: final, candidateRadius: candidateRadius, lilyPads: lilyPads) && tries < 8 {
                final.x = max(90, min(sceneSize.width - 90, final.x + CGFloat.random(in: -30...30)))
                final.y += CGFloat.random(in: -20...20)
                tries += 1
            }
        }
        
        if let gs = scene as? GameScene, let wn = self.worldNode {
            let pad = makeLilyPad(
                position: final,
                radius: candidateRadius,
                frogPosition: gs.frogController.position,
                tadpoles: &tadpoles,
                worldNode: wn
            )
            pad.node.position = pad.position
            pad.node.zPosition = 10
            worldNode.addChild(pad.node)
            lilyPads.append(pad)
            
            // Register with spatial grid for fast overlap detection
            spatialGrid.insert(pad)
            
            let actualDistance = sqrt(pow(final.x - position.x, 2) + pow(final.y - position.y, 2))
            print("⚠️ Force created pad at distance \(Int(actualDistance)) from \(Int(position.y)) to \(Int(final.y))")
        }
    }
    
    // MARK: - Initial Spawn
    
    func spawnInitialObjects(sceneSize: CGSize, lilyPads: inout [LilyPad], enemies: inout [Enemy], tadpoles: inout [Tadpole], worldOffset: CGFloat) {
        guard let worldNode = worldNode else { return }
        
        var lastPosition = CGPoint(x: sceneSize.width / 2, y: -worldOffset + sceneSize.height * 0.3)
        
        // IMPROVED: Spawn even more initial lily pads (40 instead of 30) for abundant starting coverage
        for _ in 1..<40 {
            let targetY = lastPosition.y + CGFloat.random(in: 130...170)
            
            let maxDist = GameConfig.maxRegularJumpDistance * 0.8
            var bestCandidate: CGPoint? = nil
            
            // Generate candidate radius before overlap checks
            let candidateRadius = CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
            
            // Try to find a candidate that meets distance and does not overlap
            var foundCandidate: CGPoint? = nil
            for _ in 0..<15 {
                let x = CGFloat.random(in: 100...sceneSize.width - 100)
                let candidate = CGPoint(x: x, y: targetY)
                
                let dx = candidate.x - lastPosition.x
                let dy = candidate.y - lastPosition.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance < maxDist && distance > 100 && !isOverlappingExisting(position: candidate, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                    foundCandidate = candidate
                    break
                }
            }
            if foundCandidate == nil {
                // If no suitable candidate found, skip this iteration to avoid overlapping pads
                continue
            }
            
            let finalPosition = foundCandidate!
            
            if let gs = scene as? GameScene, let wn = self.worldNode {
                let pad = makeLilyPad(
                    position: finalPosition,
                    radius: candidateRadius,
                    frogPosition: gs.frogController.position,
                    tadpoles: &tadpoles,
                    worldNode: wn
                )
                pad.node.position = pad.position
                pad.node.zPosition = 10
                worldNode.addChild(pad.node)
                lilyPads.append(pad)
                
                // Register with spatial grid for fast overlap detection
                spatialGrid.insert(pad)
            }
            lastPosition = finalPosition
        }
        
        print("Ã°Å¸Å½Â® Spawned \(lilyPads.count) initial lily pads for abundant coverage")
    }
    
    // MARK: - Continuous Spawn
    
    // Performance tracking
    private var frameCount = 0
    private var lastBeeCount = 0
    
    /// CRITICAL SAFETY: Ensures frog always has reachable lily pads ahead
    private func ensureFrogCanProgress(frogPosition: CGPoint, lilyPads: inout [LilyPad], sceneSize: CGSize, worldNode: SKNode, tadpoles: inout [Tadpole]) {
        let maxJump = GameConfig.maxRegularJumpDistance
        
        // Find all pads the frog can currently reach
        let reachablePads = lilyPads.filter { pad in
            let dx = pad.position.x - frogPosition.x
            let dy = pad.position.y - frogPosition.y
            let distance = sqrt(dx*dx + dy*dy)
            return dy > 0 && distance <= maxJump  // Only pads ahead and within jump range
        }
        
        if reachablePads.isEmpty {
            print("🆘 CRITICAL SAFETY: Frog has NO reachable pads! Creating emergency path")
            // Create an immediate reachable pad
            let emergencyPosition = CGPoint(
                x: frogPosition.x + CGFloat.random(in: -80...80),
                y: frogPosition.y + CGFloat.random(in: 120...160)
            )
            createReachablePad(from: frogPosition, targetY: emergencyPosition.y, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, forceCreate: true)
            
            // Create a few more to ensure a path forward
            if let newPad = lilyPads.last {
                for _ in 0..<3 {
                    let nextY = newPad.position.y + CGFloat.random(in: 120...160)
                    createReachablePad(from: newPad.position, targetY: nextY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, forceCreate: true)
                }
            }
        }
    }
    
    func spawnObjects(sceneSize: CGSize, lilyPads: inout [LilyPad], enemies: inout [Enemy], tadpoles: inout [Tadpole], worldOffset: CGFloat, frogPosition: CGPoint, superJumpActive: Bool) {
        guard let worldNode = worldNode else { return }
        
        frameCount += 1
        framesSinceLastTadpole += 1
        
        // CRITICAL SAFETY CHECK: Ensure frog can always progress
        if frameCount % 5 == 0 {  // Check every 5 frames
            ensureFrogCanProgress(frogPosition: frogPosition, lilyPads: &lilyPads, sceneSize: sceneSize, worldNode: worldNode, tadpoles: &tadpoles)
        }
        
        // If spawning is paused (during ability selection), don't spawn enemies or tadpoles
        if spawningPaused {
            return
        }
        
        // Calculate the spawn point (where new objects appear ahead of the player)
        let spawnWorldY = -worldOffset + sceneSize.height + 100
        
        // Calculate dynamic scroll speed for adaptive spawning
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        let dynamicScrollSpeed = calculateCurrentScrollSpeed(score: currentScore, superJumpActive: superJumpActive)
        
        let maxRegular = GameConfig.maxRegularJumpDistance * 0.85
        
        // CRITICAL FIX: Ensure sufficient lily pad density to prevent gaps
        let baseDesiredPads = superJumpActive ? 20 : 15  // Increased back to safe levels
        let speedMultiplier = min(2.5, max(1.2, dynamicScrollSpeed / GameConfig.scrollSpeed))  // Allow higher multiplier
        let desiredPadsAhead = Int(CGFloat(baseDesiredPads) * speedMultiplier)
        
        let lookaheadDistance = maxRegular * 2.0 * speedMultiplier  // Increased multiplier for better coverage
        
        let padsAheadList = lilyPads.filter { $0.position.y > frogPosition.y }.sorted { $0.position.y < $1.position.y }
        let furthestAhead = padsAheadList.last
        
        // Calculate how far ahead we have coverage
        let currentCoverage = (furthestAhead?.position.y ?? frogPosition.y) - frogPosition.y
        
        // CRITICAL FIX: More aggressive emergency spawning to prevent gaps
        let criticalPadThreshold = max(8, desiredPadsAhead / 2)  // Trigger at 50% instead of 33%
        let criticalCoverageThreshold = lookaheadDistance * 0.6  // Trigger at 60% instead of 30%
        
        if padsAheadList.count < criticalPadThreshold || currentCoverage < criticalCoverageThreshold {
            // CRITICAL: Spawn more emergency pads to guarantee coverage
            let emergencyPads = max(6, desiredPadsAhead - padsAheadList.count)  // Minimum 6, no cap
            print("🚨 EMERGENCY: Spawning \(emergencyPads) pads - only \(padsAheadList.count) ahead, coverage: \(Int(currentCoverage))")
            spawnPadChain(count: emergencyPads, startingFrom: furthestAhead?.position ?? frogPosition, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, maxRegular: maxRegular, tadpoles: &tadpoles)
        }
        
        // CRITICAL FIX: Check for gaps more frequently to prevent holes
        if frameCount % 5 == 0 {  // Back to every 5 frames for safety
            ensurePadsAtSpawnPoint(spawnWorldY: spawnWorldY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, maxRegular: maxRegular, tadpoles: &tadpoles)
        }
        
        var anchor = furthestAhead?.position ?? frogPosition
        var padsToEnsure = max(0, desiredPadsAhead - padsAheadList.count)
        
        // CRITICAL FIX: Ensure minimum pad spawning per frame
        padsToEnsure = max(padsToEnsure, 1)  // Always spawn at least 1 pad per frame
        padsToEnsure = min(padsToEnsure, 6)  // But cap at reasonable limit
        
        // Additional pads during super jump
        if superJumpActive && currentCoverage < lookaheadDistance * 0.7 {
            padsToEnsure = min(padsToEnsure + 3, 8)  // More pads for super jump
        }
        
        // If we have NO pads ahead at all, this is critical - spawn many
        if padsAheadList.isEmpty {
            padsToEnsure = desiredPadsAhead  // No cap when completely empty
            print("🆘 CRITICAL: No pads ahead of frog! Spawning \(padsToEnsure) pads immediately")
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
        
        // CRITICAL FIX: Gap checking every 10 frames for better coverage
        framesSinceLastPathCheck += 1
        if framesSinceLastPathCheck >= 10 {  // More frequent gap checking
            framesSinceLastPathCheck = 0
            fillLargeGaps(frogPosition: frogPosition, maxRegular: maxRegular, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles)
        }
        
        // Spawn enemies, tadpoles, and logs
        let inGrace = CACurrentMediaTime() < graceEndTime
        
        // PERFORMANCE FIX: Spawn enemies less frequently and cache bee/log counts
        let enemySpawnChance = GameConfig.enemySpawnRate * 1.2  // Reduced from 1.5 to 1.2
        if !inGrace && CGFloat.random(in: 0...1) < enemySpawnChance {
            // PERFORMANCE FIX: Only count bees and logs every 8 frames for better performance
            var canSpawnBee = true
            var canSpawnLog = true
            if frameCount % 8 == 0 {  // More frequent updates for better log distribution
                lastBeeCount = countBeesInVisibleWindow(enemies: enemies, worldOffset: worldOffset, sceneSize: sceneSize)
                lastLogCount = countLogsInVisibleWindow(enemies: enemies, worldOffset: worldOffset, sceneSize: sceneSize)
            }
            canSpawnBee = lastBeeCount < maxBeesPerScreen
            canSpawnLog = lastLogCount < maxLogsPerScreen

            // Simplified enemy type selection with log cap enforcement
            let currentScore: Int = (scene as? GameScene)?.score ?? 0
            var allowedTypes: [EnemyType] = []
            if currentScore < 4000 {
                allowedTypes = canSpawnBee ? [.bee] : []
            } else if currentScore < 10000 {
                allowedTypes = canSpawnBee ? [.bee, .dragonfly] : [.dragonfly]
            } else if currentScore < 15000 {
                allowedTypes = canSpawnBee ? [.bee, .dragonfly, .snake] : [.dragonfly, .snake]
            } else {
                // PERFORMANCE FIX: Only add logs if we can spawn them (under cap)
                if canSpawnLog && canSpawnBee {
                    allowedTypes = [.bee, .dragonfly, .snake]  // Remove log from regular enemy spawning
                } else if canSpawnBee {
                    allowedTypes = [.bee, .dragonfly, .snake]
                } else {
                    allowedTypes = [.dragonfly, .snake]
                }
            }
            
            if let selectedType = allowedTypes.randomElement() {
                spawnEnemy(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode, lilyPads: lilyPads)
                if selectedType == .bee {
                    lastBeeCount += 1  // Update cached count
                }
            }
        }
        
        // CRITICAL FIX: Force spawn tadpoles if too many frames pass without one
        // This ensures continuous tadpole availability even if probability rolls fail
        if !inGrace && framesSinceLastTadpole > tadpoleForceSpawnFrameThreshold {
            // Attempt forced spawn
            if spawnTadpole(at: spawnWorldY, sceneSize: sceneSize, lilyPads: lilyPads, tadpoles: &tadpoles, worldNode: worldNode, frogPosition: frogPosition) {
                framesSinceLastTadpole = 0
                lastTadpoleWorldY = spawnWorldY
            }
        }
        
        // PERFORMANCE OPTIMIZED: More frequent log spawning with smart management
        // Only spawn logs when score is above 15000, with enhanced spawn rate
        if !inGrace && currentScore > 15000 {
            let totalLogCount = enemies.filter({ $0.type == .log }).count
            
            // More frequent culling for better performance with higher log counts
            if frameCount % 20 == 0 {  // Every 20 frames instead of 30
                cullDistantLogs(enemies: &enemies, worldOffset: worldOffset, sceneSize: sceneSize)
            }
            
            // Allow more total logs but maintain visible screen limit
            if lastLogCount < maxLogsPerScreen && totalLogCount < maxTotalLogs {
                // Significantly increased spawn rate for more log presence
                let logSpawnChance = GameConfig.logSpawnRate * 0.8  // Increased from 60% to 80%
                if CGFloat.random(in: 0...1) < logSpawnChance {
                    spawnLog(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode)
                    lastLogCount += 1  // Update cached count immediately
                }
            }
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
        
        // Updated: For all enemy types including bees, filter only pads that can accommodate that enemy type.
        let suitablePads = nearbyPads.filter { pad in
            return pad.canAccommodateEnemyType(enemyType)
        }
        
        if suitablePads.isEmpty {
            return nil
        }
        
        return suitablePads.randomElement()
    }
    
    private func spawnEnemy(at worldY: CGFloat, sceneSize: CGSize, enemies: inout [Enemy], worldNode: SKNode, lilyPads: [LilyPad]) {
        // Get current score from the game scene
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        
        // Enforce per-screen bee cap when trying to spawn a bee
        // We cannot know the selected type yet here, so we'll check after selection as well.
        
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
        
        // If the selected type is a bee, ensure we are under the visible cap
        if selectedType == .bee {
            // We need scene size and worldOffset to compute the visible window; attempt to read from scene
            if let gs = scene as? GameScene {
                let visibleBeeCount = countBeesInVisibleWindow(enemies: enemies, worldOffset: gs.worldManager.worldNode.position.y, sceneSize: gs.size)
                if visibleBeeCount >= maxBeesPerScreen {
                    // Cap reached; skip this spawn entirely
                    return
                }
            }
        }
        
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
            if let targetPad = findSuitableLilyPad(for: selectedType, near: worldY, sceneSize: sceneSize, lilyPads: lilyPads), targetPad.canAccommodateEnemyType(.bee) {
                // Randomize bee speed per spawn; broader variance at higher scores
                let base = GameConfig.beeSpeed
                // Variance grows with score tiers (up to +/- 60%)
                let tier = min(3, (currentScore / 5000))
                let variance: CGFloat
                switch tier {
                case 0: variance = 0.20   // +/-20% early game
                case 1: variance = 0.35   // +/-35%
                case 2: variance = 0.50   // +/-50%
                default: variance = 0.60  // +/-60% late game
                }
                let factor = 1.0 + CGFloat.random(in: -variance...variance)
                let beeSpeed = max(40, base * factor)
                
                enemy = Enemy(
                    type: selectedType,
                    position: targetPad.position,
                    speed: beeSpeed
                )
                enemy.targetLilyPad = targetPad
                targetPad.addEnemyType(.bee)
            } else {
                // If no suitable pad found, spawn bee anyway at a reasonable position
                // This ensures bees always appear even if pads are temporarily limited
                // Randomize bee speed per spawn; broader variance at higher scores
                let base = GameConfig.beeSpeed
                // Variance grows with score tiers (up to +/- 60%)
                let tier = min(3, (currentScore / 5000))
                let variance: CGFloat
                switch tier {
                case 0: variance = 0.20   // +/-20% early game
                case 1: variance = 0.35   // +/-35%
                case 2: variance = 0.50   // +/-50%
                default: variance = 0.60  // +/-60% late game
                }
                let factor = 1.0 + CGFloat.random(in: -variance...variance)
                let beeSpeed = max(40, base * factor)
                
                enemy = Enemy(
                    type: selectedType,
                    position: CGPoint(
                        x: CGFloat.random(in: 100...sceneSize.width - 100),
                        y: worldY
                    ),
                    speed: beeSpeed
                )
                print("Ã¢Å¡Â Ã¯Â¸Â Spawned bee without lily pad at worldY: \(Int(worldY))")
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
    
    @discardableResult
    private func spawnTadpole(at worldY: CGFloat, sceneSize: CGSize, lilyPads: [LilyPad], tadpoles: inout [Tadpole], worldNode: SKNode, frogPosition: CGPoint) -> Bool {
        // Find all suitable pads in a reasonable range
        let suitablePads = lilyPads.filter { pad in
            let yDist = abs(pad.position.y - worldY)
            let xOk = pad.position.x > 80 && pad.position.x < sceneSize.width - 80
            // Accept pads within a wider range for better distribution
            return yDist < 400 && xOk
        }
        
        // Avoid spawning on or near the frog's current position
        let safeDistanceFromFrog: CGFloat = 120
        let padsAwayFromFrog = suitablePads.filter { pad in
            let dx = pad.position.x - frogPosition.x
            let dy = pad.position.y - frogPosition.y
            let dist = sqrt(dx*dx + dy*dy)
            return dist >= safeDistanceFromFrog
        }
        
        // Exclude pads that have already had a tadpole spawned before (ever)
        let neverUsedPads = padsAwayFromFrog.filter { pad in
            let id = ObjectIdentifier(pad)
            return !padsThatSpawnedTadpoles.contains(id)
        }
        
        // CRITICAL FIX: Use the proper lily pad tadpole tracking system and never reuse pads that already spawned
        let availablePads = neverUsedPads.filter { pad in
            // Only include pads that don't currently have tadpoles
            return !pad.hasTadpoles
        }
        
        // FIXED: Only use pads that have never spawned a tadpole AND don't currently have one
        // Do NOT fall back to pads that might have tadpoles
        var candidates = availablePads
        
        // Removed reservation logic; select candidate directly without reservation
        var selectedPadCandidate: LilyPad? = candidates.randomElement()
        
        // Fallback: try a limited set of recent pads ahead that have NEVER spawned a tadpole and are currently empty
        if selectedPadCandidate == nil {
            let recentAhead = lilyPads.filter { $0.position.y > frogPosition.y }.suffix(20)
            if let pad = recentAhead.first(where: { pad in
                let id = ObjectIdentifier(pad)
                return !padsThatSpawnedTadpoles.contains(id) && !pad.hasTadpoles
            }) {
                selectedPadCandidate = pad
            }
        }
        
        guard let selectedPad = selectedPadCandidate else {
            print("ðŸš« No available lily pads for tadpole spawn (reservation failed)")
            return false
        }

        // Spawn the tadpole on the reserved pad
        let tadpole = Tadpole(position: selectedPad.position)
        // Link to pad (this will add via didSet), but also finalize reservation explicitly
        tadpole.lilyPad = selectedPad
        // Mark this pad as permanently used for tadpole spawns
        padsThatSpawnedTadpoles.insert(ObjectIdentifier(selectedPad))
        
        tadpole.node.position = selectedPad.position
        tadpole.node.zPosition = 50
        worldNode.addChild(tadpole.node)
        tadpoles.append(tadpole)
        print("ðŸ¸ Spawned tadpole on lily pad at \(Int(selectedPad.position.x)), \(Int(selectedPad.position.y))")
        return true
    }
    
    private func spawnLog(at worldY: CGFloat, sceneSize: CGSize, enemies: inout [Enemy], worldNode: SKNode) {
        // PERFORMANCE OPTIMIZED: Enhanced log count tracking with spatial awareness
        let currentLogCount = enemies.filter({ $0.type == .log }).count
        
        if currentLogCount >= maxTotalLogs {
            return  // Don't spawn if we're at total cap
        }
        
        // PERFORMANCE: Check if there are already logs too close vertically (avoid clustering)
        let minVerticalSpacing: CGFloat = 150
        let hasNearbyLog = enemies.contains { enemy in
            enemy.type == .log && abs(enemy.position.y - worldY) < minVerticalSpacing
        }
        
        if hasNearbyLog {
            return  // Skip spawning to prevent vertical clustering
        }
        
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
        
        print("🪵 Spawned log (count: \(currentLogCount + 1)/\(maxTotalLogs) total) from \(fromLeft ? "left" : "right")")
    }
    
    // MARK: - Helper Methods for Improved Spawning
    
    /// PERFORMANCE FIX: Ensure there are always lily pads at the spawn point where enemies/tadpoles appear
    private func ensurePadsAtSpawnPoint(spawnWorldY: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, maxRegular: CGFloat, tadpoles: inout [Tadpole]) {
        // Check how many pads exist near the spawn point
        let padsNearSpawnPoint = lilyPads.filter { pad in
            let yDist = abs(pad.position.y - spawnWorldY)
            return yDist < 200  // Reduced from 300 to 200
        }
        
        // PERFORMANCE FIX: Reduce minimum pads from 5 to 3
        let minPadsAtSpawn = 3
        
        if padsNearSpawnPoint.count < minPadsAtSpawn {
            let padsToCreate = minPadsAtSpawn - padsNearSpawnPoint.count
            
            // Create pads directly at spawn height with horizontal variation
            for i in 0..<padsToCreate {
                var xPosition: CGFloat
                if i % 3 == 0 {
                    xPosition = CGFloat.random(in: 100...sceneSize.width/3)  // Left third
                } else if i % 3 == 1 {
                    xPosition = CGFloat.random(in: sceneSize.width/3...2*sceneSize.width/3)  // Middle third
                } else {
                    xPosition = CGFloat.random(in: 2*sceneSize.width/3...sceneSize.width-100)  // Right third
                }
                
                let yOffset = CGFloat.random(in: -80...80)  // Reduced variation from -100...100
                let candidatePosition = CGPoint(x: xPosition, y: spawnWorldY + yOffset)
                
                let candidateRadius = CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
                var finalPosition = candidatePosition
                var tries = 0
                while isOverlappingExisting(position: finalPosition, candidateRadius: candidateRadius, lilyPads: lilyPads) && tries < 10 {
                    finalPosition.x = max(90, min(sceneSize.width - 90, finalPosition.x + CGFloat.random(in: -40...40)))
                    tries += 1
                }
                if isOverlappingExisting(position: finalPosition, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                    // Skip this pad creation if still overlapping after tries
                    continue
                }
                
                if let gs = scene as? GameScene, let wn = self.worldNode {
                    let pad = makeLilyPad(
                        position: finalPosition,
                        radius: candidateRadius,
                        frogPosition: gs.frogController.position,
                        tadpoles: &tadpoles,
                        worldNode: wn
                    )
                    pad.node.position = pad.position
                    pad.node.zPosition = 10
                    worldNode.addChild(pad.node)
                    lilyPads.append(pad)
                    
                    // Register with spatial grid for fast overlap detection
                    spatialGrid.insert(pad)
                }
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
    private func spawnPadChain(count: Int, startingFrom position: CGPoint, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, maxRegular: CGFloat, tadpoles: inout [Tadpole]) {
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
            
            let constrainedX = max(90, min(sceneSize.width - 90, targetX))
            var padPosition = CGPoint(x: constrainedX, y: targetY)
            
            let candidateRadius = CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
            var tries = 0
            while isOverlappingExisting(position: padPosition, candidateRadius: candidateRadius, lilyPads: lilyPads) && tries < 10 {
                padPosition.x = max(90, min(sceneSize.width - 90, padPosition.x + CGFloat.random(in: -40...40)))
                tries += 1
            }
            if isOverlappingExisting(position: padPosition, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                // Skip creating this pad if still overlapping after attempts
                continue
            }
            
            // Create the pad directly without complex validation (for emergency spawning)
            if let gs = scene as? GameScene, let wn = self.worldNode {
                let pad = makeLilyPad(
                    position: padPosition,
                    radius: candidateRadius,
                    frogPosition: gs.frogController.position,
                    tadpoles: &tadpoles,
                    worldNode: wn
                )
                pad.node.position = pad.position
                pad.node.zPosition = 10
                worldNode.addChild(pad.node)
                lilyPads.append(pad)
                
                // Register with spatial grid for fast overlap detection
                spatialGrid.insert(pad)
            }
            
            anchor = padPosition
        }
    }
    
    /// Fill only genuinely large gaps that would be unjumpable
    private func fillLargeGaps(frogPosition: CGPoint, maxRegular: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, tadpoles: inout [Tadpole]) {
        // Look further ahead to catch gaps before they become problematic
        let recentPads = lilyPads.filter { $0.position.y >= frogPosition.y - 200 && $0.position.y <= frogPosition.y + maxRegular * 3.0 }.sorted { $0.position.y < $1.position.y }
        
        guard recentPads.count >= 2 else { 
            // If we have fewer than 2 pads in our lookahead range, that's a problem
            print("🚨 Gap filling: Only \(recentPads.count) pads in range - creating emergency pads")
            let emergencyY = frogPosition.y + 200
            createReachablePad(from: frogPosition, targetY: emergencyY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, forceCreate: true)
            return 
        }
        
        var prev = recentPads.first!.position
        for pad in recentPads.dropFirst() {
            let dy = pad.position.y - prev.y
            let dx = abs(pad.position.x - prev.x)
            let totalDistance = sqrt(dx*dx + dy*dy)
            
            // CRITICAL FIX: Fill gaps that are close to the jump limit, not just beyond it
            if totalDistance > maxRegular * 0.9 {  // Reduced from 1.15 to 0.9 for earlier intervention
                print("🔧 Filling gap: distance \(Int(totalDistance)) vs max \(Int(maxRegular))")
                var currentAnchor = prev
                var gapsFilled = 0
                
                while (pad.position.y - currentAnchor.y) > maxRegular * 0.8 && gapsFilled < 5 {  // Prevent infinite loops
                    let nextY = currentAnchor.y + CGFloat.random(in: 120...150)  // Smaller, safer jumps
                    createReachablePad(from: currentAnchor, targetY: nextY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, forceCreate: true)
                    
                    if let newPad = lilyPads.last {
                        currentAnchor = newPad.position
                        gapsFilled += 1
                    } else {
                        break
                    }
                }
            }
            prev = pad.position
        }
    }
}

// MARK: - Spatial Grid for Performant Overlap Detection

/// A spatial partitioning data structure for fast lily pad overlap queries.
/// Divides space into grid cells and only checks lily pads in nearby cells.
class SpatialGrid {
    private let cellSize: CGFloat
    private var grid: [GridKey: [LilyPad]] = [:]
    
    init(cellSize: CGFloat) {
        self.cellSize = cellSize
    }
    
    /// Insert a lily pad into the spatial grid
    func insert(_ pad: LilyPad) {
        let keys = getKeysForPad(pad)
        for key in keys {
            if grid[key] == nil {
                grid[key] = []
            }
            grid[key]?.append(pad)
        }
    }
    
    /// Remove a lily pad from the spatial grid (useful if pads move or are destroyed)
    func remove(_ pad: LilyPad) {
        let keys = getKeysForPad(pad)
        for key in keys {
            grid[key]?.removeAll { $0 === pad }
            if grid[key]?.isEmpty == true {
                grid[key] = nil
            }
        }
    }
    
    /// Query lily pads near a position within a given radius
    func query(position: CGPoint, radius: CGFloat) -> [LilyPad] {
        let keys = getKeysForCircle(center: position, radius: radius)
        var result: Set<ObjectIdentifier> = Set()
        var pads: [LilyPad] = []
        
        for key in keys {
            if let cellPads = grid[key] {
                for pad in cellPads {
                    let id = ObjectIdentifier(pad)
                    if !result.contains(id) {
                        result.insert(id)
                        pads.append(pad)
                    }
                }
            }
        }
        
        return pads
    }
    
    /// Clear all lily pads from the grid
    func clear() {
        grid.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func getKeysForPad(_ pad: LilyPad) -> [GridKey] {
        return getKeysForCircle(center: pad.position, radius: pad.radius)
    }
    
    private func getKeysForCircle(center: CGPoint, radius: CGFloat) -> [GridKey] {
        let minX = Int((center.x - radius) / cellSize)
        let maxX = Int((center.x + radius) / cellSize)
        let minY = Int((center.y - radius) / cellSize)
        let maxY = Int((center.y + radius) / cellSize)
        
        var keys: [GridKey] = []
        for x in minX...maxX {
            for y in minY...maxY {
                keys.append(GridKey(x: x, y: y))
            }
        }
        return keys
    }
}

private struct GridKey: Hashable {
    let x: Int
    let y: Int
}

