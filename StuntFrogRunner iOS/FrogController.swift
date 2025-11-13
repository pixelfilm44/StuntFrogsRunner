//
//  FrogController.swift
//  Top-down lily pad hopping
//

import SpriteKit
import UIKit

class FrogController {
    // Frog nodes
    private(set) var frogSprite: SKSpriteNode!
    // Compatibility shim so existing call sites using `frog` still work
    var frog: SKNode { frogSprite }

    var frogShadow: SKShapeNode!
    
    // Sound controller reference
    private var soundController: SoundController {
        return SoundController.shared
    }
    
    // DROWNING CALLBACK: Notify game scene when frog drowns
    var onDrowned: (() -> Void)?
    
    
    var currentLilyPad: LilyPad? {
        didSet {
            // Unregister from old lily pad
            if let oldPad = oldValue, oldPad !== currentLilyPad {
                oldPad.hasFrog = false
                oldPad.frog = nil
            }
            // Register with new lily pad
            if let newPad = currentLilyPad {
                newPad.hasFrog = true
                newPad.frog = self
            }
        }
    }

    // Position (in world coordinates)
    var position: CGPoint = .zero
    // Velocity (world units per frame)
    var velocity: CGVector = .zero
    
    // Jump state
    var isJumping: Bool = false
    var isGrounded: Bool = true
    var jumpStartPos: CGPoint = .zero
    var jumpTargetPos: CGPoint = .zero
    var jumpProgress: CGFloat = 0  // 0 to 1
    var jumpSpeed: CGFloat = GameConfig.jumpSpeed
    private var cachedJumpDistance: CGFloat = 1.0
    
    // Jump timeout safety mechanism
    private var jumpFrameCount: Int = 0
    private let maxJumpFrames: Int = 300  // 5 seconds at 60 FPS - emergency timeout
    
    // Key for repeating water ripple while floating
    private let waterRippleActionKey = "waterRippleRepeat"
    
    // Power-ups
    var superJumpActive: Bool = false
    var superJumpFramesRemaining: Int = 0
    var pauseSuperJumpCountdown: Bool = false
    var rocketActive: Bool = false
    var rocketFramesRemaining: Int = 0
    var invincible: Bool = false
    var invincibleFramesRemaining: Int = 0
    
    // Life vest state
    var lifeVestCharges: Int = 0
    var inWater: Bool = false
    var isDrowning: Bool = false  // NEW: Track explicit drowning state
    // When true, ignore subsequent water-fall checks until the frog jumps again
    var suppressWaterCollisionUntilNextJump: Bool = false
    
    // Ice sliding state
    var onIce: Bool = false
    var slideVelocity: CGVector = .zero
    var slideDeceleration: CGFloat = 0.95  // How quickly sliding slows down
    var minSlideSpeed: CGFloat = 0.5  // Below this speed, stop sliding
    
    // Super jump visuals
    var superJumpGlow: SKShapeNode?
    var superJumpTrailEmitter: SKEmitterNode?
    
    // Rocket visuals
    var rocketSprite: SKSpriteNode?  // The rocket visual attached to frog
    var rocketTrail: SKShapeNode?
    var rocketFlameEmitter: SKEmitterNode?
    var rocketSmokeEmitter: SKEmitterNode?
    
    // Textures/animations
    private var idleTexture: SKTexture!
    private var jumpTextures: [SKTexture] = []
    private var rocketTextures: [SKTexture] = []
    private var floatingTexture: SKTexture!
    private var sinkingTexture: SKTexture!
    private var scaredTexture: SKTexture!  // newly added
    
    private var jumpFrameDuration: TimeInterval = 0.06  // tweak to taste
    private var rocketFrameDuration: TimeInterval = 0.1  // Duration for each rocket frame
    private let rocketScale: CGFloat = 5.0  // Scale multiplier for rocket animation (minimum 800px width will be enforced)
    
    weak var scene: SKScene?
    
    init(scene: SKScene) {
        self.scene = scene
    }
    
