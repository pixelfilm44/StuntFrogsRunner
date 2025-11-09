//
//  GameLoopCoordinator.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//


//
//  GameLoopCoordinator.swift
//  StuntFrog Runner
//
//  Coordinates the main game update loop

import SpriteKit

class GameLoopCoordinator {
    // MARK: - Properties
    var frameCount: Int = 0
    
    // Sidecar storage for per-log direction since Enemy doesn't expose userData
    private var logDirection: [ObjectIdentifier: CGFloat] = [:]
    
    // MARK: - Frame Update
    func incrementFrame() {
        frameCount += 1
    }
    
    func getFrameCount() -> Int {
        return frameCount
    }
    
    // MARK: - Enemy Management
    func updateEnemies(
        enemies: inout [Enemy],
        lilyPads: inout [LilyPad],
        frogPosition: CGPoint,
        leftWorldX: CGFloat,
        rightWorldX: CGFloat,
        worldOffset: CGFloat? = nil,
        sceneHeight: CGFloat? = nil
    ) {
        // Check snake animation visibility if we have the required parameters
        if let offset = worldOffset, let height = sceneHeight {
            for enemy in enemies where enemy.type == .snake {
                enemy.updateVisibilityAnimation(worldOffset: offset, sceneHeight: height)
            }
        }
        
        // Parameters for log behavior
        let logSpeed: CGFloat = 10
        let perFrame: CGFloat = logSpeed / 60.0
        
        // Track logs for removal
        var indicesToRemove: [Int] = []
        
        // Update only log movement and screen bounds - collision is handled in CollisionManager
        for (i, enemy) in enemies.enumerated() {
            if enemy.type == EnemyType.log {
                // Determine or retrieve the horizontal direction for this log
                let key = ObjectIdentifier(enemy)
                var dir: CGFloat
                if let stored = logDirection[key] {
                    dir = stored
                } else {
                    // Choose direction based on initial position: if left of center, move right; else left
                    let moveRight: Bool = enemy.position.x < frogPosition.x
                    dir = moveRight ? 1.0 : -1.0
                    logDirection[key] = dir
                }
                
                // Apply horizontal movement per frame
                enemy.position.x += dir * perFrame
                enemy.node.position.x = enemy.position.x
                
                // Check if off-screen for removal
                if enemy.position.x < min(leftWorldX, rightWorldX) - 200 || 
                   enemy.position.x > max(leftWorldX, rightWorldX) + 200 {
                    indicesToRemove.append(i)
                }
            }
        }
        
        // Remove off-screen logs
        if !indicesToRemove.isEmpty {
            for i in indicesToRemove.sorted(by: >) {
                let e = enemies.remove(at: i)
                let key = ObjectIdentifier(e)
                logDirection.removeValue(forKey: key)
                e.node.removeFromParent()
            }
        }
    }
    
    // MARK: - Reset
    func reset() {
        frameCount = 0
        logDirection.removeAll()
    }
}
