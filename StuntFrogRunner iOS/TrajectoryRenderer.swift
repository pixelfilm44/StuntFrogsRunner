//
//  TrajectoryRenderer.swift
//  StuntFrogRunner iOS
//
//  Created on 12/23/2025.
//  Optimized Sprite-based trajectory with Unit Scaling
//

import SpriteKit

class TrajectoryRenderer {
    
    // MARK: - Properties
    private let containerNode: SKNode
    private var dots: [SKSpriteNode] = []
    private let dotTexture: SKTexture
    private let maxDots: Int
    
    // 🔥 VISUAL SCALING FACTOR 🔥
    // Multiplies the tiny physics values so they appear on the big screen.
    // Increase this if the line is too short. Decrease if it's too long.
    private let visualScale: CGFloat = 45.0
    
    // MARK: - Initialization
    init(zPosition: CGFloat = 50, segments: Int = 25) {
        self.maxDots = segments
        self.containerNode = SKNode()
        self.containerNode.zPosition = zPosition
        self.containerNode.name = "TrajectoryContainer"
        
        self.dotTexture = TrajectoryRenderer.createDotTexture()
        
        // Create the dot pool
        for i in 0..<maxDots {
            let dot = SKSpriteNode(texture: dotTexture)
            dot.size = CGSize(width: 14, height: 14)
            dot.color = .white
            dot.colorBlendFactor = 1.0
            dot.alpha = 0
            dot.name = "traj_dot_\(i)"
            containerNode.addChild(dot)
            dots.append(dot)
        }
        
        print("🎯 TrajectoryRenderer ready with Visual Scale: \(visualScale)")
    }
    
    // MARK: - Public Methods
    func addToNode(_ parent: SKNode) {
        if containerNode.parent == nil {
            parent.addChild(containerNode)
        }
    }
    
    func updateTrajectory(
        startPosition: CGPoint,
        startVelocity: CGVector,
        startZ: CGFloat,
        startVZ: CGFloat,
        gravity: CGFloat,
        friction: CGFloat,
        dt: CGFloat = 1.0/60.0
    ) {
        containerNode.isHidden = false
        
        // --- APPLY VISUAL SCALING ---
        // We multiply the velocity and gravity by our scale factor
        // to convert "Meters" (Physics) to "Points" (Screen).
        var pos = startPosition
        var vx = startVelocity.dx * visualScale
        var vy = startVelocity.dy * visualScale
        var z = startZ * visualScale
        var vz = startVZ * visualScale
        let scaledGravity = gravity * visualScale
        
        let simulationSteps = maxDots * 3
        let drawFrequency = 3
        var dotsUsed = 0
        
        for step in 0..<simulationSteps {
            // Physics Simulation
            vz -= scaledGravity * dt
            z += vz * dt
            
            // Floor check (using scaled Z)
            if z <= 0 { break }
            
            vx *= friction
            vy *= friction
            pos.x += vx * dt
            pos.y += vy * dt
            
            // Draw Dots
            if step % drawFrequency == 0 {
                if dotsUsed < dots.count {
                    let dot = dots[dotsUsed]
                    dot.position = pos
                    
                    // Visual Polish: Scale and fade
                    let progress = CGFloat(step) / CGFloat(simulationSteps)
                    dot.setScale(max(0.4, 1.0 - (progress * 0.5)))
                    dot.alpha = max(0.3, 1.0 - progress)
                    
                    dotsUsed += 1
                }
            }
        }
        
        // Hide unused dots
        for i in dotsUsed..<dots.count {
            dots[i].alpha = 0
        }
    }
    
    func hide() { containerNode.isHidden = true }
    func show() { containerNode.isHidden = false }
    
    func updateAppearance(color: UIColor, width: CGFloat, alpha: CGFloat) {
        for dot in dots {
            dot.color = color
            dot.size = CGSize(width: width * 1, height: width * 1)
        }
        containerNode.alpha = alpha
    }
    
    func updateForDragIntensity(_ intensity: CGFloat) {
        containerNode.alpha = 0.5 + (0.5 * intensity)
    }
    
    private static func createDotTexture() -> SKTexture {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }
}

// MARK: - Compatibility Extension
extension TrajectoryRenderer {
    static func createOptimized(for parent: SKNode) -> TrajectoryRenderer {
        let renderer = TrajectoryRenderer(zPosition: 50, segments: 25)
        renderer.addToNode(parent)
        return renderer
    }
    var debugPathNodeParent: SKNode? { return containerNode.parent }
}
