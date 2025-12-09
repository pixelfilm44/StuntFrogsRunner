import SpriteKit

protocol CollisionManagerDelegate: AnyObject {
    func didLand(on pad: Pad)
    func didCrash(into enemy: Enemy)
    func didCrash(into snake: Snake)
    func didCrash(into boat: Boat)
    func didHitObstacle(pad: Pad)
    func didCollect(coin: Coin)
    func didCollect(treasureChest: TreasureChest)
    func didCollect(fly: Fly)
    func didFallIntoWater()
    func didLand(on crocodile: Crocodile)
    func didCompleteCrocodileRide(crocodile: Crocodile)
    func crocodileDidDestroy(pad: Pad)
    func crocodileDidDestroy(enemy: Enemy)
    func crocodileDidDestroy(snake: Snake)
}

class CollisionManager {
    
    weak var delegate: CollisionManagerDelegate?
    
    private let coinRadiusSq: CGFloat
    private let chestRadiusSq: CGFloat
    private let enemyRadiusSq: CGFloat
    private let flyRadiusSq: CGFloat
    private let frogRadius: CGFloat
    
    init() {
        let coinR: CGFloat = 20.0
        let chestR: CGFloat = 25.0  // Slightly larger than coins
        let enemyR: CGFloat = 15.0
        let flyR: CGFloat = 15.0  // Small collision radius for fly
        let frogR = Configuration.Dimensions.frogRadius
        
        self.coinRadiusSq = pow(coinR + frogR, 2)
        self.chestRadiusSq = pow(chestR + frogR, 2)
        self.enemyRadiusSq = pow(enemyR + frogR, 2)
        self.flyRadiusSq = pow(flyR + frogR, 2)
        self.frogRadius = frogR
    }
    
    func update(frog: Frog, pads: [Pad], enemies: [Enemy], coins: [Coin], crocodiles: [Crocodile] = [], treasureChests: [TreasureChest] = [], snakes: [Snake] = [], flies: [Fly] = [], boat: Boat? = nil) {
        // Check crocodile ride completion first
        for crocodile in crocodiles {
            if crocodile.isRideComplete() {
                delegate?.didCompleteCrocodileRide(crocodile: crocodile)
            }
        }
        
        if frog.zHeight <= 0 && frog.zVelocity <= 0 {
            checkForLanding(frog: frog, pads: pads, crocodiles: crocodiles)
        }
        
        // Check collisions for airborne frog
        if frog.zHeight > 0 {
            checkFrogBoatCollision(frog: frog, boat: boat)
        }
        
        checkEntityCollisions(frog: frog, enemies: enemies, coins: coins, treasureChests: treasureChests, snakes: snakes, flies: flies)
        checkObstacleCollisions(frog: frog, pads: pads)
        
        // NEW: Check Log-to-Pad collisions
        checkLogPadCollisions(pads: pads)
        
        // NEW: Check Crocodile collisions (with pads and enemies)
        checkCrocodilePadCollisions(crocodiles: crocodiles, pads: pads)
        checkCrocodileEnemyCollisions(crocodiles: crocodiles, enemies: enemies)
        checkCrocodileSnakeCollisions(crocodiles: crocodiles, snakes: snakes)
    }
    
    private func checkFrogBoatCollision(frog: Frog, boat: Boat?) {
        guard let boat = boat, !frog.isInvincible else { return }

        // AABB (Axis-Aligned Bounding Box) check
        let frogFrame = frog.calculateAccumulatedFrame()
        
        // Create a smaller hitbox for the boat, half its visual size, centered on its position.
        let boatSize = boat.size
        let hitBoxSize = CGSize(width: boatSize.width / 4, height: boatSize.height / 5)
        let hitBoxOrigin = CGPoint(x: boat.position.x - hitBoxSize.width / 5,
                                   y: boat.position.y - hitBoxSize.height / 5)
        let smallerBoatFrame = CGRect(origin: hitBoxOrigin, size: hitBoxSize)

        if frogFrame.intersects(smallerBoatFrame) {
            delegate?.didCrash(into: boat)
        }
    }
    
