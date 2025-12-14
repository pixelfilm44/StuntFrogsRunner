import SpriteKit

/// A performant 5-frame animation system for the frog throwing honey at enemies.
/// Uses object pooling and optimized SKActions for smooth 60fps performance.
class HoneyAttackAnimation {
    
    // MARK: - Animation Timing
    private static let frameDuration: TimeInterval = 0.08  // 5 frames * 0.08 = 0.4s total
    private static let honeyFlightDuration: TimeInterval = 0.3
    private static let enemyHitDelay: TimeInterval = 0.25  // When enemy reacts
    private static let enemyFadeDuration: TimeInterval = 0.35
    
    // MARK: - Pooled Honey Projectiles
    private static var honeyPool: [SKSpriteNode] = []
    private static let poolSize = 5
    
    /// Initializes the honey projectile pool for performance
    static func initializePool() {
        guard honeyPool.isEmpty else { return }
        
        let honeyTexture = SKTexture(imageNamed: "honeyPot")
        for _ in 0..<poolSize {
            let honey = SKSpriteNode(texture: honeyTexture)
            honey.size = CGSize(width: 25, height: 25)
            honey.name = "honeyProjectile"
            honeyPool.append(honey)
        }
    }
    
    /// Gets a honey projectile from the pool
    private static func getHoneyProjectile() -> SKSpriteNode {
        if let honey = honeyPool.first {
            honeyPool.removeFirst()
            honey.alpha = 1.0
            honey.removeAllActions()
            honey.setScale(1.0)
            return honey
        }
        
        // Fallback: create new if pool is empty
        let honeyTexture = SKTexture(imageNamed: "honeyPot")
        let honey = SKSpriteNode(texture: honeyTexture)
        honey.size = CGSize(width: 25, height: 25)
        honey.name = "honeyProjectile"
        return honey
    }
    
    /// Returns a honey projectile to the pool
    private static func returnHoneyProjectile(_ honey: SKSpriteNode) {
        honey.removeFromParent()
        honey.removeAllActions()
        if honeyPool.count < poolSize {
            honeyPool.append(honey)
        }
    }
    
    // MARK: - Main Animation Method
    
    /// Executes the complete 5-frame honey throw animation
    /// - Parameters:
    ///   - frog: The frog entity performing the attack
    ///   - enemy: The enemy entity being attacked
    ///   - completion: Optional callback when animation completes
    static func executeAttack(
        frog: Frog,
        enemy: GameEntity,
        completion: (() -> Void)? = nil
    ) {
        guard let scene = frog.scene else { return }
        
        // Ensure pool is initialized
        initializePool()
        
        // FRAME 1: Frog wind-up (recoil back slightly)
        animateFrame1WindUp(frog: frog)
        
        // FRAME 2-3: Frog throwing motion (lean forward)
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDuration) {
            animateFrame2ThrowMotion(frog: frog)
        }
        
