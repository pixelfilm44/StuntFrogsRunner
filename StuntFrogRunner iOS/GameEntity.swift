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
    
    // NEW: Log Jumper Ability Flag
    var canJumpLogs: Bool = false
    
    private var isBeingDragged: Bool = false
    
    // Visual nodes
    let bodyNode = SKShapeNode(circleOfRadius: 20)
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: 40, height: 20))
    private let vestNode = SKShapeNode(circleOfRadius: 22)
    
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
        
        bodyNode.fillColor = .green
        bodyNode.strokeColor = .white
        bodyNode.lineWidth = 3
        addChild(bodyNode)
        
        vestNode.strokeColor = .orange
        vestNode.lineWidth = 4
        vestNode.fillColor = .clear
        vestNode.isHidden = true
        bodyNode.addChild(vestNode)
        
        let label = SKLabelNode(text: "🐸")
        label.verticalAlignmentMode = .center
        label.fontSize = 30
        bodyNode.addChild(label)
    }
    
    func update(dt: TimeInterval, weather: WeatherType) {
        if buffs.rocketTimer > 0 { buffs.rocketTimer -= 1 }
        
        if invincibilityTimer > 0 {
            invincibilityTimer -= 1
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
                    // Move with pad
                    if pad.type == .moving || pad.type == .waterLily || pad.type == .log {
                        position.x += pad.moveSpeed * pad.moveDirection
                    }
                    
                    let isRain = (weather == .rain)
                    let isIce = (pad.type == .ice)
                    if (isRain || isIce) && !isWearingBoots {
                        currentFriction = 0.80
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
        // Note: Frog body stays stationary (0,0 relative), logic handled in GameScene drawing
        // but we update rotation here
        let angle = atan2(offset.y, offset.x)
        bodyNode.zRotation = angle - CGFloat.pi / 2
    }
    
    func resetPullOffset() {
        isBeingDragged = false
        bodyNode.position = CGPoint(x: 0, y: zHeight)
        shadowNode.position = .zero
        bodyNode.zRotation = 0
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
            if abs(velocity.dx) > 0.5 {
                let angle = -velocity.dx * 0.05
                bodyNode.zRotation = angle
            } else {
                bodyNode.zRotation = 0
            }
            let scale = 1.0 + (zHeight / 100.0)
            bodyNode.setScale(scale)
        }
        
        let shadowScale = max(0, 1.0 - (zHeight / 200.0))
        shadowNode.setScale(shadowScale)
        shadowNode.alpha = 0.3 * shadowScale
        
        if isInvincible {
            let flash = (invincibilityTimer / 10) % 2 == 0
            bodyNode.alpha = flash ? 0.5 : 1.0
        } else {
            bodyNode.alpha = 1.0
        }
    }
    
    func jump(vector: CGVector, intensity: CGFloat) {
        resetPullOffset()
        self.velocity = vector
        self.zVelocity = Configuration.Physics.baseJumpZ * (0.5 + (intensity * 0.5))
        self.onPad = nil
        self.isFloating = false
        SoundManager.shared.play("jump")
        HapticsManager.shared.playImpact(.light)
    }
    
    func land(on pad: Pad, weather: WeatherType) {
        zVelocity = 0
        zHeight = 0
        self.onPad = pad
        self.isFloating = false
        resetPullOffset()
        
        let isRain = (weather == .rain)
        let isIce = (pad.type == .ice)
        
        if (isRain || isIce) && !isWearingBoots {
            velocity.dx *= 0.5
            velocity.dy *= 0.5
        } else {
            velocity = .zero
            // Don't snap to log center as they are wide rectangles
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
        velocity.dx *= -0.5
        velocity.dy *= -0.5
        HapticsManager.shared.playImpact(.heavy)
    }
}

// MARK: - Pad / Enemy / Coin (Unchanged)
class Pad: GameEntity {
    enum PadType { case normal, moving, ice, log, grave, shrinking, waterLily }
    var type: PadType = .normal
    var moveDirection: CGFloat = 1.0
    var moveSpeed: CGFloat = 2.0
    
    private var shapeNode: SKShapeNode?
    private var shrinkTime: Double = 0
    private var shrinkSpeed: Double = 2.0
    
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
            let rect = SKShapeNode(rectOf: CGSize(width: 120, height: 40), cornerRadius: 10)
            rect.fillColor = UIColor.brown
            rect.strokeColor = UIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
            rect.lineWidth = 2
            addChild(rect)
            let grain = SKShapeNode(rectOf: CGSize(width: 100, height: 2))
            grain.fillColor = .black.withAlphaComponent(0.2)
            grain.strokeColor = .clear
            addChild(grain)
        } else {
            let radius: CGFloat = 45
            let path = UIBezierPath()
            let startAngle: CGFloat = 0.2
            let endAngle: CGFloat = CGFloat.pi * 2 - 0.2
            path.addArc(withCenter: .zero, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            path.addLine(to: .zero)
            path.close()
            let padShape = SKShapeNode(path: path.cgPath)
            switch type {
            case .ice:
                padShape.fillColor = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
                padShape.strokeColor = .white
            case .grave:
                padShape.fillColor = UIColor(red: 0.2, green: 0.4, blue: 0.2, alpha: 1.0)
                padShape.strokeColor = .black
            case .shrinking:
                padShape.fillColor = UIColor(red: 155/255, green: 89/255, blue: 182/255, alpha: 1.0)
                padShape.strokeColor = UIColor(red: 142/255, green: 68/255, blue: 173/255, alpha: 1.0)
            case .waterLily:
                padShape.fillColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1)
                padShape.strokeColor = UIColor(red: 236/255, green: 64/255, blue: 122/255, alpha: 1)
            default:
                padShape.fillColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1)
                padShape.strokeColor = UIColor(red: 39/255, green: 174/255, blue: 96/255, alpha: 1)
            }
            padShape.lineWidth = 4
            addChild(padShape)
            
            if type == .grave {
                let tombstone = SKShapeNode(rectOf: CGSize(width: 20, height: 30), cornerRadius: 5)
                tombstone.fillColor = .gray
                tombstone.strokeColor = .darkGray
                tombstone.position = CGPoint(x: 0, y: 5)
                tombstone.zRotation = -self.zRotation
                addChild(tombstone)
                let cross = SKLabelNode(text: "✝")
                cross.fontSize = 16
                cross.fontColor = .black
                cross.position = CGPoint(x: 0, y: -5)
                tombstone.addChild(cross)
            }
            if type == .waterLily {
                let flower = SKShapeNode(circleOfRadius: 15)
                flower.fillColor = UIColor(red: 248/255, green: 187/255, blue: 208/255, alpha: 1.0)
                flower.strokeColor = .white
                flower.lineWidth = 2
                flower.zRotation = -self.zRotation
                addChild(flower)
                let center = SKShapeNode(circleOfRadius: 5)
                center.fillColor = .yellow
                center.strokeColor = .clear
                flower.addChild(center)
            }
        }
    }
    
    func updateColor(weather: WeatherType) {
        guard type == .normal || type == .moving || type == .waterLily else { return }
        let newColor: UIColor
        switch weather {
        case .sunny: newColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1)
        case .rain: newColor = UIColor(red: 34/255, green: 153/255, blue: 84/255, alpha: 1)
        case .night: newColor = UIColor(red: 22/255, green: 160/255, blue: 133/255, alpha: 1)
        case .winter: newColor = UIColor(red: 163/255, green: 228/255, blue: 215/255, alpha: 1)
        }
        shapeNode?.fillColor = newColor
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
        let body = SKShapeNode(circleOfRadius: 15)
        switch type {
        case "DRAGONFLY":
            body.fillColor = UIColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1)
        case "GHOST":
            body.fillColor = UIColor.white.withAlphaComponent(0.7)
        default:
            body.fillColor = UIColor(red: 241/255, green: 196/255, blue: 15/255, alpha: 1)
        }
        body.strokeColor = .black
        body.lineWidth = 2
        addChild(body)
        var icon = "🐝"
        if type == "DRAGONFLY" { icon = "🦟" }
        else if type == "GHOST" { icon = "👻" }
        let label = SKLabelNode(text: icon)
        label.verticalAlignmentMode = .center
        label.fontSize = 20
        body.addChild(label)
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
        let label = SKLabelNode(text: "🪙")
        label.verticalAlignmentMode = .center
        label.fontSize = 24
        addChild(label)
        let moveUp = SKAction.moveBy(x: 0, y: 5, duration: 0.5)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = moveUp.reversed()
        run(SKAction.repeatForever(SKAction.sequence([moveUp, moveDown])))
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
}
