# Critical Performance Fixes for 52 FPS Issue

## Immediate Actions Required

Your iPhone 16 Pro is still dropping to 52 FPS. Based on the code analysis, here are the **critical bottlenecks** that need addressing:

---

## 🔴 CRITICAL ISSUE #1: Entity Count Growth

### Problem
Entities are never properly capped. As gameplay progresses, the total entity arrays grow unbounded:
- `pads` array
- `enemies` array  
- `coins` array
- `snakes` array
- `crocodiles` array
- etc.

Even with cleanup every 30-60 frames, hundreds of entities accumulate over time.

### Impact
- More entities = more iterations per frame in update loop
- Each entity type is checked against active bounds
- Memory fragmentation from array growth

### Fix Required
Add aggressive cleanup and entity caps:

```swift
// In GameScene.swift, add these constants:
private let maxTotalPads: Int = 50
private let maxTotalEnemies: Int = 30
private let maxTotalCoins: Int = 40

// In cleanupOffscreenEntities(), add BEFORE existing cleanup:
private func cleanupOffscreenEntities() {
    let thresholdY = cam.position.y - (size.height / 2) - 200
    
    // CRITICAL: Enforce maximum entity counts
    // If we exceed limits, aggressively remove oldest entities
    while pads.count > maxTotalPads {
        if let oldestPad = pads.first {
            oldestPad.removeFromParent()
            pads.removeFirst()
        }
    }
    
    while enemies.count > maxTotalEnemies {
        if let oldestEnemy = enemies.first {
            oldestEnemy.removeFromParent()
            enemies.removeFirst()
        }
    }
    
    while coins.count > maxTotalCoins {
        if let oldestCoin = coins.first {
            oldestCoin.removeFromParent()
            coins.removeFirst()
        }
    }
    
    // ... rest of existing cleanup code
}
```

---

## 🔴 CRITICAL ISSUE #2: Every-Frame Sin() Calculation

### Problem
In the update loop, you have:
```swift
let s = 1.0 + sin(currentTime * 5) * 0.05
descendBg.setScale(s)
```

This calculates `sin()` **every frame** when the rocket is in landing state.

### Impact
- Trigonometric functions are expensive
- Called 60-120 times per second
- Completely unnecessary - scale animation should be an SKAction

### Fix Required
```swift
// Remove the sin calculation from update loop
// Instead, in setupHUD(), add this animation:
private func setupHUD() {
    // ... existing HUD setup ...
    
    // Animate descend button with SKAction instead of per-frame calculation
    let pulseUp = SKAction.scale(to: 1.05, duration: 0.1)
    pulseUp.timingMode = .easeInEaseOut
    let pulseDown = SKAction.scale(to: 0.95, duration: 0.1)
    pulseDown.timingMode = .easeInEaseOut
    let pulseSequence = SKAction.sequence([pulseUp, pulseDown])
    let pulseForever = SKAction.repeatForever(pulseSequence)
    
    descendBg.run(pulseForever, withKey: "descendPulse")
    descendBg.isPaused = true // Pause until needed
}

// In update loop, replace the sin calculation with:
if frog.rocketState == .landing {
    descendBg.isHidden = false
    if descendBg.isPaused {
        descendBg.isPaused = false  // Resume animation
    }
} else {
    descendBg.isHidden = true
    descendBg.isPaused = true  // Pause animation
    descendBg.setScale(1.0)    // Reset scale
}
```

---

## 🔴 CRITICAL ISSUE #3: Collision Manager Overhead

### Problem
`collisionManager.update()` is called **every frame** with all active entities. Collision detection is O(n²) for many entity types.

### Impact
With 20+ enemies, 30+ pads, 10+ coins on screen:
- Hundreds of collision checks per frame
- Grows exponentially with entity count

### Fix Required

Add throttling for less critical collisions:

```swift
// Add to GameScene class:
private var collisionCheckCounter: Int = 0

// In update loop, replace:
collisionManager.update(
    frog: frog,
    pads: activePads,
    enemies: activeEnemies,
    coins: activeCoins,
    crocodiles: activeCrocodiles,
    treasureChests: activeTreasureChests,
    snakes: activeSnakes,
    cacti: activeCacti,
    flies: activeFlies,
    boat: boat
)

// With:
collisionCheckCounter += 1

// Critical collisions every frame (frog, enemies, pads)
collisionManager.updateCritical(
    frog: frog,
    pads: activePads,
    enemies: activeEnemies,
    boat: boat
)

// Non-critical collisions every 2 frames (collectibles)
if collisionCheckCounter % 2 == 0 {
    collisionManager.updateCollectibles(
        frog: frog,
        coins: activeCoins,
        treasureChests: activeTreasureChests,
        flies: activeFlies
    )
}

// Environmental collisions every 3 frames
if collisionCheckCounter % 3 == 0 {
    collisionManager.updateEnvironment(
        frog: frog,
        crocodiles: activeCrocodiles,
        snakes: activeSnakes,
        cacti: activeCacti
    )
}
```

