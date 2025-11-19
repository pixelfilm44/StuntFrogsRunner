//
//  EffectsManager.swift
//  Top-down visual effects
//

import SpriteKit

class EffectsManager {
    weak var scene: SKScene?
    weak var gameStateManager: GameStateManager?
    
    // Weather effects management
    private var rainNode: SKNode?
    private var lightningNode: SKNode?
    private var snowNode: SKNode?
    private var windNode: SKNode?
    private var nightOverlayNode: SKNode?
    private var windParticlePool: [SKSpriteNode] = []
    
    private var isRainActive = false
    private var isLightningActive = false
    private var isSnowActive = false
    private var isWindActive = false
    private var isNightOverlayActive = false
    
    // Slip effect cooldown management - ensures only one slip per landing
    private var lastSlipEffectTime: TimeInterval = 0
    private let slipEffectCooldown: TimeInterval = 1.0 // Longer cooldown to prevent multiple slips
    
    private var cachedSplashAction: SKAction?
    private var cachedSplashDropletAction: SKAction?
    private var cachedLandingRippleActionDelays: [TimeInterval] = []
    private var cachedLandingRippleActionBase: SKAction?
    private var cachedLandingParticleAction: SKAction?
    private var cachedHitTextActions: [EnemyType: SKAction] = [:]
    private var cachedHitParticleAction: SKAction?
    private var cachedImpactParticleAction: SKAction?
    private var cachedWindParticleAction: SKAction?
    
