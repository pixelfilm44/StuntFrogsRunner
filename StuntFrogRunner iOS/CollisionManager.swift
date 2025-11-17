//
//  CollisionManager.swift (UPDATED)
//  Now properly handles lily pad passengers and ensures BigHoneyPots stay on lily pads
//  
//  CRITICAL FIX: Prevents BigHoneyPots from spawning or floating in water by:
//  1. Ensuring BigHoneyPots are always synced to their lily pad positions
//  2. Removing orphaned BigHoneyPots that lose their lily pad reference  
//  3. Properly cleaning up lily pads and their passengers when removed
//  4. Validating BigHoneyPot placements periodically with repair capability
//  5. Enhanced spawning logic with explicit lily pad linking
//

import SpriteKit

enum HitOutcome {
    case hitOnly
    case destroyed(cause: AbilityType?)
}

class CollisionManager {
    weak var scene: SKScene?
    weak var effectsManager: EffectsManager?
    weak var uiManager: UIManager?
    weak var frogController: FrogController?
    
    private var rippleCounter: Int = 0
    
    // PERFORMANCE: Cache for reducing expensive collision calculations
    private var lastLogCollisionFrame: [ObjectIdentifier: Int] = [:]
    private let collisionCacheFrames = 3 // Skip collision checks for N frames after processing
    
    // PERFORMANCE OPTIMIZATION: Enhanced spatial partitioning and LOD system
    private var objectSpatialGrid: ObjectSpatialGrid = ObjectSpatialGrid(cellSize: 150)
    private var lastFrogPosition: CGPoint = .zero
    private var cachedNearbyObjects: [GameObject] = []
    private var cacheValidFrameCount: Int = 0
    private let maxCacheAge: Int = 5 // Recalculate nearby objects every 5 frames
    
    // PERFORMANCE: Distance-based update frequencies
    private let nearDistance: CGFloat = 200  // Objects within 200 units get full updates
    private let mediumDistance: CGFloat = 400 // Objects 200-400 units get reduced updates
    private let farDistance: CGFloat = 600   // Objects 400-600 units get minimal updates
    private var frameCounter: Int = 0
    
    init(scene: SKScene, uiManager: UIManager? = nil, frogController: FrogController? = nil) {
        self.scene = scene
        self.uiManager = uiManager
        self.frogController = frogController
    }
    
    // MARK: - Main Update Methods
    
    func updateLilyPadPhysics(lilyPads: inout [LilyPad]) {
        guard let scene = scene else { return }
        
        // Update individual lily pad physics (velocity, friction, bounds)
        // This also updates passengers via the lily pad's updatePassengers() method
        for pad in lilyPads {
            pad.updatePhysics(screenWidth: scene.size.width)
            
            if pad.type == .pulsing {
                pad.updatePulsing()
            } else if pad.type == .moving {
                pad.updateMoving(screenWidth: scene.size.width)
            }
        }
        
        // Handle lily pad to lily pad collisions
        handleLilyPadCollisions(lilyPads: &lilyPads)
    }
    
