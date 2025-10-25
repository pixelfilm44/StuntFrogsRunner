//
//  CollisionManager.swift
//  Top-down collision detection
//

import SpriteKit

// Richer outcome for handling hits vs destroys and their causes
enum HitOutcome {
    case hitOnly
    case destroyed(cause: AbilityType?)
}

class CollisionManager {
    weak var scene: SKScene?
    weak var effectsManager: EffectsManager?
    weak var uiManager: UIManager?
    
    init(scene: SKScene, uiManager: UIManager? = nil) {
        self.scene = scene
        self.uiManager = uiManager
    }
    
    func updateEnemies(enemies: inout [Enemy], frogPosition: CGPoint, frogScreenPosition: CGPoint, invincible: Bool, rocketActive: Bool, worldOffset: CGFloat, onHit: (Enemy) -> HitOutcome, onLogBounce: ((Enemy) -> Void)? = nil) {
        guard let scene = scene else { return }
        
        enemies.removeAll { enemy in
            // Check if off screen first, and clean up lily pad occupancy
            let screenY = enemy.position.y + worldOffset
            if screenY < -100 || enemy.position.x < -150 || enemy.position.x > scene.size.width + 150 {
                // Clean up lily pad occupancy if this enemy was targeting one
                if let targetPad = enemy.targetLilyPad {
                    targetPad.removeEnemyType(enemy.type)
                }
                enemy.node.removeFromParent()
                return true
            }
            
            // For snakes, also clean up lily pad occupancy when they pass their target
            if enemy.type == .snake, let targetPad = enemy.targetLilyPad {
                let dx = enemy.position.x - targetPad.position.x
                // Snake has passed the lily pad completely
                if (enemy.speed > 0 && dx > targetPad.radius + 20) || (enemy.speed < 0 && dx < -(targetPad.radius + 20)) {
                    targetPad.removeEnemyType(enemy.type)
                    enemy.targetLilyPad = nil  // Clear the reference
                }
            }
            
            // Update enemy movement
            if enemy.type == .snake || enemy.type == .log {
                // Snakes and logs move horizontally
                enemy.position.x += enemy.speed
                enemy.node.position.x = enemy.position.x
                
                // Special handling for snakes targeting lily pads
                if enemy.type == .snake, let targetPad = enemy.targetLilyPad {
                    let dx = enemy.position.x - targetPad.position.x
                    // Check if snake has reached the lily pad horizontally
                    if (enemy.speed > 0 && dx >= -10 && dx <= 10) || (enemy.speed < 0 && dx >= -10 && dx <= 10) {
                        // Snake is over the lily pad - swim across it but don't stop
                        enemy.position.y = targetPad.position.y
                        enemy.node.position.y = enemy.position.y
                        // Continue horizontal movement - don't stop on the pad
                    }
                }
            } else if enemy.type == .bee {
                // Bees move in gentle circles around their target lily pad (if any)
                let time = CGFloat(CACurrentMediaTime())
                if let targetPad = enemy.targetLilyPad {
                    // Orbit around the target lily pad
                    let orbitRadius: CGFloat = 30
                    enemy.position.x = targetPad.position.x + cos(time * 2) * orbitRadius
                    enemy.position.y = targetPad.position.y + sin(time * 2) * orbitRadius
                } else {
                    // Free-flying bee (fallback behavior)
                    enemy.position.x += cos(time) * 0.5
                    enemy.position.y += sin(time) * 0.3
                }
                enemy.node.position = enemy.position
            } else if enemy.type == .dragonfly {
                // Dragonflies move upward (against scroll)
                enemy.position.y += enemy.speed
                enemy.node.position.y = enemy.position.y
            }
            
            // Check collision with frog
            if checkCollision(enemy: enemy, frogPosition: frogPosition) {
                if enemy.type == .log {
                    // During rocket flight, frog flies over logs without collision
                    if rocketActive {
                        // No collision during rocket flight - frog is flying above
                        return false // Keep the log but no hit
                    }

                    // Allow the game scene to consume protections (e.g., Axe) and decide outcome
                    let outcome = onHit(enemy)
                    switch outcome {
                    case .destroyed:
                        // Clean up any lily pad occupancy and remove the log
                        if let targetPad = enemy.targetLilyPad {
                            targetPad.removeEnemyType(enemy.type)
                        }
                        // Award bonus for tree/log destroyed
                        awardBonusIfEligible(for: enemy.type, at: frogScreenPosition)
                        enemy.node.removeFromParent()
                        return true
                    case .hitOnly:
                        // No protection consumed: perform the legacy bounce behavior and keep the log
                        onLogBounce?(enemy)
                        effectsManager?.createEnemyHitEffect(at: frogScreenPosition, enemyType: enemy.type)
                        return false
                    }
                } else {
                    // Other enemies only hit when not invincible
                    if !invincible {
                        let outcome = onHit(enemy)
                        switch outcome {
                        case .hitOnly:
                            // Regular hit but not destroyed; keep enemy
                            return false
                        case .destroyed(let cause):
                            // Clean up lily pad occupancy before removing enemy
                            if let targetPad = enemy.targetLilyPad {
                                targetPad.removeEnemyType(enemy.type)
                            }

                            // If we know the ability cause, play themed effect
                            if let cause = cause {
                                switch cause {
                                case .honeyJar:
                                    uiManager?.playHoneyJarEffect(at: frogScreenPosition)
                                case .axe:
                                    // Derive a slash direction from frog to enemy for visual consistency
                                    let dx = enemy.position.x - frogPosition.x
                                    let dy = enemy.position.y - frogPosition.y
                                    let angle = CGFloat(atan2(Double(dy), Double(dx)))
                                    uiManager?.playAxeChopEffect(at: frogScreenPosition, direction: angle)
                                default:
                                    // Other abilities fall back to generic destroy effect for now
                                    createEnemyDestroyEffect(at: frogScreenPosition, enemyType: enemy.type)
                                }
                            } else {
                                // Unknown cause; use generic destroy effect
                                createEnemyDestroyEffect(at: frogScreenPosition, enemyType: enemy.type)
                            }

                            // Award bonus for eligible enemy types
                            awardBonusIfEligible(for: enemy.type, at: frogScreenPosition)

                            enemy.node.removeFromParent()
                            return true
                        }
                    }
                }
            }
            
            return false
        }
    }
    
