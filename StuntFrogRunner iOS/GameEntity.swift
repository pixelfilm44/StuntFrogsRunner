import SpriteKit

// MARK: - Z-Position Constants
struct Layer {
    static let water: CGFloat = 0
    static let pad: CGFloat = 10
    static let shadow: CGFloat = 15
    static let item: CGFloat = 20 // Coins, Enemies
    static let frog: CGFloat = 30
    static let trajectory: CGFloat = 50
    static let ui: CGFloat = 1000
}

enum RocketState {
    case none
    case flying
    case landing
}

enum FrogAnimationState {
    case sitting
    case leaping     // Beginning of jump / end of jump
    case jumping     // Midway through jump (peak)
}

// MARK: - Base Entity
class GameEntity: SKSpriteNode {
    var velocity: CGVector = .zero
    var zHeight: CGFloat = 0.0
    var zVelocity: CGFloat = 0.0
    
    func constrainToRiver() {
        if position.x < Configuration.Dimensions.frogRadius {
            position.x = Configuration.Dimensions.frogRadius
            velocity.dx *= -0.6
        } else if position.x > Configuration.Dimensions.riverWidth - Configuration.Dimensions.frogRadius {
            position.x = Configuration.Dimensions.riverWidth - Configuration.Dimensions.frogRadius
            velocity.dx *= -0.6
        }
    }
}

// MARK: - The Frog
class Frog: GameEntity {
    
    struct Buffs {
        var honey: Int = 0
        var rocketTimer: Int = 0
        var bootsCount: Int = 0
        var vest: Int = 0
        var axe: Int = 0
        var swatter: Int = 0
        var cross: Int = 0
        var superJumpTimer: Int = 0
    }
    
    var buffs = Buffs()
    
    var rocketState: RocketState = .none
    var rocketTimer: Int = 0
    var landingTimer: Int = 0
    
    var maxHealth: Int = 3
    var currentHealth: Int = 3
    var isInvincible: Bool = false
    var invincibilityTimer: Int = 0
    
    var onPad: Pad?
    var isFloating: Bool = false
    var isWearingBoots: Bool = false
    
    // FIX: Re-added missing property
    var canJumpLogs: Bool = false
    
    var isSuperJumping: Bool { return buffs.superJumpTimer > 0 }
    
    private var isBeingDragged: Bool = false
    
    // Animation state
    private(set) var animationState: FrogAnimationState = .sitting
    private var jumpStartZVelocity: CGFloat = 0  // Track initial jump velocity for phase transitions
    private var lastFacingAngle: CGFloat = 0     // Preserve facing direction
    
