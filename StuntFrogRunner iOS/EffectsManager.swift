//
//  EffectsManager.swift
//  Top-down visual effects
//

import SpriteKit

class EffectsManager {
    weak var scene: SKScene?
    
    private var cachedSplashAction: SKAction?
    private var cachedSplashDropletAction: SKAction?
    private var cachedLandingRippleActionDelays: [TimeInterval] = []
    private var cachedLandingRippleActionBase: SKAction?
    private var cachedLandingParticleAction: SKAction?
    private var cachedHitTextActions: [EnemyType: SKAction] = [:]
    private var cachedHitParticleAction: SKAction?
    private var cachedImpactParticleAction: SKAction?
    
    init(scene: SKScene) {
        self.scene = scene
    }
    
    func prepare() {
        // Prebuild common actions
        cachedSplashAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.5, duration: 0.6),
                SKAction.fadeOut(withDuration: 0.6)
            ]),
            SKAction.removeFromParent()
        ])
        cachedSplashDropletAction = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 100, y: 0, duration: 0.7), // direction will be applied by rotating parent or adjusting path per-instance
                SKAction.fadeOut(withDuration: 0.7),
                SKAction.scale(to: 0.2, duration: 0.7)
            ]),
            SKAction.removeFromParent()
        ])
        cachedLandingRippleActionBase = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 5.0, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5)
            ]),
            SKAction.removeFromParent()
        ])
        cachedLandingParticleAction = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 25, y: 0, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.scale(to: 0.1, duration: 0.4)
            ]),
            SKAction.removeFromParent()
        ])
        cachedHitParticleAction = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 45, y: 0, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.scale(to: 0.1, duration: 0.5)
            ]),
            SKAction.removeFromParent()
        ])
        cachedImpactParticleAction = SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 50, y: 0, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.scale(to: 0.1, duration: 0.4)
            ]),
            SKAction.removeFromParent()
        ])

        // Prebuild hit text actions for each enemy type
        let hitTextAction = SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.1),
            SKAction.wait(forDuration: 0.25),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.moveBy(x: 0, y: 50, duration: 0.5)
            ]),
            SKAction.removeFromParent()
        ])
        cachedHitTextActions[.snake] = hitTextAction
        cachedHitTextActions[.bee] = hitTextAction
        cachedHitTextActions[.dragonfly] = hitTextAction
        cachedHitTextActions[.log] = hitTextAction
        cachedHitTextActions[.spikeBush] = hitTextAction
        cachedHitTextActions[.edgeSpikeBush] = hitTextAction

        // Warm label font rendering by creating sample labels off-screen
        if let scene = scene {
            let warmLabels: [SKLabelNode] = [
                SKLabelNode(text: "💦 SPLASH! 💦"),
                SKLabelNode(text: "💥 BONK! 💥"),
                SKLabelNode(text: "🐍 BITE!"),
                SKLabelNode(text: "🐝 STING!"),
                SKLabelNode(text: "🦟 BUZZ!"),
                SKLabelNode(text: "🪵 BONK!"),
                SKLabelNode(text: "🌿 OUCH!"),
                SKLabelNode(text: "🌵 SPIKE!")
            ]
            for label in warmLabels {
                label.fontName = "ArialRoundedMTBold"
                label.fontSize = 40
                label.alpha = 0.001
                label.position = CGPoint(x: -1000, y: -1000)
                scene.addChild(label)
                // Run a very short no-op to force layout, then remove
                label.run(SKAction.sequence([SKAction.wait(forDuration: 0.01), SKAction.removeFromParent()]))
            }
        }
    }
    
    func createSplashEffect(at position: CGPoint) {
        guard let scene = scene else { return }
        
        // Big splash circle
        let splash = SKShapeNode(circleOfRadius: 70)
        splash.fillColor = UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 0.8)
        splash.strokeColor = .white
        splash.lineWidth = 4
        splash.position = position
        splash.zPosition = 150
        scene.addChild(splash)
        
        let splashAction = cachedSplashAction ?? SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.5, duration: 0.6),
                SKAction.fadeOut(withDuration: 0.6)
            ]),
            SKAction.removeFromParent()
        ])
        splash.run(splashAction)
        
        // Water droplets radiating out
        for i in 0..<16 {
            let angle = CGFloat(i) * (CGFloat.pi * 2 / 16)
            let droplet = SKShapeNode(circleOfRadius: 8)
            droplet.fillColor = .cyan
            droplet.strokeColor = .white
            droplet.lineWidth = 2
            droplet.position = position
            droplet.zPosition = 151
            droplet.zRotation = angle
            scene.addChild(droplet)
            
            let base = cachedSplashDropletAction ?? SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 100, y: 0, duration: 0.7),
                    SKAction.fadeOut(withDuration: 0.7),
                    SKAction.scale(to: 0.2, duration: 0.7)
                ]),
                SKAction.removeFromParent()
            ])
            droplet.run(base)
        }
        
        // "SPLASH!" text
        let splashText = SKLabelNode(text: "💦 SPLASH! 💦")
        splashText.fontSize = 48
        splashText.fontColor = .white
        splashText.fontName = "ArialRoundedMTBold"
        splashText.position = CGPoint(x: position.x, y: position.y + 90)
        splashText.zPosition = 152
        scene.addChild(splashText)
        
        let textAction = SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.15),
            SKAction.wait(forDuration: 0.5),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.moveBy(x: 0, y: 40, duration: 0.4)
            ]),
            SKAction.removeFromParent()
        ])
        splashText.run(textAction)
    }
    
    func createLandingEffect(at position: CGPoint, intensity: CGFloat, lilyPad: LilyPad? = nil) {
        guard let scene = scene else { return }
        
        // Use lily pad center if provided, otherwise use the given position
        let effectPosition = lilyPad?.position ?? position
        
        // Clamp intensity to 0...1 and derive scale factors
        let clamped = max(0.0, min(1.0, intensity))
        // Ripple and particle tuning based on intensity
        let rippleScaleBase: CGFloat = 3.0
        let rippleScaleExtra: CGFloat = 2.5 // added on top across rings
        let lineWidthBase: CGFloat = 5.0
        let glowRadiusBase: CGFloat = 8.0
        let glowScale: CGFloat = 1.0 + clamped * 1.5
        let particleCount = 8 + Int(round(clamped * 8)) // 8..16
        let particleDistanceBase: CGFloat = 35.0
        let particleDistanceExtra: CGFloat = 35.0
        let rippleDuration: TimeInterval = 0.6 + TimeInterval(clamped * 0.4) // 0.6..1.0
        let particleDuration: TimeInterval = 0.4 + TimeInterval(clamped * 0.2) // 0.4..0.6
        
        // Prefer to render landing ripples in the world layer (under lily pads)
        if let gs = scene as? GameScene {
            // Use the effect position directly if lily pad is provided (already in world coordinates)
            // Otherwise convert the incoming screen-space position into world coordinates
            let worldPos = lilyPad != nil ? effectPosition : gs.convert(effectPosition, to: gs.worldManager.worldNode)
            // Safely unwrap the world node to add children
            guard let parent = gs.worldManager.worldNode else { return }
            let zBelowPads: CGFloat = 5 // pads are at 10
            
            // Inner glow for impact point - creates focal emphasis
            let glow = SKShapeNode(circleOfRadius: glowRadiusBase * (0.8 + clamped * 0.6))
            glow.fillColor = UIColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 0.9)
            glow.strokeColor = .clear
            glow.position = worldPos
            glow.zPosition = zBelowPads
            parent.addChild(glow)
            
            let glowAction = SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 3.0 * glowScale, duration: rippleDuration * 0.375),
                    SKAction.fadeOut(withDuration: rippleDuration * 0.375)
                ]),
                SKAction.removeFromParent()
            ])
            glow.run(glowAction)
            
            // Enhanced ripples emanating from landing spot with realistic properties
            for i in 1...3 {
                let ripple = SKShapeNode(circleOfRadius: 9)
                
                // Color variation: inner ripples brighter, outer ripples darker for depth
                let alphaMod = 1.0 - (CGFloat(i - 1) * 0.1)
                ripple.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: alphaMod)
                ripple.fillColor = .clear
                
                // Start with thicker line for visibility
                ripple.lineWidth = max(0.5, (lineWidthBase - CGFloat(i)) * (0.8 + clamped * 0.6)) // adjusted for intensity
                ripple.position = worldPos
                ripple.zPosition = zBelowPads
                parent.addChild(ripple)
                
                // Stagger with more visible delay for cascade effect, adjusted by intensity
                let delay = Double(i - 1) * (0.08 + (1.0 - Double(clamped)) * 0.06)
                
                // Scale more dramatically for better visibility (6-8x expansion)
                let targetScale = rippleScaleBase + CGFloat(i) + rippleScaleExtra * clamped
                
                // Create custom action for line width animation (thin as it expands - realistic water)
                let lineWidthAction = SKAction.customAction(withDuration: rippleDuration) { node, elapsedTime in
                    if let shape = node as? SKShapeNode {
                        let progress = CGFloat(elapsedTime) / CGFloat(rippleDuration)
                        let startWidth = max(0.5, (lineWidthBase - CGFloat(i)) * (0.8 + clamped * 0.6))
                        let endWidth: CGFloat = 0.5
                        shape.lineWidth = startWidth - (startWidth - endWidth) * progress
                    }
                }
                
                let scaleAction = SKAction.scale(to: targetScale, duration: rippleDuration)
                scaleAction.timingMode = .easeOut
                let rippleAnimation = SKAction.group([
                    scaleAction,
                    SKAction.fadeOut(withDuration: rippleDuration),
                    lineWidthAction
                ])
                
                let fullAction = SKAction.sequence([
                    SKAction.wait(forDuration: delay),
                    rippleAnimation,
                    SKAction.removeFromParent()
                ])
                
                ripple.run(fullAction)
            }
            
            // Enhanced splash particles with more energy
            for i in 0..<particleCount {
                let angle = CGFloat(i) * (CGFloat.pi * 2 / CGFloat(particleCount))
                let particle = SKShapeNode(circleOfRadius: 4 + clamped * 3)
                particle.fillColor = UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0)
                particle.strokeColor = UIColor(red: 0.3, green: 0.9, blue: 0.9, alpha: 1.0)
                particle.lineWidth = 2
                particle.position = worldPos
                particle.zPosition = zBelowPads + 1
                particle.zRotation = angle
                parent.addChild(particle)
                
                // Vary particle travel distance for more natural look
                let distance: CGFloat = particleDistanceBase + particleDistanceExtra * clamped + CGFloat(i % 3) * 10
                
                let moveAction = SKAction.moveBy(x: distance * cos(angle), y: distance * sin(angle), duration: particleDuration)
                moveAction.timingMode = .easeOut
                let particleAction = SKAction.sequence([
                    SKAction.wait(forDuration: Double(i) * (0.015 + (1.0 - Double(clamped)) * 0.01)), // Quick stagger
                    SKAction.group([
                        moveAction,
                        SKAction.fadeOut(withDuration: particleDuration),
                        SKAction.scale(to: 0.1, duration: particleDuration)
                    ]),
                    SKAction.removeFromParent()
                ])
                particle.run(particleAction)
            }
            return
        }
        
        // Fallback: if not in a GameScene, apply enhanced effects at scene level
        // Inner glow for impact point
        let glow = SKShapeNode(circleOfRadius: glowRadiusBase * (0.8 + clamped * 0.6))
        glow.fillColor = UIColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 0.9)
        glow.strokeColor = .clear
        glow.position = effectPosition
        glow.zPosition = 90
        scene.addChild(glow)
        
        let glowAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.0 * glowScale, duration: rippleDuration * 0.375),
                SKAction.fadeOut(withDuration: rippleDuration * 0.375)
            ]),
            SKAction.removeFromParent()
        ])
        glow.run(glowAction)
        
        // Enhanced ripples emanating from landing spot
        for i in 1...5 {
            let ripple = SKShapeNode(circleOfRadius: 12)
            
            // Color variation for depth
            let alphaMod = 1.0 - (CGFloat(i - 1) * 0.1)
            ripple.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: alphaMod)
            ripple.fillColor = .clear
            ripple.lineWidth = max(0.5, (lineWidthBase - CGFloat(i)) * (0.8 + clamped * 0.6))
            ripple.position = effectPosition
            ripple.zPosition = 90
            scene.addChild(ripple)
            
            let delay = Double(i - 1) * (0.08 + (1.0 - Double(clamped)) * 0.06)
            let targetScale = rippleScaleBase + CGFloat(i) + rippleScaleExtra * clamped
            
            // Animate line width thinning
            let lineWidthAction = SKAction.customAction(withDuration: rippleDuration) { node, elapsedTime in
                if let shape = node as? SKShapeNode {
                    let progress = CGFloat(elapsedTime) / CGFloat(rippleDuration)
                    let startWidth = max(0.5, (lineWidthBase - CGFloat(i)) * (0.8 + clamped * 0.6))
                    let endWidth: CGFloat = 0.5
                    shape.lineWidth = startWidth - (startWidth - endWidth) * progress
                }
            }
            
            let scaleAction2 = SKAction.scale(to: targetScale, duration: rippleDuration)
            scaleAction2.timingMode = .easeOut
            let rippleAnimation = SKAction.group([
                scaleAction2,
                SKAction.fadeOut(withDuration: rippleDuration),
                lineWidthAction
            ])
            
            let fullAction = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                rippleAnimation,
                SKAction.removeFromParent()
            ])
            
            ripple.run(fullAction)
        }
        
        // Enhanced splash particles
        for i in 0..<particleCount {
            let angle = CGFloat(i) * (CGFloat.pi * 2 / CGFloat(particleCount))
            let particle = SKShapeNode(circleOfRadius: 4 + clamped * 3)
            particle.fillColor = UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0)
            particle.strokeColor = UIColor(red: 0.3, green: 0.9, blue: 0.9, alpha: 1.0)
            particle.lineWidth = 2
            particle.position = effectPosition
            particle.zPosition = 91
            particle.zRotation = angle
            scene.addChild(particle)
            
            let distance: CGFloat = particleDistanceBase + particleDistanceExtra * clamped + CGFloat(i % 3) * 10
            
            let moveAction2 = SKAction.moveBy(x: distance * cos(angle), y: distance * sin(angle), duration: particleDuration)
            moveAction2.timingMode = .easeOut
            let particleAction = SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * (0.015 + (1.0 - Double(clamped)) * 0.01)),
                SKAction.group([
                    moveAction2,
                    SKAction.fadeOut(withDuration: particleDuration),
                    SKAction.scale(to: 0.1, duration: particleDuration)
                ]),
                SKAction.removeFromParent()
            ])
            particle.run(particleAction)
        }
    }
    
    func createEnemyHitEffect(at position: CGPoint, enemyType: EnemyType) {
        guard let scene = scene else { return }
        
        let hitText: String
        switch enemyType {
        case .snake: hitText = "🐍 BITE!"
        case .bee: hitText = "🐝 STING!"
        case .dragonfly: hitText = "🦟 BUZZ!"
        case .log: hitText = "🪵 BONK!"
        case .spikeBush: hitText = "🌿 OUCH!"
        case .edgeSpikeBush: hitText = "🌵 SPIKE!"
        case .chaser: hitText = "CAUGHT!"
            
        }
        
        let hitLabel = SKLabelNode(text: hitText)
        hitLabel.fontSize = 36
        hitLabel.fontColor = .red
        hitLabel.fontName = "ArialRoundedMTBold"
        hitLabel.position = position
        hitLabel.zPosition = 150
        scene.addChild(hitLabel)
        
        let textAnimation = cachedHitTextActions[enemyType] ?? SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.1),
            SKAction.wait(forDuration: 0.25),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.moveBy(x: 0, y: 50, duration: 0.5)
            ]),
            SKAction.removeFromParent()
        ])
        hitLabel.run(textAnimation)
        
        // Impact burst
        for i in 0..<10 {
            let angle = CGFloat(i) * (CGFloat.pi * 2 / 10)
            let particle = SKShapeNode(circleOfRadius: 6)
            particle.fillColor = .orange
            particle.strokeColor = .red
            particle.lineWidth = 2
            particle.position = position
            particle.zPosition = 120
            particle.zRotation = angle
            scene.addChild(particle)
            
            let base = cachedImpactParticleAction ?? SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 45, y: 0, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.scale(to: 0.1, duration: 0.5)
                ]),
                SKAction.removeFromParent()
            ])
            particle.run(base)
        }
    }
    
    func createImpactBurst(at position: CGPoint) {
        guard let scene = scene else { return }
        
        for i in 0..<8 {
            let angle = CGFloat(i) * (CGFloat.pi * 2 / 8)
            let particle = SKShapeNode(circleOfRadius: 8)
            particle.fillColor = .red
            particle.strokeColor = .red
            particle.lineWidth = 2
            particle.position = position
            particle.zPosition = 120
            particle.zRotation = angle
            scene.addChild(particle)
            
            let base = cachedImpactParticleAction ?? SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 50, y: 0, duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.scale(to: 0.1, duration: 0.4)
                ]),
                SKAction.removeFromParent()
            ])
            particle.run(base)
        }
    }
    
    func createBonkLabel(at position: CGPoint) {
        guard let scene = scene else { return }
        
        let bounceLabel = SKLabelNode(text: "💥 BONK! 💥")
        bounceLabel.fontSize = 40
        bounceLabel.fontColor = .red
        bounceLabel.fontName = "ArialRoundedMTBold"
        bounceLabel.position = position
        bounceLabel.zPosition = 150
        scene.addChild(bounceLabel)
        
        let labelAnimation = SKAction.sequence([
            SKAction.scale(to: 1.5, duration: 0.1),
            SKAction.wait(forDuration: 0.3),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.moveBy(x: 0, y: 50, duration: 0.3)
            ]),
            SKAction.removeFromParent()
        ])
        bounceLabel.run(labelAnimation)
    }
    

    
    private func createIceEffect(at position: CGPoint, in parent: SKNode) {
        // Choose z baseline depending on parent layer (world vs scene)
        let zBase: CGFloat
        if let gs = scene as? GameScene, parent === gs.worldManager.worldNode {
            // Pads are at ~10; render cracks slightly above
            zBase = 12
        } else {
            zBase = 150
        }
        
        // Ice crack effect with crystalline pattern
        let iceBase = SKShapeNode(circleOfRadius: 50)
        iceBase.fillColor = UIColor(red: 0.8, green: 0.95, blue: 1.0, alpha: 0.6)
        iceBase.strokeColor = UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 0.9)
        iceBase.lineWidth = 3
        iceBase.position = position
        iceBase.zPosition = zBase
        parent.addChild(iceBase)
        
        for i in 0..<8 {
            let angle = CGFloat(i) * (CGFloat.pi * 2 / 8)
            let crack = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: .zero)
            let segments = 3
            var currentPoint = CGPoint.zero
            for j in 0..<segments {
                let segmentLength: CGFloat = 20 + CGFloat(j) * 10
                let jitter: CGFloat = CGFloat.random(in: -5...5)
                currentPoint = CGPoint(
                    x: currentPoint.x + cos(angle) * segmentLength + sin(angle + .pi/2) * jitter,
                    y: currentPoint.y + sin(angle) * segmentLength + cos(angle + .pi/2) * jitter
                )
                path.addLine(to: currentPoint)
            }
            crack.path = path
            crack.strokeColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.8)
            crack.lineWidth = 2
            crack.position = position
            crack.zPosition = zBase + 1
            parent.addChild(crack)
            let crackAction = SKAction.sequence([
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.8),
                    SKAction.scale(to: 1.5, duration: 0.8)
                ]),
                SKAction.removeFromParent()
            ])
            crack.run(crackAction)
        }
        
        let iceAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5)
            ]),
            SKAction.removeFromParent()
        ])
        iceBase.run(iceAction)
        
        for i in 0..<12 {
            let angle = CGFloat(i) * (CGFloat.pi * 2 / 12)
            let crystal = SKShapeNode(circleOfRadius: 4)
            crystal.fillColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.9)
            crystal.strokeColor = UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1.0)
            crystal.lineWidth = 1
            crystal.position = position
            crystal.zPosition = zBase + 2
            crystal.zRotation = angle
            parent.addChild(crystal)
            let crystalAction = SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * 60, y: sin(angle) * 60, duration: 0.6),
                    SKAction.fadeOut(withDuration: 0.6),
                    SKAction.scale(to: 0.1, duration: 0.6)
                ]),
                SKAction.removeFromParent()
            ])
            crystal.run(crystalAction)
        }
        
       
    }
    
    func createIceEffect(at position: CGPoint) {
        guard let scene = scene else { return }
        // Creates ice cracks at the fixed landing position - will not follow the frog as it slides
        // Choose a stable parent (world node if available, otherwise the scene)
        if let gs = scene as? GameScene, let world = gs.worldManager.worldNode {
            // Position is assumed to already be in world coordinates when passed by callers that know about world space.
            createIceEffect(at: position, in: world)
        } else {
            createIceEffect(at: position, in: scene)
        }
    }
    
    func createExplosionEffect(at position: CGPoint) {
        guard let scene = scene else { return }
        
        // Central explosion burst
        let explosionBase = SKShapeNode(circleOfRadius: 30)
        explosionBase.fillColor = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.8)
        explosionBase.strokeColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        explosionBase.lineWidth = 4
        explosionBase.position = position
        explosionBase.zPosition = 150
        scene.addChild(explosionBase)
        
        // Explosion animation
        let explosionAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.0, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ])
        explosionBase.run(explosionAction)
        
        // Explosion particles
        for i in 0..<12 {
            let angle = CGFloat(i) * (CGFloat.pi * 2 / 12)
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 4...8))
            particle.fillColor = UIColor(red: 1.0, green: CGFloat.random(in: 0.3...0.8), blue: 0.0, alpha: 1.0)
            particle.strokeColor = .yellow
            particle.lineWidth = 1
            particle.position = position
            particle.zPosition = 151
            particle.zRotation = angle
            scene.addChild(particle)
            
            let distance = CGFloat.random(in: 40...80)
            let particleAction = SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.02), // Quick stagger
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.scale(to: 0.1, duration: 0.5)
                ]),
                SKAction.removeFromParent()
            ])
            particle.run(particleAction)
        }
        
        // "BOOM!" text effect
        let explosionText = SKLabelNode(text: "💥 BOOM! 💥")
        explosionText.fontSize = 42
        explosionText.fontColor = .orange
        explosionText.fontName = "ArialRoundedMTBold"
        explosionText.position = CGPoint(x: position.x, y: position.y + 60)
        explosionText.zPosition = 152
        scene.addChild(explosionText)
        
        let textAction = SKAction.sequence([
            SKAction.scale(to: 1.5, duration: 0.1),
            SKAction.wait(forDuration: 0.3),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.moveBy(x: 0, y: 40, duration: 0.4)
            ]),
            SKAction.removeFromParent()
        ])
        explosionText.run(textAction)
    }
}

