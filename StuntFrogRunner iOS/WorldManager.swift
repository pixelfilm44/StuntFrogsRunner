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

        // Make the shader once and reuse across tiles
        let waterShader = makeWaterFlowShader()

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

                // Apply the water shader for ripples and gentle distortion/flow
                tile.shader = waterShader

                // Flow horizontally (perpendicular to vertical scroll)
                let dir = vector_float2(1.0, 0.0)
                tile.setValue(SKAttributeValue(vectorFloat2: dir), forAttribute: "a_flowDir")

                // Slight per-tile movement using actions to avoid uniform-heavy work
                // Very gentle horizontal drift with phase based on row/col
                let base = Double(rowIndex + colIndex)
                let phase = (base.truncatingRemainder(dividingBy: 4.0)) * 0.25
                let driftDistance: CGFloat = 6.0
                let driftDuration: TimeInterval = 6.0
                let left = SKAction.moveBy(x: -driftDistance, y: 0, duration: driftDuration)
                let right = SKAction.moveBy(x: driftDistance, y: 0, duration: driftDuration)
                left.timingMode = .easeInEaseOut
                right.timingMode = .easeInEaseOut
                let drift = SKAction.sequence([left, right])
                let driftForever = SKAction.repeatForever(drift)
                let wait = SKAction.wait(forDuration: phase * driftDuration)
                tile.run(SKAction.sequence([wait, driftForever]))

                rowNode.addChild(tile)
            }

            // Center grid horizontally in scene coordinates
            rowNode.position.x = sceneSize.width / 2.0
            worldNode.addChild(rowNode)
            waterRows.append(rowNode)
        }

        // Initialize shader position uniforms once after nodes are added
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
        uniform sampler2D u_texture;
        uniform float u_time;
        uniform float u_speed;
        attribute vec2 a_flowDir;
        
        // Water effect parameters
        uniform float u_distort_amplitude;
        uniform float u_distort_frequency;
        uniform float u_distort_speed;
        
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
        
        // Simple 2D Noise function (e.g., hash-based) - critical for organic movement
        // Returns a pseudo-random value between 0.0 and 1.0
        float random(vec2 p) {
            return fract(sin(dot(p.xy ,vec2(12.9898,78.233))) * 43758.5453);
        }
        
        // Simple Perlin-like 2D Noise (Smoother interpolation)
        float noise(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            
            // Smoothstep interpolation
            vec2 u = f*f*(3.0-2.0*f);
            
            float a = random(i);
            float b = random(i + vec2(1.0, 0.0));
            float c = random(i + vec2(0.0, 1.0));
            float d = random(i + vec2(1.0, 1.0));
            
            return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
        }
        
        // Fractal Brownian Motion (FBM) - combines multiple noise layers
        float fbm(vec2 p) {
            float f = 0.0;
            f += 0.5   * noise(p); 
            f += 0.25  * noise(p * 2.0); // Higher frequency
            f += 0.125 * noise(p * 4.0); // Even higher frequency
            return f / (0.5 + 0.25 + 0.125); // Normalize
        }
        
        // Ripple Calculation (same as before, but ensuring it's used)
        float calculateRipple(vec2 worldPos, vec2 ripplePos, float age, float amplitude, float frequency) {
            if (amplitude < 0.001 || age > RIPPLE_LIFETIME) return 0.0;
            float dist = distance(worldPos, ripplePos);
            float wave = (dist / 50.0) * frequency - age * RIPPLE_SPEED;
            float fade = 1.0 - (age / RIPPLE_LIFETIME);
            fade = fade * fade;
            float distFade = 1.0 / (1.0 + dist / 150.0); 
            return cos(wave) * amplitude * fade * distFade; 
        }
        
        // Helper to retrieve ripple data at a specific index
        float getRippleDataValue(int index, vec3 v1, vec3 v2, vec3 v3, vec3 v4) {
            if (index == 0) return v1.x;
            if (index == 1) return v1.y;
            if (index == 2) return v1.z;
            if (index == 3) return v2.x;
            if (index == 4) return v2.y;
            if (index == 5) return v2.z;
            if (index == 6) return v3.x;
            if (index == 7) return v3.y;
            if (index == 8) return v3.z;
            if (index == 9) return v4.x;
            if (index == 10) return v4.y;
            if (index == 11) return v4.z;
            return 0.0;
        }
        
        void main() {
            // Pixel position in Scene/View coordinates (normalized to 0-1)
            vec2 normalizedScenePos = gl_FragCoord.xy / sk_ViewSize.xy;
            // Pixel position in Screen space (pixels)
            vec2 scenePos = gl_FragCoord.xy;
            
            // 1. Calculate Base Water Movement (FBM Distortion)
            // Adjust coordinate space for FBM to be world-scaled for continuity
            vec2 noiseCoords = normalizedScenePos * u_distort_frequency + u_time * u_distort_speed;
            
            // Use two different layers of FBM for richer, more organic movement
            float distortionX = fbm(noiseCoords * 0.7 + vec2(100.0, 0.0)) * u_distort_amplitude;
            float distortionY = fbm(noiseCoords * 1.2) * u_distort_amplitude * 0.5; // Less vertical distortion
            
            // 2. Calculate Total Ripple Distortion
            float totalRippleOffset = 0.0;
            for (int i = 0; i < 12; i++) {
                vec2 ripplePos = vec2(
                    getRippleDataValue(i, u_ripple_x, u_ripple_x2, u_ripple_x3, u_ripple_x4),
                    getRippleDataValue(i, u_ripple_y, u_ripple_y2, u_ripple_y3, u_ripple_y4)
                );
                float age = getRippleDataValue(i, u_ripple_age, u_ripple_age2, u_ripple_age3, u_ripple_age4);
                float amplitude = getRippleDataValue(i, u_ripple_amp, u_ripple_amp2, u_ripple_amp3, u_ripple_amp4);
                float frequency = getRippleDataValue(i, u_ripple_freq, u_ripple_freq2, u_ripple_freq3, u_ripple_freq4);
                
                totalRippleOffset += calculateRipple(scenePos, ripplePos, age, amplitude, frequency);
            }
            
            // 3. Apply Distortion to UVs
            vec2 uv = v_tex_coord;
            
            // Basic Flow/Scroll
            uv += a_flowDir * u_time * u_speed;
            
            // Add ambient FBM and ripple distortion to the UV coordinates
            uv.x += distortionX + totalRippleOffset;
            uv.y += distortionY + totalRippleOffset * 0.5;
            
            // Wrap UV coordinates for seamless tiling
            uv = fract(uv);
            
            // 4. Sample Texture and Apply Water Color/Depth
            vec4 baseColor = texture2D(u_texture, uv);
            
            // Simulate "depth" or "shading" by slightly darkening/brightening based on distortion
            // The water looks darker (deeper) where the distortion is lower (valleys)
            float lightIntensity = (distortionX + distortionY) * 3.0 + 1.0; 
            
            // Apply final color
            gl_FragColor = baseColor * lightIntensity;
        }
        """
        
        let shader = SKShader(source: source)
        shader.addUniform(SKUniform(name: "u_time", float: 0.0))
        shader.addUniform(SKUniform(name: "u_speed", float: 0.02))  // Slower flow for pond water
        
        // NEW: Realistic subtle distortion parameters
        shader.addUniform(SKUniform(name: "u_distort_amplitude", float: 0.015)) // Higher amplitude for visible waves
        shader.addUniform(SKUniform(name: "u_distort_frequency", float: 2.0)) // Noise frequency (smaller number = larger waves)
        shader.addUniform(SKUniform(name: "u_distort_speed", float: 0.05)) // Slow, gentle movement
        // ... (All ripple uniforms remain the same) ...
        
        return shader
    }
    
    // MARK: - Update and Scrolling
    func updateScrolling(isJumping: Bool) -> Int {
        let currentTime = CACurrentMediaTime()
        let deltaTime = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime
        rippleManager.update(deltaTime: deltaTime)
        
        guard isJumping else {
            // No auto-scroll when grounded
            // Keep ripple and shader updates active for animated water visuals
            recycleWaterRows()
            updateWaterShaderTime()
            updateWaterRipples()
            return 0
        }
        
        // No auto-scroll during jumping either
        // Keep ripple and shader updates active for animated water visuals
        recycleWaterRows()
        updateWaterShaderTime()
        updateWaterRipples()
        return 0
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

