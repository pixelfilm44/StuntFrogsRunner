//
//  WorldManager.swift
//  Top-down scrolling pond view with water ripples
//

import SpriteKit


class WorldManager {
    var worldNode: SKNode!
    var scrollOffset: CGFloat = 0
    var currentScrollSpeed: CGFloat = GameConfig.scrollSpeed
    
    weak var scene: SKScene?
    
    // Water tiling config
    private var waterTileSize: CGSize = .zero
    private let rowOverlap: Int = 2
    private let colOverlap: Int = 2
    private var waterRows: [SKNode] = []
    private var waterFlowStartTime: TimeInterval = CACurrentMediaTime()
    private var waterFlowSpeed: CGFloat = 0.25
    
    // Ripple system
    private var rippleManager: RippleManager?
    private var lastUpdateTime: TimeInterval = 0
    
    init(scene: SKScene) {
        self.scene = scene
        rippleManager = RippleManager()
    }
    
    func setupWorld(sceneSize: CGSize, weather: WeatherType = .day) -> SKNode {
        worldNode = SKNode()
        createWaterBackground(sceneSize: sceneSize, weather: weather)
        
        // Create night-specific effects if it's night weather
        if weather == .night {
            createStarField(for: weather)
        }
        
        return worldNode
    }
    
    func createWaterBackground(sceneSize: CGSize, weather: WeatherType = .day) {
        // Load the weather-appropriate water texture
        let waterTexture = getWaterTextureForWeather(weather)
        let hasTexture = waterTexture.size() != .zero

        // Decide tile size: use texture size or a reasonable default
        let tileSize: CGSize = hasTexture ? waterTexture.size() : CGSize(width: 256, height: 256)
        // Scale tile to device pixel size so it looks crisp; keep aspect ratio
        let scaleX = max(1.0, sceneSize.width / tileSize.width / 4.0)
        let scaleY = max(1.0, sceneSize.height / tileSize.height / 7.0)
        let scale = max(scaleX, scaleY)
        let finalTileSize = CGSize(width: tileSize.width * scale, height: tileSize.height * scale)

        waterTileSize = finalTileSize

        // Compute how many rows/cols we need to cover the screen with some overlap to recycle
        let colsNeeded = Int(ceil(sceneSize.width / finalTileSize.width)) + colOverlap + 2
        let rowsNeeded = Int(ceil(sceneSize.height / finalTileSize.height)) + rowOverlap + 2

        // Reset any previous rows
        waterRows.removeAll()

        // Create a grid of tiles parented in row nodes for easy vertical recycling
        // We'll center the grid so that (0,0) is roughly the scene center in world space
        let gridOriginX = -CGFloat(colsNeeded) * finalTileSize.width / 2.0 + finalTileSize.width / 2.0
        let gridOriginY = -CGFloat(rowsNeeded) * finalTileSize.height / 2.0 + finalTileSize.height / 2.0

        for rowIndex in 0..<rowsNeeded {
            let rowNode = SKNode()
            rowNode.name = "waterRow"
            rowNode.zPosition = -50

            // Position the row in world space; the world node will be positioned by the scene
            let rowY = gridOriginY + CGFloat(rowIndex) * finalTileSize.height
            rowNode.position = CGPoint(x: 0, y: rowY.rounded())

            for colIndex in 0..<colsNeeded {
                let x = gridOriginX + CGFloat(colIndex) * finalTileSize.width
                let tile: SKSpriteNode
                if hasTexture {
                    tile = SKSpriteNode(texture: waterTexture, size: finalTileSize)
                } else {
                    // Fallback solid color if the texture is missing
                    tile = SKSpriteNode(color: UIColor(red: 0.06, green: 0.30, blue: 0.50, alpha: 1.0), size: finalTileSize)
                }
                tile.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                tile.position = CGPoint(x: x.rounded(), y: 0)

                rowNode.addChild(tile)
            }

            // Apply drift animation to the entire row so all tiles move in sync
            let rowPhase = Double(rowIndex).truncatingRemainder(dividingBy: 4.0) * 0.25
            let driftDistance: CGFloat = 6.0
            let driftDuration: TimeInterval = 6.0
            let left = SKAction.moveBy(x: -driftDistance, y: 0, duration: driftDuration)
            let right = SKAction.moveBy(x: driftDistance, y: 0, duration: driftDuration)
            left.timingMode = .easeInEaseOut
            right.timingMode = .easeInEaseOut
            let drift = SKAction.sequence([left, right])
            let driftForever = SKAction.repeatForever(drift)
            let wait = SKAction.wait(forDuration: rowPhase * driftDuration)
            rowNode.run(SKAction.sequence([wait, driftForever]))

            // Center grid horizontally in scene coordinates
            rowNode.position.x = sceneSize.width / 2.0
            worldNode.addChild(rowNode)
            waterRows.append(rowNode)
        }

        waterFlowStartTime = CACurrentMediaTime()
    }
    
