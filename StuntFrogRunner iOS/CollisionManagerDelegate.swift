import SpriteKit

protocol CollisionManagerDelegate: AnyObject {
    func didLand(on pad: Pad)
    func didCrash(into enemy: Enemy)
    func didCrash(into snake: Snake)
    func didCrash(into cactus: Cactus)
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
    func didDestroyEnemyWithHoney(_ enemy: Enemy)
    func didDestroySnakeWithAxe(_ snake: Snake)
    func didDestroyCactusWithAxe(_ cactus: Cactus)
    func didDestroyLogWithAxe(_ log: Pad)
    func didDestroyDragonflyWithSwatter(_ dragonfly: Enemy)
}

class CollisionManager {
    
    weak var delegate: CollisionManagerDelegate?
    
    private let coinRadiusSq: CGFloat
    private let chestRadiusSq: CGFloat
    private let enemyRadiusSq: CGFloat
    private let flyRadiusSq: CGFloat
    private let cactusRadiusSq: CGFloat
    private let frogRadius: CGFloat
    
    init() {
        let coinR: CGFloat = 20.0
        let chestR: CGFloat = 25.0  // Slightly larger than coins
        let enemyR: CGFloat = 15.0
        let flyR: CGFloat = 15.0  // Small collision radius for fly
        let cactusR: CGFloat = 20.0  // Cactus collision radius
        let frogR = Configuration.Dimensions.frogRadius
        
        self.coinRadiusSq = pow(coinR + frogR, 2)
        self.chestRadiusSq = pow(chestR + frogR, 2)
        self.enemyRadiusSq = pow(enemyR + frogR, 2)
        self.flyRadiusSq = pow(flyR + frogR, 2)
        self.cactusRadiusSq = pow(cactusR + frogR, 2)
        self.frogRadius = frogR
    }
    
