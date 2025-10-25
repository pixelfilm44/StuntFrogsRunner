//
//  GameObjects.swift
//  Stuntfrog Superstar
//
//  Game object classes with lily pad passenger system
//

import SpriteKit

class Enemy {
    let type: EnemyType
    var position: CGPoint
    var speed: CGFloat
    let node: SKNode
    
    weak var targetLilyPad: LilyPad?
    
    init(type: EnemyType, position: CGPoint, speed: CGFloat) {
        self.type = type
        self.position = position
        self.speed = speed
        
        if type == .log {
            let logTexture = SKTexture(imageNamed: "log")
            let logSprite = SKSpriteNode(texture: logTexture)
            logSprite.size = CGSize(width: GameConfig.logWidth, height: GameConfig.logHeight)
            self.node = logSprite
        } else if type == .bee {
            let beeTexture = SKTexture(imageNamed: "bee")
            let beeSprite = SKSpriteNode(texture: beeTexture)
            beeSprite.size = CGSize(width: GameConfig.beeSize, height: GameConfig.beeSize)
            self.node = beeSprite
        } else if type == .snake {
            let snakeTexture = SKTexture(imageNamed: "snake")
            let snakeSprite = SKSpriteNode(texture: snakeTexture)
            snakeSprite.size = CGSize(width: GameConfig.snakeSize, height: GameConfig.snakeSize)
            self.node = snakeSprite
        } else if type == .dragonfly {
            let dragonflyTexture = SKTexture(imageNamed: "dragonfly")
            let dragonflySprite = SKSpriteNode(texture: dragonflyTexture)
            dragonflySprite.size = CGSize(width: GameConfig.dragonflySize, height: GameConfig.dragonflySize)
            self.node = dragonflySprite
        } else {
            let label = SKLabelNode(text: type.rawValue)
            label.fontSize = 40
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            self.node = label
        }
    }
}

class Tadpole {
    var position: CGPoint
    let node: SKSpriteNode
    
    // NEW: Track which lily pad this tadpole is on
    weak var lilyPad: LilyPad? {
        didSet {
            // When assigned to a lily pad, add this tadpole to its passengers
            if let pad = lilyPad {
                pad.addTadpole(self)
            }
            // Remove from old lily pad if needed
            if let oldPad = oldValue, oldPad !== lilyPad {
                oldPad.removeTadpole(self)
            }
        }
    }
    
    init(position: CGPoint) {
        self.position = position
        let texture = SKTexture(imageNamed: "star")
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: GameConfig.tadpoleSize, height: GameConfig.tadpoleSize)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.node = sprite
    }
    
    deinit {
        // Clean up lily pad reference when tadpole is destroyed
        lilyPad?.removeTadpole(self)
    }
}

enum LilyPadType {
    case normal
    case pulsing
    case moving
}

class LilyPad {
    var position: CGPoint
    var radius: CGFloat
    let node: SKNode

    // PHYSICS PROPERTIES
    var velocity: CGPoint = .zero
    var mass: CGFloat = 1.0
    
    var occupyingEnemyTypes: Set<EnemyType> = []

    // Pad behavior
    let type: LilyPadType
    private var padSprite: SKSpriteNode?
    
    // Pulsing animation state
    private var isPulsing: Bool = false
    private var pulseMinScale: CGFloat = 0.05
    private var pulseMaxScale: CGFloat = 1.0
    private var pulseDuration: TimeInterval = 1.8
    
    var unsafeScaleThreshold: CGFloat = 0.4
    
    var isSafeToLand: Bool {
        guard type == .pulsing, let sprite = padSprite else { return true }
        return sprite.xScale >= unsafeScaleThreshold
    }
    
    // Moving behavior
    private var isMoving: Bool = false
    private var movementDirection: CGFloat = 1.0
    var movementSpeed: CGFloat = 1.0
    private var moveTimer: CGFloat = 0
    
    var screenWidthProvider: (() -> CGFloat)?
    
    var onUnsafeLanding: (() -> Void)?
    
    // NEW: Track objects on this lily pad
    private var tadpoles: [Tadpole] = []
    
    // NEW: Track if the frog is on this lily pad (set by FrogController)
    var hasFrog: Bool = false
    weak var frog: FrogController?
    
    // NEW: Store previous position for delta calculation
    private var previousPosition: CGPoint
    
    init(position: CGPoint, radius: CGFloat, type: LilyPadType = .normal) {
        self.position = position
        self.previousPosition = position
        self.radius = radius
        self.type = type
        
        self.mass = radius / GameConfig.minLilyPadRadius
        
        let container = SKNode()
        
        let texture = SKTexture(imageNamed: "lilypad")
        let sprite = SKSpriteNode(texture: texture)
        
        let textureSize = texture.size()
        let scale = (radius * 2) / max(textureSize.width, textureSize.height)
        sprite.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        container.addChild(sprite)
        self.padSprite = sprite
        
        self.node = container
        
        if type == .pulsing {
            startPulsing()
        } else if type == .moving {
            startMoving()
        }
    }
    
    // MARK: - Physics Update
    