    private func checkCrocodileEnemyCollisions(crocodiles: [Crocodile], enemies: [Enemy]) {
        let crocHW: CGFloat = 150
        let crocHH: CGFloat = 60
        
        for crocodile in crocodiles {
            // Only destroy enemies when carrying the frog
            guard crocodile.state == .carrying && crocodile.isCarryingFrog else { continue }
            
            for enemy in enemies {
                let dx = abs(crocodile.position.x - enemy.position.x)
                let dy = abs(crocodile.position.y - enemy.position.y)
                
                // Enemy collision radius
                let enemyRadius: CGFloat = 20
                
                if dx < (crocHW + enemyRadius) && dy < (crocHH + enemyRadius) {
                    delegate?.crocodileDidDestroy(enemy: enemy)
                }
            }
        }
    }
    
    private func checkCrocodileSnakeCollisions(crocodiles: [Crocodile], snakes: [Snake]) {
        let crocHW: CGFloat = 150
        let crocHH: CGFloat = 60
        
        for crocodile in crocodiles {
            // Only destroy snakes when carrying the frog
            guard crocodile.state == .carrying && crocodile.isCarryingFrog else { continue }
            
            for snake in snakes where !snake.isDestroyed {
                let dx = abs(crocodile.position.x - snake.position.x)
                let dy = abs(crocodile.position.y - snake.position.y)
                
                // Snake collision radius
                let snakeRadius: CGFloat = snake.scaledRadius
                
                if dx < (crocHW + snakeRadius) && dy < (crocHH + snakeRadius) {
                    delegate?.crocodileDidDestroy(snake: snake)
                }
            }
        }
    }
    
