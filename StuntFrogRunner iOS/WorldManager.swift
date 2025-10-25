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
    private let waterTextureName = "water" // "water.png" in assets
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
    
    // MARK: - Water Background (Grid of Sprites with Shader Flow and Ripples)
    func createWaterBackground(sceneSize: CGSize) {
        guard let texture = SKTexture(imageNamed: waterTextureName).copy() as? SKTexture else {
            createProceduralFallback(sceneSize: sceneSize)
            return
        }
        
        waterTileSize = texture.size()
        if waterTileSize.width <= 0 || waterTileSize.height <= 0 {
            createProceduralFallback(sceneSize: sceneSize)
            return
        }
        
        let tileH = waterTileSize.height
        let tileW = waterTileSize.width
        
        let rowsNeeded = Int(ceil(sceneSize.height / tileH)) + rowOverlap
        let colsNeeded = Int(ceil(sceneSize.width / tileW)) + colOverlap
        
        // Start water tiling lower to avoid overlap with frog start area
        let verticalStartOffset: CGFloat = 260
        
        let waterShader = makeWaterFlowShader()
        
        waterRows.removeAll()
        
        for rowIndex in 0..<rowsNeeded {
            let rowNode = SKNode()
            rowNode.name = "waterRow"
            rowNode.zPosition = -50
            
            let rowY = CGFloat(rowIndex) * tileH + tileH / 2.0 - verticalStartOffset
            rowNode.position = CGPoint(x: 0, y: rowY)
            
            for colIndex in 0..<colsNeeded {
                let sprite = SKSpriteNode(texture: texture)
                
                // Alternate flip horizontally to better match seams
                // Flip when (rowIndex + colIndex) is odd
                if ((rowIndex + colIndex) % 2) == 1 {
                    sprite.xScale = -1.0
                }
                
                sprite.size = waterTileSize
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                
                let startX = -sceneSize.width / 2.0 - (CGFloat(colOverlap) * tileW / 2.0) + tileW / 2.0
                let x = startX + CGFloat(colIndex) * tileW
                sprite.position = CGPoint(x: x, y: 0)
                
                sprite.shader = waterShader
                // Flow horizontally (perpendicular to vertical scroll) to avoid cancellation
                let dir = vector_float2(1.0, 0.0)
                sprite.setValue(SKAttributeValue(vectorFloat2: dir), forAttribute: "a_flowDir")
                
                rowNode.addChild(sprite)
            }
            
            rowNode.position.x = sceneSize.width / 2.0
            worldNode.addChild(rowNode)
            waterRows.append(rowNode)
        }
        
        // Update initial sprite positions after all rows are added
        if let scene = scene {
            for row in waterRows {
                for case let sprite as SKSpriteNode in row.children {
                    let spriteScenePos = scene.convert(sprite.position, from: sprite.parent!)
                    sprite.shader?.uniformNamed("u_sprite_position")?.vectorFloat2Value = vector_float2(Float(spriteScenePos.x), Float(spriteScenePos.y))
                }
            }
        }
        
        waterFlowStartTime = CACurrentMediaTime()
    }
    
    private func makeWaterFlowShader() -> SKShader {
        let source = """
        varying vec2 v_tex_coord;
        uniform float u_time;
        uniform float u_speed;
        attribute vec2 a_flowDir;
        
        // Sprite world position and size (for coordinate conversion)
        uniform vec2 u_sprite_position;
        uniform vec2 u_sprite_size;
        
        // Wave effect parameters
        uniform float u_wave_amplitude;
        uniform float u_wave_frequency;
        uniform float u_wave_speed;
        
        // Ripple positions (in scene coordinates)
        uniform vec3 u_ripple_x;
        uniform vec3 u_ripple_x2;
        uniform vec3 u_ripple_x3;
        uniform vec3 u_ripple_x4;
        
        uniform vec3 u_ripple_y;
        uniform vec3 u_ripple_y2;
        uniform vec3 u_ripple_y3;
        uniform vec3 u_ripple_y4;
        
        // Ripple amplitudes
        uniform vec3 u_ripple_amp;
        uniform vec3 u_ripple_amp2;
        uniform vec3 u_ripple_amp3;
        uniform vec3 u_ripple_amp4;
        
        // Ripple ages
        uniform vec3 u_ripple_age;
        uniform vec3 u_ripple_age2;
        uniform vec3 u_ripple_age3;
        uniform vec3 u_ripple_age4;
        
        // Ripple frequencies
        uniform vec3 u_ripple_freq;
        uniform vec3 u_ripple_freq2;
        uniform vec3 u_ripple_freq3;
        uniform vec3 u_ripple_freq4;
        
        const float RIPPLE_SPEED = 0.8;
        const float RIPPLE_LIFETIME = 2.0;
        
        float calculateRipple(vec2 worldPos, vec2 ripplePos, float age, float amplitude, float frequency) {
            if (amplitude < 0.001 || age > RIPPLE_LIFETIME) return 0.0;
            
            // Calculate distance in world space (pixels)
            float dist = distance(worldPos, ripplePos);
            
            // Scale distance for frequency (convert to reasonable wave units)
            float wave = (dist / 50.0) * frequency - age * RIPPLE_SPEED;
            
            // Fade out over lifetime
            float fade = 1.0 - (age / RIPPLE_LIFETIME);
            fade = fade * fade;
            
            // Attenuate with distance (in pixels)
            float distFade = 1.0 / (1.0 + dist / 100.0);
            
            return sin(wave) * amplitude * fade * distFade;
        }
        
        void main() {
            vec2 dir = normalize(a_flowDir);
            vec2 uv = v_tex_coord + dir * (u_time * u_speed);
            
            // Calculate world position of current pixel
            // Sprite position is at center, texture coords are 0-1 with (0.5, 0.5) at center
            vec2 offsetFromCenter = (v_tex_coord - vec2(0.5, 0.5)) * u_sprite_size;
            vec2 worldPos = u_sprite_position + offsetFromCenter;
            
            // Apply dynamic wave distortion for visible water movement
            // Use world position to create continuous wave pattern across tiles
            float waveTime = u_time * u_wave_speed;
            
            // Create multiple overlapping wave patterns for complex, visible movement
            // Primary wave: diagonal sweeping pattern
            float wave1 = sin(worldPos.x * u_wave_frequency + waveTime) + 
                          cos(worldPos.y * u_wave_frequency - waveTime * 0.8);
            
            // Secondary wave: opposing diagonal with different speed
            float wave2 = cos(worldPos.x * u_wave_frequency * 0.7 - waveTime * 1.2) + 
                          sin(worldPos.y * u_wave_frequency * 0.8 + waveTime);
            
            // Tertiary wave: circular ripple pattern from center
            float distFromCenter = length(worldPos * u_wave_frequency * 0.001);
            float wave3 = sin(distFromCenter * 10.0 - waveTime * 1.5);
            
            // Combine waves with different directions for natural, visible water movement
            vec2 waveOffset = vec2(
                wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2,
                wave2 * 0.5 + wave1 * 0.3 + wave3 * 0.2
            ) * u_wave_amplitude;
            uv += waveOffset;
            
            // Add animated color/brightness variation for more visible movement
            float colorWave = sin(waveTime * 0.8 + worldPos.x * 0.002 + worldPos.y * 0.002) * 0.5 + 0.5;
            float brightnessModulation = 0.97 + colorWave * 0.06; // Subtle brightness pulse
            
            float rippleDisplacement = 0.0;
            
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x.x, u_ripple_y.x), u_ripple_age.x, u_ripple_amp.x, u_ripple_freq.x);
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x.y, u_ripple_y.y), u_ripple_age.y, u_ripple_amp.y, u_ripple_freq.y);
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x.z, u_ripple_y.z), u_ripple_age.z, u_ripple_amp.z, u_ripple_freq.z);
            
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x2.x, u_ripple_y2.x), u_ripple_age2.x, u_ripple_amp2.x, u_ripple_freq2.x);
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x2.y, u_ripple_y2.y), u_ripple_age2.y, u_ripple_amp2.y, u_ripple_freq2.y);
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x2.z, u_ripple_y2.z), u_ripple_age2.z, u_ripple_amp2.z, u_ripple_freq2.z);
            
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x3.x, u_ripple_y3.x), u_ripple_age3.x, u_ripple_amp3.x, u_ripple_freq3.x);
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x3.y, u_ripple_y3.y), u_ripple_age3.y, u_ripple_amp3.y, u_ripple_freq3.y);
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x3.z, u_ripple_y3.z), u_ripple_age3.z, u_ripple_amp3.z, u_ripple_freq3.z);
            
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x4.x, u_ripple_y4.x), u_ripple_age4.x, u_ripple_amp4.x, u_ripple_freq4.x);
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x4.y, u_ripple_y4.y), u_ripple_age4.y, u_ripple_amp4.y, u_ripple_freq4.y);
            rippleDisplacement += calculateRipple(worldPos, vec2(u_ripple_x4.z, u_ripple_y4.z), u_ripple_age4.z, u_ripple_amp4.z, u_ripple_freq4.z);
            
            vec2 rippleOffset = dir * rippleDisplacement;
            uv += rippleOffset;
            uv = fract(uv);
            
            vec4 texColor = texture2D(u_texture, uv);
            gl_FragColor = texColor * brightnessModulation * v_color_mix.a + v_color_mix.rgba;
        }
        """
        
        let shader = SKShader(source: source)
        shader.addUniform(SKUniform(name: "u_time", float: 0.0))
        shader.addUniform(SKUniform(name: "u_speed", float: Float(waterFlowSpeed)))
        
        // Add wave effect uniforms for dynamic wavy appearance
        shader.addUniform(SKUniform(name: "u_wave_amplitude", float: 0.020))  // Balanced wave distortion for visible movement without breaking seams
        shader.addUniform(SKUniform(name: "u_wave_frequency", float: 0.03))   // Large, clearly visible wave patterns
        shader.addUniform(SKUniform(name: "u_wave_speed", float: 3.0))        // Fast, obvious animation
        
        // Add placeholder uniforms for sprite position/size (will be set per sprite)
        shader.addUniform(SKUniform(name: "u_sprite_position", vectorFloat2: vector_float2(0, 0)))
        shader.addUniform(SKUniform(name: "u_sprite_size", vectorFloat2: vector_float2(Float(waterTileSize.width), Float(waterTileSize.height))))
        
        let rippleUniforms = rippleManager.getShaderUniforms()
        for uniform in rippleUniforms {
            shader.addUniform(uniform)
        }
        
        shader.attributes = [
            SKAttribute(name: "a_flowDir", type: .vectorFloat2)
        ]
        
        return shader
    }
    
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
        let currentTime = CACurrentMediaTime()
        let deltaTime = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime
        rippleManager.update(deltaTime: deltaTime)
        
        guard isJumping else {
            // Allow gentle drift when grounded instead of stopping completely
            // Ensure drift respects a hard minimum
            currentScrollSpeed = max(GameConfig.minScrollSpeed, GameConfig.driftScrollSpeed)
            worldNode.position.y -= currentScrollSpeed
            scrollOffset += currentScrollSpeed

            recycleWaterRows()
            updateWaterShaderTime()
            updateWaterRipples()

            // Optionally award a tiny score drip based on drift speed
            return Int(currentScrollSpeed)
        }
        
        currentScrollSpeed = GameConfig.scrollSpeedWhileJumping
        worldNode.position.y -= currentScrollSpeed
        scrollOffset += currentScrollSpeed
        
        recycleWaterRows()
        updateWaterShaderTime()
        updateWaterRipples()
        
        return Int(currentScrollSpeed * 2)
    }
    
    private func updateWaterShaderTime() {
        guard let scene = scene else { return }
        let t = Float(CACurrentMediaTime() - waterFlowStartTime)
        
        for (index, row) in waterRows.enumerated() {
            // Add very gentle alpha pulsing to each row with phase offset
            let rowPhase = CGFloat(t) * 0.5 + CGFloat(index) * 0.5
            let alphaModulation = 0.96 + sin(rowPhase) * 0.04
            row.alpha = alphaModulation
            
            for case let sprite as SKSpriteNode in row.children {
                // Update time uniform
                sprite.shader?.uniformNamed("u_time")?.floatValue = t
                
                // Convert sprite position to scene coordinates
                let spriteScenePos = scene.convert(sprite.position, from: sprite.parent!)
                sprite.shader?.uniformNamed("u_sprite_position")?.vectorFloat2Value = vector_float2(Float(spriteScenePos.x), Float(spriteScenePos.y))
                
                // Keep scale at 1.0 to maintain seamless tiling
                sprite.setScale(1.0)
            }
        }
    }
    
    private func updateWaterRipples() {
        guard let scene = scene else { return }
        
        // Get ripple data in world coordinates
        let worldRipples = rippleManager.getRipplePositions()
        
        // Convert to scene coordinates for shader
        var sceneRippleX: [Float] = []
        var sceneRippleY: [Float] = []
        
        for worldPos in worldRipples {
            let scenePos = scene.convert(worldPos, from: worldNode)
            sceneRippleX.append(Float(scenePos.x))
            sceneRippleY.append(Float(scenePos.y))
        }
        
        // Get other ripple data (amplitudes, ages, frequencies)
        let rippleData = rippleManager.getRippleData()
        
        // Update all water sprites with converted positions
        for row in waterRows {
            for case let sprite as SKSpriteNode in row.children {
                guard let shader = sprite.shader else { continue }
                
                // Update position uniforms with scene coordinates (using vector_float3/SIMD3)
                shader.uniformNamed("u_ripple_x")?.vectorFloat3Value = vector_float3(sceneRippleX[0], sceneRippleX[1], sceneRippleX[2])
                shader.uniformNamed("u_ripple_x2")?.vectorFloat3Value = vector_float3(sceneRippleX[3], sceneRippleX[4], sceneRippleX[5])
                shader.uniformNamed("u_ripple_x3")?.vectorFloat3Value = vector_float3(sceneRippleX[6], sceneRippleX[7], sceneRippleX[8])
                shader.uniformNamed("u_ripple_x4")?.vectorFloat3Value = vector_float3(sceneRippleX[9], sceneRippleX[10], sceneRippleX[11])
                
                shader.uniformNamed("u_ripple_y")?.vectorFloat3Value = vector_float3(sceneRippleY[0], sceneRippleY[1], sceneRippleY[2])
                shader.uniformNamed("u_ripple_y2")?.vectorFloat3Value = vector_float3(sceneRippleY[3], sceneRippleY[4], sceneRippleY[5])
                shader.uniformNamed("u_ripple_y3")?.vectorFloat3Value = vector_float3(sceneRippleY[6], sceneRippleY[7], sceneRippleY[8])
                shader.uniformNamed("u_ripple_y4")?.vectorFloat3Value = vector_float3(sceneRippleY[9], sceneRippleY[10], sceneRippleY[11])
                
                // Update amplitudes
                shader.uniformNamed("u_ripple_amp")?.vectorFloat3Value = rippleData.amplitudes[0]
                shader.uniformNamed("u_ripple_amp2")?.vectorFloat3Value = rippleData.amplitudes[1]
                shader.uniformNamed("u_ripple_amp3")?.vectorFloat3Value = rippleData.amplitudes[2]
                shader.uniformNamed("u_ripple_amp4")?.vectorFloat3Value = rippleData.amplitudes[3]
                
                // Update ages
                shader.uniformNamed("u_ripple_age")?.vectorFloat3Value = rippleData.ages[0]
                shader.uniformNamed("u_ripple_age2")?.vectorFloat3Value = rippleData.ages[1]
                shader.uniformNamed("u_ripple_age3")?.vectorFloat3Value = rippleData.ages[2]
                shader.uniformNamed("u_ripple_age4")?.vectorFloat3Value = rippleData.ages[3]
                
                // Update frequencies
                shader.uniformNamed("u_ripple_freq")?.vectorFloat3Value = rippleData.frequencies[0]
                shader.uniformNamed("u_ripple_freq2")?.vectorFloat3Value = rippleData.frequencies[1]
                shader.uniformNamed("u_ripple_freq3")?.vectorFloat3Value = rippleData.frequencies[2]
                shader.uniformNamed("u_ripple_freq4")?.vectorFloat3Value = rippleData.frequencies[3]
            }
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
