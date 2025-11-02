//
//  FrogController.swift
//  Top-down lily pad hopping
//

import SpriteKit

class FrogController {
    // Frog nodes
    private(set) var frogSprite: SKSpriteNode!
    // Compatibility shim so existing call sites using `frog` still work
    var frog: SKNode { frogSprite }

    var frogShadow: SKShapeNode!
    
    
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
    // When true, ignore subsequent water-fall checks until the frog jumps again
    var suppressWaterCollisionUntilNextJump: Bool = false
    
    // Super jump visuals
    var superJumpGlow: SKShapeNode?
    var superJumpTrailEmitter: SKEmitterNode?
    
    // Rocket visuals
    var rocketSprite: SKLabelNode?  // The rocket visual attached to frog
    var rocketTrail: SKShapeNode?
    var rocketFlameEmitter: SKEmitterNode?
    
    // Textures/animations
    private var idleTexture: SKTexture!
    private var jumpTextures: [SKTexture] = []
    private var floatingTexture: SKTexture!
    private var sinkingTexture: SKTexture!
    private var scaredTexture: SKTexture!  // newly added
    
    private var jumpFrameDuration: TimeInterval = 0.06  // tweak to taste
    
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
    
    private func playJumpOnce() {
        guard !jumpTextures.isEmpty else { return }
        frogSprite.removeAction(forKey: "frogJumpAnim")
        let animate = SKAction.animate(with: jumpTextures, timePerFrame: jumpFrameDuration, resize: false, restore: false)
        frogSprite.run(animate, withKey: "frogJumpAnim")
    }
    
