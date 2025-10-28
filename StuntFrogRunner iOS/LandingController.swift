//
//  LandingController.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//


//
//  LandingController.swift
//  StuntFrog Runner
//
//  Handles landing detection and pad interaction

import SpriteKit

class LandingController {
    // MARK: - Properties
    var landingPauseFrames: Int = 0
    var rocketLandingGraceFrames: Int = 0
    
    // MARK: - Callbacks
    var onLandingSuccess: ((LilyPad) -> Void)?
    var onLandingMissed: (() -> Void)?
    var onUnsafePadLanding: (() -> Void)?
    
    // MARK: - Landing Check
    func checkLanding(
        frogPosition: CGPoint,
        lilyPads: [LilyPad],
        isJumping: Bool,
        isGrounded: Bool
    ) -> Bool {
        guard !isJumping && !isGrounded else { return false }
        
        var landedOnPad = false
        
        for pad in lilyPads {
            let dx = frogPosition.x - pad.position.x
            let dy = frogPosition.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            let threshold = pad.radius * 1.15
            let epsilon: CGFloat = 6.0 // small forgiveness to account for motion/scrolling
            if distance <= threshold + epsilon {
                if pad.type == .pulsing && !pad.isSafeToLand {
                    onUnsafePadLanding?()
                    return true
                }
                
                landedOnPad = true
                
                // Add extra pause after successful landing (1 second at 60 fps)
                landingPauseFrames = max(landingPauseFrames, 60)
                
                // Bounce animation
                let bounceAction = SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.1),
                    SKAction.scale(to: 1.0, duration: 0.1)
                ])
                pad.node.run(bounceAction)
                
                onLandingSuccess?(pad)
                break
            }
        }
        
        if !landedOnPad {
            onLandingMissed?()
            return true
        }
        
        return landedOnPad
    }
    
    // MARK: - Rocket Landing Check
    func checkRocketLanding(
        frogPosition: CGPoint,
        lilyPads: [LilyPad]
    ) -> LilyPad? {
        for pad in lilyPads {
            let dx = frogPosition.x - pad.position.x
            let dy = frogPosition.y - pad.position.y
            let dist = sqrt(dx*dx + dy*dy)
            if dist < pad.radius * 1.15 {
                return pad
            }
        }
        return nil
    }
    
    // MARK: - Pause Management
    func updatePauseFrames() {
        if landingPauseFrames > 0 {
            landingPauseFrames -= 1
        }
        if rocketLandingGraceFrames > 0 {
            rocketLandingGraceFrames -= 1
        }
    }
    
    func shouldPauseScrolling() -> Bool {
        return landingPauseFrames > 0
    }
    
    func setRocketGracePeriod(frames: Int) {
        rocketLandingGraceFrames = frames
    }
    
    // MARK: - Reset
    func reset() {
        landingPauseFrames = 0
        rocketLandingGraceFrames = 0
    }
}