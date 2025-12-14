import SpriteKit

/// A performant animation system for the frog throwing an axe at logs, cacti, and snakes.
/// Uses object pooling and optimized SKActions for smooth 60fps performance.
/// Similar to HoneyAttackAnimation but with axe-specific effects.
class AxeAttackAnimation {
    
    // MARK: - Animation Timing
    private static let frameDuration: TimeInterval = 0.08  // 5 frames * 0.08 = 0.4s total
    private static let axeFlightDuration: TimeInterval = 0.25  // Faster than honey
    private static let targetHitDelay: TimeInterval = 0.2
    private static let targetDestoryDuration: TimeInterval = 0.4
    
    // MARK: - Pooled Axe Projectiles
    private static var axePool: [SKSpriteNode] = []
    private static let poolSize = 5
    
    /// Initializes the axe projectile pool for performance
    static func initializePool() {
        guard axePool.isEmpty else { return }
        
        let axeTexture = SKTexture(imageNamed: "ax")
        for _ in 0..<poolSize {
            let axe = SKSpriteNode(texture: axeTexture)
            axe.size = CGSize(width: 30, height: 30)
            axe.name = "axeProjectile"
            axePool.append(axe)
        }
    }
    
    /// Gets an axe projectile from the pool
    private static func getAxeProjectile() -> SKSpriteNode {
        if let axe = axePool.first {
            axePool.removeFirst()
            axe.alpha = 1.0
            axe.removeAllActions()
            axe.setScale(1.0)
            axe.zRotation = 0
            return axe
        }
        
        // Fallback: create new if pool is empty
        let axeTexture = SKTexture(imageNamed: "ax")
        let axe = SKSpriteNode(texture: axeTexture)
        axe.size = CGSize(width: 30, height: 30)
        axe.name = "axeProjectile"
        return axe
    }
    
    /// Returns an axe projectile to the pool
    private static func returnAxeProjectile(_ axe: SKSpriteNode) {
        axe.removeFromParent()
        axe.removeAllActions()
        if axePool.count < poolSize {
            axePool.append(axe)
        }
    }
    
    // MARK: - Main Animation Method
    
    /// Executes the complete axe throw animation
    /// - Parameters:
    ///   - frog: The frog entity performing the attack
    ///   - target: The target entity being attacked (log, cactus, or snake)
    ///   - completion: Optional callback when animation completes
    static func executeAttack(
        frog: Frog,
        target: GameEntity,
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
        
        // FRAME 3-4: Spawn and launch axe projectile
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDuration * 2) {
            animateFrame3LaunchAxe(frog: frog, target: target, scene: scene)
        }
        
        // FRAME 4: Target hit reaction
        DispatchQueue.main.asyncAfter(deadline: .now() + targetHitDelay) {
            animateFrame4TargetHit(target: target)
        }
        
        // FRAME 5: Target destruction
        DispatchQueue.main.asyncAfter(deadline: .now() + targetHitDelay + 0.1) {
            animateFrame5TargetDestroy(target: target, completion: completion)
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
        
        frog.run(SKAction.group([recoilBack, scaleUp]), withKey: "axeWindUp")
    }
    
    // MARK: - Frame 2: Throw Motion
    
    private static func animateFrame2ThrowMotion(frog: Frog) {
        // Lean forward and return to normal scale
        let throwForward = SKAction.moveBy(x: 10, y: 0, duration: frameDuration)
        throwForward.timingMode = .easeIn
        
        let scaleNormal = SKAction.scale(to: 1.0, duration: frameDuration)
        scaleNormal.timingMode = .easeIn
        
        // More pronounced rotation for powerful throw
        let rotateForward = SKAction.rotate(toAngle: 0.15, duration: frameDuration * 0.5)
        let rotateBack = SKAction.rotate(toAngle: 0, duration: frameDuration * 0.5)
        let rotation = SKAction.sequence([rotateForward, rotateBack])
        
        frog.run(SKAction.group([throwForward, scaleNormal, rotation]), withKey: "axeThrow")
    }
    
    // MARK: - Frame 3: Launch Axe
    
    private static func animateFrame3LaunchAxe(
        frog: Frog,
        target: GameEntity,
        scene: SKScene
    ) {
        let axe = getAxeProjectile()
        
        // Position axe at frog's position (slightly in front)
        axe.position = CGPoint(
            x: frog.position.x + 25,
            y: frog.position.y + 20
        )
        axe.zPosition = Layer.trajectory
        
        scene.addChild(axe)
        
        // Calculate straight line trajectory to target
        let moveTo = SKAction.move(to: target.position, duration: axeFlightDuration)
        moveTo.timingMode = .easeIn
        
        // Rapid spinning for the axe (multiple full rotations)
        let spinCount: CGFloat = 4  // 4 full spins
        let spin = SKAction.rotate(byAngle: .pi * 2 * spinCount, duration: axeFlightDuration)
        
        // Slight scale up during flight (axe gains momentum)
        let grow = SKAction.scale(to: 1.2, duration: axeFlightDuration)
        
        // Execute flight animation
        let flightGroup = SKAction.group([moveTo, spin, grow])
        
        axe.run(flightGroup) {
            // Return to pool after impact
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                returnAxeProjectile(axe)
            }
        }
        