    func setupFrog(sceneSize: CGSize) -> SKNode {
        let container = SKNode()
        container.zPosition = 110  // Above everything else!
        
        // Shadow (shows on water surface - darker/larger when frog is "higher")
        frogShadow = SKShapeNode(circleOfRadius: 20)
        frogShadow.fillColor = UIColor.black.withAlphaComponent(0.8)
        frogShadow.strokeColor = .clear
        frogShadow.zPosition = 0
        container.addChild(frogShadow)
        
        // Load textures
        idleTexture = SKTexture(imageNamed: "frogIdle")
        floatingTexture = SKTexture(imageNamed: "floatingFrog")
        sinkingTexture = SKTexture(imageNamed: "sinkingFrog")
        scaredTexture = SKTexture(imageNamed: "frogScared")  // newly added
        
        // Debug texture loading
        print("🐸 Texture sizes - Idle: \(idleTexture.size()), Floating: \(floatingTexture.size()), Sinking: \(sinkingTexture.size())")
        if floatingTexture.size() == CGSize.zero {
            print("⚠️ Warning: floatingTexture failed to load - check if 'floatingFrog' image exists in bundle")
        }

        // Preload jump frames
        let jumpNames = ["frogJump1", "frogJump2", "frogJump3", "frogJump4"]
        jumpTextures = jumpNames.map { SKTexture(imageNamed: $0) }
        
        // Preload rocket frames with safety limit
        var rocketNames: [String] = []
        let maxFrames = 5 // Safety limit to prevent infinite loop
        
        // Try to load rocket frames until we can't find any more (with safety limit)
        for frameIndex in 1...maxFrames {
            let frameName = "rocketRide\(frameIndex)"
            
            // Use UIImage to check if the asset actually exists first
            if let _ = UIImage(named: frameName) {
                let testTexture = SKTexture(imageNamed: frameName)
                rocketNames.append(frameName)
                print("🚀 Loaded rocket frame: \(frameName) - size: \(testTexture.size())")
            } else {
                print("🚀 No rocket frame found at index \(frameIndex) (asset '\(frameName)' does not exist) - stopping search")
                break
            }
        }
        
        rocketTextures = rocketNames.map { SKTexture(imageNamed: $0) }
        print("🚀 Loaded \(rocketTextures.count) rocket animation frames total")
        
        // Additional validation - let's make sure the textures are actually valid
        for (index, texture) in rocketTextures.enumerated() {
            let size = texture.size()
            print("🚀 Rocket frame \(index + 1): \(rocketNames[index]) - size: \(size)")
        }
        
        if rocketTextures.isEmpty {
            print("❌ CRITICAL: No rocket textures loaded! Rocket animations will not work!")
            print("❌ Make sure you have rocketRide1.png, rocketRide2.png, etc. in your Assets.xcassets")
        }
        
        // Create sprite
        frogSprite = SKSpriteNode(texture: idleTexture)
        // Size to GameConfig.frogSize keeping aspect
        if idleTexture.size().width > 0 && idleTexture.size().height > 0 {
            let base = idleTexture.size()
            let longest = max(base.width, base.height)
            let scale = GameConfig.frogSize / longest
            frogSprite.size = CGSize(width: base.width * scale, height: base.height * scale)
        } else {
            // Fallback size if texture metadata missing
            frogSprite.size = CGSize(width: GameConfig.frogSize, height: GameConfig.frogSize)
        }
        frogSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        frogSprite.zPosition = 1
        container.addChild(frogSprite)
        
        // Ensure starting in idle pose
        playIdle()
        
        return container
    }
    
    private func playIdle() {
        frogSprite.removeAction(forKey: "frogJumpAnim")
        frogSprite.texture = idleTexture
        frogSprite.colorBlendFactor = 0.0
        // Reset scale to baseline for idle; GameScene may apply other scale effects
        frogSprite.setScale(1.0)
    }
    
    /// Public method to set the frog to idle pose
    func setToIdlePose() {
        playIdle()
    }
    
    private func playJumpOnce() {
        guard !jumpTextures.isEmpty else { return }
        frogSprite.removeAction(forKey: "frogJumpAnim")
        let animate = SKAction.animate(with: jumpTextures, timePerFrame: jumpFrameDuration, resize: false, restore: false)
        frogSprite.run(animate, withKey: "frogJumpAnim")
    }
    
    private func playRocketAnimation() {
        guard !rocketTextures.isEmpty else { 
            print("⚠️ No rocket animation frames loaded - rocketTextures is empty!")
            print("⚠️ Expected frames: rocketRide1, rocketRide2, rocketRide3, rocketRide4, rocketRide5")
            return 
        }
        
        print("🚀 Starting rocket animation with \(rocketTextures.count) frames")
        
        // Calculate scale needed to make rocket at least 800 pixels wide
        let targetWidth: CGFloat = 150.0
        let currentSize = frogSprite.size.width
        let neededScale = max(rocketScale, targetWidth / currentSize)
        
        print("🚀 Rocket animation - Current size: \(currentSize), Target: \(targetWidth), Scale: \(neededScale)")
        
        // Remove any existing animations first
        frogSprite.removeAction(forKey: "frogRocketAnim")
        frogSprite.removeAction(forKey: "frogJumpAnim")
        
        // Set the scale to ensure minimum 800px width
        frogSprite.setScale(neededScale)
        
        // Start the rocket animation
        let animate = SKAction.animate(with: rocketTextures, timePerFrame: rocketFrameDuration, resize: false, restore: false)
        frogSprite.run(SKAction.repeatForever(animate), withKey: "frogRocketAnim")
        
        // Add rocket sprite as child node under the frog
        addRocketSprite()
        
        // Create flame and smoke particle effects
        createRocketParticleEffects()
        
        print("🚀 Rocket animation started and running!")
    }
    
    private func stopRocketAnimation() {
        frogSprite.removeAction(forKey: "frogRocketAnim")
        frogSprite.setScale(1.0)
        
        // Remove rocket sprite and particle effects
        removeRocketVisuals()
    }
    
    private func addRocketSprite() {
        // Remove any existing rocket sprite
        rocketSprite?.removeFromParent()
        
        // Create rocket sprite from rocketRide.png
        let rocketTexture = SKTexture(imageNamed: "rocketRide")
        rocketSprite = SKSpriteNode(texture: rocketTexture)
        
        guard let rocket = rocketSprite else { return }
        
        // Size the rocket appropriately relative to the frog
        let rocketSize = CGSize(width: frogSprite.size.width * 0.8, height: frogSprite.size.height * 1.2)
        rocket.size = rocketSize
        
        // Position rocket underneath the frog
        rocket.position = CGPoint(x: 0, y: -frogSprite.size.height * 0.3)
        rocket.zPosition = -1  // Behind the frog
        
        // Add rocket as child of frog sprite
        frogSprite.addChild(rocket)
        
        print("🚀 Rocket sprite added as child node")
    }
    
