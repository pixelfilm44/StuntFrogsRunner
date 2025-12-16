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
    case jumping
    case recoiling   // Hit by enemy
    case cannon     // Cannon jump
    case eating     // Eating a fly
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
    
    struct Buffs: Equatable, Hashable {
        var honey: Int = 0
        var rocketTimer: TimeInterval = 0
        var bootsCount: Int = 0
        var vest: Int = 0
        var axe: Int = 0
        var swatter: Int = 0
        var cross: Int = 0
        var superJumpTimer: TimeInterval = 0
        var cannonJumps: Int = 0

    }
    
    // Cannon Jump State
    var isCannonJumpArmed: Bool = false
    var isCannonJumping: Bool = false
    
    var buffs = Buffs()
    
    var rocketState: RocketState = .none
    var rocketTimer: TimeInterval = 0
    var landingTimer: TimeInterval = 0
    
    var maxHealth: Int = 3
    var currentHealth: Int = 3
    var isInvincible: Bool = false
    var invincibilityTimer: TimeInterval = 0
    var recoilTimer: TimeInterval = 0  // Timer for recoil animation duration
    var eatingTimer: TimeInterval = 0  // Timer for eating animation duration
    
    var onPad: Pad?
    var isFloating: Bool = false
    var isWearingBoots: Bool = false
    var isRainEffectActive: Bool = false // Controlled externally to delay slippery effect during transitions
    
    // FIX: Re-added missing property
    var canJumpLogs: Bool = false
    
    var isSuperJumping: Bool { return buffs.superJumpTimer > 0 }
    
    private var isBeingDragged: Bool = false
    
    // Animation state
    private(set) var animationState: FrogAnimationState = .sitting
    private var lastFacingAngle: CGFloat = 0     // Preserve facing direction
    
    // Visual nodes
    let bodyNode = SKNode()  // Container for the sprite
    private let frogSprite = SKSpriteNode()
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: 40, height: 20))
    private let vestNode = SKShapeNode(circleOfRadius: 22)
    private let superAura = SKShapeNode()
    private let rocketSprite = SKSpriteNode(imageNamed: "rocketRide")
    
    // Preloaded textures for performance
    private static let sitTexture = SKTexture(imageNamed: "frogSit")
    private static let sitLvTexture = SKTexture(imageNamed: "frogSitLv")
    private static let recoilTexture = SKTexture(imageNamed: "frogRecoil")
    private static let cannonTexture = SKTexture(imageNamed: "cannon")
    private static let drowningTextures: [SKTexture] = [
        SKTexture(imageNamed: "frogDrown1"),
        SKTexture(imageNamed: "frogDrown2"),
        SKTexture(imageNamed: "frogDrown3")
    ]
    private static let jumpAnimationTextures: [SKTexture] = {
        (1...6).map { SKTexture(imageNamed: "frogJump\($0)") }
    }()
    private static let jumpLvAnimationTextures: [SKTexture] = {
        (1...6).map { SKTexture(imageNamed: "frogJumpLv\($0)") }
    }()
    
    // Eating animation textures
    private static let eatAnimationTextures: [SKTexture] = {
        (1...5).map { SKTexture(imageNamed: "frogEat\($0)") }
    }()
    private static let eatLvAnimationTextures: [SKTexture] = {
        (1...5).map { SKTexture(imageNamed: "frogLvEat\($0)") }
    }()

    
    // Target heights for frog sprite (aspect ratio preserved automatically)
    private static let frogSitHeight: CGFloat = 40
    private static let frogJumpingHeight: CGFloat = 80
    private static let frogRecoilHeight: CGFloat = 60
    private static let cannonHeight: CGFloat = 60
    private static let frogEatHeight: CGFloat = 40

    
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
        
        // Create blast/star-burst shape for super jump
        let blastPath = createBlastShape(radius: 35, points: 8, innerRadius: 20)
        superAura.path = blastPath
        superAura.fillColor = .cyan.withAlphaComponent(0.3)
        superAura.strokeColor = .cyan
        superAura.lineWidth = 3
        superAura.zPosition = 0
        superAura.isHidden = true
        
        // Pulsing and rotating animation for blast effect
        let scaleUp = SKAction.scale(to: 1.15, duration: 0.25)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.25)
        let pulse = SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown]))
        
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 3.0)
        let rotateForever = SKAction.repeatForever(rotate)
        
        superAura.run(SKAction.group([pulse, rotateForever]))
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
        
      
    }
    
    // Helper function to create a blast/star-burst shape
    private func createBlastShape(radius: CGFloat, points: Int, innerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let angleStep = (.pi * 2) / CGFloat(points)
        
        for i in 0..<points {
            let outerAngle = angleStep * CGFloat(i) - .pi / 2
            let innerAngle = angleStep * CGFloat(i) + angleStep / 2 - .pi / 2
            
            let outerPoint = CGPoint(
                x: cos(outerAngle) * radius,
                y: sin(outerAngle) * radius
            )
            let innerPoint = CGPoint(
                x: cos(innerAngle) * innerRadius,
                y: sin(innerAngle) * innerRadius
            )
            
            if i == 0 {
                path.move(to: outerPoint)
            } else {
                path.addLine(to: outerPoint)
            }
            path.addLine(to: innerPoint)
        }
        
        path.closeSubpath()
        return path
    }
    
    func update(dt: TimeInterval, weather: WeatherType) {
        if buffs.rocketTimer > 0 { buffs.rocketTimer = max(0, buffs.rocketTimer - dt) }
        if buffs.superJumpTimer > 0 { buffs.superJumpTimer = max(0, buffs.superJumpTimer - dt) }
        
        if invincibilityTimer > 0 {
            invincibilityTimer = max(0, invincibilityTimer - dt)
            isInvincible = true
        } else if isSuperJumping {
            isInvincible = true
        } else {
            isInvincible = false
        }
        
        // Update recoil timer
        if recoilTimer > 0 {
            recoilTimer = max(0, recoilTimer - dt)
        }
        
        // Update eating timer
        if eatingTimer > 0 {
            eatingTimer = max(0, eatingTimer - dt)
        }
        
        vestNode.isHidden = (buffs.vest == 0)
        
        if rocketState != .none {
            updateRocketPhysics(dt: dt)
            updateVisuals()
            return
        }
        
        position.x += velocity.dx * CGFloat(dt) * 60.0
        position.y += velocity.dy * CGFloat(dt) * 60.0
        zHeight += zVelocity * CGFloat(dt) * 60.0
        
        if zHeight > 0 {
            // Adjust gravity based on weather - reduced gravity in space for floaty jumps
            let gravity = weather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ
            zVelocity -= gravity * CGFloat(dt) * 60.0
            velocity.dx *= pow(Configuration.Physics.frictionAir, CGFloat(dt) * 60.0)
            velocity.dy *= pow(Configuration.Physics.frictionAir, CGFloat(dt) * 60.0)
        } else {
            zHeight = 0
            if isFloating {
                velocity.dx *= pow(0.9, CGFloat(dt) * 60.0)
                velocity.dy *= pow(0.9, CGFloat(dt) * 60.0)
            } else {
                var currentFriction = Configuration.Physics.frictionGround
                if let pad = onPad {
                    if pad.type == .moving || pad.type == .waterLily || pad.type == .log {
                        position.x += pad.moveSpeed * pad.moveDirection * CGFloat(dt) * 60.0
                    }
                    let isIce = (pad.type == .ice)
                    if (isRainEffectActive || isIce) && !isWearingBoots {
                        currentFriction = 0.93
                    }
                }
                velocity.dx *= pow(currentFriction, CGFloat(dt) * 60.0)
                velocity.dy *= pow(currentFriction, CGFloat(dt) * 60.0)
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
    
    /// Steers the rocket left or right while in rocket mode
    /// - Parameter direction: -1 for left, 1 for right, 0 to stop steering
    func steerRocket(_ direction: CGFloat) {
        guard rocketState != .none else { return }
        let rocketSteeringSpeed: CGFloat = 5.0
        velocity.dx = direction * rocketSteeringSpeed
    }
    
    func hit() {
        invincibilityTimer = 2.0
        isInvincible = true
        recoilTimer = 0.33
    }
    
    /// Plays an eating animation showing the frog eating a fly
    func playEatingAnimation() {
        // Set eating timer to control animation state
        let animationDuration: TimeInterval = 0.45 // 3 frames * 0.15 seconds per frame
        eatingTimer = animationDuration
        
        // Choose textures based on whether the frog is wearing a vest
        let textures = buffs.vest > 0 ? Frog.eatLvAnimationTextures : Frog.eatAnimationTextures
        
        // Create the eating animation
        let timePerFrame = animationDuration / Double(textures.count)
        let frameAnimation = SKAction.animate(with: textures, timePerFrame: timePerFrame, resize: false, restore: false)
        
        // After the animation completes, return to sitting state
        let returnToSit = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.eatingTimer = 0
            // The sitting texture will be set by updateAnimationState when eatingTimer reaches 0
        }
        SoundManager.shared.play("eat")

        let sequence = SKAction.sequence([frameAnimation, returnToSit])
        frogSprite.run(sequence, withKey: "eatingAnimation")
    }
    
    /// Plays a drowning animation where the frog sinks underwater and disappears.
    /// - Parameter completion: Called when the animation finishes
    func playDrowningAnimation(completion: @escaping () -> Void) {
        // Stop any running jump animation and reset scale
        frogSprite.removeAction(forKey: "jumpFrameAnimation")
        bodyNode.removeAction(forKey: "jumpScaleAnimation")
        bodyNode.setScale(1.5)
        
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
        // Stop any running jump animation and reset scale
        frogSprite.removeAction(forKey: "jumpFrameAnimation")
        bodyNode.removeAction(forKey: "jumpScaleAnimation")
        bodyNode.setScale(1.1)
        
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
                self.setFrogTexture(texture, height: Frog.frogSitHeight * 1.5)
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
        // Stop any running jump animation and reset scale
        frogSprite.removeAction(forKey: "jumpFrameAnimation")
        bodyNode.removeAction(forKey: "jumpScaleAnimation")
        bodyNode.setScale(1.0)
        
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
        
        // Instantly update rotation for responsive, smooth slingshot feel
        bodyNode.removeAction(forKey: "pullRotation")
        bodyNode.zRotation = angle
        
        lastFacingAngle = angle  // Store for when drag ends
    }
    
    func resetPullOffset() {
        isBeingDragged = false
        
        // Smooth spring-back animation when releasing
        bodyNode.removeAction(forKey: "pullRotation")
        bodyNode.removeAction(forKey: "resetPullPosition")
        
        let springBack = SKAction.move(to: CGPoint(x: 0, y: zHeight), duration: 0.15)
        springBack.timingMode = .easeOut
        bodyNode.run(springBack, withKey: "resetPullPosition")
        
        shadowNode.position = .zero
        // Preserve last facing direction (rotation stays as is)
    }
    
    private func updateRocketPhysics(dt: TimeInterval) {
        position.x += velocity.dx * CGFloat(dt) * 60.0
        
        // Apply friction only if no steering input is being applied
        // (steering should be set by the game scene based on touch input)
        if velocity.dx.magnitude < 0.1 {
            velocity.dx *= pow(0.9, CGFloat(dt) * 60.0)
        } else {
            // Lighter friction when actively steering
            velocity.dx *= pow(0.95, CGFloat(dt) * 60.0)
        }
        
        if rocketState == .flying {
            rocketTimer = max(0, rocketTimer - dt)
            velocity.dy = 4.0
            position.y += velocity.dy * CGFloat(dt) * 60.0
            zHeight += (60 - zHeight) * 0.1 * CGFloat(dt) * 60.0
            
            if rocketTimer <= 0 {
                rocketState = .landing
                landingTimer = Configuration.GameRules.rocketLandingDuration
            }
        } else if rocketState == .landing {
            landingTimer = max(0, landingTimer - dt)
            if landingTimer <= 0 {
                descend()
                return
            }
            velocity.dy *= pow(0.25, CGFloat(dt) * 60.0)
            if velocity.dy < 0.5 { velocity.dy = 1.5 } // was 0.5
            position.y += velocity.dy * CGFloat(dt) * 60.0
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
                let flash = (invincibilityTimer / 0.1) /* was /10 */.truncatingRemainder(dividingBy: 2) == 0
                frogSprite.alpha = flash ? 0.5 : 1.0
            } else {
                frogSprite.colorBlendFactor = 0.0
                frogSprite.alpha = 1.0
            }
        }
    }
    
    private func updateAnimationState() {
        let newState: FrogAnimationState
        
        // Priority 1: Show eating animation if eating recently
        if eatingTimer > 0 {
            newState = .eating
        }
        // Priority 2: Show recoil animation if hit recently
        else if recoilTimer > 0 {
            newState = .recoiling
        } else {
            // Determine animation based on whether the frog is in the air or not.
            if zHeight <= 0.1 && abs(zVelocity) < 0.1 {
                // On ground / lilypad. Show cannon if armed, otherwise sit.
                if isCannonJumpArmed {
                    newState = .cannon
                } else {
                    newState = .sitting
                }
            } else {
                // In the air, so we are jumping.
                newState = .jumping
            }
        }
        
        // Only update texture or animation if the state has changed.
        if newState != animationState {
            // If the new state forces a stop (e.g., recoiling, eating), clean up any existing jump animation.
            // Landing animations are stopped by the land() function itself.
            if newState == .recoiling || newState == .eating {
                frogSprite.removeAction(forKey: "jumpFrameAnimation")
                bodyNode.removeAction(forKey: "jumpScaleAnimation")
                bodyNode.setScale(1.0)
            }
            
            animationState = newState
            
            switch animationState {
            case .sitting:
                let texture = buffs.vest > 0 ? Frog.sitLvTexture : Frog.sitTexture
                setFrogTexture(texture, height: Frog.frogSitHeight)
            case .jumping:
                // Animation is triggered by jump() or bounce(), so do nothing here.
                break
            case .recoiling:
                setFrogTexture(Frog.recoilTexture, height: Frog.frogRecoilHeight)
            case .cannon:
                setFrogTexture(Frog.cannonTexture, height: Frog.cannonHeight)
            case .eating:
                // Animation is triggered by playEatingAnimation(), so do nothing here.
                break
            }
        }
    }
    
    func jump(vector: CGVector, intensity: CGFloat, weather: WeatherType) {
        resetPullOffset()
        
        // NOTE: SuperJump multiplier is now applied in GameScene.touchesEnded
        // and updateTrajectoryVisuals to keep trajectory prediction accurate.
        // Do NOT multiply here again to avoid double-application.
        
        self.velocity = vector
        let zVel = Configuration.Physics.baseJumpZ * (0.5 + (intensity * 0.5))
        self.zVelocity = zVel
        self.onPad = nil
        self.isFloating = false
        
        // --- Dynamic Jump Animation ---
        // Calculate air time based on physics to sync animations.
        // Assumes physics runs at a consistent 60fps as gravity is not scaled by dt.
        // Use the same gravity as actual physics - reduced in space!
        let gravity = weather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ
        let timeToPeak = (zVel / gravity) / 60.0 // in seconds
        
        if timeToPeak > 0 {
            let totalAirTime = timeToPeak * 2.0
            
            // 1. Frame-by-frame animation action
            let textures = buffs.vest > 0 ? Frog.jumpLvAnimationTextures : Frog.jumpAnimationTextures
            let frameAnimation = SKAction.animate(with: textures, timePerFrame: totalAirTime / Double(textures.count), resize: false, restore: true)
            
            // 2. Scaling animation action
            let scaleUp = SKAction.scale(to: 1.5, duration: timeToPeak)
            scaleUp.timingMode = .easeOut
            let scaleDown = SKAction.scale(to: 1.0, duration: timeToPeak)
            scaleDown.timingMode = .easeIn
            let scaleSequence = SKAction.sequence([scaleUp, scaleDown])
            
            // 3. Run animations on their respective nodes
            frogSprite.run(frameAnimation, withKey: "jumpFrameAnimation")
            bodyNode.run(scaleSequence, withKey: "jumpScaleAnimation")
        }
        
        SoundManager.shared.play("jump")
    }
    
    func land(on pad: Pad, weather: WeatherType) {
        // Stop jump animation and reset scale immediately on landing
        frogSprite.removeAction(forKey: "jumpFrameAnimation")
        bodyNode.removeAction(forKey: "jumpScaleAnimation")
        bodyNode.setScale(1.0)
        
        bodyNode.removeAction(forKey: "wailingAnimation")
        zVelocity = 0
        zHeight = 0
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
            let texture = buffs.vest > 0 ? Frog.sitLvTexture : Frog.sitTexture
            setFrogTexture(texture, height: Frog.frogSitHeight)
        }
        let isIce = (pad.type == .ice)
        
        if (isRainEffectActive || isIce) && !isWearingBoots {
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
    
    func bounce(weather: WeatherType) {
        // High bounce to give time for air jump
        let zVel: CGFloat = 22.0
        zVelocity = zVel
        velocity.dx *= -0.5
        velocity.dy *= -0.5
        
        // --- Dynamic Bounce Animation (same as jump) ---
        // Use the same gravity as actual physics - reduced in space!
        let gravity = weather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ
        let timeToPeak = (zVel / gravity) / 60.0 // in seconds
        
        if timeToPeak > 0 {
            let totalAirTime = timeToPeak * 2.0
            
            let textures = buffs.vest > 0 ? Frog.jumpLvAnimationTextures : Frog.jumpAnimationTextures
            let frameAnimation = SKAction.animate(with: textures, timePerFrame: totalAirTime / Double(textures.count), resize: false, restore: true)

            let scaleUp = SKAction.scale(to: 1.5, duration: timeToPeak)
            scaleUp.timingMode = .easeOut
            let scaleDown = SKAction.scale(to: 1.0, duration: timeToPeak)
            scaleDown.timingMode = .easeIn
            let scaleSequence = SKAction.sequence([scaleUp, scaleDown])

            frogSprite.run(frameAnimation, withKey: "jumpFrameAnimation")
            bodyNode.run(scaleSequence, withKey: "jumpScaleAnimation")
        }
        
        HapticsManager.shared.playImpact(.heavy)
    }
}

// MARK: - Pad / Enemy / Coin (Unchanged)
class Pad: GameEntity {
    enum PadType { case normal, moving, ice, log, grave, shrinking, waterLily, launchPad, warp }
    var type: PadType = .normal
    var moveDirection: CGFloat = 1.0
    var moveSpeed: CGFloat = 2.0
    var hasSpawnedGhost: Bool = false  // Track if grave has already spawned its ghost
    private var padSprite: SKSpriteNode?
    private var shrinkTime: Double = 0
    private var shrinkSpeed: Double = 2.0
    private var currentWeather: WeatherType = .sunny
    private var hueVariation: CGFloat = 0 // Random hue shift for visual diversity
    
    // Preloaded textures for performance
    private static let dayTexture = SKTexture(imageNamed: "lilypadDay")
    private static let nightTexture = SKTexture(imageNamed: "lilypadNight")
    private static let rainTexture = SKTexture(imageNamed: "lilypadRain")
    private static let iceTexture = SKTexture(imageNamed: "lilypadIce")
    private static let snowTexture = SKTexture(imageNamed: "lilypadSnow")
    private static let desertTexture = SKTexture(imageNamed: "lilypadDesert")
    private static let spaceTexture = SKTexture(imageNamed: "lilypadSpace")
    private static let launchPadTexture = SKTexture(imageNamed: "launchPad")
    private static let warpPadTexture = SKTexture(imageNamed: "warpPad")

    private static let graveTexture = SKTexture(imageNamed: "lilypadGrave")
    private static let shrinkTexture = SKTexture(imageNamed: "lilypadShrink")
    private static let shrinkNightTexture = SKTexture(imageNamed: "lilypadShrinkNight")
    private static let shrinkRainTexture = SKTexture(imageNamed: "lilypadShrinkRain")
    private static let shrinkSnowTexture = SKTexture(imageNamed: "lilypadShrinkSnow")
    private static let shrinkSandTexture = SKTexture(imageNamed: "lilypadShrinkSand")
    private static let shrinkSpaceTexture = SKTexture(imageNamed: "lilypadShrinkSpace")
    private static let waterLilyTexture = SKTexture(imageNamed: "lilypadWater")
    private static let waterLilyNightTexture = SKTexture(imageNamed: "lilypadWaterNight")
    private static let waterLilyRainTexture = SKTexture(imageNamed: "lilypadWaterRain")
    private static let waterLilySnowTexture = SKTexture(imageNamed: "lilypadWaterSnow")
    private static let waterLilySandTexture = SKTexture(imageNamed: "lilypadWaterSand")
    private static let waterLilySpaceTexture = SKTexture(imageNamed: "lilypadWaterSpace")
    
    // LOG variants for different weather types
    private static let logSunnyTexture = SKTexture(imageNamed: "log")
    private static let logNightTexture = SKTexture(imageNamed: "logNight")
    private static let logRainTexture = SKTexture(imageNamed: "logRain")
    private static let logWinterTexture = SKTexture(imageNamed: "logWinter")
    private static let logDesertTexture = SKTexture(imageNamed: "logDesert")
    private static let logSpaceTexture = SKTexture(imageNamed: "logSpace")
    
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
        // Generate a subtle random hue variation for visual diversity
        self.hueVariation = CGFloat.random(in: -0.08...0.08)
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
    
    /// Returns the appropriate log texture based on weather
    private static func logTextureForWeather(_ weather: WeatherType) -> SKTexture {
        switch weather {
        case .sunny: return logSunnyTexture
        case .night: return logNightTexture
        case .rain: return logRainTexture
        case .winter: return logWinterTexture
        case .desert: return logDesertTexture
        case .space: return logSpaceTexture
        }
    }
    
    func setupVisuals() {
        if type == .log {
            let texture = Pad.logTextureForWeather(currentWeather)
            let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 120, height: 40))
            addChild(sprite)
            self.padSprite = sprite
        } else if type == .ice {
            // Use ice lilypad texture
            let texture = Pad.iceTexture
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 90, height: 90)
            addChild(sprite)
        } else if type == .launchPad {
            // Launch pad is special - larger and uses its own texture
            let texture = Pad.launchPadTexture
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 120, height: 120)
            addChild(sprite)
            self.padSprite = sprite
            
            // Add a pulsing glow effect to make it stand out
            let pulseUp = SKAction.scale(to: 1.1, duration: 0.8)
            pulseUp.timingMode = .easeInEaseOut
            let pulseDown = SKAction.scale(to: 1.0, duration: 0.8)
            pulseDown.timingMode = .easeInEaseOut
            sprite.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))
        } else if type == .warp {
            // Warp pad - special portal texture with swirling animation
            let texture = Pad.warpPadTexture
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 120, height: 120)
            addChild(sprite)
            self.padSprite = sprite
            
            // Add a swirling rotation effect to make it look active
            let rotate = SKAction.rotate(byAngle: CGFloat.pi * 2, duration: 2.0)
            sprite.run(SKAction.repeatForever(rotate))
            
            // Add a pulsing glow effect
            let pulseUp = SKAction.fadeAlpha(to: 1.0, duration: 0.6)
            pulseUp.timingMode = .easeInEaseOut
            let pulseDown = SKAction.fadeAlpha(to: 0.7, duration: 0.6)
            pulseDown.timingMode = .easeInEaseOut
            sprite.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))
        } else {
            // Use PNG textures for all other pad types
            let texture: SKTexture
            switch type {
            case .grave:
                texture = Pad.graveTexture
            case .shrinking:
                // Use weather-specific shrinking pad texture (starts with sunny/day)
                texture = Pad.shrinkTexture
            case .waterLily, .moving:
                texture = Pad.waterLilyTexture
            default:
                texture = Pad.dayTexture
            }
            
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 90, height: 90)
            addChild(sprite)
            self.padSprite = sprite
        }
        
        // Apply subtle hue variation to all pad types for visual diversity
        applyHueVariation()
    }
    
    /// Applies a subtle hue variation to the pad sprite for visual diversity
    /// Uses color blending which is GPU-accelerated and performant
    private func applyHueVariation() {
        guard let sprite = padSprite else { return }
        
        // Skip hue variation for special pads that need specific appearances
        guard type != .launchPad && type != .warp && type != .grave else { return }
        
        // Convert hue shift to a color (hue variation is in range -0.08 to 0.08)
        // We'll use UIColor to create a subtle tint
        let hue = 0.33 + hueVariation // Base green hue (0.33) with variation
        let tintColor = UIColor(hue: hue, saturation: 0.3, brightness: 1.0, alpha: 1.0)
        
        sprite.color = tintColor
        sprite.colorBlendFactor = 0.15 // Subtle blend to maintain texture detail
    }
    
    /// Converts this pad to a normal pad if its type is incompatible with the given weather
    func convertToNormalIfIncompatible(weather: WeatherType) {
        let shouldConvert: Bool
        
        switch type {
        case .log:
            shouldConvert = !Configuration.Difficulty.logWeathers.contains(weather)
        case .ice:
            shouldConvert = !Configuration.Difficulty.icePadWeathers.contains(weather)
        case .shrinking:
            shouldConvert = !Configuration.Difficulty.shrinkingPadWeathers.contains(weather)
        case .moving:
            shouldConvert = !Configuration.Difficulty.movingPadWeathers.contains(weather)
        default:
            shouldConvert = false // Normal pads, graves, water lilies, special pads can spawn in any weather
        }
        
        if shouldConvert {
            print("🔄 Converting \(type) pad to normal pad due to weather change to \(weather)")
            self.type = .normal
            self.moveSpeed = 0 // Stop movement for moving/log pads
            currentWeather = weather // Update tracked weather
            setupVisuals() // Re-render with new appearance
        }
    }
    
    func updateColor(weather: WeatherType, duration: TimeInterval = 0) {
        guard type == .normal || type == .moving || type == .waterLily || type == .shrinking || type == .log else { return }
        
        // Don't change if already correct
        if weather == currentWeather && padSprite?.texture != nil { return }
        currentWeather = weather
        
        let texture: SKTexture
        if type == .log {
            texture = Pad.logTextureForWeather(weather)
        } else if type == .waterLily || type == .moving {
            switch weather {
            case .sunny:
                texture = Pad.waterLilyTexture
          
            case .night:
                texture = Pad.waterLilyNightTexture
            case .rain:
                texture = Pad.waterLilyRainTexture
            case .winter:
                texture = Pad.waterLilySnowTexture
            case .desert:
                texture = Pad.waterLilySandTexture
            case .space:
                texture = Pad.waterLilySpaceTexture
            }
        } else if type == .shrinking {
            switch weather {
            case .sunny:
                texture = Pad.shrinkTexture
            case .night:
                texture = Pad.shrinkNightTexture
            case .rain:
                texture = Pad.shrinkRainTexture
            case .winter:
                texture = Pad.shrinkSnowTexture
            case .desert:
                texture = Pad.shrinkSandTexture
            case .space:
                texture = Pad.shrinkSpaceTexture
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
            case .desert:
                texture = Pad.desertTexture
            case .space:
                texture = Pad.spaceTexture
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
            
            // Apply hue variation to the new sprite
            applyHueVariation()
        } else {
            sprite.texture = texture
            // Apply hue variation after texture change
            applyHueVariation()
        }
    }
    
    /// Smoothly transforms the pad to its desert variant over a duration.
    func transformToDesert(duration: TimeInterval) {
        // Only transform pads that can change appearance.
        guard type == .normal || type == .moving || type == .shrinking || type == .waterLily else { return }
        
        let newTexture: SKTexture
        if type == .waterLily || type == .moving {
            newTexture = Pad.waterLilySandTexture
        } else if type == .shrinking {
            newTexture = Pad.shrinkSandTexture
        } else {
            newTexture = Pad.desertTexture
        }
        
        // Don't re-transform if it's already the correct texture
        guard let sprite = padSprite, sprite.texture?.hash != newTexture.hash else { return }

        // Create a cross-fade effect
        let crossfadeDuration = duration * 0.9 // Crossfade over most of the duration
        let oldSprite = self.padSprite
        
        let newSprite = SKSpriteNode(texture: newTexture)
        newSprite.size = sprite.size
        newSprite.alpha = 0
        newSprite.zRotation = sprite.zRotation
        addChild(newSprite)
        self.padSprite = newSprite

        // Add a "drying out" effect: colorize to a sandy brown then fade the colorization out.
        let dryColor = SKAction.colorize(with: UIColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0), colorBlendFactor: 0.6, duration: crossfadeDuration * 0.6)
        let normalizeColor = SKAction.colorize(withColorBlendFactor: 0.0, duration: crossfadeDuration * 0.4)
        let colorSequence = SKAction.sequence([dryColor, normalizeColor])
        newSprite.run(colorSequence)
        
        // Fade in the new sprite and fade out the old one.
        newSprite.run(SKAction.fadeIn(withDuration: crossfadeDuration))
        oldSprite?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: crossfadeDuration),
            SKAction.removeFromParent()
        ]))
        
        // After transformation, water lilies become static desert pads.
        if type == .waterLily {
            self.type = .normal
            self.moveSpeed = 0 // Stop moving
        }
    }
    
    /// Plays a subtle squish animation when the frog lands on the pad.
    /// Uses SKAction for GPU-accelerated animation with no performance impact.
    func playLandingSquish() {
        // Don't animate logs or shrinking pads (shrinking has its own animation)
        guard type != .log && type != .shrinking else { return }
        
        if currentWeather == .desert { return }
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
    private var currentWeather: WeatherType = .sunny
    private var enemySprite: SKSpriteNode?
    var isBeingDestroyed: Bool = false  // Flag to prevent multiple collision handling
    
    // Preloaded textures for performance - organized by enemy type and weather
    // BEE variants
    private static let beeSunnyTexture = SKTexture(imageNamed: "bee")
    private static let beeNightTexture = SKTexture(imageNamed: "beeNight")
    private static let beeRainTexture = SKTexture(imageNamed: "beeRain")
    private static let beeWinterTexture = SKTexture(imageNamed: "beeWinter")
    private static let beeDesertTexture = SKTexture(imageNamed: "beeDesert")
    private static let beeSpaceTexture = SKTexture(imageNamed: "beeSpace")
    
    // DRAGONFLY variants
    private static let dragonflySunnyTexture = SKTexture(imageNamed: "dragonfly")
    private static let dragonflyNightTexture = SKTexture(imageNamed: "dragonflyNight")
    private static let dragonflyRainTexture = SKTexture(imageNamed: "dragonflyRain")
    private static let dragonflyWinterTexture = SKTexture(imageNamed: "dragonflyWinter")
    private static let dragonflyDesertTexture = SKTexture(imageNamed: "dragonflyDesert")
    private static let dragonflySpaceTexture = SKTexture(imageNamed: "asteroid")
    
    init(position: CGPoint, type: String = "BEE", weather: WeatherType = .sunny) {
        self.originalPosition = position
        self.currentWeather = weather
        super.init(texture: nil, color: .clear, size: CGSize(width: 30, height: 30))
        self.position = position
        self.type = type
        self.zHeight = 20
        self.zPosition = Layer.item
        setupVisuals()
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    
    /// Returns the appropriate texture for an enemy type based on weather
    private static func textureForEnemy(_ enemyType: String, weather: WeatherType) -> SKTexture {
        switch enemyType {
        case "DRAGONFLY":
            switch weather {
            case .sunny: return dragonflySunnyTexture
            case .night: return dragonflyNightTexture
            case .rain: return dragonflyRainTexture
            case .winter: return dragonflyWinterTexture
            case .desert: return dragonflyDesertTexture
            case .space: return dragonflySpaceTexture
            }
        case "BEE":
            switch weather {
            case .sunny: return beeSunnyTexture
            case .night: return beeNightTexture
            case .rain: return beeRainTexture
            case .winter: return beeWinterTexture
            case .desert: return beeDesertTexture
            case .space: return beeSpaceTexture
            }
        default:
            // For GHOST or unknown types, return bee texture as fallback
            return beeSunnyTexture
        }
    }
    
    private func setupVisuals() {
        let shadow = SKShapeNode(circleOfRadius: 10)
        shadow.fillColor = .black.withAlphaComponent(0.2)
        shadow.strokeColor = .clear
        shadow.position.y = -20
        addChild(shadow)
        
        switch type {
        case "DRAGONFLY", "BEE":
            let texture = Enemy.textureForEnemy(type, weather: currentWeather)
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 30, height: 30)
            addChild(sprite)
            self.enemySprite = sprite
        case "GHOST":
            let ghostSprite = SKSpriteNode(imageNamed: "ghostFrog")
            ghostSprite.size = CGSize(width: 65, height: 65)
            addChild(ghostSprite)
            self.enemySprite = ghostSprite
        default:
            // Unknown type - use bee texture as fallback
            let texture = Enemy.textureForEnemy("BEE", weather: currentWeather)
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: 30, height: 30)
            addChild(sprite)
            self.enemySprite = sprite
        }
    }
    
    /// Updates the enemy's visual appearance when weather changes
    func updateWeather(_ weather: WeatherType) {
        guard weather != currentWeather, let sprite = enemySprite else { return }
        currentWeather = weather
        
        // Ghost frogs don't change with weather
        guard type != "GHOST" else { return }
        
        let newTexture = Enemy.textureForEnemy(type, weather: weather)
        sprite.texture = newTexture
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

// MARK: - Cactus
class Cactus: GameEntity {
    
    /// Whether the cactus has been destroyed
    var isDestroyed: Bool = false
    
    /// Visual nodes
    private let cactusSprite = SKSpriteNode()
    
    /// Current weather (for potential visual variants)
    private var currentWeather: WeatherType = .desert
    
    /// Preloaded textures
    private static let cactusTexture = SKTexture(imageNamed: "cactus")
    private static let cactusDesertTexture = SKTexture(imageNamed: "cactusDesert")
    private static let cactusSandTexture = SKTexture(imageNamed: "cactusSand")
    
    /// Returns the appropriate texture based on weather
    private static func textureForWeather(_ weather: WeatherType) -> SKTexture {
        switch weather {
        case .desert:
            // Try desert-specific texture, fall back to generic cactus
            let desertTexture = cactusDesertTexture
            return desertTexture.size().width > 0 ? desertTexture : cactusTexture
        default:
            return cactusTexture
        }
    }
    
    /// Collision radius
    var scaledRadius: CGFloat { return 20.0 }
    
    init(position: CGPoint, weather: WeatherType = .desert) {
        self.currentWeather = weather
        super.init(texture: nil, color: .clear, size: CGSize(width: 40, height: 50))
        self.position = position
        self.zHeight = 10  // Above the lily pad
        self.zPosition = Layer.item + 1  // Above coins, below frog
        setupVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    
    private func setupVisuals() {
        // Use weather-appropriate cactus texture
        let texture = Cactus.textureForWeather(currentWeather)
        let textureSize = texture.size()
        
        // Check if texture is valid
        if textureSize.width > 0 && textureSize.height > 0 {
            // Valid texture found - use it
            let targetHeight: CGFloat = 45
            let aspectRatio = textureSize.width / textureSize.height
            cactusSprite.size = CGSize(width: targetHeight * aspectRatio, height: targetHeight)
            cactusSprite.texture = texture
            cactusSprite.zPosition = 1
            addChild(cactusSprite)
        } else {
            // Fallback: Create a simple cactus shape if texture is missing
            print("🌵 Cactus texture missing! Using fallback shape.")
            let cactusShape = createFallbackCactus()
            addChild(cactusShape)
        }
        
        // Subtle idle animation - slight sway
        let swayLeft = SKAction.rotate(byAngle: 0.05, duration: 1.5)
        swayLeft.timingMode = .easeInEaseOut
        let swayRight = swayLeft.reversed()
        let swaySequence = SKAction.sequence([swayLeft, swayRight])
        cactusSprite.run(SKAction.repeatForever(swaySequence))
    }
    
    /// Creates a simple cactus shape as fallback if texture is missing
    private func createFallbackCactus() -> SKNode {
        let container = SKNode()
        
        // Main body (vertical rectangle)
        let body = SKShapeNode(rectOf: CGSize(width: 12, height: 40), cornerRadius: 2)
        body.fillColor = UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1.0) // Green
        body.strokeColor = UIColor(red: 0.1, green: 0.4, blue: 0.2, alpha: 1.0) // Dark green
        body.lineWidth = 2
        container.addChild(body)
        
        // Left arm
        let leftArm = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2)
        leftArm.fillColor = body.fillColor
        leftArm.strokeColor = body.strokeColor
        leftArm.lineWidth = 2
        leftArm.position = CGPoint(x: -8, y: 8)
        container.addChild(leftArm)
        
        // Right arm
        let rightArm = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2)
        rightArm.fillColor = body.fillColor
        rightArm.strokeColor = body.strokeColor
        rightArm.lineWidth = 2
        rightArm.position = CGPoint(x: 8, y: 5)
        container.addChild(rightArm)
        
        return container
    }
    
    /// Updates the cactus visual appearance when weather changes
    func updateWeather(_ weather: WeatherType) {
        guard weather != currentWeather else { return }
        currentWeather = weather
        
        // Update texture for new weather
        let newTexture = Cactus.textureForWeather(weather)
        if newTexture.size().width > 0 && newTexture.size().height > 0 {
            cactusSprite.texture = newTexture
        }
    }
    
    /// Destroys the cactus (called when hit by axe)
    func destroy() {
        guard !isDestroyed else { return }
        isDestroyed = true
        
        // Stop any animations
        cactusSprite.removeAllActions()
        
        // Death animation - break apart and fade
        let breakApart = SKAction.group([
            SKAction.scale(to: 0.2, duration: 0.3),
            SKAction.rotate(byAngle: .pi, duration: 0.3),
            SKAction.fadeOut(withDuration: 0.3)
        ])
        let remove = SKAction.removeFromParent()
        
        run(SKAction.sequence([breakApart, remove]))
    }
}

