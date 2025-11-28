import SpriteKit

// MARK: - Z-Position Constants
struct Layer {
    static let water: CGFloat = 0
    static let pad: CGFloat = 10
    static let shadow: CGFloat = 15
    static let item: CGFloat = 20 // Coins, Enemies
    static let frogCharacter: CGFloat = 30
    static let trajectory: CGFloat = 50
    static let overlay: CGFloat = 900 // Below UI, above everything else
    static let ui: CGFloat = 1000
    static let frog: CGFloat = 30
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
    case recoiling   // Hit by enemy
    case cannon     // Cannon jump
}

// MARK: - Base Entity
class GameEntity: SKSpriteNode {
    var velocity: CGVector = .zero
    var zHeight: CGFloat = 0.0
    var zVelocity: CGFloat = 0.0
    
    func constrainToRiver() {
        constrainToRiver(radius: Configuration.Dimensions.frogRadius)
    }
    
    func constrainToRiver(radius: CGFloat) {
        if position.x < radius {
            position.x = radius
            velocity.dx *= -0.6
        } else if position.x > Configuration.Dimensions.riverWidth - radius {
            position.x = Configuration.Dimensions.riverWidth - radius
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
        var cannonJumps: Int = 0

    }
    
    // Cannon Jump State
    var isCannonJumpArmed: Bool = false
    var isCannonJumping: Bool = false
    
    var buffs = Buffs()
    
    var rocketState: RocketState = .none
    var rocketTimer: Int = 0
    var landingTimer: Int = 0
    
    var maxHealth: Int = 3
    var currentHealth: Int = 3
    var isInvincible: Bool = false
    var invincibilityTimer: Int = 0
    var recoilTimer: Int = 0  // Timer for recoil animation duration
    
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
    private static let recoilTexture = SKTexture(imageNamed: "frogRecoil")
    private static let cannonTexture = SKTexture(imageNamed: "cannon")
    private static let drowningTextures: [SKTexture] = [
        SKTexture(imageNamed: "frogDrown1"),
        SKTexture(imageNamed: "frogDrown2"),
        SKTexture(imageNamed: "frogDrown3")
    ]

    
    // Target heights for frog sprite (aspect ratio preserved automatically)
    private static let frogSitHeight: CGFloat = 40
    private static let frogLeapHeight: CGFloat = 80
    private static let frogJumpHeight: CGFloat = 80
    private static let frogRecoilHeight: CGFloat = 60
    private static let cannonHeight: CGFloat = 60

    
    /// Sets the frog sprite texture while preserving the image's aspect ratio
    private func setFrogTexture(_ texture: SKTexture, height: CGFloat) {
        frogSprite.texture = texture
        let textureSize = texture.size()
        let aspectRatio = textureSize.width / textureSize.height
        frogSprite.size = CGSize(width: height * aspectRatio, height: height)
    }
    
    init() {
        super.init(texture: nil, color: .clear, size: CGSize(width: 40, height: 40))
        self.zPosition = Layer.frogCharacter
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
        let rocketTargetHeight: CGFloat = 150
        let rocketAspectRatio = rocketTextureSize.width / rocketTextureSize.height
        rocketSprite.size = CGSize(width: rocketTargetHeight * rocketAspectRatio, height: rocketTargetHeight)
        rocketSprite.position = CGPoint(x: 0, y: -30)  // Position below the frog
        rocketSprite.zPosition = -1  // Behind the frog sprite
        rocketSprite.isHidden = true
        
        // Add flame sprite behind the rocket
        let flameSprite = SKSpriteNode(imageNamed: "flame")
        let flameTargetHeight: CGFloat = 80
        let flameTexture = flameSprite.texture ?? SKTexture(imageNamed: "flame")
        let flameTextureSize = flameTexture.size()
        let flameAspectRatio = flameTextureSize.width / flameTextureSize.height
        flameSprite.size = CGSize(width: flameTargetHeight * flameAspectRatio, height: flameTargetHeight)
        flameSprite.position = CGPoint(x: 0, y: -rocketTargetHeight * 0.5)  // Position below the rocket
        flameSprite.zPosition = -1  // Behind the rocket sprite
        rocketSprite.addChild(flameSprite)
        
        bodyNode.addChild(rocketSprite)
        
        // Setup frog sprite with initial sitting texture
        // Use aspect-fit sizing to preserve image ratio
        setFrogTexture(Frog.sitTexture, height: Frog.frogSitHeight)
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
        
        // Update recoil timer
        if recoilTimer > 0 {
            recoilTimer -= 1
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
                        currentFriction = 0.93
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
        velocity.dy = 2.5  // Keep drifting forward slowly during descent
        zVelocity = -32.0
    }
    
    func hit() {
        invincibilityTimer = 120
        isInvincible = true
        recoilTimer = 20  // Show recoil animation for ~0.33 seconds (20 frames at 60fps)
    }
    
    /// Plays a drowning animation where the frog sinks underwater and disappears.
    /// - Parameter completion: Called when the animation finishes
    func playDrowningAnimation(completion: @escaping () -> Void) {
        // Stop all movement
        velocity = .zero
        zVelocity = 0
        
        // Disable physics updates during animation
        isInvincible = true
        
        // Total duration for the texture-based drowning animation
        let animationDuration: TimeInterval = 1.2
        let timePerFrame = animationDuration / Double(Frog.drowningTextures.count)

        var actions: [SKAction] = []
        for texture in Frog.drowningTextures {
            let setTextureAction = SKAction.run {
                // Use frogSitHeight as a reasonable height for the drowning frames, preserving aspect ratio.
                self.setFrogTexture(texture, height: Frog.frogSitHeight)
            }
            let waitAction = SKAction.wait(forDuration: timePerFrame)
            actions.append(setTextureAction)
            actions.append(waitAction)
        }

        let textureAnimation = SKAction.sequence(actions)

        // After the animation plays, fade out the frog and its shadow
        let fadeDuration: TimeInterval = 0.3
        let fadeOut = SKAction.fadeOut(withDuration: fadeDuration)
        let sequence = SKAction.sequence([textureAnimation, fadeOut])
        
        // Run fade out on the body container and call completion when done
        bodyNode.run(sequence, completion: completion)
        
        // Also fade the shadow over the total duration
        let totalDuration = animationDuration + fadeDuration
        shadowNode.run(SKAction.fadeOut(withDuration: totalDuration))
    }
    
    func playWailingAnimation() {
        // Stop all movement
        velocity = .zero
        zVelocity = 0
        
        // Disable physics updates during animation
        isInvincible = true
        
        // Total duration for one loop of the texture-based wailing animation
        let animationDuration: TimeInterval = 1.2
        let timePerFrame = animationDuration / Double(Frog.drowningTextures.count)

        var actions: [SKAction] = []
        for texture in Frog.drowningTextures {
            let setTextureAction = SKAction.run {
                // Use frogSitHeight as a reasonable height for the wailing frames, preserving aspect ratio.
                self.setFrogTexture(texture, height: Frog.frogSitHeight)
            }
            let waitAction = SKAction.wait(forDuration: timePerFrame)
            actions.append(setTextureAction)
            actions.append(waitAction)
        }

        let textureAnimation = SKAction.sequence(actions)
        let loopingAnimation = SKAction.repeatForever(textureAnimation)
        
        // Run the looping wailing animation on the body container.
        // This will not complete, so no completion handler is used.
        bodyNode.run(loopingAnimation, withKey: "wailingAnimation")
    }

    
    /// Plays a death animation where the frog spins around and falls off the screen (for enemy deaths).
    /// - Parameter completion: Called when the animation finishes
    func playDeathAnimation(completion: @escaping () -> Void) {
        // Stop all movement
        velocity = .zero
        zVelocity = 0
        
        // Disable physics updates during animation
        isInvincible = true
        
        // Create the dramatic spinning fall animation
        let duration: TimeInterval = 1.5
        
        // Rapid spinning (multiple full rotations)
        let spinCount: CGFloat = 4  // 4 full spins
        let spin = SKAction.rotate(byAngle: spinCount * CGFloat.pi * 2, duration: duration)
        spin.timingMode = .easeIn
        
        // Fall down off the screen
        let fallDistance: CGFloat = 600
        let fall = SKAction.moveBy(x: 0, y: -fallDistance, duration: duration)
        fall.timingMode = .easeIn
        
        // Scale down as falling (getting further away)
        let scaleDown = SKAction.scale(to: 0.2, duration: duration)
        scaleDown.timingMode = .easeIn
        
        // Fade out near the end
        let wait = SKAction.wait(forDuration: duration * 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: duration * 0.4)
        let fadeSequence = SKAction.sequence([wait, fadeOut])
        
        // Combine all animations for the main frog node
        let mainAnimation = SKAction.group([fall, scaleDown, fadeSequence])
        
        // Combine spin with the main animation on the body
        let bodyAnimation = SKAction.group([spin])
        
        // Shadow fades quickly as frog falls
        let shadowFade = SKAction.fadeOut(withDuration: duration * 0.3)
        let shadowScale = SKAction.scale(to: 0.1, duration: duration * 0.3)
        let shadowAnimation = SKAction.group([shadowFade, shadowScale])
        
        // Run animations
        shadowNode.run(shadowAnimation)
        bodyNode.run(bodyAnimation)
        self.run(mainAnimation) {
            completion()
        }
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
            velocity.dy *= 0.25
            if velocity.dy < 0.5 { velocity.dy = 1.5 } // was 0.5
            position.y += velocity.dy
            zHeight = 60 + sin(CGFloat(Date().timeIntervalSince1970) * 5) * 5
        }
        constrainToRiver()
    }
    
    private func updateVisuals() {
        if !isBeingDragged {
            if isFloating {
                // Add a gentle bobbing motion when floating in water
                let bobOffset = sin(CGFloat(Date().timeIntervalSince1970) * 5.0) * 3.0
                bodyNode.position.y = bobOffset
            } else {
                bodyNode.position.y = zHeight
            }
            
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
            
            // Low health warning - flash red when at 1 heart
            if currentHealth == 1 && invincibilityTimer <= 0 {
                let flashPhase = Int(Date().timeIntervalSince1970 * 4) % 2
                frogSprite.colorBlendFactor = flashPhase == 0 ? 0.6 : 0.0
                frogSprite.color = .red
                frogSprite.alpha = 1.0
            } else if invincibilityTimer > 0 {
                frogSprite.colorBlendFactor = 0.0
                let flash = (invincibilityTimer / 10) % 2 == 0
                frogSprite.alpha = flash ? 0.5 : 1.0
            } else {
                frogSprite.colorBlendFactor = 0.0
                frogSprite.alpha = 1.0
            }
        }
    }
    
    private func updateAnimationState() {
        let newState: FrogAnimationState
        
        // Priority 1: Show recoil animation if hit recently
        if recoilTimer > 0 {
            newState = .recoiling
        } else {
            // Determine animation state based on jump phase and movement
            if zHeight <= 0.1 && abs(zVelocity) < 0.1 {
                // On ground / lilypad. Show cannon if armed, otherwise sit.
                if isCannonJumpArmed {
                    newState = .cannon
                } else {
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
        }
        
        // Only update texture if state changed (performance optimization)
        if newState != animationState {
            animationState = newState
            
            switch animationState {
            case .sitting:
                setFrogTexture(Frog.sitTexture, height: Frog.frogSitHeight)
            case .leaping:
                setFrogTexture(Frog.leapTexture, height: Frog.frogLeapHeight)
            case .jumping:
                setFrogTexture(Frog.jumpTexture, height: Frog.frogJumpHeight)
            case .recoiling:
                setFrogTexture(Frog.recoilTexture, height: Frog.frogRecoilHeight)
            case .cannon:
                setFrogTexture(Frog.cannonTexture, height: Frog.cannonHeight)
            }
        }
    }
    
    func jump(vector: CGVector, intensity: CGFloat) {
        resetPullOffset()
        
        // NOTE: SuperJump multiplier is now applied in GameScene.touchesEnded
        // and updateTrajectoryVisuals to keep trajectory prediction accurate.
        // Do NOT multiply here again to avoid double-application.
        
        self.velocity = vector
        self.zVelocity = Configuration.Physics.baseJumpZ * (0.5 + (intensity * 0.5))
        self.jumpStartZVelocity = self.zVelocity  // Track for animation phase calculation
        self.onPad = nil
        self.isFloating = false
        
        // Immediately transition to leaping state
        animationState = .leaping
        setFrogTexture(Frog.leapTexture, height: Frog.frogLeapHeight)
        
        SoundManager.shared.play("jump")
    }
    
    func land(on pad: Pad, weather: WeatherType) {
        bodyNode.removeAction(forKey: "wailingAnimation")
        zVelocity = 0
        zHeight = 0
        jumpStartZVelocity = 0  // Reset for next jump
        self.onPad = pad
        self.isFloating = false
        resetPullOffset()
        
        if isCannonJumpArmed {
            animationState = .cannon
            setFrogTexture(Frog.cannonTexture, height: Frog.cannonHeight)
        }
        else {
            // Transition to sitting state
            animationState = .sitting
            setFrogTexture(Frog.sitTexture, height: Frog.frogSitHeight)
        }
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
        // High bounce to give time for air jump - extra air time for steering to a lilypad
        zVelocity = 22.0
        jumpStartZVelocity = zVelocity  // Track for animation phases
        velocity.dx *= -0.5
        velocity.dy *= -0.5
        
        // Transition to leaping state since we're bouncing up
        animationState = .leaping
        setFrogTexture(Frog.leapTexture, height: Frog.frogLeapHeight)
        
        HapticsManager.shared.playImpact(.heavy)
    }
}

// MARK: - Pad / Enemy / Coin (Unchanged)
class Pad: GameEntity {
    enum PadType { case normal, moving, ice, log, grave, shrinking, waterLily }
    var type: PadType = .normal
    var moveDirection: CGFloat = 1.0
    var moveSpeed: CGFloat = 2.0
    var hasSpawnedGhost: Bool = false  // Track if grave has already spawned its ghost
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
    
    /// The base radius for this pad (before any scaling from shrinking)
    private(set) var baseRadius: CGFloat = Configuration.Dimensions.minPadRadius
    
    var scaledRadius: CGFloat {
        if type == .log { return 60.0 }
        return baseRadius * xScale
    }
    
    init(type: PadType, position: CGPoint, radius: CGFloat? = nil) {
        // Use provided radius or generate a random one
        let padRadius = (type == .log) ? 45.0 : (radius ?? Configuration.Dimensions.randomPadRadius())
        let diameter = padRadius * 2
        let size = (type == .log) ? CGSize(width: 120, height: 40) : CGSize(width: diameter, height: diameter)
        super.init(texture: nil, color: .clear, size: size)
        self.type = type
        self.baseRadius = padRadius
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
    func updateColor(weather: WeatherType, duration: TimeInterval = 0) {
        guard type == .normal || type == .moving || type == .waterLily else { return }
        
        // Don't change if already correct
        if weather == currentWeather && padSprite?.texture != nil { return }
        currentWeather = weather
        
        let texture: SKTexture
        if type == .waterLily {
            switch weather {
            case .sunny:
                texture = Pad.waterLilyTexture
          
            case .night:
                texture = Pad.waterLilyNightTexture
            case .rain:
                texture = Pad.waterLilyRainTexture
            case .winter:
                texture = Pad.waterLilySnowTexture
            }
        } else {
            switch weather {
            case .sunny:
                texture = Pad.dayTexture
            case .night:
                texture = Pad.nightTexture
            case .rain:
                texture = Pad.rainTexture
            
            case .winter:
                texture = Pad.snowTexture
            }
        }
        
        guard let sprite = padSprite, sprite.texture != texture else { return }

        if duration > 0 {
            let crossfadeDuration = duration * 0.5 // Crossfade over a portion of the total transition
            let oldSprite = self.padSprite
            
            let newSprite = SKSpriteNode(texture: texture)
            newSprite.size = sprite.size
            newSprite.alpha = 0
            newSprite.zRotation = sprite.zRotation
            addChild(newSprite)
            self.padSprite = newSprite

            newSprite.run(SKAction.fadeIn(withDuration: crossfadeDuration))
            oldSprite?.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: crossfadeDuration),
                SKAction.removeFromParent()
            ]))
        } else {
            sprite.texture = texture
        }
    }
    /// Plays a subtle squish animation when the frog lands on the pad.
    /// Uses SKAction for GPU-accelerated animation with no performance impact.
    func playLandingSquish() {
        // Don't animate logs or shrinking pads (shrinking has its own animation)
        guard type != .log && type != .shrinking else { return }
        
        // Remove any existing squish action to avoid stacking
        removeAction(forKey: "landingSquish")
        
        // Quick squish down (shrink slightly) then bounce back
        let squishDown = SKAction.scale(to: 0.85, duration: 0.06)
        let squishUp = SKAction.scale(to: 1.0, duration: 0.12)
        squishDown.timingMode = .easeOut
        squishUp.timingMode = .easeOut
        
        let squishSequence = SKAction.sequence([squishDown, squishUp])
        run(squishSequence, withKey: "landingSquish")
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
        
        // Handle velocity from being pushed
        if velocity != .zero {
            position.x += velocity.dx
            position.y += velocity.dy
            
            // Apply friction
            let friction: CGFloat = 0.95
            velocity.dx *= friction
            velocity.dy *= friction
            
            // Stop movement when slow enough
            if abs(velocity.dx) < 0.1 && abs(velocity.dy) < 0.1 {
                velocity = .zero
            }
            
            // Constrain to river bounds
            constrainToRiver(radius: self.scaledRadius)
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
            let ghostSprite = SKSpriteNode(imageNamed: "ghostFrog")
            ghostSprite.size = CGSize(width: 65, height: 65)
            addChild(ghostSprite)
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

// MARK: - Treasure Chest
class TreasureChest: GameEntity {
    
    /// Possible rewards from opening a treasure chest
    enum Reward: CaseIterable {
        case heartsRefill       // Refill all hearts
        case lifevest4Pack      // 4 life vests
        case cross4Pack         // 4 holy crosses
        case axe4Pack           // 4 axes
        case swatter4Pack       // 4 fly swatters
        
        var displayName: String {
            switch self {
            case .heartsRefill: return "Full Hearts!"
            case .lifevest4Pack: return "4x Life Vest"
            case .cross4Pack: return "4x Holy Cross"
            case .axe4Pack: return "4x Axe"
            case .swatter4Pack: return "4x Swatter"
            }
        }
        
        var icon: String {
            switch self {
            case .heartsRefill: return "❤️‍🔥"
            case .lifevest4Pack: return "🦺"
            case .cross4Pack: return "✝️"
            case .axe4Pack: return "🪓"
            case .swatter4Pack: return "🏸"
            }
        }
        
        static func random() -> Reward {
            return allCases.randomElement() ?? .heartsRefill
        }
    }
    
    var isCollected = false
    private(set) var reward: Reward
    private let chestSprite: SKSpriteNode
    private let glowNode: SKShapeNode
    
    // Preloaded texture (with fallback if image is missing)
    private static var chestTexture: SKTexture {
        if let _ = UIImage(named: "treasureChest") {
            return SKTexture(imageNamed: "treasureChest")
        } else {
            // Fallback: create a simple chest-like shape texture won't work, use sprite instead
            return SKTexture(imageNamed: "star") // Fallback to star if chest image missing
        }
    }
    
    init(position: CGPoint) {
        self.reward = Reward.random()
        
        // Create chest sprite - check if treasureChest image exists
        if UIImage(named: "treasureChest") != nil {
            chestSprite = SKSpriteNode(texture: TreasureChest.chestTexture)
            chestSprite.size = CGSize(width: 40, height: 40)
        } else {
            // Fallback: create a simple chest visual using shapes
            chestSprite = SKSpriteNode(color: .clear, size: CGSize(width: 40, height: 40))
            let chestBody = SKShapeNode(rectOf: CGSize(width: 36, height: 28), cornerRadius: 4)
            chestBody.fillColor = UIColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1.0) // Brown
            chestBody.strokeColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0) // Gold
            chestBody.lineWidth = 3
            chestBody.position.y = -2
            chestSprite.addChild(chestBody)
            
            // Lid
            let lid = SKShapeNode(rectOf: CGSize(width: 38, height: 12), cornerRadius: 3)
            lid.fillColor = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
            lid.strokeColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0)
            lid.lineWidth = 2
            lid.position.y = 12
            chestSprite.addChild(lid)
            
            // Lock/clasp
            let clasp = SKShapeNode(circleOfRadius: 5)
            clasp.fillColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0)
            clasp.strokeColor = UIColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1.0)
            clasp.lineWidth = 1
            clasp.position.y = 4
            chestSprite.addChild(clasp)
        }
        
        // Create glow effect
        glowNode = SKShapeNode(circleOfRadius: 25)
        glowNode.fillColor = .yellow.withAlphaComponent(0.3)
        glowNode.strokeColor = .yellow.withAlphaComponent(0.6)
        glowNode.lineWidth = 2
        glowNode.zPosition = -1
        
        super.init(texture: nil, color: .clear, size: CGSize(width: 40, height: 40))
        self.position = position
        self.zHeight = 15  // Slightly above the lilypad
        self.zPosition = Layer.item + 1  // Above coins
        
        setupVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    
    private func setupVisuals() {
        // Add glow behind chest
        addChild(glowNode)
        
        // Add chest sprite
        addChild(chestSprite)
        
        // Pulsing glow animation
        let glowUp = SKAction.fadeAlpha(to: 0.8, duration: 0.6)
        let glowDown = SKAction.fadeAlpha(to: 0.4, duration: 0.6)
        glowNode.run(SKAction.repeatForever(SKAction.sequence([glowUp, glowDown])))
        
        // Subtle floating animation
        let moveUp = SKAction.moveBy(x: 0, y: 6, duration: 0.8)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = moveUp.reversed()
        run(SKAction.repeatForever(SKAction.sequence([moveUp, moveDown])))
        
        // Slight rotation wobble for visual interest
        let rotateLeft = SKAction.rotate(byAngle: 0.1, duration: 1.0)
        let rotateRight = SKAction.rotate(byAngle: -0.1, duration: 1.0)
        chestSprite.run(SKAction.repeatForever(SKAction.sequence([rotateLeft, rotateRight, rotateRight, rotateLeft])))
    }
    
    /// Play the chest opening animation and return the reward
    func open() -> Reward {
        guard !isCollected else { return reward }
        isCollected = true
        
        // Stop all animations
        removeAllActions()
        glowNode.removeAllActions()
        chestSprite.removeAllActions()
        
        // Opening animation - scale up and burst
        let scaleUp = SKAction.scale(to: 1.5, duration: 0.15)
        let burst = SKAction.group([
            SKAction.scale(to: 2.0, duration: 0.2),
            SKAction.fadeOut(withDuration: 0.2)
        ])
        let remove = SKAction.removeFromParent()
        
        run(SKAction.sequence([scaleUp, burst, remove]))
        
        return reward
    }
}

