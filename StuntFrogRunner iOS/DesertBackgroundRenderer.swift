//
//  DesertBackgroundRenderer.swift
//  StuntFrogRunner iOS
//
//  Created on 01/02/2026.
//  Performant desert background with dark brown-to-black void gradient
//

import SpriteKit

/// Renders a desert void-themed background with dark brown to black gradient.
/// Optimized for 60 FPS performance with a single draw call.
class DesertBackgroundRenderer {
    
    // MARK: - Properties
    
    /// The main background gradient sprite (dark brown to near-black)
    private let gradientSprite: SKSpriteNode
    
    /// Container node for sand particles
    private let sandParticlesNode = SKNode()
    
    /// Array of sand particle sprites for animation
    private var sandParticles: [SKSpriteNode] = []
    
    /// Whether the background is currently active
    private(set) var isActive: Bool = false
    
    /// Reference to the camera for positioning
    private weak var cameraNode: SKCameraNode?
    
    /// Last camera position for particle recycling
    private var lastCameraY: CGFloat = 0
    
    // MARK: - Configuration
    
    /// Size of the background (should cover the screen with some margin)
    private let backgroundSize: CGSize
    
    /// Number of sand particles (adjusted based on device performance)
    private let sandParticleCount: Int
    
    // MARK: - Initialization
    
    /// Creates a new desert background renderer
    /// - Parameters:
    ///   - size: Size of the background (should cover screen dimensions)
    ///   - zPosition: Z-position for the background (should be behind everything but above water background)
    ///   - particleCount: Number of sand particles (adjusted based on device capability)
    init(size: CGSize, zPosition: CGFloat = -99, particleCount: Int = 25) {
        self.backgroundSize = size
        self.sandParticleCount = particleCount
        
        // Create gradient texture and sprite
        let gradientTexture = Self.createDesertVoidGradientTexture(size: size)
        self.gradientSprite = SKSpriteNode(texture: gradientTexture, size: size)
        gradientSprite.zPosition = zPosition
        gradientSprite.alpha = 0 // Start invisible
        
        // Setup sand particles node
        sandParticlesNode.zPosition = zPosition + 5 // Above gradient, below gameplay
        sandParticlesNode.alpha = 0 // Start invisible
        
        // Create sand particles
        createSandParticles()
    }
    
    /// Creates a smooth gradient texture from dark brown to near-black void
    /// This is done once and cached for performance
    private static func createDesertVoidGradientTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Define gradient colors: dark brown at top fading to near-black void at bottom
            // Using Configuration colors for consistency
            let topColor = Configuration.Colors.desertTop
            let bottomColor = Configuration.Colors.desertBottom
            
            // Create a multi-stop gradient for smoother transition
            let colors = [
                topColor.cgColor,                                                                    // Dark brown (top)
                UIColor(red: 30/255, green: 22/255, blue: 15/255, alpha: 1.0).cgColor,             // Medium-dark brown
                UIColor(red: 20/255, green: 15/255, blue: 10/255, alpha: 1.0).cgColor,             // Very dark brown
                UIColor(red: 15/255, green: 12/255, blue: 8/255, alpha: 1.0).cgColor,              // Near black with brown tint
                bottomColor.cgColor                                                                  // Near black (bottom)
            ] as CFArray
            
            let locations: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
            