    func updatePhysics(screenWidth: CGFloat) {
        // Store previous position before updating
        previousPosition = position
        
        // Apply velocity to position
        position.x += velocity.x
        position.y += velocity.y
        
        // Water friction dampening
        let dampening: CGFloat = 0.92
        velocity.x *= dampening
        velocity.y *= dampening
        
        // Stop very small velocities
        if abs(velocity.x) < 0.05 { velocity.x = 0 }
        if abs(velocity.y) < 0.05 { velocity.y = 0 }
        
        // Keep within screen bounds with soft bounce
        let width = screenWidthProvider?() ?? screenWidth
        let minX: CGFloat = 60
        let maxX = width - 60
        
        if position.x < minX {
            position.x = minX
            velocity.x = abs(velocity.x) * 0.3
        } else if position.x > maxX {
            position.x = maxX
            velocity.x = -abs(velocity.x) * 0.3
        }
        
        // Update sprite position
        node.position = position
        
        // NEW: Update positions of objects on this lily pad
        updatePassengers()
    }
    
    func applyForce(_ force: CGPoint) {
        velocity.x += force.x / mass
        velocity.y += force.y / mass
        
        let maxVelocity: CGFloat = 4.0
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        if speed > maxVelocity {
            velocity.x = (velocity.x / speed) * maxVelocity
            velocity.y = (velocity.y / speed) * maxVelocity
        }
    }
    
    // MARK: - Passenger Management
    
    /// NEW: Update positions of all objects on this lily pad
    private func updatePassengers() {
        // Calculate how much the lily pad moved this frame
        let deltaX = position.x - previousPosition.x
        let deltaY = position.y - previousPosition.y
        
        // Update frog position if it's on this pad
        if hasFrog, let frogController = frog, frogController.isGrounded {
            frogController.position.x += deltaX
            frogController.position.y += deltaY
        }
        
        // Update tadpole positions
        for tadpole in tadpoles {
            tadpole.position.x += deltaX
            tadpole.position.y += deltaY
            tadpole.node.position = tadpole.position
        }
    }
    
    /// NEW: Add a tadpole to this lily pad
    func addTadpole(_ tadpole: Tadpole) {
        if !tadpoles.contains(where: { $0 === tadpole }) {
            tadpoles.append(tadpole)
        }
    }
    
    /// NEW: Remove a tadpole from this lily pad
    func removeTadpole(_ tadpole: Tadpole) {
        tadpoles.removeAll { $0 === tadpole }
    }
    
    // MARK: - Pulsing Behavior
    
    private func startPulsing() {
        guard !isPulsing, let sprite = padSprite else { return }
        isPulsing = true
        
        let shrink = SKAction.scale(to: pulseMinScale, duration: pulseDuration)
        let grow = SKAction.scale(to: pulseMaxScale, duration: pulseDuration)
        shrink.timingMode = .easeInEaseOut
        grow.timingMode = .easeInEaseOut
        let sequence = SKAction.sequence([shrink, grow])
        let forever = SKAction.repeatForever(sequence)
        sprite.run(forever, withKey: "pulsing")
    }
    
    func stopPulsing() {
        guard isPulsing, let sprite = padSprite else { return }
        sprite.removeAction(forKey: "pulsing")
        sprite.setScale(1.0)
        isPulsing = false
    }
    
    func updatePulsing() {
        // No manual update needed - SKActions handle it
    }
    
    // MARK: - Moving Behavior
    
    private func startMoving() {
        isMoving = true
        movementDirection = Bool.random() ? 1.0 : -1.0
        movementSpeed = CGFloat.random(in: 0.5...1.5)
        moveTimer = 0
    }
    
    func updateMoving(screenWidth: CGFloat) {
        guard type == .moving && isMoving else { return }
        
        // Store previous position before updating
        previousPosition = position
        
        moveTimer += 1
        
        if moveTimer > 180 {
            movementDirection *= -1
            moveTimer = 0
        }
        
        position.x += movementDirection * movementSpeed
        
        let width = screenWidthProvider?() ?? screenWidth
        let minX: CGFloat = 60
        let maxX = width - 60
        
        if position.x <= minX || position.x >= maxX {
            movementDirection *= -1
            position.x = max(minX, min(maxX, position.x))
        }
        
        node.position = position
        
        // NEW: Update positions of objects on this lily pad
        updatePassengers()
    }
    
    func stopMoving() {
        isMoving = false
    }
    
    func refreshMovement() {
        if isMoving {
            stopMoving()
            startMoving()
        }
    }

    @discardableResult
    func handleLandingAttempt() -> Bool {
        if !isSafeToLand {
            onUnsafeLanding?()
            return false
        }
        return true
    }

    // MARK: - Enemy Occupancy Management
    
    func canAccommodateEnemyType(_ enemyType: EnemyType) -> Bool {
        if occupyingEnemyTypes.isEmpty {
            return true
        }
        
        switch enemyType {
        case .snake:
            return !occupyingEnemyTypes.contains(.bee)
        case .bee:
            return !occupyingEnemyTypes.contains(.snake)
        case .dragonfly, .log:
            return false
        }
    }
    
    func addEnemyType(_ enemyType: EnemyType) {
        occupyingEnemyTypes.insert(enemyType)
    }
    
    func removeEnemyType(_ enemyType: EnemyType) {
        occupyingEnemyTypes.remove(enemyType)
    }
    
    var hasEnemies: Bool {
        return !occupyingEnemyTypes.isEmpty
    }
}