// MARK: - Snake
class Snake: GameEntity {
    
    /// Movement speed (pixels per frame)
    private let moveSpeed: CGFloat = 2.5
    
    /// Visual nodes
    private let bodySprite = SKSpriteNode()
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: 50, height: 20))
    
    /// Animation textures
    private static let animationTextures: [SKTexture] = {
        return (1...5).map { SKTexture(imageNamed: "snake\($0)") }
    }()
    
    /// Animation key
    private let animationKey = "snakeAnimation"
    
    /// Collision radius
    var scaledRadius: CGFloat { return 25.0 }
    
    /// Whether the snake has been destroyed
    var isDestroyed: Bool = false
    
    init(position: CGPoint) {
        super.init(texture: nil, color: .clear, size: CGSize(width: 60, height: 40))
        self.position = position
        self.zHeight = 5  // Slightly above water level (on lilypads/logs)
        self.zPosition = Layer.item + 2  // Above coins and other items
        setupVisuals()
        startAnimation()
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    
    private func setupVisuals() {
        // Shadow
        shadowNode.fillColor = .black.withAlphaComponent(0.25)
        shadowNode.strokeColor = .clear
        shadowNode.position.y = -10
        shadowNode.zPosition = -1
        addChild(shadowNode)
        
        // Snake sprite
        let texture = Snake.animationTextures.first ?? SKTexture(imageNamed: "snake1")
        let textureSize = texture.size()
        let targetHeight: CGFloat = 50
        let aspectRatio = textureSize.width / textureSize.height
        bodySprite.size = CGSize(width: targetHeight * aspectRatio, height: targetHeight)
        bodySprite.texture = texture
        bodySprite.zPosition = 1
        addChild(bodySprite)
    }
    
    private func startAnimation() {
        // Cycle through snake1-5 frames
        let animateAction = SKAction.animate(with: Snake.animationTextures, timePerFrame: 0.12)
        let repeatAnimation = SKAction.repeatForever(animateAction)
        bodySprite.run(repeatAnimation, withKey: animationKey)
    }
    
    /// Updates the snake's position - moves left to right, avoiding logs and going over lilypads
    /// - Parameters:
    ///   - dt: Delta time
    ///   - pads: Array of pads to check for obstacles
    /// - Returns: True if the snake has moved off the right side of the screen
    func update(dt: TimeInterval, pads: [Pad]) -> Bool {
        guard !isDestroyed else { return false }
        
        // Move from left to right
        position.x += moveSpeed
        
        // Check for log obstacles - move around them
        for pad in pads where pad.type == .log {
            let dx = abs(position.x - pad.position.x)
            let dy = abs(position.y - pad.position.y)
            
            // Log is nearby horizontally and vertically
            if dx < 80 && dy < 60 {
                // Move up or down to avoid the log
                if position.y < pad.position.y {
                    position.y -= 1.5  // Move down
                } else {
                    position.y += 1.5  // Move up
                }
            }
        }
        
        // Constrain Y position to stay within river bounds
        let margin: CGFloat = 30
        if position.y < margin {
            position.y = margin
        } else if position.y > Configuration.Dimensions.riverWidth - margin {
            position.y = Configuration.Dimensions.riverWidth - margin
        }
        
        // Return true if snake has moved off the right edge
        return position.x > Configuration.Dimensions.riverWidth + 50
    }
    
    /// Destroys the snake (called when hit by axe)
    func destroy() {
        guard !isDestroyed else { return }
        isDestroyed = true
        
        // Stop animation
        bodySprite.removeAction(forKey: animationKey)
        
        // Death animation - shrink and fade
        let shrink = SKAction.scale(to: 0.3, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 0.2)
        let deathAnimation = SKAction.group([shrink, fade, spin])
        let remove = SKAction.removeFromParent()
        
        run(SKAction.sequence([deathAnimation, remove]))
    }
}