            // Create vertical gradient (top to bottom)
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size.width / 2, y: size.height),
                    end: CGPoint(x: size.width / 2, y: 0),
                    options: []
                )
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
    
    // MARK: - Sand Particle System
    
    /// Creates the sand particle texture (small circular grain)
    private static func createSandParticleTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Sand color - warm tan/beige
            let sandColor = UIColor(red: 210/255, green: 180/255, blue: 140/255, alpha: 0.7)
            ctx.setFillColor(sandColor.cgColor)
            
            // Draw a soft circle
            let rect = CGRect(origin: .zero, size: size)
            ctx.fillEllipse(in: rect)
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
    
    /// Creates sand particles that will blow across the screen
    private func createSandParticles() {
        let particleTexture = Self.createSandParticleTexture()
        
        // Create particles distributed across the screen
        for _ in 0..<sandParticleCount {
            let particle = SKSpriteNode(texture: particleTexture)
            
            // Random size for depth variation
            let scale = CGFloat.random(in: 0.5...1.5)
            particle.setScale(scale)
            
            // Random starting position (will be repositioned in activate())
            particle.position = CGPoint(
                x: CGFloat.random(in: -backgroundSize.width/2...backgroundSize.width/2),
                y: CGFloat.random(in: -backgroundSize.height/2...backgroundSize.height/2)
            )
            
            // Vary alpha based on scale (smaller = more distant = more faded)
            particle.alpha = 0.3 + (scale - 0.5) * 0.4 // Range: 0.3 to 0.7
            particle.blendMode = .alpha
            
            sandParticlesNode.addChild(particle)
            sandParticles.append(particle)
        }
    }
    
    /// Animates a single sand particle with wind-blown movement
    private func animateSandParticle(_ particle: SKSpriteNode, delay: TimeInterval = 0) {
        // Remove any existing actions
        particle.removeAllActions()
        
        // Horizontal wind movement (right to left, simulating wind direction)
        let windDistance = CGFloat.random(in: 150...300)
        let windDuration = TimeInterval.random(in: 2.0...4.0)
        
        let moveWind = SKAction.moveBy(x: -windDistance, y: 0, duration: windDuration)
        moveWind.timingMode = .linear
        
        // Slight vertical drift for natural movement
        let driftAmount = CGFloat.random(in: -30...30)
        let drift = SKAction.moveBy(x: 0, y: driftAmount, duration: windDuration)
        drift.timingMode = .easeInEaseOut
        
        // Combine horizontal wind and vertical drift
        let movement = SKAction.group([moveWind, drift])
        
        // Fade in and out subtly
        let fadeOut = SKAction.fadeAlpha(to: 0.1, duration: windDuration * 0.3)
        let fadeIn = SKAction.fadeAlpha(to: particle.alpha, duration: windDuration * 0.3)
        let fadeSequence = SKAction.sequence([fadeOut, fadeIn])
        
        // Run movement and fading together
        let combined = SKAction.group([movement, fadeSequence])
        
        // Repeat forever
        let repeatAction = SKAction.repeatForever(combined)
        
        // Apply delay if specified (for staggered animation start)
        if delay > 0 {
            let wait = SKAction.wait(forDuration: delay)
            particle.run(SKAction.sequence([wait, repeatAction]))
        } else {
            particle.run(repeatAction)
        }
    }
    
    // MARK: - Public Methods
    
    /// Adds the desert background to a parent node (typically the scene)
    /// - Parameter parent: The parent node to add the background to
    func addToNode(_ parent: SKNode) {
        parent.addChild(gradientSprite)
        parent.addChild(sandParticlesNode)
    }
    
    /// Sets the camera to follow for positioning
    /// - Parameter camera: The camera node to track
    func setCamera(_ camera: SKCameraNode) {
        self.cameraNode = camera
        self.lastCameraY = camera.position.y
        
        // Immediately position the background at camera center
        gradientSprite.position = camera.position
        sandParticlesNode.position = camera.position
    }
    
    /// Activates the desert background
    /// - Parameter animated: Whether to fade in smoothly
    func activate(animated: Bool = true) {
        guard !isActive else { return }
        isActive = true
        
        // Stop any existing actions
        gradientSprite.removeAllActions()
        sandParticlesNode.removeAllActions()
        
        if animated {
            // Smooth fade in
            let fadeIn = SKAction.fadeIn(withDuration: 2.0)
            fadeIn.timingMode = .easeInEaseOut
            gradientSprite.run(fadeIn)
            sandParticlesNode.run(fadeIn)
        } else {
            gradientSprite.alpha = 1.0
            sandParticlesNode.alpha = 1.0
        }
        
        // Start animating sand particles with staggered delays
        for (index, particle) in sandParticles.enumerated() {
            // Stagger animation starts to avoid synchronized movement
            let delay = TimeInterval(index) * 0.1
            animateSandParticle(particle, delay: delay)
        }
    }
    
    /// Deactivates the desert background
    /// - Parameter animated: Whether to fade out smoothly
    func deactivate(animated: Bool = true) {
        guard isActive else { return }
        isActive = false
        
        // Stop any existing actions
        gradientSprite.removeAllActions()
        sandParticlesNode.removeAllActions()
        
        // Stop all particle animations
        for particle in sandParticles {
            particle.removeAllActions()
        }
        
        if animated {
            // Smooth fade out
            let fadeOut = SKAction.fadeOut(withDuration: 2.0)
            fadeOut.timingMode = .easeInEaseOut
            gradientSprite.run(fadeOut)
            sandParticlesNode.run(fadeOut)
        } else {
            gradientSprite.alpha = 0.0
            sandParticlesNode.alpha = 0.0
        }
    }
    
    /// Updates the background position to follow camera
    /// Call this from your scene's update() method
    /// - Parameter currentTime: The current time from the scene
    func update(_ currentTime: TimeInterval) {
        guard isActive, let camera = cameraNode else { return }
        
        // Update gradient position to follow camera exactly
        gradientSprite.position = camera.position
        sandParticlesNode.position = camera.position
        
        // Recycle sand particles that have moved too far off screen
        let cameraY = camera.position.y
        let screenWidth = backgroundSize.width
        
        // Only update particle positions periodically (every ~100 units of camera movement)
        if abs(cameraY - lastCameraY) > 100 {
            lastCameraY = cameraY
            
            for particle in sandParticles {
                // Get particle's world position relative to camera
                let relativeX = particle.position.x
                
                // If particle has blown too far left, reset it to the right
                if relativeX < -screenWidth/2 - 50 {
                    particle.position.x = screenWidth/2 + CGFloat.random(in: 0...50)
                    // Randomize y position slightly for variety
                    particle.position.y = CGFloat.random(in: -backgroundSize.height/2...backgroundSize.height/2)
                }
            }
        }
    }
    
    /// Cleans up resources and removes nodes from the scene
    func cleanup() {
        // Stop all animations
        gradientSprite.removeAllActions()
        sandParticlesNode.removeAllActions()
        
        // Stop all particle animations
        for particle in sandParticles {
            particle.removeAllActions()
        }
        
        // Disable
        isActive = false
        
        // Remove from parent
        gradientSprite.removeFromParent()
        sandParticlesNode.removeFromParent()
    }
}