    private func createRocketParticleEffects() {
        guard let rocket = rocketSprite else { return }
        
        // Create flame emitter
        rocketFlameEmitter = SKEmitterNode()
        if let flameEmitter = rocketFlameEmitter {
            // Flame particle configuration
            flameEmitter.particleTexture = SKTexture(imageNamed: "flame") // Fallback to circle if no flame texture
            flameEmitter.particleBirthRate = 80
            flameEmitter.numParticlesToEmit = 0 // Continuous emission
            flameEmitter.particleLifetime = 0.6
            flameEmitter.particleLifetimeRange = 0.2
            
            // Position at bottom of rocket
            flameEmitter.position = CGPoint(x: 0, y: -rocket.size.height * 0.5)
            flameEmitter.particlePositionRange = CGVector(dx: 20, dy: 5)
            
            // Movement and physics
            flameEmitter.emissionAngle = CGFloat.pi * 1.5 // Downward
            flameEmitter.emissionAngleRange = CGFloat.pi * 0.3
            flameEmitter.particleSpeed = 120
            flameEmitter.particleSpeedRange = 40
            
            // Appearance
            flameEmitter.particleScale = 0.3
            flameEmitter.particleScaleRange = 0.15
            flameEmitter.particleScaleSpeed = -0.8
            flameEmitter.particleAlpha = 0.9
            flameEmitter.particleAlphaSpeed = -1.5
            
            // Color progression: bright orange/yellow to red
            flameEmitter.particleColor = SKColor.orange
            flameEmitter.particleColorBlendFactor = 1.0
            
            // Create color sequence for flame color progression
            let orangeColor = SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.9)
            let redColor = SKColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 0.7)
            let darkRedColor = SKColor(red: 0.8, green: 0.1, blue: 0.0, alpha: 0.3)
            
            let keyframeSequence = SKKeyframeSequence(keyframeValues: [orangeColor, redColor, darkRedColor],
                                                    times: [0.0, 0.5, 1.0])
            flameEmitter.particleColorSequence = keyframeSequence
            