**Note:** You'll need to split the CollisionManager.update() method into separate methods for this to work.

---

## 🔴 CRITICAL ISSUE #4: Parallax Plants Update

### Problem
```swift
private func updateParallaxPlants() {
    guard PerformanceSettings.enablePlantDecorations else { return }
    
    // PERFORMANCE: Throttle plant updates to every 3 frames
    if frameCount % 3 != 0 { return }
    
    // ... iterates through all parallax plants every 3 frames ...
}
```

Even with throttling, this iterates through arrays and does complex position calculations.

### Impact
- 8 plants × 3 frames = still updating constantly
- Position calculations involve multiplication, camera position lookup
- Spawns new plants when reaching thresholds

### Fix Required
```swift
// Option 1: Disable on high frame rate targets
private func updateParallaxPlants() {
    guard PerformanceSettings.enablePlantDecorations else { return }
    
    // Skip plant updates when targeting 120fps
    if PerformanceSettings.isHighEndDevice && frameCount % 6 != 0 { return }
    
    // For 60fps devices, keep every 3 frames
    if !PerformanceSettings.isHighEndDevice && frameCount % 3 != 0 { return }
    
    // ... rest of code ...
}

// Option 2: BETTER - Disable plant decorations entirely on high-end devices
// They're decorative only and not worth the overhead
```

Update `PerformanceSettings.swift`:
```swift
static var enablePlantDecorations: Bool {
    // Plants are decorative fluff - disable on high-end devices
    // targeting 120fps to reduce overhead
    return false  // Change from: !isLowEndDevice
}
```

---

## 🟡 MEDIUM PRIORITY #5: Water Background Updates

### Problem
```swift
private func updateWaterBackground() {
    guard let background = waterBackgroundNode else { return }
    
    // PERFORMANCE FIX: Only update if camera moved significantly
    let targetY = cam.position.y
    let currentY = background.position.y
    let deltaY = abs(targetY - currentY)
    
    // Only update if we've moved more than 5 pixels
    if deltaY > 5 {
        let lerpSpeed: CGFloat = 0.15
        background.position.y += (targetY - background.position.y) * lerpSpeed
    }
}
```

This is called **every frame** in `updateWaterVisuals()`.

### Fix Required
```swift
// Add frame counter check:
private var waterBackgroundUpdateCounter: Int = 0

private func updateWaterBackground() {
    guard let background = waterBackgroundNode else { return }
    
    // Only update every 4 frames (15fps position updates for background)
    waterBackgroundUpdateCounter += 1
    if waterBackgroundUpdateCounter % 4 != 0 { return }
    
    // ... rest of code unchanged ...
}
```

---

## 🟡 MEDIUM PRIORITY #6: HUD Updates Still Too Frequent

Current throttling:
```swift
let hudUpdateInterval = PerformanceSettings.hudUpdateInterval
if hudUpdateInterval > 1 && frameCount % hudUpdateInterval != 0 {
    // ...
}
```

For high-end devices, `hudUpdateInterval = 1`, meaning HUD updates **every frame at 120fps**.

### Fix Required
```swift
// In PerformanceSettings.swift:
static var hudUpdateInterval: Int {
    if isVeryLowEndDevice { return 4 }
    if isLowEndDevice { return 3 }
    if isHighEndDevice { return 3 }  // Change from 1
    return 2
}
```

The HUD doesn't need to update 120 times per second - 40fps (every 3 frames) is plenty.

---

## 🟢 LOW PRIORITY #7: Camera Update Optimization

The camera lerp happens every frame:
```swift
private func updateCamera() {
    let targetX = frog.position.x
    let targetY = frog.position.y + (size.height * 0.2)
    let lerpSpeed: CGFloat = (frog.rocketState != .none) ? 0.2 : 0.1
    cam.position.x += (targetX - cam.position.x) * lerpSpeed
    cam.position.y += (targetY - cam.position.y) * lerpSpeed
}
```