// MARK: - Crocodile
class Crocodile: GameEntity {
    
    enum CrocodileState {
        case submerged      // Hidden below water, waiting to rise
        case rising         // Emerging from water
        case idle           // Floating on surface, can be landed on
        case fleeing        // Swimming away from approaching frog
        case carrying       // Frog is riding on the crocodile
    }
    
    private(set) var state: CrocodileState = .submerged
    private var stateTimer: TimeInterval = 0
    private var riseDelay: TimeInterval = 0
    
    // Carrying state
    private(set) var isCarryingFrog: Bool = false
    private var carryTimer: TimeInterval = 0
    static let carryDuration: TimeInterval = 15.0  // 15 second ride
    static let carryReward: Int = 10  // Coins rewarded for successful ride (increased for longer ride)
    
    // Movement
    private let swimSpeed: CGFloat = 4.0
    private let fleeSpeed: CGFloat = 6.0
    private var steerDirection: CGFloat = 0  // -1 for left, 0 for none, 1 for right
    private let detectionRadius: CGFloat = 400.0
    
    // Visual nodes
    private let bodySprite = SKSpriteNode(imageNamed: "crocodile")
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: 240, height: 90))  // 3x bigger
    private let rideIndicator = SKShapeNode(circleOfRadius: 50)  //
    
    // Preloaded textures
    private static let crocodileTexture = SKTexture(imageNamed: "crocodile")
    private static let carryingTextures: [SKTexture] = [
        SKTexture(imageNamed: "crocodile1"),
        SKTexture(imageNamed: "crocodile2"),
        SKTexture(imageNamed: "crocodile3"),
        SKTexture(imageNamed: "crocodile4"),
        SKTexture(imageNamed: "crocodile5")
    ]
    
    // Animation key
    private let carryingAnimationKey = "carryingAnimation"
    
    var scaledRadius: CGFloat { return 150.0 }  // 3x bigger hitbox
    
    init(position: CGPoint, riseDelay: TimeInterval = 0) {
        super.init(texture: nil, color: .clear, size: CGSize(width: 300, height: 120))  // 3x bigger
        self.position = position
        self.riseDelay = riseDelay
        self.zPosition = Layer.pad + 1
        self.alpha = 0  // Start invisible (submerged)
        setupVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    
    private func setupVisuals() {
       
        
        // Crocodile sprite - 3x bigger
        let textureSize = Crocodile.crocodileTexture.size()
        let targetHeight: CGFloat = 150  // 3x bigger (was 50)
        let aspectRatio = textureSize.width / textureSize.height
        bodySprite.size = CGSize(width: targetHeight * aspectRatio, height: targetHeight)
        bodySprite.texture = Crocodile.crocodileTexture
        bodySprite.zPosition = 1
        addChild(bodySprite)
        
        // Ride indicator (shows when can be landed on)
        rideIndicator.strokeColor = .green
        rideIndicator.fillColor = .green.withAlphaComponent(0.2)
        rideIndicator.lineWidth = 3  // Thicker line for bigger indicator
        rideIndicator.zPosition = 0
        rideIndicator.isHidden = true
        addChild(rideIndicator)
        
        // Pulsing animation for ride indicator
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.4)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.4)
        rideIndicator.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))
    }
    
    func update(dt: TimeInterval, frogPosition: CGPoint, frogZHeight: CGFloat) {
        stateTimer += dt
        
        switch state {
        case .submerged:
            // Wait for rise delay, then start rising
            if stateTimer >= riseDelay {
                transitionTo(.rising)
            }
            
        case .rising:
            // Fade in over 1 second
            let riseProgress = min(1.0, stateTimer / 1.0)
            self.alpha = CGFloat(riseProgress)
            
            if riseProgress >= 1.0 {
                transitionTo(.idle)
            }
            
        case .idle:
            // Check if frog is approaching
            let dx = frogPosition.x - position.x
            let dy = frogPosition.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // Show ride indicator when frog is nearby
            rideIndicator.isHidden = distance > detectionRadius * 1.5
            
            // If frog is close and approaching from below (frog is behind/below the crocodile), start fleeing
            // dy < 0 means frog is below (behind) the crocodile, approaching from downstream
            if distance < detectionRadius && dy < 50 {
                transitionTo(.fleeing)
            }
            
            // Gentle bobbing animation
            let bobOffset = sin(stateTimer * 2) * 5  // Slightly bigger bob for bigger croc
            bodySprite.position.y = CGFloat(bobOffset)
            
        case .fleeing:
            // Swim upstream (positive Y direction) - FAST!
            position.y += fleeSpeed
            
            // Slight side-to-side motion while fleeing
            let wiggle = sin(stateTimer * 8) * 4
            position.x += CGFloat(wiggle) * 0.5
            
            // Constrain to river
            constrainToRiver()
            
            // Check if frog is still chasing
            let dx = frogPosition.x - position.x
            let dy = frogPosition.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            // If frog is far away or frog is now ahead of crocodile (croc escaped), return to idle
            // dy > 0 means frog is now ABOVE (ahead of) the crocodile - we escaped!
            if distance > detectionRadius * 2.5 || dy > 100 {
                if stateTimer > 1.5 {
                    transitionTo(.idle)
                }
            }
            
        case .carrying:
            carryTimer += dt
            
            // Swim upstream while carrying - good speed for the ride!
            position.y += swimSpeed * 1.5
            SoundManager.shared.play("crocodileMashing")

            // Apply player steering
            let steerSpeed: CGFloat = 4.0
            position.x += steerDirection * steerSpeed
            
            // Decay steering input (requires continuous tapping)
            steerDirection *= 0.9
            
            constrainToRiver()
            
            // Show remaining time via indicator color
            let progress = carryTimer / Crocodile.carryDuration
            let green = CGFloat(1.0 - progress)
            let red = CGFloat(progress)
            rideIndicator.strokeColor = UIColor(red: red, green: green, blue: 0, alpha: 1)
            rideIndicator.fillColor = UIColor(red: red, green: green, blue: 0, alpha: 0.2)
            rideIndicator.isHidden = false
        }
    }
    
    private func transitionTo(_ newState: CrocodileState) {
        state = newState
        stateTimer = 0
        
        switch newState {
        case .submerged:
            self.alpha = 0
            rideIndicator.isHidden = true
            
        case .rising:
            // Play a subtle ripple effect could be added here
            break
            
        case .idle:
            self.alpha = 1.0
            bodySprite.zRotation = 0
            
        case .fleeing:
            // Point upstream (facing up)
            rideIndicator.isHidden = true
            
        case .carrying:
            carryTimer = 0
            isCarryingFrog = true
            rideIndicator.isHidden = false
            rideIndicator.strokeColor = .green
            rideIndicator.fillColor = .green.withAlphaComponent(0.2)
            
            // Start the carrying animation (cycling through crocodile1-5)
            startCarryingAnimation()
        }
    }
    
    private func startCarryingAnimation() {
        // Stop any existing animation
        bodySprite.removeAction(forKey: carryingAnimationKey)
        
        // Create animation action cycling through crocodile1-5 frames
        let animateAction = SKAction.animate(with: Crocodile.carryingTextures, timePerFrame: 0.15)
        let repeatAnimation = SKAction.repeatForever(animateAction)
        bodySprite.run(repeatAnimation, withKey: carryingAnimationKey)
    }
    
    private func stopCarryingAnimation() {
        // Stop the animation and return to default texture
        bodySprite.removeAction(forKey: carryingAnimationKey)
        bodySprite.texture = Crocodile.crocodileTexture
    }
    
    /// Called when frog lands on the crocodile
    func startCarrying() {
        transitionTo(.carrying)
    }
    
    /// Steer the crocodile left or right while riding
    /// - Parameter direction: -1 for left, 1 for right
    func steer(_ direction: CGFloat) {
        guard state == .carrying else { return }
        steerDirection = direction
    }
    
    /// Called when ride is complete or frog jumps off
    func stopCarrying() -> Bool {
        let wasCarrying = isCarryingFrog
        let rideComplete = carryTimer >= Crocodile.carryDuration
        
        isCarryingFrog = false
        carryTimer = 0
        stopCarryingAnimation()
        transitionTo(.idle)
        
        return wasCarrying && rideComplete
    }
    
    /// Check if the ride duration is complete
    func isRideComplete() -> Bool {
        return state == .carrying && carryTimer >= Crocodile.carryDuration
    }
    
    /// Returns remaining ride time
    func remainingRideTime() -> TimeInterval {
        return max(0, Crocodile.carryDuration - carryTimer)
    }
    
    /// Makes the crocodile submerge underwater and disappear
    func submergeAndDisappear() {
        state = .submerged
        isCarryingFrog = false
        rideIndicator.isHidden = true
        stopCarryingAnimation()
        
        // Animate sinking and fading out
        let sink = SKAction.moveBy(x: 0, y: -20, duration: 0.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let group = SKAction.group([sink, fadeOut])
        let remove = SKAction.removeFromParent()
        
        run(SKAction.sequence([group, remove]))
    }
}

