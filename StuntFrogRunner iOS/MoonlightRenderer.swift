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
    let lightNode: SKLightNode
    
    /// Visual spotlight sprite that creates the visible glow effect
    private let spotlightSprite: SKSpriteNode
    
    /// Background illumination sprite (for space scenes where background needs lighting)
    private let backgroundIllumination: SKSpriteNode?
    
    /// Reference to the frog node to illuminate (for lighting bit mask)
    private weak var targetNode: SKNode?
    
    /// Reference to the camera to determine screen center
    private weak var cameraNode: SKCameraNode?
    
    /// Whether the moonlight is currently active
    private(set) var isActive: Bool = false
    
    /// Smoothing factor for light position (0 = instant, 1 = no movement)
    private let positionSmoothing: CGFloat
    
    /// Color scheme for the spotlight
    private let colorScheme: ColorScheme
    
    /// Available color schemes for different weather types
    enum ColorScheme {
            case moonlight
            case spaceBlue
            
            var ambientColor: (red: CGFloat, green: CGFloat, blue: CGFloat) {
                switch self {
                case .moonlight:
                    return (0.7, 0.8, 1.0)
                case .spaceBlue:
                    return (0.2, 0.2, 0.2)
                }
            }
            
            var lightColor: (red: CGFloat, green: CGFloat, blue: CGFloat) {
                // Both use the same light color
                return (0.9, 0.95, 1.0)
            }
            
            var spotlightColors: [(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)] {
                switch self {
                case .moonlight:
                    return [
                        (0.7, 0.85, 1.0, 0.4),
                        (0.6, 0.75, 0.95, 0.2),
                        (0.0, 0.0, 0.0, 0.0)
                    ]
                case .spaceBlue:
                    return [
                        (0.2, 0.95, 0.2, 0.15),  // Dramatically reduced from 0.85
                        (0.2, 0.2, 0.2, 0.08),   // Dramatically reduced from 0.6
                        (0.0, 0.0, 0.0, 0.0)
                    ]
                }
            }
            
            var spotlightSize: CGSize {
                switch self {
                case .moonlight:
                    return CGSize(width: 1200, height: 1200)
                case .spaceBlue:
                    return CGSize(width: 300, height: 300)  // Reduced from 500 for tighter glow
                }
            }
            
            var usesBackgroundIllumination: Bool {
                switch self {
                case .moonlight:
                    return false
                case .spaceBlue:
                    return true
                }
            }
            
            var positionSmoothing: CGFloat {
                switch self {
                case .moonlight:
                    return 0.15  // Smooth movement
                case .spaceBlue:
                    return 0.15   // Locked to camera (no smoothing)
                }
            }
        }
    // MARK: - Initialization
    
    /// Creates a new moonlight renderer
    /// - Parameters:
    ///   - zPosition: The z-position for the light (should be above everything)
    ///   - intensity: Light intensity (0.0 to 1.0, default 0.6)
    ///   - colorScheme: The color scheme to use (default .moonlight)
    init(zPosition: CGFloat = 100, intensity: CGFloat = 0.6, colorScheme: ColorScheme = .moonlight) {
            self.colorScheme = colorScheme
            self.positionSmoothing = colorScheme.positionSmoothing
            self.lightNode = SKLightNode()
            
            let ambient = colorScheme.ambientColor
            let light = colorScheme.lightColor
            
            lightNode.categoryBitMask = 1
            lightNode.falloff = 1.5
            lightNode.ambientColor = UIColor(red: ambient.red, green: ambient.green, blue: ambient.blue, alpha: intensity)
            lightNode.lightColor = UIColor(red: light.red, green: light.green, blue: light.blue, alpha: 1.0)
            lightNode.zPosition = zPosition
            lightNode.isEnabled = false
            lightNode.shadowColor = .clear
            
            // Get spotlight size from color scheme
            let spotlightSize = colorScheme.spotlightSize
            
            let spotlightTexture = Self.createSpotlightTexture(size: spotlightSize, intensity: intensity, colorScheme: colorScheme)
            self.spotlightSprite = SKSpriteNode(texture: spotlightTexture, size: spotlightSize)
            spotlightSprite.zPosition = zPosition - 1
            spotlightSprite.alpha = 0
            spotlightSprite.blendMode = .add
            
            // Create background illumination if the color scheme uses it
            if colorScheme.usesBackgroundIllumination {
                let bgSize = CGSize(width: 2000, height: 2000)
                let bgTexture = Self.createBackgroundIlluminationTexture(size: bgSize, intensity: intensity)
                let bgSprite = SKSpriteNode(texture: bgTexture, size: bgSize)
                bgSprite.zPosition = -50
                bgSprite.alpha = 0
                bgSprite.blendMode = .add
                self.backgroundIllumination = bgSprite
            } else {
                self.backgroundIllumination = nil
            }
        }
    /// Creates a radial gradient texture for the spotlight visual effect
    private static func createSpotlightTexture(size: CGSize, intensity: CGFloat, colorScheme: ColorScheme) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2
            
            // Get colors from the color scheme
            let schemeColors = colorScheme.spotlightColors
            
            // Create radial gradient: bright center fading to transparent
            let colors = [
                UIColor(red: schemeColors[0].red, green: schemeColors[0].green, blue: schemeColors[0].blue, alpha: intensity * schemeColors[0].alpha).cgColor,
                UIColor(red: schemeColors[1].red, green: schemeColors[1].green, blue: schemeColors[1].blue, alpha: intensity * schemeColors[1].alpha).cgColor,
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
    
    /// Creates a large radial gradient for background illumination in space scenes
    private static func createBackgroundIlluminationTexture(size: CGSize, intensity: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = size.width / 2
            
            // Create a light blue gradient that illuminates the dark space background
            // Dramatically reduced alpha values for subtler glow
            let colors = [
                UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: intensity * 0.15).cgColor,  // Reduced from 0.8
                UIColor(red: 0.7, green: 0.85, blue: 0.98, alpha: intensity * 0.08).cgColor,  // Reduced from 0.5
                UIColor(red: 0.6, green: 0.75, blue: 0.9, alpha: intensity * 0.03).cgColor,  // Reduced from 0.2
                UIColor.clear.cgColor
            ] as CFArray
            
            let locations: [CGFloat] = [0.0, 0.3, 0.7, 1.0]
            
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
    /// Adds the moonlight renderer to a parent node
        /// - Parameter parent: The parent node (typically the scene)
        func addToNode(_ parent: SKNode) {
            if let bgIllumination = backgroundIllumination {
                parent.addChild(bgIllumination) // Add background illumination
            }
            parent.addChild(spotlightSprite) // Add visual spotlight
            
            // DISABLE DYNAMIC LIGHTING:
            // We do NOT add lightNode to the parent.
            // This prevents the scene from being darkened by the lighting engine.
            // parent.addChild(lightNode)
        }
    
    /// Sets the target node to illuminate (the frog)
    /// - Parameter node: The node to configure for lighting
    func setTarget(_ node: SKNode) {
        self.targetNode = node
        
        // FIX: Recursively disable lighting on the target and all its children
        // This ensures the frog is rendered at full brightness (ignoring the dark ambient light)
        // Note: lightingBitMask is only available on SKSpriteNode
        if let sprite = node as? SKSpriteNode {
            sprite.lightingBitMask = 0
        }
        
        node.enumerateChildNodes(withName: "//*") { child, _ in
            if let sprite = child as? SKSpriteNode {
                sprite.lightingBitMask = 0
            }
            // Note: SKShapeNode doesn't have lightingBitMask property
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
            backgroundIllumination?.position = cam.position
        }
    }
    
    /// Activates the moonlight effect for night scenes
    /// - Parameter animated: Whether to fade in smoothly
    func activate(animated: Bool = true) {
        guard !isActive else { return }
        
        isActive = true
        
        // Stop any existing actions to prevent conflicts
        lightNode.removeAllActions()
        spotlightSprite.removeAllActions()
        backgroundIllumination?.removeAllActions()
        
        lightNode.isEnabled = true
        
        if animated {
            // Fade in the moonlight smoothly
            let fadeIn = SKAction.fadeIn(withDuration: 1.5)
            fadeIn.timingMode = .easeInEaseOut
            lightNode.run(fadeIn)
            spotlightSprite.run(fadeIn)
            backgroundIllumination?.run(fadeIn) // Fade in background illumination
        } else {
            lightNode.alpha = 1.0
            spotlightSprite.alpha = 1.0
            backgroundIllumination?.alpha = 1.0
        }
    }
    
    /// Deactivates the moonlight effect
    /// - Parameter animated: Whether to fade out smoothly
    func deactivate(animated: Bool = true) {
        guard isActive else { return }
        
        isActive = false
        
        // Stop any existing actions to prevent conflicts
        lightNode.removeAllActions()
        spotlightSprite.removeAllActions()
        backgroundIllumination?.removeAllActions()
        
        if animated {
            // Fade out the moonlight smoothly
            let fadeOut = SKAction.fadeOut(withDuration: 1.5)
            fadeOut.timingMode = .easeInEaseOut
            let disable = SKAction.run { [weak self] in
                self?.lightNode.isEnabled = false
            }
            lightNode.run(SKAction.sequence([fadeOut, disable]))
            spotlightSprite.run(fadeOut)
            backgroundIllumination?.run(fadeOut) // Fade out background illumination
        } else {
            lightNode.alpha = 0.0
            spotlightSprite.alpha = 0.0
            backgroundIllumination?.alpha = 0.0
            lightNode.isEnabled = false
        }
    }
    
    /// Updates the moonlight position to aim at screen center (camera position)
    /// Call this from your scene's update() method
    /// - Parameter currentTime: The current time from the scene
    func update(_ currentTime: TimeInterval) {
        guard isActive, let camera = cameraNode else { return }
        
        // Use color scheme's position smoothing setting
        let targetPosition = camera.position
        let currentPosition = lightNode.position
        
        // Lerp towards target using the smoothing factor (0 = instant, higher = more smoothing)
        let newX = currentPosition.x + (targetPosition.x - currentPosition.x) * (1.0 - positionSmoothing)
        let newY = currentPosition.y + (targetPosition.y - currentPosition.y) * (1.0 - positionSmoothing)
        
        let newPosition = CGPoint(x: newX, y: newY)
        lightNode.position = newPosition
        spotlightSprite.position = newPosition
        backgroundIllumination?.position = newPosition
    }
    
    /// Updates the moonlight intensity
    /// - Parameter intensity: New intensity value (0.0 to 1.0)
    func setIntensity(_ intensity: CGFloat) {
        let clampedIntensity = max(0.0, min(1.0, intensity))
        let ambient = colorScheme.ambientColor
        lightNode.ambientColor = UIColor(red: ambient.red, green: ambient.green, blue: ambient.blue, alpha: clampedIntensity)
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
    
    /// Cleans up resources and removes nodes from the scene
    /// Call this before deallocating or when changing scenes
    func cleanup() {
        // Stop all animations
        lightNode.removeAllActions()
        spotlightSprite.removeAllActions()
        backgroundIllumination?.removeAllActions()
        
        // Disable lighting
        isActive = false
        lightNode.isEnabled = false
        
        // Remove from parent
        lightNode.removeFromParent()
        spotlightSprite.removeFromParent()
        backgroundIllumination?.removeFromParent()
    }
}

// MARK: - Compatibility Extension

extension MoonlightRenderer {
    
    /// Creates a moonlight renderer optimized for device performance
    /// - Parameters:
    ///   - parent: Parent node to add the renderer to
    ///   - target: The frog node to illuminate
    ///   - camera: The camera node to track for screen center positioning
    ///   - colorScheme: The color scheme to use (default .moonlight)
    /// - Returns: Configured moonlight renderer
    static func createOptimized(for parent: SKNode, target: SKNode, camera: SKCameraNode, colorScheme: ColorScheme = .moonlight) -> MoonlightRenderer {
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
        let renderer = MoonlightRenderer(zPosition: 5, intensity: intensity, colorScheme: colorScheme)
        renderer.addToNode(parent)
        renderer.setTarget(target)
        renderer.setCamera(camera)
        
        return renderer
    }
    
    /// Creates a blue-hued space spotlight renderer optimized for device performance
    /// - Parameters:
    ///   - parent: Parent node to add the renderer to
    ///   - target: The frog node to illuminate
    ///   - camera: The camera node to track for screen center positioning
    /// - Returns: Configured space spotlight renderer with blue hue
    static func createSpaceSpotlight(for parent: SKNode, target: SKNode, camera: SKCameraNode) -> MoonlightRenderer {
        // Space needs higher intensity to illuminate the dark environment
        let intensity: CGFloat
        if PerformanceSettings.isVeryLowEndDevice {
            intensity = 0.8
        } else if PerformanceSettings.isLowEndDevice {
            intensity = 0.9
        } else {
            intensity = 1.0  // Maximum brightness for space
        }
        
        let renderer = MoonlightRenderer(zPosition: 5, intensity: intensity, colorScheme: .spaceBlue)
        renderer.addToNode(parent)
        renderer.setTarget(target)
        renderer.setCamera(camera)
        
        return renderer
    }
}
