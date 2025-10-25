//
//  WorldManager.swift
//  Top-down scrolling pond view
//

import SpriteKit

class WorldManager {
    var worldNode: SKNode!
    var scrollOffset: CGFloat = 0
    var currentScrollSpeed: CGFloat = GameConfig.scrollSpeed
    
    weak var scene: SKScene?
    
    // Water tiling config
    private let waterTextureName = "water" // "water.png" in assets
    private var waterTileSize: CGSize = .zero
    private let rowOverlap: Int = 2 // extra rows to cover recycling
    private let colOverlap: Int = 2 // extra columns to cover width edges
    private var waterRows: [SKNode] = []
    private var waterFlowStartTime: TimeInterval = CACurrentMediaTime()
    private var waterFlowSpeed: CGFloat = 0.02 // UV units per second (shader-based)
    
    init(scene: SKScene) {
        self.scene = scene
    }
    
    func setupWorld(sceneSize: CGSize) -> SKNode {
        worldNode = SKNode()
        createWaterBackground(sceneSize: sceneSize)
        return worldNode
    }
    
    // MARK: - Water Background (Grid of Sprites with Shader Flow)
    func createWaterBackground(sceneSize: CGSize) {
        guard let texture = SKTexture(imageNamed: waterTextureName).copy() as? SKTexture else {
            // Fallback to solid color if texture missing
            createProceduralFallback(sceneSize: sceneSize)
            return
        }
        
        // Use texture's point size
        waterTileSize = texture.size()
        if waterTileSize.width <= 0 || waterTileSize.height <= 0 {
            createProceduralFallback(sceneSize: sceneSize)
            return
        }
        
        // Build rows that cover screen height + overlap
        let tileH = waterTileSize.height
        let tileW = waterTileSize.width
        
        // Number of rows needed to cover height; add overlap rows for recycling
        let rowsNeeded = Int(ceil(sceneSize.height / tileH)) + rowOverlap
        // Number of columns needed to cover width; add overlap columns
        let colsNeeded = Int(ceil(sceneSize.width / tileW)) + colOverlap
        
        // Prebuild shader for flow
        let waterShader = makeWaterFlowShader()
        
        waterRows.removeAll()
        
        for rowIndex in 0..<rowsNeeded {
            let rowNode = SKNode()
            rowNode.name = "waterRow"
            rowNode.zPosition = -50 // behind pads and enemies
            
            // Y position for this row (centered tiles)
            let rowY = CGFloat(rowIndex) * tileH + tileH / 2.0
            rowNode.position = CGPoint(x: 0, y: rowY)
            
            // Build columns across width
            for colIndex in 0..<colsNeeded {
                let sprite = SKSpriteNode(texture: texture)
                sprite.size = waterTileSize
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                
                // Compute X position for this column
                // Start a bit left so columns cover entire width
                let startX = -sceneSize.width / 2.0 - (CGFloat(colOverlap) * tileW / 2.0) + tileW / 2.0
                let x = startX + CGFloat(colIndex) * tileW
                sprite.position = CGPoint(x: x, y: 0)
                
                // Apply shader for animated flow
                sprite.shader = waterShader
                // Provide per-sprite uniforms (flow direction can vary slightly for variety)
                let dir = vector_float2(0.0, -1.0) // downward flow
                sprite.setValue(SKAttributeValue(vectorFloat2: dir), forAttribute: "a_flowDir")
                
                rowNode.addChild(sprite)
            }
            
            // Position rowNode in world space
            rowNode.position.x = sceneSize.width / 2.0
            worldNode.addChild(rowNode)
            waterRows.append(rowNode)
        }
        
        // Start time for shader
        waterFlowStartTime = CACurrentMediaTime()
    }
    
