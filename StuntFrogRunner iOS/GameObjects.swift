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
    
    // Additional properties for chaser behavior
    weak var targetFrog: FrogController?
    
    // Animation properties for frame-based enemies like snakes
    private var animationTextures: [SKTexture] = []
    private var animationFrameDuration: TimeInterval = 0.15
    private var isAnimationStarted: Bool = false
    private var hasBeenVisible: Bool = false  // Track if this enemy has ever been visible
    
    init(type: EnemyType, position: CGPoint, speed: CGFloat) {
        self.type = type
        self.position = position
        
        // Base speed provided by caller
        self.speed = speed

        // Randomize bee speed at creation time (±30% variability)
        if type == .bee {
            let variability: ClosedRange<CGFloat> = 0.7...1.3
            let multiplier = CGFloat.random(in: variability)
            self.speed *= multiplier
        }
        
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
            // Load snake animation frames with a safe upper limit
            var frameTextures: [SKTexture] = []
            let maxFramesToCheck = 20 // Safety limit to prevent infinite loops
            
            print("🐍 Attempting to load snake animation frames...")
            
            // Try to load numbered frames (snake1, snake2, etc.)
            for frameIndex in 1...maxFramesToCheck {
                let frameName = "snake\(frameIndex)"
                
                // Use a safer approach to check if texture exists
                if let _ = UIImage(named: frameName) {
                    let frameTexture = SKTexture(imageNamed: frameName)
                    frameTextures.append(frameTexture)
                    print("🐍 Found animation frame: \(frameName)")
                } else {
                    // Stop when we can't find the next frame
                    print("🐍 No more animation frames found after \(frameName)")
                    break
                }
            }
            
            // If no numbered frames were found, fall back to the base snake texture
            if frameTextures.isEmpty {
                print("🐍 No numbered frames found, trying base 'snake' texture...")
                if let _ = UIImage(named: "snake") {
                    let fallbackTexture = SKTexture(imageNamed: "snake")
                    frameTextures.append(fallbackTexture)
                    print("🐍 Using base snake texture as fallback")
                } else {
                    print("⚠️ No snake texture found at all! Snake will be invisible or use default texture")
                    // Create a fallback texture so the snake still appears
                    let fallbackTexture = SKTexture(imageNamed: "snake")
                    frameTextures.append(fallbackTexture)
                }
            }
            
            // Store the animation textures
            animationTextures = frameTextures
            print("🐍 Final: Loaded \(animationTextures.count) snake animation frames")
            
            let initialTexture = animationTextures.first ?? SKTexture(imageNamed: "snake")
            let snakeSprite = SKSpriteNode(texture: initialTexture)
            snakeSprite.size = CGSize(width: GameConfig.snakeSize, height: GameConfig.snakeSize)
            self.node = snakeSprite
            
            print("🐍 Created snake sprite with size: \(GameConfig.snakeSize)x\(GameConfig.snakeSize)")
            
            // Don't start animation immediately - wait until snake is visible
            print("🐍 Snake created but animation will start when visible")
        } else if type == .dragonfly {
            let dragonflyTexture = SKTexture(imageNamed: "dragonfly")
            let dragonflySprite = SKSpriteNode(texture: dragonflyTexture)
            dragonflySprite.size = CGSize(width: GameConfig.dragonflySize, height: GameConfig.dragonflySize)
            self.node = dragonflySprite
        } else if type == .chaser {
            let chaserTexture = SKTexture(imageNamed: "ghostFrog") // Use frog sprite as base
            let chaserSprite = SKSpriteNode(texture: chaserTexture)
            chaserSprite.size = CGSize(width: GameConfig.chaserSize, height: GameConfig.chaserSize)
            
            self.node = chaserSprite
        } else if type == .spikeBush {
            let spikeBushTexture = SKTexture(imageNamed: "spikeBush")
            let spikeBushSprite = SKSpriteNode(texture: spikeBushTexture)
            spikeBushSprite.size = CGSize(width: GameConfig.spikeBushSize, height: GameConfig.spikeBushSize)
            self.node = spikeBushSprite
        } else if type == .edgeSpikeBush {
            let edgeSpikeBushTexture = SKTexture(imageNamed: "spikeBush") // Reuse same texture
            let edgeSpikeBushSprite = SKSpriteNode(texture: edgeSpikeBushTexture)
            edgeSpikeBushSprite.size = CGSize(width: GameConfig.edgeSpikeBushSize, height: GameConfig.edgeSpikeBushSize)
            self.node = edgeSpikeBushSprite
        } else {
            let label = SKLabelNode(text: type.rawValue)
            label.fontSize = 40
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            self.node = label
        }
    }
    
    // MARK: - Chaser Movement Logic
    
    func updateChaserMovement() {
        guard type == .chaser, let frog = targetFrog else { return }
        
        // Calculate direction from chaser to frog
        let dx = frog.position.x - position.x
        let dy = frog.position.y - position.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Avoid division by zero
        guard distance > 0.1 else { return }
        
        // Normalize direction vector
        let nx = dx / distance
        let ny = dy / distance
        
        // Move toward frog at chaser speed
        let moveSpeed = GameConfig.chaserSpeed
        position.x += nx * moveSpeed
        position.y += ny * moveSpeed
        
        // Flip the chaser image based on vertical movement direction
        if let chaserSprite = node as? SKSpriteNode {
            if ny < 0 {
                // Moving down (negative Y direction) - flip upside down
                chaserSprite.zRotation = .pi
            } else {
                // Moving up or not moving vertically - normal orientation
                chaserSprite.zRotation = 0
            }
        }
        
        // Update the visual node position
        node.position = position
    }
    
    // MARK: - Animation Methods
    

    
    /// Start the snake animation loop if not already started
    private func startSnakeAnimation() {
        guard type == .snake, !animationTextures.isEmpty, !isAnimationStarted else { return }
        guard let snakeSprite = node as? SKSpriteNode else { return }
        
        // Create repeating animation
        let animate = SKAction.animate(with: animationTextures, 
                                     timePerFrame: animationFrameDuration, 
                                     resize: false, 
                                     restore: false)
        let repeatAnimation = SKAction.repeatForever(animate)
        
        snakeSprite.run(repeatAnimation, withKey: "snakeAnimation")
        isAnimationStarted = true
        print("🐍 Snake animation started with \(animationTextures.count) frames")
    }
    
    /// Check if the snake is visible in the current frame and start animation if needed
    func updateVisibilityAnimation(worldOffset: CGFloat, sceneHeight: CGFloat) {
        guard type == .snake, !isAnimationStarted, !hasBeenVisible else { return }
        
        // Calculate visible Y range in world coordinates
        let visibleMinY = -worldOffset - 100  // Small margin below screen
        let visibleMaxY = -worldOffset + sceneHeight + 100  // Small margin above screen
        
        // Check if snake is within visible range
        if position.y >= visibleMinY && position.y <= visibleMaxY {
            hasBeenVisible = true
            startSnakeAnimation()
            print("🐍 Snake at (\(Int(position.x)), \(Int(position.y))) came into view - starting animation")
        }
    }
    
    /// Force start snake animation (for testing or special cases)
    func forceStartAnimation() {
        if type == .snake {
            startSnakeAnimation()
        }
    }
    
    /// Check if this snake is currently animated
    var isSnakeAnimated: Bool {
        return type == .snake && isAnimationStarted
    }
    
    /// Stop the snake animation (called when enemy is removed)
    func stopAnimation() {
        if type == .snake {
            node.removeAction(forKey: "snakeAnimation")
            isAnimationStarted = false
            print("🐍 Snake animation stopped")
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
    case grave
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
    private var pulseDuration: TimeInterval = 2.8
    
    var unsafeScaleThreshold: CGFloat = 0.4
    
    // Spawn probabilities
    static let graveSpawnChance: CGFloat = 0.75 // 75% chance to spawn a grave lily pad
    static let chaserOnGraveSpawnChance: CGFloat = 0.75 // 75% chance to spawn a chaser on a grave pad
    
    /// Returns true with the configured probability to spawn a grave lily pad
    static func shouldSpawnGravePad() -> Bool {
        return CGFloat.random(in: 0...1) <= graveSpawnChance
    }
    
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
    
    // Optional provider to query other lily pads for overlap avoidance
    var nearbyPadsProvider: (() -> [LilyPad])?
    
    var onUnsafeLanding: (() -> Void)?
    
    // NEW: Track objects on this lily pad
    private var tadpoles: [Tadpole] = []
    private var bigHoneyPots: [BigHoneyPot] = []
   
    
    // NEW: Track if the frog is on this lily pad (set by FrogController)
    var hasFrog: Bool = false {
        didSet {
            if hasFrog {
                press()
            } else {
                release()
            }
        }
    }
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
        
        // Choose texture based on lily pad type
        let textureName: String
        if type == .grave {
            textureName = "graveLilypad"
        } else {
            textureName = "lilypad"
        }
        let texture = SKTexture(imageNamed: textureName)
        
        let textureSize = texture.size()
        let scale = (radius * 2) / max(textureSize.width, textureSize.height)
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        container.addChild(sprite)
        
        // Randomize initial rotation so pads appear at different angles
        let randomRotation = CGFloat.random(in: 0..<(2 * .pi))
        sprite.zRotation = randomRotation
        container.zRotation = randomRotation
        
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
        
        let maxVelocity: CGFloat = 2.0
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
        
        // CRITICAL FIX: Update tadpole positions when pad moves
        for tadpole in tadpoles {
            tadpole.position.x += deltaX
            tadpole.position.y += deltaY
            tadpole.node.position = tadpole.position
        }
        
        // Update big honey pot positions when pad moves
        for bigHoneyPot in bigHoneyPots {
            bigHoneyPot.position.x += deltaX
            bigHoneyPot.position.y += deltaY
            bigHoneyPot.node.position = bigHoneyPot.position
        }
    }
    
    /// NEW: Add a tadpole to this lily pad
    func addTadpole(_ tadpole: Tadpole) {
        // Enforce the one-tadpole-per-lily-pad rule
        if !tadpoles.isEmpty {
            print("âš ï¸ Attempted to add tadpole to lily pad that already has \(tadpoles.count) tadpole(s) - blocking")
            return
        }
        
        if !tadpoles.contains(where: { $0 === tadpole }) {
            tadpoles.append(tadpole)
            print("ðŸ¸ Added tadpole to lily pad at \(Int(position.x)), \(Int(position.y)) - now has \(tadpoles.count) tadpole(s)")
        }
    }
    
    /// NEW: Remove a tadpole from this lily pad
    func removeTadpole(_ tadpole: Tadpole) {
        let countBefore = tadpoles.count
        tadpoles.removeAll { $0 === tadpole }
        let countAfter = tadpoles.count
        
        if countBefore != countAfter {
            print("ðŸ—‘ï¸ Removed tadpole from lily pad at \(Int(position.x)), \(Int(position.y)) - now has \(countAfter) tadpole(s)")
        }
     
    }
    
    /// NEW: Check if this lily pad has any tadpoles
    var hasTadpoles: Bool {
        return !tadpoles.isEmpty
    }
    
    /// NEW: Get the number of tadpoles on this lily pad
    var tadpoleCount: Int {
        return tadpoles.count
    }
    
    /// Remove all tadpoles from this lily pad 
    func clearTadpoles() {
        // Remove tadpoles' nodes from the scene and clear tracking
        for t in tadpoles {
            t.node.removeFromParent()
            // Break the link without triggering add/remove loops
            t.lilyPad = nil
        }
        tadpoles.removeAll()
    }
    
    // MARK: - Big Honey Pot Management
    
    /// Add a big honey pot to this lily pad
    func addBigHoneyPot(_ bigHoneyPot: BigHoneyPot) {
        // Enforce the one-big-honey-pot-per-lily-pad rule
        if !bigHoneyPots.isEmpty {
            print("⚠️ Attempted to add big honey pot to lily pad that already has \(bigHoneyPots.count) big honey pot(s) - blocking")
            return
        }
        
        if !bigHoneyPots.contains(where: { $0 === bigHoneyPot }) {
            bigHoneyPots.append(bigHoneyPot)
            print("🍯 Added big honey pot to lily pad at \(Int(position.x)), \(Int(position.y)) - now has \(bigHoneyPots.count) big honey pot(s)")
        }
    }
    
    /// Remove a big honey pot from this lily pad
    func removeBigHoneyPot(_ bigHoneyPot: BigHoneyPot) {
        let countBefore = bigHoneyPots.count
        bigHoneyPots.removeAll { $0 === bigHoneyPot }
        let countAfter = bigHoneyPots.count
        
        if countBefore != countAfter {
            print("🗑️ Removed big honey pot from lily pad at \(Int(position.x)), \(Int(position.y)) - now has \(countAfter) big honey pot(s)")
        }
    }
    
    /// Check if this lily pad has any big honey pots
    var hasBigHoneyPots: Bool {
        return !bigHoneyPots.isEmpty
    }
    
    /// Get the number of big honey pots on this lily pad
    var bigHoneyPotCount: Int {
        return bigHoneyPots.count
    }
    
    /// Remove all big honey pots from this lily pad
    func clearBigHoneyPots() {
        // Remove big honey pots' nodes from the scene and clear tracking
        for bhp in bigHoneyPots {
            bhp.node.removeFromParent()
            // Break the link without triggering add/remove loops
            bhp.lilyPad = nil
        }
        bigHoneyPots.removeAll()
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
        // Only set a random speed if no speed was explicitly set (i.e., if it's still at default 1.0)
        if movementSpeed <= 1.0 {
            movementSpeed = CGFloat.random(in: 0.2...0.6)
        }
        // Always clamp to a sensible max so pads don't zip around
        movementSpeed = min(movementSpeed, 0.8)
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
        
        // Apply movement with a conservative speed cap
        let dx = movementDirection * movementSpeed
        let clampedDX = max(-1.0, min(1.0, dx))
        position.x += clampedDX
        
        let width = screenWidthProvider?() ?? screenWidth
        let minX: CGFloat = 60
        let maxX = width - 60
        
        if position.x <= minX || position.x >= maxX {
            movementDirection *= -1
            position.x = max(minX, min(maxX, position.x))
        }
        
        node.position = position
        
        // Prevent overlap with static lily pads by backing off if intersecting
        if let otherPads = nearbyPadsProvider?() {
            for other in otherPads where other !== self {
                // Only avoid static/pulsing pads; allow moving pads to manage their own spacing elsewhere
                guard other.type != .moving else { continue }
                let dx = position.x - other.position.x
                let dy = position.y - other.position.y
                let distSq = dx * dx + dy * dy
                let minDist = radius + other.radius
                if distSq < (minDist * minDist) {
                    // Push this pad away along the smallest horizontal adjustment to clear overlap
                    let dist = sqrt(max(distSq, 0.0001))
                    let overlap = minDist - dist
                    if dist > 0 {
                        let nx = dx / dist
                        let ny = dy / dist
                        // Apply a small separation proportional to the overlap
                        position.x += nx * overlap
                        position.y += ny * overlap
                        node.position = position
                    } else {
                        // If exactly overlapping, nudge horizontally based on current movement direction
                        position.x += (movementDirection >= 0 ? 1 : -1) * overlap
                        node.position = position
                    }
                }
            }
        }
        
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
    
    func startMovingIfNeeded() {
        if type == .moving && !isMoving {
            startMoving()
        }
    }
    
    // Debug accessor for movement state
    var debugMovementInfo: String {
        return "type: \(type), isMoving: \(isMoving), speed: \(movementSpeed), direction: \(movementDirection)"
    }

    @discardableResult
    func handleLandingAttempt() -> Bool {
        if !isSafeToLand {
            onUnsafeLanding?()
            return false
        }
        return true
    }
    
    // MARK: - Press/Release Animations

    /// Shrink slightly to accommodate frog weight
    func press() {
        guard let sprite = padSprite else { return }
        // Stop any ongoing press animation before starting a new one
        sprite.removeAction(forKey: "press")
        let targetScale: CGFloat = 0.92
        let duration: TimeInterval = 0.12
        let action = SKAction.scale(to: targetScale, duration: duration)
        action.timingMode = .easeOut
        sprite.run(action, withKey: "press")
    }

    /// Return to original size when frog leaves
    func release() {
        guard let sprite = padSprite else { return }
        // Stop any ongoing press animation before starting a new one
        sprite.removeAction(forKey: "press")
        let targetScale: CGFloat = 1.0
        let duration: TimeInterval = 0.18
        let action = SKAction.scale(to: targetScale, duration: duration)
        action.timingMode = .easeIn
        sprite.run(action, withKey: "press")
    }

    // MARK: - Enemy Occupancy Management
    
    func canAccommodateEnemyType(_ enemyType: EnemyType) -> Bool {
        // Only allow at most one bee per pad. Bees cannot share with any other enemy types.
        switch enemyType {
        case .bee:
            // If any enemy is already on the pad, disallow another bee.
            return occupyingEnemyTypes.isEmpty
        case .snake, .dragonfly, .log, .spikeBush, .edgeSpikeBush, .chaser:
            // Do not allow any of these to occupy pads that already have an enemy (including bees).
            return occupyingEnemyTypes.isEmpty
        }
    }
    
    func addEnemyType(_ enemyType: EnemyType) {
        occupyingEnemyTypes.insert(enemyType)
    }
    
    func removeEnemyType(_ enemyType: EnemyType) {
        occupyingEnemyTypes.remove(enemyType)
    }
    
    func hasEnemyType(_ enemyType: EnemyType) -> Bool {
        return occupyingEnemyTypes.contains(enemyType)
    }
    
    func clearAllEnemyTypes() {
        occupyingEnemyTypes.removeAll()
    }
    
    // MARK: - Grave Pad / Chaser Spawning

    /// If this pad is a grave pad, optionally spawn a chaser enemy at its center with the configured probability.
    /// Only spawns if the frog is within visible range of this lily pad.
    /// - Parameters:
    ///   - frog: The frog controller that the chaser should target.
    ///   - baseSpeed: Base speed used to initialize the chaser enemy (will be used by existing Enemy logic).
    ///   - worldOffset: Current world offset for visibility calculations (worldNode.position.y).
    ///   - sceneSize: Scene size for visibility calculations.
    /// - Returns: The spawned chaser `Enemy` if one was created, otherwise `nil`.
    @discardableResult
    func maybeSpawnChaser(targeting frog: FrogController?, baseSpeed: CGFloat = GameConfig.chaserSpeed, worldOffset: CGFloat? = nil, sceneSize: CGSize? = nil) -> Enemy? {
        guard type == .grave else { return nil }
        guard let frogController = frog else { return nil }
        
        // Check if frog is visible from this grave pad
        if let offset = worldOffset, let size = sceneSize {
            let visibleMinY = -offset - 200  // Margin below screen for spawn detection
            let visibleMaxY = -offset + size.height + 200  // Margin above screen for spawn detection
            
            // Only spawn if frog is within the visible range relative to this pad's position
            let frogInVisibleRange = frogController.position.y >= visibleMinY && frogController.position.y <= visibleMaxY
            let padInVisibleRange = position.y >= visibleMinY && position.y <= visibleMaxY
            
            // Both frog and pad should be in visible range, or close to it
            guard frogInVisibleRange || padInVisibleRange else {
                return nil
            }
            
            // Additional check: ensure frog and pad are reasonably close vertically
            let verticalDistance = abs(frogController.position.y - position.y)
            let maxSpawnDistance = size.height * 1.5  // Only spawn if within 1.5 screen heights
            guard verticalDistance <= maxSpawnDistance else {
                return nil
            }
        }
        
        // 75% chance to spawn a chaser on a grave pad
        let roll = CGFloat.random(in: 0...1)
        guard roll <= LilyPad.chaserOnGraveSpawnChance else { return nil }
        
        // Spawn chaser at the pad's center
        let chaser = Enemy(type: .chaser, position: position, speed: baseSpeed)
        chaser.targetFrog = frog
        SoundController.shared.playSoundEffect(.ghostly)
        // Position the node visually at the pad center
        chaser.node.position = position
        return chaser
    }
}

// MARK: - BigHoneyPot Class

class BigHoneyPot {
    var position: CGPoint
    let node: SKSpriteNode
    
    // Track which lily pad this big honey pot is on
    weak var lilyPad: LilyPad? {
        didSet {
            // When assigned to a lily pad, add this big honey pot to its passengers
            if let pad = lilyPad {
                pad.addBigHoneyPot(self)
            }
            // Remove from old lily pad if needed
            if let oldPad = oldValue, oldPad !== lilyPad {
                oldPad.removeBigHoneyPot(self)
            }
        }
    }
    
    init(position: CGPoint) {
        self.position = position
        let texture = SKTexture(imageNamed: "honeyBucket")
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: 50, height: 50) // Appropriate size for big honey pot
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.node = sprite
    }
    
    deinit {
        // Clean up lily pad reference when big honey pot is destroyed
        lilyPad?.removeBigHoneyPot(self)
    }
}