// MARK: - Flotsam (Floating Debris)
class Flotsam: GameEntity {
    
    // Note: You will need to add these images to your asset catalog.
    private static let debrisImages = ["bottle", "boot", "twig"]
    
    init(position: CGPoint) {
        // Choose a random texture for the debris
        let imageName = Flotsam.debrisImages.randomElement() ?? "twig"
        let texture = SKTexture(imageNamed: imageName)
        
        super.init(texture: texture, color: .clear, size: texture.size())
        
        self.position = position
        self.zPosition = 0 // Relative to its parent node
        
        // Randomize appearance for variety
        self.setScale(CGFloat.random(in: 0.2...0.3))
        self.zRotation = CGFloat.random(in: 0...CGFloat.pi * 2)
        self.alpha = CGFloat.random(in: 0.7...0.9)
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    
    /// Sets the debris floating downstream with a gentle animation.
    func float() {
        // Animate floating a very long distance downstream.
        // The GameScene's cleanup logic will handle removing it when it's far off-screen.
        let moveAction = SKAction.moveBy(x: CGFloat.random(in: -40...40), y: -4000, duration: TimeInterval.random(in: 80...120))
        
        // Animate a slow, gentle rotation.
        let rotateAmount = CGFloat.random(in: -2.0...2.0)
        let rotateAction = SKAction.rotate(byAngle: rotateAmount, duration: moveAction.duration)
        
        // Run both animations at the same time.
        let group = SKAction.group([moveAction, rotateAction])
        self.run(group)
    }
}

// MARK: - Boat (for Race Mode)
class Boat: GameEntity {
    
