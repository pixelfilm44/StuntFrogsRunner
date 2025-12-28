//
//  MoonlightRenderer.swift
//  StuntFrogRunner iOS
//
//  Created on 12/23/2025.
//  Performant moonlight effect for the night scene
//

import SpriteKit

/// Renders a moonlight spotlight effect on the frog during night scenes.
/// Uses SKLightNode with optimized settings to maintain 60 FPS.
class MoonlightRenderer {
    
    // MARK: - Properties
    
    /// The light node that creates the moonlight effect
    private let lightNode: SKLightNode
    
    /// Visual spotlight sprite that creates the visible glow effect
    private let spotlightSprite: SKSpriteNode
    
    /// Reference to the frog node to illuminate (for lighting bit mask)
    private weak var targetNode: SKNode?
    
    /// Reference to the camera to determine screen center
    private weak var cameraNode: SKCameraNode?
    
    /// Whether the moonlight is currently active
    private(set) var isActive: Bool = false
    
    /// Smoothing factor for light position (0 = instant, 1 = no movement)
    private let positionSmoothing: CGFloat = 0.15
    
    // MARK: - Initialization
    
    /// Creates a new moonlight renderer
    /// - Parameters:
    ///   - zPosition: The z-position for the light (should be above everything)
    ///   - intensity: Light intensity (0.0 to 1.0, default 0.6)
    init(zPosition: CGFloat = 100, intensity: CGFloat = 0.6) {
        self.lightNode = SKLightNode()
        
        // Configure moonlight appearance
        // Cool blue-white moonlight color
        lightNode.categoryBitMask = 1
        lightNode.falloff = 1.5 // Smooth falloff for natural look
        lightNode.ambientColor = UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: intensity)
        lightNode.lightColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        lightNode.zPosition = zPosition
        lightNode.isEnabled = false
        
        // Performance optimization: Limit shadow casting
        lightNode.shadowColor = .clear // No shadows for better performance
        