    // MARK: - Stars and Fireflies
    
    /// Creates star field that moves with the water background during night weather
    func createStarField(for weather: WeatherType) {
        guard weather == .night else { return }
        guard let scene = scene else {
            print("❌ Star field creation failed: No scene")
            return
        }
        
        print("🌟 Creating star field in world coordinates...")
        
        // Place stars in the world coordinate system so they move with the background
        let starParent = worldNode!
        let starZPosition: CGFloat = 1 // Below lily pads but above background
        
        // Use a larger area than just the screen to create stars across the world
        // This ensures stars are visible as the player moves around
        let screenSize = scene.size
        let worldBounds = CGRect(
            x: -screenSize.width * 2,
            y: -screenSize.height * 2,
            width: screenSize.width * 4,
            height: screenSize.height * 4
        )
        print("🌟 Using world node for stars, bounds: \(worldBounds)")
        
        // Create a manageable number of star reflections for performance
        let starCount = 160 // Increased slightly since we're covering a larger area
        print("🌟 Creating \(starCount) stars...")
        
        var starsCreated = 0
        
        for i in 0..<starCount {
            let starRadius = CGFloat.random(in: 3...5)
            let star = SKShapeNode(circleOfRadius: starRadius)
            star.name = "star" // Add name for debugging
            star.fillColor = UIColor(red: 1.0, green: 1.0, blue: CGFloat.random(in: 0.8...1.0), alpha: 0.6)
            star.strokeColor = UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.3)
            star.lineWidth = 1.5
            
            // Create a subtle ripple effect for water reflections
            let rippleRadius = CGFloat.random(in: 8...15)
            let ripple = SKShapeNode(circleOfRadius: rippleRadius)
            ripple.name = "starRipple"
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
            starsCreated += 2 // Count both star and ripple
            
            // Create twinkling effect with staggered timing for performance
            let twinkleDuration = TimeInterval.random(in: 1.5...3.5)
            let delay = TimeInterval(i) * 0.01 // Reduced delay for faster startup
            
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
                SKAction.wait(forDuration: delay + 0.1),
                rippleForever
            ]))
        }
        
        print("🌟 Created \(starsCreated) star elements (stars + ripples)")
        
        // Generate initial fireflies around the starting area for night weather
        let initialWorldCenter = CGPoint.zero // Adjust based on your game's starting position
        print("🐛 Creating fireflies around world center: \(initialWorldCenter)")
        generateFirefliesInWorldArea(centerWorldPosition: initialWorldCenter, areaRadius: 400)
    }
    
    /// Creates fireflies at static world positions that persist as the frog moves past them
    /// Call this periodically to populate new areas as the frog explores
    func generateFirefliesInWorldArea(centerWorldPosition: CGPoint, areaRadius: CGFloat) {
        guard let scene = scene else { return }
        
        // Place fireflies in world coordinates so they move with the background
        let fireflyParent = worldNode!
        let fireflyZPosition: CGFloat = 15 // Above lily pads and water, below most effects
        
        // Create fireflies scattered around the specified world area
        let fireflyCount = Int(areaRadius / 150) + 2 // Scale count with area size, minimum 2
        let maxFireflies = 18 // Cap to avoid performance issues
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
        let firefly = SKShapeNode(circleOfRadius: CGFloat.random(in: 5...10))
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
        
        let fireflyParent = worldNode!
        
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
    /// if currentWeather == .night {
    ///     worldManager.updateFirefliesForPosition(frog.position)
    /// }
    /// ```
    public func updateFirefliesForPosition(_ frogWorldPosition: CGPoint) {
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
        
        let fireflyParent = worldNode!
        
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
        
        let fireflyParent = worldNode!
        
        var removed = 0
        fireflyParent.enumerateChildNodes(withName: "firefly") { node, _ in
            node.removeFromParent()
            removed += 1
        }
        
        print("🐛 Removed \(removed) fireflies")
    }
    
    /// Remove all stars from the world (useful when switching weather or resetting)
    public func removeAllStars() {
        guard let scene = scene else { return }
        
        let starParent = worldNode!
        
        var removed = 0
        starParent.enumerateChildNodes(withName: "star") { node, _ in
            node.removeFromParent()
            removed += 1
        }
        starParent.enumerateChildNodes(withName: "starRipple") { node, _ in
            node.removeFromParent()
            removed += 1
        }
        
        print("🌟 Removed \(removed) star elements")
    }
    

    // MARK: - Update and Scrolling
    func updateScrolling(isJumping: Bool) -> Int {
        guard let _ = scene else { return 0 } // Safety check
        
        let currentTime = CACurrentMediaTime()
        let deltaTime = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime
        rippleManager?.update(deltaTime: deltaTime)
        
        guard isJumping else {
            // No auto-scroll when grounded
            // Keep basic water animation active
            recycleWaterRows()
            updateWaterShaderTime()
            return 0
        }
        
        // No auto-scroll during jumping either
        // Keep basic water animation active
        recycleWaterRows()
        updateWaterShaderTime()
        return 0
    }
    
    private func updateWaterShaderTime() {
        guard let scene = scene else { return }
        let t = Float(CACurrentMediaTime() - waterFlowStartTime)
        
        for (index, row) in waterRows.enumerated() {
            // Add gentle alpha pulsing to each row with phase offset
            let rowPhase = CGFloat(t) * 0.3 + CGFloat(index) * 0.2
            let alphaModulation = 0.95 + sin(rowPhase) * 0.05
            row.alpha = alphaModulation
        }
    }
    
    private func recycleWaterRows() {
        guard let scene = scene else { return }
        let rowHeight = (waterTileSize.height > 0) ? waterTileSize.height : 300
        
        for row in waterRows {
            let worldY = row.position.y + worldNode.position.y
            if worldY < -rowHeight {
                let totalHeight = rowHeight * CGFloat(waterRows.count)
                row.position.y += totalHeight
                // Sprite positions will be updated in updateWaterShaderTime
            }
        }
    }
    
    func reset(weather: WeatherType = .day) {
        scrollOffset = 0
        currentScrollSpeed = GameConfig.scrollSpeed
        lastUpdateTime = 0
        rippleManager?.reset()
        worldNode.removeAllChildren()
        waterRows.removeAll()
        
        guard let scene = scene else { return }
        createWaterBackground(sceneSize: scene.size, weather: weather)
        
        // Create night-specific effects if it's night weather
        if weather == .night {
            createStarField(for: weather)
        }
    }
    
    // MARK: - Weather-based Water Textures
    
    /// Get the appropriate water texture based on weather conditions
    private func getWaterTextureForWeather(_ weather: WeatherType) -> SKTexture {
        let textureName = getWaterTextureNameForWeather(weather)
        let texture = SKTexture(imageNamed: textureName)
        
        // If the weather-specific texture doesn't exist, fall back to default
        if texture.size() == .zero && weather != .day {
            print("⚠️ Weather-specific water texture '\(textureName)' not found, falling back to water.png")
            return SKTexture(imageNamed: "water.png")
        }
        
        return texture
    }
    
    /// Get the texture name for water based on weather
    private func getWaterTextureNameForWeather(_ weather: WeatherType) -> String {
        switch weather {
        case .day:
            return "water.png"
        case .night:
            return "water_night.png"
        case .stormy, .storm:
            return "water_stormy.png" 
        case .rain:
            return "water_rain.png"
        case .winter, .ice:
            return "water_winter.png"
        }
    }
    
    /// Update water textures for weather change without recreating the background
    func updateWaterTextureForWeather(_ weather: WeatherType) {
        let newTexture = getWaterTextureForWeather(weather)
        
        // Update all existing water tiles with the new texture
        for row in waterRows {
            for child in row.children {
                if let tile = child as? SKSpriteNode {
                    tile.texture = newTexture
                }
            }
        }
    }
    
    /// Update the world for a weather change, handling night-specific effects
    func updateWorldForWeather(_ weather: WeatherType) {
        // Update water textures
        updateWaterTextureForWeather(weather)
        
        // Handle night-specific effects
        if weather == .night {
            // Add stars and fireflies if not already present
            createStarField(for: weather)
        } else {
            // Remove stars and fireflies for non-night weather
            removeAllStars()
            removeAllFireflies()
        }
    }
    
    /// Add a ripple at the given world position
    func addRipple(at worldPosition: CGPoint, amplitude: CGFloat = 0.015, frequency: CGFloat = 8.0) {
        // Store in WORLD coordinates - we'll convert to scene coordinates every frame
        // This way ripples scroll with the world
        rippleManager?.addRipple(at: worldPosition, amplitude: amplitude, frequency: frequency)
    }
    
    /// Clean up all resources to prevent memory leaks
    func cleanup() {
        rippleManager = nil
        scene = nil
        worldNode?.removeAllChildren()
        worldNode = nil
        waterRows.removeAll()
    }
}