    // Simple shader that scrolls UVs over time. Attributes:
    // a_flowDir: vec2 direction; u_time: time; u_speed: flow speed
    private func makeWaterFlowShader() -> SKShader {
        let source = """
        // SpriteKit fragment shader
        // Scrolls texture coordinates over time to simulate flow
        varying vec2 v_tex_coord;
        uniform float u_time;
        uniform float u_speed;
        attribute vec2 a_flowDir;
        
        void main() {
            // Normalize flow direction
            vec2 dir = normalize(a_flowDir);
            // Offset UVs by time * speed * direction
            vec2 uv = v_tex_coord + dir * (u_time * u_speed);
            // Wrap UVs to [0,1] for tiling
            uv = fract(uv);
            gl_FragColor = texture2D(u_texture, uv) * v_color_mix.a + v_color_mix.rgbab;
        }
        """
        let shader = SKShader(source: source)
        // Custom uniforms
        let timeUniform = SKUniform(name: "u_time", float: 0.0)
        let speedUniform = SKUniform(name: "u_speed", float: Float(waterFlowSpeed))
        shader.addUniform(timeUniform)
        shader.addUniform(speedUniform)
        
        // Declare attribute for flow direction
        shader.attributes = [
            SKAttribute(name: "a_flowDir", type: .vectorFloat2)
        ]
        
        return shader
    }
    
    // Fallback if texture missing
    private func createProceduralFallback(sceneSize: CGSize) {
        let tileHeight: CGFloat = 300
        let numberOfTiles = Int(ceil(sceneSize.height / tileHeight)) + 3
        
        for i in 0..<numberOfTiles {
            let tile = SKNode()
            tile.name = "waterRow"
            
            let water = SKShapeNode(rectOf: CGSize(width: sceneSize.width, height: tileHeight))
            water.fillColor = UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
            water.strokeColor = .clear
            water.zPosition = -20
            tile.addChild(water)
            
            tile.position = CGPoint(x: sceneSize.width / 2, y: CGFloat(i) * tileHeight + tileHeight / 2)
            worldNode.addChild(tile)
            waterRows.append(tile)
        }
    }
    
    // MARK: - Update and Scrolling
    func updateScrolling(isJumping: Bool) -> Int {
        // CRITICAL: Only scroll when frog is jumping!
        guard isJumping else {
            currentScrollSpeed = 0
            // Still update shader time for flow
            updateWaterShaderTime()
            return 0
        }
        
        // Scroll faster when jumping
        currentScrollSpeed = GameConfig.scrollSpeedWhileJumping
        
        // Move world DOWN (objects appear to scroll down screen)
        worldNode.position.y -= currentScrollSpeed
        scrollOffset += currentScrollSpeed
        
        recycleWaterRows()
        updateWaterShaderTime()
        
        // Score based on distance traveled
        return Int(currentScrollSpeed * 2)
    }
    
    private func updateWaterShaderTime() {
        let t = Float(CACurrentMediaTime() - waterFlowStartTime)
        // Update uniform u_time on all sprite children
        for row in waterRows {
            for case let sprite as SKSpriteNode in row.children {
                sprite.shader?.uniformNamed("u_time")?.floatValue = t
                // u_speed already set via shader default; can be varied per sprite if desired
            }
        }
    }
    
    private func recycleWaterRows() {
        guard let scene = scene else { return }
        // Determine row height
        let rowHeight = (waterTileSize.height > 0) ? waterTileSize.height : 300
        
        for row in waterRows {
            // world space Y of this row
            let worldY = row.position.y + worldNode.position.y
            if worldY < -rowHeight {
                // Move this row to the top
                let totalHeight = rowHeight * CGFloat(waterRows.count)
                row.position.y += totalHeight
            }
        }
    }
    
    func reset() {
        scrollOffset = 0
        currentScrollSpeed = GameConfig.scrollSpeed
        worldNode.removeAllChildren()
        waterRows.removeAll()
        guard let scene = scene else { return }
        createWaterBackground(sceneSize: scene.size)
    }
}