// MARK: - FinishLine Class

class FinishLine {
    var position: CGPoint
    let width: CGFloat
    let node: SKNode
    var onCrossed: (() -> Void)?
    
    init(position: CGPoint, width: CGFloat) {
        self.position = position
        self.width = width
        
        let container = SKNode()
        
        // Try to use finishLine.png asset first
        let finishLineTexture = SKTexture(imageNamed: "finishLine")
        if finishLineTexture.size().width > 1 && finishLineTexture.size().height > 1 {
            let finishLineSprite = SKSpriteNode(texture: finishLineTexture)
            finishLineSprite.size = CGSize(width: width, height: 80)
            finishLineSprite.position = CGPoint(x: 0, y: 40)
            finishLineSprite.zPosition = 20
            container.addChild(finishLineSprite)
        } else {
            // Fallback to original design if finishLine.png is not available
            let lineShape = SKShapeNode(rect: CGRect(x: -width/2, y: -5, width: width, height: 10))
            lineShape.fillColor = .systemYellow
            lineShape.strokeColor = .white
            lineShape.lineWidth = 2.0
            lineShape.zPosition = 20
            
            // Add flag texture if available
            let flagTexture = SKTexture(imageNamed: "finishFlag")
            if flagTexture.size().width > 1 && flagTexture.size().height > 1 {
                let flagSprite = SKSpriteNode(texture: flagTexture)
                flagSprite.size = CGSize(width: 60, height: 80)
                flagSprite.position = CGPoint(x: 0, y: 40)
                flagSprite.zPosition = 21
                container.addChild(flagSprite)
            } else {
                // Fallback flag using shapes
                let flagPole = SKShapeNode(rect: CGRect(x: -2, y: 0, width: 4, height: 60))
                flagPole.fillColor = .brown
                flagPole.strokeColor = .clear
                
                let flag = SKShapeNode(rect: CGRect(x: 2, y: 30, width: 40, height: 25))
                flag.fillColor = .systemRed
                flag.strokeColor = .white
                flag.lineWidth = 1
                
                container.addChild(flagPole)
                container.addChild(flag)
            }
            
            container.addChild(lineShape)
        }
        
        container.position = position
        
        self.node = container
    }
    
    /// Check if the frog has crossed the finish line
    func checkCrossing(frogPosition: CGPoint, frogPreviousY: CGFloat) -> Bool {
        // Check if frog crossed the finish line (moved from below to above)
        let currentY = frogPosition.y
        let finishY = position.y
        
        // Frog crossed if it was below the finish line and is now above it
        let wasBelowFinish = frogPreviousY <= finishY
        let isAboveFinish = currentY > finishY
        
        // Also check horizontal bounds (frog must be within the finish line width)
        let horizontalDistance = abs(frogPosition.x - position.x)
        let withinFinishLine = horizontalDistance <= width / 2
        
        if wasBelowFinish && isAboveFinish && withinFinishLine {
            onCrossed?()
            return true
        }
        
        return false
    }
}

