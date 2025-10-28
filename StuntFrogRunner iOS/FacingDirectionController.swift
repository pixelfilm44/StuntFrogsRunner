//
//  FacingDirectionController.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//


//
//  FacingDirectionController.swift
//  StuntFrog Runner
//
//  Manages frog facing direction and rotation

import SpriteKit

class FacingDirectionController {
    // MARK: - Properties
    private var frogFacingAngle: CGFloat = 0
    private var lockedFacingAngle: CGFloat?
    private let artCorrection: CGFloat = .pi  // Flip 180°
    
    weak var frogNode: SKNode?
    
    // MARK: - Initialization
    init(frogNode: SKNode?) {
        self.frogNode = frogNode
    }
    
    // MARK: - Facing Direction
    func updateFacingDirection(
        isPlaying: Bool,
        rocketActive: Bool,
        frogContainerPosition: CGPoint,
        glideTargetScreenX: CGFloat?,
        frogVelocity: CGVector
    ) {
        guard isPlaying, let frogNode = frogNode else { return }
        
        // If we have a locked facing (from aiming), keep it while jumping and until next explicit change
        if let locked = lockedFacingAngle {
            // Apply the locked angle and smooth toward it
            let lerpFactor: CGFloat = 0.18
            var delta = locked - frogFacingAngle
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            
            frogFacingAngle = frogFacingAngle + delta * lerpFactor
            frogNode.zRotation = frogFacingAngle
            return
        }
        
        // Choose an orientation source:
        // 1) If rocket is active, use horizontal steering (screen-space) combined with upward motion
        // 2) Else if the frog has meaningful velocity while jumping, use velocity vector
        // 3) Else keep the last angle
        var desiredAngle: CGFloat?
        
        if rocketActive {
            let currentScreen = frogContainerPosition
            let targetX = glideTargetScreenX ?? currentScreen.x
            let targetScreen = CGPoint(x: targetX, y: currentScreen.y + 60)
            let dx = targetScreen.x - currentScreen.x
            let dy = targetScreen.y - currentScreen.y
            if dx != 0 || dy != 0 {
                desiredAngle = atan2(dy, dx)
            }
        } else {
            let v = frogVelocity
            if abs(v.dx) + abs(v.dy) > 1.0 {
                desiredAngle = atan2(v.dy, v.dx)
            }
        }
        
        if let base = desiredAngle { desiredAngle = base + artCorrection }
        
        let targetAngle = desiredAngle ?? frogFacingAngle
        let lerpFactor: CGFloat = 0.18
        let current = frogFacingAngle
        var delta = targetAngle - current
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        let newAngle = current + delta * lerpFactor
        frogFacingAngle = newAngle
        frogNode.zRotation = newAngle
    }
    
    func setFacingFromPull(pullDirection: CGPoint) {
        if pullDirection.x != 0 || pullDirection.y != 0 {
            let desired = atan2(-pullDirection.y, -pullDirection.x) + .pi/2
            frogFacingAngle = desired + artCorrection
            frogNode?.zRotation = frogFacingAngle
            lockedFacingAngle = frogFacingAngle
        }
    }
    
    func lockCurrentFacing() {
        lockedFacingAngle = frogFacingAngle
    }
    
    func clearLockedFacing() {
        lockedFacingAngle = nil
    }
    
    func resetFacing() {
        frogFacingAngle = 0
        lockedFacingAngle = nil
        frogNode?.zRotation = 0
    }
}