// MARK: - Compatibility Extension

extension DesertBackgroundRenderer {
    
    /// Creates a desert background optimized for device performance
    /// - Parameters:
    ///   - parent: Parent node to add the background to
    ///   - camera: Camera node to track
    ///   - screenSize: Size of the screen/viewport
    /// - Returns: Configured desert background renderer
    static func createOptimized(for parent: SKNode, camera: SKCameraNode, screenSize: CGSize) -> DesertBackgroundRenderer {
        // Make background larger than screen to handle camera movement
        let backgroundSize = CGSize(
            width: screenSize.width * 2,
            height: screenSize.height * 2
        )
        
        // Adjust particle count based on device performance
        // High-end devices get more particles for richer effect
        let particleCount: Int
        if PerformanceSettings.isHighEndDevice {
            particleCount = 35 // More particles on high-end devices
        } else if PerformanceSettings.isLowEndDevice {
            particleCount = 15 // Fewer particles on low-end devices
        } else {
            particleCount = 25 // Default for mid-range devices
        }
        
        let renderer = DesertBackgroundRenderer(
            size: backgroundSize,
            zPosition: -99, // Above water background (-100) to ensure proper layering
            particleCount: particleCount
        )
        renderer.addToNode(parent)
        renderer.setCamera(camera)
        
        return renderer
    }
}
