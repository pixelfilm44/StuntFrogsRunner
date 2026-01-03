//
//  SpaceBackgroundRenderer.swift
//  StuntFrogRunner iOS
//
//  Created on 12/31/2025.
//  Performant space background with purple gradient and distant stars
//

import SpriteKit

/// Renders a space-themed background with black-to-purple gradient and twinkling stars.
/// Optimized for 60 FPS performance with minimal draw calls.
class SpaceBackgroundRenderer {
    
    // MARK: - Properties
    
    /// The main background gradient sprite (black to purple)
    private let gradientSprite: SKSpriteNode
    
    /// Container node for all star sprites
    private let starsContainer: SKNode
    
    /// Array of star sprites for animation
    private var stars: [SKSpriteNode] = []
    
    /// Whether the background is currently active
    private(set) var isActive: Bool = false
    
    /// Reference to the camera for parallax effect
    private weak var cameraNode: SKCameraNode?
    
    /// Last camera position for parallax calculation
    private var lastCameraPosition: CGPoint = .zero
    
    // MARK: - Configuration
    
    /// Number of stars to render (fewer = better performance)
    private let starCount: Int
    
    /// Size of the background (should cover the screen with some margin)
    private let backgroundSize: CGSize
    
    /// Parallax speed multiplier for stars (0.0 = no parallax, 1.0 = full parallax)
    private let parallaxSpeed: CGFloat = 0.3
    
    // MARK: - Initialization
    
    /// Creates a new space background renderer
    /// - Parameters:
    ///   - size: Size of the background (should cover screen dimensions)
    ///   - starCount: Number of stars to render (default: 80 for good balance)
    ///   - zPosition: Z-position for the background (should be behind everything)
    init(size: CGSize, starCount: Int = 80, zPosition: CGFloat = -100) {
        self.backgroundSize = size
        self.starCount = starCount
        
        // Create gradient texture and sprite
        let gradientTexture = Self.createSpaceGradientTexture(size: size)
        self.gradientSprite = SKSpriteNode(texture: gradientTexture, size: size)
        gradientSprite.zPosition = zPosition
        gradientSprite.alpha = 0 // Start invisible
        
        // Create stars container
        self.starsContainer = SKNode()
        starsContainer.zPosition = zPosition + 1 // Just above gradient
        starsContainer.alpha = 0 // Start invisible
        
        // Generate stars
        createStars()
    }
    
    /// Creates a smooth gradient texture from black to purple
    /// This is done once and cached for performance
    private static func createSpaceGradientTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Define gradient colors: deep space black to rich purple
            let colors = [
                UIColor(red: 0.05, green: 0.0, blue: 0.1, alpha: 1.0).cgColor,  // Very dark purple-black (top)
                UIColor(red: 0.1, green: 0.05, blue: 0.2, alpha: 1.0).cgColor,  // Dark purple (mid-top)
                UIColor(red: 0.15, green: 0.08, blue: 0.25, alpha: 1.0).cgColor, // Medium purple (mid)
                UIColor(red: 0.2, green: 0.1, blue: 0.3, alpha: 1.0).cgColor,   // Rich purple (mid-bottom)
                UIColor(red: 0.1, green: 0.05, blue: 0.15, alpha: 1.0).cgColor  // Dark purple-black (bottom)
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
    
    /// Creates star sprites with varied sizes and positions
    /// Uses a simple circle texture for performance
    private func createStars() {
        // Create a reusable star texture (simple white circle)
        let starTexture = Self.createStarTexture()
        
        // Determine star spawn area (larger than screen for parallax)
        let spawnWidth = backgroundSize.width * 1.5
        let spawnHeight = backgroundSize.height * 1.5
        let offsetX = -spawnWidth / 4
        let offsetY = -spawnHeight / 4
        
        for _ in 0..<starCount {
            let star = SKSpriteNode(texture: starTexture)
            
            // Random size (smaller = distant stars, larger = closer stars)
            let size = CGFloat.random(in: 1.5...4.0)
            star.size = CGSize(width: size, height: size)
            
            // Random position across the spawn area
            star.position = CGPoint(
                x: CGFloat.random(in: offsetX...(offsetX + spawnWidth)),
                y: CGFloat.random(in: offsetY...(offsetY + spawnHeight))
            )
            
            // Vary brightness for depth (dimmer = further away)
            star.alpha = CGFloat.random(in: 0.5...1.0)
            
            // Subtle color tint (some stars slightly blue, others slightly white)
            let colorVariation = CGFloat.random(in: 0.85...1.0)
            star.color = UIColor(red: colorVariation, green: colorVariation, blue: 1.0, alpha: 1.0)
            star.colorBlendFactor = 0.3
            
            // Add to container
            starsContainer.addChild(star)
            stars.append(star)
            
            // Start twinkle animation with random delay for variety
            let randomDelay = Double.random(in: 0...3.0)
            star.run(SKAction.sequence([
                SKAction.wait(forDuration: randomDelay),
                SKAction.run { [weak star] in
                    star?.startTwinkleAnimation()
                }
            ]))
        }
    }
    
    /// Creates a simple circular star texture
    /// Cached and reused for all stars for performance
    private static func createStarTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Draw a simple white circle
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(origin: .zero, size: size))
            