    /// Shows the scared texture for a short duration, then returns to idle if appropriate
    func showScared(duration: TimeInterval = 1.0) {
        // Don't override rocket visuals
        if rocketActive { return }
        // Set scared texture immediately
        if let scared = scaredTexture, scared.size() != .zero {
            frogSprite.removeAction(forKey: "frogJumpAnim")
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
            } else if !self.isJumping {
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
        suppressWaterCollisionUntilNextJump = false
        frogSprite.texture = idleTexture
        
        // Visual reset
        frogSprite.alpha = 1.0
        frogShadow.alpha = 0.3
        playIdle()
        
        print("ðŸ¸ Frog reset to starting lily pad at \(position)")
    }
    
    func startJump(to targetPos: CGPoint) {
        jumpStartPos = position
        jumpTargetPos = targetPos
        jumpProgress = 0
        isJumping = true
        isGrounded = false
        // Stop water bobbing when leaving water to jump
        frogSprite.removeAction(forKey: "frogBob")
        frogSprite.parent?.removeAction(forKey: waterRippleActionKey)
        currentLilyPad = nil
        
        // Any new jump re-enables water detection
        suppressWaterCollisionUntilNextJump = false
        
        // Ensure rotation is unlocked for new jump (in case rocket constraints are still active)
        unlockFacingAfterRocket()
        print("🐸 Starting jump - rotation constraints cleared")
        
        let dx = targetPos.x - position.x
        let dy = targetPos.y - position.y
        let distance = max(0.001, sqrt(dx*dx + dy*dy))
        // Face the direction of travel with art correction
        // atan2(dy, dx) gives us the angle to the target
        // Common corrections based on your frog art's default orientation:
        //   0: frog faces right by default
        //   Ï€/2 (90Â°): frog faces up by default
        //   -Ï€/2 (-90Â°): frog faces down by default
        //   Ï€/4 (45Â°): frog faces up-right by default
        let angle = atan2(dy, dx)
        let correction: CGFloat = .pi / 2 // 90 degrees - top of frog faces up in the art
        frogSprite.removeAction(forKey: "face")
        frogSprite.run(SKAction.rotate(toAngle: angle + correction, duration: 0.08, shortestUnitArc: true), withKey: "face")
        // Speed per frame stays GameConfig.jumpSpeed; superjump can scale distance elsewhere
        jumpSpeed = GameConfig.jumpSpeed
        let dirX = dx / distance
        let dirY = dy / distance
        velocity = CGVector(dx: dirX * jumpSpeed, dy: dirY * jumpSpeed)
        // Cache total distance for visual progress
        cachedJumpDistance = distance
        
        // Play jump animation
        playJumpOnce()
        
        print("ðŸ¸ Jump started from \(jumpStartPos) to \(jumpTargetPos)")
    }
    
    func updateJump() {
        guard isJumping else { return }
        
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

            if lifeVestCharges > 0 {
                // Do not consume the vest here. Let GameScene decide and manage suppression.
                inWater = true
                
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
                // No vest: normal splash behavior (hide frog)
                inWater = false
                frogSprite.setScale(1.5)
                frogSprite.texture = sinkingTexture
                frogSprite.alpha = 0
                frogSprite.removeAction(forKey: "frogBob")
                frogSprite.parent?.removeAction(forKey: waterRippleActionKey)
                print("SPLASH! Fell in water")
            }
        }
    
    func landOnPad(_ pad: LilyPad) {
               isGrounded = true
               currentLilyPad = pad
               
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
                   
                   print("ðŸ¸ Frog position BEFORE snap: \(position)")
                   print("ðŸ¦¦ Lily pad position: \(pad.position)")
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
        superJumpFramesRemaining = GameConfig.superJumpDurationFrames

        // Become invincible during super jump
        invincible = true
        invincibleFramesRemaining = max(invincibleFramesRemaining, GameConfig.superJumpDurationFrames)
        frogSprite.alpha = 1.0

        // Yellow glow around the frog disabled per request
    }
    
    func updateRocket(indicator: SKLabelNode?) {
        if rocketActive {
            rocketFramesRemaining -= 1
            
            // Create rocket sprite attached to frog
            if rocketSprite == nil {
                let rocket = SKLabelNode(text: "Woo hoo!")
                rocket.fontSize = 32
                rocket.position = CGPoint(x: 0, y: -40)  // Below the frog
                rocket.zPosition = -1
                frogSprite.addChild(rocket)
                rocketSprite = rocket
                
                // Add a pulsing animation to the rocket
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.2, duration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
                rocket.run(SKAction.repeatForever(pulse))
            }
            
            // Create exhaust trail behind the rocket
            if rocketTrail == nil, let scene = scene {
                let trail = SKShapeNode()
                let trailPath = CGMutablePath()
                trailPath.addEllipse(in: CGRect(x: -8, y: -20, width: 16, height: 30))
                trail.path = trailPath
                trail.fillColor = .orange
                trail.strokeColor = .red
                trail.lineWidth = 1
                trail.alpha = 0.8
                trail.zPosition = frogSprite.zPosition - 1
                scene.addChild(trail)
                rocketTrail = trail
            }
            
            // Update trail position to follow rocket
            if let rocket = rocketSprite, let scene = scene {
                let rocketWorldPos = scene.convert(rocket.position, from: frogSprite)
                rocketTrail?.position = CGPoint(x: rocketWorldPos.x, y: rocketWorldPos.y - 15)
            }
            
            // Emit flame particles occasionally
            if Int.random(in: 0...2) == 0, let scene = scene, let rocket = rocketSprite {
                let rocketWorldPos = scene.convert(rocket.position, from: frogSprite)
                let flameTexture = SKTexture(imageNamed: "flame")
                let flame = SKSpriteNode(texture: flameTexture)
                flame.size = CGSize(width: 14, height: 14) // approximate previous visual scale
                flame.position = CGPoint(
                    x: rocketWorldPos.x + CGFloat.random(in: -5...5),
                    y: rocketWorldPos.y - 20
                )
                // Place behind the rocket sprite but above the background
                flame.zPosition = (rocket.zPosition - 1)
                scene.addChild(flame)
                
                let action = SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: 0, y: -30, duration: 0.4),
                        SKAction.fadeOut(withDuration: 0.4),
                        SKAction.scale(to: 0.2, duration: 0.4)
                    ]),
                    SKAction.removeFromParent()
                ])
                flame.run(action)
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
                // Remove rocket sprite
                rocketSprite?.removeFromParent()
                rocketSprite = nil
                // Remove trail visual
                rocketTrail?.removeFromParent()
                rocketTrail = nil
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
        
        // Remove rocket sprite and its animations
        rocketSprite?.removeAllActions()
        rocketSprite?.removeFromParent()
        rocketSprite = nil
        
        // Remove trail visual
        rocketTrail?.removeFromParent()
        rocketTrail = nil
        
        // Restore normal rotation behavior
        unlockFacingAfterRocket()
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
    }

    // Unlocks rotation after rocket ends
    private func unlockFacingAfterRocket() {
        // Re-enable physics rotation if needed
        frogSprite.physicsBody?.allowsRotation = true
        
        // Clear all rotation constraints to ensure frog can rotate freely
        // This is more reliable than trying to filter specific constraint types
        frogSprite.constraints = nil
        
        print("🐸 Rotation unlocked after rocket - frog can now turn freely")
    }
    
    func activateRocket() {
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
        
        // The frog will be moved to center screen by GameScene
        frogSprite.alpha = 1.0  // Keep full visibility during rocket flight
        lockFacingUpForRocket()
    }
}

