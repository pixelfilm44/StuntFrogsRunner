import SpriteKit

/// A performant 5-frame animation system for the frog holding a cross to dissolve ghost enemies.
/// Uses object pooling and optimized SKActions for smooth 60fps performance.
class CrossAttackAnimation {
    
    // MARK: - Animation Timing
    private static let frameDuration: TimeInterval = 0.08  // 5 frames * 0.08 = 0.4s total
    private static let crossHoldDuration: TimeInterval = 0.5  // How long the cross is held up
    private static let ghostReactDelay: TimeInterval = 0.2  // When ghost starts reacting
    private static let ghostDissolveDuration: TimeInterval = 0.6
    
    // MARK: - Pooled Cross Sprites
    private static var crossPool: [SKSpriteNode] = []
    private static let poolSize = 3
    
    /// Initializes the cross sprite pool for performance
    static func initializePool() {
        guard crossPool.isEmpty else { return }
        
        let crossTexture = SKTexture(imageNamed: "cross")
        for _ in 0..<poolSize {
            let cross = SKSpriteNode(texture: crossTexture)
            cross.size = CGSize(width: 30, height: 30)
            cross.name = "crossSprite"
            crossPool.append(cross)
        }
    }
    
    /// Gets a cross sprite from the pool
    private static func getCrossSprite() -> SKSpriteNode {
        if let cross = crossPool.first {
            crossPool.removeFirst()
            cross.alpha = 1.0
            cross.removeAllActions()
            cross.setScale(1.0)
            return cross
        }
        
        // Fallback: create new if pool is empty
        let crossTexture = SKTexture(imageNamed: "cross")
        let cross = SKSpriteNode(texture: crossTexture)
        cross.size = CGSize(width: 30, height: 30)
        cross.name = "crossSprite"
        return cross
    }
    
    /// Returns a cross sprite to the pool
    private static func returnCrossSprite(_ cross: SKSpriteNode) {
        cross.removeFromParent()
        cross.removeAllActions()
        if crossPool.count < poolSize {
            crossPool.append(cross)
        }
    }
    
    // MARK: - Main Animation Method
    
    /// Executes the complete cross banishment animation
    /// - Parameters:
    ///   - frog: The frog entity performing the banishment
    ///   - ghost: The ghost enemy being banished
    ///   - completion: Optional callback when animation completes
    static func executeAttack(
        frog: Frog,
        ghost: GameEntity,
        completion: (() -> Void)? = nil
    ) {
        print("✝️ CrossAttackAnimation.executeAttack called")
        print("   - Frog position: \(frog.position)")
        print("   - Ghost position: \(ghost.position)")
        print("   - Scene: \(frog.scene != nil ? "Available" : "MISSING!")")
        
        guard let scene = frog.scene else {
            print("❌ ERROR: Frog has no scene! Animation cannot play.")
            return
        }
        
        print("✅ Scene available, starting animation sequence...")
        
        // Ensure pool is initialized
        initializePool()
        
        // FRAME 1: Frog reaches for cross (slight crouch)
        animateFrame1Reach(frog: frog)
        
        // FRAME 2: Frog pulls out cross
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDuration) {
            print("✝️ Frame 2: Pulling out cross")
            animateFrame2PullOutCross(frog: frog, scene: scene)
        }
        
        // FRAME 3: Frog holds cross high (cross appears)
        let crossSprite = getCrossSprite()
        DispatchQueue.main.asyncAfter(deadline: .now() + frameDuration * 2) {
            print("✝️ Frame 3: Cross appears and holy light activates")
            animateFrame3HoldCrossHigh(frog: frog, cross: crossSprite, scene: scene)
            // Play a dramatic sound when the cross appears
            SoundManager.shared.play("coin") // Using coin as a "holy" sound - could be replaced with custom sound
        }
        
