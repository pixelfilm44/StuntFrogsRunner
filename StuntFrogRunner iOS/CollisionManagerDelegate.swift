import SpriteKit

protocol CollisionManagerDelegate: AnyObject {
    func didLand(on pad: Pad)
    func didCrash(into enemy: Enemy)
    func didHitObstacle(pad: Pad)
    func didCollect(coin: Coin)
    func didFallIntoWater()
}

class CollisionManager {
    
    weak var delegate: CollisionManagerDelegate?
    
    private let coinRadiusSq: CGFloat
    private let enemyRadiusSq: CGFloat
    private let frogRadius: CGFloat
    
    init() {
        let coinR: CGFloat = 20.0
        let enemyR: CGFloat = 15.0
        let frogR = Configuration.Dimensions.frogRadius
        
        self.coinRadiusSq = pow(coinR + frogR, 2)
        self.enemyRadiusSq = pow(enemyR + frogR, 2)
        self.frogRadius = frogR
    }
    
    func update(frog: Frog, pads: [Pad], enemies: [Enemy], coins: [Coin]) {
        if frog.zHeight <= 0 && frog.zVelocity <= 0 {
            checkForLanding(frog: frog, pads: pads)
        }
        checkEntityCollisions(frog: frog, enemies: enemies, coins: coins)
        checkObstacleCollisions(frog: frog, pads: pads)
        
        // NEW: Check Log-to-Pad collisions
        checkLogPadCollisions(pads: pads)
    }
    
    private func checkLogPadCollisions(pads: [Pad]) {
        // Filter for moving logs to optimize
        let logs = pads.filter { $0.type == .log }
        
        for log in logs {
            // Log Half-Extents (120x40 size -> 60x20 half)
            let logHW: CGFloat = 60
            let logHH: CGFloat = 20
            
            for other in pads {
                if log === other { continue } // Skip self
                
                // Determine dimensions of the other pad
                // Log: 60x20, Pad: 45x45 (Approx rect for collision)
                let otherHW: CGFloat = (other.type == .log) ? 60 : 45
                let otherHH: CGFloat = (other.type == .log) ? 20 : 45
                
                let dx = abs(log.position.x - other.position.x)
                let dy = abs(log.position.y - other.position.y)
                
                let overlapX = dx < (logHW + otherHW)
                let overlapY = dy < (logHH + otherHH)
                
                if overlapX && overlapY {
                    // Collision Detected. Bounce Log.
                    // Only bounce if moving towards the target to prevent sticky jitter
                    if log.position.x < other.position.x && log.moveDirection > 0 {
                        log.moveDirection = -1.0
                    } else if log.position.x > other.position.x && log.moveDirection < 0 {
                        log.moveDirection = 1.0
                    }
                }
            }
        }
    }
    
    private func checkForLanding(frog: Frog, pads: [Pad]) {
        var hasLanded = false
        
        for pad in pads {
            // FIX: If Log Jumper ability is active, treat Logs as landing pads
            if pad.type == .log && !frog.canJumpLogs {
                continue // Skip this log, fall through to water logic if no other pad found
            }
            
            // If canJumpLogs is true, logs are processed below just like pads
            
            // Special handling for Log hitboxes (Rectangular vs Circle)
            var isHit = false
            
            if pad.type == .log {
                // Log Box Collision Logic
                let halfW: CGFloat = 60 + frogRadius
                let halfH: CGFloat = 20 + frogRadius
                let dx = abs(frog.position.x - pad.position.x)
                let dy = abs(frog.position.y - pad.position.y)
                if dx < halfW && dy < halfH {
                    isHit = true
                }
            } else {
                // Circle Pad Logic
                // Use dynamic scaled radius for checking
                let currentPadRadius = pad.scaledRadius
                
                // Optimization: Simple bounds check with dynamic size
                if abs(frog.position.x - pad.position.x) > (currentPadRadius + frogRadius) { continue }
                if abs(frog.position.y - pad.position.y) > (currentPadRadius + frogRadius) { continue }
                
                let dx = frog.position.x - pad.position.x
                let dy = frog.position.y - pad.position.y
                let distSq = (dx * dx) + (dy * dy)
                
                let distThresholdSq = pow(currentPadRadius + frogRadius, 2)
                if distSq < distThresholdSq {
                    isHit = true
                }
            }
            
            if isHit {
                hasLanded = true
                if frog.onPad != pad {
                    delegate?.didLand(on: pad)
                }
                break
            }
        }
        
        if !hasLanded {
            delegate?.didFallIntoWater()
        }
    }
    
    private func checkObstacleCollisions(frog: Frog, pads: [Pad]) {
        // Rocket ignores everything
        if frog.rocketState != .none { return }
        
        // Log Jumper ignores log collisions (treats them as floors in checkForLanding)
        if frog.canJumpLogs { return }
        
        for pad in pads where pad.type == .log {
            let halfW: CGFloat = 60 + frogRadius
            let halfH: CGFloat = 20 + frogRadius
            let dx = abs(frog.position.x - pad.position.x)
            let dy = abs(frog.position.y - pad.position.y)
            if dx < halfW && dy < halfH {
                delegate?.didHitObstacle(pad: pad)
                return
            }
        }
    }
    
    private func checkEntityCollisions(frog: Frog, enemies: [Enemy], coins: [Coin]) {
        for coin in coins where !coin.isCollected {
            let dx = frog.position.x - coin.position.x
            let dy = frog.position.y - coin.position.y
            let distSq = (dx * dx) + (dy * dy)
            if distSq < coinRadiusSq {
                coin.isCollected = true
                delegate?.didCollect(coin: coin)
            }
        }
        
        if frog.isInvincible { return }
        
        for enemy in enemies {
            let dx = frog.position.x - enemy.position.x
            let dy = frog.position.y - enemy.position.y
            let distSq = (dx * dx) + (dy * dy)
            let zDiff = abs(frog.zHeight - enemy.zHeight)
            
            if distSq < enemyRadiusSq && zDiff < 30 {
                delegate?.didCrash(into: enemy)
            }
        }
    }
}
