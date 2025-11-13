//
//  SpawnManager.swift (UPDATED)
//  Enhanced lily pad path validation and tadpole distribution
//  SAFETY: Prevents tadpole spawning on shrinking (unsafe) pulsing lily pads
//

import SpriteKit

/// Manages spawning of game objects including lily pads, enemies, and tadpoles.
/// 
/// Key Safety Features:
/// - Prevents tadpole spawning on shrinking (unsafe) pulsing lily pads
/// - Ensures proper spacing and distribution of game objects
/// - Maintains performance through spatial grid optimization
class SpawnManager {
    weak var scene: SKScene?
    weak var worldNode: SKNode?
    
    // Pending enemies to add in the next update cycle to avoid simultaneous access
    private var pendingEnemies: [Enemy] = []
    
    // Level-based difficulty scaling - now uses LevelEnemyConfigManager
    var levelSpawnRateMultiplier: CGFloat = 1.0  // Legacy compatibility - will be replaced by level configs
    
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
    
    // Edge spike bush wall management
    private var lastWallSpawnY: CGFloat = -CGFloat.greatestFiniteMagnitude
    private let wallHorizontalOffset: CGFloat = 800
    
    // Tadpole pacing
    private var framesSinceLastTadpole: Int = 0
    private let tadpoleForceSpawnFrameThreshold: Int = 120 // ~2 seconds at 60fps
    private var lastTadpoleWorldY: CGFloat = -CGFloat.greatestFiniteMagnitude
    private let minTadpoleSpacingY: CGFloat = 180
    
    // Finish line management
    private var finishLinePosition: CGFloat = 25000.0  // Start at 25,000 points for first level
    private let levelPointIncrement: CGFloat = 25000.0 // Add 25,000 points per level
    
    // Probability to attach a tadpole to a newly spawned lily pad
    private var tadpolePerPadProbability: CGFloat {
        return GameConfig.tadpolePerPadProbability
    }
    
    /// Checks if a lily pad is safe for tadpole spawning.
    /// Returns false for pulsing lily pads since they are unsafe for tadpoles.
    /// Returns true for normal and moving lily pad types only.
    private func isSafeForTadpoleSpawn(_ pad: LilyPad) -> Bool {
        // SAFETY: Never spawn tadpoles on pulsing or grave lily pads since they can be unsafe
        if pad.type == .pulsing || pad.type == .grave {
            print("🚫 Lily pad at \(Int(pad.position.x)), \(Int(pad.position.y)) is \(pad.type) type - not safe for tadpole spawn")
            return false
        }
        // Only normal and moving lily pads are safe for tadpoles
        return true
    }
    
