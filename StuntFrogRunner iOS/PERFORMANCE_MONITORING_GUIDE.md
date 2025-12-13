# Performance Monitoring Quick Reference

## 🎯 Target Metrics (iPhone 14)

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| **FPS** | 60 | < 55 | < 45 |
| **Node Count** | < 300 | 300-500 | > 500 |
| **CPU Usage** | < 50% | 50-70% | > 70% |
| **Memory** | < 200 MB | 200-300 MB | > 300 MB |
| **Draw Calls** | < 100 | 100-150 | > 150 |

---

## 🔍 How to Monitor

### In-Game Display (Debug Builds)
```swift
#if DEBUG
skView.showsFPS = true          // Shows FPS and Node Count
skView.showsNodeCount = true
skView.showsDrawCount = true    // Shows draw calls
#endif
```

### Xcode Debug Navigator
While running on device:
- **CPU**: Shows real-time CPU usage
- **Memory**: Shows memory consumption
- **Energy**: Shows power efficiency
- **Disk**: Shows file I/O operations

### Instruments (Detailed Profiling)

#### Time Profiler
```
Product → Profile → Time Profiler
```
**Look for**:
- Methods taking > 16.67ms per frame (60 FPS threshold)
- Hot spots in `update(_:)` method
- Expensive rendering operations

**Key Methods to Watch**:
- `updateWaterVisuals()` - Should be < 1ms
- `update(_:)` - Should be < 15ms total
- `updateTrajectoryVisuals()` - Should be < 2ms
- `collisionManager.update()` - Should be < 5ms

#### Allocations Instrument
```
Product → Profile → Allocations
```
**Look for**:
- Memory leaks (persistent growth)
- Excessive allocations in game loop
- Large texture memory usage

#### Core Animation Instrument
```
Product → Profile → Core Animation
```
**Check**:
- Frame rate consistency
- Drawing performance
- Offscreen rendering

---

## 🚨 Common Performance Issues

### Issue: Low FPS (< 55)
**Possible Causes**:
- Too many nodes on screen (check node count)
- Expensive update calculations
- Scene graph searches (`enumerateChildNodes`)
- Unoptimized collision detection

**Quick Fixes**:
1. Check that water tile optimization is active
2. Verify cleanup is running regularly
3. Ensure texture preloading completed
4. Check for entity culling issues

### Issue: Frame Rate Drops During Gameplay
**Possible Causes**:
- Weather transition loading textures
- Too many active entities
- Memory pressure causing GC pauses
- Particle effects overwhelming GPU

**Quick Fixes**:
1. Verify textures are preloaded
2. Check active entity counts in update loop
3. Reduce particle birth rates
4. Check for memory warnings

### Issue: High Node Count (> 500)
**Possible Causes**:
- Entities not being cleaned up
- Particle nodes accumulating
- UI elements duplicated
- Pool objects not being reused

**Quick Fixes**:
1. Verify `cleanupOffscreenEntities()` is running
2. Check that pooled objects are being returned
3. Look for nodes added but never removed
4. Check for action-created nodes

### Issue: High Memory Usage (> 250 MB)
**Possible Causes**:
- Texture memory not being released
- Retain cycles preventing deallocation
- Large texture assets
- Cached data not being cleared

**Quick Fixes**:
1. Profile with Instruments → Allocations
2. Check for strong reference cycles
3. Verify textures are appropriate size
4. Clear caches when transitioning

---

## 📱 Device-Specific Thresholds

### iPhone 15+ (High-End)
- **Target FPS**: 60 (consistent)
- **Max Nodes**: 500
- **CPU**: < 40%
- **Settings**: All effects enabled

### iPhone 14 (Low-End)
- **Target FPS**: 58-60
- **Max Nodes**: 400
- **CPU**: < 60%
- **Settings**: Reduced particle effects

### iPhone 12-13 (Mid-Range)
- **Target FPS**: 58-60
- **Max Nodes**: 400
- **CPU**: < 55%
- **Settings**: Moderate reduction

### iPhone 11 and Older (Very Low-End)
- **Target FPS**: 55-58
- **Max Nodes**: 300
- **CPU**: < 70%
- **Settings**: Aggressive optimization

---

## ⚡ Performance Red Flags

### Immediate Action Required
- ❌ FPS drops below 45
- ❌ Memory exceeds 400 MB
- ❌ CPU usage consistently above 80%
- ❌ Hitches/freezes during gameplay
- ❌ Node count exceeds 600

### Investigation Needed
- ⚠️ FPS varies widely (40-60 range)
- ⚠️ Memory gradually increases over time
- ⚠️ Draw calls exceed 150
- ⚠️ CPU spikes during specific actions
- ⚠️ Node count steadily increasing