    // Visual nodes
    let bodyNode = SKNode()  // Container for the sprite
    private let frogSprite = SKSpriteNode()
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: 40, height: 20))
    private let vestNode = SKShapeNode(circleOfRadius: 22)
    private let superAura = SKShapeNode(circleOfRadius: 28)
    private let rocketSprite = SKSpriteNode(imageNamed: "rocketRide")
    
    // Preloaded textures for performance
    private static let sitTexture = SKTexture(imageNamed: "frogSit")
    private static let leapTexture = SKTexture(imageNamed: "frogLeap")
    private static let jumpTexture = SKTexture(imageNamed: "frogJump")
    
    // Target height for frog sprite (aspect ratio preserved automatically)
    private static let frogTargetHeight: CGFloat = 40
    
    /// Sets the frog sprite texture while preserving the image's aspect ratio
    private func setFrogTexture(_ texture: SKTexture) {
        frogSprite.texture = texture
        let textureSize = texture.size()
        let aspectRatio = textureSize.width / textureSize.height
        frogSprite.size = CGSize(width: Frog.frogTargetHeight * aspectRatio, height: Frog.frogTargetHeight)
    }
    
    init() {
        super.init(texture: nil, color: .clear, size: CGSize(width: 40, height: 40))
        self.zPosition = Layer.frog
        setupNodes()
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    
    private func setupNodes() {
        shadowNode.fillColor = .black.withAlphaComponent(0.3)
        shadowNode.strokeColor = .clear
        shadowNode.zPosition = -1
        addChild(shadowNode)
        
        superAura.fillColor = .clear
        superAura.strokeColor = .cyan
        superAura.lineWidth = 4
        superAura.zPosition = 0
        superAura.isHidden = true
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
        superAura.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))
        addChild(superAura)
        
        bodyNode.zPosition = 1
        addChild(bodyNode)
        
        // Setup rocket sprite (hidden by default, shown during rocket ride)
        // Use aspect-fit sizing to preserve image ratio
        let rocketTexture = rocketSprite.texture ?? SKTexture(imageNamed: "rocketRide")
        let rocketTextureSize = rocketTexture.size()
        let rocketTargetHeight: CGFloat = 60
        let rocketAspectRatio = rocketTextureSize.width / rocketTextureSize.height
        rocketSprite.size = CGSize(width: rocketTargetHeight * rocketAspectRatio, height: rocketTargetHeight)
        rocketSprite.position = CGPoint(x: 0, y: -30)  // Position below the frog
        rocketSprite.zPosition = -1  // Behind the frog sprite
        rocketSprite.isHidden = true
        bodyNode.addChild(rocketSprite)
        
        // Setup frog sprite with initial sitting texture
        // Use aspect-fit sizing to preserve image ratio
        setFrogTexture(Frog.sitTexture)
        bodyNode.addChild(frogSprite)
        
        vestNode.strokeColor = .orange
        vestNode.lineWidth = 4
        vestNode.fillColor = .clear
        vestNode.isHidden = true
        bodyNode.addChild(vestNode)
    }
    
    func update(dt: TimeInterval, weather: WeatherType) {
        if buffs.rocketTimer > 0 { buffs.rocketTimer -= 1 }
        if buffs.superJumpTimer > 0 { buffs.superJumpTimer -= 1 }
        
        if invincibilityTimer > 0 {
            invincibilityTimer -= 1
            isInvincible = true
        } else if isSuperJumping {
            isInvincible = true
        } else {
            isInvincible = false
        }
        
        vestNode.isHidden = (buffs.vest == 0)
        
        if rocketState != .none {
            updateRocketPhysics()
            updateVisuals()
            return
        }
        
        position.x += velocity.dx
        position.y += velocity.dy
        zHeight += zVelocity
        
        if zHeight > 0 {
            zVelocity -= Configuration.Physics.gravityZ
            velocity.dx *= Configuration.Physics.frictionAir
            velocity.dy *= Configuration.Physics.frictionAir
        } else {
            zHeight = 0
            if isFloating {
                velocity.dx *= 0.9
                velocity.dy *= 0.9
            } else {
                var currentFriction = Configuration.Physics.frictionGround
                if let pad = onPad {
                    if pad.type == .moving || pad.type == .waterLily || pad.type == .log {
                        position.x += pad.moveSpeed * pad.moveDirection
                    }
                    let isRain = (weather == .rain)
                    let isIce = (pad.type == .ice)
                    if (isRain || isIce) && !isWearingBoots {
                        currentFriction = 0.94
                    }
                }
                velocity.dx *= currentFriction
                velocity.dy *= currentFriction
            }
        }
        
        constrainToRiver()
        updateVisuals()
    }
    
    func descend() {
        rocketState = .none
        rocketTimer = 0
        landingTimer = 0
        velocity.dx = 0
        velocity.dy = 0
        zVelocity = -25.0
    }
    
    func hit() {
        invincibilityTimer = 120
        isInvincible = true
    }
    
    func setPullOffset(_ offset: CGPoint) {
        isBeingDragged = true
        let maxVisualStretch = Configuration.Physics.maxDragDistance
        let dist = sqrt(offset.x*offset.x + offset.y*offset.y)
        var visualVector = offset
        if dist > maxVisualStretch {
            let ratio = maxVisualStretch / dist
            visualVector.x *= ratio
            visualVector.y *= ratio
        }
        bodyNode.position = .zero
        shadowNode.position = .zero
        
        // Point in the direction the frog will jump (opposite of drag)
        let angle = atan2(-offset.y, -offset.x) - CGFloat.pi / 2
        bodyNode.zRotation = angle
        lastFacingAngle = angle  // Store for when drag ends
    }
    
    func resetPullOffset() {
        isBeingDragged = false
        bodyNode.position = CGPoint(x: 0, y: zHeight)
        shadowNode.position = .zero
        bodyNode.zRotation = lastFacingAngle  // Preserve last facing direction
    }
    
    private func updateRocketPhysics() {
        position.x += velocity.dx
        velocity.dx *= 0.9
        
        if rocketState == .flying {
            rocketTimer -= 1
            velocity.dy = 4.0
            position.y += velocity.dy
            zHeight += (60 - zHeight) * 0.1
            
            if rocketTimer <= 0 {
                rocketState = .landing
                landingTimer = Int(Configuration.GameRules.rocketLandingDuration * 60)
            }
        } else if rocketState == .landing {
            landingTimer -= 1
            if landingTimer <= 0 {
                descend()
                return
            }
            velocity.dy *= 0.95
            if velocity.dy < 0.5 { velocity.dy = 0.5 }
            position.y += velocity.dy
            zHeight = 60 + sin(CGFloat(Date().timeIntervalSince1970) * 5) * 5
        }
        constrainToRiver()
    }
    
    private func updateVisuals() {
        if !isBeingDragged {
            bodyNode.position.y = zHeight
            
            // Update facing direction based on movement
            let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
            if speed > 0.5 {
                // Calculate angle from velocity vector and store it
                lastFacingAngle = atan2(velocity.dy, velocity.dx) - CGFloat.pi / 2
                bodyNode.zRotation = lastFacingAngle
            } else {
                // Keep facing the last direction when stationary
                bodyNode.zRotation = lastFacingAngle
            }
            
            let scale = 1.0 + (zHeight / 100.0)
            bodyNode.setScale(scale)
        }
        
        let shadowScale = max(0, 1.0 - (zHeight / 200.0))
        shadowNode.setScale(shadowScale)
        shadowNode.alpha = 0.3 * shadowScale
        
        // Show/hide rocket during rocket ride
        rocketSprite.isHidden = (rocketState == .none)
        
        // Update animation state based on jump phase
        updateAnimationState()
        
        if isSuperJumping {
            superAura.isHidden = false
            superAura.position.y = bodyNode.position.y
            frogSprite.colorBlendFactor = 0.5
            frogSprite.color = .cyan
            frogSprite.alpha = 1.0
        } else {
            superAura.isHidden = true
            frogSprite.colorBlendFactor = 0.0
            
            if invincibilityTimer > 0 {
                let flash = (invincibilityTimer / 10) % 2 == 0
                frogSprite.alpha = flash ? 0.5 : 1.0
            } else {
                frogSprite.alpha = 1.0
            }
        }
    }
    
    private func updateAnimationState() {
        let newState: FrogAnimationState
        
        // Calculate horizontal speed
        let horizontalSpeed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        
        // Determine animation state based on jump phase and movement
        if zHeight <= 0.1 && abs(zVelocity) < 0.1 {
            // On ground / lilypad - use sitting if idle, leaping if sliding
            if horizontalSpeed < 0.5 {
                newState = .sitting
            } else {
                // Sliding on ice or moving - still show sitting pose when grounded
                newState = .sitting
            }
        } else if zVelocity > jumpStartZVelocity * 0.3 {
            // Rising phase - just started jumping (first ~30% of upward velocity)
            newState = .leaping
        } else if zVelocity > -jumpStartZVelocity * 0.3 {
            // Peak phase - midway through jump
            newState = .jumping
        } else {
            // Falling phase - about to land
            newState = .leaping
        }
        
        // Only update texture if state changed (performance optimization)
        if newState != animationState {
            animationState = newState
            
            switch animationState {
            case .sitting:
                setFrogTexture(Frog.sitTexture)
            case .leaping:
                setFrogTexture(Frog.leapTexture)
            case .jumping:
                setFrogTexture(Frog.jumpTexture)
            }
        }
    }
    
    func jump(vector: CGVector, intensity: CGFloat) {
        resetPullOffset()
        
        var finalVector = vector
        if buffs.superJumpTimer > 0 {
            finalVector.dx *= 2.0
            finalVector.dy *= 2.0
        }
        
        self.velocity = finalVector
        self.zVelocity = Configuration.Physics.baseJumpZ * (0.5 + (intensity * 0.5))
        self.jumpStartZVelocity = self.zVelocity  // Track for animation phase calculation
        self.onPad = nil
        self.isFloating = false
        
        // Immediately transition to leaping state
        animationState = .leaping
        setFrogTexture(Frog.leapTexture)
        
        SoundManager.shared.play("jump")
        HapticsManager.shared.playImpact(.light)
    }
    
    func land(on pad: Pad, weather: WeatherType) {
        zVelocity = 0
        zHeight = 0
        jumpStartZVelocity = 0  // Reset for next jump
        self.onPad = pad
        self.isFloating = false
        resetPullOffset()
        
        // Transition to sitting state
        animationState = .sitting
        setFrogTexture(Frog.sitTexture)
        
        let isRain = (weather == .rain)
        let isIce = (pad.type == .ice)
        
        if (isRain || isIce) && !isWearingBoots {
            velocity.dx *= 0.5
            velocity.dy *= 0.5
        } else {
            velocity = .zero
            if pad.type != .log {
                let dx = pad.position.x - position.x
                let dy = pad.position.y - position.y
                position.x += dx * 0.1
                position.y += dy * 0.1
            }
        }
        SoundManager.shared.play("land")
    }
    
    func bounce() {
        zVelocity = 15.0
        jumpStartZVelocity = zVelocity  // Track for animation phases
        velocity.dx *= -0.5
        velocity.dy *= -0.5
        
        // Transition to leaping state since we're bouncing up
        animationState = .leaping
        setFrogTexture(Frog.leapTexture)
        
        HapticsManager.shared.playImpact(.heavy)
    }
}