        // FRAME 3-4: Spawn and launch honey projectile
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDuration * 2) {
            animateFrame3LaunchHoney(frog: frog, enemy: enemy, scene: scene)
        }
        
        // FRAME 4: Enemy hit reaction
        DispatchQueue.main.asyncAfter(deadline: .now() + enemyHitDelay) {
            animateFrame4EnemyHit(enemy: enemy)
        }
        
        // FRAME 5: Enemy fade away and cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + enemyHitDelay + 0.1) {
            animateFrame5EnemyDestroy(enemy: enemy, completion: completion)
        }
        
        // Reset frog to idle after throw
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDuration * 3) {
            resetFrogToIdle(frog: frog)
        }
    }
    
    // MARK: - Frame 1: Wind-Up
    
    private static func animateFrame1WindUp(frog: Frog) {
        // Small recoil back and slight scale up for anticipation
        let recoilBack = SKAction.moveBy(x: -5, y: 0, duration: frameDuration)
        recoilBack.timingMode = .easeOut
        
        let scaleUp = SKAction.scale(to: 1.1, duration: frameDuration)
        scaleUp.timingMode = .easeOut
        
        frog.run(SKAction.group([recoilBack, scaleUp]), withKey: "honeyWindUp")
    }
    
    // MARK: - Frame 2: Throw Motion
    
    private static func animateFrame2ThrowMotion(frog: Frog) {
        // Lean forward and return to normal scale
        let throwForward = SKAction.moveBy(x: 10, y: 0, duration: frameDuration)
        throwForward.timingMode = .easeIn
        
        let scaleNormal = SKAction.scale(to: 1.0, duration: frameDuration)
        scaleNormal.timingMode = .easeIn
        
        // Slight rotation for throwing motion
        let rotateForward = SKAction.rotate(toAngle: 0.1, duration: frameDuration * 0.5)
        let rotateBack = SKAction.rotate(toAngle: 0, duration: frameDuration * 0.5)
        let rotation = SKAction.sequence([rotateForward, rotateBack])
        
        frog.run(SKAction.group([throwForward, scaleNormal, rotation]), withKey: "honeyThrow")
    }
    
    // MARK: - Frame 3: Launch Honey
    
    private static func animateFrame3LaunchHoney(
        frog: Frog,
        enemy: GameEntity,
        scene: SKScene
    ) {
        let honey = getHoneyProjectile()
        
        // Position honey at frog's position (slightly in front)
        honey.position = CGPoint(
            x: frog.position.x + 20,
            y: frog.position.y + 15
        )
        honey.zPosition = Layer.trajectory
        
        scene.addChild(honey)
        
        // Calculate trajectory to enemy
        let dx = enemy.position.x - honey.position.x
        let dy = enemy.position.y - honey.position.y
        
        // Arc motion using parabolic path
        let moveTo = SKAction.move(to: enemy.position, duration: honeyFlightDuration)
        moveTo.timingMode = .easeIn
        
        // Spin the honey as it flies
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: honeyFlightDuration)
        
        // Slight scale down during flight
        let shrink = SKAction.scale(to: 0.8, duration: honeyFlightDuration)
        
        // Arc trajectory (simulate gravity with y-offset)
        let arcHeight: CGFloat = 40
        let midPoint = CGPoint(
            x: (honey.position.x + enemy.position.x) / 2,
            y: max(honey.position.y, enemy.position.y) + arcHeight
        )
        
        let arc1 = SKAction.move(to: midPoint, duration: honeyFlightDuration * 0.5)
        arc1.timingMode = .easeOut
        let arc2 = SKAction.move(to: enemy.position, duration: honeyFlightDuration * 0.5)
        arc2.timingMode = .easeIn
        let arcPath = SKAction.sequence([arc1, arc2])
        
        // Execute flight animation
        let flightGroup = SKAction.group([arcPath, spin, shrink])
        
        honey.run(flightGroup) {
            // Return to pool after impact
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                returnHoneyProjectile(honey)
            }
        }
        
        // Add honey splash particle effect at impact point
        DispatchQueue.main.asyncAfter(deadline: .now() + honeyFlightDuration) {
            createHoneySplashEffect(at: enemy.position, in: scene)
        }
    }
    
    // MARK: - Frame 4: Enemy Hit Reaction
    
    private static func animateFrame4EnemyHit(enemy: GameEntity) {
       
        
        // Shake effect
        let shakeLeft = SKAction.moveBy(x: -5, y: 0, duration: 0.05)
        let shakeRight = SKAction.moveBy(x: 5, y: 0, duration: 0.05)
        let shake = SKAction.sequence([shakeLeft, shakeRight, shakeLeft, shakeRight])
        
        // Scale up from impact
        let impactScale = SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.05),
            SKAction.scale(to: 1.0, duration: 0.05)
        ])
        
        enemy.run(SKAction.group([shake, impactScale]), withKey: "honeyHit")
    }
    
    // MARK: - Frame 5: Enemy Destroy
    
    private static func animateFrame5EnemyDestroy(
        enemy: GameEntity,
        completion: (() -> Void)?
    ) {
        // Fade out with rotation and scale down
        let fadeOut = SKAction.fadeOut(withDuration: enemyFadeDuration)
        fadeOut.timingMode = .easeIn
        
        let scaleDown = SKAction.scale(to: 0.1, duration: enemyFadeDuration)
        scaleDown.timingMode = .easeIn
        
        let rotate = SKAction.rotate(byAngle: .pi, duration: enemyFadeDuration)
        
        // Float upward as fading
        let floatUp = SKAction.moveBy(x: 0, y: 20, duration: enemyFadeDuration)
        floatUp.timingMode = .easeOut
        
        let destroyGroup = SKAction.group([fadeOut, scaleDown, rotate, floatUp])
        
        enemy.run(destroyGroup) {
            enemy.removeFromParent()
            completion?()
        }
    }
    
    // MARK: - Helper: Reset Frog
    
    private static func resetFrogToIdle(frog: Frog) {
        // Smoothly return frog to original position
        let returnToIdle = SKAction.move(to: CGPoint(x: frog.position.x - 5, y: frog.position.y), duration: frameDuration)
        returnToIdle.timingMode = .easeOut
        
        frog.run(returnToIdle, withKey: "honeyReset")
    }
    
    // MARK: - Visual Effects
    
    /// Creates a honey splash particle effect at the impact point
    private static func createHoneySplashEffect(at position: CGPoint, in scene: SKScene) {
        // Create simple particle splash with shapes for performance
        let particleCount = 8
        let honeyColor = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        
        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: 3)
            particle.fillColor = honeyColor
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = Layer.trajectory
            
            scene.addChild(particle)
            
            // Splash outward in all directions
            let angle = (CGFloat(i) / CGFloat(particleCount)) * .pi * 2
            let distance: CGFloat = 20
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            
            let splash = SKAction.moveBy(x: dx, y: dy, duration: 0.3)
            splash.timingMode = .easeOut
            
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let shrink = SKAction.scale(to: 0.1, duration: 0.3)
            
            let splashGroup = SKAction.group([splash, fadeOut, shrink])
            
            particle.run(splashGroup) {
                particle.removeFromParent()
            }
        }
        
        // Add a central impact ring
        let impactRing = SKShapeNode(circleOfRadius: 15)
        impactRing.strokeColor = honeyColor
        impactRing.lineWidth = 3
        impactRing.fillColor = .clear
        impactRing.position = position
        impactRing.zPosition = Layer.trajectory
        impactRing.setScale(0.5)
        
        scene.addChild(impactRing)
        
        let expandRing = SKAction.scale(to: 2.0, duration: 0.25)
        expandRing.timingMode = .easeOut
        let fadeRing = SKAction.fadeOut(withDuration: 0.25)
        
        impactRing.run(SKAction.group([expandRing, fadeRing])) {
            impactRing.removeFromParent()
        }
    }
    
    // MARK: - Convenience Method for Enemy Types
    
    /// Executes honey attack on a Snake enemy
    static func attackSnake(_ snake: Snake, from frog: Frog, completion: (() -> Void)? = nil) {
        guard !snake.isDestroyed else { return }
        snake.isDestroyed = true
        executeAttack(frog: frog, enemy: snake, completion: completion)
    }
    
    /// Executes honey attack on a Cactus enemy
    static func attackCactus(_ cactus: Cactus, from frog: Frog, completion: (() -> Void)? = nil) {
        guard !cactus.isDestroyed else { return }
        cactus.isDestroyed = true
        executeAttack(frog: frog, enemy: cactus, completion: completion)
    }
}

// MARK: - Extension for Easy Integration

extension Frog {
    /// Throws honey at a target enemy using optimized animation
    func throwHoneyAt(_ enemy: GameEntity, completion: (() -> Void)? = nil) {
        // Check if frog has honey buff
        guard buffs.honey > 0 else {
            print("🍯 Frog has no honey to throw!")
            return
        }
        
        // Decrement honey count
        buffs.honey -= 1
        
        // Execute attack animation
        HoneyAttackAnimation.executeAttack(frog: self, enemy: enemy, completion: completion)
    }
}