    /// Resets all spawn-related state so a new run starts fresh
    func reset(for lilyPads: inout [LilyPad], tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest]) {
        // Clear global tracking
        padsThatSpawnedTadpoles.removeAll()
        framesSinceLastTadpole = 0
        lastTadpoleWorldY = -CGFloat.greatestFiniteMagnitude
        lastWallSpawnY = -CGFloat.greatestFiniteMagnitude
        frameCount = 0
        lastBeeCount = 0
        lastLogCount = 0
        spawningPaused = false
        spawningPausedStartTime = 0  // Reset pause timer
        graceEndTime = 0
        
        // Reset finish line to starting position
        resetFinishLine()
        
        // Clear pending enemies
        pendingEnemies.removeAll()
        
        // Clear spatial grid
        spatialGrid.clear()
        
        // Clear existing tadpoles from scene and detach from pads
        for t in tadpoles {
            t.lilyPad?.clearTadpoles()
            t.node.removeFromParent()
        }
        tadpoles.removeAll()
        
        // Clear existing big honey pots from scene and detach from pads
        for bhp in bigHoneyPots {
            bhp.lilyPad?.clearBigHoneyPots()
            bhp.node.removeFromParent()
        }
        bigHoneyPots.removeAll()
        
        // Clear existing life vests from scene and detach from pads
        for lv in lifeVests {
            lv.lilyPad?.clearLifeVests()
            lv.node.removeFromParent()
        }
        lifeVests.removeAll()
        
        // Reset tadpole-related state on existing lily pads
        for pad in lilyPads {
            pad.clearTadpoles()
        }
        
        // Rebuild spatial grid with existing pads
        for pad in lilyPads {
            spatialGrid.insert(pad)
        }
        
        print("🔄 SpawnManager: Reset complete - all states cleared")
    }
    
    /// Clears the spatial grid completely - used when starting a new game
    func clearSpatialGrid() {
        spatialGrid.clear()
        print("🗂️ Spatial grid cleared for new game")
    }
    
    /// Updates the level-based spawn rate multiplier
    func updateSpawnRateMultiplier(_ multiplier: CGFloat) {
        levelSpawnRateMultiplier = multiplier
        print("📈 Spawn rate multiplier updated to: \(String(format: "%.2f", multiplier))x")
    }
    
    /// Gets the current finish line position (where the flag should be placed)
    func getCurrentFinishLinePosition() -> CGFloat {
        return finishLinePosition
    }
    
    /// Advances the finish line to the next level by setting it relative to the current score
    func advanceToNextLevel(currentScore: Int) {
        // Set the finish line to be currentScore + 25,000 points ahead
        finishLinePosition = CGFloat(currentScore) + levelPointIncrement
        print("🏁 Finish line advanced from current score \(currentScore) to: \(Int(finishLinePosition)) points for next level (+\(Int(levelPointIncrement)) points needed)")
    }
    
    /// Resets the finish line to the starting position (25,000 points from score 0)
    func resetFinishLine() {
        finishLinePosition = levelPointIncrement  // Start at 25,000 points from 0
        print("🏁 Finish line reset to: \(Int(finishLinePosition)) points for first level (need \(Int(levelPointIncrement)) points to complete)")
    }
    
    /// Checks if the current score has reached or exceeded the finish line
    func hasReachedFinishLine(currentScore: Int) -> Bool {
        return CGFloat(currentScore) >= finishLinePosition
    }
    
    /// Flushes pending enemies to the main enemies array safely
    /// This should be called from the game loop to avoid simultaneous access issues
    func flushPendingEnemies(to enemies: inout [Enemy]) {
        for enemy in pendingEnemies {
            enemies.append(enemy)
        }
        if !pendingEnemies.isEmpty {
            print("🔄 Flushed \(pendingEnemies.count) pending enemies to main array")
            pendingEnemies.removeAll()
        }
    }
    
    /// Adds a single lily pad to the spatial grid
    func addToSpatialGrid(_ pad: LilyPad) {
        spatialGrid.insert(pad)
        print("🗂️ Added lily pad at \(Int(pad.position.x)), \(Int(pad.position.y)) to spatial grid")
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
    private var spawningPausedStartTime: TimeInterval = 0
    private let maxAbilitySelectionTimeout: TimeInterval = 10.0  // 10 seconds maximum for ability selection
    var pauseSpawning: (() -> Void)?
    var resumeSpawning: (() -> Void)?
    
    // Public getter to check spawning state
    var isSpawningPaused: Bool {
        return spawningPaused
    }
    
    // MARK: - Lily Pad Factory with Integrated Spawn System
    private func makeLilyPad(position: CGPoint, radius: CGFloat, frogPosition: CGPoint, tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], enemies: inout [Enemy], worldNode: SKNode, existingLilyPads: [LilyPad]) -> LilyPad {
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        print("🎯 Creating lily pad with current score: \(currentScore)")
        
        let type: LilyPadType
        if currentScore < 500 {  // Start spawning grave pads earlier for testing
            // Early game: Mix of normal and some grave pads for testing
            let r = CGFloat.random(in: 0.0...1.0)
            if r < 0.85 { type = .normal }
            else { type = .grave }  // 15% grave pads for early testing
        } else if currentScore < 1000 {
            // Continue with mix including grave pads
            let r = CGFloat.random(in: 0.0...1.0)
            if r < 0.90 { type = .normal }
            else { type = .grave }  // 10% grave pads
        } else if currentScore < 8000 {
            // 1500-7999 points: 55% normal, 20% pulsing, 20% moving, 5% grave
            let r = CGFloat.random(in: 0.0...1.0)
            var proposedType: LilyPadType
            if r < 0.55  { proposedType = .normal }
            else if r < 0.75 { proposedType = .pulsing }
            else if r < 0.95 { proposedType = .moving }
            else { proposedType = .grave }
            
            // Apply pulsing pad clustering prevention
            if proposedType == .pulsing {
                type = shouldAllowPulsingPadAt(position: position, existingPads: existingLilyPads) ? .pulsing : .normal
                if type != proposedType {
                    print("🚫 Prevented pulsing pad clustering - converted to normal at \(Int(position.x)), \(Int(position.y))")
                }
            } else {
                type = proposedType
            }
        } else {
            // 8000+ points: More challenging mix including grave pads
            // 35% normal, 30% pulsing, 25% moving, 10% grave
            let r = CGFloat.random(in: 0.0...1.0)
            var proposedType: LilyPadType
            if r < 0.35 { proposedType = .normal }
            else if r < 0.65 { proposedType = .pulsing }
            else if r < 0.90 { proposedType = .moving }
            else { proposedType = .grave }
            
            // Apply pulsing pad clustering prevention
            if proposedType == .pulsing {
                type = shouldAllowPulsingPadAt(position: position, existingPads: existingLilyPads) ? .pulsing : .normal
                if type != proposedType {
                    print("🚫 Prevented pulsing pad clustering - converted to normal at \(Int(position.x)), \(Int(position.y))")
                }
            } else {
                type = proposedType
            }
        }
        
        let pad = LilyPad(position: position, radius: radius, type: type)
        
        if type == .moving {
            pad.screenWidthProvider = { [weak self] in
                return (self?.scene as? GameScene)?.size.width ?? 1024
            }
            pad.movementSpeed = 120.0
            pad.startMovingIfNeeded()
        }
        
        // PERFORMANCE OPTIMIZATION: Spawn items/enemies at lily pad creation time
        // This eliminates the need for multiple search passes and ensures proper placement
        spawnItemsOnNewLilyPad(pad: pad, frogPosition: frogPosition, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies, worldNode: worldNode, currentScore: currentScore)
        
        return pad
    }
    
    /// Efficiently spawn items and enemies on a newly created lily pad
    /// This consolidates all spawn logic into a single pass for better performance
    private func spawnItemsOnNewLilyPad(pad: LilyPad, frogPosition: CGPoint, tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], enemies: inout [Enemy], worldNode: SKNode, currentScore: Int) {
        
        // SAFETY: Never spawn anything on unsafe lily pad types
        let isSafeForSpawning = isSafeForTadpoleSpawn(pad)
        
        // Don't spawn anything behind the frog
        guard pad.position.y > frogPosition.y + 40 else { return }
        
        // Don't reuse pads that have already been processed
        let padId = ObjectIdentifier(pad)
        guard !padsThatSpawnedTadpoles.contains(padId) else { return }
        
        // Grave pads should not spawn tadpoles or big honey pots; only chasers are allowed
        let isGravePad = pad.type == .grave
        
        // Calculate spawn probabilities based on game state
        let tadpoleChance = (!isGravePad && isSafeForSpawning) ? tadpolePerPadProbability : 0.0
        let bigHoneyPotChance: CGFloat = (!isGravePad && isSafeForSpawning) ? 0.15 : 0.0  // 15% chance for big honey pots
        let lifeVestChance: CGFloat = (!isGravePad && isSafeForSpawning) ? 0.08 : 0.0  // 8% chance for life vests (rarer than honey pots)
        
        // Enemy spawn chances based on current score and grace period
        let inGrace = CACurrentMediaTime() < graceEndTime
        var enemyChance: CGFloat = 0.0
        if !inGrace {
            if isGravePad {
                // 100% chance to spawn chaser on grave pads (always spawn chasers)
                enemyChance = 1.0
                print("🏴‍☠️ Grave pad guaranteed chaser spawn at \(Int(pad.position.x)), \(Int(pad.position.y))")
            } else if isSafeForSpawning {
                // For other pads, only spawn enemies if safe for spawning
                // Apply level-based spawn rate multiplier
                let baseChance = GameConfig.enemySpawnRate * 0.3  // Lower chance per pad since we're doing it at spawn time
                enemyChance = baseChance * levelSpawnRateMultiplier
            }
        } else if isGravePad {
            print("🏴‍☠️ Grave pad in grace period - no chaser spawning")
        }
        
        // Priority system: Try to spawn items in order of importance
        var itemSpawned = false
        
        // 1. Try to spawn tadpole (highest priority for game progression)
        if !itemSpawned && CGFloat.random(in: 0.0...1.0) < tadpoleChance {
            let tadpole = Tadpole(position: pad.position)
            tadpole.lilyPad = pad
            tadpole.node.position = pad.position
            tadpole.node.zPosition = 50
            worldNode.addChild(tadpole.node)
            tadpoles.append(tadpole)
            
            // Mark this pad as used and reset forced spawn timer
            padsThatSpawnedTadpoles.insert(padId)
            framesSinceLastTadpole = 0
            lastTadpoleWorldY = pad.position.y
            itemSpawned = true
            
            print("🐸 Spawned tadpole on new safe pad (type: \(pad.type)) at \(Int(pad.position.x)), \(Int(pad.position.y))")
        }
        
        // 2. Try to spawn big honey pot (if no tadpole spawned)
        if !itemSpawned && CGFloat.random(in: 0.0...1.0) < bigHoneyPotChance {
            let bigHoneyPot = BigHoneyPot(position: pad.position)
            
            // CRITICAL FIX: Ensure proper lily pad linking
            bigHoneyPot.lilyPad = pad
            pad.addBigHoneyPot(bigHoneyPot)  // Explicitly add to lily pad's collection
            
            bigHoneyPot.node.position = pad.position
            bigHoneyPot.node.position.y += 5  // Small visual offset above lily pad center
            bigHoneyPot.node.zPosition = 50
            worldNode.addChild(bigHoneyPot.node)
            bigHoneyPots.append(bigHoneyPot)
            itemSpawned = true
            
            print("🍯 Spawned big honey pot on new pad (type: \(pad.type)) at \(Int(pad.position.x)), \(Int(pad.position.y))")
        }
        
        // 2.5. Try to spawn life vest (if no other item spawned)
        if !itemSpawned && CGFloat.random(in: 0.0...1.0) < lifeVestChance {
            let lifeVest = LifeVest(position: pad.position)
            
            // CRITICAL FIX: Ensure proper lily pad linking
            lifeVest.lilyPad = pad
            pad.addLifeVest(lifeVest)  // Explicitly add to lily pad's collection
            
            lifeVest.node.position = pad.position
            lifeVest.node.position.y += 5  // Small visual offset above lily pad center
            lifeVest.node.zPosition = 50
            worldNode.addChild(lifeVest.node)
            lifeVests.append(lifeVest)
            itemSpawned = true
            
            print("🦺 Spawned life vest on new pad (type: \(pad.type)) at \(Int(pad.position.x)), \(Int(pad.position.y))")
        }
        
        // 3. Try to spawn enemy (if no items spawned and pad can accommodate)
        if !itemSpawned && CGFloat.random(in: 0.0...1.0) < enemyChance {
            var allowedTypes: [EnemyType] = []
            if isGravePad {
                // Grave pads ONLY spawn chasers - guaranteed
                allowedTypes = [.chaser]
                print("🏴‍☠️ Grave pad detected - forcing chaser spawn at \(Int(pad.position.x)), \(Int(pad.position.y))")
            } else {
                // Regular pads get normal enemy type selection
                allowedTypes = getAllowedEnemyTypes(forScore: currentScore, pad: pad)
            }
            
            if let enemyType = allowedTypes.randomElement() {
                // Use weighted selection if available for this level, otherwise fall back to random
                let level = (currentScore / 25000) + 1
                let weightedType = LevelEnemyConfigManager.getWeightedRandomEnemyType(for: level)
                let finalType = (weightedType != nil && allowedTypes.contains(weightedType!)) ? weightedType! : enemyType
                spawnEnemyOnPad(type: finalType, pad: pad, enemies: &enemies, worldNode: worldNode, currentScore: currentScore)
                print("🐛 Spawned \(finalType) on new pad at \(Int(pad.position.x)), \(Int(pad.position.y))")
            } else {
                print("⚠️ No enemy types available for spawning on pad at \(Int(pad.position.x)), \(Int(pad.position.y))")
            }
        } else if isGravePad {
            let randomRoll = CGFloat.random(in: 0.0...1.0)
            print("🏴‍☠️ Grave pad enemy spawn blocked - itemSpawned: \(itemSpawned), enemyChance: \(enemyChance), roll: \(randomRoll)")
        }
    }
    
    /// Get allowed enemy types for a specific score and lily pad using the new configuration system
    private func getAllowedEnemyTypes(forScore score: Int, pad: LilyPad) -> [EnemyType] {
        // Only allow enemies that can be accommodated by this pad type
        guard pad.canAccommodateEnemyType(.bee) else { return [] }  // Basic check
        
        // Grave pads should only ever spawn chasers
        if pad.type == .grave {
            return [.chaser]
        }
        
        // Get level-based configuration
        let level = max(1, (score / 25000) + 1) // Ensure level is at least 1
        let levelConfig = LevelEnemyConfigManager.getConfig(for: level)
        
        // Filter enemy types that can spawn on pads
        let allowedTypes = levelConfig.enemyConfigs.compactMap { enemyConfig -> EnemyType? in
            // Check if this enemy type can spawn on lily pads
            guard enemyConfig.canSpawnOnPads else { return nil }
            
            // Check if the lily pad can accommodate this enemy type
            guard pad.canAccommodateEnemyType(enemyConfig.enemyType) else { return nil }
            
            return enemyConfig.enemyType
        }
        
        return allowedTypes
    }
    
    /// Spawn a specific enemy type on a lily pad
    private func spawnEnemyOnPad(type: EnemyType, pad: LilyPad, enemies: inout [Enemy], worldNode: SKNode, currentScore: Int) {
        let enemy: Enemy
        
        switch type {
        case .bee:
            // Check bee count limits
            if let gameScene = scene as? GameScene {
                let visibleBeeCount = countBeesInVisibleWindow(enemies: enemies, worldOffset: gameScene.worldManager.worldNode.position.y, sceneSize: gameScene.size)
                if visibleBeeCount >= maxBeesPerScreen {
                    return  // Skip if at bee limit
                }
            }
            
            // Create bee with score-based speed variation
            let base = GameConfig.beeSpeed
            let tier = min(3, (currentScore / 5000))
            let variance: CGFloat
            switch tier {
            case 0: variance = 0.20
            case 1: variance = 0.35
            case 2: variance = 0.50
            default: variance = 0.60
            }
            let factor = 1.0 + CGFloat.random(in: -variance...variance)
            let beeSpeed = max(40, base * factor)
            
            enemy = Enemy(type: .bee, position: pad.position, speed: beeSpeed)
            
        case .dragonfly:
            enemy = Enemy(type: .dragonfly, position: pad.position, speed: GameConfig.dragonflySpeed)
            
        case .spikeBush:
            enemy = Enemy(type: .spikeBush, position: pad.position, speed: 0.0)
            
        case .chaser:
            // Chasers only spawn on grave lily pads and only when frog is visible
            guard pad.type == .grave else { return }
            
            // Get visibility parameters for chaser spawning
            guard let gameScene = scene as? GameScene else { return }
            let worldOffset = gameScene.worldManager.worldNode.position.y
            let sceneSize = gameScene.size
            
            // Use the lily pad's visibility-aware spawning method
            guard let spawnedChaser = pad.maybeSpawnChaser(
                targeting: gameScene.frogController,
                baseSpeed: GameConfig.chaserSpeed,
                worldOffset: worldOffset,
                sceneSize: sceneSize
            ) else { return }
            
            enemy = spawnedChaser
            
        default:
            return  // Don't spawn other types on pads
        }
        
        // Set up enemy
        enemy.targetLilyPad = pad
        pad.addEnemyType(type)
        enemy.node.position = enemy.position
        enemy.node.zPosition = 50
        worldNode.addChild(enemy.node)
        enemies.append(enemy)
    }
    
    /// Attempts to spawn a tadpole on a newly created pad based on probability.
    /// Ensures we never spawn behind the frog and never reuse the same pad twice.
    /// SAFETY: Never spawns tadpoles on shrinking (unsafe) pulsing lily pads.
    private func maybeAttachTadpole(to pad: LilyPad, frogPosition: CGPoint, tadpoles: inout [Tadpole], worldNode: SKNode) {
        // Do not spawn if pad is at or behind the frog
        guard pad.position.y > frogPosition.y + 40 else { return }
        
        // SAFETY CHECK: Do not spawn tadpoles on shrinking pulsing lily pads
        guard isSafeForTadpoleSpawn(pad) else { return }
        
        // Only if pad does not already have tadpoles and has never spawned one
        let id = ObjectIdentifier(pad)
        //   guard !pad.hasTadpoles && !padsThatSpawnedTadpoles.contains(id) else { return }
        
        // Probability gate
        if CGFloat.random(in: 0.0...1.0) > tadpolePerPadProbability { return }
        
        
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
        print("ðŸ¸ (auto) Spawned tadpole on safe new pad (type: \(pad.type)) at \(Int(pad.position.x)), \(Int(pad.position.y))")
    }
    
    /// Checks all lily pads to see if any need special handling
    private func checkSpecialPadBehavior(lilyPads: [LilyPad], enemiesSnapshot: [Enemy], worldNode: SKNode) {
        guard let gameScene = scene as? GameScene else { return }
        
        let worldOffset = gameScene.worldManager.worldNode.position.y
        let visibleMinY = -worldOffset - 100  // Small margin below screen
        let visibleMaxY = -worldOffset + gameScene.size.height + 100  // Small margin above screen
        
        // Find pads that are now in view and might need special handling
        let padsInView = lilyPads.filter { pad in
            pad.position.y >= visibleMinY &&
            pad.position.y <= visibleMaxY
        }
        
        // Handle special behavior for different pad types
        for pad in padsInView {
            switch pad.type {
            case .normal:
                break // No special behavior
            case .pulsing:
                // Pulsing behavior is handled by the pad itself
                break
            case .moving:
                // Moving behavior is handled by the pad itself
                break
            case .grave:
                // Check if this grave pad needs a chaser spawned
                checkAndSpawnChaserOnGravePad(pad, gameScene: gameScene, enemiesSnapshot: enemiesSnapshot, worldNode: worldNode)
                break
            }
        }
        
        // Debug: Occasionally log grave pad visibility
        if frameCount % 60 == 0 { // Every second
            let gravePadsInView = padsInView.filter { $0.type == .grave }
            if !gravePadsInView.isEmpty {
                print("🏴‍☠️ DEBUG: \(gravePadsInView.count) grave pad(s) currently in view")
            }
        }
    }
    
    /// Check if a grave lily pad needs a chaser spawned and spawn one if appropriate
    private func checkAndSpawnChaserOnGravePad(_ pad: LilyPad, gameScene: GameScene, enemiesSnapshot: [Enemy], worldNode: SKNode) {
        // Only process grave pads
        guard pad.type == .grave else { return }
        
        // SAFETY: Use read-only snapshot to avoid exclusivity violations with inout enemies
        let hasExistingChaser = enemiesSnapshot.contains { enemy in
            enemy.type == .chaser && enemy.targetLilyPad === pad
        }
        if hasExistingChaser { return }
        
        // Check if this pad already has a chaser in pending enemies
        // Note: We only check pending enemies to avoid simultaneous access issues
        // The main game loop will handle checking existing enemies before calling this method
        let hasPendingChaser = pendingEnemies.contains { enemy in
            enemy.type == .chaser && enemy.targetLilyPad === pad
        }
        
        if hasPendingChaser {
            return // Already has a pending chaser, don't spawn another
        }
        
        // Check if we're in a grace period
        let inGrace = CACurrentMediaTime() < graceEndTime
        if inGrace {
            return // Don't spawn during grace period
        }
        
        // Get visibility parameters for chaser spawning
        let worldOffset = gameScene.worldManager.worldNode.position.y
        let sceneSize = gameScene.size
        
        // Use the lily pad's visibility-aware spawning method
        guard let spawnedChaser = pad.maybeSpawnChaser(
            targeting: gameScene.frogController,
            baseSpeed: GameConfig.chaserSpeed,
            worldOffset: worldOffset,
            sceneSize: sceneSize
        ) else {
            return // Chaser spawn failed (could be due to probability or visibility)
        }
        
        // Set up the chaser
        spawnedChaser.targetLilyPad = pad
        pad.addEnemyType(.chaser)
        spawnedChaser.node.position = spawnedChaser.position
        spawnedChaser.node.zPosition = 50
        worldNode.addChild(spawnedChaser.node)
        
        // Add to the pending enemies to avoid simultaneous access issues
        pendingEnemies.append(spawnedChaser)
        
        print("🏴‍☠️ Spawned visibility-based chaser on grave pad at \(Int(pad.position.x)), \(Int(pad.position.y))")
    }
    
    /// Potentially spawns special effects or enemies based on lily pad type
    private func maybeSpawnSpecialEffectFromPad(_ pad: LilyPad, worldNode: SKNode) {
        // Get current score from the game scene
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        
        // Check if we're in visible screen area
        guard let gameScene = scene as? GameScene else { return }
        let worldOffset = gameScene.worldManager.worldNode.position.y
        let visibleMinY = -worldOffset - 100  // Small margin below screen
        let visibleMaxY = -worldOffset + gameScene.size.height + 100  // Small margin above screen
        
        // Only process pads in the visible area
        guard pad.position.y >= visibleMinY && pad.position.y <= visibleMaxY else { return }
        
        // Handle special effects based on pad type and score
        switch pad.type {
        case .normal:
            break // No special effects
        case .pulsing:
            // Pulsing pads could have visual effects when they pulse
            break
        case .moving:
            // Moving pads could have trailing effects
            break
        case .grave:
            // ghosts
            break
        }
        
        print("🎪 Processed special effects for \(pad.type) lily pad at \(Int(pad.position.x)), \(Int(pad.position.y))")
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
        spawningPausedStartTime = CACurrentMediaTime()
        print("⏸️ SpawnManager: Spawning paused for ability selection")
        
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
        print("✅ SpawnManager: Spawning resumed after ability selection")
    }
    
    // MARK: - Pulsing Pad Clustering Prevention
    
    /// Checks if a pulsing lily pad can be placed at the given position without creating clusters of more than 2.
    /// Returns true if the pad can be placed, false if it would violate the clustering rule.
    private func shouldAllowPulsingPadAt(position: CGPoint, existingPads: [LilyPad]) -> Bool {
        // Use the provided lily pads array to avoid simultaneous access issues
        let allPads = existingPads
        
        // Use configurable values for cluster detection
        let clusterRadius = GameConfig.pulsingPadClusterRadius
        let maxAllowed = GameConfig.maxPulsingPadsInCluster
        
        // Find all pulsing pads near the proposed position
        let nearbyPulsingPads = allPads.filter { pad in
            guard pad.type == .pulsing else { return false }
            let dx = pad.position.x - position.x
            let dy = pad.position.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            return distance <= clusterRadius
        }
        
        // If there are already maxAllowed or more pulsing pads nearby, don't allow another one
        if nearbyPulsingPads.count >= maxAllowed {
            print("🚫 Blocking pulsing pad at \(Int(position.x)), \(Int(position.y)) - found \(nearbyPulsingPads.count) nearby pulsing pads (max: \(maxAllowed))")
            return false
        }
        
        return true
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
    
    // FIXED: Improved overlap check with consistent spacing and comprehensive detection
    private func isOverlappingExisting(position: CGPoint, candidateRadius: CGFloat, lilyPads: [LilyPad], extraPadding: CGFloat = 20.0) -> Bool {
        // CRITICAL: Enforce consistent minimum 75-pixel spacing between lily pad centers
        let minimumSpacing: CGFloat = 75.0
        
        // Use spatial grid for O(1) average case lookup instead of O(n) linear search
        let searchRadius = max(minimumSpacing + candidateRadius, candidateRadius + extraPadding + GameConfig.maxLilyPadRadius)
        let nearbyPads = spatialGrid.query(position: position, radius: searchRadius)
        
        for pad in nearbyPads {
            let dx = position.x - pad.position.x
            let dy = position.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Use the larger of minimum spacing or radius-based separation
            let radiusBasedSeparation = pad.radius + candidateRadius + extraPadding
            let requiredSeparation = max(minimumSpacing, radiusBasedSeparation)
            
            if distance < requiredSeparation {
                return true
            }
        }
        return false
    }
    
    /// FIXED: Thread-safe lily pad creation with proper spatial grid management
    private func createLilyPadSafely(position: CGPoint, radius: CGFloat, lilyPads: inout [LilyPad], worldNode: SKNode, tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], enemies: inout [Enemy], allowForceCreate: Bool = false) -> Bool {
        // Always check for overlap before creating, even when force creating
        let standardPadding: CGFloat = 20.0
        
        // Final validation: Never create overlapping pads
        if isOverlappingExisting(position: position, candidateRadius: radius, lilyPads: lilyPads, extraPadding: standardPadding) {
            
            return false
        }
        
        if let gs = scene as? GameScene, let wn = self.worldNode {
            let pad = makeLilyPad(
                position: position,
                radius: radius,
                frogPosition: gs.frogController.position,
                tadpoles: &tadpoles,
                bigHoneyPots: &bigHoneyPots,
                lifeVests: &lifeVests,
                enemies: &enemies,
                worldNode: wn,
                existingLilyPads: lilyPads
            )
            pad.node.position = pad.position
            pad.node.zPosition = 10
            worldNode.addChild(pad.node)
            lilyPads.append(pad)
            
            // CRITICAL: Add to spatial grid IMMEDIATELY after adding to array
            spatialGrid.insert(pad)
            
            return true
        }
        return false
    }
    
    private func createReachablePad(from position: CGPoint, targetY: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], enemies: inout [Enemy], forceCreate: Bool = false) {
        let maxDist = GameConfig.maxRegularJumpDistance * 0.85  // Ensure it's definitely reachable
        let minDist: CGFloat = 80  // Reduced minimum distance for easier placement
        
        // Check if frog is sliding on ice - if so, constrain horizontal variation much more
        var horizontalVariation: CGFloat = 100
        var isOnIce = false
        if let gameScene = scene as? GameScene, gameScene.frogController.onIce {
            horizontalVariation = 25  // Much smaller horizontal variation when sliding (reduced from 40)
            isOnIce = true
            print("🧊 Constraining horizontal pad variation due to ice sliding")
        }
        
        var bestCandidate: (position: CGPoint, radius: CGFloat)? = nil
        var bestDistance: CGFloat = 0
        
        // Try to find a good position - more attempts when on ice for better placement
        let maxAttempts = isOnIce ? 30 : 20  // More attempts when on ice to find non-overlapping spots
        for attempt in 0..<maxAttempts {
            let xVariation = CGFloat.random(in: -horizontalVariation...horizontalVariation)
            let x = max(90, min(sceneSize.width - 90, position.x + xVariation))
            let candidate = CGPoint(x: x, y: targetY)
            let candidateRadius = CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
            
            let dx = candidate.x - position.x
            let dy = candidate.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance > minDist && distance < maxDist && dy > 0 {
                // FIXED: Use consistent padding and safer creation
                if !isOverlappingExisting(position: candidate, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                    if createLilyPadSafely(position: candidate, radius: candidateRadius, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies) {
                        print("✅ Created reachable pad at distance \(Int(distance)) from \(Int(position.y)) to \(Int(candidate.y))")
                        return
                    }
                }
                
                // Track the best valid position even if it overlaps
                if distance > bestDistance {
                    bestDistance = distance
                    bestCandidate = (candidate, candidateRadius)
                }
            }
        }
        
        // FIXED: More careful fallback logic that maintains spacing requirements
        if forceCreate, let best = bestCandidate {
            var finalPosition = best.position
            let finalRadius = best.radius
            
            // Try to adjust position to avoid overlap
            var adjustAttempts = 0
            while isOverlappingExisting(position: finalPosition, candidateRadius: finalRadius, lilyPads: lilyPads) && adjustAttempts < 20 {
                finalPosition.x = max(90, min(sceneSize.width - 90, finalPosition.x + CGFloat.random(in: -40...40)))
                finalPosition.y += CGFloat.random(in: -15...15)
                adjustAttempts += 1
            }
            
            // Only create if we successfully found a non-overlapping position
            if !isOverlappingExisting(position: finalPosition, candidateRadius: finalRadius, lilyPads: lilyPads) {
                if createLilyPadSafely(position: finalPosition, radius: finalRadius, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies, allowForceCreate: true) {
                    let actualDistance = sqrt(pow(finalPosition.x - position.x, 2) + pow(finalPosition.y - position.y, 2))
                    print("⚠️ Force created pad at distance \(Int(actualDistance)) after \(adjustAttempts) position adjustments")
                }
            }
        }
    }
    
    /// Spawns paired edge spike bushes (left and right) at the given world Y to create containment walls.
    /// Ensures placement respects margins and avoids excessive duplication by spacing in Y.
    private func spawnEdgeWalls(at worldY: CGFloat, sceneSize: CGSize, enemies: inout [Enemy], worldNode: SKNode) {
        // PERFORMANCE FIX: More conservative spacing to prevent excessive spawning
        let minWallVerticalSpacing: CGFloat = 200  // Increased from 100 to 200
        if worldY - lastWallSpawnY < minWallVerticalSpacing { return }
        
        // Compute target X positions around the screen center ± offset, clamped within margins
        let centerX = sceneSize.width / 2
        let leftX = max(GameConfig.edgeSpikeBushMargin, centerX - wallHorizontalOffset)
        let rightX = min(sceneSize.width - GameConfig.edgeSpikeBushMargin, centerX + wallHorizontalOffset)
        
        // If the left and right would collapse into margins (very narrow screens), skip
        if rightX - leftX < 2 * GameConfig.edgeSpikeBushMargin { return }
        
        // PERFORMANCE FIX: More strict duplicate checking with wider range
        let existingNearY = enemies.contains { enemy in
            guard enemy.type == .edgeSpikeBush else { return false }
            return abs(enemy.position.y - worldY) < 150  // Increased from 80 to 150
        }
        if existingNearY { return }
        
        // PERFORMANCE FIX: Limit total number of edge spike bushes in the scene
        let currentEdgeBushCount = enemies.filter { $0.type == .edgeSpikeBush }.count
        if currentEdgeBushCount >= 30 {  // Hard limit to prevent excessive accumulation
            return
        }
        
        // Create left bush
        let leftBush = Enemy(
            type: .edgeSpikeBush,
            position: CGPoint(x: leftX, y: worldY),
            speed: 0.0
        )
        leftBush.node.position = leftBush.position
        leftBush.node.zPosition = 50
        worldNode.addChild(leftBush.node)
        enemies.append(leftBush)
        
        // Create right bush
        let rightBush = Enemy(
            type: .edgeSpikeBush,
            position: CGPoint(x: rightX, y: worldY),
            speed: 0.0
        )
        rightBush.node.position = rightBush.position
        rightBush.node.zPosition = 50
        worldNode.addChild(rightBush.node)
        enemies.append(rightBush)
        
        lastWallSpawnY = worldY
        print("🌿 Spawned edge walls at y=\(Int(worldY)) leftX=\(Int(leftX)) rightX=\(Int(rightX)) (total: \(currentEdgeBushCount + 2))")
    }
    
    // MARK: - Initial Spawn
    
    func spawnInitialObjects(sceneSize: CGSize, lilyPads: inout [LilyPad], enemies: inout [Enemy], tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], worldOffset: CGFloat) {
        guard let worldNode = worldNode else { return }
        
        print("🌸 spawnInitialObjects CALLED - starting lily pads count: \(lilyPads.count)")
        
        // CRITICAL FIX: Start from the actual starting lily pad position, not an arbitrary position
        // The starting lily pad is at (sceneSize.width/2, 0) in world coordinates
        var lastPosition = CGPoint(x: sceneSize.width / 2, y: 0)
        
        // If there's already a starting pad in the array, use its position
        if let startingPad = lilyPads.first {
            lastPosition = startingPad.position
            print("🌸 Using existing starting pad position: \(lastPosition)")
        } else {
            print("🌸 Using default starting position: \(lastPosition)")
        }
        
        // IMPROVED: Spawn initial lily pads with more relaxed constraints
        var successfulSpawns = 0
        for i in 1..<40 {
            // Much smaller Y increment to ensure reachable jumps
            let targetY = lastPosition.y + CGFloat.random(in: 100...140)  // Reduced from 120...180
            
            // More generous distance limits for initial spawning
            let maxDist = GameConfig.maxRegularJumpDistance * 0.85  // Slightly more conservative
            let minDist: CGFloat = 70  // Reduced minimum distance
            let candidateRadius = CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
            
            // Try to find a candidate that meets distance and maintains proper spacing
            var foundCandidate: CGPoint? = nil
            for attempt in 0..<25 {  // Increased attempts from 20 to 25
                let x = CGFloat.random(in: 80...sceneSize.width - 80)  // More margin
                let candidate = CGPoint(x: x, y: targetY)
                
                let dx = candidate.x - lastPosition.x
                let dy = candidate.y - lastPosition.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance < maxDist && distance > minDist && !isOverlappingExisting(position: candidate, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                    foundCandidate = candidate
                    break
                } else if attempt % 5 == 4 {  // Every 5th attempt, log why it failed
                    let reasons = [
                        distance >= maxDist ? "too far (\(Int(distance)) >= \(Int(maxDist)))" : nil,
                        distance <= minDist ? "too close (\(Int(distance)) <= \(Int(minDist)))" : nil,
                        isOverlappingExisting(position: candidate, candidateRadius: candidateRadius, lilyPads: lilyPads) ? "overlapping" : nil
                    ].compactMap { $0 }
                    print("🌸 Attempt \(attempt + 1) failed: \(reasons.joined(separator: ", "))")
                }
            }
            
            if let finalPosition = foundCandidate {
                if createLilyPadSafely(position: finalPosition, radius: candidateRadius, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies) {
                    lastPosition = finalPosition
                    successfulSpawns += 1
                    if i <= 5 || successfulSpawns % 10 == 0 {
                        print("🌸 ✅ Successfully spawned pad #\(successfulSpawns) at \(Int(finalPosition.x)), \(Int(finalPosition.y))")
                    }
                }
            } else {
                print("⚠️ Skipping initial pad #\(i) - could not find non-overlapping position after 25 attempts")
                
                // FALLBACK: If we can't find a perfect spot, try a simpler approach
                if successfulSpawns < 5 {  // Only if we haven't spawned many pads yet
                    let fallbackY = lastPosition.y + 150
                    let fallbackX = lastPosition.x + CGFloat.random(in: -60...60)
                    let fallbackPos = CGPoint(x: max(80, min(sceneSize.width - 80, fallbackX)), y: fallbackY)
                    let fallbackRadius = GameConfig.minLilyPadRadius
                    
                    if !isOverlappingExisting(position: fallbackPos, candidateRadius: fallbackRadius, lilyPads: lilyPads) {
                        if createLilyPadSafely(position: fallbackPos, radius: fallbackRadius, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies) {
                            lastPosition = fallbackPos
                            successfulSpawns += 1
                            print("🌸 🆘 Created fallback pad #\(successfulSpawns) at \(Int(fallbackPos.x)), \(Int(fallbackPos.y))")
                        }
                    }
                }
            }
        }
        
        print("🌸 🏁 FINAL: Spawned \(successfulSpawns) lily pads successfully (total in array: \(lilyPads.count))")
        
        // Seed initial edge walls near the top of the initial band
        let initialWallY = lastPosition.y + 200  // Place walls ahead of the spawned pads
        //spawnEdgeWalls(at: initialWallY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode)
    }
    
    // MARK: - Continuous Spawn
    
    // Performance tracking
    private var frameCount = 0
    private var lastBeeCount = 0
    
    /// CRITICAL SAFETY: Ensures frog always has reachable lily pads ahead
    private func ensureFrogCanProgress(frogPosition: CGPoint, lilyPads: inout [LilyPad], sceneSize: CGSize, worldNode: SKNode, tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], enemies: inout [Enemy]) {
        let maxJump = GameConfig.maxRegularJumpDistance
        
        // Check if frog is sliding on ice - if so, use a more conservative horizontal check
        // to avoid spawning tons of pads based on temporary horizontal displacement
        var effectiveFrogPosition = frogPosition
        var isOnIce = false
        if let gameScene = scene as? GameScene, gameScene.frogController.onIce {
            // When sliding on ice, use the center of the screen as the reference point
            // to prevent spawning pads based on temporary horizontal sliding
            effectiveFrogPosition.x = sceneSize.width / 2
            isOnIce = true
            print("🧊 Ice sliding detected - using screen center for pad spawning logic")
        }
        
        // Find all pads the frog can currently reach
        let reachablePads = lilyPads.filter { pad in
            let dx = pad.position.x - effectiveFrogPosition.x
            let dy = pad.position.y - effectiveFrogPosition.y
            let distance = sqrt(dx*dx + dy*dy)
            return dy > 0 && distance <= maxJump  // Only pads ahead and within jump range
        }
        
        // CRITICAL FIX: When on ice, be much more conservative about emergency spawning
        // Only create emergency pads if there are truly no reachable pads
        if reachablePads.isEmpty {
            print("🆘 CRITICAL SAFETY: Frog has NO reachable pads! Creating emergency path")
            
            // When on ice, create fewer pads and with stricter spacing
            let padCount = isOnIce ? 2 : 3  // Fewer pads when sliding on ice
            let minSpacing: CGFloat = isOnIce ? 150 : 120  // Greater minimum spacing on ice
            
            // Create an immediate reachable pad
            let horizontalVariation: CGFloat = isOnIce ? 40 : 80  // Much smaller horizontal variation on ice
            let emergencyPosition = CGPoint(
                x: effectiveFrogPosition.x + CGFloat.random(in: -horizontalVariation...horizontalVariation),
                y: effectiveFrogPosition.y + CGFloat.random(in: minSpacing...(minSpacing + 40))
            )
            
            // Ensure no overlap before creating emergency pad
            let candidateRadius = CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
            if !isOverlappingExisting(position: emergencyPosition, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                if createLilyPadSafely(position: emergencyPosition, radius: candidateRadius, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies, allowForceCreate: true) {
                    print("🆘 Created emergency lily pad at \(Int(emergencyPosition.x)), \(Int(emergencyPosition.y))")
                    
                    // Create a few more to ensure a path forward, but with strict spacing
                    if let newPad = lilyPads.last {
                        var anchor = newPad.position
                        for i in 0..<padCount {
                            let nextY = anchor.y + CGFloat.random(in: minSpacing...(minSpacing + 40))
                            let nextX = anchor.x + CGFloat.random(in: -20...20)  // Very small horizontal variation
                            let nextPosition = CGPoint(x: nextX, y: nextY)
                            let nextRadius = CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius)
                            
                            // Only create if no overlap
                            if !isOverlappingExisting(position: nextPosition, candidateRadius: nextRadius, lilyPads: lilyPads) {
                                if createLilyPadSafely(position: nextPosition, radius: nextRadius, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies) {
                                    anchor = nextPosition
                                    print("🆘 Created follow-up emergency pad #\(i+1)")
                                }
                            } else {
                                print("🧊 Skipping overlapping emergency pad #\(i+1)")
                            }
                        }
                    }
                }
            } else {
                print("🧊 Emergency pad would overlap - attempting alternative position")
                // Try a few alternative positions
                for alternativeAttempt in 0..<5 {
                    let altPosition = CGPoint(
                        x: effectiveFrogPosition.x + CGFloat.random(in: -horizontalVariation...horizontalVariation),
                        y: effectiveFrogPosition.y + CGFloat.random(in: minSpacing...(minSpacing + 60))
                    )
                    if !isOverlappingExisting(position: altPosition, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                        if createLilyPadSafely(position: altPosition, radius: candidateRadius, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies, allowForceCreate: true) {
                            print("🆘 Created alternative emergency lily pad after \(alternativeAttempt+1) attempts")
                            break
                        }
                    }
                }
            }
        }
    }
    
    func spawnObjects(sceneSize: CGSize, lilyPads: inout [LilyPad], enemies: inout [Enemy], tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], worldOffset: CGFloat, frogPosition: CGPoint, superJumpActive: Bool) {
        guard let worldNode = worldNode else { return }
        
        frameCount += 1
        framesSinceLastTadpole += 1
        
        // Update snake animations based on visibility
        if frameCount % 10 == 0 {  // Check every 10 frames for performance
            for enemy in enemies where enemy.type == .snake {
                enemy.updateVisibilityAnimation(worldOffset: worldOffset, sceneHeight: sceneSize.height)
            }
        }
        
        // CRITICAL SAFETY CHECK: Ensure frog can always progress (reduced frequency to prevent cascading)
        if frameCount % 30 == 0 {  // Check every 30 frames instead of 5 to reduce cascading spawning
            ensureFrogCanProgress(frogPosition: frogPosition, lilyPads: &lilyPads, sceneSize: sceneSize, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies)
        }
        
        // Check if frog is sliding on ice - if so, reduce spawning to avoid over-spawning
        var shouldReduceSpawning = false
        var isOnIce = false
        if let gameScene = scene as? GameScene, gameScene.frogController.onIce {
            shouldReduceSpawning = true
            isOnIce = true
            // Reduce spawn frequency when sliding on ice by checking every 30 frames instead of 5
            if frameCount % 30 != 0 {
                return  // Skip most spawning cycles when sliding
            }
            print("🧊 Significantly reducing spawn frequency due to ice sliding")
        }
        
        // If spawning is paused (during ability selection), don't spawn enemies or tadpoles
        if spawningPaused {
            // SAFETY: Check for timeout to prevent permanent stuck states
            let currentTime = CACurrentMediaTime()
            if currentTime - spawningPausedStartTime > maxAbilitySelectionTimeout {
                print("🚨 SpawnManager: Ability selection timeout detected - auto-resuming spawning")
                print("🚨 Spawning was paused for \(Int(currentTime - spawningPausedStartTime)) seconds")
                spawningPaused = false
                spawningPausedStartTime = 0
                
                // Notify the game that we've auto-resumed due to timeout
                if let gameScene = scene as? GameScene {
                    print("🚨 Notifying GameScene of spawn manager timeout recovery")
                    // This should trigger the GameScene to also clear its stuck state
                }
            } else {
                return
            }
        }
        
        // Calculate the spawn point (where new objects appear ahead of the player)
        let spawnWorldY = -worldOffset + sceneSize.height + 100
        
        // Continuously maintain edge spike bush walls along the path
        let inGraceForWalls = CACurrentMediaTime() < graceEndTime
        if !inGraceForWalls {
            //spawnEdgeWalls(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode)
        }
        
        let dynamicScrollSpeed = 1.0
        
        let maxRegular = GameConfig.maxRegularJumpDistance * 0.85
        
        // CRITICAL FIX: Ensure sufficient lily pad density to prevent gaps
        // When on ice, use much more conservative spawning to prevent over-generation
        let baseDesiredPads = isOnIce ? 8 : (superJumpActive ? 20 : 15)  // Much fewer pads when sliding on ice
        let speedMultiplier = min(2.5, max(1.2, dynamicScrollSpeed / GameConfig.scrollSpeed))  // Allow higher multiplier
        let desiredPadsAhead = isOnIce ? baseDesiredPads : Int(CGFloat(baseDesiredPads) * speedMultiplier)  // No multiplier on ice
        
        let lookaheadDistance = isOnIce ? maxRegular * 1.2 : maxRegular * 2.0 * speedMultiplier  // Much shorter lookahead on ice
        
        let padsAheadList = lilyPads.filter { $0.position.y > frogPosition.y }.sorted { $0.position.y < $1.position.y }
        let furthestAhead = padsAheadList.last
        
        // Calculate how far ahead we have coverage
        let currentCoverage = (furthestAhead?.position.y ?? frogPosition.y) - frogPosition.y
        
        // CRITICAL FIX: More aggressive emergency spawning to prevent gaps
        // When on ice, use much more conservative thresholds
        let criticalPadThreshold = isOnIce ? max(3, desiredPadsAhead / 3) : max(8, desiredPadsAhead / 2)  // Much lower threshold on ice
        let criticalCoverageThreshold = isOnIce ? lookaheadDistance * 0.4 : lookaheadDistance * 0.6  // Lower coverage threshold on ice
        
        if padsAheadList.count < criticalPadThreshold || currentCoverage < criticalCoverageThreshold {
            // CRITICAL: When on ice, spawn fewer emergency pads
            let emergencyPads = isOnIce ? max(2, criticalPadThreshold - padsAheadList.count) : max(6, desiredPadsAhead - padsAheadList.count)
            print("🚨 EMERGENCY: Spawning \(emergencyPads) pads - only \(padsAheadList.count) ahead, coverage: \(Int(currentCoverage))")
            spawnPadChain(count: emergencyPads, startingFrom: furthestAhead?.position ?? frogPosition, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, maxRegular: maxRegular, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies)
        }
        
        // CRITICAL FIX: Check for gaps more frequently to prevent holes
        if frameCount % 5 == 0 {  // Back to every 5 frames for safety
            ensurePadsAtSpawnPoint(spawnWorldY: spawnWorldY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, maxRegular: maxRegular, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies)
        }
        
        var anchor = furthestAhead?.position ?? frogPosition
        var padsToEnsure = max(0, desiredPadsAhead - padsAheadList.count)
        
        // CRITICAL FIX: When on ice, be much more conservative about pad spawning
        if isOnIce {
            padsToEnsure = max(padsToEnsure, 0)  // Don't force minimum spawning on ice
            padsToEnsure = min(padsToEnsure, 2)  // Cap at 2 pads when sliding on ice
        } else {
            padsToEnsure = max(padsToEnsure, 1)  // Always spawn at least 1 pad per frame when not on ice
            padsToEnsure = min(padsToEnsure, 6)  // But cap at reasonable limit
        }
        
        // Additional pads during super jump (but not when on ice)
        if superJumpActive && !isOnIce && currentCoverage < lookaheadDistance * 0.7 {
            padsToEnsure = min(padsToEnsure + 3, 8)  // More pads for super jump
        }
        
        // If we have NO pads ahead at all, this is critical - spawn many (unless on ice)
        if padsAheadList.isEmpty {
            padsToEnsure = isOnIce ? 3 : desiredPadsAhead  // Much fewer when on ice
            print("🆘 CRITICAL: No pads ahead of frog! Spawning \(padsToEnsure) pads immediately")
        }
        
        // Create forward pads with horizontal variation for multiple paths
        // Check if ice sliding to reduce horizontal variation
        var baseHorizontalVariation: CGFloat = 80
        if let gameScene = scene as? GameScene, gameScene.frogController.onIce {
            baseHorizontalVariation = 30  // Much smaller variation when sliding
        }
        
        for i in 0..<padsToEnsure {
            let minSpacing: CGFloat = 125
            let maxSpacing = min(maxRegular * 0.9, 190)
            let targetY = anchor.y + CGFloat.random(in: minSpacing...maxSpacing)
            
            // Add horizontal variation to create left/center/right path options
            var targetAnchor = anchor
            if i % 3 == 0 {
                targetAnchor.x = max(100, anchor.x - CGFloat.random(in: 30...baseHorizontalVariation))
            } else if i % 3 == 2 {
                targetAnchor.x = min(sceneSize.width - 100, anchor.x + CGFloat.random(in: 30...baseHorizontalVariation))
            } else {
                targetAnchor.x = anchor.x + CGFloat.random(in: -40...40)
            }
            
            createReachablePad(from: targetAnchor, targetY: targetY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies)
            if let newPad = lilyPads.last {
                anchor = newPad.position
            }
        }
        
        // PERFORMANCE FIX: Gap checking every 10 frames for better coverage
        framesSinceLastPathCheck += 1
        if framesSinceLastPathCheck >= 10 {  // More frequent gap checking
            framesSinceLastPathCheck = 0
            fillLargeGaps(frogPosition: frogPosition, maxRegular: maxRegular, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies)
        }
        
        // PERFORMANCE FIX: More frequent edge spike bush cleanup to prevent accumulation
        if frameCount % 180 == 0 {  // Every 3 seconds at 60 FPS
            cullExcessEdgeSpikeBushes(enemies: &enemies, frogPosition: frogPosition, sceneSize: sceneSize)
        }
        
        // PERFORMANCE FIX: Cull distant lily pads to prevent memory bloat and maintain performance
        if frameCount % 200 == 0 {  // Every 5 seconds at 60 FPS
            cullDistantLilyPads(lilyPads: &lilyPads, frogPosition: frogPosition, sceneSize: sceneSize, worldNode: worldNode)
        }
        
        // Spawn enemies, tadpoles, and logs
        let inGrace = CACurrentMediaTime() < graceEndTime
        
        // Pass a value copy to avoid simultaneous access to enemies while mutating
        if frameCount % 10 == 0 {  // Check every 10 frames for better responsiveness (grace period check is inside)
            checkSpecialPadBehavior(lilyPads: lilyPads, enemiesSnapshot: enemies, worldNode: worldNode)
        }
        
        // Use new level-based enemy configuration system
        let currentScore: Int = (scene as? GameScene)?.score ?? 0
        let level = max(1, (currentScore / 25000) + 1) // Ensure level is at least 1
        let levelConfig = LevelEnemyConfigManager.getConfig(for: level)
        
        // DEBUG: Log spawn attempt occasionally with new level-based info
        if frameCount % 180 == 0 {  // Every 3 seconds
            print("🐛 DEBUG Level \(level): Score=\(currentScore), inGrace=\(inGrace), spawningPaused=\(spawningPaused)")
            print("🐛 Level config enemy count: \(levelConfig.enemyConfigs.count)")
            for enemyConfig in levelConfig.enemyConfigs {
                let finalRate = enemyConfig.spawnRate * levelConfig.globalSpawnRateMultiplier
                print("🐛   \(enemyConfig.enemyType): rate=\(String(format: "%.3f", finalRate)), max=\(enemyConfig.maxCount), canSpawnInWater=\(enemyConfig.canSpawnInWater)")
            }
        }
        
        if !inGrace && !spawningPaused {
            // Use new level-based configuration for individual enemy spawn attempts
            for enemyConfig in levelConfig.enemyConfigs {
                // Skip if this enemy can't spawn in water
                guard enemyConfig.canSpawnInWater else { continue }
                
                // Calculate final spawn rate for this enemy type
                let finalSpawnRate = enemyConfig.spawnRate * levelConfig.globalSpawnRateMultiplier
                
                // Check if we should attempt to spawn this enemy type this frame
                if CGFloat.random(in: 0.0...1.0) < finalSpawnRate {
                    // Check individual type constraints
                    var canSpawn = true
                    switch enemyConfig.enemyType {
                    case .bee:
                        if frameCount % 8 == 0 {
                            lastBeeCount = countBeesInVisibleWindow(enemies: enemies, worldOffset: worldOffset, sceneSize: sceneSize)
                        }
                        canSpawn = lastBeeCount < min(enemyConfig.maxCount, maxBeesPerScreen)
                    case .log:
                        if frameCount % 8 == 0 {
                            lastLogCount = countLogsInVisibleWindow(enemies: enemies, worldOffset: worldOffset, sceneSize: sceneSize)
                        }
                        canSpawn = lastLogCount < min(enemyConfig.maxCount, maxLogsPerScreen)
                    default:
                        // For other enemy types, just check the level-specific max count
                        let currentCount = enemies.filter { $0.type == enemyConfig.enemyType }.count
                        canSpawn = currentCount < enemyConfig.maxCount
                    }
                    
                    if canSpawn {
                        print("🐛 DEBUG Level \(level): Spawning \(enemyConfig.enemyType) in water (rate: \(String(format: "%.3f", finalSpawnRate)))")
                        spawnEnemy(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode, lilyPads: lilyPads)
                        
                        // Update cached counts
                        if enemyConfig.enemyType == .bee {
                            lastBeeCount += 1
                        } else if enemyConfig.enemyType == .log {
                            lastLogCount += 1
                        }
                        
                        // Only spawn one enemy per frame to avoid overwhelming
                        break
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
            
            // Spawn BigHoneyPots occasionally - rare special collectibles
            if !inGrace && frameCount % 60 == 0 { // Spawn attempt every 5 seconds (300 frames at 60fps)
                let bigHoneyPotSpawnChance: CGFloat = 0.15 // 15% chance when the interval triggers
                if CGFloat.random(in: 0...1) < bigHoneyPotSpawnChance {
                    spawnBigHoneyPot(at: spawnWorldY, sceneSize: sceneSize, lilyPads: lilyPads, bigHoneyPots: &bigHoneyPots, worldNode: worldNode, frogPosition: frogPosition)
                }
            }
            
            // Spawn LifeVests occasionally - very rare special collectibles
            if !inGrace && frameCount % 90 == 0 { // Spawn attempt every 1.5 seconds (90 frames at 60fps)
                let lifeVestSpawnChance: CGFloat = 0.08 // 8% chance when the interval triggers (rarer than honey pots)
                if CGFloat.random(in: 0...1) < lifeVestSpawnChance {
                    spawnLifeVest(at: spawnWorldY, sceneSize: sceneSize, lilyPads: lilyPads, lifeVests: &lifeVests, worldNode: worldNode, frogPosition: frogPosition)
                }
            }
            
            // PERFORMANCE OPTIMIZED: More frequent log spawning with smart management
            // Only spawn logs when score is above 5000, with enhanced spawn rate
            if !inGrace && currentScore > 5000 {
                let totalLogCount = enemies.filter({ $0.type == .log }).count
                
                // More frequent culling for better performance with higher log counts
                if frameCount % 20 == 0 {  // Every 20 frames instead of 30
                    cullDistantLogs(enemies: &enemies, worldOffset: worldOffset, sceneSize: sceneSize)
                }
                
                // Allow more total logs but maintain visible screen limit
                if lastLogCount < maxLogsPerScreen && totalLogCount < maxTotalLogs {
                    // ENHANCED: Apply level-based spawn rate multiplier to logs as well
                    let baseLogSpawnChance = GameConfig.logSpawnRate * 0.8  // Increased from 60% to 80%
                    let logSpawnChance = baseLogSpawnChance * levelSpawnRateMultiplier
                    if CGFloat.random(in: 0.0...1.0) < logSpawnChance {
                        spawnLog(at: spawnWorldY, sceneSize: sceneSize, enemies: &enemies, worldNode: worldNode)
                        lastLogCount += 1  // Update cached count immediately
                    }
                }
            }
            
#if DEBUG
            // DEBUG: Validate no overlapping pads every 5 seconds in debug builds
            if frameCount % 300 == 0 {
                validateNoOverlappingPads(lilyPads: lilyPads)
            }
#endif
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
            let level = max(1, (currentScore / 25000) + 1) // Ensure level is at least 1
            let levelConfig = LevelEnemyConfigManager.getConfig(for: level)
            
            // Use weighted selection from level configuration
            guard let selectedType = LevelEnemyConfigManager.getWeightedRandomEnemyType(for: level) else {
                print("🐛 No enemy types configured for level \(level)")
                return
            }
            
            // Check if we can spawn this enemy type (respect max counts)
            let maxCount = LevelEnemyConfigManager.getMaxCount(for: selectedType, at: level)
            let currentCount = enemies.filter { $0.type == selectedType }.count
            
            if currentCount >= maxCount {
                print("🐛 Cannot spawn \(selectedType): at max count (\(currentCount)/\(maxCount))")
                return
            }
            
            // Additional specific checks for certain enemy types
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
                    // Spawn 250 pixels to the left of the target lily pad
                    enemy = Enemy(
                        type: selectedType,
                        position: CGPoint(
                            x: targetPad.position.x - 350,  // 250 pixels left of lily pad
                            y: targetPad.position.y
                        ),
                        speed: GameConfig.snakeSpeed  // Always positive (left to right)
                    )
                    enemy.targetLilyPad = targetPad
                    targetPad.addEnemyType(selectedType)
                } else {
                    // Fallback: spawn from the left side if no lily pad found
                    enemy = Enemy(
                        type: selectedType,
                        position: CGPoint(
                            x: -30,  // Fallback to left side
                            y: worldY
                        ),
                        speed: GameConfig.snakeSpeed  // Always positive (left to right)
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
                
            case .spikeBush:
                // Spike bushes are static and should be placed on lily pads
                if let targetPad = findSuitableLilyPad(for: selectedType, near: worldY, sceneSize: sceneSize, lilyPads: lilyPads) {
                    enemy = Enemy(
                        type: selectedType,
                        position: targetPad.position,
                        speed: 0.0  // Static, no movement
                    )
                    enemy.targetLilyPad = targetPad
                    targetPad.addEnemyType(selectedType)
                } else {
                    // If no suitable lily pad, don't spawn the spike bush
                    return
                }
                
            case .edgeSpikeBush:
                // Edge spike bushes are static and should be placed at screen edges
                let isLeft = Bool.random()
                let xPosition = isLeft ? GameConfig.edgeSpikeBushMargin : sceneSize.width - GameConfig.edgeSpikeBushMargin
                enemy = Enemy(
                    type: selectedType,
                    position: CGPoint(x: xPosition, y: worldY),
                    speed: 0.0  // Static, no movement
                )
                
            case .log:
                // Logs move horizontally across the screen
                let fromLeft = Bool.random()
                enemy = Enemy(
                    type: .log,
                    position: CGPoint(
                        x: fromLeft ? -GameConfig.logWidth : sceneSize.width + GameConfig.logWidth,
                        y: worldY
                    ),
                    speed: fromLeft ? GameConfig.logSpeed : -GameConfig.logSpeed
                )
                
            case .chaser:
                // Chasers are spawned through special game mechanics
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
                // Only include pads that don't currently have tadpoles AND are safe for tadpole spawning
                return !pad.hasTadpoles && isSafeForTadpoleSpawn(pad)
            }
            
            // FIXED: Only use pads that have never spawned a tadpole AND don't currently have one
            // Do NOT fall back to pads that might have tadpoles
            var candidates = availablePads
            
            // Removed reservation logic; select candidate directly without reservation
            var selectedPadCandidate: LilyPad? = candidates.randomElement()
            
            // Fallback: try a limited set of recent pads ahead that have NEVER spawned a tadpole and are currently empty AND safe
            if selectedPadCandidate == nil {
                let recentAhead = lilyPads.filter { $0.position.y > frogPosition.y }.suffix(20)
                if let pad = recentAhead.first(where: { pad in
                    let id = ObjectIdentifier(pad)
                    return !padsThatSpawnedTadpoles.contains(id) && !pad.hasTadpoles && isSafeForTadpoleSpawn(pad)
                }) {
                    selectedPadCandidate = pad
                }
            }
            
            guard let selectedPad = selectedPadCandidate else {
                return false
            }
            
            // FINAL SAFETY CHECK: Ensure the selected pad is still safe for tadpole spawning
            guard isSafeForTadpoleSpawn(selectedPad) else {
                print("🚫 Aborting tadpole spawn - selected lily pad became unsafe for tadpole spawning at \(Int(selectedPad.position.x)), \(Int(selectedPad.position.y))")
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
            print("ðŸ¸ Spawned tadpole on safe lily pad (type: \(selectedPad.type)) at \(Int(selectedPad.position.x)), \(Int(selectedPad.position.y))")
            return true
        }
        
        @discardableResult
        private func spawnBigHoneyPot(at worldY: CGFloat, sceneSize: CGSize, lilyPads: [LilyPad], bigHoneyPots: inout [BigHoneyPot], worldNode: SKNode, frogPosition: CGPoint) -> Bool {
            // Find suitable lily pads for big honey pot spawning
            // Requirements: lily pad must be empty (no tadpole, no enemy, no existing big honey pot)
            let suitablePads = lilyPads.filter { pad in
                let yDist = abs(pad.position.y - worldY)
                let xOk = pad.position.x > 80 && pad.position.x < sceneSize.width - 80
                return yDist < 400 && xOk
            }
            
            // Avoid spawning near the frog
            let safeDistanceFromFrog: CGFloat = 150
            let padsAwayFromFrog = suitablePads.filter { pad in
                let dx = pad.position.x - frogPosition.x
                let dy = pad.position.y - frogPosition.y
                let dist = sqrt(dx*dx + dy*dy)
                return dist >= safeDistanceFromFrog
            }
            
            // Only use lily pads that are completely empty: no tadpoles, no enemies, no big honey pots
            let availablePads = padsAwayFromFrog.filter { pad in
                return !pad.hasTadpoles &&
                !pad.hasBigHoneyPots &&
                pad.occupyingEnemyTypes.isEmpty &&
                isSafeForTadpoleSpawn(pad) // Use same safety rules as tadpoles
            }
            
            guard let selectedPad = availablePads.randomElement() else {
                return false
            }
            
            // Final safety check
            guard isSafeForTadpoleSpawn(selectedPad) else {
                print("🚫 Aborting big honey pot spawn - selected lily pad became unsafe")
                return false
            }
            
            // Spawn the big honey pot on the selected pad
            let bigHoneyPot = BigHoneyPot(position: selectedPad.position)
            
            // CRITICAL FIX: Ensure proper lily pad linking
            bigHoneyPot.lilyPad = selectedPad
            selectedPad.addBigHoneyPot(bigHoneyPot)  // Explicitly add to lily pad's collection
            
            bigHoneyPot.node.position = selectedPad.position
            bigHoneyPot.node.position.y += 5  // Small visual offset above lily pad center
            bigHoneyPot.node.zPosition = 50
            worldNode.addChild(bigHoneyPot.node)
            bigHoneyPots.append(bigHoneyPot)
            print("🍯 Spawned big honey pot on lily pad (type: \(selectedPad.type)) at \(Int(selectedPad.position.x)), \(Int(selectedPad.position.y))")
            return true
        }
        
        @discardableResult
        private func spawnLifeVest(at worldY: CGFloat, sceneSize: CGSize, lilyPads: [LilyPad], lifeVests: inout [LifeVest], worldNode: SKNode, frogPosition: CGPoint) -> Bool {
            // Find suitable lily pads for life vest spawning
            // Requirements: lily pad must be empty (no tadpole, no enemy, no existing life vest, no big honey pot)
            let suitablePads = lilyPads.filter { pad in
                let yDist = abs(pad.position.y - worldY)
                let xOk = pad.position.x > 80 && pad.position.x < sceneSize.width - 80
                return yDist < 400 && xOk
            }
            
            // Avoid spawning near the frog
            let safeDistanceFromFrog: CGFloat = 150
            let padsAwayFromFrog = suitablePads.filter { pad in
                let dx = pad.position.x - frogPosition.x
                let dy = pad.position.y - frogPosition.y
                let dist = sqrt(dx*dx + dy*dy)
                return dist >= safeDistanceFromFrog
            }
            
            // Only use lily pads that are completely empty: no tadpoles, no enemies, no big honey pots, no life vests
            let availablePads = padsAwayFromFrog.filter { pad in
                return !pad.hasTadpoles &&
                !pad.hasBigHoneyPots &&
                !pad.hasLifeVests &&
                pad.occupyingEnemyTypes.isEmpty &&
                isSafeForTadpoleSpawn(pad) // Use same safety rules as tadpoles
            }
            
            guard let selectedPad = availablePads.randomElement() else {
                return false
            }
            
            // Final safety check
            guard isSafeForTadpoleSpawn(selectedPad) else {
                print("🚫 Selected lily pad at \(Int(selectedPad.position.x)), \(Int(selectedPad.position.y)) became unsafe during life vest spawn")
                return false
            }
            
            // Spawn the life vest on the selected pad
            let lifeVest = LifeVest(position: selectedPad.position)
            
            // CRITICAL FIX: Ensure proper lily pad linking
            lifeVest.lilyPad = selectedPad
            selectedPad.addLifeVest(lifeVest)  // Explicitly add to lily pad's collection
            
            lifeVest.node.position = selectedPad.position
            lifeVest.node.position.y += 5  // Small visual offset above lily pad center
            lifeVest.node.zPosition = 50
            worldNode.addChild(lifeVest.node)
            lifeVests.append(lifeVest)
            print("🦺 Spawned life vest on lily pad (type: \(selectedPad.type)) at \(Int(selectedPad.position.x)), \(Int(selectedPad.position.y))")
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
        private func ensurePadsAtSpawnPoint(spawnWorldY: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, maxRegular: CGFloat, tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], enemies: inout [Enemy]) {
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
                    
                    if !isOverlappingExisting(position: finalPosition, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                        if createLilyPadSafely(position: finalPosition, radius: candidateRadius, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies) {
                        }
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
        private func spawnPadChain(count: Int, startingFrom position: CGPoint, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, maxRegular: CGFloat, tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], enemies: inout [Enemy]) {
            var anchor = position
            
            // Check if ice sliding to reduce horizontal spreading
            var horizontalSpread: CGFloat = 70
            if let gameScene = scene as? GameScene, gameScene.frogController.onIce {
                horizontalSpread = 30  // Much smaller spread when sliding
                print("🧊 Reducing pad chain horizontal spread due to ice sliding")
            }
            
            for i in 0..<count {
                let minSpacing: CGFloat = 130
                let maxSpacing = min(maxRegular * 0.85, 180)
                let targetY = anchor.y + CGFloat.random(in: minSpacing...maxSpacing)
                
                // Alternate between left, center, and right paths
                var targetX = anchor.x
                if i % 3 == 0 {
                    targetX = max(90, anchor.x - CGFloat.random(in: 20...horizontalSpread))
                } else if i % 3 == 2 {
                    targetX = min(sceneSize.width - 90, anchor.x + CGFloat.random(in: 20...horizontalSpread))
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
                
                if !isOverlappingExisting(position: padPosition, candidateRadius: candidateRadius, lilyPads: lilyPads) {
                    if createLilyPadSafely(position: padPosition, radius: candidateRadius, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies) {
                        anchor = padPosition
                        print("✅ Created pad chain element #\(i+1) at \(Int(padPosition.x)), \(Int(padPosition.y))")
                    }
                } else {
                    print("⚠️ Skipping pad chain element #\(i+1) - would violate spacing requirements")
                    // Still advance anchor to prevent getting stuck
                    anchor.y = targetY
                }
            }
        }
        
        /// Fill only genuinely large gaps that would be unjumpable
        private func fillLargeGaps(frogPosition: CGPoint, maxRegular: CGFloat, sceneSize: CGSize, lilyPads: inout [LilyPad], worldNode: SKNode, tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], lifeVests: inout [LifeVest], enemies: inout [Enemy]) {
            // Look further ahead to catch gaps before they become problematic
            let recentPads = lilyPads.filter { $0.position.y >= frogPosition.y - 200 && $0.position.y <= frogPosition.y + maxRegular * 3.0 }.sorted { $0.position.y < $1.position.y }
            
            guard recentPads.count >= 2 else {
                // If we have fewer than 2 pads in our lookahead range, that's a problem
                print("🚨 Gap filling: Only \(recentPads.count) pads in range - creating emergency pads")
                let emergencyY = frogPosition.y + 200
                createReachablePad(from: frogPosition, targetY: emergencyY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies, forceCreate: true)
                return
            }
            
            var prev = recentPads.first!.position
            for pad in recentPads.dropFirst() {
                let dy = pad.position.y - prev.y
                let dx = abs(pad.position.x - prev.x)
                let totalDistance = sqrt(dx*dx + dy*dy)
                
                // CRITICAL FIX: Only fill gaps that are genuinely too large (increased threshold)
                if totalDistance > maxRegular * 1.15 {  // Much higher threshold - only fill actually impossible gaps
                    print("🔧 Filling gap: distance \(Int(totalDistance)) vs max \(Int(maxRegular))")
                    
                    // Calculate exactly how many intermediate pads we need
                    let gapSize = totalDistance
                    let maxSafeJump = maxRegular * 0.8
                    let numberOfPadsNeeded = max(1, Int(ceil(gapSize / maxSafeJump)) - 1)
                    let actualPadsToCreate = min(numberOfPadsNeeded, 2)  // Never create more than 2 at once
                    
                    var currentAnchor = prev
                    var gapsFilled = 0
                    
                    for _ in 0..<actualPadsToCreate {
                        let progress = CGFloat(gapsFilled + 1) / CGFloat(actualPadsToCreate + 1)
                        let nextY = prev.y + (pad.position.y - prev.y) * progress
                        let padCountBefore = lilyPads.count
                        
                        createReachablePad(from: currentAnchor, targetY: nextY, sceneSize: sceneSize, lilyPads: &lilyPads, worldNode: worldNode, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests, enemies: &enemies, forceCreate: true)
                        
                        // Always advance the anchor to prevent infinite loops
                        if lilyPads.count > padCountBefore, let newPad = lilyPads.last {
                            currentAnchor = newPad.position
                            gapsFilled += 1
                            print("🔧 Gap fill #\(gapsFilled): Created pad at Y=\(Int(newPad.position.y))")
                        } else {
                            // Emergency: Force advance to prevent infinite loop
                            currentAnchor.y = nextY
                            gapsFilled += 1
                            print("⚠️ Gap fill #\(gapsFilled): No pad created, advancing anchor to Y=\(Int(nextY))")
                            break  // If we can't create pads, stop trying
                        }
                    }
                    
                    print("✅ Gap filling complete: created \(gapsFilled) pads for distance \(Int(totalDistance))")
                }
                prev = pad.position
            }
        }
        
        /// PERFORMANCE FIX: Remove lily pads that are far behind the frog to prevent memory bloat
        private func cullDistantLilyPads(lilyPads: inout [LilyPad], frogPosition: CGPoint, sceneSize: CGSize, worldNode: SKNode) {
            let cullBehindY = frogPosition.y - sceneSize.height * 2.0  // Remove pads 2 screen heights behind frog
            let initialCount = lilyPads.count
            
            // Find lily pads to remove
            let indicesToRemove = lilyPads.enumerated().compactMap { index, pad in
                return pad.position.y < cullBehindY ? index : nil
            }.sorted(by: >)  // Remove from back to front to maintain valid indices
            
            // Remove pads from scene, spatial grid, and array
            for index in indicesToRemove {
                let pad = lilyPads[index]
                
                // Clear any tadpoles on this pad
                pad.clearTadpoles()
                
                // Remove from spatial grid
                spatialGrid.remove(pad)
                
                // Remove from scene
                pad.node.removeFromParent()
                
                // Remove from array
                lilyPads.remove(at: index)
            }
            
            let removedCount = indicesToRemove.count
            if removedCount > 0 {
                print("🧹 Culled \(removedCount) distant lily pads (was \(initialCount), now \(lilyPads.count))")
            }
        }
        
        /// DEBUG: Validate that no lily pads are overlapping (call periodically for debugging)
        func validateNoOverlappingPads(lilyPads: [LilyPad]) -> Bool {
            var hasOverlaps = false
            let minimumSpacing: CGFloat = 75.0
            
            for i in 0..<lilyPads.count {
                for j in (i+1)..<lilyPads.count {
                    let pad1 = lilyPads[i]
                    let pad2 = lilyPads[j]
                    
                    let dx = pad1.position.x - pad2.position.x
                    let dy = pad1.position.y - pad2.position.y
                    let distance = sqrt(dx * dx + dy * dy)
                    
                    let radiusBasedSeparation = pad1.radius + pad2.radius + 20.0  // Standard padding
                    let requiredSeparation = max(minimumSpacing, radiusBasedSeparation)
                    
                    if distance < requiredSeparation {
                        
                        hasOverlaps = true
                    }
                }
            }
            
            if !hasOverlaps {
                print("✅ Validation passed: No overlapping lily pads detected among \(lilyPads.count) pads")
            }
            return !hasOverlaps
        }
        
        /// PERFORMANCE: Central cleanup method to call all cleanup functions
        func performCleanup(lilyPads: inout [LilyPad], enemies: inout [Enemy], frogPosition: CGPoint, sceneSize: CGSize, worldNode: SKNode) {
            // Cleanup distant lily pads
            cullDistantLilyPads(lilyPads: &lilyPads, frogPosition: frogPosition, sceneSize: sceneSize, worldNode: worldNode)
            
            // Cleanup distant enemies (logs, etc.)
            cullDistantEnemies(enemies: &enemies, frogPosition: frogPosition, sceneSize: sceneSize)
            
            // PERFORMANCE FIX: Specific cleanup for edge spike bushes
            cullExcessEdgeSpikeBushes(enemies: &enemies, frogPosition: frogPosition, sceneSize: sceneSize)
            
            // Enforce maximum object limits
            enforceObjectLimits(lilyPads: &lilyPads, enemies: &enemies, frogPosition: frogPosition, worldNode: worldNode)
        }
        
        /// PERFORMANCE FIX: Remove enemies that are far behind the frog
        private func cullDistantEnemies(enemies: inout [Enemy], frogPosition: CGPoint, sceneSize: CGSize) {
            let cullBehindY = frogPosition.y - sceneSize.height * 2.0
            let cullAheadY = frogPosition.y + sceneSize.height * 3.0
            
            let indicesToRemove = enemies.enumerated().compactMap { index, enemy in
                return (enemy.position.y < cullBehindY || enemy.position.y > cullAheadY) ? index : nil
            }.sorted(by: >)
            
            for index in indicesToRemove {
                enemies[index].node.removeFromParent()
                enemies.remove(at: index)
            }
            
            if !indicesToRemove.isEmpty {
                print("🧹 Culled \(indicesToRemove.count) distant enemies")
            }
        }
        
        /// PERFORMANCE FIX: Aggressive cleanup of edge spike bushes to prevent accumulation
        private func cullExcessEdgeSpikeBushes(enemies: inout [Enemy], frogPosition: CGPoint, sceneSize: CGSize) {
            // More aggressive culling for edge spike bushes since they're static and can accumulate
            let cullBehindY = frogPosition.y - sceneSize.height * 1.5  // Closer cull distance
            let cullAheadY = frogPosition.y + sceneSize.height * 2.0   // Don't need as many ahead
            
            // Find all edge spike bushes
            let edgeBushes = enemies.enumerated().compactMap { index, enemy in
                enemy.type == .edgeSpikeBush ? (index: index, enemy: enemy) : nil
            }
            
            // Remove bushes outside the tighter bounds
            let indicesToRemove = edgeBushes.compactMap { item in
                let y = item.enemy.position.y
                return (y < cullBehindY || y > cullAheadY) ? item.index : nil
            }.sorted(by: >)
            
            for index in indicesToRemove {
                enemies[index].node.removeFromParent()
                enemies.remove(at: index)
            }
            
            // Also enforce a maximum count of edge spike bushes
            let maxEdgeBushes = 20  // Reasonable limit for edge bushes
            let remainingEdgeBushes = enemies.enumerated().compactMap { index, enemy in
                enemy.type == .edgeSpikeBush ? (index: index, enemy: enemy, distance: abs(enemy.position.y - frogPosition.y)) : nil
            }.sorted { $0.distance > $1.distance }  // Sort by distance from frog (furthest first)
            
            if remainingEdgeBushes.count > maxEdgeBushes {
                let excessBushes = Array(remainingEdgeBushes.prefix(remainingEdgeBushes.count - maxEdgeBushes))
                let excessIndices = excessBushes.map { $0.index }.sorted(by: >)
                
                for index in excessIndices {
                    enemies[index].node.removeFromParent()
                    enemies.remove(at: index)
                }
                
                print("🌿 Culled \(excessIndices.count) excess edge spike bushes (limit: \(maxEdgeBushes))")
            }
            
            let totalRemoved = indicesToRemove.count + (remainingEdgeBushes.count > maxEdgeBushes ? remainingEdgeBushes.count - maxEdgeBushes : 0)
            if totalRemoved > 0 {
                print("🧹 Culled \(totalRemoved) edge spike bushes for performance")
            }
        }
        
        /// PERFORMANCE FIX: Enforce maximum object limits by removing oldest objects
        private func enforceObjectLimits(lilyPads: inout [LilyPad], enemies: inout [Enemy], frogPosition: CGPoint, worldNode: SKNode) {
            // Enforce lily pad limit
            if lilyPads.count > GameConfig.maxActiveLilyPads {
                let excessCount = lilyPads.count - GameConfig.maxActiveLilyPads
                
                // Sort lily pads by distance from frog (furthest first)
                let indexedPads = lilyPads.enumerated().map { index, pad in
                    let distance = abs(pad.position.y - frogPosition.y)
                    return (index: index, distance: distance)
                }
                
                let sortedByDistance = indexedPads.sorted { $0.distance > $1.distance }
                let limitedPads = Array(sortedByDistance.prefix(excessCount))
                let indices = limitedPads.map { $0.index }
                let sortedIndices = indices.sorted(by: >)
                
                for index in sortedIndices {
                    let pad = lilyPads[index]
                    pad.clearTadpoles()
                    spatialGrid.remove(pad)
                    pad.node.removeFromParent()
                    lilyPads.remove(at: index)
                }
                
                print("🧹 Enforced lily pad limit: removed \(excessCount) pads (now \(lilyPads.count))")
            }
            
            // Enforce enemy limit
            if enemies.count > GameConfig.maxActiveEnemies {
                let excessCount = enemies.count - GameConfig.maxActiveEnemies
                
                // Remove oldest/furthest enemies
                let indexedEnemies = enemies.enumerated().map { index, enemy in
                    let distance = abs(enemy.position.y - frogPosition.y)
                    return (index: index, distance: distance)
                }
                
                let sortedByDistance = indexedEnemies.sorted { $0.distance > $1.distance }
                let limitedEnemies = Array(sortedByDistance.prefix(excessCount))
                let indices = limitedEnemies.map { $0.index }
                let sortedIndices = indices.sorted(by: >)
                
                for index in sortedIndices {
                    enemies[index].node.removeFromParent()
                    enemies.remove(at: index)
                }
                
                print("🧹 Enforced enemy limit: removed \(excessCount) enemies (now \(enemies.count))")
            }
        }
        
       
}

// MARK: - Spatial Grid for Performant Overlap Detection

private struct GridKey: Hashable {
    let x: Int
    let y: Int
}

/// A spatial grid for fast overlap detection of lily pads
private class SpatialGrid {
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
