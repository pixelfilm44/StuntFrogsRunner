//
//  EffectsManager.swift
//  Top-down visual effects
//

import SpriteKit

class EffectsManager {
    weak var scene: SKScene?
    
    // Weather effects management
    private var rainNode: SKNode?
    private var lightningNode: SKNode?
    private var snowNode: SKNode?
    private var windNode: SKNode?
    private var nightOverlayNode: SKNode?
    
    private var isRainActive = false
    private var isLightningActive = false
    private var isSnowActive = false
    private var isWindActive = false
    private var isNightOverlayActive = false
    
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
    
    /// Creates a slip effect with sliding particles and visual feedback
    func createSlipEffect(at position: CGPoint) {
        guard let scene = scene else { return }
        
        // Create slip streaks showing sliding motion
        for i in 0..<6 {
            let streak = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 15...25), height: 2))
            streak.fillColor = UIColor.systemBlue.withAlphaComponent(0.6)
            streak.strokeColor = .clear
            
            // Position streaks randomly around the slip point
            let offsetX = CGFloat.random(in: -20...20)
            let offsetY = CGFloat.random(in: -20...20)
            streak.position = CGPoint(x: position.x + offsetX, y: position.y + offsetY)
            streak.zPosition = 80
            
            // Random rotation for natural look
            streak.zRotation = CGFloat.random(in: 0...(CGFloat.pi * 2))
            
            scene.addChild(streak)
            
            // Animate streak sliding away and fading
            let slideDistance = CGFloat.random(in: 40...60)
            let slideDirection = CGFloat.random(in: 0...(CGFloat.pi * 2))
            
            let slideAction = SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.05), // Small stagger
                SKAction.group([
                    SKAction.moveBy(
                        x: cos(slideDirection) * slideDistance,
                        y: sin(slideDirection) * slideDistance,
                        duration: 0.8
                    ),
                    SKAction.fadeOut(withDuration: 0.8),
                    SKAction.scale(to: 0.2, duration: 0.8)
                ]),
                SKAction.removeFromParent()
            ])
            
            streak.run(slideAction)
        }
        
        // Central slip burst
        let slipBurst = SKShapeNode(circleOfRadius: 12)
        slipBurst.fillColor = UIColor.systemCyan.withAlphaComponent(0.4)
        slipBurst.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
        slipBurst.lineWidth = 2
        slipBurst.position = position
        slipBurst.zPosition = 85
        scene.addChild(slipBurst)
        
        // Slip burst animation
        let burstAction = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.5, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5)
            ]),
            SKAction.removeFromParent()
        ])
        slipBurst.run(burstAction)
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
    
    // MARK: - Weather Effects
    func startRainEffect() {
        guard let scene = scene, !isRainActive else { return }
        
        isRainActive = true
        rainNode = SKNode()
        rainNode?.zPosition = 200  // Above most game elements
        scene.addChild(rainNode!)
        
        print("🌧️ Starting rain effect")
        
        // Create continuous rain drops
        let createRainDrop = SKAction.run { [weak self] in
            self?.createRainDrop()
        }
        let wait = SKAction.wait(forDuration: 0.1)
        let rainSequence = SKAction.sequence([createRainDrop, wait])
        let rainForever = SKAction.repeatForever(rainSequence)
        
        rainNode?.run(rainForever)
    }
    
    func stopRainEffect() {
        guard isRainActive, let rain = rainNode else { return }
        
        print("🌧️ Stopping rain effect")
        isRainActive = false
        
        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 2.0)
        let remove = SKAction.removeFromParent()
        rain.run(SKAction.sequence([fadeOut, remove]))
        rainNode = nil
    }
    
    private func createRainDrop() {
        guard let scene = scene, let rain = rainNode else { return }
        
        let drop = SKShapeNode(rectOf: CGSize(width: 2, height: 8))
        drop.fillColor = UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.7)
        drop.strokeColor = .clear
        
        // Random position across screen width
        let x = CGFloat.random(in: 0...scene.size.width)
        let y = scene.size.height + 20
        drop.position = CGPoint(x: x, y: y)
        
        rain.addChild(drop)
        
        // Animate drop falling
        let fallDistance = scene.size.height + 40
        let fallDuration = TimeInterval.random(in: 0.8...1.2)
        
        let fall = SKAction.moveBy(x: -30, y: -fallDistance, duration: fallDuration)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()
        
        let dropAction = SKAction.sequence([
            fall,
            SKAction.group([fadeOut, remove])
        ])
        
        drop.run(dropAction)
    }
    
    func startLightningEffect() {
        guard let scene = scene else { return }
        
        isLightningActive = true
        print("⚡ Lightning effect active")
        
        // Schedule random lightning strikes
        scheduleNextLightning()
    }
    
    func stopLightningEffect() {
        print("⚡ Lightning effect stopped")
        isLightningActive = false
        lightningNode?.removeAllActions()
        lightningNode?.removeFromParent()
        lightningNode = nil
    }
    
    private func scheduleNextLightning() {
        guard isLightningActive, let scene = scene else { return }
        
        let delay = TimeInterval.random(in: 3.0...8.0)
        
        let wait = SKAction.wait(forDuration: delay)
        let flash = SKAction.run { [weak self] in
            self?.createLightningFlash()
        }
        let schedule = SKAction.run { [weak self] in
            self?.scheduleNextLightning()
        }
        
        let sequence = SKAction.sequence([wait, flash, schedule])
        scene.run(sequence)
    }
    
    private func createLightningFlash() {
        guard let scene = scene else { return }
        
        print("⚡ Lightning flash!")
        
        // Screen flash effect
        let flash = SKShapeNode(rect: CGRect(x: 0, y: 0, width: scene.size.width, height: scene.size.height))
        flash.fillColor = UIColor(red: 1.0, green: 1.0, blue: 0.9, alpha: 0.4)
        flash.strokeColor = .clear
        flash.zPosition = 300  // Above everything
        scene.addChild(flash)
        
        // Lightning bolt (simplified zigzag)
        let bolt = SKShapeNode()
        let path = CGMutablePath()
        let startX = CGFloat.random(in: scene.size.width * 0.2...scene.size.width * 0.8)
        var currentY = scene.size.height
        var currentX = startX
        
        path.move(to: CGPoint(x: currentX, y: currentY))
        
        // Create zigzag pattern
        for _ in 0..<8 {
            currentY -= CGFloat.random(in: 40...80)
            currentX += CGFloat.random(in: -40...40)
            path.addLine(to: CGPoint(x: currentX, y: currentY))
        }
        
        bolt.path = path
        bolt.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 0.9)
        bolt.lineWidth = 4
        bolt.zPosition = 299
        scene.addChild(bolt)
        
        // Flash animation
        let flashFadeOut = SKAction.fadeOut(withDuration: 0.2)
        let flashRemove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([flashFadeOut, flashRemove]))
        
        // Bolt animation
        let boltFadeOut = SKAction.fadeOut(withDuration: 0.3)
        let boltRemove = SKAction.removeFromParent()
        bolt.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            boltFadeOut,
            boltRemove
        ]))
        
        // Play thunder sound if SoundController is available
        if let soundController = try? SoundController.shared {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Thunder sound would go here - for now we'll use an existing sound
                soundController.playSoundEffect(.dangerZone, volume: 0.3)
            }
        }
    }
    
    // MARK: - Snow Effects
    func startSnowEffect() {
        guard let scene = scene, !isSnowActive else { return }
        
        isSnowActive = true
        snowNode = SKNode()
        snowNode?.zPosition = 200  // Above most game elements
        scene.addChild(snowNode!)
        
        print("❄️ Starting snow effect")
        
        // Create continuous snow flakes
        let createSnowFlake = SKAction.run { [weak self] in
            self?.createSnowFlake()
        }
        let wait = SKAction.wait(forDuration: 0.15)  // Slower than rain
        let snowSequence = SKAction.sequence([createSnowFlake, wait])
        let snowForever = SKAction.repeatForever(snowSequence)
        
        snowNode?.run(snowForever)
    }
    
    func stopSnowEffect() {
        guard isSnowActive, let snow = snowNode else { return }
        
        print("❄️ Stopping snow effect")
        isSnowActive = false
        
        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 3.0)  // Longer fade for snow
        let remove = SKAction.removeFromParent()
        snow.run(SKAction.sequence([fadeOut, remove]))
        snowNode = nil
    }
    
    private func createSnowFlake() {
        guard let scene = scene, let snow = snowNode else { return }
        
        let flake = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
        flake.fillColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8)
        flake.strokeColor = .clear
        
        // Random position across screen width
        let x = CGFloat.random(in: 0...scene.size.width)
        let y = scene.size.height + 20
        flake.position = CGPoint(x: x, y: y)
        
        snow.addChild(flake)
        
        // Animate snowflake falling (slower and more drifting than rain)
        let fallDistance = scene.size.height + 40
        let fallDuration = TimeInterval.random(in: 2.0...3.5)  // Much slower than rain
        let drift = CGFloat.random(in: -50...50)  // Side-to-side drift
        
        let fall = SKAction.moveBy(x: drift, y: -fallDistance, duration: fallDuration)
        let rotate = SKAction.rotate(byAngle: CGFloat.random(in: -2...2), duration: fallDuration)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        
        let flakeAction = SKAction.sequence([
            SKAction.group([fall, rotate]),
            SKAction.group([fadeOut, remove])
        ])
        
        flake.run(flakeAction)
    }
    
    // MARK: - Wind Effects
    func startWindEffect(strength: CGFloat, direction: CGFloat) {
        guard let scene = scene else { return }
        
        isWindActive = true
        print("💨 Starting wind effect - strength: \(strength), direction: \(direction)")
        
        // Schedule random wind gusts
        scheduleNextWindGust(strength: strength, direction: direction)
    }
    
    func stopWindEffect() {
        print("💨 Wind effect stopped")
        isWindActive = false
        windNode?.removeAllActions()
        windNode?.removeFromParent()
        windNode = nil
    }
    
    private func scheduleNextWindGust(strength: CGFloat, direction: CGFloat) {
        guard isWindActive, let scene = scene else { return }
        
        let delay = TimeInterval.random(in: 2.0...6.0)  // Random wind gusts
        
        let wait = SKAction.wait(forDuration: delay)
        let gust = SKAction.run { [weak self] in
            self?.createWindGust(strength: strength, direction: direction)
        }
        let schedule = SKAction.run { [weak self] in
            self?.scheduleNextWindGust(strength: strength, direction: direction)
        }
        
        let sequence = SKAction.sequence([wait, gust, schedule])
        scene.run(sequence)
    }
    
    private func createWindGust(strength: CGFloat, direction: CGFloat) {
        guard let scene = scene else { return }
        
        print("💨 Wind gust! Strength: \(strength)")
        
        // Create visual wind effect with particles
        for i in 0..<Int(strength * 20) {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            particle.fillColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3)
            particle.strokeColor = .clear
            
            let startX = CGFloat.random(in: -50...scene.size.width + 50)
            let startY = CGFloat.random(in: 0...scene.size.height)
            particle.position = CGPoint(x: startX, y: startY)
            particle.zPosition = 190
            
            scene.addChild(particle)
            
            let windDistance = strength * 300
            let moveX = cos(direction) * windDistance
            let moveY = sin(direction) * windDistance
            
            let move = SKAction.moveBy(x: moveX, y: moveY, duration: 1.0)
            let fade = SKAction.fadeOut(withDuration: 1.0)
            let remove = SKAction.removeFromParent()
            
            let particleAction = SKAction.sequence([
                SKAction.group([move, fade]),
                remove
            ])
            
            particle.run(particleAction)
        }
        
        // Apply wind force to frog if accessible
        if let gameScene = scene as? GameScene {
            applyWindForce(to: gameScene, strength: strength, direction: direction)
        }
    }
    
    private func applyWindForce(to gameScene: GameScene, strength: CGFloat, direction: CGFloat) {
        // This would need to be implemented in your GameScene
        // For now, we'll post a notification that wind should affect the frog
        let windForce = CGVector(
            dx: cos(direction) * strength * 100,
            dy: sin(direction) * strength * 100
        )
        
        NotificationCenter.default.post(
            name: NSNotification.Name("WindForceApplied"),
            object: windForce
        )
    }
    
    // MARK: - Night Overlay Effects
    func startNightOverlay() {
        guard let scene = scene, !isNightOverlayActive else { return }
        
        isNightOverlayActive = true
        nightOverlayNode = SKNode()
        nightOverlayNode?.zPosition = 180  // Below weather but above game elements
        scene.addChild(nightOverlayNode!)
        
        print("🌙 Starting night overlay effect")
        
        // Dark semi-transparent overlay
        let overlay = SKShapeNode(rect: CGRect(x: 0, y: 0, width: scene.size.width, height: scene.size.height))
        overlay.fillColor = UIColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 0.4)
        overlay.strokeColor = .clear
        overlay.zPosition = 0
        nightOverlayNode?.addChild(overlay)
        
        // Create twinkling stars
        createStarField()
        
        // Animate in the overlay
        nightOverlayNode?.alpha = 0
        let fadeIn = SKAction.fadeIn(withDuration: 2.0)
        nightOverlayNode?.run(fadeIn)
    }
    
    func stopNightOverlay() {
        guard isNightOverlayActive, let nightOverlay = nightOverlayNode else { return }
        
        print("🌙 Stopping night overlay effect")
        isNightOverlayActive = false
        
        // Clean up fireflies when stopping night overlay
        removeAllFireflies()
        
        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 2.0)
        let remove = SKAction.removeFromParent()
        nightOverlay.run(SKAction.sequence([fadeOut, remove]))
        nightOverlayNode = nil
    }
    
    private func createStarField() {
        guard let scene = scene else { return }
        
        // Determine where to place star reflections - prefer world coordinates for proper movement
        let starParent: SKNode
        let starZPosition: CGFloat
        let worldBounds: CGRect
        
        if let gameScene = scene as? GameScene, let worldNode = gameScene.worldManager.worldNode {
            // Place stars in the world coordinate system so they move with the background
            starParent = worldNode
            starZPosition = 1 // Below lily pads but above background
            
            // Use a larger area than just the screen to create stars across the world
            // This ensures stars are visible as the player moves around
            let screenSize = scene.size
            worldBounds = CGRect(
                x: -screenSize.width * 2,
                y: -screenSize.height * 2,
                width: screenSize.width * 4,
                height: screenSize.height * 4
            )
        } else {
            // Fallback to night overlay node for non-GameScene contexts
            guard let nightOverlay = nightOverlayNode else { return }
            starParent = nightOverlay
            starZPosition = 1
            worldBounds = CGRect(x: 20, y: 20, width: scene.size.width - 40, height: scene.size.height - 40)
        }
        
        // Create a manageable number of star reflections for performance
        let starCount = 140 // Increased slightly since we're covering a larger area
        
        for i in 0..<starCount {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2.5))
            star.fillColor = UIColor(red: 1.0, green: 1.0, blue: CGFloat.random(in: 0.8...1.0), alpha: 0.6)
            star.strokeColor = UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.3)
            star.lineWidth = 0.5
            
            // Create a subtle ripple effect for water reflections
            let rippleRadius = CGFloat.random(in: 8...15)
            let ripple = SKShapeNode(circleOfRadius: rippleRadius)
            ripple.fillColor = .clear
            ripple.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1)
            ripple.lineWidth = 1
            
            // Random position across the world bounds
            let x = CGFloat.random(in: worldBounds.minX...worldBounds.maxX)
            let y = CGFloat.random(in: worldBounds.minY...worldBounds.maxY)
            star.position = CGPoint(x: x, y: y)
            star.zPosition = starZPosition
            
            ripple.position = star.position
            ripple.zPosition = starZPosition - 0.1
            
            starParent.addChild(ripple)
            starParent.addChild(star)
            
            // Create twinkling effect with staggered timing for performance
            let twinkleDuration = TimeInterval.random(in: 1.5...3.5)
            let delay = TimeInterval(i) * 0.15 // Stagger star animations
            
            let fadeOut = SKAction.fadeOut(withDuration: twinkleDuration * 0.3)
            let fadeIn = SKAction.fadeIn(withDuration: twinkleDuration * 0.3)
            let wait = SKAction.wait(forDuration: twinkleDuration * 0.4)
            
            let twinkleSequence = SKAction.sequence([fadeOut, fadeIn, wait])
            let twinkleForever = SKAction.repeatForever(twinkleSequence)
            
            // Add subtle ripple animation for water reflection effect
            let rippleScale = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: twinkleDuration * 0.5),
                SKAction.scale(to: 1.0, duration: twinkleDuration * 0.5)
            ])
            let rippleForever = SKAction.repeatForever(rippleScale)
            
            star.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                twinkleForever
            ]))
            
            ripple.run(SKAction.sequence([
                SKAction.wait(forDuration: delay + 0.5),
                rippleForever
            ]))
        }
        
        // Add fireflies for extra ambiance in world space
        // Generate initial fireflies around the starting area
        if let gameScene = scene as? GameScene {
            // Start with fireflies around the initial camera/world position
            let initialWorldCenter = CGPoint.zero // Adjust based on your game's starting position
            generateFirefliesInWorldArea(centerWorldPosition: initialWorldCenter, areaRadius: 400)
        }
    }
    
    private func createFireflies() {
        // Fireflies are now created in world space when night overlay starts
        // This method is kept for compatibility but the actual creation happens in generateFirefliesInWorldArea
    }
    
    /// Creates fireflies at static world positions that persist as the frog moves past them
    /// Call this periodically to populate new areas as the frog explores
    func generateFirefliesInWorldArea(centerWorldPosition: CGPoint, areaRadius: CGFloat) {
        guard let scene = scene, isNightOverlayActive else { return }
        
        // Determine the parent node - prefer world coordinates
        let fireflyParent: SKNode
        let fireflyZPosition: CGFloat
        
        if let gameScene = scene as? GameScene, let worldNode = gameScene.worldManager.worldNode {
            fireflyParent = worldNode
            fireflyZPosition = 15 // Above lily pads and water, below most effects
        } else {
            // Fallback if not in GameScene
            fireflyParent = scene
            fireflyZPosition = 85
        }
        
        // Create fireflies scattered around the specified world area
        let fireflyCount = Int(areaRadius / 150) + 2 // Scale count with area size, minimum 2
        let maxFireflies = 8 // Cap to avoid performance issues
        let actualCount = min(fireflyCount, maxFireflies)
        
        for i in 0..<actualCount {
            let firefly = createSingleFirefly()
            
            // Position randomly within the specified world area
            let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
            let distance = CGFloat.random(in: 0...areaRadius)
            let offsetX = cos(angle) * distance
            let offsetY = sin(angle) * distance
            
            firefly.position = CGPoint(
                x: centerWorldPosition.x + offsetX,
                y: centerWorldPosition.y + offsetY
            )
            firefly.zPosition = fireflyZPosition
            
            fireflyParent.addChild(firefly)
            
            // Start the firefly behavior with a staggered delay
            let delay = TimeInterval(i) * 0.3
            startFireflyBehavior(firefly, delay: delay)
        }
    }
    
    /// Creates a single firefly node with proper visual setup
    private func createSingleFirefly() -> SKShapeNode {
        let firefly = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...3))
        firefly.name = "firefly" // For easy identification and cleanup
        firefly.fillColor = UIColor(red: 1.0, green: 1.0, blue: 0.3, alpha: 0.9)
        firefly.strokeColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 0.6)
        firefly.lineWidth = 0.5
        
        // Add a subtle glow effect
        let glow = SKShapeNode(circleOfRadius: 6)
        glow.fillColor = UIColor(red: 1.0, green: 1.0, blue: 0.3, alpha: 0.2)
        glow.strokeColor = .clear
        glow.zPosition = -1
        firefly.addChild(glow)
        
        return firefly
    }
    
    /// Starts the floating and blinking behavior for a firefly
    private func startFireflyBehavior(_ firefly: SKShapeNode, delay: TimeInterval) {
        // Gentle floating movement in a constrained area around the firefly's position
        let floatDistance: CGFloat = 30
        let baseDuration: TimeInterval = 4.0
        
        // Create random floating pattern
        func createRandomFloatAction() -> SKAction {
            let duration = TimeInterval.random(in: baseDuration * 0.8...baseDuration * 1.2)
            let deltaX = CGFloat.random(in: -floatDistance...floatDistance)
            let deltaY = CGFloat.random(in: -floatDistance...floatDistance)
            
            let moveAction = SKAction.moveBy(x: deltaX, y: deltaY, duration: duration)
            moveAction.timingMode = .easeInEaseOut
            return moveAction
        }
        
        // Create infinite floating sequence
        let floatSequence = SKAction.sequence([
            createRandomFloatAction(),
            createRandomFloatAction(),
            createRandomFloatAction(),
            createRandomFloatAction()
        ])
        let floatForever = SKAction.repeatForever(floatSequence)
        
        // Create blinking effect
        let blinkDuration = TimeInterval.random(in: 0.3...0.7)
        let blinkWait = TimeInterval.random(in: 1.5...3.5)
        
        let blink = SKAction.sequence([
            SKAction.fadeOut(withDuration: blinkDuration * 0.5),
            SKAction.fadeIn(withDuration: blinkDuration * 0.5),
            SKAction.wait(forDuration: blinkWait)
        ])
        let blinkForever = SKAction.repeatForever(blink)
        
        // Start both behaviors after the specified delay
        firefly.run(SKAction.sequence([
            SKAction.wait(forDuration: delay),
            SKAction.group([floatForever, blinkForever])
        ]))
    }
    
    /// Remove fireflies that are far from the specified position to manage memory
    func cleanupDistantFireflies(from centerPosition: CGPoint, maxDistance: CGFloat) {
        guard let scene = scene else { return }
        
        let fireflyParent: SKNode
        if let gameScene = scene as? GameScene, let worldNode = gameScene.worldManager.worldNode {
            fireflyParent = worldNode
        } else {
            fireflyParent = scene
        }
        
        // Find and remove distant fireflies
        fireflyParent.enumerateChildNodes(withName: "firefly") { node, _ in
            let distance = sqrt(pow(node.position.x - centerPosition.x, 2) + pow(node.position.y - centerPosition.y, 2))
            if distance > maxDistance {
                node.removeFromParent()
            }
        }
    }
    
    // MARK: - Public Firefly Management Methods
    
    /// Call this from GameScene when the frog moves to populate new areas with fireflies
    /// This should be called periodically as the frog explores new areas during night weather
    /// 
    /// Usage in GameScene:
    /// ```
    /// // In your update loop or when frog position changes significantly:
    /// if effectsManager.isNightOverlayActive {
    ///     effectsManager.updateFirefliesForPosition(frog.position)
    /// }
    /// ```
    public func updateFirefliesForPosition(_ frogWorldPosition: CGPoint) {
        guard isNightOverlayActive else { return }
        
        // Clean up distant fireflies first to manage memory
        cleanupDistantFireflies(from: frogWorldPosition, maxDistance: 600)
        
        // Generate new fireflies ahead of the frog's movement direction
        // You might want to adjust this based on the frog's movement direction
        let generationRadius: CGFloat = 300
        let areasToPopulate = [
            CGPoint(x: frogWorldPosition.x, y: frogWorldPosition.y + 200), // Ahead
            CGPoint(x: frogWorldPosition.x - 150, y: frogWorldPosition.y + 100), // Left-ahead
            CGPoint(x: frogWorldPosition.x + 150, y: frogWorldPosition.y + 100), // Right-ahead
        ]
        
        for area in areasToPopulate {
            // Check if we already have fireflies in this area before generating more
            if !hasFirefliesNear(area, radius: generationRadius) {
                generateFirefliesInWorldArea(centerWorldPosition: area, areaRadius: generationRadius)
            }
        }
    }
    
    /// Check if there are already fireflies in the specified area
    private func hasFirefliesNear(_ position: CGPoint, radius: CGFloat) -> Bool {
        guard let scene = scene else { return false }
        
        let fireflyParent: SKNode
        if let gameScene = scene as? GameScene, let worldNode = gameScene.worldManager.worldNode {
            fireflyParent = worldNode
        } else {
            fireflyParent = scene
        }
        
        var hasFireflies = false
        fireflyParent.enumerateChildNodes(withName: "firefly") { node, stop in
            let distance = sqrt(pow(node.position.x - position.x, 2) + pow(node.position.y - position.y, 2))
            if distance < radius {
                hasFireflies = true
                stop.pointee = true
            }
        }
        
        return hasFireflies
    }
    
    /// Remove all fireflies from the world (useful when switching weather or resetting)
    public func removeAllFireflies() {
        guard let scene = scene else { return }
        
        let fireflyParent: SKNode
        if let gameScene = scene as? GameScene, let worldNode = gameScene.worldManager.worldNode {
            fireflyParent = worldNode
        } else {
            fireflyParent = scene
        }
        
        fireflyParent.enumerateChildNodes(withName: "firefly") { node, _ in
            node.removeFromParent()
        }
    }
    func updateWeatherEffects(for weather: WeatherType) {
        // Stop all current weather effects
        stopRainEffect()
        stopLightningEffect()
        stopSnowEffect()
        stopWindEffect()
        stopNightOverlay()
        
        // Clean up any existing fireflies when changing weather
        removeAllFireflies()
        
        // Start appropriate effects for new weather
        switch weather {
        case .day:
            // No additional weather effects needed
            break
        case .night:
            startNightOverlay()
            
        case .winter:
            startSnowEffect()
            
        case .ice:
            startSnowEffect()
            
        case .rain:
            startRainEffect()
            
        case .stormy:
            startRainEffect()
            startLightningEffect()
            startWindEffect(strength: 0.5, direction: 0)
            
        case .storm:
            startRainEffect()
            startLightningEffect()
            startWindEffect(strength: 0.5, direction: 0)
        }
    }
}