            flameEmitter.zPosition = -2
            rocket.addChild(flameEmitter)
        }
        
        // Create smoke emitter
        rocketSmokeEmitter = SKEmitterNode()
        if let smokeEmitter = rocketSmokeEmitter {
            // Smoke particle configuration
            smokeEmitter.particleTexture = nil // Use default circle
            smokeEmitter.particleBirthRate = 30
            smokeEmitter.numParticlesToEmit = 0 // Continuous emission
            smokeEmitter.particleLifetime = 2.0
            smokeEmitter.particleLifetimeRange = 0.5
            
            // Position slightly behind flame
            smokeEmitter.position = CGPoint(x: 0, y: -rocket.size.height * 0.6)
            smokeEmitter.particlePositionRange = CGVector(dx: 15, dy: 8)
            
            // Movement and physics
            smokeEmitter.emissionAngle = CGFloat.pi * 1.5 // Downward
            smokeEmitter.emissionAngleRange = CGFloat.pi * 0.4
            smokeEmitter.particleSpeed = 60
            smokeEmitter.particleSpeedRange = 30
            
            // Appearance
            smokeEmitter.particleScale = 0.2
            smokeEmitter.particleScaleRange = 0.1
            smokeEmitter.particleScaleSpeed = 0.8 // Grows over time
            smokeEmitter.particleAlpha = 0.6
            smokeEmitter.particleAlphaSpeed = -0.3
            
            // Color: dark gray smoke
            smokeEmitter.particleColor = SKColor.darkGray
            smokeEmitter.particleColorBlendFactor = 1.0
            
            smokeEmitter.zPosition = -3 // Behind flames
            rocket.addChild(smokeEmitter)
        }
        
        print("🚀 Rocket particle effects created")
    }
    
    private func removeRocketVisuals() {
        // Remove particle emitters
        rocketFlameEmitter?.removeFromParent()
        rocketFlameEmitter = nil
        
        rocketSmokeEmitter?.removeFromParent()
        rocketSmokeEmitter = nil
        
        // Remove rocket sprite
        rocketSprite?.removeFromParent()
        rocketSprite = nil
        
        print("🚀 Rocket visuals removed")
    }
    
    /// Shows the scared texture for a short duration, then returns to idle if appropriate
    func showScared(duration: TimeInterval = 1.0) {
        // Don't override rocket visuals
        if rocketActive { return }
        // Set scared texture immediately
        if let scared = scaredTexture, scared.size() != .zero {
            frogSprite.removeAction(forKey: "frogJumpAnim")
            frogSprite.removeAction(forKey: "frogRocketAnim")
            frogSprite.removeAction(forKey: "frogBounce")
            frogSprite.texture = scared
            // Keep scale reasonable during scare
            frogSprite.setScale(1.0)
        }
        // After delay, restore appropriate idle/floating state if not jumping
        let wait = SKAction.wait(forDuration: duration)
        let restore = SKAction.run { [weak self] in
            guard let self = self else { return }
            // If currently in water floating with life vest, keep floating texture
            if self.inWater, let floatTex = self.floatingTexture, floatTex.size() != .zero {
                self.frogSprite.texture = floatTex
                // ensure bob remains if applicable (do not restart here to avoid duplicates)
            } else if !self.isJumping && !self.rocketActive {
                self.playIdle()
            }
        }
        frogSprite.run(SKAction.sequence([wait, restore]), withKey: "frogScaredRestore")
    }
    
    func resetToStartPad(startPad: LilyPad, sceneSize: CGSize) {
        position = startPad.position
        currentLilyPad = startPad
        isGrounded = true
        isJumping = false
        jumpProgress = 0
        velocity = .zero
        inWater = false
        isDrowning = false  // NEW: Reset drowning state
        onIce = false
        slideVelocity = .zero
        suppressWaterCollisionUntilNextJump = false
        frogSprite.texture = idleTexture
        
        // Visual reset
        frogSprite.alpha = 1.0
        frogShadow.alpha = 0.3
        playIdle()
        
        print("Frog reset to starting lily pad at \(position)")
    }
    
    func startJump(to targetPos: CGPoint) {
        jumpStartPos = position
        
        // Note: Jump range multiplier is now applied in SlingshotController for consistent targeting
        // No need to modify the target position here - it's already been calculated correctly
        jumpTargetPos = targetPos
        jumpProgress = 0
        isJumping = true
        isGrounded = false
        jumpFrameCount = 0  // Reset jump timeout counter
        
        // CRITICAL FIX: When starting a jump, clear the water state 
        // This prevents the frog from being stuck in floating mode
        inWater = false
        isDrowning = false
        
        // Stop water bobbing when leaving water to jump
        frogSprite.removeAction(forKey: "frogBob")
        frogSprite.parent?.removeAction(forKey: waterRippleActionKey)
        currentLilyPad = nil
        
        // Any new jump re-enables water detection
        suppressWaterCollisionUntilNextJump = false
        
        // Ensure rotation is unlocked for new jump (in case rocket constraints are still active)
        unlockFacingAfterRocket()
        print("🐸 Starting jump - rotation constraints cleared, water state reset")
        
        let dx = targetPos.x - position.x
        let dy = targetPos.y - position.y
        let distance = max(0.001, sqrt(dx*dx + dy*dy))
        
        // Calculate jump intensity for sound
        let jumpIntensity = min(distance / 200.0, 1.0) // Normalize to 0-1 range
        
        // Play jump sound with intensity-based pitch variation
        soundController.playFrogJumpSound(intensity: Float(jumpIntensity))
        // Face the direction of travel with art correction
        // atan2(dy, dx) gives us the angle to the target
        // Common corrections based on your frog art's default orientation:
        //   0: frog faces right by default
        //   π/2 (90°): frog faces up by default
        //   -π/2 (-90°): frog faces down by default
        //   π/4 (45°): frog faces up-right by default
        let angle = atan2(dy, dx)
        let correction: CGFloat = .pi / 2 // 90 degrees - top of frog faces up in the art
        frogSprite.removeAction(forKey: "face")
        frogSprite.run(SKAction.rotate(toAngle: angle + correction, duration: 0.08, shortestUnitArc: true), withKey: "face")
        // SUPER POWERS: Apply Jump Recoil reduction to speed up jump timing
        jumpSpeed = GameConfig.jumpSpeed
        if let gameScene = scene as? GameScene {
            let recoilReduction = gameScene.uiManager.getJumpRecoilReduction()
            if recoilReduction > 0 {
                // Increase jump speed to reduce hang time (faster jumps)
                let speedMultiplier = 1.0 + (recoilReduction / 10.0) // Convert seconds to speed multiplier
                jumpSpeed *= CGFloat(speedMultiplier)
                print("⚡ Jump Recoil Super Power: Jump speed increased by \(String(format: "%.1f", (speedMultiplier - 1.0) * 100))%")
            }
        
        let dirX = dx / distance
        let dirY = dy / distance
        velocity = CGVector(dx: dirX * jumpSpeed, dy: dirY * jumpSpeed)
        // Cache total distance for visual progress
        cachedJumpDistance = distance
        
        // Play jump animation
        playJumpOnce()
        
        print("Jump started from \(jumpStartPos) to \(jumpTargetPos)")
            let speedMultiplier = 1.0 + (recoilReduction / 10.0) // Convert seconds to speed multiplier

                jumpSpeed *= CGFloat(speedMultiplier)
                print("⚡ Jump Recoil Super Power: Jump speed increased by \(String(format: "%.1f", (speedMultiplier - 1.0) * 100))%")
            }
        
        let dirX = dx / distance
        let dirY = dy / distance
        velocity = CGVector(dx: dirX * jumpSpeed, dy: dirY * jumpSpeed)
        // Cache total distance for visual progress
        cachedJumpDistance = distance
        
        // Play jump animation
        playJumpOnce()
        
        print("Jump started from \(jumpStartPos) to \(jumpTargetPos)")
    }
    
    func updateJump() {
        guard isJumping else { 
            jumpFrameCount = 0  // Reset counter when not jumping
            return 
        }
        
        // Increment jump frame counter and check for timeout
        jumpFrameCount += 1
        if jumpFrameCount > maxJumpFrames {
            print("🚨 EMERGENCY: Jump timeout after \(jumpFrameCount) frames - force completing jump")
            position = jumpTargetPos
            jumpProgress = 1.0
            completeJump()
            return
        }
        
        // Move by velocity toward target
        position.x += velocity.dx
        position.y += velocity.dy
        
        // Compute remaining vector to target
        let rdx = jumpTargetPos.x - position.x
        let rdy = jumpTargetPos.y - position.y
        let remainingDist = sqrt(rdx*rdx + rdy*rdy)
        
        // If we would overshoot next frame, clamp to target and complete
        if remainingDist <= jumpSpeed {
            position = jumpTargetPos
            jumpProgress = 1.0
            completeJump()
        } else {
            // Update synthetic progress for visuals based on traveled distance
            let traveledX = position.x - jumpStartPos.x
            let traveledY = position.y - jumpStartPos.y
            let traveled = sqrt(traveledX*traveledX + traveledY*traveledY)
            jumpProgress = min(1.0, traveled / max(0.001, cachedJumpDistance))
        }
        
        // Update visual "height" effect (shadow and scale)
        updateJumpVisuals()
    }
    
    private func updateJumpVisuals() {
        // Create arc illusion with shadow and scale
        // Shadow gets smaller and lighter as frog "jumps higher"
        // Peak of jump is at 0.5 progress
        
        let heightFactor: CGFloat
        if jumpProgress < 0.5 {
            heightFactor = jumpProgress * 2  // 0 to 1
        } else {
            heightFactor = (1.0 - jumpProgress) * 2  // 1 to 0
        }
        
        // Shadow effect - smaller and lighter when higher
        let shadowScale = 1.0 - (heightFactor * 0.6)
        let shadowAlpha = 0.3 - (heightFactor * 0.2)
        frogShadow.setScale(shadowScale)
        frogShadow.alpha = shadowAlpha
        
        // Frog gets slightly bigger when at peak (closer to camera)
        let frogScale = 2.0 + (heightFactor * 0.3)
        frogSprite.setScale(frogScale)
    }
    
    private func completeJump() {
        isJumping = false
        velocity = .zero
        // Note: Don't set isGrounded yet - need to check lily pad landing first!
        
        // Reset visuals
        frogShadow.setScale(1.0)
        frogShadow.alpha = 0.3
        // Keep the last jump frame until landing logic decides outcome
        
        print("ðŸ¸ Jump completed at \(position)")
    }
    
    
    func splash() {
        isJumping = false
        isGrounded = false
        frogSprite.setScale(1.0)

        // Create a large splash ripple
        if let gameScene = scene as? GameScene {
            // Large amplitude and high frequency for dramatic splash
            gameScene.worldManager.addRipple(at: position, amplitude: 0.045, frequency: 14.0)
        }

        // Check if frog has life vests available for this splash
        if lifeVestCharges > 0 {
            // Do not consume the vest here. Let GameScene decide and manage suppression.
            inWater = true
            isDrowning = false  // Not drowning if we have life vests
            
            // Debug floating texture assignment
            print("🐸 Setting floating texture. Before: \(String(describing: frogSprite.texture)), FloatingTexture: \(String(describing: floatingTexture))")
            frogSprite.texture = floatingTexture ?? idleTexture  // Fallback to idle if floating texture is nil
            print("🐸 After setting floating texture: \(String(describing: frogSprite.texture))")
            
            frogSprite.alpha = 1.0 // keep visible while floating
            // Start bobbing while floating in water
            frogSprite.removeAction(forKey: "frogBob")
            let bobUp = SKAction.moveBy(x: 0, y: 6, duration: 0.6)
            bobUp.timingMode = .easeInEaseOut
            let bobDown = SKAction.moveBy(x: 0, y: -6, duration: 0.6)
            bobDown.timingMode = .easeInEaseOut
            let bobSequence = SKAction.sequence([bobUp, bobDown])
            frogSprite.run(SKAction.repeatForever(bobSequence), withKey: "frogBob")
            
            // Start gentle repeating water ripples while floating
            frogSprite.parent?.removeAction(forKey: waterRippleActionKey)
            if let gameScene = scene as? GameScene {
                let rippleOnce = SKAction.run { [weak gameScene, weak self] in
                    guard let self = self, let gameScene = gameScene else { return }
                    gameScene.worldManager.addRipple(at: self.position, amplitude: 0.012, frequency: 12.0)
                }
                let wait = SKAction.wait(forDuration: 0.8)
                let seq = SKAction.sequence([rippleOnce, wait])
                frogSprite.parent?.run(SKAction.repeatForever(seq), withKey: waterRippleActionKey)
            }
            
            print("Life vest available. Entering water; GameScene will handle rescue.")
        } else {
            // No vest: frog drowns
            // CRITICAL FIX: Even if the frog was previously floating, it should drown without life vests
            inWater = true  // Set to true to indicate drowning state
            isDrowning = true  // NEW: Explicit drowning flag
            isGrounded = false
            frogSprite.setScale(0.9)
            frogSprite.texture = sinkingTexture
            frogSprite.alpha = 0
            frogSprite.removeAction(forKey: "frogBob")
            frogSprite.parent?.removeAction(forKey: waterRippleActionKey)
            
            // Enhanced logging to debug the issue
            print("SPLASH! Fell in water - DROWNING (no life vest available)")
            print("  🐸 lifeVestCharges: \(lifeVestCharges)")
            print("  🐸 Previous inWater state: \(inWater)")
            print("  🐸 Setting isDrowning: true")
            
            // Play splash sound
            soundController.playWaterSplash(severity: 1.0)
            
            // Trigger drowning callback to notify game scene
            print("  🐸 Calling onDrowned callback...")
            onDrowned?()
        }
    }
    
    func landOnPad(_ pad: LilyPad) {
               isGrounded = true
               currentLilyPad = pad
               
               // Play landing sound
               soundController.playSoundEffect(.frogLand)
               // soundController.playSoundEffect(.lilyPadBounce) // TODO: Add missing sound file
               
               // Create a subtle water ripple just outside the pad edge so it is visible "under" the pad
               if let gameScene = scene as? GameScene {
                   // Direction from jump start to pad (fallback to a random direction if zero-length)
                   var dir = CGVector(dx: pad.position.x - jumpStartPos.x, dy: pad.position.y - jumpStartPos.y)
                   let len = max(0.001, sqrt(dir.dx * dir.dx + dir.dy * dir.dy))
                   dir.dx /= len
                   dir.dy /= len
                   
                   // If the direction is effectively zero (e.g., snap/teleport), use a random unit vector
                   if len < 0.01 {
                       let angle = CGFloat.random(in: 0..<(2 * .pi))
                       dir = CGVector(dx: cos(angle), dy: sin(angle))
                   }
                   
                   // Offset distance: slightly beyond the visible pad radius
                   let offset: CGFloat = pad.radius + 12  // 12px past the rim
                   // Small random jitter so repeated landings don't look identical
                   let jitter = CGVector(dx: CGFloat.random(in: -6...6), dy: CGFloat.random(in: -6...6))
                   
                   let ripplePos = CGPoint(
                       x: pad.position.x + dir.dx * offset + jitter.dx,
                       y: pad.position.y + dir.dy * offset + jitter.dy
                   )
                   
                   // Tuned amplitude/frequency for a nice but not overpowering deformation
                   let amplitude: CGFloat = 0.015
                   let frequency: CGFloat = 40.0
                   gameScene.worldManager.addRipple(at: ripplePos, amplitude: amplitude, frequency: frequency)
                   
                   // Trigger Impact Jumps super power effect
                   gameScene.handleImpactJumpLanding(at: position)
               }
            
        // Preserve actual landing position on the pad instead of snapping to center
        // If you ever want to restore center-snap, flip GameConfig.disablePostLandingSnap to false
        if GameConfig.disablePostLandingSnap {
            // Keep current position (already at landing point)
            // Optionally clamp to pad radius for safety if slightly outside
            let dx = position.x - pad.position.x
            let dy = position.y - pad.position.y
            let dist = max(0.0001, sqrt(dx*dx + dy*dy))
            if dist > pad.radius {
                let nx = dx / dist
                let ny = dy / dist
                position = CGPoint(x: pad.position.x + nx * pad.radius * 0.98,
                                   y: pad.position.y + ny * pad.radius * 0.98)
            }
        } else {
            // Backward-compatible: snap to center if explicitly configured
            position = pad.position
        }

        // Optional: log world/screen after snap for clarity
        if let scene = scene as? GameScene {
            let screenAfter = scene.convert(position, from: scene.worldManager.worldNode)
            print("ðŸ¸ Frog position AFTER land - local(world): \(position) screen: \(screenAfter)")
        } else {
            print("ðŸ¸ Frog position AFTER land - local(world): \(position)")
        }
            
            inWater = false
            isDrowning = false  // CRITICAL: Reset drowning state when landing on pad
            frogSprite.removeAction(forKey: "frogBob")
            frogSprite.parent?.removeAction(forKey: waterRippleActionKey)
            frogSprite.texture = idleTexture
            
            // Return to idle pose on land
            playIdle()
            
            // Bounce animation (keyed, non-conflicting)
            frogSprite.removeAction(forKey: "frogBounce")
            let up = SKAction.scale(to: 1.2, duration: 0.1)
            up.timingMode = .easeOut
            let down = SKAction.scale(to: 1.0, duration: 0.12)
            down.timingMode = .easeIn
            let bounce = SKAction.sequence([up, down])
            frogSprite.run(bounce, withKey: "frogBounce")
        }
    
    
    func updateInvincibility() {
        if invincible {
            invincibleFramesRemaining -= 1
            frogSprite.alpha = (invincibleFramesRemaining / 5) % 2 == 0 ? 1.0 : 0.5
            
            if invincibleFramesRemaining <= 0 {
                invincible = false
                frogSprite.alpha = 1.0
            }
        }
    }
    
    func updateSuperJump(indicator: SKLabelNode?) {
        if superJumpActive {
            if pauseSuperJumpCountdown {
                // Keep visuals but do not decrement timer while aiming
                return
            }
            superJumpFramesRemaining -= 1

            // Yellow glow disabled per request: do nothing here

            // Emit trailing sparkles behind the frog occasionally
            if Int.random(in: 0...3) == 0, let scene = scene {
                let sparkle = SKLabelNode(text: "âœ¨")
                sparkle.fontSize = 22
                sparkle.position = CGPoint(x: frogSprite.position.x, y: frogSprite.position.y - 10)
                sparkle.zPosition = frogSprite.zPosition - 2
                frogSprite.parent?.addChild(sparkle)
                let action = SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: 0, y: -40, duration: 0.4),
                        SKAction.fadeOut(withDuration: 0.4),
                        SKAction.scale(to: 0.6, duration: 0.4)
                    ]),
                    SKAction.removeFromParent()
                ])
                sparkle.run(action)
            }

            if superJumpFramesRemaining <= 0 {
                superJumpActive = false
                // Remove indicator and its animations defensively
                indicator?.removeAllActions()
                indicator?.removeFromParent()

                // Remove glow
                superJumpGlow?.removeAllActions()
                superJumpGlow?.removeFromParent()
                superJumpGlow = nil

                // Clear special track state and return to normal gameplay music
                SoundController.shared.handleSpecialAbilityEnded()

                // Restore full visibility
                frogSprite.alpha = 1.0

                // End invincibility granted by super jump only if no other invincibility is active
                if invincibleFramesRemaining <= 0 {
                    invincible = false
                }
            }
        }
    }
    
    /// Activates invincibility for a given number of seconds.
    /// - Parameter seconds: Duration in seconds. Converted to frames assuming 60 FPS.
    func activateInvincibility(seconds: Double) {
        invincible = true
        // Convert seconds to frames (rounding up) and ensure at least 1 frame
        let frames = max(1, Int(ceil(seconds * 60.0)))
        invincibleFramesRemaining = max(invincibleFramesRemaining, frames)
        frogSprite.alpha = 1.0
    }

    /// Activates invincibility for a given number of frames.
    /// - Parameter frames: Duration in frames.
    func activateInvincibility(frames: Int) {
        invincible = true
        invincibleFramesRemaining = max(invincibleFramesRemaining, max(1, frames))
        frogSprite.alpha = 1.0
    }

    /// Backward-compatible convenience using configured default duration.
    func activateInvincibility() {
        activateInvincibility(frames: GameConfig.invincibleDurationFrames)
    }
    
    func activateSuperJump() {
        superJumpActive = true
        
        // For super jump activation
        HapticFeedbackManager.shared.notification(.success)
        
        // SUPER POWERS: Apply Super Jump Focus extension
        var superJumpDuration = GameConfig.superJumpDurationFrames
        if let gameScene = scene as? GameScene {
            let extensionSeconds = gameScene.uiManager.getSuperJumpExtension()
            if extensionSeconds > 0 {
                let extensionFrames = Int(extensionSeconds * 60.0) // Convert seconds to frames (60 FPS)
                superJumpDuration += extensionFrames
                print("🎯 Super Jump Focus Super Power: Extended by \(String(format: "%.1f", extensionSeconds)) seconds (\(extensionFrames) frames)")
            }
        }
        
        superJumpFramesRemaining = superJumpDuration

        // Become invincible during super jump
        invincible = true
        invincibleFramesRemaining = max(invincibleFramesRemaining, superJumpDuration)
        frogSprite.alpha = 1.0

        // Yellow glow around the frog disabled per request
    }
    
    func updateRocket(indicator: SKLabelNode?) {
        if rocketActive {
            rocketFramesRemaining -= 1
            
            // Check if rocket animation is already started
            if rocketSprite == nil {
                // This shouldn't happen as rocket sprite is created in playRocketAnimation
                // but we'll handle it gracefully
                print("⚠️ Rocket sprite missing during active rocket - attempting to recreate")
                addRocketSprite()
                createRocketParticleEffects()
            }
            
            // Update indicator with countdown
            if let indicator = indicator {
                let secondsRemaining = Int(ceil(Double(rocketFramesRemaining) / 60.0))
                indicator.text = "ROCKET: \(secondsRemaining)s"
            }
            
            if rocketFramesRemaining <= 0 {
                rocketActive = false
                // Remove indicator and its animations
                indicator?.removeAllActions()
                indicator?.removeFromParent()
                // Stop rocket animation and return to idle
                stopRocketAnimation()
                if !isJumping {
                    playIdle()
                }
                frogSprite.setScale(1.0)
                
                // Clear special track state and return to normal gameplay music
                SoundController.shared.handleSpecialAbilityEnded()
                
                // Rocket landing will be handled by the game scene
                
                // Restore normal rotation behavior
                unlockFacingAfterRocket()
            }
        }
    }
    
    /// Force the rocket ride to end immediately (e.g., when user taps land button)
    func forceRocketLanding() {
        guard rocketActive else { return }
        
        rocketActive = false
        rocketFramesRemaining = 0
        
        // Stop rocket animation and return to idle
        stopRocketAnimation()
        if !isJumping {
            playIdle()
        }
        frogSprite.setScale(1.0)
        
        // Clear special track state and return to normal gameplay music
        SoundController.shared.handleSpecialAbilityEnded()
        
        // Restore normal rotation behavior
        unlockFacingAfterRocket()
    }
    
    /// Force the rocket to land and place frog on starting lily pad for next level
    func forceRocketLandingOnNextLevelStart(startPad: LilyPad, sceneSize: CGSize) {
        guard rocketActive else { return }
        
        print("🚀➡️🏁 Rocket crossed finish line - transitioning to next level start pad")
        
        // End rocket mode
        rocketActive = false
        rocketFramesRemaining = 0
        
        // Stop rocket animation and visuals
        stopRocketAnimation()
        frogSprite.setScale(1.0)
        
        // Clear special track state and return to normal gameplay music
        SoundController.shared.handleSpecialAbilityEnded()
        
        // Restore normal rotation behavior
        unlockFacingAfterRocket()
        
        // Place frog on the starting lily pad of the next level
        position = startPad.position
        currentLilyPad = startPad
        isGrounded = true
        isJumping = false
        jumpProgress = 0
        velocity = .zero
        inWater = false
        isDrowning = false
        onIce = false
        slideVelocity = .zero
        suppressWaterCollisionUntilNextJump = false
        
        // Reset to idle appearance
        playIdle()
        frogSprite.alpha = 1.0
        frogShadow.alpha = 0.3
        
        print("🐸 Frog successfully placed on next level start pad at \(position)")
    }
    
    // Locks the frog to face upwards (top of screen) during rocket
    private func lockFacingUpForRocket() {
        // Ensure the frog faces up (0 radians points to the right; +Ï€/2 rotates to up for our art)
        // If your art already faces up at 0, set to 0 and constrain to 0.
        frogSprite.removeAction(forKey: "face")
        frogSprite.zRotation = 0
        // Disallow physics-based rotation and constrain zRotation
        frogSprite.physicsBody?.allowsRotation = false
        let lock = SKConstraint.zRotation(SKRange(constantValue: 0))
        // Preserve any existing constraints while adding lock
        if let existing = frogSprite.constraints, !existing.isEmpty {
            var new = existing.filter { constraint in
                // Remove any previous zRotation constant locks to avoid duplicates
                if case .some = (constraint as? SKConstraint) { /* keep */ }
                return true
            }
            new.append(lock)
            frogSprite.constraints = new
        } else {
            frogSprite.constraints = [lock]
        }
        
        print("🚀 Rocket facing locked - zRotation set to 0, constraints applied: \(frogSprite.constraints?.count ?? 0)")
    }

    // Unlocks rotation after rocket ends
    private func unlockFacingAfterRocket() {
        // Re-enable physics rotation if needed
        frogSprite.physicsBody?.allowsRotation = true
        
        // Clear all rotation constraints to ensure frog can rotate freely
        // This is more reliable than trying to filter specific constraint types
        let constraintCount = frogSprite.constraints?.count ?? 0
        frogSprite.constraints = nil
        
        print("🐸 Rotation unlocked after rocket - frog can now turn freely (cleared \(constraintCount) constraints)")
    }
    
    func activateRocket() {
        print("🚀 ACTIVATING ROCKET MODE!")
        rocketActive = true
        
        // For rocket activation
        HapticFeedbackManager.shared.notification(.success)
        rocketFramesRemaining = GameConfig.rocketDurationFrames
        
        // Make frog invincible while in rocket mode
        invincible = true
        invincibleFramesRemaining = max(invincibleFramesRemaining, GameConfig.rocketDurationFrames)
        
        // Stop any current jump and prepare for rocket flight
        isJumping = false
        isGrounded = false
        velocity = CGVector.zero
        
        // Start rocket animation
        print("🚀 About to start rocket animation...")
        playRocketAnimation()
        print("🚀 Rocket animation call completed")

        
        // The frog will be moved to center screen by GameScene
        frogSprite.alpha = 1.0  // Keep full visibility during rocket flight
        lockFacingUpForRocket()
        
        print("🚀 Rocket activation complete!")
    }
    
    // MARK: - Ice Sliding Methods
    
    /// Start sliding on ice with initial velocity from jump
    func startSlidingOnIce(initialVelocity: CGVector) {
        onIce = true
        inWater = false
        isGrounded = true
        isJumping = false
        
        // Use the frog's current facing direction for sliding
        // The frog's zRotation includes the art correction (π/2), so subtract it to get world direction
        let frogFacingAngle = frogSprite.zRotation + (.pi / 2)
        let facingDirection = CGVector(dx: cos(frogFacingAngle), dy: sin(frogFacingAngle))
        
        // Calculate slide speed from initial velocity magnitude
        let initialSpeed = sqrt(initialVelocity.dx * initialVelocity.dx + initialVelocity.dy * initialVelocity.dy)
        let slideSpeed = initialSpeed * 1.2 // Apply dampening factor
        
        // Apply the speed in the frog's facing direction
        slideVelocity = CGVector(dx: facingDirection.dx * slideSpeed, dy: facingDirection.dy * slideSpeed)
        
        // Play sliding sound
        soundController.playFrogSlide(intensity: Float(min(slideSpeed / 10.0, 1.0)))
        soundController.playIceSlide(velocity: Float(min(slideSpeed / 8.0, 1.0)))
        
        // Remove any lily pad association while sliding
        currentLilyPad = nil
        
        print("🧊 Frog started sliding on ice with velocity: (\(slideVelocity.dx), \(slideVelocity.dy)), facing angle: \(frogFacingAngle * 180 / .pi)°")
    }
    
    /// Update sliding physics each frame
    func updateSliding() {
        guard onIce else { return }
        
        // Apply slide velocity to position
        position.x += slideVelocity.dx
        position.y += slideVelocity.dy
        
        // Apply deceleration
        slideVelocity.dx *= slideDeceleration
        slideVelocity.dy *= slideDeceleration
        
        // Stop sliding when velocity is very low
        let speed = sqrt(slideVelocity.dx * slideVelocity.dx + slideVelocity.dy * slideVelocity.dy)
        if speed < minSlideSpeed {
            stopSliding()
        }
    }
    
    /// Stop sliding and return to normal grounded state
    func stopSliding() {
        guard onIce else { return }
        
        onIce = false
        slideVelocity = .zero
        
        // Try to find a nearby lily pad to land on
        // This will be handled by GameScene collision detection
        print("🧊 Frog stopped sliding")
    }
    
    /// Force stop sliding (e.g., when landing on a lily pad)
    func forceStopSliding() {
        onIce = false
        slideVelocity = .zero
    }
}

