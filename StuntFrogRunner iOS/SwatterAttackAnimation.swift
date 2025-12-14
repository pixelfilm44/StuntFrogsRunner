import SpriteKit

/// A performant animation system for the frog swatting dragonflies.
/// Uses object pooling and optimized SKActions for smooth 60fps performance.
/// Dragonflies fly backward and spin away when hit.
class SwatterAttackAnimation {
    
    // MARK: - Animation Timing
    private static let frameDuration: TimeInterval = 0.06  // Quick swat motion
    private static let swatterFlightDuration: TimeInterval = 0.15  // Very fast swat
    private static let dragonflyHitDelay: TimeInterval = 0.12
    private static let dragonflyFlyAwayDuration: TimeInterval = 0.5
    
    // MARK: - Pooled Swatter Projectiles
    private static var swatterPool: [SKSpriteNode] = []
    private static let poolSize = 5
    
    /// Initializes the swatter projectile pool for performance
    static func initializePool() {
        guard swatterPool.isEmpty else { return }
        
        let swatterTexture = SKTexture(imageNamed: "swatter")
        for _ in 0..<poolSize {
            let swatter = SKSpriteNode(texture: swatterTexture)
            swatter.size = CGSize(width: 40, height: 40)
            swatter.name = "swatterProjectile"
            swatterPool.append(swatter)
        }
    }
    
    /// Gets a swatter projectile from the pool
    private static func getSwatterProjectile() -> SKSpriteNode {
        if let swatter = swatterPool.first {
            swatterPool.removeFirst()
            swatter.alpha = 1.0
            swatter.removeAllActions()
            swatter.setScale(1.0)
            swatter.zRotation = 0
            return swatter
        }
        
        // Fallback: create new if pool is empty
        let swatterTexture = SKTexture(imageNamed: "swatter")
        let swatter = SKSpriteNode(texture: swatterTexture)
        swatter.size = CGSize(width: 40, height: 40)
        swatter.name = "swatterProjectile"
        return swatter
    }
    
    /// Returns a swatter projectile to the pool
    private static func returnSwatterProjectile(_ swatter: SKSpriteNode) {
        swatter.removeFromParent()
        swatter.removeAllActions()
        if swatterPool.count < poolSize {
            swatterPool.append(swatter)
        }
    }
    
    // MARK: - Main Animation Method
    
    /// Executes the complete swatter attack animation
    /// - Parameters:
    ///   - frog: The frog entity performing the attack
    ///   - dragonfly: The dragonfly being swatted
    ///   - completion: Optional callback when animation completes
    static func executeAttack(
        frog: Frog,
        dragonfly: Enemy,
        completion: (() -> Void)? = nil
    ) {
        print("🏸 SwatterAttackAnimation.executeAttack started")
        guard let scene = frog.scene else { 
            print("🏸 ERROR: Frog has no scene!")
            return 
        }
        
        print("🏸 Scene found, initializing pool and starting animation frames")
        
        // Ensure pool is initialized
        initializePool()
        
        // FRAME 1: Frog wind-up (quick recoil)
        animateFrame1WindUp(frog: frog)
        
        // FRAME 2: Frog swat motion (quick forward lunge)
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDuration) {
            animateFrame2SwatMotion(frog: frog)
        }
        
