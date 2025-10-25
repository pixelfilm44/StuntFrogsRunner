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
    
    // Current lily pad
    var currentLilyPad: LilyPad?
    
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
        frogShadow.fillColor = UIColor.black.withAlphaComponent(0.3)
        frogShadow.strokeColor = .clear
        frogShadow.zPosition = 0
        container.addChild(frogShadow)
        
        // Load textures
        idleTexture = SKTexture(imageNamed: "frogIdle")
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
    
    func resetToStartPad(startPad: LilyPad, sceneSize: CGSize) {
        position = startPad.position
        currentLilyPad = startPad
        isGrounded = true
        isJumping = false
        jumpProgress = 0
        velocity = .zero
        inWater = false
        suppressWaterCollisionUntilNextJump = false
        
        // Visual reset
        frogSprite.alpha = 1.0
        frogShadow.alpha = 0.3
        playIdle()
        
        print("🐸 Frog reset to starting lily pad at \(position)")
    }
    
    func startJump(to targetPos: CGPoint) {
        jumpStartPos = position
        jumpTargetPos = targetPos
        jumpProgress = 0
        isJumping = true
        isGrounded = false
        currentLilyPad = nil
        
        // Any new jump re-enables water detection
        suppressWaterCollisionUntilNextJump = false
        
        let dx = targetPos.x - position.x
        let dy = targetPos.y - position.y
        let distance = max(0.001, sqrt(dx*dx + dy*dy))
        // Speed per frame stays GameConfig.jumpSpeed; superjump can scale distance elsewhere
        jumpSpeed = GameConfig.jumpSpeed
        let dirX = dx / distance
        let dirY = dy / distance
        velocity = CGVector(dx: dirX * jumpSpeed, dy: dirY * jumpSpeed)
        // Cache total distance for visual progress
        cachedJumpDistance = distance
        
        // Play jump animation
        playJumpOnce()
        
        print("🐸 Jump started from \(jumpStartPos) to \(jumpTargetPos)")
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
        
        print("🐸 Jump completed at \(position)")
    }
    
    func landOnPad(_ pad: LilyPad) {
        isGrounded = true
        currentLilyPad = pad
        if GameConfig.disablePostLandingSnap {
            // Respect exact landing; keep the computed landing position
        } else {
            position = pad.position  // Snap to pad center
        }
        inWater = false
        
        // Return to idle pose on land
        playIdle()
        
        print("🐸 Landed on lily pad at \(pad.position)")
        
        // Bounce animation (keyed, non-conflicting)
        frogSprite.removeAction(forKey: "frogBounce")
        let up = SKAction.scale(to: 1.2, duration: 0.1)
        up.timingMode = .easeOut
        let down = SKAction.scale(to: 1.0, duration: 0.12)
        down.timingMode = .easeIn
        let bounce = SKAction.sequence([up, down])
        frogSprite.run(bounce, withKey: "frogBounce")
    }
    
    func splash() {
        isJumping = false
        isGrounded = false

        if lifeVestCharges > 0 {
            // Do not consume the vest here. Let GameScene decide and manage suppression.
            inWater = true
            frogSprite.alpha = 1.0 // keep visible while floating
            print("🦺 Life vest available. Entering water; GameScene will handle rescue.")
        } else {
            // No vest: normal splash behavior (hide frog)
            inWater = false
            frogSprite.alpha = 0
            print("🐸 SPLASH! Fell in water")
        }
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
                let sparkle = SKLabelNode(text: "✨")
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
    
    func activateInvincibility() {
        invincible = true
        invincibleFramesRemaining = GameConfig.invincibleDurationFrames
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
                let rocket = SKLabelNode(text: "🚀")
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
                trailPath.addEllipse(in: CGRect(x: -8, y: -20, width: 16, height: 10))
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
                let flame = SKLabelNode(text: "🔥")
                flame.fontSize = 8
                flame.position = CGPoint(x: rocketWorldPos.x + CGFloat.random(in: -5...5), y: rocketWorldPos.y - 20)
                flame.zPosition = 55
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
                indicator.text = "🚀 ROCKET: \(secondsRemaining)s"
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
            }
        }
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
    }
}
