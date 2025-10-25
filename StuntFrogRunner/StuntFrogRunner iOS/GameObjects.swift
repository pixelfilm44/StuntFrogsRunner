//
//  Enemy.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/13/25.
//


//
//  GameObjects.swift
//  Stuntfrog Superstar
//
//  Game object classes: Enemy, Tadpole, LilyPad
//

import SpriteKit

class Enemy {
    let type: EnemyType
    var position: CGPoint
    var speed: CGFloat
    let node: SKNode
    
    // Track which lily pad this enemy is targeting (if any)
    weak var targetLilyPad: LilyPad?
    
    init(type: EnemyType, position: CGPoint, speed: CGFloat) {
        self.type = type
        self.position = position
        self.speed = speed
        
        if type == .log {
            // Use log.png image for logs
            let logTexture = SKTexture(imageNamed: "log")
            let logSprite = SKSpriteNode(texture: logTexture)
            logSprite.size = CGSize(width: GameConfig.logWidth, height: GameConfig.logHeight)
            self.node = logSprite
        } else if type == .bee {
            // Use bee.png image for bees
            let beeTexture = SKTexture(imageNamed: "bee")
            let beeSprite = SKSpriteNode(texture: beeTexture)
            beeSprite.size = CGSize(width: GameConfig.beeSize, height: GameConfig.beeSize)
            self.node = beeSprite
        } else if type == .snake {
            // Use snake.png image for snakes
            let snakeTexture = SKTexture(imageNamed: "snake")
            let snakeSprite = SKSpriteNode(texture: snakeTexture)
            snakeSprite.size = CGSize(width: GameConfig.snakeSize, height: GameConfig.snakeSize)
            self.node = snakeSprite
        } else if type == .dragonfly {
            // Use dragonfly.png image for dragonflies
            let dragonflyTexture = SKTexture(imageNamed: "dragonfly")
            let dragonflySprite = SKSpriteNode(texture: dragonflyTexture)
            dragonflySprite.size = CGSize(width: GameConfig.dragonflySize, height: GameConfig.dragonflySize)
            self.node = dragonflySprite
        } else {
            // Fallback for any future enemy types
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
    
    init(position: CGPoint) {
        self.position = position
        // Use star.png from assets (named "star")
        let texture = SKTexture(imageNamed: "star")
        let sprite = SKSpriteNode(texture: texture)
        // Size using tadpoleSize as the intended visual size
        sprite.size = CGSize(width: GameConfig.tadpoleSize, height: GameConfig.tadpoleSize)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.node = sprite
    }
}

/// Types of lily pads
enum LilyPadType {
    case normal
    case pulsing
    case moving
}

class LilyPad {
    var position: CGPoint
    var radius: CGFloat
    let node: SKNode

    // Track enemy types present on this lily pad
    var occupyingEnemyTypes: Set<EnemyType> = []

    // Pad behavior
    let type: LilyPadType
    private var padSprite: SKSpriteNode? // the main sprite to scale for pulsing
    private var pulseMinScale: CGFloat = 0.05
    private var pulseMaxScale: CGFloat = 1.0
    private var pulseDuration: TimeInterval = 1.8
    private var isPulsing: Bool = false

    // Movement behavior
    private var isMoving: Bool = false
    var movementSpeed: CGFloat = 120.0 // points per second
    /// Provide the visible width to know when to wrap. If nil, uses 1024 as a fallback.
    var screenWidthProvider: (() -> CGFloat)?

    /// Optional callback invoked when a landing occurs while pad is unsafe (too small)
    var onUnsafeLanding: (() -> Void)?

    /// Threshold under which landing is unsafe (frog drowns). Set per requirement to 40%.
    var unsafeScaleThreshold: CGFloat = 0.4

    /// Whether it's currently safe for the frog to land on or stand on this pad
    var isSafeToLand: Bool {
        guard type == .pulsing, let sprite = padSprite else { return true }
        // Use x-scale (same as y-scale for uniform scaling)
        return sprite.xScale >= unsafeScaleThreshold
    }
    
    init(position: CGPoint, radius: CGFloat, type: LilyPadType = .normal) {
        self.position = position
        self.radius = radius
        self.type = type

        let container = SKNode()

        // Load lily pad texture
        if let texture = SKTexture(imageNamed: "lilypad") as? SKTexture {
            let sprite = SKSpriteNode(texture: texture)
            // Scale sprite to match the desired radius
            // Assuming the texture is roughly circular, we scale based on radius
            let textureSize = texture.size()
            let scale = (radius * 2) / max(textureSize.width, textureSize.height)
            sprite.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            container.addChild(sprite)
            self.padSprite = sprite
        } else {
            // Fallback to procedural generation if texture not found
            let pad = SKShapeNode(circleOfRadius: radius)
            pad.fillColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
            pad.strokeColor = UIColor(red: 0.15, green: 0.5, blue: 0.15, alpha: 1.0)
            pad.lineWidth = 3
            
            let center = SKShapeNode(circleOfRadius: radius * 0.3)
            center.fillColor = UIColor(red: 0.25, green: 0.65, blue: 0.25, alpha: 1.0)
            center.strokeColor = .clear
            pad.addChild(center)
            
            for i in 0..<6 {
                let angle = CGFloat(i) * (CGFloat.pi * 2 / 6)
                let linePath = CGMutablePath()
                linePath.move(to: .zero)
                linePath.addLine(to: CGPoint(x: cos(angle) * radius * 0.8, y: sin(angle) * radius * 0.8))
                let line = SKShapeNode(path: linePath)
                line.strokeColor = UIColor(red: 0.15, green: 0.5, blue: 0.15, alpha: 0.6)
                line.lineWidth = 2
                pad.addChild(line)
            }
            
            container.addChild(pad)
            
            // For fallback, wrap the shape in a sprite node for consistent scaling
            let wrapperSprite = SKSpriteNode()
            wrapperSprite.addChild(container)
            self.padSprite = wrapperSprite
            // Move container back to be the main node since sprite is just for scaling
            container.removeFromParent()
        }

        self.node = container

        // Configure pulsing behavior if needed
        if type == .pulsing {
            startPulsing()
        }
        if type == .moving {
            startMoving()
        }
    }

    // MARK: - Pulsing Behavior

    private func startPulsing() {
        guard !isPulsing, let sprite = padSprite else { return }
        isPulsing = true

        // Create a repeating shrink -> expand sequence
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


    // MARK: - Movement Behavior (Left to Right Loop)

        private func startMoving() {
            guard !isMoving else { return }
            isMoving = true

            // Ensure the container (self.node) moves as a whole
            let width = screenWidthProvider?() ?? 1024.0
            let offRight = width + radius * 2
            let startX = -radius * 2

            // DON'T reset position - start from wherever the pad was spawned
            // This allows pads to appear at different points in their movement cycle

            func makeRunAction() -> SKAction {
                // Distance to travel from current x to off-right
                let distance = offRight - node.position.x
                let duration = TimeInterval(distance / max(movementSpeed, 1))
                let moveRight = SKAction.moveTo(x: offRight, duration: duration)
                moveRight.timingMode = .linear
                let warpLeft = SKAction.run { [weak self] in
                    guard let self = self else { return }
                    self.node.position.x = startX
                }
                return SKAction.sequence([moveRight, warpLeft])
            }

            let loop = SKAction.repeatForever(SKAction.sequence([
                SKAction.run { [weak self] in
                    guard let self = self else { return }
                    let run = makeRunAction()
                    self.node.run(run, withKey: "moving-once")
                },
                SKAction.wait(forDuration: 0.01)
            ]))
            node.run(loop, withKey: "moving-loop")
        }
    func stopMoving() {
        guard isMoving else { return }
        node.removeAction(forKey: "moving-loop")
        node.removeAction(forKey: "moving-once")
        isMoving = false
    }

    /// Call to refresh movement path if screen width or speed changes at runtime.
    func refreshMovement() {
        if isMoving {
            stopMoving()
            startMoving()
        }
    }

    /// Call this when the frog attempts to land on the pad.
    /// If the pad is currently too small, it triggers the unsafe callback and returns false.
    /// Otherwise returns true, indicating a safe landing.
    @discardableResult
    func handleLandingAttempt() -> Bool {
        if !isSafeToLand {
            onUnsafeLanding?() // e.g., notify scene to drown frog
            return false
        }
        return true
    }

    // MARK: - Enemy Occupancy Management
    
    /// Check if this lily pad can accommodate the given enemy type
    func canAccommodateEnemyType(_ enemyType: EnemyType) -> Bool {
        // If no enemies are present, any type can be placed
        if occupyingEnemyTypes.isEmpty {
            return true
        }
        
        // Special rules based on enemy type
        switch enemyType {
        case .snake:
            // Snakes can only target lily pads with no bees (but can coexist with other snakes)
            return !occupyingEnemyTypes.contains(.bee)
        case .bee:
            // Bees can only target lily pads with no snakes (but can coexist with other bees)
            return !occupyingEnemyTypes.contains(.snake)
        case .dragonfly:
            // Dragonflies don't target lily pads, so this shouldn't be called
            return false
        case .log:
            // Logs don't target lily pads, so this shouldn't be called
            return false
        }
    }
    
    /// Add an enemy type to this lily pad's occupancy
    func addEnemyType(_ enemyType: EnemyType) {
        occupyingEnemyTypes.insert(enemyType)
    }
    
    /// Remove an enemy type from this lily pad's occupancy
    func removeEnemyType(_ enemyType: EnemyType) {
        occupyingEnemyTypes.remove(enemyType)
    }
    
    /// Check if this lily pad has any enemies
    var hasEnemies: Bool {
        return !occupyingEnemyTypes.isEmpty
    }
}
