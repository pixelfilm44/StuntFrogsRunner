//
//  EdgeSpikeBushManager.swift
//  Manages spike bushes that appear on the left and right edges of the screen
//

import SpriteKit
import Foundation
import AVFoundation

class EdgeSpikeBushManager {
    weak var worldNode: SKNode?
    weak var scene: SKScene?
    
    private var leftEdgeSpikeBushes: [Enemy] = []
    private var rightEdgeSpikeBushes: [Enemy] = []
    
    // Track the highest Y position for spawned edge spike bushes to avoid duplicates
    private var lastLeftSpawnY: CGFloat = -CGFloat.greatestFiniteMagnitude
    private var lastRightSpawnY: CGFloat = -CGFloat.greatestFiniteMagnitude
    
    init(worldNode: SKNode?, scene: SKScene?) {
        self.worldNode = worldNode
        self.scene = scene
    }
    
    func reset() {
        // Clean up existing edge spike bushes
        for bush in leftEdgeSpikeBushes {
            bush.node.removeFromParent()
        }
        for bush in rightEdgeSpikeBushes {
            bush.node.removeFromParent()
        }
        
        leftEdgeSpikeBushes.removeAll()
        rightEdgeSpikeBushes.removeAll()
        
        lastLeftSpawnY = -CGFloat.greatestFiniteMagnitude
        lastRightSpawnY = -CGFloat.greatestFiniteMagnitude
    }
    
    func updateAndSpawn(worldOffset: CGFloat, sceneSize: CGSize, frogPosition: CGPoint) {
        guard let worldNode = worldNode, let scene = scene else { return }
        
        // Calculate visible area in world coordinates
        let visibleMinY = -worldOffset - 200 // Spawn slightly below visible area
        let visibleMaxY = -worldOffset + sceneSize.height + 400 // Spawn well above visible area
        
        // Remove edge spike bushes that are too far below the visible area
        cullDistantEdgeSpikeBushes(belowY: visibleMinY - 300)
        
        // Spawn new edge spike bushes if needed
        spawnEdgeSpikeBushes(
            fromY: max(visibleMinY, lastLeftSpawnY + GameConfig.edgeSpikeBushSpacing),
            toY: visibleMaxY,
            sceneSize: sceneSize,
            worldNode: worldNode
        )
    }
    
    private func spawnEdgeSpikeBushes(fromY: CGFloat, toY: CGFloat, sceneSize: CGSize, worldNode: SKNode) {
        let spacing = GameConfig.edgeSpikeBushSpacing
        let leftX = GameConfig.edgeSpikeBushMargin
        let rightX = sceneSize.width - GameConfig.edgeSpikeBushMargin
        
        var currentY = fromY
        
        while currentY <= toY {
            // Spawn left edge spike bush
            let leftBush = Enemy(
                type: .edgeSpikeBush,
                position: CGPoint(x: leftX, y: currentY),
                speed: 0.0
            )
            leftBush.node.position = leftBush.position
            leftBush.node.zPosition = 45 // Behind other enemies but in front of lily pads
            worldNode.addChild(leftBush.node)
            leftEdgeSpikeBushes.append(leftBush)
            
            // Spawn right edge spike bush
            let rightBush = Enemy(
                type: .edgeSpikeBush,
                position: CGPoint(x: rightX, y: currentY),
                speed: 0.0
            )
            rightBush.node.position = rightBush.position
            rightBush.node.zPosition = 45
            worldNode.addChild(rightBush.node)
            rightEdgeSpikeBushes.append(rightBush)
            
            currentY += spacing
        }
        
        // Update last spawn positions
        if currentY > lastLeftSpawnY {
            lastLeftSpawnY = currentY - spacing
            lastRightSpawnY = currentY - spacing
        }
    }
    
    private func cullDistantEdgeSpikeBushes(belowY: CGFloat) {
        // Remove left edge spike bushes that are too far below
        leftEdgeSpikeBushes.removeAll { bush in
            if bush.position.y < belowY {
                bush.node.removeFromParent()
                return true
            }
            return false
        }
        
        // Remove right edge spike bushes that are too far below
        rightEdgeSpikeBushes.removeAll { bush in
            if bush.position.y < belowY {
                bush.node.removeFromParent()
                return true
            }
            return false
        }
    }
    
   
    
    // Get all edge spike bushes for integration with main enemy system if needed
    func getAllEdgeSpikeBushes() -> [Enemy] {
        return leftEdgeSpikeBushes + rightEdgeSpikeBushes
    }
}
