//
//  SlingshotController.swift
//  Top-down aiming and launching
//

import SpriteKit

class SlingshotController {
    // Slingshot state
    var slingshotActive: Bool = false
    var pullStartPos: CGPoint = .zero
    var pullCurrentPos: CGPoint = .zero
    var pullStartFrogScreenPos: CGPoint = .zero  // Lock frog's screen position when aiming begins
    
    // Visual indicators
    var aimLine: SKShapeNode?
    var targetReticle: SKShapeNode?
    var nearestPadHighlight: SKShapeNode?
    
    weak var scene: SKScene?
    
    init(scene: SKScene) {
        self.scene = scene
    }
    
    func handleTouchBegan(at location: CGPoint, frogScreenPosition: CGPoint) {
        let dx = location.x - frogScreenPosition.x
        let dy = location.y - frogScreenPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance < 80 {
            slingshotActive = true
            pullStartPos = location
            pullCurrentPos = location
            pullStartFrogScreenPos = frogScreenPosition  // Lock frog position in screen space
            print("✅ Aiming activated!")
        }
    }
    
    func handleTouchMoved(to location: CGPoint) {
        if slingshotActive {
            pullCurrentPos = location
        }
    }
    
    func handleTouchEnded(at location: CGPoint, frogScreenPosition: CGPoint, frogWorldPosition: CGPoint, worldOffset: CGFloat, superJumpActive: Bool) -> CGPoint? {
        guard slingshotActive else { return nil }
        
        // Use the locked screen position from when aiming began, not the current position
        let dx = location.x - pullStartFrogScreenPos.x
        let dy = location.y - pullStartFrogScreenPos.y
        
        let maxPull = superJumpActive ? GameConfig.maxPullDistanceSuperJump : GameConfig.maxPullDistance
        let pullDistance = min(sqrt(dx * dx + dy * dy), maxPull)
        let angle = atan2(dy, dx)
        
        // Dead zone: ignore tiny pulls
        if pullDistance < GameConfig.minPullDistance {
            slingshotActive = false
            clearVisuals()
            return nil
        }
        
        let distanceMultiplier = superJumpActive ? GameConfig.superJumpDistanceMultiplier : 1.0
        let targetOffsetX = -cos(angle) * pullDistance * 1.5 * distanceMultiplier
        let targetOffsetY = -sin(angle) * pullDistance * 1.5 * distanceMultiplier
        
        // Calculate world position
        let targetWorldX = frogWorldPosition.x + targetOffsetX
        let targetWorldY = frogWorldPosition.y + targetOffsetY
        
        slingshotActive = false
        clearVisuals()
        
        print("🎯 Target: world(\(targetWorldX), \(targetWorldY))")
        return CGPoint(x: targetWorldX, y: targetWorldY)
    }
    
    func drawSlingshot(frogScreenPosition: CGPoint, frogWorldPosition: CGPoint, superJumpActive: Bool, lilyPads: [LilyPad], worldNode: SKNode, scene: SKScene, worldOffset: CGFloat) {
        clearVisuals()
        
       
        
        guard slingshotActive else { return }
        
        // Use the locked screen position from when aiming began, not the current position
        // This prevents the aim from drifting as the world scrolls
        let lockedFrogPos = pullStartFrogScreenPos
        
        // Draw aim line from frog to pull point
        let linePath = CGMutablePath()
        linePath.move(to: lockedFrogPos)
        linePath.addLine(to: pullCurrentPos)
        
        aimLine = SKShapeNode(path: linePath)
        aimLine?.strokeColor = superJumpActive ? .yellow : .white
        aimLine?.lineWidth = 3
        aimLine?.zPosition = 200
        aimLine?.alpha = 0.8
        scene.addChild(aimLine!)
        
        // Calculate and show target position using locked screen position
        let dx = pullCurrentPos.x - lockedFrogPos.x
        let dy = pullCurrentPos.y - lockedFrogPos.y
        
        let maxPull = superJumpActive ? GameConfig.maxPullDistanceSuperJump : GameConfig.maxPullDistance
        let pullDistance = min(sqrt(dx * dx + dy * dy), maxPull)
        let angle = atan2(dy, dx)
        let distanceMultiplier = superJumpActive ? GameConfig.superJumpDistanceMultiplier : 1.0
        let targetOffsetX = -cos(angle) * pullDistance * 1.5 * distanceMultiplier
        let targetOffsetY = -sin(angle) * pullDistance * 1.5 * distanceMultiplier
        
        // If below dead zone, don't draw target reticle (keep nearest pad highlight only)
        if pullDistance < GameConfig.minPullDistance {
            return
        }
        
        let targetScreenX = lockedFrogPos.x + targetOffsetX
        let targetScreenY = lockedFrogPos.y + targetOffsetY
        
        // Draw target reticle
        targetReticle = SKShapeNode(circleOfRadius: 35)
        targetReticle?.position = CGPoint(x: targetScreenX, y: targetScreenY)
        targetReticle?.strokeColor = superJumpActive ? .yellow : .green
        targetReticle?.fillColor = (superJumpActive ? UIColor.yellow : UIColor.green).withAlphaComponent(0.3)
        targetReticle?.lineWidth = 4
        targetReticle?.zPosition = 97
        
        // Add crosshair
        let crosshair = SKShapeNode()
        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: -20, y: 0))
        crossPath.addLine(to: CGPoint(x: 20, y: 0))
        crossPath.move(to: CGPoint(x: 0, y: -20))
        crossPath.addLine(to: CGPoint(x: 0, y: 20))
        crosshair.path = crossPath
        crosshair.strokeColor = .white
        crosshair.lineWidth = 2
        targetReticle?.addChild(crosshair)
        
        scene.addChild(targetReticle!)
        
        // Pulsing animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.3)
        ])
        targetReticle?.run(SKAction.repeatForever(pulse))
    }
    
    private func findNearestReachablePad(lilyPads: [LilyPad], frogWorldPos: CGPoint) -> LilyPad? {
        var nearestPad: LilyPad?
        var minDistance: CGFloat = .infinity
        
        for pad in lilyPads {
            // Only consider pads ahead (higher Y in world)
            if pad.position.y > frogWorldPos.y {
                let dx = pad.position.x - frogWorldPos.x
                let dy = pad.position.y - frogWorldPos.y
                let distance = sqrt(dx * dx + dy * dy)
                
                // Within reasonable jump range
                if distance < GameConfig.maxRegularJumpDistance && distance < minDistance {
                    minDistance = distance
                    nearestPad = pad
                }
            }
        }
        
        return nearestPad
    }
    
    private func clearVisuals() {
        aimLine?.removeFromParent()
        aimLine = nil
        
        targetReticle?.removeFromParent()
        targetReticle = nil
        
        nearestPadHighlight?.removeFromParent()
        nearestPadHighlight = nil
    }
    
    /// Cancels any current aiming interaction and clears all slingshot visuals.
    func cancelCurrentAiming() {
        slingshotActive = false
        clearVisuals()
    }
}
