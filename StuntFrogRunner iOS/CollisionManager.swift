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
                enemy.node.removeFromParent()
                return true
            }
            
            if enemy.type == .snake, let targetPad = enemy.targetLilyPad {
                let dx = enemy.position.x - targetPad.position.x
                if (enemy.speed > 0 && dx > targetPad.radius + 20) || (enemy.speed < 0 && dx < -(targetPad.radius + 20)) {
                    targetPad.removeEnemyType(enemy.type)
                    enemy.targetLilyPad = nil
                }
            }
            
            if enemy.type == .snake || enemy.type == .log {
                enemy.position.x += enemy.speed
                enemy.node.position.x = enemy.position.x
                
                if enemy.type == .log {
                    self.handleLogLilyPadCollisions(log: enemy, lilyPads: &lilyPads)
                }
                
                if rippleCounter % 15 == 0 {
                    if let gameScene = scene as? GameScene {
                        let amplitude: CGFloat = enemy.type == .log ? 0.018 : 0.012
                        let frequency: CGFloat = enemy.type == .log ? 6.0 : 8.0
                        gameScene.worldManager.addRipple(at: enemy.position, amplitude: amplitude, frequency: frequency)
                    }
                }
                
                if enemy.type == .snake, let targetPad = enemy.targetLilyPad {
                    let dx = enemy.position.x - targetPad.position.x
                    if (enemy.speed > 0 && dx >= -10 && dx <= 10) || (enemy.speed < 0 && dx >= -10 && dx <= 10) {
                        enemy.position.y = targetPad.position.y
                        enemy.node.position.y = enemy.position.y
                    }
                }
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
                                // Direction based on log movement: right-moving ~0 rad, left-moving ~Ãâ‚¬ rad
                                let dir: CGFloat = enemy.speed >= 0 ? 0.0 : .pi
                                self.uiManager?.playAxeChopEffect(at: screenPos, direction: dir)
                                HapticFeedbackManager.shared.impact(.heavy)
                            }
                            if let targetPad = enemy.targetLilyPad {
                                targetPad.removeEnemyType(enemy.type)
                            }
                            enemy.node.removeFromParent()
                            return true
                        case .hitOnly:
                            // No destruction (e.g., no axe) Ã¢â‚¬â€ perform the legacy bounce behavior ONCE and then remove the log to prevent repeat bonks
                            onLogBounce?(enemy)
                            // Clean up any lily pad occupancy
                            if let targetPad = enemy.targetLilyPad {
                                targetPad.removeEnemyType(enemy.type)
                                enemy.targetLilyPad = nil
                            }
                            // Remove the log node from the scene and signal removal from the enemies array
                            enemy.node.removeFromParent()
                            return true
                        }
                    } else {
                        let outcome = onHit(enemy)
                        switch outcome {
                        case .destroyed(let cause):
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
                            enemy.node.removeFromParent()
                            return true
                        case .hitOnly:
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
    
    // MARK: - Log-Lily Pad Physics
    
    private func handleLogLilyPadCollisions(log: Enemy, lilyPads: inout [LilyPad]) {
        guard let scene = scene else { return }
        
        let logHalfWidth = GameConfig.logWidth / 2
        let logHalfHeight = GameConfig.logHeight / 2
        
        for pad in lilyPads {
            // AABB vs circle
            let closestX = max(log.position.x - logHalfWidth,
                               min(pad.position.x, log.position.x + logHalfWidth))
            let closestY = max(log.position.y - logHalfHeight,
                               min(pad.position.y, log.position.y + logHalfHeight))
            
            let dx = pad.position.x - closestX
            let dy = pad.position.y - closestY
            let distance = sqrt(dx * dx + dy * dy)
            
            let collisionDistance = pad.radius + 5
            
            if distance < collisionDistance {
                // Normalize; protect against zero
                let invDist = distance > 0.001 ? 1.0 / distance : 0.0
                let nx = dx * invDist
                
                // Stronger, horizontal-only shove so logs can squeeze between pads
                // Scale with overlap depth; allow a higher clamp than before
                let base: CGFloat = 0.7                        // was 0.45
                let speedScale = min(1.0, abs(log.speed) / 2.5) // a bit more responsive to speed
                let penetration = (collisionDistance - distance)
                // Allow full effect at 60% of pad radius overlap, not 40%
                let penetrationScale = min(1.0, penetration / (pad.radius * 0.6))
                // Higher clamp to enable noticeable push
                let forceStrength = min(1.4, base * speedScale * (0.5 + 0.5 * penetrationScale))
                
                let force = CGPoint(x: nx * forceStrength, y: 0.0)
                pad.applyForce(force)
                
                // Maintain contact a touch longer so the wedge feels real
                // Slight slowdown (gentle) while overlapping
                let slowFactor: CGFloat = 0.94   // was 0.92; a bit less slowdown to keep logs moving
                log.speed *= slowFactor
                
                // Optional: occasional ripple
                if let gameScene = scene as? GameScene, rippleCounter % 18 == 0 {
                    gameScene.worldManager.addRipple(
                        at: CGPoint(x: closestX, y: closestY),
                        amplitude: 0.012,
                        frequency: 7.0
                    )
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
            
            if distance < (GameConfig.frogSize / 2 + GameConfig.tadpoleSize / 2) {
                // NEW: Clean up lily pad reference when collecting
                tadpole.lilyPad = nil
                onCollect()
                tadpole.node.removeFromParent()
                return true
            }
            
            return false
        }
    }
    
    func updateLilyPads(lilyPads: inout [LilyPad], worldOffset: CGFloat, screenHeight: CGFloat, frogPosition: CGPoint) {
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
    
    private func checkCollision(enemy: Enemy, frogPosition: CGPoint, frogIsJumping: Bool) -> Bool {
        // Bees and snakes should NOT collide with the frog when the frog is jumping
        // The frog can safely jump over them
        if frogIsJumping && (enemy.type == .bee || enemy.type == .snake) {
            return false
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

        default:
            let dx = frogPosition.x - enemy.position.x
            let dy = frogPosition.y - enemy.position.y
            let distance = sqrt(dx * dx + dy * dy)

            let enemySize: CGFloat
            switch enemy.type {
            case .snake: enemySize = GameConfig.snakeSize
            case .bee: enemySize = GameConfig.beeSize
            case .dragonfly: enemySize = GameConfig.dragonflySize
            case .log: enemySize = GameConfig.logCollisionWidth
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