    func updateEnemies(enemies: inout [Enemy], frogPosition: CGPoint, frogScreenPosition: CGPoint, rocketActive: Bool, frogIsJumping: Bool, worldOffset: CGFloat, lilyPads: inout [LilyPad], onHit: (Enemy) -> HitOutcome, onLogBounce: ((Enemy) -> Void)? = nil) {
        guard let scene = scene else { return }
        
        rippleCounter += 1
        
        enemies.removeAll { enemy in
            let screenY = enemy.position.y + worldOffset
            if screenY < -100 || enemy.position.x < -150 || enemy.position.x > scene.size.width + 150 {
                if let targetPad = enemy.targetLilyPad {
                    targetPad.removeEnemyType(enemy.type)
                }
                // Clean up collision cache for logs
                if enemy.type == .log {
                    let key = ObjectIdentifier(enemy)
                    lastLogCollisionFrame.removeValue(forKey: key)
                }
                enemy.stopAnimation()
                enemy.node.removeFromParent()
                return true
            }
            
            if enemy.type == .snake {
                // Straight horizontal movement - no vertical variance
                if let targetPad = enemy.targetLilyPad {
                    // Maintain occupancy only while the snake is near the pad horizontally; otherwise release
                    let dx = enemy.position.x - targetPad.position.x
                    if (enemy.speed > 0 && dx > targetPad.radius + 20) || (enemy.speed < 0 && dx < -(targetPad.radius + 20)) {
                        targetPad.removeEnemyType(enemy.type)
                        enemy.targetLilyPad = nil
                    } else {
                        // Keep the snake at the exact same Y position as the target pad (straight line)
                        enemy.position.y = targetPad.position.y
                        enemy.node.position.y = enemy.position.y
                    }
                }
                // If no target pad, snake maintains its original Y position (straight line)
                // No vertical variance added - snakes move in perfectly straight horizontal lines
            }
            
            if enemy.type == .snake || enemy.type == .log {
                // Maintain horizontal motion
                enemy.position.x += enemy.speed
                enemy.node.position.x = enemy.position.x

                if enemy.type == .log {
                    // PERFORMANCE: Use cached collision checking to reduce per-frame overhead
                    let key = ObjectIdentifier(enemy)
                    let lastFrame = lastLogCollisionFrame[key] ?? 0
                    let currentFrame = rippleCounter
                    
                    // Only process collision every few frames for performance
                    if currentFrame - lastFrame >= collisionCacheFrames {
                        self.handleLogLilyPadCollisions(log: enemy, lilyPads: &lilyPads)
                        lastLogCollisionFrame[key] = currentFrame
                    }
                }

                // Reduced ripple frequency for performance
                if rippleCounter % 30 == 0 { // Less frequent ripples
                    if let gameScene = scene as? GameScene {
                        let amplitude: CGFloat = enemy.type == .log ? 0.018 : 0.008
                        let frequency: CGFloat = enemy.type == .log ? 6.0 : 9.0
                        gameScene.worldManager.addRipple(at: enemy.position, amplitude: amplitude, frequency: frequency)
                    }
                }

                // Do not snap snake Y to pad here; vertical motion is handled by the jump logic above
            } else if enemy.type == .bee {
                let time = CGFloat(CACurrentMediaTime())
                if let targetPad = enemy.targetLilyPad {
                    let orbitRadius: CGFloat = 30
                    enemy.position.x = targetPad.position.x + cos(time * 2) * orbitRadius
                    enemy.position.y = targetPad.position.y + sin(time * 2) * orbitRadius
                } else {
                    enemy.position.x += cos(time) * 0.5
                    enemy.position.y += sin(time) * 0.3
                }
                enemy.node.position = enemy.position
            } else if enemy.type == .dragonfly {
                enemy.position.y += enemy.speed
                enemy.node.position.y = enemy.position.y
            } else if enemy.type == .chaser {
                // Set frog reference if not already set
                if enemy.targetFrog == nil {
                    enemy.targetFrog = frogController
                }
                // Update chaser movement towards frog
                enemy.updateChaserMovement()
            } else if enemy.type == .spikeBush {
                // Spike bushes are static but should stay with their lily pad if it moves
                if let targetPad = enemy.targetLilyPad {
                    enemy.position = targetPad.position
                    enemy.node.position = enemy.position
                }
                // If no target lily pad, spike bush remains stationary
            } else if enemy.type == .edgeSpikeBush {
                // Edge spike bushes are completely static - no movement needed
                // They maintain their fixed edge positions
            }
            
            if checkCollision(enemy: enemy, frogPosition: frogPosition, frogIsJumping: frogIsJumping) {
                // CRITICAL: Edge spike bushes are SOLID BARRIERS - they ALWAYS block movement regardless of invincibility
                if enemy.type == .edgeSpikeBush {
                    print("🌵 PROCESSING EDGE SPIKE BUSH HIT! Acting as solid barrier.")
                    let outcome = onHit(enemy)
                    switch outcome {
                    case .destroyed(let cause):
                        // Edge spike bushes can be destroyed by axes - only then can frog pass through
                        if case .some(.axe) = cause, let scene = self.scene {
                            var screenPos = enemy.position
                            if let gameScene = scene as? GameScene {
                                screenPos = gameScene.convert(enemy.position, from: gameScene.worldManager.worldNode)
                            }
                            // Edge spike bushes get chopped straight down (no direction variance)
                            let dir: CGFloat = -.pi/2  // Straight down
                            self.uiManager?.playAxeChopEffect(at: screenPos, direction: dir)
                            HapticFeedbackManager.shared.impact(.heavy)
                        }
                        if let targetPad = enemy.targetLilyPad {
                            targetPad.removeEnemyType(enemy.type)
                        }
                        enemy.stopAnimation()
                        enemy.node.removeFromParent()
                        return true  // Remove the barrier - frog can now continue
                    case .hitOnly:
                        // CRITICAL: Edge spike bush acts as SOLID BARRIER - blocks frog movement completely
                        // This happens regardless of invincibility status!
                        if let frog = self.frogController {
                            print("🌵 EDGE SPIKE BUSH BLOCKED FROG MOVEMENT - SOLID BARRIER!")
                            
                            // Only apply damage if not invincible (but still block movement!)
                            if !frog.invincible && !rocketActive {
                                // Lose a heart (like hitting a solid wall)
                                if let scene = self.scene as? GameScene {
                                    scene.healthManager.damageHealth()
                                }
                                // Show scared reaction on the frog (longer for solid barriers)
                                frog.showScared(duration: 1.5)
                                // Haptic feedback (strongest for solid barriers)
                                HapticFeedbackManager.shared.impact(.heavy)
                            } else {
                                print("🌵 EDGE SPIKE BUSH HIT BUT FROG IS INVINCIBLE - STILL BLOCKING MOVEMENT!")
                            }
                            
                            // CRITICAL: Stop the frog's movement immediately REGARDLESS of invincibility
                            frog.isJumping = false  // Stop any jump in progress
                            frog.velocity = .zero   // Stop all movement
                            
                            // Calculate bounce-back position (move frog away from barrier)
                            let dx = frogPosition.x - enemy.position.x
                            let dy = frogPosition.y - enemy.position.y
                            let distance = sqrt(dx * dx + dy * dy)
                            
                            if distance > 0 && distance < 100 {  // Only bounce if very close
                                // Normalize direction and push frog away from barrier
                                let normalizedX = dx / distance
                                let normalizedY = dy / distance
                                let bounceDistance: CGFloat = 30.0  // Push back distance
                                
                                // Set new position away from the barrier
                                frog.position.x = frogPosition.x + (normalizedX * bounceDistance)
                                frog.position.y = frogPosition.y + (normalizedY * bounceDistance)
                            }
                        }
                        // IMPORTANT: Edge spike bushes remain as permanent physical barriers
                        return false
                    }
                }
                
                // CRITICAL FIX: Check frogController.invincible directly instead of using stale parameter
                // This prevents multiple enemies from hitting in the same frame before invincibility is applied
                let isInvincible = frogController?.invincible ?? false
                if !isInvincible && !rocketActive {
                    if enemy.type == .log {
                        // Attempt to handle via onHit first (enables Axe to destroy logs)
                        let outcome = onHit(enemy)
                        switch outcome {
                        case .destroyed(let cause):
                            // If destroyed by axe, play a slash effect at the log's screen position
                            if case .some(.axe) = cause, let scene = self.scene {
                                var screenPos = enemy.position
                                if let gameScene = scene as? GameScene {
                                    screenPos = gameScene.convert(enemy.position, from: gameScene.worldManager.worldNode)
                                }
                                // Direction based on log movement: right-moving ~0 rad, left-moving ~ÃƒÂÃ¢â€šÂ¬ rad
                                let dir: CGFloat = enemy.speed >= 0 ? 0.0 : .pi
                                self.uiManager?.playAxeChopEffect(at: screenPos, direction: dir)
                                HapticFeedbackManager.shared.impact(.heavy)
                            }
                            if let targetPad = enemy.targetLilyPad {
                                targetPad.removeEnemyType(enemy.type)
                            }
                            enemy.stopAnimation()
                            enemy.node.removeFromParent()
                            return true
                        case .hitOnly:
                            // No destruction (e.g., no axe) perform the legacy bounce behavior ONCE and then remove the log to prevent repeat bonks
                            onLogBounce?(enemy)
                            // Clean up any lily pad occupancy
                            if let targetPad = enemy.targetLilyPad {
                                targetPad.removeEnemyType(enemy.type)
                                enemy.targetLilyPad = nil
                            }
                            // Clean up collision cache for logs
                            let key = ObjectIdentifier(enemy)
                            lastLogCollisionFrame.removeValue(forKey: key)
                            // Remove the log node from the scene and signal removal from the enemies array
                            enemy.stopAnimation()
                            enemy.node.removeFromParent()
                            return true
                        }
                    }
                    
                    // Special handling: Regular spike bushes cause heart loss and bounce-back, can be destroyed by axes
                    if enemy.type == .spikeBush {
                        print("🌿 PROCESSING SPIKE BUSH HIT! Type: \(enemy.type)")
                        let outcome = onHit(enemy)
                        switch outcome {
                        case .destroyed(let cause):
                            if case .some(.axe) = cause, let scene = self.scene {
                                var screenPos = enemy.position
                                if let gameScene = scene as? GameScene {
                                    screenPos = gameScene.convert(enemy.position, from: gameScene.worldManager.worldNode)
                                }
                                // Spike bushes get chopped straight down (no direction variance)
                                let dir: CGFloat = -.pi/2  // Straight down
                                self.uiManager?.playAxeChopEffect(at: screenPos, direction: dir)
                                HapticFeedbackManager.shared.impact(.heavy)
                            }
                            if let targetPad = enemy.targetLilyPad {
                                targetPad.removeEnemyType(enemy.type)
                            }
                            enemy.stopAnimation()
                            enemy.node.removeFromParent()
                            return true
                        case .hitOnly:
                            // Apply damage if not invincible or in rocket state
                            if let frog = self.frogController, !(frog.invincible) && !rocketActive {
                                print("🌿 APPLYING SPIKE BUSH DAMAGE!")
                                // Lose a heart (similar to what happens with bees)
                                if let scene = self.scene as? GameScene {
                                    scene.healthManager.damageHealth()
                                }
                                // Replace bounce calculation and impulse with call to GameScene's log-bounce handler
                                if let gameScene = self.scene as? GameScene {
                                    gameScene.handleLogBounce(enemy: enemy)
                                }

                                // Show scared reaction on the frog
                                frog.showScared(duration: 1.0)

                                // Haptic feedback
                                HapticFeedbackManager.shared.impact(.medium)
                            } else {
                                print("🌿 SPIKE BUSH HIT BUT FROG IS INVINCIBLE OR IN ROCKET MODE")
                            }
                            // Do not remove the spike bush; keep it as a hazard
                            return false
                        }
                    }
                    
                    // Special handling: Edge spike bushes are SOLID BARRIERS - they BLOCK movement unless destroyed by axe
                    // NOTE: This is now handled above before the invincibility check
                    
                    // Regular spike bushes cause heart loss and bounce-back, can be destroyed by axes
                    if enemy.type == .spikeBush {
                        let outcome = onHit(enemy)
                        switch outcome {
                        case .destroyed(let cause):
                            // Only play danger zone sound if enemy was not destroyed by a protective ability
                            // (e.g., bee destroyed by honey jar should not play danger sound since no heart was lost)
                            if cause != .honeyJar && (enemy.type == .bee || enemy.type == .snake || enemy.type == .dragonfly) {
                                SoundController.shared.playSoundEffect(.dangerZone)
                            }
                            
                            if case .some(.axe) = cause, let scene = self.scene {
                                var screenPos = enemy.position
                                if let gameScene = scene as? GameScene {
                                    screenPos = gameScene.convert(enemy.position, from: gameScene.worldManager.worldNode)
                                }
                                let dir: CGFloat = (enemy.type == .log && enemy.speed < 0) ? .pi : 0.0
                                self.uiManager?.playAxeChopEffect(at: screenPos, direction: dir)
                                HapticFeedbackManager.shared.impact(.heavy)
                            }
                            if let targetPad = enemy.targetLilyPad {
                                targetPad.removeEnemyType(enemy.type)
                            }
                            enemy.stopAnimation()
                            enemy.node.removeFromParent()
                            return true
                        case .hitOnly:
                            // Play danger zone sound for enemies that hit but weren't destroyed
                            // This means the frog took damage
                            if enemy.type == .bee || enemy.type == .snake || enemy.type == .dragonfly {
                                SoundController.shared.playSoundEffect(.dangerZone)
                            }
                            break
                        }
                    }
                }
            }
            
            return false
        }
    }
    
