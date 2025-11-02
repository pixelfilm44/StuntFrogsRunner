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
    var rippleManager: RippleManager!
    private var lastUpdateTime: TimeInterval = 0
    
    init(scene: SKScene) {
        self.scene = scene
        rippleManager = RippleManager()
    }
    
    func setupWorld(sceneSize: CGSize) -> SKNode {
        worldNode = SKNode()
        createWaterBackground(sceneSize: sceneSize)
        return worldNode
    }
    
    func createWaterBackground(sceneSize: CGSize) {
        // Load the water texture; fall back to solid color if missing
        let waterTexture = SKTexture(imageNamed: "water.png")
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

    // MARK: - Update and Scrolling
    func updateScrolling(isJumping: Bool) -> Int {
        let currentTime = CACurrentMediaTime()
        let deltaTime = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime
        rippleManager.update(deltaTime: deltaTime)
        
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
    
    func reset() {
        scrollOffset = 0
        currentScrollSpeed = GameConfig.scrollSpeed
        lastUpdateTime = 0
        rippleManager.reset()
        worldNode.removeAllChildren()
        waterRows.removeAll()
        
        guard let scene = scene else { return }
        createWaterBackground(sceneSize: scene.size)
    }
    
    /// Add a ripple at the given world position
    func addRipple(at worldPosition: CGPoint, amplitude: CGFloat = 0.015, frequency: CGFloat = 8.0) {
        // Store in WORLD coordinates - we'll convert to scene coordinates every frame
        // This way ripples scroll with the world
        rippleManager.addRipple(at: worldPosition, amplitude: amplitude, frequency: frequency)
    }
}