        // FRAME 4: Ghost reacts and starts dissolving
        DispatchQueue.main.asyncAfter(deadline: .now() + ghostReactDelay) {
            print("👻 Frame 4: Ghost reacts to the cross")
            animateFrame4GhostReacts(ghost: ghost)
            // Play ghost reaction sound
            SoundManager.shared.play("ghost")
        }
        
        // FRAME 5: Ghost fully dissolves away
        DispatchQueue.main.asyncAfter(deadline: .now() + ghostReactDelay + 0.15) {
            print("💨 Frame 5: Ghost dissolves away")
            animateFrame5GhostDissolve(ghost: ghost, completion: completion)
        }
        
        // Lower cross and return frog to idle
        DispatchQueue.main.asyncAfter(deadline: .now() + crossHoldDuration) {
            print("✝️ Lowering cross and returning frog to idle")
            animateCrossLower(cross: crossSprite, frog: frog)
        }
    }
    
    // MARK: - Frame 1: Reach for Cross
    
    private static func animateFrame1Reach(frog: Frog) {
        // Slight crouch as frog reaches for the cross
        let crouch = SKAction.scale(to: 0.95, duration: frameDuration)
        crouch.timingMode = .easeOut
        
        frog.run(crouch, withKey: "crossReach")
    }
    
    // MARK: - Frame 2: Pull Out Cross
    
    private static func animateFrame2PullOutCross(frog: Frog, scene: SKScene) {
        // Frog rises back up slightly
        let rise = SKAction.scale(to: 1.05, duration: frameDuration)
        rise.timingMode = .easeIn
        
        frog.run(rise, withKey: "crossPullOut")
    }
    
    // MARK: - Frame 3: Hold Cross High
    
    private static func animateFrame3HoldCrossHigh(
        frog: Frog,
        cross: SKSpriteNode,
        scene: SKScene
    ) {
        // Position cross above and in front of frog
        cross.position = CGPoint(
            x: frog.position.x,
            y: frog.position.y + 45
        )
        cross.zPosition = Layer.trajectory
        cross.alpha = 0
        cross.setScale(0.5)
        
        scene.addChild(cross)
        
        // Cross appears with a glow effect
        let appear = SKAction.fadeIn(withDuration: 0.15)
        let grow = SKAction.scale(to: 1.2, duration: 0.15)
        grow.timingMode = .easeOut
        
        // Add a subtle pulse
        let pulse1 = SKAction.scale(to: 1.3, duration: 0.2)
        let pulse2 = SKAction.scale(to: 1.2, duration: 0.2)
        let pulseSequence = SKAction.sequence([pulse1, pulse2])
        let continuousPulse = SKAction.repeatForever(pulseSequence)
        
        cross.run(SKAction.group([appear, grow])) {
            cross.run(continuousPulse, withKey: "crossPulse")
        }
        
        // Add holy light effect around the cross
        createHolyLightEffect(at: cross.position, in: scene, attachTo: cross)
        
        // Frog holds steady with cross raised
        let holdSteady = SKAction.scale(to: 1.0, duration: frameDuration)
        frog.run(holdSteady, withKey: "crossHold")
    }
    
    // MARK: - Frame 4: Ghost Reacts
    
    private static func animateFrame4GhostReacts(ghost: GameEntity) {
        // Ghost recoils and shakes violently
        let recoil = SKAction.moveBy(x: -10, y: 5, duration: 0.1)
        recoil.timingMode = .easeOut
        
        // Rapid shaking
        let shakeLeft = SKAction.moveBy(x: -4, y: 0, duration: 0.05)
        let shakeRight = SKAction.moveBy(x: 4, y: 0, duration: 0.05)
        let shakeUp = SKAction.moveBy(x: 0, y: 4, duration: 0.05)
        let shakeDown = SKAction.moveBy(x: 0, y: -4, duration: 0.05)
        let shake = SKAction.sequence([shakeLeft, shakeRight, shakeUp, shakeDown])
        let rapidShake = SKAction.repeat(shake, count: 3)
        
        // Start flickering (alpha oscillation)
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.1)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        let flicker = SKAction.sequence([fadeOut, fadeIn])
        let continuousFlicker = SKAction.repeat(flicker, count: 5)
        
        ghost.run(SKAction.sequence([recoil, SKAction.group([rapidShake, continuousFlicker])]), withKey: "ghostReact")
    }
    
    // MARK: - Frame 5: Ghost Dissolves
    
    private static func animateFrame5GhostDissolve(
        ghost: GameEntity,
        completion: (() -> Void)?
    ) {
        guard let scene = ghost.scene else {
            completion?()
            return
        }
        
        // Create dissolve particle effect
        createDissolveParticles(for: ghost, in: scene)
        
        // Ghost fades out with distortion effect
        let fadeOut = SKAction.fadeOut(withDuration: ghostDissolveDuration)
        fadeOut.timingMode = .easeIn
        
        // Scale down to nothing
        let scaleDown = SKAction.scale(to: 0.01, duration: ghostDissolveDuration)
        scaleDown.timingMode = .easeIn
        
        // Spin as dissolving
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: ghostDissolveDuration)
        
        // Float upward and drift slightly
        let floatUp = SKAction.moveBy(x: CGFloat.random(in: -15...15), y: 30, duration: ghostDissolveDuration)
        floatUp.timingMode = .easeOut
        
        // Combine all dissolution effects
        let dissolveGroup = SKAction.group([fadeOut, scaleDown, spin, floatUp])
        
        ghost.run(dissolveGroup) {
            ghost.removeFromParent()
            completion?()
        }
    }
    
    // MARK: - Cross Lower Animation
    
    private static func animateCrossLower(cross: SKSpriteNode, frog: Frog) {
        // Stop pulsing
        cross.removeAction(forKey: "crossPulse")
        
        // Lower the cross and fade it away
        let lower = SKAction.moveBy(x: 0, y: -20, duration: 0.25)
        lower.timingMode = .easeIn
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.25)
        let shrink = SKAction.scale(to: 0.5, duration: 0.25)
        
        let lowerGroup = SKAction.group([lower, fadeOut, shrink])
        
        cross.run(lowerGroup) {
            returnCrossSprite(cross)
        }
        
        // Frog returns to normal stance
        let returnToNormal = SKAction.scale(to: 1.0, duration: 0.2)
        returnToNormal.timingMode = .easeOut
        frog.run(returnToNormal, withKey: "crossLower")
    }
    
    // MARK: - Visual Effects
    
    /// Creates a holy light effect around the cross
    private static func createHolyLightEffect(at position: CGPoint, in scene: SKScene, attachTo parent: SKNode) {
        // Create radial light rays
        let rayCount = 8
        let holyColor = UIColor(red: 1.0, green: 1.0, blue: 0.9, alpha: 0.6)
        
        for i in 0..<rayCount {
            let ray = SKShapeNode(rectOf: CGSize(width: 3, height: 25))
            ray.fillColor = holyColor
            ray.strokeColor = .clear
            ray.position = .zero
            ray.zPosition = -1  // Behind the cross
            
            // Rotate rays evenly around the cross
            let angle = (CGFloat(i) / CGFloat(rayCount)) * .pi * 2
            ray.zRotation = angle
            
            parent.addChild(ray)
            
            // Gentle rotation of rays
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 3.0)
            let rotateForever = SKAction.repeatForever(rotate)
            ray.run(rotateForever)
            
            // Fade in the rays
            ray.alpha = 0
            ray.run(SKAction.fadeAlpha(to: 0.6, duration: 0.2))
        }
        
        // Add a glowing circle around the cross
        let glow = SKShapeNode(circleOfRadius: 20)
        glow.fillColor = UIColor(red: 1.0, green: 1.0, blue: 0.9, alpha: 0.2)
        glow.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 0.4)
        glow.lineWidth = 2
        glow.position = .zero
        glow.zPosition = -2
        glow.setScale(0.5)
        
        parent.addChild(glow)
        
        // Glow pulses
        let expandGlow = SKAction.scale(to: 1.2, duration: 0.3)
        let contractGlow = SKAction.scale(to: 0.8, duration: 0.3)
        let glowPulse = SKAction.sequence([expandGlow, contractGlow])
        let glowForever = SKAction.repeatForever(glowPulse)
        
        glow.alpha = 0
        glow.run(SKAction.fadeAlpha(to: 0.3, duration: 0.2)) {
            glow.run(glowForever)
        }
    }
    
    /// Creates particle effect for ghost dissolution
    private static func createDissolveParticles(for ghost: GameEntity, in scene: SKScene) {
        let particleCount = 20
        let ghostColor = UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 0.8)  // Pale ghostly blue-white
        
        // Create particles that float up and fade away
        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
            particle.fillColor = ghostColor
            particle.strokeColor = .clear
            particle.position = CGPoint(
                x: ghost.position.x + CGFloat.random(in: -20...20),
                y: ghost.position.y + CGFloat.random(in: -20...20)
            )
            particle.zPosition = Layer.trajectory
            particle.alpha = 0.8
            
            scene.addChild(particle)
            
            // Particles float upward and fade
            let floatDistance: CGFloat = CGFloat.random(in: 40...80)
            let floatDuration = TimeInterval.random(in: 0.8...1.2)
            
            let floatUp = SKAction.moveBy(
                x: CGFloat.random(in: -20...20),
                y: floatDistance,
                duration: floatDuration
            )
            floatUp.timingMode = .easeOut
            
            let fadeOut = SKAction.fadeOut(withDuration: floatDuration)
            let shrink = SKAction.scale(to: 0.1, duration: floatDuration)
            
            let particleGroup = SKAction.group([floatUp, fadeOut, shrink])
            
            // Stagger particle animations slightly
            let delay = SKAction.wait(forDuration: TimeInterval.random(in: 0...0.2))
            let sequence = SKAction.sequence([delay, particleGroup])
            
            particle.run(sequence) {
                particle.removeFromParent()
            }
        }
        
        // Add a dissolve wave that expands from ghost center
        let dissolveWave = SKShapeNode(circleOfRadius: 10)
        dissolveWave.strokeColor = ghostColor
        dissolveWave.lineWidth = 3
        dissolveWave.fillColor = .clear
        dissolveWave.position = ghost.position
        dissolveWave.zPosition = Layer.trajectory
        
        scene.addChild(dissolveWave)
        
        let expandWave = SKAction.scale(to: 4.0, duration: 0.6)
        expandWave.timingMode = .easeOut
        let fadeWave = SKAction.fadeOut(withDuration: 0.6)
        
        dissolveWave.run(SKAction.group([expandWave, fadeWave])) {
            dissolveWave.removeFromParent()
        }
    }
    
    // MARK: - Convenience Method for Enemy Types
    
    /// Executes cross banishment on a ghost enemy
    static func banishGhost(_ ghost: GameEntity, from frog: Frog, completion: (() -> Void)? = nil) {
        executeAttack(frog: frog, ghost: ghost, completion: completion)
    }
}

// MARK: - Extension for Easy Integration

extension Frog {
    /// Holds up a cross to banish a ghost enemy using optimized animation
    func holdCrossAt(_ ghost: GameEntity, completion: (() -> Void)? = nil) {
        // Check if frog has cross buff
        guard buffs.cross > 0 else {
            print("✝️ Frog has no cross to use!")
            return
        }
        
        // Decrement cross count
        buffs.cross -= 1
        
        // Execute banishment animation
        CrossAttackAnimation.executeAttack(frog: self, ghost: ghost, completion: completion)
    }
}