    private func checkCrocodilePadCollisions(crocodiles: [Crocodile], pads: [Pad]) {
        // Crocodile half-extents (300x120 size -> 150x60 half)
        let crocHW: CGFloat = 150
        let crocHH: CGFloat = 60
        
        for crocodile in crocodiles {
            // Only check collision for visible crocodiles (not submerged)
            guard crocodile.state != .submerged else { continue }
            
            // Check if crocodile is carrying (destroys obstacles) or not (gets pushed)
            let isCarrying = crocodile.state == .carrying && crocodile.isCarryingFrog
            
            for pad in pads {
                // Determine dimensions of the pad
                let padHW: CGFloat = (pad.type == .log) ? 60 : 50
                let padHH: CGFloat = (pad.type == .log) ? 20 : 50
                
                let dx = crocodile.position.x - pad.position.x
                let dy = crocodile.position.y - pad.position.y
                let absDx = abs(dx)
                let absDy = abs(dy)
                
                let overlapX = absDx < (crocHW + padHW)
                let overlapY = absDy < (crocHH + padHH)
                
                if overlapX && overlapY {
                    if isCarrying {
                        // DESTROY the pad/log when carrying the frog!
                        delegate?.crocodileDidDestroy(pad: pad)
                    } else {
                        // Push crocodile away from the pad when not carrying
                        let overlapAmountX = (crocHW + padHW) - absDx
                        let overlapAmountY = (crocHH + padHH) - absDy
                        
                        if overlapAmountX < overlapAmountY {
                            // Push horizontally
                            if dx > 0 {
                                crocodile.position.x += overlapAmountX * 0.5
                            } else {
                                crocodile.position.x -= overlapAmountX * 0.5
                            }
                        } else {
                            // Push vertically (usually upstream since croc moves that way)
                            if dy > 0 {
                                crocodile.position.y += overlapAmountY * 0.5
                            } else {
                                crocodile.position.y -= overlapAmountY * 0.5
                            }
                        }
                        
                        // Keep crocodile within river bounds after push
                        crocodile.constrainToRiver()
                    }
                }
            }
        }
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
    
    private func checkForLanding(frog: Frog, pads: [Pad], crocodiles: [Crocodile] = []) {
        var hasLanded = false
        
        // Check for crocodile landing
        for crocodile in crocodiles {
            // Check for crocodile landing
            if crocodile.state == .carrying && crocodile.isCarryingFrog {
                let dx = abs(frog.position.x - crocodile.position.x)
                let dy = abs(frog.position.y - crocodile.position.y)
                
                // Minimal safety buffer - only 15% of frog radius for tighter landing requirement
                let safetyBuffer = frogRadius * 0.15
                let halfW: CGFloat = 150 + safetyBuffer
                let halfH: CGFloat = 60 + safetyBuffer
                
                // Only count as landed if frog is still positioned on the crocodile
                if dx < halfW && dy < halfH {
                    hasLanded = true
                    break
                }
            }
            // Check for new crocodile landing (idle or fleeing crocodiles)
            else if crocodile.state == .idle || crocodile.state == .fleeing {
                let dx = abs(frog.position.x - crocodile.position.x)
                let dy = abs(frog.position.y - crocodile.position.y)
                
                // Rectangular hitbox for crocodile (300x120 size - 3x bigger)
                // Minimal safety buffer - only 15% of frog radius for tighter landing requirement
                let safetyBuffer = frogRadius * 0.15
                let halfW: CGFloat = 150 + safetyBuffer
                let halfH: CGFloat = 60 + safetyBuffer
                
                if dx < halfW && dy < halfH {
                    hasLanded = true
                    delegate?.didLand(on: crocodile)
                    return
                }
            }
        }
        
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
                // Minimal safety buffer - only 15% of frog radius for tighter landing requirement
                let safetyBuffer = frogRadius * 0.15
                let halfW: CGFloat = 60 + safetyBuffer
                let halfH: CGFloat = 20 + safetyBuffer
                let dx = abs(frog.position.x - pad.position.x)
                let dy = abs(frog.position.y - pad.position.y)
                if dx < halfW && dy < halfH {
                    isHit = true
                }
            } else {
                // Circle Pad Logic
                let currentPadRadius = pad.scaledRadius
                let safetyBuffer = frogRadius * 0.10
                let hitDistance = currentPadRadius + safetyBuffer
                
                // 1. Broad Phase: Simple Box Check (Fastest)
                if abs(frog.position.x - pad.position.x) > hitDistance { continue }
                if abs(frog.position.y - pad.position.y) > hitDistance { continue }
                
                // 2. Narrow Phase: Squared Distance (Fast)
                let dx = frog.position.x - pad.position.x
                let dy = frog.position.y - pad.position.y
                let distSq = (dx * dx) + (dy * dy)
                let hitDistanceSq = hitDistance * hitDistance // Pre-calculate squared radius
                
                if distSq < hitDistanceSq {
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
    
    private func checkEntityCollisions(frog: Frog, enemies: [Enemy], coins: [Coin], treasureChests: [TreasureChest], snakes: [Snake], flies: [Fly]) {
        for coin in coins where !coin.isCollected {
            let dx = frog.position.x - coin.position.x
            let dy = frog.position.y - coin.position.y
            let distSq = (dx * dx) + (dy * dy)
            if distSq < coinRadiusSq {
                coin.isCollected = true
                delegate?.didCollect(coin: coin)
            }
        }
        
        // Check treasure chest collisions
        for chest in treasureChests where !chest.isCollected {
            let dx = frog.position.x - chest.position.x
            let dy = frog.position.y - chest.position.y
            let distSq = (dx * dx) + (dy * dy)
            
            // Check horizontal proximity and z-height proximity
            // Allow collection during rocket flight regardless of z-height
            let zDiff = abs(frog.zHeight - chest.zHeight)
            let canCollect: Bool
            if frog.rocketState != .none {
                // During rocket flight, ignore z-height and just check horizontal distance
                canCollect = distSq < chestRadiusSq
            } else {
                // Normal collection requires being near the chest level
                canCollect = distSq < chestRadiusSq && zDiff < 25
            }
            
            if canCollect {
                delegate?.didCollect(treasureChest: chest)
            }
        }
        
        // Check fly collisions
        for fly in flies where !fly.isCollected {
            let dx = frog.position.x - fly.position.x
            let dy = frog.position.y - fly.position.y
            let distSq = (dx * dx) + (dy * dy)
            if distSq < flyRadiusSq {
                delegate?.didCollect(fly: fly)
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
        
        // Check snake collisions
        for snake in snakes where !snake.isDestroyed {
            let dx = frog.position.x - snake.position.x
            let dy = frog.position.y - snake.position.y
            let distSq = (dx * dx) + (dy * dy)
            let zDiff = abs(frog.zHeight - snake.zHeight)
            
            // Snake radius collision check
            let snakeRadiusSq = pow(snake.scaledRadius + frogRadius, 2)
            if distSq < snakeRadiusSq && zDiff < 20 {
                delegate?.didCrash(into: snake)
            }
        }
    }
}
