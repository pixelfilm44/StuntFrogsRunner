import SpriteKit

// MARK: - Z-Position Constants
struct Layer {
    static let water: CGFloat = 0
    static let pad: CGFloat = 10
    static let shadow: CGFloat = 15
    static let item: CGFloat = 20 // Coins, Enemies
    static let frogCharacter: CGFloat = 30
    static let trajectory: CGFloat = 800 // High above game elements, below UI
    static let overlay: CGFloat = 900 // Below UI, above everything else
    static let ui: CGFloat = 1000
    static let frog: CGFloat = 30
}

enum RocketState {
    case none
    case flying
    case landing
    case descending  // Playing explosion and fall animations
}

enum FrogAnimationState {
    case sitting
    case jumping
    case recoiling   // Hit by enemy
    case cannon     // Cannon jump
    case eating     // Eating a fly
    case splat      // Flattened/impact pose
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
    
    private var physicsAccumulator: TimeInterval = 0
    private let fixedDelta: TimeInterval = 1.0 / 60.0
    // Cannon Jump State
    var isCannonJumpArmed: Bool = false
    var isCannonJumping: Bool = false
    
    var buffs = Buffs()
    
    var rocketState: RocketState = .none
    var rocketTimer: TimeInterval = 0
    var landingTimer: TimeInterval = 0
    var justLandedFromRocket: Bool = false  // Flag to preserve falling animation after rocket landing
    
    var maxHealth: Int = 3
    var currentHealth: Int = 3
    var isInvincible: Bool = false
    var invincibilityTimer: TimeInterval = 0
    var isComboInvincible: Bool = false  // Invincibility from 25+ combo streak
    var recoilTimer: TimeInterval = 0  // Timer for recoil animation duration
    var eatingTimer: TimeInterval = 0  // Timer for eating animation duration
    var splatTimer: TimeInterval = 0   // Timer for splat animation duration
    
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
    
    // PERFORMANCE: Track accumulated time for bobbing animation instead of querying Date()
    private var accumulatedTime: TimeInterval = 0
    
    // Visual nodes
    let bodyNode = SKNode()  // Container for the sprite
    private let frogSprite = SKSpriteNode()
    private let shadowNode = SKShapeNode(ellipseOf: CGSize(width: 40, height: 20))
    private let vestNode = SKShapeNode(circleOfRadius: 22)
    private let superAura = SKShapeNode()
    private let rocketSprite = SKSpriteNode()
    private var smokeEmitter: SKEmitterNode?
    
    // Preloaded textures for performance
    private static let sitTexture = SKTexture(imageNamed: "frogSit")
    private static let sitLvTexture = SKTexture(imageNamed: "frogSitLv")
    private static let recoilTexture = SKTexture(imageNamed: "frogRecoil")
    private static let cannonTexture = SKTexture(imageNamed: "cannon")
    private static let splatTexture = SKTexture(imageNamed: "frogSplat")
    private static let splatLvTexture = SKTexture(imageNamed: "frogSplatLv")
    private static let drowningTextures: [SKTexture] = [
        SKTexture(imageNamed: "frogDrown1"),
        SKTexture(imageNamed: "frogDrown2"),
        SKTexture(imageNamed: "frogDrown3")
    ]
    private static let desertDrownTexture = SKTexture(imageNamed: "frogDrown4")
    
    // MARK: - Jump Animation Texture Sets (Combo-Based)
    // Base jump animations (combo 0-2)
    private static let jumpAnimationTextures: [SKTexture] = {
        (1...6).map { SKTexture(imageNamed: "frogJump\($0)") }
    }()
    private static let jumpLvAnimationTextures: [SKTexture] = {
        (1...6).map { SKTexture(imageNamed: "frogJumpLv\($0)") }
    }()
    
    // Cool jump animations (combo 3-5) - Try alternative sets, fallback to base
    private static let jumpCoolAnimationTextures: [SKTexture] = {
        #if DEBUG
        print("🔍 INITIALIZING Cool Jump Textures...")
        #endif
        // Try to load frogJumpCool1-6, fallback to base if not found
        let textures = (1...6).map { index -> SKTexture in
            let imageName = "frogJumpCool\(index)"
            let texture = SKTexture(imageNamed: imageName)
            
            // Check if texture loaded successfully by checking size
            if texture.size() == .zero {
                #if DEBUG
                print("❌ Missing: \(imageName) (texture size is zero)")
                #endif
                return jumpAnimationTextures[index - 1]
            } else {
                #if DEBUG
                print("✅ Found: \(imageName) - size: \(texture.size())")
                #endif
                return texture
            }
        }
        #if DEBUG
        print("🎯 Loaded \(textures.count) cool jump textures (may include fallbacks)")
        #endif
        return textures
    }()
    private static let jumpCoolLvAnimationTextures: [SKTexture] = {
        #if DEBUG
        print("🔍 INITIALIZING Cool Jump Lv Textures...")
        #endif
        let textures = (1...6).map { index -> SKTexture in
            let imageName = "frogJumpCoolLv\(index)"
            let texture = SKTexture(imageNamed: imageName)
            
            if texture.size() == .zero {
                #if DEBUG
                print("❌ Missing: \(imageName)")
                #endif
                return jumpLvAnimationTextures[index - 1]
            } else {
                #if DEBUG
                print("✅ Found: \(imageName)")
                #endif
                return texture
            }
        }
        return textures
    }()
    
    // Wild jump animations (combo 6-9) - More energetic
    private static let jumpWildAnimationTextures: [SKTexture] = {
        #if DEBUG
        print("🔍 INITIALIZING Wild Jump Textures...")
        #endif
        let textures = (1...6).map { index -> SKTexture in
            let imageName = "frogJumpWild\(index)"
            let texture = SKTexture(imageNamed: imageName)
            
            if texture.size() == .zero {
                #if DEBUG
                print("❌ Missing: \(imageName) - falling back to cool")
                #endif
                return jumpCoolAnimationTextures[index - 1]
            } else {
                #if DEBUG
                print("✅ Found: \(imageName) - size: \(texture.size())")
                #endif
                return texture
            }
        }
        return textures
    }()
    private static let jumpWildLvAnimationTextures: [SKTexture] = {
        #if DEBUG
        print("🔍 INITIALIZING Wild Jump Lv Textures...")
        #endif
        let textures = (1...6).map { index -> SKTexture in
            let imageName = "frogJumpWildLv\(index)"
            let texture = SKTexture(imageNamed: imageName)
            
            if texture.size() == .zero {
                #if DEBUG
                print("❌ Missing: \(imageName)")
                #endif
                return jumpCoolLvAnimationTextures[index - 1]
            } else {
                #if DEBUG
                print("✅ Found: \(imageName)")
                #endif
                return texture
            }
        }
        return textures
    }()
    
    // Extreme jump animations (combo 10+) - Wildest animations
    private static let jumpExtremeAnimationTextures: [SKTexture] = {
        #if DEBUG
        print("🔍 INITIALIZING Extreme Jump Textures...")
        #endif
        let textures = (1...6).map { index -> SKTexture in
            let imageName = "frogJumpExtreme\(index)"
            let texture = SKTexture(imageNamed: imageName)
            
            if texture.size() == .zero {
                #if DEBUG
                print("❌ Missing: \(imageName) - falling back to wild")
                #endif
                return jumpWildAnimationTextures[index - 1]
            } else {
                #if DEBUG
                print("✅ Found: \(imageName) - size: \(texture.size())")
                #endif
                return texture
            }
        }
        return textures
    }()
    private static let jumpExtremeLvAnimationTextures: [SKTexture] = {
        #if DEBUG
        print("🔍 INITIALIZING Extreme Jump Lv Textures...")
        #endif
        let textures = (1...6).map { index -> SKTexture in
            let imageName = "frogJumpExtremeLv\(index)"
            let texture = SKTexture(imageNamed: imageName)
            
            if texture.size() == .zero {
                #if DEBUG
                print("❌ Missing: \(imageName)")
                #endif
                return jumpWildLvAnimationTextures[index - 1]
            } else {
                #if DEBUG
                print("✅ Found: \(imageName)")
                #endif
                return texture
            }
        }
        return textures
    }()
    