        // Add impact effect at impact point
        DispatchQueue.main.asyncAfter(deadline: .now() + axeFlightDuration) {
            createImpactEffect(at: target.position, in: scene, targetType: type(of: target))
        }
    }
    
    // MARK: - Frame 4: Target Hit Reaction
    
    private static func animateFrame4TargetHit(target: GameEntity) {
        // Strong shake effect
        let shakeLeft = SKAction.moveBy(x: -8, y: 0, duration: 0.04)
        let shakeRight = SKAction.moveBy(x: 8, y: 0, duration: 0.04)
        let shake = SKAction.sequence([shakeLeft, shakeRight, shakeLeft, shakeRight, shakeLeft, shakeRight])
        
        // Impact scale pulse
        let impactScale = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.06),
            SKAction.scale(to: 0.9, duration: 0.06),
            SKAction.scale(to: 1.0, duration: 0.06)
        ])
        
        // Brief flash to white for impact
        let flashWhite = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        ])
        
        target.run(SKAction.group([shake, impactScale, flashWhite]), withKey: "axeHit")
    }
    
    // MARK: - Frame 5: Target Destroy
    
    private static func animateFrame5TargetDestroy(
        target: GameEntity,
        completion: (() -> Void)?
    ) {
        // Different destruction based on target type
        if target is Snake {
            destroySnake(target, completion: completion)
        } else if target is Cactus {
            destroyCactus(target, completion: completion)
        } else {
            // Assume it's a log (Pad)
            destroyLog(target, completion: completion)
        }
    }
    
    /// Snake destruction: Slice and fade
    private static func destroySnake(_ snake: GameEntity, completion: (() -> Void)?) {
        // Fade out with rotation and scale down
        let fadeOut = SKAction.fadeOut(withDuration: targetDestoryDuration)
        fadeOut.timingMode = .easeIn
        
        let scaleDown = SKAction.scale(to: 0.2, duration: targetDestoryDuration)
        scaleDown.timingMode = .easeIn
        
        let rotate = SKAction.rotate(byAngle: .pi * 1.5, duration: targetDestoryDuration)
        
        // Split apart horizontally (like being cut)
        let splitLeft = SKAction.moveBy(x: -15, y: 0, duration: targetDestoryDuration * 0.5)
        splitLeft.timingMode = .easeOut
        
        let destroyGroup = SKAction.group([fadeOut, scaleDown, rotate, splitLeft])
        
        snake.run(destroyGroup) {
            snake.removeFromParent()
            completion?()
        }
    }
    
    /// Cactus destruction: Chop and fall
    private static func destroyCactus(_ cactus: GameEntity, completion: (() -> Void)?) {
        // Tip over like being chopped at the base
        let tipOver = SKAction.rotate(byAngle: .pi / 2, duration: targetDestoryDuration)
        tipOver.timingMode = .easeIn
        
        let fallDown = SKAction.moveBy(x: 20, y: -30, duration: targetDestoryDuration)
        fallDown.timingMode = .easeIn
        
        let fadeOut = SKAction.fadeOut(withDuration: targetDestoryDuration)
        fadeOut.timingMode = .easeIn
        
        let destroyGroup = SKAction.group([tipOver, fallDown, fadeOut])
        SoundManager.shared.play("chop")

        cactus.run(destroyGroup) {
            cactus.removeFromParent()
            completion?()
        }
    }
    
    /// Log destruction: Break apart and sink
    private static func destroyLog(_ log: GameEntity, completion: (() -> Void)?) {
        // Break into pieces effect
        let fadeOut = SKAction.fadeOut(withDuration: targetDestoryDuration)
        fadeOut.timingMode = .easeIn
        SoundManager.shared.play("chop")

        let scaleDown = SKAction.scale(to: 0.3, duration: targetDestoryDuration)
        scaleDown.timingMode = .easeIn
        
        // Rotate and sink like a log would
        let rotate = SKAction.rotate(byAngle: .pi * 0.5, duration: targetDestoryDuration)
        
        // Sink downward (logs sink in water)
        let sink = SKAction.moveBy(x: 0, y: -40, duration: targetDestoryDuration)
        sink.timingMode = .easeIn
        
        let destroyGroup = SKAction.group([fadeOut, scaleDown, rotate, sink])
        
        log.run(destroyGroup) {
            log.removeFromParent()
            completion?()
        }
    }
    
    // MARK: - Helper: Reset Frog
    
    private static func resetFrogToIdle(frog: Frog) {
        // Smoothly return frog to original position
        let returnToIdle = SKAction.move(to: CGPoint(x: frog.position.x - 5, y: frog.position.y), duration: frameDuration)
        returnToIdle.timingMode = .easeOut
        
        frog.run(returnToIdle, withKey: "axeReset")
    }
    
    // MARK: - Visual Effects
    
    /// Creates an impact effect at the hit point
    private static func createImpactEffect(at position: CGPoint, in scene: SKScene, targetType: Any.Type) {
        // Choose effect color based on target type
        let effectColor: UIColor
        let particleCount: Int
        
        if targetType is Snake.Type {
            effectColor = UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0)  // Green for snake
            particleCount = 10
        } else if targetType is Cactus.Type {
            effectColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)  // Light green for cactus
            particleCount = 12
        } else {
            effectColor = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)  // Brown for log
            particleCount = 15
        }
        
        // Create particle burst
        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            particle.fillColor = effectColor
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = Layer.trajectory
            
            scene.addChild(particle)
            
            // Burst outward in all directions
            let angle = (CGFloat(i) / CGFloat(particleCount)) * .pi * 2
            let distance: CGFloat = CGFloat.random(in: 25...40)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            
            let burst = SKAction.moveBy(x: dx, y: dy, duration: 0.35)
            burst.timingMode = .easeOut
            
            let fadeOut = SKAction.fadeOut(withDuration: 0.35)
            let shrink = SKAction.scale(to: 0.1, duration: 0.35)
            
            // Add gravity effect (particles fall down)
            let fall = SKAction.moveBy(x: 0, y: -20, duration: 0.35)
            fall.timingMode = .easeIn
            
            let burstGroup = SKAction.group([burst, fadeOut, shrink, fall])
            
            particle.run(burstGroup) {
                particle.removeFromParent()
            }
        }
        
        // Add central impact flash
        let impactFlash = SKShapeNode(circleOfRadius: 20)
        impactFlash.strokeColor = .white
        impactFlash.lineWidth = 4
        impactFlash.fillColor = effectColor.withAlphaComponent(0.5)
        impactFlash.position = position
        impactFlash.zPosition = Layer.trajectory
        impactFlash.setScale(0.3)
        
        scene.addChild(impactFlash)
        
        let expandFlash = SKAction.scale(to: 2.5, duration: 0.2)
        expandFlash.timingMode = .easeOut
        let fadeFlash = SKAction.fadeOut(withDuration: 0.2)
        
        impactFlash.run(SKAction.group([expandFlash, fadeFlash])) {
            impactFlash.removeFromParent()
        }
        
        // Add impact slash lines for extra effect
        createSlashLines(at: position, in: scene)
    }
    
    /// Creates slash effect lines at impact
    private static func createSlashLines(at position: CGPoint, in scene: SKScene) {
        for i in 0..<3 {
            let slash = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint.zero)
            path.addLine(to: CGPoint(x: 25, y: 0))
            slash.path = path
            slash.strokeColor = .white
            slash.lineWidth = 2
            slash.position = position
            slash.zPosition = Layer.trajectory
            slash.zRotation = CGFloat(i) * (.pi / 3) + .pi / 4  // Angle the slashes
            slash.alpha = 0.8
            
            scene.addChild(slash)
            
            let fadeOut = SKAction.fadeOut(withDuration: 0.15)
            let expand = SKAction.scaleX(to: 1.5, duration: 0.15)
            
            slash.run(SKAction.group([fadeOut, expand])) {
                slash.removeFromParent()
            }
        }
    }
    
    // MARK: - Convenience Methods for Different Target Types
    
    /// Executes axe attack on a Snake
    static func attackSnake(_ snake: Snake, from frog: Frog, completion: (() -> Void)? = nil) {
        guard !snake.isDestroyed else { return }
        snake.isDestroyed = true
        executeAttack(frog: frog, target: snake, completion: completion)
        SoundManager.shared.play("hit")  // Play impact sound
    }
    
    /// Executes axe attack on a Cactus
    static func attackCactus(_ cactus: Cactus, from frog: Frog, completion: (() -> Void)? = nil) {
        guard !cactus.isDestroyed else { return }
        cactus.isDestroyed = true
        executeAttack(frog: frog, target: cactus, completion: completion)
        SoundManager.shared.play("hit")  // Play impact sound
    }
    
    /// Executes axe attack on a Log (Pad)
    static func attackLog(_ log: Pad, from frog: Frog, completion: (() -> Void)? = nil) {
        guard log.type == .log else { return }
        executeAttack(frog: frog, target: log, completion: completion)
        SoundManager.shared.play("hit")  // Play impact sound
    }
}

// MARK: - Extension for Easy Integration

extension Frog {
    /// Throws axe at a target (log, cactus, or snake) using optimized animation
    func throwAxeAt(_ target: GameEntity, completion: (() -> Void)? = nil) {
        // Check if frog has axe buff
        guard buffs.axe > 0 else {
            print("🪓 Frog has no axe to throw!")
            return
        }
        
        // Decrement axe count
        buffs.axe -= 1
        
        // Execute attack animation based on target type
        if let snake = target as? Snake {
            AxeAttackAnimation.attackSnake(snake, from: self, completion: completion)
        } else if let cactus = target as? Cactus {
            AxeAttackAnimation.attackCactus(cactus, from: self, completion: completion)
        } else if let log = target as? Pad, log.type == .log {
            AxeAttackAnimation.attackLog(log, from: self, completion: completion)
        } else {
            print("🪓 Invalid target for axe attack!")
        }
    }
}
