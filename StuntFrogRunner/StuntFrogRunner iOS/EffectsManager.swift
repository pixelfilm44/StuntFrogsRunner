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

        // Warm label font rendering by creating sample labels off-screen
        if let scene = scene {
            let warmLabels: [SKLabelNode] = [
                SKLabelNode(text: "💦 SPLASH! 💦"),
                SKLabelNode(text: "💥 BONK! 💥"),
                SKLabelNode(text: "🐍 BITE!"),
                SKLabelNode(text: "🐝 STING!"),
                SKLabelNode(text: "🦟 BUZZ!"),
                SKLabelNode(text: "🪵 BONK!")
            ]
            for label in warmLabels {
                label.fontName = "Arial-BoldMT"
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
        splashText.fontName = "Arial-BoldMT"
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
    
    func createLandingEffect(at position: CGPoint) {
        guard let scene = scene else { return }
        
        // Ripples emanating from landing spot
        for i in 1...4 {
            let ripple = SKShapeNode(circleOfRadius: 8)
            ripple.strokeColor = UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 0.7)
            ripple.fillColor = .clear
            ripple.lineWidth = 3
            ripple.position = position
            ripple.zPosition = 90
            scene.addChild(ripple)
            
            let delay = Double(i) * 0.08
            let base = cachedLandingRippleActionBase ?? SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: CGFloat(4 + i), duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ]),
                SKAction.removeFromParent()
            ])
            let rippleAction = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                base
            ])
            ripple.run(rippleAction)
        }
        
        // Small splash particles
        for i in 0..<8 {
            let angle = CGFloat(i) * (CGFloat.pi * 2 / 8)
            let particle = SKShapeNode(circleOfRadius: 4)
            particle.fillColor = .white
            particle.strokeColor = .cyan
            particle.lineWidth = 1
            particle.position = position
            particle.zPosition = 91
            particle.zRotation = angle
            scene.addChild(particle)
            
            let base = cachedLandingParticleAction ?? SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 25, y: 0, duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.scale(to: 0.1, duration: 0.4)
                ]),
                SKAction.removeFromParent()
            ])
            particle.run(base)
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
        }
        
        let hitLabel = SKLabelNode(text: hitText)
        hitLabel.fontSize = 36
        hitLabel.fontColor = .red
        hitLabel.fontName = "Arial-BoldMT"
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
            
            let base = cachedHitParticleAction ?? SKAction.sequence([
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
            particle.fillColor = .orange
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
        bounceLabel.fontName = "Arial-BoldMT"
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
}