    func updateTadpoles(tadpoles: inout [Tadpole], frogPosition: CGPoint, frogScreenPosition: CGPoint, worldOffset: CGFloat, rocketActive: Bool, onCollect: () -> Void) {
        guard let scene = scene else { return }
        
        tadpoles.removeAll { tadpole in
            // Check if off screen
            let screenY = tadpole.position.y + worldOffset
            if screenY < -100 {
                tadpole.node.removeFromParent()
                return true
            }
            
            // Check collection (skip during rocket flight)
            if !rocketActive && checkCollisionTadpole(tadpole: tadpole, frogPosition: frogPosition) {
                onCollect()
                
                // Build a small group: star sprite + "+1" label, animate together
                let group = SKNode()
                group.position = frogScreenPosition
                group.zPosition = 150
                scene.addChild(group)
                
                let starTexture = SKTexture(imageNamed: "star")
                let star = SKSpriteNode(texture: starTexture)
                star.size = CGSize(width: 24, height: 24)
                star.position = CGPoint(x: -12, y: 0)
                group.addChild(star)
                
                let plusOne = SKLabelNode(text: "+1")
                plusOne.fontSize = 22
                plusOne.fontColor = .yellow
                plusOne.fontName = "Arial-BoldMT"
                plusOne.verticalAlignmentMode = .center
                plusOne.horizontalAlignmentMode = .left
                plusOne.position = CGPoint(x: 4, y: 0)
                group.addChild(plusOne)
                
                let collectAnimation = SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: 0, y: 50, duration: 0.6),
                        SKAction.fadeOut(withDuration: 0.6),
                        SKAction.scale(to: 1.5, duration: 0.6)
                    ]),
                    SKAction.removeFromParent()
                ])
                group.run(collectAnimation)
                
                // Sparkle effect
                for i in 0..<6 {
                    let angle = CGFloat(i) * (.pi * 2 / 6)
                    let sparkle = SKLabelNode(text: "✨")
                    sparkle.fontSize = 20
                    sparkle.position = frogScreenPosition
                    sparkle.zPosition = 149
                    scene.addChild(sparkle)
                    
                    let sparkleAction = SKAction.sequence([
                        SKAction.group([
                            SKAction.moveBy(x: cos(angle) * 40, y: sin(angle) * 40, duration: 0.5),
                            SKAction.fadeOut(withDuration: 0.5),
                            SKAction.rotate(byAngle: .pi * 2, duration: 0.5)
                        ]),
                        SKAction.removeFromParent()
                    ])
                    sparkle.run(sparkleAction)
                }
                
                tadpole.node.removeFromParent()
                return true
            }
            
            return false
        }
    }
    
    func updateLilyPads(lilyPads: inout [LilyPad], worldOffset: CGFloat, screenHeight: CGFloat, frogPosition: CGPoint) {
        // Remove lily pads that scrolled off bottom
        // BUT keep pads that are behind the frog for a while (safety buffer)
        lilyPads.removeAll { pad in
            let screenY = pad.position.y + worldOffset
            let isBehindFrog = pad.position.y < frogPosition.y - 500  // 500 units behind
            
            // Only remove if WAY off screen AND behind frog
            if screenY < -150 && isBehindFrog {
                // Clear any enemy occupancy when removing the lily pad
                pad.occupyingEnemyTypes.removeAll()
                pad.node.removeFromParent()
                return true
            }
            return false
        }
    }
    
    private func checkCollision(enemy: Enemy, frogPosition: CGPoint) -> Bool {
        switch enemy.type {
        case .log:
            // Rect-based collision for logs, expanded by frog radius for circle-rect overlap
            let halfW = GameConfig.logWidth / 2
            let halfH = GameConfig.logHeight / 2
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
            case .log: fatalError("log handled above")
            }

            let baseThreshold = (GameConfig.frogSize + enemySize) / 2.5
            let threshold: CGFloat
            if enemy.type == .dragonfly {
                threshold = baseThreshold * GameConfig.dragonflyHitboxMultiplier
            } else {
                threshold = baseThreshold
            }
            return distance < threshold
        }
    }
    
    private func checkCollisionTadpole(tadpole: Tadpole, frogPosition: CGPoint) -> Bool {
        let dx = frogPosition.x - tadpole.position.x
        let dy = frogPosition.y - tadpole.position.y
        let distance = sqrt(dx * dx + dy * dy)
        
        return distance < (GameConfig.frogSize + GameConfig.tadpoleSize)
    }
    
    // MARK: - Local destroy effect (distinct from a hit)
    private func createEnemyDestroyEffect(at position: CGPoint, enemyType: EnemyType) {
        guard let scene = scene else { return }

        // A small "poof" plus directional sparkles to differentiate from a hit
        let poof = SKLabelNode(text: "💥")
        poof.fontSize = 36
        poof.position = position
        poof.zPosition = 200
        poof.alpha = 0.0
        scene.addChild(poof)

        let appear = SKAction.group([
            SKAction.fadeAlpha(to: 1.0, duration: 0.06),
            SKAction.scale(to: 1.2, duration: 0.08)
        ])
        appear.timingMode = .easeOut
        let settle = SKAction.scale(to: 0.9, duration: 0.1)
        settle.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: 0.18)
        let remove = SKAction.removeFromParent()
        poof.run(SKAction.sequence([appear, settle, fade, remove]))

        // 8 sparkles flying outwards
        let sparkleCount = 8
        for i in 0..<sparkleCount {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(sparkleCount))
            let sparkle = SKLabelNode(text: "✨")
            sparkle.fontSize = 18
            sparkle.position = position
            sparkle.zPosition = 199
            sparkle.alpha = 0.9
            scene.addChild(sparkle)

            let distance: CGFloat = 48
            let move = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.25)
            move.timingMode = .easeOut
            let spin = SKAction.rotate(byAngle: .pi, duration: 0.25)
            let fadeOut = SKAction.fadeOut(withDuration: 0.25)
            let group = SKAction.group([move, spin, fadeOut])
            sparkle.run(SKAction.sequence([group, remove]))
        }
    }
    
    // MARK: - Bonus award
    private func awardBonusIfEligible(for type: EnemyType, at screenPosition: CGPoint) {
        guard type == .bee || type == .dragonfly || type == .log else { return }
        guard let scene = scene else { return }
        
        // Add +200 floating label
        let label = SKLabelNode(text: "+200")
        label.fontName = "Arial-BoldMT"
        label.fontSize = 22
        label.fontColor = .systemGreen
        label.position = screenPosition
        label.zPosition = 220
        scene.addChild(label)
        
        let rise = SKAction.moveBy(x: 0, y: 48, duration: 0.8)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.8)
        let scale = SKAction.scale(to: 1.3, duration: 0.8)
        let group = SKAction.group([rise, fade, scale])
        label.run(SKAction.sequence([group, .removeFromParent()]))

        // Increment score on GameScene
        if let gs = scene as? GameScene {
            gs.score += 200
        }
    }
}

