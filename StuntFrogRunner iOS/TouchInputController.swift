//
//  TouchInputController.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//


//
//  TouchInputController.swift
//  StuntFrog Runner
//
//  Handles touch input for slingshot aiming and rocket steering

import SpriteKit
import UIKit

class TouchInputController {
    // MARK: - Properties
    private var touchSideMap: [ObjectIdentifier: Bool] = [:] // true = right, false = left
    private var leftHoldCount: Int = 0
    private var rightHoldCount: Int = 0
    
    private let holdNudgePerFrame: CGFloat = 3.0
    private let holdMargin: CGFloat = 40.0
    private let tapNudgeAmount: CGFloat = 12.0
    
    var glideTargetScreenX: CGFloat?
    
    // MARK: - Callbacks
    var onSlingshotAimStarted: ((CGPoint) -> Void)?
    var onSlingshotAimMoved: ((CGPoint) -> Void)?
    var onSlingshotAimEnded: ((CGPoint) -> Void)?
    var onSlingshotCancelled: (() -> Void)?
    var onFacingUpdate: ((CGPoint) -> Void)?  // Pull direction
    
    // MARK: - Touch Handling
    func handleTouchBegan(_ touch: UITouch, in view: UIView, sceneSize: CGSize, rocketActive: Bool) -> CGPoint {
        let location = touch.location(in: view)
        
        if rocketActive {
            // Track which side of the screen is being held
            let key = ObjectIdentifier(touch)
            let screenCenter = sceneSize.width / 2
            if location.x > screenCenter + holdMargin {
                touchSideMap[key] = true
                rightHoldCount += 1
            } else if location.x < screenCenter - holdMargin {
                touchSideMap[key] = false
                leftHoldCount += 1
            }
        }
        
        onSlingshotAimStarted?(location)
        return location
    }
    
    func handleTouchMoved(_ touch: UITouch, in view: UIView, sceneSize: CGSize, rocketActive: Bool, hudBarHeight: CGFloat) -> CGPoint {
        var location = touch.location(in: view)
        
        // Clamp to HUD if below it
        if location.y <= hudBarHeight && !rocketActive {
            location = CGPoint(x: location.x, y: hudBarHeight + 1)
        }
        
        onSlingshotAimMoved?(location)
        return location
    }
    
    func handleTouchEnded(_ touch: UITouch, in view: UIView, sceneSize: CGSize, rocketActive: Bool, hudBarHeight: CGFloat) -> CGPoint {
        var location = touch.location(in: view)
        
        if rocketActive {
            let key = ObjectIdentifier(touch)
            if let isRight = touchSideMap.removeValue(forKey: key) {
                if isRight { rightHoldCount = max(0, rightHoldCount - 1) }
                else { leftHoldCount = max(0, leftHoldCount - 1) }
            }
        }
        
        // Clamp to HUD if below it
        if location.y <= hudBarHeight && !rocketActive {
            location = CGPoint(x: location.x, y: hudBarHeight + 1)
        }
        
        onSlingshotAimEnded?(location)
        return location
    }
    
    // MARK: - Rocket Steering
    func updateRocketSteering(frogContainerX: CGFloat, sceneWidth: CGFloat) {
        guard let glideTargetScreenX = glideTargetScreenX else { return }
        
        var newTarget = glideTargetScreenX
        
        // Apply tap nudges
        if rightHoldCount > 0 {
            newTarget += holdNudgePerFrame
        }
        if leftHoldCount > 0 {
            newTarget -= holdNudgePerFrame
        }
        
        // Clamp to screen bounds
        let margin: CGFloat = 60
        newTarget = max(margin, min(sceneWidth - margin, newTarget))
        
        self.glideTargetScreenX = newTarget
    }
    
    func initializeRocketTarget(frogContainerX: CGFloat) {
        glideTargetScreenX = frogContainerX
    }
    
    func applyTapNudge(isRightSide: Bool, sceneWidth: CGFloat) {
        guard let current = glideTargetScreenX else { return }
        
        var newTarget = current
        if isRightSide {
            newTarget += tapNudgeAmount
        } else {
            newTarget -= tapNudgeAmount
        }
        
        // Clamp to screen bounds
        let margin: CGFloat = 60
        newTarget = max(margin, min(sceneWidth - margin, newTarget))
        
        glideTargetScreenX = newTarget
    }
    
    // MARK: - Reset
    func reset() {
        touchSideMap.removeAll()
        leftHoldCount = 0
        rightHoldCount = 0
        glideTargetScreenX = nil
    }
}
