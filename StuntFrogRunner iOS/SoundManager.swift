import UIKit
import AVFoundation
import CoreHaptics
import SpriteKit

// MARK: - Sound Manager
class SoundManager {
    static let shared = SoundManager()
    private var players: [String: AVAudioPlayer] = [:]
    
    private init() {}
    
    func preloadSounds() {
        let sounds = ["jump", "land", "coin", "hit", "splash"]
        for sound in sounds {
            if let url = Bundle.main.url(forResource: sound, withExtension: "wav") {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    players[sound] = player
                }
            }
        }
    }
    
    func play(_ name: String) {
        guard let player = players[name] else { return }
        if player.isPlaying { player.stop(); player.currentTime = 0 }
        player.play()
    }
}

// MARK: - Haptics Manager
class HapticsManager {
    static let shared = HapticsManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
    }
    
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light: impactLight.impactOccurred()
        case .medium: impactMedium.impactOccurred()
        case .heavy: impactHeavy.impactOccurred()
        default: break
        }
    }
    
    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
    }
}

// MARK: - VFX Manager
/// Handles particle emitters for weather and interactions.
class VFXManager {
    static let shared = VFXManager()
    
    private init() {}
    
    func spawnSplash(at position: CGPoint, in scene: SKScene) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(imageNamed: "spark") // Uses default circle if missing
        emitter.particleBirthRate = 100
        emitter.numParticlesToEmit = 15
        emitter.particleLifetime = 0.4
        emitter.particlePosition = position
        emitter.particleSpeed = 100
        emitter.particleSpeedRange = 50
        emitter.emissionAngle = CGFloat.pi / 2
        emitter.emissionAngleRange = CGFloat.pi / 3
        emitter.particleAlpha = 0.6
        emitter.particleAlphaSpeed = -1.0
        emitter.particleScale = 0.3
        emitter.particleColor = .white
        scene.addChild(emitter)
        
        let wait = SKAction.wait(forDuration: 1.0)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }
    
    // Programmatic Weather Emitters
    func createRainEmitter(width: CGFloat) -> SKEmitterNode {
        let node = SKEmitterNode()
        node.particleTexture = SKTexture(imageNamed: "spark")
        node.particleBirthRate = 150
        node.particleLifetime = 1.5
        node.particlePositionRange = CGVector(dx: width, dy: 0)
        node.particleSpeed = 600
        node.particleSpeedRange = 100
        node.emissionAngle = -CGFloat.pi / 2 // Down
        node.particleAlpha = 0.5
        node.particleScale = 0.1
        node.particleScaleRange = 0.05
        node.particleColor = .white
        node.particleColorBlendFactor = 1.0
        return node
    }
    
    func createSnowEmitter(width: CGFloat) -> SKEmitterNode {
        let node = SKEmitterNode()
        node.particleTexture = SKTexture(imageNamed: "spark")
        node.particleBirthRate = 20
        node.particleLifetime = 4.0
        node.particlePositionRange = CGVector(dx: width, dy: 0)
        node.particleSpeed = 80
        node.particleSpeedRange = 40
        node.emissionAngle = -CGFloat.pi / 2
        node.emissionAngleRange = CGFloat.pi / 4 // Drift
        node.xAcceleration = 50 // Wobble
        node.particleAlpha = 0.8
        node.particleScale = 0.2
        node.particleScaleRange = 0.1
        node.particleColor = .white
        return node
    }
    
    func createFirefliesEmitter(width: CGFloat, height: CGFloat) -> SKEmitterNode {
        let node = SKEmitterNode()
        node.particleTexture = SKTexture(imageNamed: "spark")
        node.particleBirthRate = 5
        node.particleLifetime = 5.0
        // Emit mainly from top, but fireflies linger
        node.particlePositionRange = CGVector(dx: width, dy: height/2)
        node.particleSpeed = 20
        node.particleSpeedRange = 10
        node.emissionAngleRange = CGFloat.pi * 2 // All directions
        node.xAcceleration = 20
        node.yAcceleration = 20
        
        // Pulse/Blink effect via alpha sequence
        let sequence = SKKeyframeSequence(keyframeValues: [0, 1, 0.2, 1, 0], times: [0, 0.2, 0.5, 0.8, 1])
        node.particleAlphaSequence = sequence
        
        node.particleScale = 0.15
        node.particleColor = UIColor(red: 241/255, green: 196/255, blue: 15/255, alpha: 1) // Yellow
        node.particleColorBlendFactor = 1.0
        return node
    }
}