// MARK: - Pad / Enemy / Coin (Unchanged)
class Pad: GameEntity {
    enum PadType { case normal, moving, ice, log, grave, shrinking, waterLily }
    var type: PadType = .normal
    var moveDirection: CGFloat = 1.0
    var moveSpeed: CGFloat = 2.0
    private var padSprite: SKSpriteNode?
    private var shrinkTime: Double = 0
    private var shrinkSpeed: Double = 2.0
    private var currentWeather: WeatherType = .sunny
    
    // Preloaded textures for performance
    private static let dayTexture = SKTexture(imageNamed: "lilypadDay")
    private static let nightTexture = SKTexture(imageNamed: "lilypadNight")
    private static let rainTexture = SKTexture(imageNamed: "lilypadRain")
    private static let iceTexture = SKTexture(imageNamed: "lilypadIce")
    private static let snowTexture = SKTexture(imageNamed: "lilypadSnow")
    private static let graveTexture = SKTexture(imageNamed: "lilypadGrave")
    private static let shrinkTexture = SKTexture(imageNamed: "lilypadShrink")
    private static let waterLilyTexture = SKTexture(imageNamed: "lilypadWater")
    private static let waterLilyNightTexture = SKTexture(imageNamed: "lilypadWaterNight")
    private static let waterLilyRainTexture = SKTexture(imageNamed: "lilypadWaterRain")
    private static let waterLilySnowTexture = SKTexture(imageNamed: "lilypadWaterSnow")
    