        // FRAME 3: Launch swatter
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDuration * 2) {
            animateFrame3LaunchSwatter(frog: frog, dragonfly: dragonfly, scene: scene)
        }
        
        // FRAME 4: Dragonfly hit reaction
        DispatchQueue.main.asyncAfter(deadline: .now() + dragonflyHitDelay) {
            animateFrame4DragonflyHit(dragonfly: dragonfly)
        }
        
        // FRAME 5: Dragonfly flies away backward
        DispatchQueue.main.asyncAfter(deadline: .now() + dragonflyHitDelay + 0.05) {
            animateFrame5DragonflyFlyAway(dragonfly: dragonfly, completion: completion)
        }
        
        // Reset frog to idle after swat
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDuration * 3) {
            resetFrogToIdle(frog: frog)
        }
    }
    
    // MARK: - Frame 1: Wind-Up
    
    private static func animateFrame1WindUp(frog: Frog) {
        // Quick recoil back and slight scale up
        let recoilBack = SKAction.moveBy(x: -4, y: 0, duration: frameDuration)
        recoilBack.timingMode = .easeOut
        
        let scaleUp = SKAction.scale(to: 1.08, duration: frameDuration)
        scaleUp.timingMode = .easeOut
        
        // Slight upward tilt for swat preparation
        let tiltUp = SKAction.rotate(toAngle: -0.08, duration: frameDuration)
        tiltUp.timingMode = .easeOut
        
        frog.run(SKAction.group([recoilBack, scaleUp, tiltUp]), withKey: "swatterWindUp")
    }
    
    // MARK: - Frame 2: Swat Motion
    
    private static func animateFrame2SwatMotion(frog: Frog) {
        // Quick forward lunge
        let swatForward = SKAction.moveBy(x: 8, y: 0, duration: frameDuration)
        swatForward.timingMode = .easeIn
        
        let scaleNormal = SKAction.scale(to: 1.0, duration: frameDuration)
        scaleNormal.timingMode = .easeIn
        
        // Downward swat motion
        let swatDown = SKAction.rotate(toAngle: 0.12, duration: frameDuration * 0.5)
        let resetRotation = SKAction.rotate(toAngle: 0, duration: frameDuration * 0.5)
        let swatRotation = SKAction.sequence([swatDown, resetRotation])
        
        frog.run(SKAction.group([swatForward, scaleNormal, swatRotation]), withKey: "swatterSwat")
    }
    
    // MARK: - Frame 3: Launch Swatter
    
    private static func animateFrame3LaunchSwatter(
        frog: Frog,
        dragonfly: Enemy,
        scene: SKScene
    ) {
        let swatter = getSwatterProjectile()
        
        // Position swatter at frog's position (slightly in front and above)
        swatter.position = CGPoint(
            x: frog.position.x + 20,
            y: frog.position.y + 25
        )
        swatter.zPosition = Layer.trajectory
        
        scene.addChild(swatter)
        
        // Quick arc motion to dragonfly (swat comes from above)
        let arcHeight: CGFloat = 30
        let midPoint = CGPoint(
            x: (swatter.position.x + dragonfly.position.x) / 2,
            y: max(swatter.position.y, dragonfly.position.y) + arcHeight
        )
        
        let arc1 = SKAction.move(to: midPoint, duration: swatterFlightDuration * 0.4)
        arc1.timingMode = .easeOut
        let arc2 = SKAction.move(to: dragonfly.position, duration: swatterFlightDuration * 0.6)
        arc2.timingMode = .easeIn
        let arcPath = SKAction.sequence([arc1, arc2])
        
        // Spinning swat motion
        let spin = SKAction.rotate(byAngle: .pi * 1.5, duration: swatterFlightDuration)
        
        // Scale up during flight for impact
        let grow = SKAction.scale(to: 1.3, duration: swatterFlightDuration)
        
        let flightGroup = SKAction.group([arcPath, spin, grow])
        
        swatter.run(flightGroup) {
            // Return to pool after impact
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                returnSwatterProjectile(swatter)
            }
        }
        
        // Add impact effect
        DispatchQueue.main.asyncAfter(deadline: .now() + swatterFlightDuration) {
            createSwatImpactEffect(at: dragonfly.position, in: scene)
        }
    }
    
    // MARK: - Frame 4: Dragonfly Hit Reaction
    
    private static func animateFrame4DragonflyHit(dragonfly: Enemy) {
        // Quick shake and scale pulse
        let shakeLeft = SKAction.moveBy(x: -6, y: 0, duration: 0.03)
        let shakeRight = SKAction.moveBy(x: 6, y: 0, duration: 0.03)
        let shake = SKAction.sequence([shakeLeft, shakeRight, shakeLeft, shakeRight])
        
        // Impact pulse
        let impactScale = SKAction.sequence([
            SKAction.scale(to: 1.25, duration: 0.04),
            SKAction.scale(to: 0.95, duration: 0.04),
            SKAction.scale(to: 1.0, duration: 0.04)
        ])
        
        // Brief white flash
        let flashWhite = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 0.7, duration: 0.04),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.08)
        ])
        
        dragonfly.run(SKAction.group([shake, impactScale, flashWhite]), withKey: "swatterHit")
    }
    
    // MARK: - Frame 5: Dragonfly Fly Away
    
    private static func animateFrame5DragonflyFlyAway(
        dragonfly: Enemy,
        completion: (() -> Void)?
    ) {
        // Dragonfly gets knocked backward and spirals away
        let flyBackDistance: CGFloat = 200
        let flyUpDistance: CGFloat = 150
        
        // Backward arc trajectory
        let flyBack = SKAction.moveBy(
            x: -flyBackDistance,
            y: flyUpDistance,
            duration: dragonflyFlyAwayDuration
        )
        flyBack.timingMode = .easeOut
        
        // Rapid spinning while flying away
        let spinAway = SKAction.rotate(byAngle: .pi * 4, duration: dragonflyFlyAwayDuration)
        
        // Scale down as it flies away
        let shrink = SKAction.scale(to: 0.3, duration: dragonflyFlyAwayDuration)
        shrink.timingMode = .easeIn
        
        // Fade out
        let fadeOut = SKAction.fadeOut(withDuration: dragonflyFlyAwayDuration)
        fadeOut.timingMode = .easeIn
        
        // Add wobble effect to flight path
        let wobble1 = SKAction.moveBy(x: 20, y: 0, duration: dragonflyFlyAwayDuration * 0.25)
        let wobble2 = SKAction.moveBy(x: -40, y: 0, duration: dragonflyFlyAwayDuration * 0.25)
        let wobble3 = SKAction.moveBy(x: 40, y: 0, duration: dragonflyFlyAwayDuration * 0.25)
        let wobble4 = SKAction.moveBy(x: -20, y: 0, duration: dragonflyFlyAwayDuration * 0.25)
        let wobbleSequence = SKAction.sequence([wobble1, wobble2, wobble3, wobble4])
        
        let flyAwayGroup = SKAction.group([flyBack, spinAway, shrink, fadeOut, wobbleSequence])
        
        dragonfly.run(flyAwayGroup) {
            dragonfly.removeFromParent()
            completion?()
        }
    }
    
    // MARK: - Helper: Reset Frog
    
    private static func resetFrogToIdle(frog: Frog) {
        // Smoothly return frog to idle position
        let returnToIdle = SKAction.move(
            to: CGPoint(x: frog.position.x - 4, y: frog.position.y),
            duration: frameDuration
        )
        returnToIdle.timingMode = .easeOut
        
        frog.run(returnToIdle, withKey: "swatterReset")
    }
    
    // MARK: - Visual Effects
    
    /// Creates a swat impact effect at the hit point
    private static func createSwatImpactEffect(at position: CGPoint, in scene: SKScene) {
        // Create impact burst with motion lines
        let impactColor = UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0)  // Yellow impact
        
        // Motion lines radiating outward (like action comics)
        for i in 0..<6 {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint.zero)
            path.addLine(to: CGPoint(x: 30, y: 0))
            line.path = path
            line.strokeColor = impactColor
            line.lineWidth = 3
            line.position = position
            line.zPosition = Layer.trajectory
            line.zRotation = CGFloat(i) * (.pi / 3)  // Evenly space around circle
            line.alpha = 0.9
            
            scene.addChild(line)
            
            let expand = SKAction.scaleX(to: 2.0, duration: 0.15)
            expand.timingMode = .easeOut
            let fadeOut = SKAction.fadeOut(withDuration: 0.15)
            
            line.run(SKAction.group([expand, fadeOut])) {
                line.removeFromParent()
            }
        }
        
        // Central impact star burst
        let starBurst = SKShapeNode(circleOfRadius: 15)
        starBurst.strokeColor = .white
        starBurst.lineWidth = 4
        starBurst.fillColor = impactColor.withAlphaComponent(0.6)
        starBurst.position = position
        starBurst.zPosition = Layer.trajectory
        starBurst.setScale(0.5)
        
        scene.addChild(starBurst)
        
        let expandBurst = SKAction.scale(to: 2.5, duration: 0.2)
        expandBurst.timingMode = .easeOut
        let fadeBurst = SKAction.fadeOut(withDuration: 0.2)
        
        starBurst.run(SKAction.group([expandBurst, fadeBurst])) {
            starBurst.removeFromParent()
        }
        
        // Speed lines for "whoosh" effect
        for i in 0..<4 {
            let speedLine = SKShapeNode()
            let linePath = CGMutablePath()
            linePath.move(to: CGPoint.zero)
            linePath.addLine(to: CGPoint(x: 25, y: 0))
            speedLine.path = linePath
            speedLine.strokeColor = .white
            speedLine.lineWidth = 2
            speedLine.position = CGPoint(x: position.x - 20, y: position.y + CGFloat(i * 8 - 12))
            speedLine.zPosition = Layer.trajectory
            speedLine.alpha = 0.7
            
            scene.addChild(speedLine)
            
            let slideRight = SKAction.moveBy(x: 40, y: 0, duration: 0.12)
            slideRight.timingMode = .easeOut
            let fadeSpeed = SKAction.fadeOut(withDuration: 0.12)
            
            speedLine.run(SKAction.group([slideRight, fadeSpeed])) {
                speedLine.removeFromParent()
            }
        }
        
        // Particle burst
        let particleCount = 10
        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            particle.fillColor = impactColor
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = Layer.trajectory
            
            scene.addChild(particle)
            
            // Burst in all directions
            let angle = (CGFloat(i) / CGFloat(particleCount)) * .pi * 2
            let distance: CGFloat = CGFloat.random(in: 20...35)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            
            let burst = SKAction.moveBy(x: dx, y: dy, duration: 0.25)
            burst.timingMode = .easeOut
            
            let fadeParticle = SKAction.fadeOut(withDuration: 0.25)
            let shrinkParticle = SKAction.scale(to: 0.1, duration: 0.25)
            
            particle.run(SKAction.group([burst, fadeParticle, shrinkParticle])) {
                particle.removeFromParent()
            }
        }
    }
    
    // MARK: - Convenience Method
    
    /// Executes swatter attack on a Dragonfly
    /// Note: CollisionManager sets isBeingDestroyed before calling this, so we don't check it here
    static func attackDragonfly(_ dragonfly: Enemy, from frog: Frog, completion: (() -> Void)? = nil) {
        print("🏸 SwatterAttackAnimation.attackDragonfly called")
        print("🏸 Dragonfly type: \(dragonfly.type), isBeingDestroyed: \(dragonfly.isBeingDestroyed)")
        
        // Only verify it's a dragonfly - isBeingDestroyed is already set by CollisionManager
        guard dragonfly.type == "DRAGONFLY" else { 
            print("🏸 Guard failed - not a dragonfly!")
            return 
        }
        
        print("🏸 Executing attack animation")
        
        executeAttack(frog: frog, dragonfly: dragonfly, completion: completion)
        SoundManager.shared.play("hit")  // Play impact sound
    }
}

// MARK: - Extension for Easy Integration

extension Frog {
    /// Swats a dragonfly using optimized animation
    func swatDragonfly(_ dragonfly: Enemy, completion: (() -> Void)? = nil) {
        print("🏸 Frog.swatDragonfly called - Swatter count: \(buffs.swatter)")
        
        // Check if frog has swatter buff
        guard buffs.swatter > 0 else {
            print("🏸 Frog has no swatter!")
            return
        }
        
        // Verify target is a dragonfly
        guard dragonfly.type == "DRAGONFLY" else {
            print("🏸 Can only swat dragonflies!")
            return
        }
        
        print("🏸 Decrementing swatter count and executing animation")
        // Decrement swatter count
        buffs.swatter -= 1
        
        // Execute attack animation
        SwatterAttackAnimation.attackDragonfly(dragonfly, from: self, completion: completion)
    }
}