    // Eating animation textures
    private static let eatAnimationTextures: [SKTexture] = {
        (1...5).map { SKTexture(imageNamed: "frogEat\($0)") }
    }()
    private static let eatLvAnimationTextures: [SKTexture] = {
        (1...5).map { SKTexture(imageNamed: "frogLvEat\($0)") }
    }()
    
    // Rocket ride animation textures (5 frames)
    private static let rocketRideAnimationTextures: [SKTexture] = {
        (1...5).map { SKTexture(imageNamed: "rocketRide\($0)") }
    }()
    
    // Rocket explosion animation textures (6 frames) - rocket exploding when descending
    private static let rocketExplodeAnimationTextures: [SKTexture] = {
        (1...6).map { SKTexture(imageNamed: "rocketExplode\($0)") }
    }()
    
    // Frog falling animation textures (8 frames) - frog falling after rocket explosion
    private static let frogFallAnimationTextures: [SKTexture] = {
        (1...8).map { SKTexture(imageNamed: "frogFall\($0)") }
    }()
    private static let frogFallLvAnimationTextures: [SKTexture] = {
        (1...8).map { SKTexture(imageNamed: "frogLvFall\($0)") }
    }()

    
    // Target heights for frog sprite (aspect ratio preserved automatically)
    private static let frogSitHeight: CGFloat = 40
    private static let frogJumpingHeight: CGFloat = 80
    private static let frogRecoilHeight: CGFloat = 60
    private static let cannonHeight: CGFloat = 60
    private static let frogEatHeight: CGFloat = 40
    private static let frogFallHeight: CGFloat = 60  // Height for falling animation
    private static let frogSplatHeight: CGFloat = 45  // Height for splat animation (flattened)

    
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
        rocketSprite.texture = Frog.rocketRideAnimationTextures.first
        let rocketTexture = rocketSprite.texture ?? SKTexture(imageNamed: "rocketRide1")
        let rocketTextureSize = rocketTexture.size()
        let rocketTargetHeight: CGFloat = 150
        let rocketAspectRatio = rocketTextureSize.width / rocketTextureSize.height
        rocketSprite.size = CGSize(width: rocketTargetHeight * rocketAspectRatio, height: rocketTargetHeight)
        rocketSprite.position = CGPoint(x: 0, y: -30)  // Position below the frog
        rocketSprite.zPosition = -1  // Behind the frog sprite
        rocketSprite.isHidden = true
        
       
        
        // Setup smoke trail emitter (hidden by default)
        setupSmokeEmitter()
        
        bodyNode.addChild(rocketSprite)
        