    // Assumes "boat.png" exists in the asset catalog
    private let boatSprite = SKSpriteNode(imageNamed: "boat")
    
    // Veering state
    private var veerTimer: TimeInterval = 0
    private var veerDirection: CGFloat = 0
    // Increased veer speed for a more noticeable reaction to being hit.
    private let veerSpeed: CGFloat = 500.0
    private let originalX: CGFloat
    
    // Wake particle emitter
    private var wakeEmitter: SKEmitterNode?
    
    init(position: CGPoint, wakeTargetNode: SKNode? = nil) {
        self.originalX = position.x
        super.init(texture: nil, color: .clear, size: CGSize(width: 80, height: 150))
        self.position = position
        self.zPosition = Layer.pad + 2 // Above pads, but can be behind frog
        
        setupVisuals()
        setupWakeEmitter(targetNode: wakeTargetNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupVisuals() {
        boatSprite.size = self.size
        addChild(boatSprite)
        
        // Add a subtle bobbing animation
        let moveUp = SKAction.moveBy(x: 0, y: 3, duration: 1.2)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = moveUp.reversed()
        let bob = SKAction.sequence([moveUp, moveDown])
        run(SKAction.repeatForever(bob))
    }
    
    /// Sets up the wake particle emitter.
    private func setupWakeEmitter(targetNode: SKNode?) {
        guard let target = targetNode,
              let emitter = SKEmitterNode(fileNamed: "BoatWake.sks") else {
            return
        }
        
        // The targetNode makes particles emit into the world space,
        // leaving a trail behind the moving boat.
        emitter.targetNode = target
        
        // Position the emitter at the back of the boat.
        emitter.position = CGPoint(x: 0, y: -size.height / 2 + 10)
        emitter.zPosition = -1 // Behind the boat sprite but in front of water
        
        // Store and add the emitter
        self.wakeEmitter = emitter
        addChild(emitter)
    }
    
    func update(dt: TimeInterval) {
        // The boat moves at a constant speed upstream
        position.y += Configuration.GameRules.boatSpeed
        
        // Handle veering logic
        if veerTimer > 0 {
            position.x += veerDirection * veerSpeed * CGFloat(dt)
            veerTimer -= dt
        } else {
            // Smoothly return to original path
            let returnSpeed: CGFloat = 0.05
            position.x += (originalX - position.x) * returnSpeed
        }
        
        // Constrain to river bounds
        let halfWidth = size.width / 2
        if position.x < halfWidth {
            position.x = halfWidth
        } else if position.x > Configuration.Dimensions.riverWidth - halfWidth {
            position.x = Configuration.Dimensions.riverWidth - halfWidth
        }
    }
    
    /// Triggers the boat to veer off course when hit by the frog.
    func hitByFrog(frogPosition: CGPoint) {
        veerTimer = 1.0 // Veer for 1 second
        
        // Veer away from the frog's horizontal position
        veerDirection = (self.position.x > frogPosition.x) ? 1.0 : -1.0
    }
}