    func update(frog: Frog, pads: [Pad], enemies: [Enemy], coins: [Coin], crocodiles: [Crocodile] = [], treasureChests: [TreasureChest] = [], snakes: [Snake] = [], cacti: [Cactus] = [], flies: [Fly] = [], boat: Boat? = nil) {
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
        
        checkEntityCollisions(frog: frog, enemies: enemies, coins: coins, treasureChests: treasureChests, snakes: snakes, cacti: cacti, flies: flies, pads: pads)
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
                let safetyBuffer = frogRadius * 0.01
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
    
    private func checkEntityCollisions(frog: Frog, enemies: [Enemy], coins: [Coin], treasureChests: [TreasureChest], snakes: [Snake], cacti: [Cactus], flies: [Fly], pads: [Pad]) {
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
        
        // Check honey attack on bees (before invincibility check so honey always works)
        // BUT skip if super jumping - super jump handles all collisions without using items
        if frog.buffs.honey > 0 && !frog.isSuperJumping {
            var beeToDestroy: Enemy?
            
            for enemy in enemies where enemy.type == "BEE" && !enemy.isBeingDestroyed {
                let dx = frog.position.x - enemy.position.x
                let dy = frog.position.y - enemy.position.y
                let distSq = (dx * dx) + (dy * dy)
                let zDiff = abs(frog.zHeight - enemy.zHeight)
                
                // Honey attack range is slightly larger than collision range
                let honeyRangeSq = pow(60 + frogRadius, 2) // ~80 pixel range
                
                // If bee is in range and frog has honey, automatically throw honey
                if distSq < honeyRangeSq && zDiff < 40 {
                    beeToDestroy = enemy
                    break // Only attack one bee per frame
                }
            }
            
            // Execute honey attack outside the loop to avoid concurrent modification
            if let bee = beeToDestroy {
                // Mark as being destroyed IMMEDIATELY
                bee.isBeingDestroyed = true
                
                // Trigger honey attack animation
                frog.throwHoneyAt(bee) {
                    // Enemy will be removed after animation completes
                    bee.removeFromParent()
                }
                // Mark bee for removal (delegate should handle array cleanup)
                delegate?.didDestroyEnemyWithHoney(bee)
            }
        }
        
        // Check swatter attack on dragonflies (before invincibility check so swatter always works)
        // BUT skip if super jumping - super jump handles all collisions without using items
        if frog.buffs.swatter > 0 && !frog.isSuperJumping {
            var dragonflyToDestroy: Enemy?
            
            for enemy in enemies where enemy.type == "DRAGONFLY" && !enemy.isBeingDestroyed {
                let dx = frog.position.x - enemy.position.x
                let dy = frog.position.y - enemy.position.y
                let distSq = (dx * dx) + (dy * dy)
                let zDiff = abs(frog.zHeight - enemy.zHeight)
                
                // Swatter attack range (similar to honey)
                let swatterRangeSq = pow(60 + frogRadius, 2) // ~80 pixel range
                
                // If dragonfly is in range and frog has swatter, automatically swat it
                if distSq < swatterRangeSq && zDiff < 40 {
                    print("🏸 SWATTER: Found dragonfly in range! Distance: \(sqrt(distSq)), Z-diff: \(zDiff)")
                    dragonflyToDestroy = enemy
                    break // Only attack one dragonfly per frame
                }
            }
            
            // Execute swatter attack outside the loop to avoid concurrent modification
            if let dragonfly = dragonflyToDestroy {
                print("🏸 SWATTER: Starting attack animation!")
                // Mark as being destroyed IMMEDIATELY
                dragonfly.isBeingDestroyed = true
                
                // Trigger swatter attack animation
                frog.swatDragonfly(dragonfly) {
                    print("🏸 SWATTER: Animation completed, removing dragonfly from parent")
                    // Dragonfly will be removed after animation completes
                    dragonfly.removeFromParent()
                }
                // Mark dragonfly for removal (delegate should handle array cleanup)
                delegate?.didDestroyDragonflyWithSwatter(dragonfly)
            }
        }
        
        // Check axe attack on snakes, cacti, and logs (before invincibility check)
        // BUT skip if super jumping - super jump handles all collisions without using items
        if frog.buffs.axe > 0 && !frog.isSuperJumping {
            var targetToDestroy: GameEntity?
            var targetType: AxeTargetType = .snake
            
            enum AxeTargetType {
                case snake
                case cactus
                case log
            }
            
            // Check snakes first
            for snake in snakes where !snake.isDestroyed {
                let dx = frog.position.x - snake.position.x
                let dy = frog.position.y - snake.position.y
                let distSq = (dx * dx) + (dy * dy)
                let zDiff = abs(frog.zHeight - snake.zHeight)
                
                // Axe attack range (~80 pixel range)
                let axeRangeSq = pow(60 + frogRadius, 2)
                
                if distSq < axeRangeSq && zDiff < 40 {
                    targetToDestroy = snake
                    targetType = .snake
                    break // Only attack one target per frame
                }
            }
            
            // Check cacti if no snake found
            if targetToDestroy == nil {
                for cactus in cacti where !cactus.isDestroyed {
                    guard let parentPad = cactus.parent as? SKNode else { continue }
                    let cactusWorldPos = parentPad.convert(cactus.position, to: cactus.scene ?? parentPad)
                    
                    let dx = frog.position.x - cactusWorldPos.x
                    let dy = frog.position.y - cactusWorldPos.y
                    let distSq = (dx * dx) + (dy * dy)
                    let zDiff = abs(frog.zHeight - cactus.zHeight)
                    
                    let axeRangeSq = pow(60 + frogRadius, 2)
                    
                    if distSq < axeRangeSq && zDiff < 40 {
                        targetToDestroy = cactus
                        targetType = .cactus
                        break
                    }
                }
            }
            
            // Check logs if no snake or cactus found
            if targetToDestroy == nil {
                for pad in pads where pad.type == .log {
                    let dx = frog.position.x - pad.position.x
                    let dy = frog.position.y - pad.position.y
                    let distSq = (dx * dx) + (dy * dy)
                    let zDiff = abs(frog.zHeight)
                    
                    let axeRangeSq = pow(80 + frogRadius, 2) // Slightly larger for logs
                    
                    if distSq < axeRangeSq && zDiff < 40 {
                        targetToDestroy = pad
                        targetType = .log
                        break
                    }
                }
            }
            
            // Execute axe attack outside the loop to avoid concurrent modification
            if let target = targetToDestroy {
                switch targetType {
                case .snake:
                    if let snake = target as? Snake {
                        snake.isDestroyed = true
                        frog.throwAxeAt(snake) {
                            snake.removeFromParent()
                        }
                        delegate?.didDestroySnakeWithAxe(snake)
                    }
                    
                case .cactus:
                    if let cactus = target as? Cactus {
                        cactus.isDestroyed = true
                        frog.throwAxeAt(cactus) {
                            cactus.removeFromParent()
                        }
                        delegate?.didDestroyCactusWithAxe(cactus)
                    }
                    
                case .log:
                    if let log = target as? Pad, log.type == .log {
                        frog.throwAxeAt(log) {
                            log.removeFromParent()
                        }
                        delegate?.didDestroyLogWithAxe(log)
                    }
                }
            }
        }
        
        if frog.isInvincible { return }
        
        for enemy in enemies where !enemy.isBeingDestroyed {
            let dx = frog.position.x - enemy.position.x
            let dy = frog.position.y - enemy.position.y
            let distSq = (dx * dx) + (dy * dy)
            let zDiff = abs(frog.zHeight - enemy.zHeight)
            
            if distSq < enemyRadiusSq && zDiff < 30 {
                // Mark enemy as being destroyed IMMEDIATELY to prevent re-triggering
                enemy.isBeingDestroyed = true
                delegate?.didCrash(into: enemy)
            }
        }
        
        // Check snake collisions
        for snake in snakes where !snake.isDestroyed {
            let dx = frog.position.x - snake.position.x
            let dy = frog.position.y - snake.position.y
            let distSq = (dx * dx) + (dy * dy)
            let zDiff = frog.zHeight - snake.zHeight
            
            // Snake radius collision check
            let snakeRadiusSq = pow(snake.scaledRadius + frogRadius, 2)
            
            // Only collide if frog is not significantly above the snake
            // Frog can jump over snakes if zHeight difference > 10
            // (changed from zDiff < 20 to allow jumping over)
            if distSq < snakeRadiusSq && zDiff < 10 {
                delegate?.didCrash(into: snake)
            }
        }
        
        // Check cactus collisions (cacti are stationary on lily pads)
        for cactus in cacti where !cactus.isDestroyed {
            // Cacti are children of pads, so we need to get their world position
            // Since cactus.position is (0,0) relative to its parent pad, we use the parent's position
            guard let parentPad = cactus.parent as? SKNode else { continue }
            
            // Get the cactus position in world coordinates
            let cactusWorldPos = parentPad.convert(cactus.position, to: cactus.scene ?? parentPad)
            
            let dx = frog.position.x - cactusWorldPos.x
            let dy = frog.position.y - cactusWorldPos.y
            let distSq = (dx * dx) + (dy * dy)
            let zDiff = frog.zHeight - cactus.zHeight
            
            // Only collide if frog is on the same level (not jumping significantly above)
            // Frog can jump over cacti if zHeight difference > 10
            if distSq < cactusRadiusSq && zDiff < 10 {
                delegate?.didCrash(into: cactus)
            }
        }
    }
}