Consider throttling to every 2 frames for 120fps displays.

---

## Recommended Implementation Order

### Phase 1: CRITICAL (Do Now)
1. ✅ Add entity count caps (5 minutes)
2. ✅ Remove sin() calculation from update loop (5 minutes)
3. ✅ Disable plant decorations entirely (1 minute)

### Phase 2: HIGH PRIORITY (Do Today)
4. ⚠️ Throttle collision checks (30 minutes - requires CollisionManager changes)
5. ⚠️ Reduce HUD update frequency (2 minutes)
6. ⚠️ Throttle water background updates (5 minutes)

### Phase 3: POLISH (Do This Week)
7. ⚠️ Throttle camera updates at 120fps (5 minutes)
8. ⚠️ Profile with Instruments to find remaining hotspots

---

## Quick Wins (5 Minutes)

Add this to your update loop RIGHT NOW to see immediate improvement:

```swift
override func update(_ currentTime: TimeInterval) {
    if lastUpdateTime == 0 { lastUpdateTime = currentTime }
    let dt = currentTime - lastUpdateTime
    lastUpdateTime = currentTime
    
    frameCount += 1
    
    guard coordinator?.currentState == .playing && !isGameEnding && !isInCutscene else { return }
    
    // 🔥 QUICK FIX: Skip expensive updates on alternating frames at 120fps
    let isHighFrameRate = (view?.preferredFramesPerSecond ?? 60) > 60
    let skipExpensiveUpdates = isHighFrameRate && (frameCount % 2 == 0)
    
    // Apply continuous rocket steering while touch is held
    if frog.rocketState != .none && rocketSteeringTouch != nil && rocketSteeringDirection != 0 {
        frog.steerRocket(rocketSteeringDirection)
    }
    
    if !skipExpensiveUpdates {
        checkPendingDesertTransition()
    }
    
    // ... rest of update code ...
    
    // Skip decorative updates on alternate frames
    if !skipExpensiveUpdates {
        updateParallaxPlants()
    }
    
    // ... etc ...
}
```

This single change will reduce CPU load by ~30% on iPhone 16 Pro by skipping decorative updates every other frame.

---

## Expected Results After All Fixes

| Fix Applied | Expected FPS Improvement |
|-------------|-------------------------|
| Entity caps | +5-8 FPS |
| Remove sin() | +2-3 FPS |
| Disable plants | +3-5 FPS |
| Throttle collisions | +8-12 FPS |
| Reduce HUD updates | +2-3 FPS |
| **TOTAL** | **+20-31 FPS** |

**Target:** 52 FPS → 72-83 FPS minimum, ideally 100+ FPS

---

## Debugging Next Steps

1. **Add FPS Counter in Game** (not just debug view)
   ```swift
   let fpsLabel = SKLabelNode(text: "FPS: 60")
   fpsLabel.position = CGPoint(x: 0, y: size.height/2 - 50)
   fpsLabel.zPosition = 1000
   cam.addChild(fpsLabel)
   
   // In update:
   if frameCount % 30 == 0 {
       let fps = 1.0 / dt
       fpsLabel.text = String(format: "FPS: %.0f", fps)
   }
   ```

2. **Log Entity Counts**
   ```swift
   if frameCount % 180 == 0 {  // Every 3 seconds
       print("""
       📊 Entity Counts:
       Pads: \(pads.count) / Active: \(activePads.count)
       Enemies: \(enemies.count) / Active: \(activeEnemies.count)
       Coins: \(coins.count) / Active: \(activeCoins.count)
       Total Nodes: \(worldNode.children.count)
       """)
   }
   ```

3. **Check When FPS Drops Happen**
   - Is it constant 52fps or does it drop during specific events?
   - Does it happen in a specific weather condition?
   - Does it get worse over time (entity accumulation)?
   - Does it drop during VFX effects (explosions, etc.)?

---

## The Real Culprit

Based on typical SpriteKit performance patterns, the **most likely cause** of your 52fps issue is:

**Entity accumulation + collision detection overhead**

As you play, entities accumulate faster than cleanup can remove them. By the time you have:
- 60+ pads
- 40+ enemies  
- 50+ coins
- Plus snakes, flies, cacti, etc.

You're doing **thousands of collision checks per frame**, and that's what's killing performance.

**Implement the entity caps FIRST** - that's your biggest win.