    var scaledRadius: CGFloat {
        if type == .log { return 60.0 }
        return 45.0 * xScale
    }
    init(type: PadType, position: CGPoint) {
        let size = (type == .log) ? CGSize(width: 120, height: 40) : CGSize(width: 90, height: 90)
        super.init(texture: nil, color: .clear, size: size)
        self.type = type
        self.position = position
        self.zPosition = Layer.pad
        self.moveDirection = Bool.random() ? 1.0 : -1.0
        if type == .shrinking {
            self.shrinkSpeed = Double.random(in: 1.0...3.0)
            self.shrinkTime = Double.random(in: 0...10.0)
        }
        if type == .waterLily {
            self.moveDirection = 1.0
            self.moveSpeed = 1.5
        }
        setupVisuals()
        if type != .log { self.zRotation = CGFloat.random(in: 0...CGFloat.pi*2) }
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    func setupVisuals() {
        if type == .log {
            let texture = SKTexture(imageNamed: "log")
            let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 120, height: 40))
            addChild(sprite)
        } else if type == .ice {
            // Use ice lilypad texture
            let texture = Pad.iceTexture
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 90, height: 90)
            addChild(sprite)
        } else {
            // Use PNG textures for all other pad types
            let texture: SKTexture
            switch type {
            case .grave:
                texture = Pad.graveTexture
            case .shrinking:
                texture = Pad.shrinkTexture
            case .waterLily:
                texture = Pad.waterLilyTexture
            default:
                texture = Pad.dayTexture
            }
            
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 90, height: 90)
            addChild(sprite)
            self.padSprite = sprite
        }
    }
    func updateColor(weather: WeatherType) {
        guard type == .normal || type == .moving || type == .waterLily else { return }
        currentWeather = weather
        
        let texture: SKTexture
        if type == .waterLily {
            switch weather {
            case .sunny:
                texture = Pad.waterLilyTexture
            case .rain:
                texture = Pad.waterLilyRainTexture
            case .night:
                texture = Pad.waterLilyNightTexture
            case .winter:
                texture = Pad.waterLilySnowTexture
            }
        } else {
            switch weather {
            case .sunny:
                texture = Pad.dayTexture
            case .rain:
                texture = Pad.rainTexture
            case .night:
                texture = Pad.nightTexture
            case .winter:
                texture = Pad.snowTexture
            }
        }
        padSprite?.texture = texture
    }
    func update(dt: TimeInterval) {
        if type == .moving || type == .log || type == .waterLily {
            position.x += moveSpeed * moveDirection
            let limit: CGFloat = (type == .log) ? 60 : 45
            if position.x > Configuration.Dimensions.riverWidth - limit || position.x < limit {
                moveDirection *= -1
            }
        }
        if type == .shrinking {
            shrinkTime += dt
            let s = 0.75 + 0.25 * sin(shrinkTime * shrinkSpeed)
            self.xScale = CGFloat(s)
            self.yScale = CGFloat(s)
        }
    }
}