### Monitoring Suggested
- ℹ️ FPS occasionally dips to 55
- ℹ️ Memory fluctuates 200-250 MB
- ℹ️ CPU usage spikes briefly
- ℹ️ Node count varies with gameplay

---

## 🛠️ Quick Diagnostic Commands

### Print Current Performance Stats
Add to your GameScene for manual checks:
```swift
func printPerformanceStats() {
    print("🎮 Performance Stats:")
    print("   Nodes: \(view?.scene?.children.count ?? 0)")
    print("   Pads: \(pads.count)")
    print("   Active Pads: \(activePads.count)")
    print("   Enemies: \(enemies.count)")
    print("   Active Enemies: \(activeEnemies.count)")
    print("   Ripple Pool: \(ripplePool.count)")
    print("   Device: \(PerformanceSettings.isLowEndDevice ? "Low-End" : "High-End")")
}
```

Call it during debugging:
```swift
// In update loop, triggered by condition:
if frameCount % 300 == 0 { // Every 5 seconds at 60 FPS
    printPerformanceStats()
}
```

### Check for Memory Leaks
```swift
// Monitor total node count
print("Total Scene Nodes: \(worldNode.descendants.count)")

// Check pool utilization
print("Ripple Pool Active: \(ripplePool.filter { $0.parent != nil }.count)/\(ripplePool.count)")
print("Trajectory Dots Active: \(trajectoryDots.filter { !$0.isHidden }.count)/\(trajectoryDots.count)")
```

---

## 📊 Benchmark Test Sequence

Run through this sequence to validate performance:

1. **Startup** (0-30 seconds)
   - [ ] FPS reaches 60 within 5 seconds
   - [ ] Node count stabilizes under 200
   - [ ] No memory spikes

2. **Normal Gameplay** (30-120 seconds)
   - [ ] FPS maintains 58+ consistently
   - [ ] Node count stays under max threshold
   - [ ] Memory stays under 250 MB

3. **Weather Transitions** (at each transition)
   - [ ] No frame drops during fade
   - [ ] Texture loads smoothly
   - [ ] FPS recovers immediately after

4. **Heavy Action** (multiple entities, effects)
   - [ ] FPS stays above 55 with many enemies
   - [ ] Collision detection remains responsive
   - [ ] No stuttering during jumps

5. **Extended Play** (5+ minutes)
   - [ ] No memory leaks (gradual increase)
   - [ ] FPS doesn't degrade over time
   - [ ] Cleanup working properly

---

## 🎓 Optimization Priority Matrix

```
High Impact, Easy Fix          │ High Impact, Hard Fix
• Water tile caching ✅        │ • Spatial hash collision
• Texture preloading ✅        │ • Custom render pipeline
• Pool size reduction ✅       │ • Shader optimizations
• HUD throttling              │ • Multi-threaded physics
                               │
─────────────────────────────┼─────────────────────────
Low Impact, Easy Fix           │ Low Impact, Hard Fix
• Label caching               │ • Advanced particle system
• Action cleanup              │ • Procedural generation
• Font optimization           │ • Level of detail system
• Asset compression           │ • Occlusion culling
```

**Priority**: Start with top-left quadrant (already done!), then top-right if needed.

---

## 🔧 Emergency Performance Fixes

If FPS drops critically during gameplay:

### Quick Disable
```swift
// In GameScene, add emergency mode:
private var emergencyMode = false

func enableEmergencyMode() {
    emergencyMode = true
    weatherNode.isHidden = true        // Disable weather
    leafNode.isHidden = true           // Disable leaves
    // Reduce update frequency
    physicsWorld.speed = 0.9
}
```

### Trigger Emergency Mode
```swift
// In update loop:
if frameCount % 60 == 0 { // Check every second
    if let fps = view?.currentFrameRate, fps < 45 {
        enableEmergencyMode()
    }
}
```

---

## ✅ Daily Monitoring Checklist

Before each commit:
- [ ] Test on iPhone 14 simulator
- [ ] Verify FPS counter shows 58-60
- [ ] Run through weather cycle once
- [ ] Check no console warnings
- [ ] Node count reasonable
- [ ] Memory stable

Before release:
- [ ] Profile with Instruments
- [ ] Test on physical iPhone 14
- [ ] Extended play test (10+ minutes)
- [ ] Memory leak check
- [ ] Performance across all weather types
- [ ] Verify optimizations active

---

**Remember**: Consistent 58-60 FPS is more important than hitting 60 FPS with frequent drops!
