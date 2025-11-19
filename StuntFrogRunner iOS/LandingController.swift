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
import Foundation

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
        isGrounded: Bool,
        frogController: FrogController? = nil,
        currentWeather: WeatherType = .day
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
                
                // Check if lily pads should be slippery due to weather
                let shouldSlip = shouldPadBeSlippery(weather: currentWeather)
                
                if shouldSlip, let frog = frogController {
                    // Get the slip factor from weather effects
                    let slipFactor = getSlipFactor(for: currentWeather)
                    
                    // Calculate landing velocity based on approach direction and speed
                    let approachVector = CGVector(dx: dx, dy: dy)
                    let approachSpeed = sqrt(approachVector.dx * approachVector.dx + approachVector.dy * approachVector.dy)
                    
                    // Create slide velocity - frog continues moving in landing direction
                    // Scale by slip factor and approach speed
                    let slideSpeed = min(approachSpeed * 0.3 * slipFactor, 5.0) // Cap max slide speed
                    let normalizedDirection = CGVector(
                        dx: approachVector.dx / max(distance, 0.1),
                        dy: approachVector.dy / max(distance, 0.1)
                    )
                    let slideVelocity = CGVector(
                        dx: normalizedDirection.dx * slideSpeed,
                        dy: normalizedDirection.dy * slideSpeed
                    )
                    
                    // Reduced pause frames for slippery landing - don't stop immediately
                    landingPauseFrames = max(landingPauseFrames, Int(20 * (1.0 - slipFactor))) // Less pause when more slippery
                    
                    // Start sliding on the lily pad
                    print("🌧️ Slippery landing! Starting slide with velocity: \(slideVelocity), factor: \(slipFactor)")
                    frog.startNaturalSlip(initialVelocity: slideVelocity, slipFactor: slipFactor)
                    
                } else {
                    // Normal landing - full pause
                    landingPauseFrames = max(landingPauseFrames, 60)
                }
                
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
    
    // MARK: - Weather Helpers
    
    /// Check if lily pads should be slippery based on current weather
    private func shouldPadBeSlippery(weather: WeatherType) -> Bool {
        return weather.gameplayEffects.contains { effect in
            if case .slipperyPads = effect {
                return true
            }
            return false
        }
    }
    
    /// Get the slip factor for lily pads from weather effects
    private func getSlipFactor(for weather: WeatherType) -> CGFloat {
        for effect in weather.gameplayEffects {
            if case .slipperyPads(let factor) = effect {
                return factor
            }
        }
        return 0.0
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