class Enemy: GameEntity {
    var type: String = "BEE"
    private var originalPosition: CGPoint
    private var angle: CGFloat = 0.0
    
    // Preloaded textures for performance
    private static let beeTexture = SKTexture(imageNamed: "bee")
    private static let dragonflyTexture = SKTexture(imageNamed: "dragonfly")
    
    init(position: CGPoint, type: String = "BEE") {
        self.originalPosition = position
        super.init(texture: nil, color: .clear, size: CGSize(width: 30, height: 30))
        self.position = position
        self.type = type
        self.zHeight = 20
        self.zPosition = Layer.item
        setupVisuals()
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    private func setupVisuals() {
        let shadow = SKShapeNode(circleOfRadius: 10)
        shadow.fillColor = .black.withAlphaComponent(0.2)
        shadow.strokeColor = .clear
        shadow.position.y = -20
        addChild(shadow)
        
        switch type {
        case "DRAGONFLY":
            let sprite = SKSpriteNode(texture: Enemy.dragonflyTexture)
            sprite.size = CGSize(width: 30, height: 30)
            addChild(sprite)
        case "GHOST":
            let body = SKShapeNode(circleOfRadius: 15)
            body.fillColor = UIColor.white.withAlphaComponent(0.7)
            body.strokeColor = .black
            body.lineWidth = 2
            addChild(body)
            let label = SKLabelNode(text: "👻")
            label.verticalAlignmentMode = .center
            label.fontSize = 20
            body.addChild(label)
        default: // BEE
            let sprite = SKSpriteNode(texture: Enemy.beeTexture)
            sprite.size = CGSize(width: 30, height: 30)
            addChild(sprite)
        }
    }
    func update(dt: TimeInterval, target: CGPoint? = nil) {
        if type == "DRAGONFLY" {
            position.y -= 150 * CGFloat(dt)
            position.x = originalPosition.x + sin(angle * 5) * 10
            angle += CGFloat(dt)
        } else if type == "GHOST" {
            guard let target = target else { return }
            let speed: CGFloat = 60.0
            let dx = target.x - position.x
            let dy = target.y - position.y
            let dist = sqrt(dx*dx + dy*dy)
            if dist > 1 {
                position.x += (dx / dist) * speed * CGFloat(dt)
                position.y += (dy / dist) * speed * CGFloat(dt)
            }
        } else {
            let radius: CGFloat = 40.0
            let speed: CGFloat = 3.0
            angle += speed * CGFloat(dt)
            position.x = originalPosition.x + cos(angle) * radius
            position.y = originalPosition.y + sin(angle) * radius
        }
    }
}

class Coin: GameEntity {
    var isCollected = false
    init(position: CGPoint) {
        super.init(texture: nil, color: .clear, size: CGSize(width: 20, height: 20))
        self.position = position
        self.zHeight = 10
        self.zPosition = Layer.item
        let starSprite = SKSpriteNode(imageNamed: "star")
        starSprite.size = CGSize(width: 24, height: 24)
        addChild(starSprite)
        let moveUp = SKAction.moveBy(x: 0, y: 5, duration: 0.5)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = moveUp.reversed()
        run(SKAction.repeatForever(SKAction.sequence([moveUp, moveDown])))
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
}
