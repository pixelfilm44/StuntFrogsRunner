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
        rightWorldX: CGFloat
    ) {
        // Parameters for log behavior
        let logSpeed: CGFloat = 10   // points/sec equivalent; we convert per-frame below
        let perFrame: CGFloat = logSpeed / 60.0
        
        let logRadius: CGFloat = 48.0   // approximate collision radius for pushing pads
        let padPushStrength: CGFloat = 22.0 // how much to nudge pads per frame when overlapping
        
        // Move each log and mark for removal if off-screen
        var indicesToRemove: [Int] = []
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
                
                // Push nearby lily pads away horizontally
                for pad in lilyPads {
                    let dx = pad.position.x - enemy.position.x
                    let dy = pad.position.y - enemy.position.y
                    let dist = sqrt(dx*dx + dy*dy)
                    if dist < (logRadius + pad.radius * 0.6) { // overlap threshold
                        // Push direction is away from the log's center
                        let pushDir: CGFloat = dx >= 0 ? 1.0 : -1.0
                        let newX = pad.position.x + (pushDir * (padPushStrength / 60.0))
                        pad.position.x = newX
                        pad.node.position.x = newX
                    }
                }
                
                // If the log has gone off-screen horizontally, mark for removal
                if enemy.position.x < min(leftWorldX, rightWorldX) - 200 || enemy.position.x > max(leftWorldX, rightWorldX) + 200 {
                    indicesToRemove.append(i)
                }
            }
        }
        
        // Remove off-screen logs (from both array and node tree)
        if !indicesToRemove.isEmpty {
            // Remove higher indices first to avoid reindexing issues
            for i in indicesToRemove.sorted(by: >) {
                let e = enemies.remove(at: i)
                // Clean up sidecar direction state
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