    // MARK: - Lily Pad to Lily Pad Collision Physics
    
    private func handleLilyPadCollisions(lilyPads: inout [LilyPad]) {
        guard let scene = scene else { return }
        
        for i in 0..<lilyPads.count {
            for j in (i+1)..<lilyPads.count {
                let pad1 = lilyPads[i]
                let pad2 = lilyPads[j]
                
                let dx = pad2.position.x - pad1.position.x
                let dy = pad2.position.y - pad1.position.y
                let distance = sqrt(dx * dx + dy * dy)
                
                let minDistance = pad1.radius + pad2.radius
                
                if distance < minDistance && distance > 0.1 {
                    let nx = dx / distance
                    let ny = dy / distance
                    
                    let overlap = minDistance - distance
                    
                    let totalMass = pad1.mass + pad2.mass
                    let separation1 = overlap * (pad2.mass / totalMass)
                    let separation2 = overlap * (pad1.mass / totalMass)
                    
                    pad1.position.x -= nx * separation1
                    pad1.position.y -= ny * separation1
                    pad2.position.x += nx * separation2
                    pad2.position.y += ny * separation2
                    
                    let relativeVelocityX = pad2.velocity.x - pad1.velocity.x
                    let relativeVelocityY = pad2.velocity.y - pad1.velocity.y
                    let velocityAlongNormal = relativeVelocityX * nx + relativeVelocityY * ny
                    
                    if velocityAlongNormal < 0 {
                        let restitution: CGFloat = 0.4
                        let impulseMagnitude = -(1 + restitution) * velocityAlongNormal / totalMass
                        
                        pad1.velocity.x -= impulseMagnitude * pad2.mass * nx
                        pad1.velocity.y -= impulseMagnitude * pad2.mass * ny
                        pad2.velocity.x += impulseMagnitude * pad1.mass * nx
                        pad2.velocity.y += impulseMagnitude * pad1.mass * ny
                        
                        if let gameScene = scene as? GameScene {
                            let collisionX = pad1.position.x + nx * pad1.radius
                            let collisionY = pad1.position.y + ny * pad1.radius
                            gameScene.worldManager.addRipple(
                                at: CGPoint(x: collisionX, y: collisionY),
                                amplitude: 0.015,
                                frequency: 10.0
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Optimized Log-Lily Pad Physics
    
    private func handleLogLilyPadCollisions(log: Enemy, lilyPads: inout [LilyPad]) {
        guard let scene = scene else { return }
        
        let logHalfWidth = GameConfig.logWidth / 2
        let logHalfHeight = GameConfig.logHeight / 2
        let logRadius: CGFloat = 48.0
        
        // PERFORMANCE OPTIMIZATION: Spatial filtering
        // Only check lily pads within a reasonable distance (both X and Y)
        let maxInteractionDistance: CGFloat = 300.0
        let candidatePads = lilyPads.filter { pad in
            let dx = abs(pad.position.x - log.position.x)
            let dy = abs(pad.position.y - log.position.y)
            return dx < maxInteractionDistance && dy < maxInteractionDistance
        }
        
        for pad in candidatePads {
            // AABB vs circle collision detection
            let closestX = max(log.position.x - logHalfWidth,
                               min(pad.position.x, log.position.x + logHalfWidth))
            let closestY = max(log.position.y - logHalfHeight,
                               min(pad.position.y, log.position.y + logHalfHeight))
            
            let dx = pad.position.x - closestX
            let dy = pad.position.y - closestY
            let distanceSquared = dx * dx + dy * dy // Avoid sqrt when possible
            
            let collisionDistance = pad.radius + 5
            let collisionDistanceSquared = collisionDistance * collisionDistance
            
            if distanceSquared < collisionDistanceSquared {
                let distance = sqrt(distanceSquared) // Only calculate sqrt when we need it
                
                // Normalize; protect against zero
                let invDist = distance > 0.001 ? 1.0 / distance : 0.0
                let nx = dx * invDist
                
                // Optimized force calculation - horizontal only push
                let baseForce: CGFloat = 0.7
                let speedScale = min(1.0, abs(log.speed) / 2.5)
                let penetration = (collisionDistance - distance)
                let penetrationScale = min(1.0, penetration / (pad.radius * 0.6))
                let forceStrength = min(1.4, baseForce * speedScale * (0.5 + 0.5 * penetrationScale))
                
                // Apply horizontal-only force for better gameplay
                pad.applyForce(CGPoint(x: nx * forceStrength, y: 0.0))
                
                // Slight log slowdown during collision
                log.speed *= 0.94
                
                // Reduced ripple frequency for performance
                if rippleCounter % 30 == 0 { // Less frequent ripples
                    if let gameScene = scene as? GameScene {
                        gameScene.worldManager.addRipple(
                            at: CGPoint(x: closestX, y: closestY),
                            amplitude: 0.012,
                            frequency: 7.0
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Collision Detection
    
    // MARK: - Performance-Optimized Update Methods
    
    /// Update all objects using enhanced spatial partitioning and LOD
    func updateAllObjects(enemies: inout [Enemy], tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot], 
                         lilyPads: inout [LilyPad], frogPosition: CGPoint, frogScreenPosition: CGPoint, 
                         worldOffset: CGFloat, screenHeight: CGFloat, rocketActive: Bool, 
                         frogIsJumping: Bool, sceneSize: CGSize,
                         onEnemyHit: (Enemy) -> HitOutcome, onLogBounce: ((Enemy) -> Void)? = nil,
                         onTadpoleCollect: () -> Void, onBigHoneyPotCollect: () -> Void) {
        
        frameCounter += 1
        
        // PERFORMANCE: Check if we need to update our cached nearby objects
        let frogMovement = hypot(frogPosition.x - lastFrogPosition.x, frogPosition.y - lastFrogPosition.y)
        let shouldUpdateCache = frameCounter - cacheValidFrameCount >= maxCacheAge || frogMovement > 50
        
        if shouldUpdateCache {
            // Update spatial grid with current objects
            objectSpatialGrid.clear()
            for enemy in enemies { objectSpatialGrid.insert(enemy) }
            for tadpole in tadpoles { objectSpatialGrid.insert(tadpole) }
            for bigHoneyPot in bigHoneyPots { objectSpatialGrid.insert(bigHoneyPot) }
            for lilyPad in lilyPads { objectSpatialGrid.insert(lilyPad) }
            
            // Cache nearby objects for next few frames
            cachedNearbyObjects = objectSpatialGrid.queryNear(position: frogPosition, radius: farDistance)
            lastFrogPosition = frogPosition
            cacheValidFrameCount = frameCounter
        }
        
        // PERFORMANCE: Separate objects by distance for LOD processing
        var nearObjects: [GameObject] = []
        var mediumObjects: [GameObject] = []
        var farObjects: [GameObject] = []
        
        for obj in cachedNearbyObjects {
            let distanceSquared = distanceSquaredToFrog(obj.position, frogPosition)
            
            if distanceSquared <= nearDistance * nearDistance {
                nearObjects.append(obj)
            } else if distanceSquared <= mediumDistance * mediumDistance {
                mediumObjects.append(obj)
            } else if distanceSquared <= farDistance * farDistance {
                farObjects.append(obj)
            }
        }
        
        // PERFORMANCE: Update objects with different frequencies based on distance
        updateObjectsByDistance(
            nearObjects: nearObjects,
            mediumObjects: mediumObjects, 
            farObjects: farObjects,
            enemies: &enemies,
            tadpoles: &tadpoles,
            bigHoneyPots: &bigHoneyPots,
            lilyPads: &lilyPads,
            frogPosition: frogPosition,
            frogScreenPosition: frogScreenPosition,
            worldOffset: worldOffset,
            screenHeight: screenHeight,
            rocketActive: rocketActive,
            frogIsJumping: frogIsJumping,
            sceneSize: sceneSize,
            onEnemyHit: onEnemyHit,
            onLogBounce: onLogBounce,
            onTadpoleCollect: onTadpoleCollect,
            onBigHoneyPotCollect: onBigHoneyPotCollect
        )
    }
    
    private func distanceSquaredToFrog(_ position: CGPoint, _ frogPosition: CGPoint) -> CGFloat {
        let dx = position.x - frogPosition.x
        let dy = position.y - frogPosition.y
        return dx * dx + dy * dy
    }
    
    private func updateObjectsByDistance(nearObjects: [GameObject], mediumObjects: [GameObject], farObjects: [GameObject],
                                       enemies: inout [Enemy], tadpoles: inout [Tadpole], bigHoneyPots: inout [BigHoneyPot],
                                       lilyPads: inout [LilyPad], frogPosition: CGPoint, frogScreenPosition: CGPoint,
                                       worldOffset: CGFloat, screenHeight: CGFloat, rocketActive: Bool, frogIsJumping: Bool,
                                       sceneSize: CGSize, onEnemyHit: (Enemy) -> HitOutcome, onLogBounce: ((Enemy) -> Void)?,
                                       onTadpoleCollect: () -> Void, onBigHoneyPotCollect: () -> Void) {
        
        // NEAR OBJECTS: Update every frame with full collision detection
        for obj in nearObjects {
            if let enemy = obj as? Enemy {
                updateSingleEnemy(enemy, enemies: &enemies, frogPosition: frogPosition, frogScreenPosition: frogScreenPosition,
                                worldOffset: worldOffset, screenHeight: screenHeight, rocketActive: rocketActive,
                                frogIsJumping: frogIsJumping, sceneSize: sceneSize, onHit: onEnemyHit, onLogBounce: onLogBounce)
            } else if let tadpole = obj as? Tadpole {
                if updateSingleTadpole(tadpole, tadpoles: &tadpoles, frogPosition: frogPosition, worldOffset: worldOffset,
                                     screenHeight: screenHeight, rocketActive: rocketActive, onCollect: onTadpoleCollect) {
                    // Tadpole was collected or removed, update spatial grid
                    objectSpatialGrid.remove(tadpole)
                }
            } else if let bigHoneyPot = obj as? BigHoneyPot {
                if updateSingleBigHoneyPot(bigHoneyPot, bigHoneyPots: &bigHoneyPots, frogPosition: frogPosition, 
                                         worldOffset: worldOffset, screenHeight: screenHeight, rocketActive: rocketActive,
                                         onCollect: onBigHoneyPotCollect) {
                    // Big honey pot was collected or removed, update spatial grid
                    objectSpatialGrid.remove(bigHoneyPot)
                }
            }
        }
        
        // MEDIUM OBJECTS: Update every 2nd frame
        if frameCounter % 2 == 0 {
            for obj in mediumObjects {
                if let enemy = obj as? Enemy {
                    updateSingleEnemy(enemy, enemies: &enemies, frogPosition: frogPosition, frogScreenPosition: frogScreenPosition,
                                    worldOffset: worldOffset, screenHeight: screenHeight, rocketActive: rocketActive,
                                    frogIsJumping: frogIsJumping, sceneSize: sceneSize, onHit: onEnemyHit, onLogBounce: onLogBounce)
                }
                // Skip collision detection for medium-distance tadpoles and big honey pots since they're too far to collect
            }
        }
        
        // FAR OBJECTS: Update every 4th frame (movement only, no collision detection)
        if frameCounter % 4 == 0 {
            for obj in farObjects {
                if let enemy = obj as? Enemy {
                    // Only update position, skip collision detection
                    updateEnemyMovement(enemy)
                }
            }
        }
    }
    
    private func updateSingleTadpole(_ tadpole: Tadpole, tadpoles: inout [Tadpole], frogPosition: CGPoint, 
                                   worldOffset: CGFloat, screenHeight: CGFloat, rocketActive: Bool, 
                                   onCollect: () -> Void) -> Bool {
        let screenY = tadpole.position.y + worldOffset
        if screenY < -100 {
            // Remove from array
            if let index = tadpoles.firstIndex(where: { $0 === tadpole }) {
                tadpole.lilyPad = nil
                tadpole.node.removeFromParent()
                tadpoles.remove(at: index)
                return true
            }
        }
        
        // PERFORMANCE: Use squared distance to avoid expensive sqrt
        let dx = frogPosition.x - tadpole.position.x
        let dy = frogPosition.y - tadpole.position.y
        let distanceSquared = dx * dx + dy * dy
        let collisionRadiusSquared = (GameConfig.frogSize / 2 + GameConfig.tadpoleSize / 2 + GameConfig.tadpolePickupPadding) * (GameConfig.frogSize / 2 + GameConfig.tadpoleSize / 2 + GameConfig.tadpolePickupPadding)
        
        if distanceSquared < collisionRadiusSquared {
            // Remove from array
            if let index = tadpoles.firstIndex(where: { $0 === tadpole }) {
                tadpole.lilyPad = nil
                onCollect()
                tadpole.node.removeFromParent()
                tadpoles.remove(at: index)
                return true
            }
        }
        
        return false
    }
    
    private func updateSingleBigHoneyPot(_ bigHoneyPot: BigHoneyPot, bigHoneyPots: inout [BigHoneyPot], 
                                       frogPosition: CGPoint, worldOffset: CGFloat, screenHeight: CGFloat, 
                                       rocketActive: Bool, onCollect: () -> Void) -> Bool {
        // CRITICAL FIX: Ensure BigHoneyPot stays with its lily pad
        if let lilyPad = bigHoneyPot.lilyPad {
            // Keep the BigHoneyPot positioned exactly on the lily pad center
            bigHoneyPot.position = lilyPad.position
            bigHoneyPot.node.position = lilyPad.position
            
            // Add small visual offset so it doesn't overlap with other objects
            bigHoneyPot.node.position.y += 5  // Slightly above the lily pad center
        } else {
            // WARNING: BigHoneyPot has lost its lily pad reference - remove to prevent water spawning
            print("⚠️ WARNING: BigHoneyPot at \(Int(bigHoneyPot.position.x)), \(Int(bigHoneyPot.position.y)) has lost its lily pad reference - removing")
            if let index = bigHoneyPots.firstIndex(where: { $0 === bigHoneyPot }) {
                bigHoneyPot.node.removeFromParent()
                bigHoneyPots.remove(at: index)
                return true
            }
        }
        
        let screenY = bigHoneyPot.position.y + worldOffset
        if screenY < -100 {
            // Remove from array
            if let index = bigHoneyPots.firstIndex(where: { $0 === bigHoneyPot }) {
                bigHoneyPot.lilyPad = nil
                SoundController.shared.playSoundEffect(.specialReward)
                bigHoneyPot.node.removeFromParent()
                bigHoneyPots.remove(at: index)
                return true
            }
        }
        
        // PERFORMANCE: Use squared distance to avoid expensive sqrt
        let dx = frogPosition.x - bigHoneyPot.position.x
        let dy = frogPosition.y - bigHoneyPot.position.y
        let distanceSquared = dx * dx + dy * dy
        let collisionDistanceSquared: CGFloat = 40 * 40 // 40^2
        
        if distanceSquared < collisionDistanceSquared {
            // Remove from array
            if let index = bigHoneyPots.firstIndex(where: { $0 === bigHoneyPot }) {
                bigHoneyPot.lilyPad = nil
                onCollect()
                bigHoneyPot.node.removeFromParent()
                bigHoneyPots.remove(at: index)
                return true
            }
        }
        
        return false
    }
    
    private func updateSingleEnemy(_ enemy: Enemy, enemies: inout [Enemy], frogPosition: CGPoint, 
                                 frogScreenPosition: CGPoint, worldOffset: CGFloat, screenHeight: CGFloat, 
                                 rocketActive: Bool, frogIsJumping: Bool, sceneSize: CGSize, 
                                 onHit: (Enemy) -> HitOutcome, onLogBounce: ((Enemy) -> Void)?) {
        // Check if enemy is off-screen and should be removed
        let screenY = enemy.position.y + worldOffset
        if screenY < -100 || enemy.position.x < -150 || enemy.position.x > sceneSize.width + 150 {
            if let index = enemies.firstIndex(where: { $0 === enemy }) {
                if let targetPad = enemy.targetLilyPad {
                    targetPad.removeEnemyType(enemy.type)
                }
                if enemy.type == .log {
                    let key = ObjectIdentifier(enemy)
                    lastLogCollisionFrame.removeValue(forKey: key)
                }
                enemy.stopAnimation()
                enemy.node.removeFromParent()
                enemies.remove(at: index)
                objectSpatialGrid.remove(enemy)
            }
            return
        }
        
        // Update enemy movement
        updateEnemyMovement(enemy)
        
        // Check collision with frog
        if checkCollision(enemy: enemy, frogPosition: frogPosition, frogIsJumping: frogIsJumping) {
            let isInvincible = frogController?.invincible ?? false
            if !isInvincible && !rocketActive {
                handleEnemyCollision(enemy, enemies: &enemies, frogPosition: frogPosition, onHit: onHit, onLogBounce: onLogBounce)
            }
        }
    }
    
    func updateEnemyMovement(_ enemy: Enemy) {
        // Movement logic extracted from the main updateEnemies method
        switch enemy.type {
        case .snake:
            if let targetPad = enemy.targetLilyPad {
                let dx = enemy.position.x - targetPad.position.x
                if (enemy.speed > 0 && dx > targetPad.radius + 20) || (enemy.speed < 0 && dx < -(targetPad.radius + 20)) {
                    targetPad.removeEnemyType(enemy.type)
                    enemy.targetLilyPad = nil
                } else {
                    enemy.position.y = targetPad.position.y
                    enemy.node.position.y = enemy.position.y
                }
            }
            enemy.position.x += enemy.speed
            enemy.node.position.x = enemy.position.x
            
        case .log:
            enemy.position.x += enemy.speed
            enemy.node.position.x = enemy.position.x
            
        case .bee:
            let time = CGFloat(CACurrentMediaTime())
            if let targetPad = enemy.targetLilyPad {
                let orbitRadius: CGFloat = 30
                enemy.position.x = targetPad.position.x + cos(time * 2) * orbitRadius
                enemy.position.y = targetPad.position.y + sin(time * 2) * orbitRadius
            } else {
                enemy.position.x += cos(time) * 0.5
                enemy.position.y += sin(time) * 0.3
            }
            enemy.node.position = enemy.position
            
        case .dragonfly:
            enemy.position.y += enemy.speed
            enemy.node.position.y = enemy.position.y
            
        case .chaser:
            if enemy.targetFrog == nil {
                enemy.targetFrog = frogController
            }
            enemy.updateChaserMovement()
            
        case .spikeBush:
            if let targetPad = enemy.targetLilyPad {
                enemy.position = targetPad.position
                enemy.node.position = enemy.position
            }
            
        case .edgeSpikeBush:
            // Edge spike bushes are static
            break
        }
    }
    
    private func handleEnemyCollision(_ enemy: Enemy, enemies: inout [Enemy], frogPosition: CGPoint, onHit: (Enemy) -> HitOutcome, 
                                    onLogBounce: ((Enemy) -> Void)?) {
        
        // CRITICAL: Edge spike bushes are SOLID BARRIERS - they ALWAYS block movement regardless of invincibility
        if enemy.type == .edgeSpikeBush {
            let outcome = onHit(enemy)
            switch outcome {
            case .destroyed(let cause):
                if case .some(.axe) = cause, let scene = self.scene {
                    var screenPos = enemy.position
                    if let gameScene = scene as? GameScene {
                        screenPos = gameScene.convert(enemy.position, from: gameScene.worldManager.worldNode)
                    }
                    // Edge spike bushes get chopped straight down (no direction variance)
                    let dir: CGFloat = -.pi/2  // Straight down
                    self.uiManager?.playAxeChopEffect(at: screenPos, direction: dir)
                    HapticFeedbackManager.shared.impact(.heavy)
                }
                removeEnemy(enemy, from: &enemies)
                return
            case .hitOnly:
                if let frog = self.frogController {
                    print("🌵 EDGE SPIKE BUSH BLOCKED FROG MOVEMENT - SOLID BARRIER!")
                    
                    // Only apply damage if not invincible (but still block movement!)
                    if !frog.invincible {
                        if let scene = self.scene as? GameScene {
                            scene.healthManager.damageHealth()
                        }
                        frog.showScared(duration: 1.5)
                        HapticFeedbackManager.shared.impact(.heavy)
                    } else {
                        print("🌵 EDGE SPIKE BUSH HIT BUT FROG IS INVINCIBLE - STILL BLOCKING MOVEMENT!")
                    }
                    
                    // CRITICAL: Stop frog movement immediately REGARDLESS of invincibility
                    frog.isJumping = false  // Stop any jump in progress
                    frog.velocity = .zero   // Stop all movement
                    
                    // Calculate bounce-back position (move frog away from barrier)
                    let dx = frogPosition.x - enemy.position.x
                    let dy = frogPosition.y - enemy.position.y
                    let distance = sqrt(dx * dx + dy * dy)
                    
                    if distance > 0 && distance < 100 {  // Only bounce if very close
                        // Normalize direction and push frog away from barrier
                        let normalizedX = dx / distance
                        let normalizedY = dy / distance
                        let bounceDistance: CGFloat = 30.0  // Push back distance
                        
                        // Set new position away from the barrier
                        frog.position.x = frogPosition.x + (normalizedX * bounceDistance)
                        frog.position.y = frogPosition.y + (normalizedY * bounceDistance)
                    }
                }
                return // Don't remove edge spike bushes - they remain as permanent barriers
            }
        }
        
        if enemy.type == .log {
            let outcome = onHit(enemy)
            switch outcome {
            case .destroyed(let cause):
                if case .some(.axe) = cause, let scene = self.scene {
                    var screenPos = enemy.position
                    if let gameScene = scene as? GameScene {
                        screenPos = gameScene.convert(enemy.position, from: gameScene.worldManager.worldNode)
                    }
                    let dir: CGFloat = enemy.speed >= 0 ? 0.0 : .pi
                    self.uiManager?.playAxeChopEffect(at: screenPos, direction: dir)
                    HapticFeedbackManager.shared.impact(.heavy)
                }
                removeEnemy(enemy, from: &enemies)
                return
            case .hitOnly:
                onLogBounce?(enemy)
                removeEnemy(enemy, from: &enemies)
                return
            }
        }
        
        // Handle regular spike bushes - can be chopped by axes or cause damage
        if enemy.type == .spikeBush {
            let outcome = onHit(enemy)
            switch outcome {
            case .destroyed(let cause):
                if case .some(.axe) = cause, let scene = self.scene {
                    var screenPos = enemy.position
                    if let gameScene = scene as? GameScene {
                        screenPos = gameScene.convert(enemy.position, from: gameScene.worldManager.worldNode)
                    }
                    // Spike bushes get chopped straight down (no direction variance)
                    let dir: CGFloat = -.pi/2  // Straight down
                    self.uiManager?.playAxeChopEffect(at: screenPos, direction: dir)
                    HapticFeedbackManager.shared.impact(.heavy)
                }
                removeEnemy(enemy, from: &enemies)
                return
            case .hitOnly:
                if let frog = self.frogController {
                    if let scene = self.scene as? GameScene {
                        scene.healthManager.damageHealth()
                    }
                    if let gameScene = self.scene as? GameScene {
                        gameScene.handleLogBounce(enemy: enemy)
                    }
                    frog.showScared(duration: 1.0)
                    HapticFeedbackManager.shared.impact(.medium)
                }
                return // Don't remove spike bushes when not chopped
            }
        }
        
        // Handle other enemies (non edge spike bushes)
        let outcome = onHit(enemy)
        switch outcome {
        case .destroyed(let cause):
            if cause != .honeyJar && (enemy.type == .bee || enemy.type == .snake || enemy.type == .dragonfly) {
                SoundController.shared.playSoundEffect(.dangerZone)
            }
            if case .some(.axe) = cause, let scene = self.scene {
                var screenPos = enemy.position
                if let gameScene = scene as? GameScene {
                    screenPos = gameScene.convert(enemy.position, from: gameScene.worldManager.worldNode)
                }
                let dir: CGFloat = (enemy.type == .log && enemy.speed < 0) ? .pi : 0.0
                self.uiManager?.playAxeChopEffect(at: screenPos, direction: dir)
                HapticFeedbackManager.shared.impact(.heavy)
            }
            removeEnemy(enemy, from: &enemies)
        case .hitOnly:
            if enemy.type == .bee || enemy.type == .snake || enemy.type == .dragonfly {
                SoundController.shared.playSoundEffect(.dangerZone)
            }
            break
        }
    }
    
    private func removeEnemy(_ enemy: Enemy, from enemies: inout [Enemy]) {
        if let index = enemies.firstIndex(where: { $0 === enemy }) {
            if let targetPad = enemy.targetLilyPad {
                targetPad.removeEnemyType(enemy.type)
            }
            if enemy.type == .log {
                let key = ObjectIdentifier(enemy)
                lastLogCollisionFrame.removeValue(forKey: key)
            }
            enemy.stopAnimation()
            enemy.node.removeFromParent()
            enemies.remove(at: index)
            objectSpatialGrid.remove(enemy)
        }
    }
    
    // MARK: - Legacy Update Methods (Kept for Compatibility)
    
    func updateTadpoles(tadpoles: inout [Tadpole], frogPosition: CGPoint, frogScreenPosition: CGPoint, worldOffset: CGFloat, screenHeight: CGFloat, rocketActive: Bool, onCollect: () -> Void) {
        // TEMPORARY FIX: Disable spatial grid optimization and check all tadpoles
        // This should immediately fix the collection issue while we debug the spatial grid
        var indicesToRemove: [Int] = []
        
        for (index, tadpole) in tadpoles.enumerated() {
            let screenY = tadpole.position.y + worldOffset
            if screenY < -100 {
                // Mark for removal
                indicesToRemove.append(index)
                tadpole.lilyPad = nil
                tadpole.node.removeFromParent()
                continue
            }
            
            // Check collision for ALL tadpoles (no spatial filtering)
            let dx = frogPosition.x - tadpole.position.x
            let dy = frogPosition.y - tadpole.position.y
            let distanceSquared = dx * dx + dy * dy
            let collisionRadiusSquared = (GameConfig.frogSize / 2 + GameConfig.tadpoleSize / 2 + GameConfig.tadpolePickupPadding) * (GameConfig.frogSize / 2 + GameConfig.tadpoleSize / 2 + GameConfig.tadpolePickupPadding)
            
            if distanceSquared < collisionRadiusSquared {
                // Mark for removal
                indicesToRemove.append(index)
                tadpole.lilyPad = nil
                onCollect()
                tadpole.node.removeFromParent()
                print("🐸 SUCCESS: Tadpole collected! Distance: \(sqrt(distanceSquared)), Required: \(sqrt(collisionRadiusSquared))")
            }
        }
        
        // Remove tadpoles in reverse order to maintain valid indices
        for index in indicesToRemove.reversed() {
            tadpoles.remove(at: index)
        }
    }
    
    func updateBigHoneyPots(bigHoneyPots: inout [BigHoneyPot], frogPosition: CGPoint, frogScreenPosition: CGPoint, worldOffset: CGFloat, screenHeight: CGFloat, rocketActive: Bool, onCollect: () -> Void) {
        var indicesToRemove: [Int] = []
        
        for (index, bigHoneyPot) in bigHoneyPots.enumerated() {
            // CRITICAL FIX: Ensure BigHoneyPot stays with its lily pad
            // If the BigHoneyPot has a lily pad reference, sync its position
            if let lilyPad = bigHoneyPot.lilyPad {
                // Keep the BigHoneyPot positioned exactly on the lily pad center
                bigHoneyPot.position = lilyPad.position
                bigHoneyPot.node.position = lilyPad.position
                
                // Add small visual offset so it doesn't overlap with other objects
                bigHoneyPot.node.position.y += 5  // Slightly above the lily pad center
            } else {
                // WARNING: BigHoneyPot has lost its lily pad reference
                // This should not happen, but if it does, remove the BigHoneyPot to prevent water spawning
                print("⚠️ WARNING: BigHoneyPot at \(Int(bigHoneyPot.position.x)), \(Int(bigHoneyPot.position.y)) has lost its lily pad reference - removing to prevent water spawning")
                indicesToRemove.append(index)
                bigHoneyPot.node.removeFromParent()
                continue
            }
            
            let screenY = bigHoneyPot.position.y + worldOffset
            if screenY < -100 {
                // Mark for removal
                indicesToRemove.append(index)
                bigHoneyPot.lilyPad = nil
                SoundController.shared.playSoundEffect(.specialReward)
                bigHoneyPot.node.removeFromParent()
                continue
            }
            
            // Check collision for ALL big honey pots (no spatial filtering)
            let dx = frogPosition.x - bigHoneyPot.position.x
            let dy = frogPosition.y - bigHoneyPot.position.y
            let distanceSquared = dx * dx + dy * dy
            let collisionDistanceSquared: CGFloat = 40 * 40 // 40^2
            
            if distanceSquared < collisionDistanceSquared {
                // Mark for removal
                indicesToRemove.append(index)
                bigHoneyPot.lilyPad = nil
                onCollect()
                bigHoneyPot.node.removeFromParent()
                print("🍯 SUCCESS: Big honey pot collected! Distance: \(sqrt(distanceSquared)), Required: \(sqrt(collisionDistanceSquared))")
            }
        }
        
        // Remove big honey pots in reverse order to maintain valid indices
        for index in indicesToRemove.reversed() {
            bigHoneyPots.remove(at: index)
        }
    }
    
    /// Validate and repair any BigHoneyPots that may have lost their lily pad connections
    /// This is a safety method to prevent BigHoneyPots from floating in water
    func validateBigHoneyPotPlacements(bigHoneyPots: inout [BigHoneyPot], lilyPads: [LilyPad]) {
        var indicesToRemove: [Int] = []
        var orphanedCount = 0
        var repairedCount = 0
        
        for (index, bigHoneyPot) in bigHoneyPots.enumerated() {
            // Check if BigHoneyPot has a valid lily pad reference
            if bigHoneyPot.lilyPad == nil {
                orphanedCount += 1
                
                // Try to find a nearby lily pad to attach to
                let nearbyPad = lilyPads.first { lilyPad in
                    let distance = hypot(bigHoneyPot.position.x - lilyPad.position.x, 
                                       bigHoneyPot.position.y - lilyPad.position.y)
                    return distance < lilyPad.radius && !lilyPad.hasBigHoneyPots
                }
                
                if let pad = nearbyPad {
                    // Reattach to nearby lily pad
                    bigHoneyPot.lilyPad = pad
                    pad.addBigHoneyPot(bigHoneyPot)
                    bigHoneyPot.position = pad.position
                    bigHoneyPot.node.position = pad.position
                    bigHoneyPot.node.position.y += 5  // Visual offset
                    repairedCount += 1
                    print("🔧 REPAIR: Reattached orphaned BigHoneyPot to lily pad at \(Int(pad.position.x)), \(Int(pad.position.y))")
                } else {
                    // No suitable lily pad found - remove to prevent water spawning
                    print("🗑️ CLEANUP: Removing orphaned BigHoneyPot at \(Int(bigHoneyPot.position.x)), \(Int(bigHoneyPot.position.y)) - no lily pad available")
                    indicesToRemove.append(index)
                    bigHoneyPot.node.removeFromParent()
                }
            }
        }
        
        // Remove orphaned BigHoneyPots in reverse order
        for index in indicesToRemove.reversed() {
            bigHoneyPots.remove(at: index)
        }
        
        // Report validation results if any issues were found
        if orphanedCount > 0 {
            print("🍯 BigHoneyPot Validation: Found \(orphanedCount) orphaned, repaired \(repairedCount), removed \(indicesToRemove.count)")
        }
    }
    
    /// Debug method to check all BigHoneyPots have lily pad references
    func debugBigHoneyPotPlacements(bigHoneyPots: [BigHoneyPot]) {
        let orphanedCount = bigHoneyPots.filter { $0.lilyPad == nil }.count
        if orphanedCount > 0 {
            print("⚠️ DEBUG: \(orphanedCount) out of \(bigHoneyPots.count) BigHoneyPots are missing lily pad references!")
            for (index, bhp) in bigHoneyPots.enumerated() {
                if bhp.lilyPad == nil {
                    print("   - BigHoneyPot #\(index) at (\(Int(bhp.position.x)), \(Int(bhp.position.y))) has no lily pad")
                }
            }
        } else if bigHoneyPots.count > 0 {
            print("✅ DEBUG: All \(bigHoneyPots.count) BigHoneyPots are properly attached to lily pads")
        }
    }
    
    // MARK: - LifeVest Management
    
    func updateLifeVests(lifeVests: inout [LifeVest], frogPosition: CGPoint, frogScreenPosition: CGPoint, worldOffset: CGFloat, screenHeight: CGFloat, rocketActive: Bool, onCollect: () -> Void) {
        var indicesToRemove: [Int] = []
        
        for (index, lifeVest) in lifeVests.enumerated() {
            // Remove life vests that have scrolled off screen (bottom)
            let screenY = lifeVest.position.y + worldOffset
            if screenY < -100 {
                print("🦺 Life vest removed (off bottom of screen) at Y: \(Int(screenY))")
                indicesToRemove.append(index)
                lifeVest.lilyPad = nil  // Clean up lily pad reference
                lifeVest.node.removeFromParent()
                continue
            }
            
            // Skip collision detection during rocket mode
            if rocketActive {
                continue
            }
            
            // Check for collection by frog
            let distance = hypot(frogPosition.x - lifeVest.position.x, frogPosition.y - lifeVest.position.y)
            let collectionDistance: CGFloat = 40  // Same as honey pot collection distance
            
            if distance < collectionDistance {
                print("🦺 Life vest collected! Distance: \(distance), Required: \(collectionDistance)")
                indicesToRemove.append(index)
                lifeVest.lilyPad = nil
                onCollect()
                lifeVest.node.removeFromParent()
                print("🦺 SUCCESS: Life vest collected! Distance: \(distance), Required: \(collectionDistance)")
            }
        }
        
        // Remove life vests in reverse order to maintain valid indices
        for index in indicesToRemove.reversed() {
            lifeVests.remove(at: index)
        }
    }
    
    /// Validate and repair any LifeVests that may have lost their lily pad connections
    /// This is a safety method to prevent LifeVests from floating in water
    func validateLifeVestPlacements(lifeVests: inout [LifeVest], lilyPads: [LilyPad]) {
        var indicesToRemove: [Int] = []
        var orphanedCount = 0
        var repairedCount = 0
        
        for (index, lifeVest) in lifeVests.enumerated() {
            // Check if LifeVest has a valid lily pad reference
            if lifeVest.lilyPad == nil {
                orphanedCount += 1
                
                // Try to find a nearby lily pad to attach to
                let nearbyPad = lilyPads.first { lilyPad in
                    let distance = hypot(lifeVest.position.x - lilyPad.position.x, 
                                       lifeVest.position.y - lilyPad.position.y)
                    return distance < lilyPad.radius && !lilyPad.hasLifeVests
                }
                
                if let pad = nearbyPad {
                    // Reattach to nearby lily pad
                    lifeVest.lilyPad = pad
                    pad.addLifeVest(lifeVest)
                    lifeVest.position = pad.position
                    lifeVest.node.position = pad.position
                    lifeVest.node.position.y += 5  // Visual offset
                    repairedCount += 1
                    print("🔧 REPAIR: Reattached orphaned LifeVest to lily pad at \(Int(pad.position.x)), \(Int(pad.position.y))")
                } else {
                    // No suitable lily pad found - remove to prevent water spawning
                    print("🗑️ CLEANUP: Removing orphaned LifeVest at \(Int(lifeVest.position.x)), \(Int(lifeVest.position.y)) - no lily pad available")
                    indicesToRemove.append(index)
                    lifeVest.node.removeFromParent()
                }
            }
        }
        
        // Remove orphaned LifeVests in reverse order
        for index in indicesToRemove.reversed() {
            lifeVests.remove(at: index)
        }
        
        // Report validation results if any issues were found
        if orphanedCount > 0 {
            print("🦺 LifeVest Validation: Found \(orphanedCount) orphaned, repaired \(repairedCount), removed \(indicesToRemove.count)")
        }
    }
    
    /// Debug method to check all LifeVests have lily pad references
    func debugLifeVestPlacements(lifeVests: [LifeVest]) {
        let orphanedCount = lifeVests.filter { $0.lilyPad == nil }.count
        if orphanedCount > 0 {
            print("⚠️ DEBUG: \(orphanedCount) out of \(lifeVests.count) LifeVests are missing lily pad references!")
            for (index, lv) in lifeVests.enumerated() {
                if lv.lilyPad == nil {
                    print("   - LifeVest #\(index) at (\(Int(lv.position.x)), \(Int(lv.position.y))) has no lily pad")
                }
            }
        } else if lifeVests.count > 0 {
            print("✅ DEBUG: All \(lifeVests.count) LifeVests are properly attached to lily pads")
        }
    }
    
    func updateLilyPads(lilyPads: inout [LilyPad], worldOffset: CGFloat, screenHeight: CGFloat, frogPosition: CGPoint) {
        // Update moving behavior for all lily pads
        for pad in lilyPads {
            if pad.type == .moving {
                // Get screen width from the scene if possible, fallback to reasonable default
                let screenWidth = (scene as? GameScene)?.size.width ?? 1024
                pad.updateMoving(screenWidth: screenWidth)
            }
        }
        
        // Remove lily pads that scrolled off bottom
        lilyPads.removeAll { pad in
            let screenY = pad.position.y + worldOffset
            let isBehindFrog = pad.position.y < frogPosition.y - 500
            
            if screenY < -150 && isBehindFrog {
                // CRITICAL FIX: Clean up all objects on this lily pad before removing
                // This prevents BigHoneyPots and other objects from being orphaned
                pad.clearTadpoles()
                pad.clearBigHoneyPots()
                pad.clearLifeVests()
                pad.occupyingEnemyTypes.removeAll()
                pad.hasFrog = false
                pad.frog = nil
                pad.node.removeFromParent()
                print("🧹 Cleaned up lily pad at (\(Int(pad.position.x)), \(Int(pad.position.y))) and all its objects")
                return true
            }
            return false
        }
    }
    
    func cleanupLilyPads(lilyPads: inout [LilyPad], worldOffset: CGFloat, screenHeight: CGFloat, frogPosition: CGPoint) {
        updateLilyPads(lilyPads: &lilyPads, worldOffset: worldOffset, screenHeight: screenHeight, frogPosition: frogPosition)
    }
    
  func checkCollision(enemy: Enemy, frogPosition: CGPoint, frogIsJumping: Bool) -> Bool {
        // Only bees and snakes can be jumped over when the frog is jumping
        // Spike bushes, logs, dragonflies, and other enemies still cause collision when jumping
        if frogIsJumping && (enemy.type == .bee || enemy.type == .snake) {
            return false
        }
        
        // DEBUG: Add logging for spike bush collisions
        if enemy.type == .spikeBush || enemy.type == .edgeSpikeBush {
            let dx = frogPosition.x - enemy.position.x
            let dy = frogPosition.y - enemy.position.y
            let distance = sqrt(dx * dx + dy * dy)
            let collisionRadius = (GameConfig.frogSize / 2) + (enemy.type == .spikeBush ? GameConfig.spikeBushSize / 2 : GameConfig.edgeSpikeBushSize / 2)
            
            if distance < collisionRadius {
                print("🌿 SPIKE BUSH COLLISION DETECTED! Enemy: \(enemy.type), Distance: \(distance), Required: \(collisionRadius), Jumping: \(frogIsJumping)")
                return true
            }
        }
        
        switch enemy.type {
        case .log:
            // Use tighter collision bounds than the visual size so logs feel fairer
            let halfW = GameConfig.logCollisionWidth / 2
            let halfH = GameConfig.logCollisionHeight / 2
            let frogHalf = GameConfig.frogSize / 2

            let minX = enemy.position.x - (halfW + frogHalf)
            let maxX = enemy.position.x + (halfW + frogHalf)
            let minY = enemy.position.y - (halfH + frogHalf)
            let maxY = enemy.position.y + (halfH + frogHalf)

            return frogPosition.x >= minX && frogPosition.x <= maxX &&
                   frogPosition.y >= minY && frogPosition.y <= maxY

        case .snake:
            // Use rectangular collision with reduced vertical hit zone
            let halfW = GameConfig.snakeCollisionWidth / 2
            let halfH = GameConfig.snakeCollisionHeight / 2
            let frogHalf = GameConfig.frogSize / 2

            let minX = enemy.position.x - (halfW + frogHalf)
            let maxX = enemy.position.x + (halfW + frogHalf)
            let minY = enemy.position.y - (halfH + frogHalf)
            let maxY = enemy.position.y + (halfH + frogHalf)

            return frogPosition.x >= minX && frogPosition.x <= maxX &&
                   frogPosition.y >= minY && frogPosition.y <= maxY

        default:
            let dx = frogPosition.x - enemy.position.x
            let dy = frogPosition.y - enemy.position.y
            let distance = sqrt(dx * dx + dy * dy)

            let enemySize: CGFloat
            switch enemy.type {
            case .bee: enemySize = GameConfig.beeSize
            case .dragonfly: enemySize = GameConfig.dragonflySize
            case .log: enemySize = GameConfig.logCollisionWidth
            case .spikeBush: enemySize = GameConfig.spikeBushSize
            case .edgeSpikeBush: enemySize = GameConfig.edgeSpikeBushSize
            case .chaser: enemySize = GameConfig.chaserSize
            case .snake: enemySize = GameConfig.snakeSize // This shouldn't be reached due to separate case above
            }

            return distance < (GameConfig.frogSize / 2 + enemySize / 2)
        }
    }
    
    func checkLandingCollision(frogPosition: CGPoint, lilyPads: [LilyPad]) -> LilyPad? {
        for pad in lilyPads {
            let dx = frogPosition.x - pad.position.x
            let dy = frogPosition.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < pad.radius {
                return pad
            }
        }
        return nil
    }
    
    func findNearestLilyPad(to position: CGPoint, from lilyPads: [LilyPad], ahead: Bool = true, frogY: CGFloat = 0) -> LilyPad? {
        var candidates = lilyPads
        
        if ahead {
            candidates = candidates.filter { $0.position.y > frogY }
        }
        
        guard !candidates.isEmpty else { return nil }
        
        return candidates.min(by: { pad1, pad2 in
            let dist1 = hypot(position.x - pad1.position.x, position.y - pad1.position.y)
            let dist2 = hypot(position.x - pad2.position.x, position.y - pad2.position.y)
            return dist1 < dist2
        })
    }
}

// MARK: - Enhanced Spatial Partitioning System

/// Protocol for game objects that can be spatially partitioned
protocol GameObject: AnyObject {
    var position: CGPoint { get }
    var objectID: ObjectIdentifier { get }
}

/// Enhanced spatial grid that can handle multiple object types
class ObjectSpatialGrid {
    private let cellSize: CGFloat
    private var grid: [GridKey: [GameObject]] = [:]
    
    init(cellSize: CGFloat) {
        self.cellSize = cellSize
    }
    
    /// Insert any game object into the spatial grid
    func insert(_ object: GameObject) {
        let keys = getKeysForPosition(object.position, radius: 25) // Default radius for collision detection
        for key in keys {
            if grid[key] == nil {
                grid[key] = []
            }
            grid[key]?.append(object)
        }
    }
    
    /// Remove a game object from the spatial grid
    func remove(_ object: GameObject) {
        let keys = getKeysForPosition(object.position, radius: 25)
        for key in keys {
            grid[key]?.removeAll { $0.objectID == object.objectID }
            if grid[key]?.isEmpty == true {
                grid[key] = nil
            }
        }
    }
    
    /// Query game objects near a position within a given radius
    func queryNear(position: CGPoint, radius: CGFloat) -> [GameObject] {
        let keys = getKeysForCircle(center: position, radius: radius)
        var result: Set<ObjectIdentifier> = Set()
        var objects: [GameObject] = []
        
        for key in keys {
            if let cellObjects = grid[key] {
                for obj in cellObjects {
                    let id = obj.objectID
                    if !result.contains(id) {
                        result.insert(id)
                        objects.append(obj)
                    }
                }
            }
        }
        
        return objects
    }
    
    /// Clear all objects from the grid
    func clear() {
        grid.removeAll()
    }
    
    /// Get statistics about the grid for performance monitoring
    func getStats() -> (totalCells: Int, totalObjects: Int, averageObjectsPerCell: Double) {
        let totalCells = grid.count
        let totalObjects = grid.values.reduce(0) { $0 + $1.count }
        let avgObjectsPerCell = totalCells > 0 ? Double(totalObjects) / Double(totalCells) : 0.0
        return (totalCells, totalObjects, avgObjectsPerCell)
    }
    
    // MARK: - Private Methods
    
    private func getKeysForPosition(_ position: CGPoint, radius: CGFloat) -> [GridKey] {
        return getKeysForCircle(center: position, radius: radius)
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

// MARK: - GameObject Extensions

extension Enemy: GameObject {
    var objectID: ObjectIdentifier { ObjectIdentifier(self) }
}

extension Tadpole: GameObject {
    var objectID: ObjectIdentifier { ObjectIdentifier(self) }
}

extension BigHoneyPot: GameObject {
    var objectID: ObjectIdentifier { ObjectIdentifier(self) }
}

extension LilyPad: GameObject {
    var objectID: ObjectIdentifier { ObjectIdentifier(self) }
}