        // Setup frog sprite with initial sitting texture
        // Use aspect-fit sizing to preserve image ratio
        setFrogTexture(Frog.sitTexture, height: Frog.frogSitHeight)
        bodyNode.addChild(frogSprite)
        
      
    }
    
    /// Sets up the smoke trail emitter for the rocket
    private func setupSmokeEmitter() {
        // Create a lightweight, performant smoke emitter
        let emitter = SKEmitterNode()
        
        // Try to use a particle texture if available, otherwise use a simple circle
        let particleTexture = SKTexture(imageNamed: "smokeParticle")
        if particleTexture.size().width > 0 {
            emitter.particleTexture = particleTexture
        }
        
        // Emission configuration - BILLOWING SMOKE
        emitter.particleBirthRate = 0  // Start at 0, will be set when rocket activates
        emitter.particleLifetime = 2.0  // Long lifetime for smoke that lingers
        emitter.particleLifetimeRange = 0.6
        
        // Position emitter at the rocket exhaust
        emitter.position = CGPoint(x: 0, y: 0)
        emitter.zPosition = 0  // Emitter's own z-position (relative to rocketSprite)
        
        // CRITICAL: Set particle z-position in the target node's coordinate space
        // This ensures particles render above lilypads (Layer.pad = 10) when targetNode is set to scene
        emitter.particleZPosition = Layer.shadow  // Above lilypads, below frog
        
        // Emission angle and spread - WIDE for billowing effect
        emitter.emissionAngle = -.pi / 2  // Point downward
        emitter.emissionAngleRange = .pi / 2.5  // Very wide spread for billowing
        
        // Particle movement - SLOWER for smoke-like behavior
        emitter.particleSpeed = 40  // Slower initial speed
        emitter.particleSpeedRange = 25  // Lots of variation
        
        // Visual appearance - SOFT AND BILLOWY
        emitter.particleAlpha = 0.5  // Start more transparent for soft look
        emitter.particleAlphaSpeed = -0.25  // Very slow fade
        emitter.particleScale = 1.5  // Start large
        emitter.particleScaleSpeed = 0.4  // Grow significantly (smoke expands)
        emitter.particleScaleRange = 0.6  // Lots of size variation
        
        // Color - Soft white/gray smoke that darkens
        emitter.particleColor = UIColor(white: 0.95, alpha: 1.0)  // Start very light
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            UIColor(white: 0.95, alpha: 1.0),  // Very light start
            UIColor(white: 0.8, alpha: 1.0),   // Lighter gray
            UIColor(white: 0.65, alpha: 1.0),  // Medium gray
            UIColor(white: 0.5, alpha: 1.0)    // Darker gray at end
        ], times: [0, 0.25, 0.6, 1.0])
        
        // Blend mode for soft, realistic smoke
        emitter.particleBlendMode = .alpha
        
        // Add rotation for more natural smoke swirl
        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 0.5
        
        // DON'T set targetNode here - it will be set when the rocket starts
        // because self.parent might be nil at this point
        
        rocketSprite.addChild(emitter)
        self.smokeEmitter = emitter
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
            // PERFORMANCE: Accumulate time once for all animation calculations
            accumulatedTime += dt
            
            // Timer logic handles raw time (unaffected by physics integration)
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
            
            if recoilTimer > 0 { recoilTimer = max(0, recoilTimer - dt) }
            if eatingTimer > 0 { eatingTimer = max(0, eatingTimer - dt) }
            if splatTimer > 0 { splatTimer = max(0, splatTimer - dt) }
            
            vestNode.isHidden = (buffs.vest == 0)
            
            if rocketState != .none {
                updateRocketPhysics(dt: dt)
                updateVisuals()
                return
            }
            
            // --- FIXED TIMESTEP LOGIC STARTS HERE ---
            
            // 1. Accumulate the time passed
            physicsAccumulator += dt
            
            // 2. Cap the accumulator to prevent "spiral of death" if the game freezes for a long time
            // (If the game lags for 1 second, don't try to run 60 physics steps in one frame)
            if physicsAccumulator > 0.1 {
                physicsAccumulator = 0.1
            }
            
            // 3. Consume the accumulated time in fixed 1/60th second chunks
            while physicsAccumulator >= fixedDelta {
                performFixedPhysicsStep(weather: weather)
                physicsAccumulator -= fixedDelta
            }
            
            constrainToRiver()
            updateVisuals()
        }
    func descend() {
        rocketState = .descending  // Changed from .none to .descending
        rocketTimer = 0
        landingTimer = 0
        velocity.dx = 0
        velocity.dy = 2.5  // Keep drifting forward slowly during descent
        zVelocity = -32.0
        
        // Play the 6-frame descend animation
        playDescendAnimation()
    }
    
    private func performFixedPhysicsStep(weather: WeatherType) {
            // Since this runs exactly 60 times per second of game time,
            // dt is always 1/60, so (dt * 60.0) is always 1.0.
            // We remove the multiplication to simplify.
            
            position.x += velocity.dx
            position.y += velocity.dy
            zHeight += zVelocity
            
            if zHeight > 0 {
                // Airborne Logic
                let gravity = weather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ
                
                // Apply Gravity (per fixed frame)
                zVelocity -= gravity
                
                // Apply Air Friction (per fixed frame)
                // Use the base friction constant directly since we are in a fixed step
                velocity.dx *= Configuration.Physics.frictionAir
                velocity.dy *= Configuration.Physics.frictionAir
                
            } else {
                // Grounded Logic
                zHeight = 0
                if isFloating {
                    velocity.dx *= 0.9
                    velocity.dy *= 0.9
                } else {
                    var currentFriction = Configuration.Physics.frictionGround
                    if let pad = onPad {
                        // Moving pad logic - handled per fixed frame
                        if pad.type == .moving || pad.type == .waterLily || pad.type == .log {
                            position.x += pad.moveSpeed * pad.moveDirection
                        }
                        let isIce = (pad.type == .ice)
                        if (isRainEffectActive || isIce) && !isWearingBoots {
                            currentFriction = 0.93
                        }
                    }
                    velocity.dx *= currentFriction
                    velocity.dy *= currentFriction
                }
            }
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
    
    /// Plays a splat animation showing the frog flattened/squished
    /// - Parameter duration: How long to show the splat pose (default: 0.3 seconds)
    func playSplatAnimation(duration: TimeInterval = 0.3) {
        // Set splat timer to control animation state
        splatTimer = duration
        
        // Choose texture based on whether the frog is wearing a vest
        let texture = buffs.vest > 0 ? Frog.splatLvTexture : Frog.splatTexture
        
        // Immediately show the splat texture
        setFrogTexture(texture, height: Frog.frogSplatHeight)
        
        // Optional: Add a squish scale effect for extra impact
        bodyNode.removeAction(forKey: "splatSquish")
        let squishDown = SKAction.scaleX(to: 1.3, y: 0.7, duration: 0.05)
        let squishUp = SKAction.scale(to: 1.0, duration: duration - 0.05)
        squishUp.timingMode = .easeOut
        let sequence = SKAction.sequence([squishDown, squishUp])
        bodyNode.run(sequence, withKey: "splatSquish")
        
        // After duration, splatTimer will reach 0 and updateAnimationState will return to sitting
    }
    
    /// Plays a drowning animation where the frog sinks underwater and disappears.
    /// - Parameters:
    ///   - isDesert: If true, plays a simple fall animation instead of drowning
    ///   - completion: Called when the animation finishes
    func playDrowningAnimation(isDesert: Bool = false, completion: @escaping () -> Void) {
        // Stop any running jump animation and reset scale
        frogSprite.removeAction(forKey: "jumpFrameAnimation")
        bodyNode.removeAction(forKey: "jumpScaleAnimation")
        bodyNode.setScale(1.5)
        
        // Stop all movement
        velocity = .zero
        zVelocity = 0
        
        // Disable physics updates during animation
        isInvincible = true
        
        // Desert variant: Simple shrink and fall animation
        if isDesert {
            let duration: TimeInterval = 1.0
            
            // Set the frogDrown4 texture as the frog falls into darkness
            setFrogTexture(Frog.desertDrownTexture, height: Frog.frogSitHeight)
            
            // Shrink the frog while fading out
            let shrink = SKAction.scale(to: 0.0, duration: duration)
            shrink.timingMode = .easeIn
            
            let fadeOut = SKAction.fadeOut(withDuration: duration)
            
            let group = SKAction.group([shrink, fadeOut])
            bodyNode.run(group, completion: completion)
            
            // Also fade the shadow
            shadowNode.run(SKAction.fadeOut(withDuration: duration))
            return
        }
        
        // Normal water drowning animation
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
    
    func playWailingAnimation(isDesert: Bool = false) {
        // Stop any running jump animation and reset scale
        frogSprite.removeAction(forKey: "jumpFrameAnimation")
        bodyNode.removeAction(forKey: "jumpScaleAnimation")
        bodyNode.setScale(1.1)
        
        // Stop all movement
        velocity = .zero
        zVelocity = 0
        
        // Disable physics updates during animation
        isInvincible = true
        
        // Desert variant: Simple shrinking animation (play once)
        if isDesert {
            let shrinkDuration: TimeInterval = 1.0
            
            // Shrink down and fade slightly
            let shrink = SKAction.scale(to: 0.3, duration: shrinkDuration)
            shrink.timingMode = .easeIn
            let fadePartial = SKAction.fadeAlpha(to: 0.3, duration: shrinkDuration)
            
            // Play the shrinking animation once
            let shrinkAnimation = SKAction.group([shrink, fadePartial])
            bodyNode.run(shrinkAnimation, withKey: "wailingAnimation")
            return
        }
        
        // Normal wailing animation for water
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
        
        // Reset any color effects (like red low-health warning)
        frogSprite.colorBlendFactor = 0.0
        frogSprite.color = .clear
        frogSprite.alpha = 1.0
        
        // Create the dramatic spinning fall animation
        let duration: TimeInterval = 1.5
        
        // Rapid spinning (multiple full rotations) - applied to the frog sprite
        let spinCount: CGFloat = 4  // 4 full spins
        let spin = SKAction.rotate(byAngle: spinCount * CGFloat.pi * 2, duration: duration)
        spin.timingMode = .easeIn
        
        // Scale down as falling (getting further away) - applied to the frog sprite
        let scaleDown = SKAction.scale(to: 0.2, duration: duration)
        scaleDown.timingMode = .easeIn
        
        // Fade out near the end - applied to the frog sprite
        let wait = SKAction.wait(forDuration: duration * 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: duration * 0.4)
        let fadeSequence = SKAction.sequence([wait, fadeOut])
        
        // Combine spin, scale, and fade for the FROG SPRITE (the actual visual)
        let frogSpriteAnimation = SKAction.group([spin, scaleDown, fadeSequence])
        
        // Fall down off the screen - applied to main node to move position
        let fallDistance: CGFloat = 600
        let fall = SKAction.moveBy(x: 0, y: -fallDistance, duration: duration)
        fall.timingMode = .easeIn
        
        // Shadow fades quickly as frog falls
        let shadowFade = SKAction.fadeOut(withDuration: duration * 0.3)
        let shadowScale = SKAction.scale(to: 0.1, duration: duration * 0.3)
        let shadowAnimation = SKAction.group([shadowFade, shadowScale])
        
        // Run animations
        shadowNode.run(shadowAnimation)
        frogSprite.run(frogSpriteAnimation)  // Spin, scale, and fade the ACTUAL FROG SPRITE
        self.run(fall) {
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
            // PERFORMANCE FIX: Use accumulated time instead of Date()
            zHeight = 60 + sin(CGFloat(accumulatedTime) * 5) * 5
        } else if rocketState == .descending {
            // During descent animation, continue moving forward slowly
            position.y += velocity.dy * CGFloat(dt) * 60.0
            
            // DON'T update zHeight or zVelocity during descent animation
            // The visual animation controls everything, and physics is frozen
            // Landing will be detected by the animation sequence timing
        }
        constrainToRiver()
    }
    
    private func updateVisuals() {
            // During descent, the animation sequence controls bodyNode position and scale completely
            if !isBeingDragged && rocketState != .descending {
                if isFloating {
                    let bobOffset = sin(CGFloat(accumulatedTime) * 5.0) * 3.0
                    bodyNode.position.y = bobOffset
                } else {
                    bodyNode.position.y = zHeight
                }
                
                // Update facing direction based on movement
                let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
                if speed > 0.5 {
                    lastFacingAngle = atan2(velocity.dy, velocity.dx) - CGFloat.pi / 2
                    bodyNode.zRotation = lastFacingAngle
                } else {
                    bodyNode.zRotation = lastFacingAngle
                }
            }
            
            let shadowScale = max(0, 1.0 - (zHeight / 200.0))
            shadowNode.setScale(shadowScale)
            shadowNode.alpha = 0.3 * shadowScale
            
            // FIX: Completely bypass visibility toggling if descending.
            // The playDescendAnimation sequence has full control over what is shown/hidden.
            if rocketState != .descending {
                
                // Show/hide rocket during rocket ride (only flying or landing)
                let shouldShowRocket = (rocketState == .flying || rocketState == .landing)
                
                let wasRocketHidden = rocketSprite.isHidden
                
                if shouldShowRocket && wasRocketHidden {
                    // Rocket just became visible - start animation and hide frog
                    rocketSprite.run(SKAction.unhide())
                    frogSprite.run(SKAction.hide())
                    startRocketAnimation()
                } else if !shouldShowRocket && !wasRocketHidden {
                    // Rocket just became hidden - stop animation and show frog
                    rocketSprite.removeAllActions()
                    smokeEmitter?.particleBirthRate = 0
                    rocketSprite.run(SKAction.hide())
                    
                    frogSprite.removeAllActions()
                    frogSprite.run(SKAction.sequence([
                        SKAction.run { [weak self] in self?.frogSprite.alpha = 1.0 },
                        SKAction.unhide()
                    ]))
                }
                
                // Only update standard animations if we aren't performing a sequence
                updateAnimationState()
            }
            
            // ... (Super Jump aura logic unchanged) ...
            if isSuperJumping {
                superAura.isHidden = false
                superAura.position.y = bodyNode.position.y
                frogSprite.colorBlendFactor = 0.5
                frogSprite.color = .cyan
                frogSprite.alpha = 1.0
            } else {
                superAura.isHidden = true
                // ... (health flash logic unchanged) ...
                if currentHealth == 1 && invincibilityTimer <= 0 {
                    let flashPhase = Int(Date().timeIntervalSince1970 * 4) % 2
                    frogSprite.colorBlendFactor = flashPhase == 0 ? 0.6 : 0.0
                    frogSprite.color = .red
                    frogSprite.alpha = 1.0
                } else if invincibilityTimer > 0 {
                    frogSprite.colorBlendFactor = 0.0
                    let flash = (invincibilityTimer / 0.1).truncatingRemainder(dividingBy: 2) == 0
                    frogSprite.alpha = flash ? 0.5 : 1.0
                } else {
                    frogSprite.colorBlendFactor = 0.0
                    frogSprite.alpha = 1.0
                }
            }
        }
    /// Starts the 6-frame rocket ride animation
    private func startRocketAnimation() {
        // Create animation with 6 frames
        let frameAnimation = SKAction.animate(with: Frog.rocketRideAnimationTextures, timePerFrame: 0.08)
        let repeatAnimation = SKAction.repeatForever(frameAnimation)
        rocketSprite.run(repeatAnimation, withKey: "rocketAnimation")
        
        // CRITICAL: Set the target node for smoke trail
        // This MUST be the scene (or a world node) so particles stay in place as rocket moves
        if let scene = self.scene {
            smokeEmitter?.targetNode = scene
            #if DEBUG
            print("🚀 Smoke emitter target set to scene")
            #endif
        } else if let parent = self.parent {
            smokeEmitter?.targetNode = parent
            #if DEBUG
            print("🚀 Smoke emitter target set to parent")
            #endif
        } else {
            #if DEBUG
            print("⚠️ WARNING: No target node available for smoke emitter!")
            #endif
        }
        
        // Start smoke trail
        smokeEmitter?.particleBirthRate = 40
        #if DEBUG
        print("🚀 Smoke trail started with birth rate: \(smokeEmitter?.particleBirthRate ?? 0)")
        #endif
    }
    
    /// Plays the rocket explosion and frog falling animations when descending from the rocket
    private func playDescendAnimation() {
            // Stop the repeating rocket animation
            rocketSprite.removeAction(forKey: "rocketAnimation")
            
            // Stop smoke trail
            smokeEmitter?.particleBirthRate = 0
            
            // Hide the shadow during the descent animation
            shadowNode.isHidden = true
            
            // Stop all sound effects and play explosion
            SoundManager.shared.stopAllSoundEffects()
            SoundManager.shared.play("explosion", volume: 1.0)
            
            // Heavy haptic feedback for dramatic explosion
            HapticsManager.shared.playImpact(.heavy)
            
            // Use frame counts to determine duration
            let explosionDuration = 0.28 * Double(Frog.rocketExplodeAnimationTextures.count)
            let fallTexturesCount = Double(Frog.frogFallAnimationTextures.count)
            let fallAnimationDuration = 0.10 * fallTexturesCount
            
            // Total animation duration (use the longer of the two)
            let totalDuration = max(explosionDuration, fallAnimationDuration)
            
            // Landing happens at ~80% through the fall animation (near the end but not quite)
            let landingTime = totalDuration * 0.8
            
            // Setup frog for simultaneous animation
            let setupFrog = SKAction.run { [weak self] in
                guard let self = self else { return }
                
                // CRITICAL: Ensure bodyNode is positioned correctly at current zHeight
                // This is where the descent starts - at the rocket's current altitude
                self.bodyNode.position = CGPoint(x: 0, y: self.zHeight)
                self.bodyNode.setScale(2.5)  // Start LARGE (at high altitude)
                self.bodyNode.zRotation = 0  // Face forward during fall
                
                // Show frog sprite immediately (independent of rocket)
                self.frogSprite.isHidden = false
                self.frogSprite.alpha = 1.0
                self.frogSprite.zPosition = 1  // Above rocket sprite
                self.frogSprite.position = .zero  // Centered in bodyNode
                self.frogSprite.zRotation = 0
                
                // Select textures based on vest status
                let fallTextures = self.buffs.vest > 0 ?
                    Frog.frogFallLvAnimationTextures :
                    Frog.frogFallAnimationTextures
                
                // Set proper size and texture for the frog sprite
                if let firstFrame = fallTextures.first {
                    let textureSize = firstFrame.size()
                    let aspectRatio = textureSize.width / textureSize.height
                    self.frogSprite.size = CGSize(
                        width: Frog.frogFallHeight * aspectRatio,
                        height: Frog.frogFallHeight
                    )
                    self.frogSprite.texture = firstFrame
                }
                
                // Start falling animation on the frog sprite
                let fallAnimation = SKAction.animate(with: fallTextures, timePerFrame: 0.10)
                self.frogSprite.run(fallAnimation, withKey: "fallAnimation")
                
                // PERSPECTIVE SCALING: Start large, shrink to 1.6x size as falling
                // This creates the illusion of falling from altitude toward the ground
                // Landing at 1.6x makes the impact feel more dramatic
                let scaleDown = SKAction.scale(to: 1.6, duration: totalDuration)
                scaleDown.timingMode = .easeIn  // Accelerate as getting closer
                self.bodyNode.run(scaleDown, withKey: "fallScaleAnimation")
                
                // Animate bodyNode position from high altitude (zHeight) to ground (0)
                // This makes the frog visually descend
                let descendToGround = SKAction.moveTo(y: 0, duration: totalDuration)
                descendToGround.timingMode = .easeIn
                self.bodyNode.run(descendToGround, withKey: "fallDescentAnimation")
            }
            
            // Play explosion animation on rocket sprite (in parallel with frog fall)
            // The rocket stays where it is and explodes in place
            let startExplosion = SKAction.run { [weak self] in
                guard let self = self else { return }
                let explodeAnimation = SKAction.animate(with: Frog.rocketExplodeAnimationTextures, timePerFrame: 0.28, resize: false, restore: false)
                self.rocketSprite.run(explodeAnimation, withKey: "rocketExplosion")
            }
            
            // Wait until landing moment
            let waitForLanding = SKAction.wait(forDuration: landingTime)
            
            // Play landing impact at the right moment
            let landingImpact = SKAction.run { [weak self] in
                guard let self = self else { return }
                
                // Play splat sound with a slight delay so explosion can be heard
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    SoundManager.shared.play("splat")
                }
                
                // Trigger landing squish on the pad the frog is on
                if let pad = self.onPad {
                    pad.playLandingSquish()
                }
                
                // Set physics state to grounded
                self.zHeight = 0
                self.zVelocity = 0
            }
            
            // Wait for remaining animation time
            let waitForCompletion = SKAction.wait(forDuration: totalDuration - landingTime)
        
            // Clean up and reset
            let resetState = SKAction.run { [weak self] in
                guard let self = self else { return }
                
                // Clean up rocket completely
                self.rocketSprite.removeAllActions()
                self.rocketSprite.isHidden = true
                self.rocketSprite.texture = Frog.rocketRideAnimationTextures.first
                self.rocketSprite.position = CGPoint(x: 0, y: -30)  // Reset to default position
                self.smokeEmitter?.particleBirthRate = 0
                
                // Reset state flags
                self.rocketState = .none
                self.bodyNode.setScale(1.0)  // Return to normal scale after the 1.6x landing
                self.shadowNode.isHidden = false
                
                // Reset frog sprite visibility
                self.frogSprite.isHidden = false
                self.frogSprite.alpha = 1.0
                self.frogSprite.zPosition = 0  // Back to normal z-position
                self.frogSprite.position = .zero
                self.frogSprite.zRotation = 0
                
                // Show splat animation and keep it indefinitely (until next jump)
                // Set timer to a very large value so it stays in splat state
                self.splatTimer = 999999.0  // Effectively infinite - will be cleared on next jump
                
                // Set the splat texture immediately
                let texture = self.buffs.vest > 0 ? Frog.splatLvTexture : Frog.splatTexture
                self.setFrogTexture(texture, height: Frog.frogSplatHeight)
                self.animationState = .splat
            }
            
            // Run the sequence: setup frog, start both animations, wait for landing, trigger impact, wait for completion, reset
            let sequence = SKAction.sequence([
                setupFrog,
                startExplosion,
                waitForLanding,
                landingImpact,
                waitForCompletion,
                resetState
            ])
            self.run(sequence, withKey: "descendTiming")
        }
    private func updateAnimationState() {
        let newState: FrogAnimationState
        
        // Priority 1: Show splat animation if splatting recently
        if splatTimer > 0 {
            newState = .splat
        }
        // Priority 2: Show eating animation if eating recently
        else if eatingTimer > 0 {
            newState = .eating
        }
        // Priority 3: Show recoil animation if hit recently
        else if recoilTimer > 0 {
            newState = .recoiling
        }
        // Priority 4: Preserve falling animation after rocket descent
        else if justLandedFromRocket {
            // Don't change state - keep the falling animation frame
            return
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
            // If the new state forces a stop (e.g., recoiling, eating, splat), clean up any existing jump animation.
            // Landing animations are stopped by the land() function itself.
            if newState == .recoiling || newState == .eating || newState == .splat {
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
            case .splat:
                // Splat texture is set by playSplatAnimation(), so do nothing here.
                break
            }
        }
    }
    
    /// Selects the appropriate jump animation textures based on combo count
    private func selectJumpAnimationTextures(comboCount: Int) -> [SKTexture] {
        let hasVest = buffs.vest > 0
        
        switch comboCount {
        case 0...2:
            return hasVest ? Frog.jumpLvAnimationTextures : Frog.jumpAnimationTextures
        case 3...5:
            return hasVest ? Frog.jumpCoolLvAnimationTextures : Frog.jumpCoolAnimationTextures
        case 6...9:
            return hasVest ? Frog.jumpWildLvAnimationTextures : Frog.jumpWildAnimationTextures
        default:
            return hasVest ? Frog.jumpExtremeLvAnimationTextures : Frog.jumpExtremeAnimationTextures
        }
    }
    
    /// Adds a lightweight visual particle effect for combo jumps
    private func addComboJumpEffect(comboCount: Int, duration: TimeInterval) {
        // Determine effect intensity based on combo tier
        let particleCount: Int
        let particleColor: UIColor
        
        switch comboCount {
        case 3...5:
            particleCount = 15  // Reduced from 20
            particleColor = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.8)
        case 6...9:
            particleCount = 25  // Reduced from 40
            particleColor = UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 0.8)
        default:
            particleCount = 35  // Reduced from 60
            particleColor = UIColor(red: 1.0, green: 0.3, blue: 0.8, alpha: 0.8)
        }
        
        // Try to load particle texture, skip effect if not found
        let particleTexture = SKTexture(imageNamed: "particle")
        guard particleTexture.size() != .zero else {
            // No particle texture available - that's fine, rotation is enough visual feedback
            return
        }
        
        // Create optimized particle emitter
        let emitter = SKEmitterNode()
        emitter.particleTexture = particleTexture
        emitter.particleBirthRate = CGFloat(particleCount) / CGFloat(duration)
        emitter.numParticlesToEmit = particleCount
        emitter.particleLifetime = CGFloat(duration * 0.6)  // Shorter lifetime
        emitter.particleLifetimeRange = CGFloat(duration * 0.1)
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 80  // Reduced from 100
        emitter.particleSpeedRange = 30  // Reduced from 50
        emitter.particleAlpha = 0.7
        emitter.particleAlphaSpeed = -1.2 / CGFloat(duration)
        emitter.particleScale = 0.25  // Smaller particles
        emitter.particleScaleRange = 0.1
        emitter.particleScaleSpeed = -0.3
        emitter.particleColor = particleColor
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.zPosition = -1
        emitter.targetNode = self.parent  // Particles stay in place as frog moves
        
        frogSprite.addChild(emitter)
        
        // Auto-cleanup
        let wait = SKAction.wait(forDuration: duration)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }
    
    
    func jump(vector: CGVector, intensity: CGFloat, weather: WeatherType, comboCount: Int = 0) {
        // IMPORTANT: Reset the physics accumulator to ensure the jump starts
        // on a clean physics step, matching the trajectory prediction exactly
        physicsAccumulator = 0
        
        resetPullOffset()
        
        // Clear the rocket landing flag when jumping
        justLandedFromRocket = false
        
        // Reset animation state (this will clear any lingering falling animation frame)
        animationState = .jumping
        
        // NOTE: SuperJump multiplier is now applied in GameScene.touchesEnded
        // and updateTrajectoryVisuals to keep trajectory prediction accurate.
        // Do NOT multiply here again to avoid double-application.
        
        // BUGFIX: Clear any residual velocity before applying new jump vector
        // This prevents velocity accumulation from quick successive jumps on slippery surfaces
        self.velocity = .zero
        self.velocity = vector
        var zVel = Configuration.Physics.baseJumpZ * (0.5 + (intensity * 0.5))
        // NOTE: Z velocity scaling for superjump should NOT be applied here.
        // The horizontal vector is already scaled in GameScene.touchesEnded,
        // and the Z velocity is derived from the same intensity parameter.
        // The trajectory prediction and actual jump must use the same physics.
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
            
            // 1. Frame-by-frame animation action - SELECT BASED ON COMBO!
            let textures = selectJumpAnimationTextures(comboCount: comboCount)
            
            // Make cool/wild/extreme animations slower and more dramatic
            let animationSpeedMultiplier: Double
            switch comboCount {
            case 0...2:
                animationSpeedMultiplier = 1.0  // Normal speed
            case 3...5:
                animationSpeedMultiplier = 1.8  // 80% slower for cool animations (was 1.3)
            case 6...9:
                animationSpeedMultiplier = 2.2  // 120% slower for wild animations (was 1.5)
            default:
                animationSpeedMultiplier = 2.5  // 150% slower for extreme animations (was 1.7)
            }
            
            let dramaticAirTime = totalAirTime * animationSpeedMultiplier
            let frameAnimation = SKAction.animate(with: textures, timePerFrame: dramaticAirTime / Double(textures.count), resize: false, restore: true)
            
            // 2. Scaling animation action - MORE DRAMATIC FOR HIGHER COMBOS
            let scaleMultiplier: CGFloat
            switch comboCount {
            case 0...2:
                scaleMultiplier = 1.5
            case 3...5:
                scaleMultiplier = 2.2  // Bigger! (was 1.7)
            case 6...9:
                scaleMultiplier = 2.8  // Much bigger! (was 2.0)
            default:
                scaleMultiplier = 3.5  // HUGE! (was 2.3)
            }
            
            let scaleUp = SKAction.scale(to: scaleMultiplier, duration: timeToPeak)
            scaleUp.timingMode = .easeOut
            let scaleDown = SKAction.scale(to: 1.0, duration: timeToPeak)
            scaleDown.timingMode = .easeIn
            let scaleSequence = SKAction.sequence([scaleUp, scaleDown])
            
            // 3. Add visual particle effect for combo jumps
            if comboCount >= 3 {
                // Add a visual particle effect for combo jumps
                addComboJumpEffect(comboCount: comboCount, duration: totalAirTime)
            }
            
            // 4. Run animations on their respective nodes
            frogSprite.run(frameAnimation, withKey: "jumpFrameAnimation")
            bodyNode.run(scaleSequence, withKey: "jumpScaleAnimation")
        }
        
        SoundManager.shared.play("jump")
    }
    
    func land(on pad: Pad, weather: WeatherType) {
        // Stop jump animation and reset scale immediately on landing
        frogSprite.removeAction(forKey: "jumpFrameAnimation")
        frogSprite.removeAction(forKey: "jumpRotation")
        frogSprite.zRotation = 0  // Reset rotation
        bodyNode.removeAction(forKey: "jumpScaleAnimation")
        bodyNode.setScale(1.0)
        
        // RESET ACCUMULATOR
            physicsAccumulator = 0
        
        bodyNode.removeAction(forKey: "wailingAnimation")
        zVelocity = 0
        zHeight = 0
        self.onPad = pad
        self.isFloating = false
        resetPullOffset()
        
        // Play splat animation on landing (brief impact pose)
        playSplatAnimation(duration: 0.15)
        
        if isCannonJumpArmed {
            animationState = .cannon
            setFrogTexture(Frog.cannonTexture, height: Frog.cannonHeight)
        }
        else if !justLandedFromRocket {
            // Only transition to sitting if we didn't just land from a rocket descent
            // (preserve the falling animation frame in that case)
            animationState = .sitting
            let texture = buffs.vest > 0 ? Frog.sitLvTexture : Frog.sitTexture
            setFrogTexture(texture, height: Frog.frogSitHeight)
        }
        
        let isIce = (pad.type == .ice)
        
        if (isRainEffectActive || isIce) && !isWearingBoots {
            // On slippery surfaces, reduce velocity but cap it to prevent accumulation
            velocity.dx *= 0.5
            velocity.dy *= 0.5
            
            // BUGFIX: Cap slippery velocity to prevent accumulation from successive jumps
            let maxSlipperyVelocity: CGFloat = 2.0
            velocity.dx = max(-maxSlipperyVelocity, min(maxSlipperyVelocity, velocity.dx))
            velocity.dy = max(-maxSlipperyVelocity, min(maxSlipperyVelocity, velocity.dy))
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
        
        // Medium haptic feedback for landing on lilypad
        HapticsManager.shared.playImpact(.medium)
    }
    
    func bounce(weather: WeatherType, comboCount: Int = 0) {
        // High bounce to give time for air jump
        let zVel: CGFloat = 22.0
        zVelocity = zVel
        velocity.dx *= -0.5
        velocity.dy *= -0.5
        
        // --- Dynamic Bounce Animation (same as jump with combo-based textures) ---
        // Use the same gravity as actual physics - reduced in space!
        let gravity = weather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ
        let timeToPeak = (zVel / gravity) / 60.0 // in seconds
        
        if timeToPeak > 0 {
            let totalAirTime = timeToPeak * 2.0
            
            // Select textures based on combo count
            let textures = selectJumpAnimationTextures(comboCount: comboCount)
            
            // Make cool/wild/extreme animations slower and more dramatic
            let animationSpeedMultiplier: Double
            switch comboCount {
            case 0...2:
                animationSpeedMultiplier = 1.0  // Normal speed
            case 3...5:
                animationSpeedMultiplier = 2.8  // 80% slower for cool animations (was 1.3)
            case 6...9:
                animationSpeedMultiplier = 3.2  // 120% slower for wild animations (was 1.5)
            default:
                animationSpeedMultiplier = 2.5  // 150% slower for extreme animations (was 1.7)
            }
            
            let dramaticAirTime = totalAirTime * animationSpeedMultiplier
            let frameAnimation = SKAction.animate(with: textures, timePerFrame: dramaticAirTime / Double(textures.count), resize: false, restore: true)

            // More dramatic scaling for higher combos
            let scaleMultiplier: CGFloat
            switch comboCount {
            case 0...2:
                scaleMultiplier = 1.5
            case 3...5:
                scaleMultiplier = 2.2  // Bigger! (was 1.7)
            case 6...9:
                scaleMultiplier = 2.8  // Much bigger! (was 2.0)
            default:
                scaleMultiplier = 3.5  // HUGE! (was 2.3)
            }
            
            let scaleUp = SKAction.scale(to: scaleMultiplier, duration: timeToPeak)
            scaleUp.timingMode = .easeOut
            let scaleDown = SKAction.scale(to: 1.0, duration: timeToPeak)
            scaleDown.timingMode = .easeIn
            let scaleSequence = SKAction.sequence([scaleUp, scaleDown])

            // Add rotation for combo bounces too!
            if comboCount >= 3 {
                let rotations: CGFloat
                switch comboCount {
                case 3...5:
                    rotations = 1.0  // One full rotation for cool
                case 6...9:
                    rotations = 2.0  // Two rotations for wild
                default:
                    rotations = 3.0  // Three rotations for extreme!
                }
                
                let rotate = SKAction.rotate(byAngle: rotations * .pi * 2, duration: totalAirTime)
                rotate.timingMode = .easeInEaseOut
                frogSprite.run(rotate, withKey: "jumpRotation")
                
                // Add particle effect for combo bounces too
                addComboJumpEffect(comboCount: comboCount, duration: totalAirTime)
            }

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
    
    // MARK: - Motion Lines System
    private var motionLines: [SKSpriteNode] = []
    private let motionLineCount: Int = 3  // Number of trailing lines
    private var motionLineSpawnTimer: TimeInterval = 0
    private let motionLineSpawnInterval: TimeInterval = 0.15  // Spawn a new line every 0.15 seconds
    
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
        // Apply physics multiplier to make hit zone match visual size
        return baseRadius * xScale * Configuration.Dimensions.padPhysicsRadiusMultiplier
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
        self.hueVariation = CGFloat.random(in: -0.15...0.15)
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
    
    /// Checks if this pad is at least `minDistance` away from all pads in the provided array.
    /// - Parameters:
    ///   - pads: Array of existing pads to check against
    ///   - minDistance: Minimum required distance (default: uses Configuration value)
    /// - Returns: True if the pad is far enough from all other pads, false otherwise
    func isFarEnoughFrom(pads: [Pad], minDistance: CGFloat = Configuration.Dimensions.movingPadMinDistance) -> Bool {
        for pad in pads {
            let dx = self.position.x - pad.position.x
            let dy = self.position.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < minDistance {
                return false
            }
        }
        return true
    }
    
    /// Static helper to generate a valid position for a moving lilypad that is at least `minDistance` away from existing pads.
    /// - Parameters:
    ///   - existingPads: Array of existing pads to avoid
    ///   - yPosition: The Y position for the new pad (typically the row position)
    ///   - minDistance: Minimum required distance from other pads (default: uses Configuration value)
    ///   - maxAttempts: Maximum number of attempts to find a valid position (default: 20)
    /// - Returns: A valid position, or nil if no valid position could be found after maxAttempts
    static func generateValidPosition(avoiding existingPads: [Pad], yPosition: CGFloat, minDistance: CGFloat = Configuration.Dimensions.movingPadMinDistance, maxAttempts: Int = 20) -> CGPoint? {
        for _ in 0..<maxAttempts {
            // Generate a random X position within the river bounds
            let padding: CGFloat = 60.0 // Keep pads away from edges
            let randomX = CGFloat.random(in: padding...(Configuration.Dimensions.riverWidth - padding))
            let candidatePosition = CGPoint(x: randomX, y: yPosition)
            
            // Check if this position is far enough from all existing pads
            var isValid = true
            for pad in existingPads {
                let dx = candidatePosition.x - pad.position.x
                let dy = candidatePosition.y - pad.position.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance < minDistance {
                    isValid = false
                    break
                }
            }
            
            if isValid {
                return candidatePosition
            }
        }
        
        // If we couldn't find a valid position after maxAttempts, return nil
        return nil
    }
    
    /// Checks if a Y position is safe for spawning a log (not too close to moving lilypads or other logs).
    /// - Parameters:
    ///   - yPosition: The Y position to check
    ///   - existingPads: Array of existing pads to check against
    ///   - minYDistance: Minimum required Y distance from moving lilypads/logs (default: 80 - reduced for more spawns)
    /// - Returns: True if the Y position is safe for spawning a log
    static func isYPositionSafeForLog(_ yPosition: CGFloat, existingPads: [Pad], minYDistance: CGFloat = 80) -> Bool {
        for pad in existingPads {
            // Only check moving lilypads and existing logs
            // Note: waterLily pads are stationary and don't need spacing requirements
            guard pad.type == .moving || pad.type == .log else { continue }
            
            let dy = abs(yPosition - pad.position.y)
            if dy < minYDistance {
                return false  // Too close to a moving pad or log
            }
        }
        return true
    }
    
    /// Checks if a log at the specified position would collide with any lilypads along its horizontal path.
    /// This checks the entire width of the river since logs move left-to-right.
    /// - Parameters:
    ///   - logPosition: The proposed position for the log
    ///   - existingPads: Array of existing pads to check against
    ///   - safetyMargin: Additional safety margin around pads (default: 30 - reduced for more spawns)
    /// - Returns: True if the log's path is clear of lilypads, false if it would collide
    static func isLogPathClear(at logPosition: CGPoint, existingPads: [Pad], safetyMargin: CGFloat = 30) -> Bool {
        // Log dimensions: width = 120, height = 40
        let logHalfWidth: CGFloat = 60.0
        let logHalfHeight: CGFloat = 20.0
        
        for pad in existingPads {
            // Skip other logs and special pads - we only care about lilypads the frog could be on
            if pad.type == .log || pad.type == .launchPad || pad.type == .warp {
                continue
            }
            
            // Check if this pad is at a similar Y position (vertical overlap)
            let dy = abs(pad.position.y - logPosition.y)
            let verticalOverlapDistance = logHalfHeight + pad.scaledRadius + safetyMargin
            
            if dy < verticalOverlapDistance {
                // This pad is at the same height as the log's path
                // Since logs move horizontally across the entire river width,
                // we need to check if the pad is anywhere along that horizontal line
                
                // A log at position.x will eventually sweep across the entire river
                // So we just need to check if the pad is within the vertical collision zone
                return false  // Path is NOT clear - there's a lilypad in the way
            }
        }
        
        return true  // Path is clear
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
            #if DEBUG
            print("🪵 Log sprite created - texture size: \(texture.size()), sprite size: \(sprite.size), sprite parent: \(sprite.parent != nil)")
            #endif
        } else if type == .ice {
            // Use ice lilypad texture - scale to match physics body
            let texture = Pad.iceTexture
            let sprite = SKSpriteNode(texture: texture)
            // Scale sprite to match the actual pad radius (multiplied by physics multiplier for tighter hit zone)
            let visualDiameter = baseRadius * 2 * Configuration.Dimensions.padPhysicsRadiusMultiplier
            sprite.size = CGSize(width: visualDiameter, height: visualDiameter)
            addChild(sprite)
            self.padSprite = sprite
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
            // Scale sprite to match the actual pad radius (multiplied by physics multiplier for tighter hit zone)
            var visualDiameter = baseRadius * 2 * Configuration.Dimensions.padPhysicsRadiusMultiplier
            
            // Make grave pads (skeletons) at least 2x smaller
            if type == .grave {
                visualDiameter = visualDiameter / 2.0
            }
            
            sprite.size = CGSize(width: visualDiameter, height: visualDiameter)
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
            
            // DISABLE tinting for Space weather to keep the purple/blue texture bright
            if currentWeather == .space {
                sprite.colorBlendFactor = 0.0
                return
            }
            
            // Skip for special pads
            guard type != .launchPad && type != .warp && type != .grave && type != .waterLily && type != .moving else { return }
            
            let hue = 0.33 + hueVariation
            let tintColor = UIColor(hue: hue, saturation: 0.5, brightness: 1.0, alpha: 1.0)
            
            sprite.color = tintColor
            sprite.colorBlendFactor = 0.85
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
            #if DEBUG
            print("🔄 Converting \(type) pad to normal pad due to weather change to \(weather)")
            #endif
            self.type = .normal
            self.moveSpeed = 0 // Stop movement for moving/log pads
            currentWeather = weather // Update tracked weather
            setupVisuals() // Re-render with new appearance
        }
    }
    

        func updateColor(weather: WeatherType, duration: TimeInterval = 0) {
            // 1. Determine the Texture (Keep your existing texture logic)
            let texture: SKTexture
            if type == .log {
                 texture = Pad.logTextureForWeather(weather)
            } else if type == .waterLily || type == .moving {
                 switch weather {
                     case .sunny: texture = Pad.waterLilyTexture
                     case .night: texture = Pad.waterLilyNightTexture
                     case .rain: texture = Pad.waterLilyRainTexture
                     case .winter: texture = Pad.waterLilySnowTexture
                     case .desert: texture = Pad.waterLilySandTexture
                     case .space: texture = Pad.waterLilySpaceTexture
                 }
            } else if type == .shrinking {
                 // ... (Keep your shrinking texture switch) ...
                 switch weather {
                     case .space: texture = Pad.shrinkSpaceTexture
                     default: texture = Pad.shrinkTexture // Simplified for brevity
                 }
            } else if type == .grave {
                // CRITICAL FIX: Grave pads should ALWAYS use the grave texture
                texture = Pad.graveTexture
            } else if type == .ice {
                // Ice pads should keep their ice texture
                texture = Pad.iceTexture
            } else if type == .launchPad {
                // Launch pads keep their special texture
                texture = Pad.launchPadTexture
            } else if type == .warp {
                // Warp pads keep their special texture
                texture = Pad.warpPadTexture
            } else {
                 // Normal pads use weather-based textures
                 switch weather {
                     case .sunny: texture = Pad.dayTexture
                     case .night: texture = Pad.nightTexture
                     case .rain: texture = Pad.rainTexture
                     case .winter: texture = Pad.snowTexture
                     case .desert: texture = Pad.desertTexture
                     case .space: texture = Pad.spaceTexture
                 }
            }

            // 2. Lighting Configuration
            // Since all SKLightNode instances are removed from the scene,
            // we don't need to modify lightingBitMask - nodes will render at full brightness by default.
            // Keeping this line commented out as a reference:
            // let targetMask: UInt32 = (weather == .space) ? 0 : (weather == .night || weather == .rain ? 1 : 0)
            
            // 3. THE FIX: Force "Pure Color" for Space
            // If Space, remove all tinting (White + 0.0 blend).
            let targetColor: SKColor
            let targetBlend: CGFloat
            
            if weather == .space {
                targetColor = .white
                targetBlend = 0.0
            } else {
                // Restore random tint for other weathers
                let hue = 0.33 + hueVariation
                targetColor = UIColor(hue: hue, saturation: 0.5, brightness: 1.0, alpha: 1.0)
                targetBlend = 0.85
            }

            // 4. Apply immediately (Stop using Actions for this, they are unreliable during transitions)
            if let sprite = padSprite {
                sprite.texture = texture
                // Don't modify lightingBitMask - let nodes render at full brightness
                sprite.color = targetColor
                sprite.colorBlendFactor = targetBlend
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
        let squishDown = SKAction.scale(to: 0.75, duration: 0.12)
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
            
            // Update motion lines for moving pads
            updateMotionLines(dt: dt)
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
    
    // MARK: - Motion Lines for Moving Pads
    
    /// Updates the motion lines trailing behind moving pads
    private func updateMotionLines(dt: TimeInterval) {
        // Only show motion lines if the pad is actually moving
        guard moveSpeed > 0 else { return }
        
        motionLineSpawnTimer += dt
        
        // Spawn a new motion line at intervals
        if motionLineSpawnTimer >= motionLineSpawnInterval {
            motionLineSpawnTimer = 0
            spawnMotionLine()
        }
    }
    
    /// Creates and spawns a motion line behind the moving pad
    private func spawnMotionLine() {
        // Limit the number of active motion lines for performance
        if motionLines.count >= motionLineCount {
            // Remove the oldest line
            if let oldestLine = motionLines.first {
                oldestLine.removeFromParent()
                motionLines.removeFirst()
            }
        }
        
        // Create a motion line
        let lineWidth: CGFloat = type == .log ? 80.0 : 40.0
        let lineHeight: CGFloat = 2.0
        let line = SKSpriteNode(color: .white, size: CGSize(width: lineWidth, height: lineHeight))
        
        // Position the line in world space, behind where the pad currently is
        // If moving right (moveDirection = 1), spawn line to the LEFT of current position
        // If moving left (moveDirection = -1), spawn line to the RIGHT of current position
        let trailDistance: CGFloat = type == .log ? 70.0 : 35.0
        let lineWorldX = self.position.x + (-moveDirection * trailDistance)
        let lineWorldY = self.position.y
        
        // Set position in parent's coordinate space (worldNode)
        if let parent = self.parent {
            line.position = CGPoint(x: lineWorldX, y: lineWorldY)
            line.zPosition = Layer.pad - 1  // Behind pads but above water
            line.alpha = 0.6
            line.blendMode = .alpha
            
            parent.addChild(line)
            motionLines.append(line)
            
            // Animate the line: fade out and shrink
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let scaleX = SKAction.scaleX(to: 0.3, duration: 0.5)
            let remove = SKAction.removeFromParent()
            
            let animation = SKAction.group([fadeOut, scaleX])
            let sequence = SKAction.sequence([animation, remove])
            
            line.run(sequence) { [weak self] in
                // Remove from tracking array when animation completes
                if let self = self, let index = self.motionLines.firstIndex(of: line) {
                    self.motionLines.remove(at: index)
                }
            }
        }
    }
    
    
    /// Cleans up motion lines when pad is removed or stops moving
    func cleanupMotionLines() {
        for line in motionLines {
            line.removeFromParent()
        }
        motionLines.removeAll()
    }
}

class Enemy: GameEntity {
    var type: String = "BEE"
    private var originalPosition: CGPoint
    private var angle: CGFloat = 0.0
    private var currentWeather: WeatherType = .sunny
     var enemySprite: SKSpriteNode?
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
        // --- ADD THIS ---
                if currentWeather == .space {
                    self.enemySprite?.color = .white
                    self.enemySprite?.colorBlendFactor = 0.0
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
        
        // After self.enemySprite = sprite:
                if currentWeather == .space {
                    // FIX: Apply to the enemy sprite
                    self.enemySprite?.color = .white
                    self.enemySprite?.colorBlendFactor = 0.0
                    self.enemySprite?.lightingBitMask = 0
                    
                    // FIX: Apply to the root node (self) just in case
                    self.color = .white
                    self.colorBlendFactor = 0.0
                    self.lightingBitMask = 0
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
        if let _ = UIImage(named: "treasureChest") {
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
            #if DEBUG
            print("🌵 Cactus texture missing! Using fallback shape.")
            #endif
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
        
        // Snake sprite
        let textures = Snake.animationTexturesForWeather(currentWeather)
        let texture = textures.first ?? SKTexture(imageNamed: "snake1")
        let textureSize = texture.size()
        
        #if DEBUG
        // Debug print the names of the textures being loaded
        for (i, tex) in textures.enumerated() {
            print("🐍 Attempted to load texture 'snake\(currentWeather)\(i+1)': size = \(tex.size())")
        }
        print("🐍 First snake texture size: \(textureSize)")
        #endif
        
        // Check if texture is valid (has actual image data)
        if textureSize.width > 0 && textureSize.height > 0 {
            #if DEBUG
            print("🐍 Using valid snake texture for sprite")
            #endif
            // Valid texture found - use it
            let targetHeight: CGFloat = 50
            let aspectRatio = textureSize.width / textureSize.height
            bodySprite.size = CGSize(width: targetHeight * aspectRatio, height: targetHeight)
            bodySprite.texture = texture
            bodySprite.zPosition = 1
            addChild(bodySprite)
        } else {
            #if DEBUG
            print("🐍 Snake texture missing or invalid! Drawing fallback or placeholder.")
            #endif
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
        guard let target = targetNode else {
            return
        }
        
        guard let emitter = SKEmitterNode(fileNamed: "BoatWake.sks") else {
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