// MARK: - Snake
class Snake: GameEntity {
    
    /// Movement speed (pixels per frame)
    private let moveSpeed: CGFloat = 2.5
    
    /// Visual nodes
    private let bodySprite = SKSpriteNode()
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: 50, height: 20))
    
    /// Current weather
    private var currentWeather: WeatherType = .sunny
    
    /// Animation textures - organized by weather type
    private static let sunnySerpentTextures: [SKTexture] = {
        return (1...5).map { SKTexture(imageNamed: "snake\($0)") }
    }()
    private static let nightSerpentTextures: [SKTexture] = {
        return (1...5).map { SKTexture(imageNamed: "snakeNight\($0)") }
    }()
    private static let rainSerpentTextures: [SKTexture] = {
        return (1...5).map { SKTexture(imageNamed: "snakeRain\($0)") }
    }()
    private static let winterSerpentTextures: [SKTexture] = {
        return (1...5).map { SKTexture(imageNamed: "snakeWinter\($0)") }
    }()
    private static let desertSerpentTextures: [SKTexture] = {
        return (1...5).map { SKTexture(imageNamed: "snakeDesert\($0)") }
    }()
    private static let spaceSerpentTextures: [SKTexture] = {
        return (1...5).map { SKTexture(imageNamed: "snakeSpace\($0)") }
    }()
    
    /// Returns the appropriate animation textures based on weather
    private static func animationTexturesForWeather(_ weather: WeatherType) -> [SKTexture] {
        switch weather {
        case .sunny: return sunnySerpentTextures
        case .night: return nightSerpentTextures
        case .rain: return rainSerpentTextures
        case .winter: return winterSerpentTextures
        case .desert: return desertSerpentTextures
        case .space: return spaceSerpentTextures
        }
    }
    
    /// Animation key
    private let animationKey = "snakeAnimation"
    
    /// Collision radius
    var scaledRadius: CGFloat { return 25.0 }
    
    /// Whether the snake has been destroyed
    var isDestroyed: Bool = false
    
    /// Current scale state (1.0 = normal, 1.2 = on lilypad)
    private var targetScale: CGFloat = 1.0
    private var isOnLilypad: Bool = false
    
    init(position: CGPoint, weather: WeatherType = .sunny) {
        self.currentWeather = weather
        super.init(texture: nil, color: .clear, size: CGSize(width: 60, height: 40))
        self.position = position
        self.zHeight = 5  // Slightly above water level (on lilypads/logs)
        self.zPosition = Layer.item + 2  // Above coins and other items
        setupVisuals()
        startAnimation()
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not be implemented") }
    
    private func setupVisuals() {
        
        // Debug print the names of the textures being loaded
        let textures = Snake.animationTexturesForWeather(currentWeather)
        for (i, tex) in textures.enumerated() {
            print("🐍 Attempted to load texture 'snake\(currentWeather)\(i+1)': size = \(tex.size())")
        }
        
        // Snake sprite
        let texture = textures.first ?? SKTexture(imageNamed: "snake1")
        let textureSize = texture.size()
        print("🐍 First snake texture size: \(textureSize)")
        
        // Check if texture is valid (has actual image data)
        if textureSize.width > 0 && textureSize.height > 0 {
            print("🐍 Using valid snake texture for sprite")
            // Valid texture found - use it
            let targetHeight: CGFloat = 50
            let aspectRatio = textureSize.width / textureSize.height
            bodySprite.size = CGSize(width: targetHeight * aspectRatio, height: targetHeight)
            bodySprite.texture = texture
            bodySprite.zPosition = 1
            addChild(bodySprite)
        } else {
            print("🐍 Snake texture missing or invalid! Drawing fallback or placeholder.")
        }
    }
      
    
    private func startAnimation() {
        // Cycle through snake animation frames for current weather
        let textures = Snake.animationTexturesForWeather(currentWeather)
        let animateAction = SKAction.animate(with: textures, timePerFrame: 0.12)
        let repeatAnimation = SKAction.repeatForever(animateAction)
        bodySprite.run(repeatAnimation, withKey: animationKey)
    }
    
    /// Updates the snake's visual appearance when weather changes
    func updateWeather(_ weather: WeatherType) {
        guard weather != currentWeather else { return }
        currentWeather = weather
        
        // Restart animation with new weather textures
        bodySprite.removeAction(forKey: animationKey)
        startAnimation()
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
        
        // Track if snake is currently on a lilypad
        var currentlyOnLilypad = false
        
        // PERFORMANCE OPTIMIZATION: Only check pads that are within reasonable distance
        // Snakes move horizontally, so we mainly care about pads at similar Y positions
        // Maximum interaction distances: 80 pixels for logs, ~60 pixels for lilypads
        let maxInteractionDistance: CGFloat = 100
        
        // Check for log obstacles - move around them
        // Also check if snake is on top of any lilypad (for scaling effect)
        for pad in pads {
            // Early exit: Skip pads that are too far away vertically
            let dy = abs(position.y - pad.position.y)
            if dy > maxInteractionDistance { continue }
            
            // Now check horizontal distance
            let dx = abs(position.x - pad.position.x)
            
            if pad.type == .log {
                // Log is nearby horizontally and vertically - avoid it
                if dx < 80 && dy < 60 {
                    // Move up or down to avoid the log
                    if position.y < pad.position.y {
                        position.y -= 1.5  // Move down
                    } else {
                        position.y += 1.5  // Move up
                    }
                }
            } else {
                // Check if snake is over a lilypad (not a log)
                // Use a slightly larger detection radius to ensure smooth transitions
                let padRadius = pad.scaledRadius + 10  // Add some buffer
                if dx < padRadius && dy < padRadius {
                    currentlyOnLilypad = true
                }
            }
        }
        
        // Update scale based on whether snake is on a lilypad
        // Use smooth interpolation to avoid sudden changes
        if currentlyOnLilypad != isOnLilypad {
            isOnLilypad = currentlyOnLilypad
            targetScale = isOnLilypad ? 1.2 : 1.0
            
            // Apply smooth scaling animation
            // Remove any existing scale animation to avoid conflicts
            removeAction(forKey: "snakeScaleAnimation")
            
            // Create a smooth scale animation (0.15 seconds for quick but smooth transition)
            let scaleAction = SKAction.scale(to: targetScale, duration: 0.15)
            scaleAction.timingMode = .easeInEaseOut
            run(scaleAction, withKey: "snakeScaleAnimation")
        }
        
        // Constrain X position to stay within river bounds (horizontal constraint)
        // Note: Y position should NOT be constrained - snakes exist at the camera's Y level
        let margin: CGFloat = 30
        if position.x < -margin {
            position.x = -margin
        } else if position.x > Configuration.Dimensions.riverWidth + margin {
            position.x = Configuration.Dimensions.riverWidth + margin
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
    /// Resets the snake for reuse (e.g., from a pool)
    func reset(position: CGPoint, weather: WeatherType = .sunny) {
        self.position = position
        self.zHeight = 5
        self.isDestroyed = false
        self.isOnLilypad = false
        self.targetScale = 1.0

        // Stop all actions on both the main node and bodySprite
        self.removeAllActions()
        bodySprite.removeAllActions()
        
        // Reset scale to normal
        self.setScale(1.0)

        // Ensure bodySprite is visible and set to the first animation frame
        bodySprite.alpha = 1.0
        
        // Update weather if it changed
        if weather != currentWeather {
            currentWeather = weather
            let textures = Snake.animationTexturesForWeather(currentWeather)
            if let firstTexture = textures.first {
                bodySprite.texture = firstTexture
            }
        } else {
            let textures = Snake.animationTexturesForWeather(currentWeather)
            if let firstTexture = textures.first {
                bodySprite.texture = firstTexture
            }
        }
        
        bodySprite.isHidden = false

        // If bodySprite was removed for some reason, re-add it
        if bodySprite.parent == nil {
            addChild(bodySprite)
        }
        // Optionally, ensure shadowNode is present (shouldn't be removed, but safe)
        if shadowNode.parent == nil {
            addChild(shadowNode)
        }
        
        // Restart animation with current weather
        startAnimation()
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
    
    // Speed multiplier for rematches
    var speedMultiplier: CGFloat = 1.1
    
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
        // The boat moves at a constant speed upstream, adjusted by the multiplier
        position.y += Configuration.GameRules.boatSpeed * speedMultiplier
        
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