            // Add a slight glow (optional, can be removed for better performance)
            ctx.setBlendMode(.screen)
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: -2, y: -2, width: size.width + 4, height: size.height + 4))
        }
        
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
    
    // MARK: - Public Methods
    
    /// Adds the space background to a parent node (typically the scene)
    /// - Parameter parent: The parent node to add the background to
    func addToNode(_ parent: SKNode) {
        parent.addChild(gradientSprite)
        parent.addChild(starsContainer)
    }
    
    /// Sets the camera to follow for parallax effect
    /// - Parameter camera: The camera node to track
    func setCamera(_ camera: SKCameraNode) {
        self.cameraNode = camera
        lastCameraPosition = camera.position
        
        // Immediately position the background at camera center
        gradientSprite.position = camera.position
        starsContainer.position = camera.position
    }
    
    /// Activates the space background
    /// - Parameter animated: Whether to fade in smoothly
    func activate(animated: Bool = true) {
        guard !isActive else { return }
        isActive = true
        
        // Stop any existing actions
        gradientSprite.removeAllActions()
        starsContainer.removeAllActions()
        
        if animated {
            // Smooth fade in
            let fadeIn = SKAction.fadeIn(withDuration: 2.0)
            fadeIn.timingMode = .easeInEaseOut
            gradientSprite.run(fadeIn)
            starsContainer.run(fadeIn)
        } else {
            gradientSprite.alpha = 1.0
            starsContainer.alpha = 1.0
        }
    }
    
    /// Deactivates the space background
    /// - Parameter animated: Whether to fade out smoothly
    func deactivate(animated: Bool = true) {
        guard isActive else { return }
        isActive = false
        
        // Stop any existing actions
        gradientSprite.removeAllActions()
        starsContainer.removeAllActions()
        
        if animated {
            // Smooth fade out
            let fadeOut = SKAction.fadeOut(withDuration: 2.0)
            fadeOut.timingMode = .easeInEaseOut
            gradientSprite.run(fadeOut)
            starsContainer.run(fadeOut)
        } else {
            gradientSprite.alpha = 0.0
            starsContainer.alpha = 0.0
        }
    }
    
    /// Updates the background position with parallax effect
    /// Call this from your scene's update() method
    /// - Parameter currentTime: The current time from the scene
    func update(_ currentTime: TimeInterval) {
        guard isActive, let camera = cameraNode else { return }
        
        // Update gradient position to follow camera exactly
        gradientSprite.position = camera.position
        
        // Update stars with parallax effect (moves slower than camera for depth)
        let cameraDelta = CGPoint(
            x: camera.position.x - lastCameraPosition.x,
            y: camera.position.y - lastCameraPosition.y
        )
        
        // Apply parallax: stars move slower than camera, creating depth illusion
        let parallaxOffset = CGPoint(
            x: cameraDelta.x * parallaxSpeed,
            y: cameraDelta.y * parallaxSpeed
        )
        
        starsContainer.position.x += parallaxOffset.x
        starsContainer.position.y += parallaxOffset.y
        
        lastCameraPosition = camera.position
    }
    
    /// Cleans up resources and removes nodes from the scene
    func cleanup() {
        // Stop all animations
        gradientSprite.removeAllActions()
        starsContainer.removeAllActions()
        for star in stars {
            star.removeAllActions()
        }
        
        // Disable
        isActive = false
        
        // Remove from parent
        gradientSprite.removeFromParent()
        starsContainer.removeFromParent()
        
        // Clear references
        stars.removeAll()
    }
}

// MARK: - Star Twinkle Animation Extension

private extension SKSpriteNode {
    /// Adds a subtle twinkling animation to a star
    func startTwinkleAnimation() {
        // Random twinkle duration for variety
        let twinkleDuration = Double.random(in: 1.5...3.5)
        
        // Fade out slightly
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: twinkleDuration / 2)
        fadeOut.timingMode = .easeInEaseOut
        
        // Fade back in
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: twinkleDuration / 2)
        fadeIn.timingMode = .easeInEaseOut
        
        // Create sequence
        let twinkle = SKAction.sequence([fadeOut, fadeIn])
        
        // Repeat forever
        run(SKAction.repeatForever(twinkle), withKey: "twinkle")
    }
}

// MARK: - Compatibility Extension

extension SpaceBackgroundRenderer {
    
    /// Creates a space background optimized for device performance
    /// - Parameters:
    ///   - parent: Parent node to add the background to
    ///   - camera: Camera node to track
    ///   - screenSize: Size of the screen/viewport
    /// - Returns: Configured space background renderer
    static func createOptimized(for parent: SKNode, camera: SKCameraNode, screenSize: CGSize) -> SpaceBackgroundRenderer {
        // Adjust star count based on device performance
        let starCount: Int
        if PerformanceSettings.isVeryLowEndDevice {
            starCount = 40  // Fewer stars for low-end devices
        } else if PerformanceSettings.isLowEndDevice {
            starCount = 60
        } else {
            starCount = 100  // More stars for high-end devices
        }
        
        // Make background larger than screen to handle camera movement
        let backgroundSize = CGSize(
            width: screenSize.width * 2,
            height: screenSize.height * 2
        )
        
        let renderer = SpaceBackgroundRenderer(
            size: backgroundSize,
            starCount: starCount,
            zPosition: -100
        )
        renderer.addToNode(parent)
        renderer.setCamera(camera)
        
        return renderer
    }
}
