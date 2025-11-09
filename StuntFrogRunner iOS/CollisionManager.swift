//
//  CollisionManager.swift (UPDATED)
//  Now properly handles lily pad passengers
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
                    
                    // Special handling: Spike bushes cause heart loss and a bounce-back, but are not destroyed
                    if enemy.type == .spikeBush || enemy.type == .edgeSpikeBush {
                        print("🌿 PROCESSING SPIKE BUSH HIT! Type: \(enemy.type)")
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

                            // Brief invincibility frames to avoid rapid repeated hits
                           // frog.activateInvincibility(seconds: 1.0)
                            
                            // Show scared reaction on the frog
                            frog.showScared(duration: 1.0)

                           
                            // Haptic feedback
                            HapticFeedbackManager.shared.impact(.medium)
                        } else {
                            print("🌿 SPIKE BUSH HIT BUT FROG IS INVINCIBLE OR IN ROCKET MODE")
                        }
                        // Do not remove the spike bush; keep it as a hazard
                        return false
                    } else {
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
    
    func updateTadpoles(tadpoles: inout [Tadpole], frogPosition: CGPoint, frogScreenPosition: CGPoint, worldOffset: CGFloat, screenHeight: CGFloat, rocketActive: Bool, onCollect: () -> Void) {
        tadpoles.removeAll { tadpole in
            let screenY = tadpole.position.y + worldOffset
            if screenY < -100 {
                // NEW: Clean up lily pad reference when removing
                tadpole.lilyPad = nil
                tadpole.node.removeFromParent()
                return true
            }
            
            let dx = frogPosition.x - tadpole.position.x
            let dy = frogPosition.y - tadpole.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < (GameConfig.frogSize / 2 + GameConfig.tadpoleSize / 2 + GameConfig.tadpolePickupPadding) {
                // NEW: Clean up lily pad reference when collecting
                tadpole.lilyPad = nil
                onCollect()
                tadpole.node.removeFromParent()
                return true
            }
            
            return false
        }
    }
    
    func updateBigHoneyPots(bigHoneyPots: inout [BigHoneyPot], frogPosition: CGPoint, frogScreenPosition: CGPoint, worldOffset: CGFloat, screenHeight: CGFloat, rocketActive: Bool, onCollect: () -> Void) {
        bigHoneyPots.removeAll { bigHoneyPot in
            let screenY = bigHoneyPot.position.y + worldOffset
            if screenY < -100 {
                // Clean up lily pad reference when removing
                bigHoneyPot.lilyPad = nil
                SoundController.shared.playSoundEffect(.specialReward)
                bigHoneyPot.node.removeFromParent()
                return true
            }
            
            let dx = frogPosition.x - bigHoneyPot.position.x
            let dy = frogPosition.y - bigHoneyPot.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Use similar collision detection to tadpoles
            let collisionDistance: CGFloat = 40 // Reasonable collision radius for big honey pot
            if distance < collisionDistance {
                // Clean up lily pad reference when collecting
                bigHoneyPot.lilyPad = nil
                onCollect()
                bigHoneyPot.node.removeFromParent()
                return true
            }
            
            return false
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
                // Clean up references before removing
                pad.occupyingEnemyTypes.removeAll()
                pad.hasFrog = false
                pad.frog = nil
                pad.node.removeFromParent()
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