        // Create visual spotlight sprite (radial gradient)
        let spotlightSize = CGSize(width: 600, height: 600) // Large enough to cover frog
        let spotlightTexture = Self.createSpotlightTexture(size: spotlightSize, intensity: intensity)
        self.spotlightSprite = SKSpriteNode(texture: spotlightTexture, size: spotlightSize)
        spotlightSprite.zPosition = zPosition - 1 // Just below the light node
        spotlightSprite.alpha = 0
        spotlightSprite.blendMode = .add // Additive blending for glowing effect
    }
    
    /// Creates a radial gradient texture for the spotlight visual effect
    private static func createSpotlightTexture(size: CGSize, intensity: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2
            
            // Create radial gradient: bright center fading to transparent
            let colors = [
                UIColor(red: 0.7, green: 0.85, blue: 1.0, alpha: intensity * 0.4).cgColor,
                UIColor(red: 0.6, green: 0.75, blue: 0.95, alpha: intensity * 0.2).cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            
            let locations: [CGFloat] = [0.0, 0.5, 1.0]
            
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: radius,
                    options: []
                )
            }
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
    
    // MARK: - Public Methods
    
    /// Adds the moonlight renderer to a parent node
    /// - Parameter parent: The parent node (typically the scene)
    func addToNode(_ parent: SKNode) {
        parent.addChild(spotlightSprite) // Add visual spotlight first (renders behind)
        parent.addChild(lightNode)
    }
    
    /// Sets the target node to illuminate (the frog)
    /// - Parameter node: The node to configure for lighting
    func setTarget(_ node: SKNode) {
        self.targetNode = node
        
        // Configure the target to receive lighting (only works on sprite nodes)
        if let spriteNode = node as? SKSpriteNode {
            spriteNode.lightingBitMask = 1
        }
    }
    
    /// Sets the camera to follow for screen center positioning
    /// - Parameter camera: The camera node to track
    func setCamera(_ camera: SKCameraNode) {
        self.cameraNode = camera
        
        // Immediately position the light at the camera center
        if let cam = cameraNode {
            lightNode.position = cam.position
            spotlightSprite.position = cam.position
        }
    }
    
    /// Activates the moonlight effect for night scenes
    /// - Parameter animated: Whether to fade in smoothly
    func activate(animated: Bool = true) {
        guard !isActive else { return }
        
        isActive = true
        lightNode.isEnabled = true
        
        if animated {
            // Fade in the moonlight smoothly
            let fadeIn = SKAction.fadeIn(withDuration: 1.5)
            fadeIn.timingMode = .easeInEaseOut
            lightNode.run(fadeIn)
            spotlightSprite.run(fadeIn) // Also fade in the visual spotlight
        } else {
            lightNode.alpha = 1.0
            spotlightSprite.alpha = 1.0
        }
    }
    
    /// Deactivates the moonlight effect
    /// - Parameter animated: Whether to fade out smoothly
    func deactivate(animated: Bool = true) {
        guard isActive else { return }
        
        isActive = false
        
        if animated {
            // Fade out the moonlight smoothly
            let fadeOut = SKAction.fadeOut(withDuration: 1.5)
            fadeOut.timingMode = .easeInEaseOut
            let disable = SKAction.run { [weak self] in
                self?.lightNode.isEnabled = false
            }
            lightNode.run(SKAction.sequence([fadeOut, disable]))
            spotlightSprite.run(fadeOut) // Also fade out the visual spotlight
        } else {
            lightNode.alpha = 0.0
            lightNode.isEnabled = false
            spotlightSprite.alpha = 0.0
        }
    }
    
    /// Updates the moonlight position to aim at screen center (camera position)
    /// Call this from your scene's update() method
    /// - Parameter currentTime: The current time from the scene
    func update(_ currentTime: TimeInterval) {
        guard isActive, let camera = cameraNode else { return }
        
        // Smoothly interpolate to camera position (screen center) for natural movement
        let targetPosition = camera.position
        let currentPosition = lightNode.position
        
        // Lerp towards target (prevents jittery movement)
        let newX = currentPosition.x + (targetPosition.x - currentPosition.x) * (1.0 - positionSmoothing)
        let newY = currentPosition.y + (targetPosition.y - currentPosition.y) * (1.0 - positionSmoothing)
        
        let newPosition = CGPoint(x: newX, y: newY)
        lightNode.position = newPosition
        spotlightSprite.position = newPosition // Move visual spotlight with the light
    }
    
    /// Updates the moonlight intensity
    /// - Parameter intensity: New intensity value (0.0 to 1.0)
    func setIntensity(_ intensity: CGFloat) {
        let clampedIntensity = max(0.0, min(1.0, intensity))
        lightNode.ambientColor = UIColor(red: 0.7, green: 0.8, blue: 1.0, alpha: clampedIntensity)
    }
    
    /// Creates a subtle pulsing animation for atmospheric effect
    /// - Parameter duration: Duration of one pulse cycle
    func startPulseAnimation(duration: TimeInterval = 3.0) {
        guard isActive else { return }
        
        // Subtle intensity variation (60% to 70%)
        let pulse = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.setIntensity(0.7)
            },
            SKAction.wait(forDuration: duration / 2),
            SKAction.run { [weak self] in
                self?.setIntensity(0.6)
            },
            SKAction.wait(forDuration: duration / 2)
        ])
        
        lightNode.run(SKAction.repeatForever(pulse), withKey: "moonPulse")
    }
    
    /// Stops the pulsing animation
    func stopPulseAnimation() {
        lightNode.removeAction(forKey: "moonPulse")
        setIntensity(0.6) // Reset to default
    }
}

// MARK: - Compatibility Extension

extension MoonlightRenderer {
    
    /// Creates a moonlight renderer optimized for device performance
    /// - Parameters:
    ///   - parent: Parent node to add the renderer to
    ///   - target: The frog node to illuminate
    ///   - camera: The camera node to track for screen center positioning
    /// - Returns: Configured moonlight renderer
    static func createOptimized(for parent: SKNode, target: SKNode, camera: SKCameraNode) -> MoonlightRenderer {
        // Adjust intensity based on device performance
        let intensity: CGFloat
        if PerformanceSettings.isVeryLowEndDevice {
            // Lower intensity for better performance
            intensity = 0.4
        } else if PerformanceSettings.isLowEndDevice {
            intensity = 0.5
        } else {
            intensity = 0.6
        }
        
        // Position spotlight well below the frog layer to avoid visual interference
        // Place it between water and pads (Layer.water = 0, Layer.pad = 10)
        let renderer = MoonlightRenderer(zPosition: 5, intensity: intensity)
        renderer.addToNode(parent)
        renderer.setTarget(target)
        renderer.setCamera(camera)
        
        return renderer
    }
}