    init(scene: SKScene, gameStateManager: GameStateManager? = nil) {
        self.scene = scene
        self.gameStateManager = gameStateManager
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
        if gameStateManager?.splashTriggered == true { return }
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
                
                // Pre-calculate line width for performance optimization
                let startLineWidth = max(0.5, (lineWidthBase - CGFloat(i)) * (0.8 + clamped * 0.6))
                ripple.lineWidth = startLineWidth
                ripple.position = worldPos
                ripple.zPosition = zBelowPads
                parent.addChild(ripple)
                
                // Stagger with more visible delay for cascade effect, adjusted by intensity
                let delay = Double(i - 1) * (0.08 + (1.0 - Double(clamped)) * 0.06)
                
                // Scale more dramatically for better visibility (6-8x expansion)
                let targetScale = rippleScaleBase + CGFloat(i) + rippleScaleExtra * clamped
                
                // Create optimized custom action for line width animation (thin as it expands - realistic water)
                let lineWidthAction = SKAction.customAction(withDuration: rippleDuration) { node, elapsedTime in
                    if let shape = node as? SKShapeNode {
                        let progress = CGFloat(elapsedTime) / CGFloat(rippleDuration)
                        let endWidth: CGFloat = 0.5
                        shape.lineWidth = startLineWidth - (startLineWidth - endWidth) * progress
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
    
   
    /// Creates landing effect specifically for moving lily pads
    /// This helps indicate to the player that they've landed on a moving platform
    func createMovingPadLandingEffect(at position: CGPoint, padVelocity: CGVector, intensity: CGFloat = 0.5) {
        guard let scene = scene else { return }
        
        // Create directional landing particles that show the pad's movement
        let particleCount = 6
        let velocityMagnitude = sqrt(padVelocity.dx*padVelocity.dx + padVelocity.dy*padVelocity.dy)
        
        // Only show special effect if the pad is actually moving
        guard velocityMagnitude > 0.1 else {
            print("🚁 Pad velocity too low for moving effect: \(velocityMagnitude)")
            return
        }
        
        let velocityDirection = atan2(padVelocity.dy, padVelocity.dx)
        
        for i in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: 4)
            particle.fillColor = UIColor.systemGreen.withAlphaComponent(0.7) // Green to distinguish from slip
            particle.strokeColor = .clear
            
            // Arrange particles in the direction of movement
            let angle = velocityDirection + CGFloat(i - particleCount/2) * 0.3
            let startDistance: CGFloat = 25
            
            particle.position = CGPoint(
                x: position.x + cos(angle) * startDistance,
                y: position.y + sin(angle) * startDistance
            )
            particle.zPosition = 85
            scene.addChild(particle)
            
            // Animate particles in the direction of pad movement
            let moveDistance: CGFloat = min(40, velocityMagnitude * 20) // Scale with pad speed
            let moveX = cos(velocityDirection) * moveDistance
            let moveY = sin(velocityDirection) * moveDistance
            
            let particleAction = SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.03),
                SKAction.group([
                    SKAction.moveBy(x: moveX, y: moveY, duration: 0.6),
                    SKAction.fadeOut(withDuration: 0.6),
                    SKAction.scale(to: 0.3, duration: 0.6)
                ]),
                SKAction.removeFromParent()
            ])
            particle.run(particleAction)
        }
        
        // Create a subtle directional indicator
        let indicator = SKLabelNode(text: "🌊")
        indicator.fontSize = 24
        indicator.position = CGPoint(x: position.x, y: position.y + 40)
        indicator.zPosition = 90
        indicator.zRotation = velocityDirection + .pi/2 // Point in movement direction
        scene.addChild(indicator)
        
        let indicatorAction = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.1),
            SKAction.wait(forDuration: 0.4),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.moveBy(x: cos(velocityDirection) * 20, y: sin(velocityDirection) * 20, duration: 0.4)
            ]),
            SKAction.removeFromParent()
        ])
        indicator.run(indicatorAction)
        
        print("🚁 Moving lily pad landing effect created - pad velocity: (\(padVelocity.dx), \(padVelocity.dy))")
    }
    
    
    /// Creates a smooth platform movement effect for frogs on moving lily pads
    /// This ensures the frog visually stays attached to the moving platform
    func createPlatformMovementEffect(at position: CGPoint, velocity: CGVector) {
        guard let scene = scene else { return }
        
        // Create subtle movement ripples around the lily pad edge to show it's moving
        let rippleCount = 3
        for i in 0..<rippleCount {
            let angle = CGFloat(i) * (CGFloat.pi * 2 / CGFloat(rippleCount))
            let rippleOffset: CGFloat = 45 // Distance from center
            
            let ripplePosition = CGPoint(
                x: position.x + cos(angle) * rippleOffset,
                y: position.y + sin(angle) * rippleOffset
            )
            
            let ripple = SKShapeNode(circleOfRadius: 3)
            ripple.fillColor = UIColor.systemBlue.withAlphaComponent(0.3)
            ripple.strokeColor = .clear
            ripple.position = ripplePosition
            ripple.zPosition = 75
            scene.addChild(ripple)
            
            // Animate ripples in the direction of movement
            let moveDistance: CGFloat = 20
            let moveX = (velocity.dx / max(1, abs(velocity.dx) + abs(velocity.dy))) * moveDistance
            let moveY = (velocity.dy / max(1, abs(velocity.dx) + abs(velocity.dy))) * moveDistance
            
            let rippleAction = SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.1),
                SKAction.group([
                    SKAction.moveBy(x: moveX, y: moveY, duration: 0.6),
                    SKAction.fadeOut(withDuration: 0.6),
                    SKAction.scale(to: 2.0, duration: 0.6)
                ]),
                SKAction.removeFromParent()
            ])
            ripple.run(rippleAction)
        }
        
        // Create a gentle trail effect behind the moving lily pad
        if abs(velocity.dx) > 0.1 || abs(velocity.dy) > 0.1 {
            let trail = SKShapeNode(circleOfRadius: 2)
            trail.fillColor = UIColor.white.withAlphaComponent(0.4)
            trail.strokeColor = .clear
            
            // Position trail behind the movement direction
            let trailDistance: CGFloat = 30
            let normalizedVelocity = CGVector(
                dx: velocity.dx / max(1, sqrt(velocity.dx*velocity.dx + velocity.dy*velocity.dy)),
                dy: velocity.dy / max(1, sqrt(velocity.dx*velocity.dx + velocity.dy*velocity.dy))
            )
            
            trail.position = CGPoint(
                x: position.x - normalizedVelocity.dx * trailDistance,
                y: position.y - normalizedVelocity.dy * trailDistance
            )
            trail.zPosition = 70
            scene.addChild(trail)
            
            let trailAction = SKAction.sequence([
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.scale(to: 0.5, duration: 0.4)
                ]),
                SKAction.removeFromParent()
            ])
            trail.run(trailAction)
        }
    }
    
    /// Creates a continuous slip trail effect for ongoing sliding
    func createSlipTrail(from startPosition: CGPoint, to endPosition: CGPoint, intensity: CGFloat = 1.0) {
        guard let scene = scene else { return }
        
        // Only create trail if sufficient distance to avoid performance waste
        let distance = sqrt(pow(endPosition.x - startPosition.x, 2) + pow(endPosition.y - startPosition.y, 2))
        guard distance > 8.0 else { return } // Skip micro-movements
        
        let direction = atan2(endPosition.y - startPosition.y, endPosition.x - startPosition.x)
        
        // Create only 2-3 trail particles for better performance
        let particleCount = min(3, max(2, Int(distance / 20)))
        
        for i in 0..<particleCount {
            let progress = CGFloat(i) / CGFloat(particleCount - 1)
            let trailPosition = CGPoint(
                x: startPosition.x + (endPosition.x - startPosition.x) * progress,
                y: startPosition.y + (endPosition.y - startPosition.y) * progress
            )
            
            let trail = SKShapeNode(circleOfRadius: 2 + intensity * 1.5)
            trail.fillColor = UIColor.systemBlue.withAlphaComponent(0.3 * intensity)
            trail.strokeColor = .clear // Remove stroke for performance
            trail.position = trailPosition
            trail.zPosition = 75
            scene.addChild(trail)
            
            // Simple, lightweight animation
            let delay = Double(i) * 0.08
            let trailAction = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.scale(to: 0.5, duration: 0.3)
                ]),
                SKAction.removeFromParent()
            ])
            trail.run(trailAction)
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
        // Play rain sound looping
        SoundController.shared.playLooping(.rain, volume: 0.3)
        
        rainNode?.run(rainForever)
    }
    
    func stopRainEffect() {
        guard isRainActive, let rain = rainNode else { return }
        // Stop rain sound when rain stops
        SoundController.shared.stopLooping(.rain)
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
        
        // Play thunder sound after lightning flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            SoundController.shared.playSoundEffect(.thunder, volume: 0.3)
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
    private let maxWindParticles = 8  // Reduced from potentially 20+ particles
    
    func startWindEffect(strength: CGFloat, direction: CGFloat) {
        guard let scene = scene else { return }
        
        isWindActive = true
        windNode = SKNode()
        windNode?.zPosition = 190
        scene.addChild(windNode!)
        
        // Pre-cache wind particle action
        cacheWindParticleAction(strength: strength, direction: direction)
        
        // Pre-populate particle pool
        prepareWindParticlePool()
        
        // Schedule random wind gusts with longer intervals for performance
        scheduleNextWindGust(strength: strength, direction: direction)
    }
    
    func stopWindEffect() {
        print("💨 Wind effect stopped")
        isWindActive = false
        windNode?.removeAllActions()
        windNode?.removeFromParent()
        windNode = nil
        
        // Clean up particle pool
        windParticlePool.removeAll()
        cachedWindParticleAction = nil
    }
    
    private func prepareWindParticlePool() {
        windParticlePool.removeAll()
        
        // Create a pool of reusable wind particles
        for _ in 0..<maxWindParticles {
            let particle = createWindParticle()
            particle.alpha = 0
            particle.position = CGPoint(x: -1000, y: -1000) // Off-screen
            windParticlePool.append(particle)
        }
    }
    
    private func createWindParticle() -> SKSpriteNode {
        // Randomize aspect ratio (length vs width) to vary leaf shapes
        let baseWidth: CGFloat = 34
        let aspect: CGFloat = CGFloat.random(in: 0.5...1.6) // <1 = rounder, >1 = longer
        let leafSize = CGSize(width: baseWidth * aspect, height: 18)

        // Randomize color using HSB for natural greens/yellows
        // Base around green hue with slight drift toward yellow or teal
        let baseHue: CGFloat = 0.28 // ~green
        let hue = max(0, min(1, baseHue + CGFloat.random(in: -0.06...0.07)))
        let baseSat: CGFloat = 0.65
        let sat = max(0, min(1, baseSat + CGFloat.random(in: -0.2...0.2)))
        let baseBright: CGFloat = 0.8
        let bri = max(0, min(1, baseBright + CGFloat.random(in: -0.1...0.1)))
        let fillColor = UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 0.6)
        let strokeColor = UIColor(hue: hue, saturation: min(1, sat + 0.15), brightness: max(0, bri - 0.1), alpha: 0.9)

        // Build a simple almond-shaped leaf using two quadratic curves
        let path = UIBezierPath()
        // Start at left tip
        path.move(to: CGPoint(x: 0, y: leafSize.height / 2))
        // Top curve to right tip
        path.addQuadCurve(to: CGPoint(x: leafSize.width, y: leafSize.height / 2), controlPoint: CGPoint(x: leafSize.width * 0.5, y: leafSize.height))
        // Bottom curve back to left tip
        path.addQuadCurve(to: CGPoint(x: 0, y: leafSize.height / 2), controlPoint: CGPoint(x: leafSize.width * 0.5, y: 0))

        let leafShape = SKShapeNode(path: path.cgPath)
        leafShape.fillColor = fillColor
        leafShape.strokeColor = strokeColor
        leafShape.lineWidth = 1.2

        // Add a subtle central vein
        let veinPath = UIBezierPath()
        veinPath.move(to: CGPoint(x: leafSize.width * 0.08, y: leafSize.height / 2))
        veinPath.addLine(to: CGPoint(x: leafSize.width * 0.92, y: leafSize.height / 2))
        let vein = SKShapeNode(path: veinPath.cgPath)
        vein.strokeColor = UIColor(white: 1.0, alpha: 0.45)
        vein.lineWidth = 0.7
        leafShape.addChild(vein)

        // Slight random rotation and tiny scale variance to avoid uniformity
        leafShape.zRotation = CGFloat.random(in: -0.6...0.6)
        leafShape.setScale(CGFloat.random(in: 0.9...1.15))

        // Try to render the shape to a texture for performance
        if let scene = self.scene, let view = scene.view, let texture = view.texture(from: leafShape) {
            let sprite = SKSpriteNode(texture: texture)
            sprite.alpha = CGFloat.random(in: 0.25...0.55)
            sprite.colorBlendFactor = 0.0
            return sprite
        }

        // Fallback: simple rounded rectangle approximating a leaf
        let fallbackColor = UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 0.35)
        let fallback = SKSpriteNode(color: fallbackColor, size: CGSize(width: 30 * aspect, height: 18))
        fallback.colorBlendFactor = 1.0
        fallback.alpha = 0.4
        fallback.zRotation = CGFloat.random(in: -0.6...0.6)
        return fallback
    }
    
    private func cacheWindParticleAction(strength: CGFloat, direction: CGFloat) {
        let windDistance = strength * 200  // Reduced from 300 for shorter travel
        let moveX = cos(direction) * windDistance
        let moveY = sin(direction) * windDistance
        
        let move = SKAction.moveBy(x: moveX, y: moveY, duration: 0.8) // Reduced duration
        let fade = SKAction.fadeOut(withDuration: 0.8)
        
        cachedWindParticleAction = SKAction.group([move, fade])
    }
    
    private func scheduleNextWindGust(strength: CGFloat, direction: CGFloat) {
        guard isWindActive, let scene = scene else { return }
        
        let delay = TimeInterval.random(in: 3.0...7.0)  // Slightly longer intervals
        
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
        guard let scene = scene, let windNode = windNode else { return }
        
        // Limit the number of active particles based on performance
        let particleCount = min(maxWindParticles, max(3, Int(strength * 8))) // Reduced multiplier
        
        var activeParticles = 0
        
        // Use pooled particles for better performance
        for i in 0..<particleCount {
            guard i < windParticlePool.count else { break }
            
            let particle = windParticlePool[i]
            
            // Skip if particle is already animating
            guard particle.hasActions() == false else { continue }
            
            // Reset particle properties
            let diameter = CGFloat.random(in: 20...40) // Smaller range
            particle.size = CGSize(width: diameter, height: diameter)
            particle.alpha = CGFloat.random(in: 0.8...1) // Lower opacity
            
            let startX = CGFloat.random(in: -50...scene.size.width + 50)
            let startY = CGFloat.random(in: 0...scene.size.height)
            particle.position = CGPoint(x: startX, y: startY)
            
            // Add to wind node if not already a child
            if particle.parent == nil {
                windNode.addChild(particle)
            }
            
            if let cachedAction = cachedWindParticleAction {
                let resetAction = SKAction.run {
                    particle.alpha = 0
                    particle.removeAction(forKey: "wobble")
                    particle.zRotation = 0
                }

                // Add a slight wobble rotation for realism while the particle moves
                let wobbleAmplitude = CGFloat.random(in: 0.08...0.22)
                let wobbleDuration = TimeInterval.random(in: 0.18...0.32)
                let wobble = SKAction.sequence([
                    SKAction.rotate(byAngle: wobbleAmplitude, duration: wobbleDuration),
                    SKAction.rotate(byAngle: -wobbleAmplitude * 2.0, duration: wobbleDuration * 2.0),
                    SKAction.rotate(byAngle: wobbleAmplitude, duration: wobbleDuration)
                ])
                let wobbleForever = SKAction.repeatForever(wobble)
                particle.run(wobbleForever, withKey: "wobble")

                let fullAction = SKAction.sequence([
                    cachedAction,
                    resetAction
                ])

                particle.run(fullAction)
                activeParticles += 1
            }
        }
        
        // Play wind sound less frequently to reduce audio processing load
        if activeParticles > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                SoundController.shared.playSoundEffect(.windStorm, volume: 0.2) // Reduced volume
            }
        }
        
        // Apply wind force to frog if accessible
        if let gameScene = scene as? GameScene {
            applyWindForce(to: gameScene, strength: strength, direction: direction)
        }
    }
    
    private func applyWindForce(to gameScene: GameScene, strength: CGFloat, direction: CGFloat) {
        // Calculate wind force vector with improved scaling
        let baseForce: CGFloat = 150 // Base force multiplier for wind effects
        let windForce = CGVector(
            dx: cos(direction) * strength * baseForce,
            dy: sin(direction) * strength * baseForce
        )
        
        // Create additional info dictionary for more detailed wind data
        let windInfo: [String: Any] = [
            "force": windForce,
            "strength": strength,
            "direction": direction,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Post notification with enhanced wind data
        NotificationCenter.default.post(
            name: NSNotification.Name("WindForceApplied"),
            object: windForce,
            userInfo: windInfo
        )
        
        print("🌬️ Wind force applied - strength: \(strength), direction: \(direction * 180 / .pi)°, force: (\(windForce.dx), \(windForce.dy))")
    }
    
    // MARK: - Night Overlay Effects
    func startNightOverlay() {
        guard let scene = scene else { 
            print("❌ Night overlay failed: No scene")
            return 
        }
        
        guard !isNightOverlayActive else { 
            print("⚠️ Night overlay already active")
            return 
        }
        // Play night ambience
        SoundController.shared.playLooping(.night, volume: 0.3)
        isNightOverlayActive = true
        nightOverlayNode = SKNode()
        nightOverlayNode?.zPosition = 180  // Below weather but above game elements
        scene.addChild(nightOverlayNode!)
        
        print("🌙 Starting night overlay effect - scene size: \(scene.size)")
        
        // Dark semi-transparent overlay
        let overlay = SKShapeNode(rect: CGRect(x: 0, y: 0, width: scene.size.width, height: scene.size.height))
        overlay.fillColor = UIColor(red: 0.0, green: 0.0, blue: 0.2, alpha: 0.4)
        overlay.strokeColor = .clear
        overlay.zPosition = 0
        overlay.name = "nightOverlay"
        nightOverlayNode?.addChild(overlay)
        
        print("🌙 Added dark overlay: \(overlay.frame)")
        
        
        
        // Animate in the overlay
        nightOverlayNode?.alpha = 0
        let fadeIn = SKAction.fadeIn(withDuration: 2.0)
        nightOverlayNode?.run(fadeIn) { [weak self] in
            print("🌙 Night overlay fade-in complete")
            self?.debugNightEffects()
        }
    }
    
    func stopNightOverlay() {
        guard isNightOverlayActive, let nightOverlay = nightOverlayNode else { return }
        
        print("🌙 Stopping night overlay effect")
        isNightOverlayActive = false
        
        // Stop night ambience
        SoundController.shared.stopLooping(.night)
        
        // Fade out and remove
        let fadeOut = SKAction.fadeOut(withDuration: 2.0)
        let remove = SKAction.removeFromParent()
        nightOverlay.run(SKAction.sequence([fadeOut, remove]))
        nightOverlayNode = nil
    }
    
  
    // MARK: - Public Testing Methods
    
    /// Force start night effects for testing (call this from your GameScene or debug menu)
    public func testNightEffects() {
        print("🧪 TESTING: Force starting night effects...")
        
        // Stop any existing weather effects
        stopRainEffect()
        stopLightningEffect()
        stopSnowEffect()
        stopWindEffect()
        stopNightOverlay()
        
        // Start night overlay
        startNightOverlay()
        
        // Debug after a delay to let things settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.debugNightEffects()
        }
    }
    
    /// Test individual star creation
    public func testStarCreation() {
        guard let scene = scene else { 
            print("❌ No scene for star testing")
            return 
        }
        
        print("🧪 TESTING: Creating test stars...")
        
        // Create a few test stars directly in the scene for visibility
        for i in 0..<10 {
            let star = SKShapeNode(circleOfRadius: 8)
            star.name = "testStar"
            star.fillColor = .yellow
            star.strokeColor = .white
            star.lineWidth = 2
            
            let x = 100 + CGFloat(i * 50)
            let y = scene.size.height / 2
            star.position = CGPoint(x: x, y: y)
            star.zPosition = 200 // Very high z-position to ensure visibility
            
            scene.addChild(star)
            
            // Simple twinkling
            let twinkle = SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.fadeIn(withDuration: 0.5)
            ])
            star.run(SKAction.repeatForever(twinkle))
        }
        
        print("🧪 Created 10 test stars across the screen")
    }
    
    /// Test individual firefly creation
    func updateWeatherEffects(for weather: WeatherType) {
        print("🌟 EffectsManager.updateWeatherEffects called with weather: \(weather)")
        
        // Stop all current weather effects
        stopRainEffect()
        stopLightningEffect()
        stopSnowEffect()
        stopWindEffect()
        stopNightOverlay()
        
       
        
        // Start appropriate effects for new weather
        switch weather {
        case .day:
            // No additional weather effects needed
            print("🌞 Day weather - no special effects")
            break
        case .night:
            print("🌙 Starting night effects - overlay and stars")
            startNightOverlay()
            
        case .winter:
            print("❄️ Starting winter effects")
            startSnowEffect()
            
        case .ice:
            print("🧊 Starting ice effects")
            startSnowEffect()
            
        case .rain:
            print("🌧️ Starting rain effects")
            startRainEffect()
            startWindEffect(strength: 0.3, direction: 2) // Light wind with rain
            
        case .stormy:
            print("⛈️ Starting stormy effects")
            startRainEffect()
            startLightningEffect()
            startWindEffect(strength: 0.5, direction: 4)
            
        case .storm:
            print("🌩️ Starting storm effects")
            startRainEffect()
            startLightningEffect()
            startWindEffect(strength: 0.5, direction: 4)
        }
    }
    
    // Debug method to check if night effects are active
    func debugNightEffects() {
        print("🌟 NIGHT EFFECTS DEBUG:")
        print("  - isNightOverlayActive: \(isNightOverlayActive)")
        print("  - nightOverlayNode exists: \(nightOverlayNode != nil)")
        print("  - scene exists: \(scene != nil)")
        
        if let scene = scene {
            print("  - scene size: \(scene.size)")
            print("  - scene children count: \(scene.children.count)")
        }
        
        // Check for stars and fireflies in the scene
        if let scene = scene {
            var starCount = 0
            var fireflyCount = 0
            
            func countNodes(in node: SKNode, depth: Int = 0) {
                let indent = String(repeating: "  ", count: depth)
                
                for child in node.children {
                    if child is SKShapeNode && child.name != "firefly" {
                        // Could be a star
                        if let shape = child as? SKShapeNode, shape.fillColor.description.contains("1.0") {
                            starCount += 1
                        }
                    }
                    if child.name == "firefly" {
                        fireflyCount += 1
                    }
                    
                    // Recursively check children
                    countNodes(in: child, depth: depth + 1)
                }
            }
            
            countNodes(in: scene)
            print("  - Star-like shapes found: \(starCount)")
            print("  - Fireflies found: \(fireflyCount)")
            
            // Check if we have a GameScene with world manager
            if let gameScene = scene as? GameScene {
                print("  - Is GameScene: true")
                if let worldNode = gameScene.worldManager?.worldNode {
                    print("  - World node exists: true")
                    print("  - World node children: \(worldNode.children.count)")
                    
                    var worldFireflies = 0
                    worldNode.enumerateChildNodes(withName: "firefly") { _, _ in
                        worldFireflies += 1
                    }
                    print("  - Fireflies in world node: \(worldFireflies)")
                } else {
                    print("  - World node exists: false")
                }
            } else {
                print("  - Is GameScene: false")
            }
        }
    }
}

