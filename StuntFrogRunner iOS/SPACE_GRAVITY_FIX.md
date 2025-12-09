# Space Gravity Slingshot Accuracy Fix

## Problem

When in space (score 25,000+), the frog experiences reduced gravity (30% of normal), but the slingshot trajectory prediction was using full gravity. This caused the trajectory indicator to show where the frog would land under **normal gravity**, while the frog actually flew much **farther** due to the weaker space gravity.

**Result:** Players were overshooting their intended targets in space because the visual trajectory was inaccurate.

---

## Root Cause

### Physics System
In `GameEntity.swift` line 229, the actual physics correctly applies reduced gravity in space:

```swift
let gravity = weather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ
zVelocity -= gravity
```

### Trajectory Prediction (Bug)
However, in `GameScene.swift` around line 2238, the trajectory simulation was using the hardcoded full gravity:

```swift
simZVel -= Configuration.Physics.gravityZ  // ❌ Always uses full gravity
```

This mismatch meant the trajectory dots showed a shorter arc than the frog actually traveled.

### Animation Timing (Bug)
Similarly, the jump and bounce animation timing calculations didn't account for space gravity, causing animations to desync from actual flight time.

---

## Solution

### 1. Fix Trajectory Prediction (`GameScene.swift`)

**Location:** `updateTrajectoryVisuals()` function, around line 2238

**Before:**
```swift
// Simulate jump physics to position trajectory dots
var simZ: CGFloat = 0
var simZVel: CGFloat = Configuration.Physics.baseJumpZ * (0.5 + (ratio * 0.5))

var landingPoint = simPos
var dotsUsed = 0

// Simulate physics and place dots along the arc
let simulationSteps = isSuperJumping ? 120 : 60
for i in 0..<simulationSteps {
    simPos.x += simVel.dx
    simPos.y += simVel.dy
    simZ += simZVel
    simZVel -= Configuration.Physics.gravityZ  // ❌ Wrong!
    simVel.dx *= Configuration.Physics.frictionAir
    simVel.dy *= Configuration.Physics.frictionAir
```

**After:**
```swift
// Simulate jump physics to position trajectory dots
var simZ: CGFloat = 0
var simZVel: CGFloat = Configuration.Physics.baseJumpZ * (0.5 + (ratio * 0.5))

// Use the same gravity as actual physics - reduced in space!
let gravity = currentWeather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ

var landingPoint = simPos
var dotsUsed = 0

// Simulate physics and place dots along the arc
let simulationSteps = isSuperJumping ? 120 : 60
for i in 0..<simulationSteps {
    simPos.x += simVel.dx
    simPos.y += simVel.dy
    simZ += simZVel
    simZVel -= gravity  // ✅ Correct!
    simVel.dx *= Configuration.Physics.frictionAir
    simVel.dy *= Configuration.Physics.frictionAir
```

---

### 2. Fix Jump Animation Timing (`GameEntity.swift`)

**Location:** `jump()` function, around line 604

**Before:**
```swift
// --- Dynamic Jump Animation ---
// Calculate air time based on physics to sync animations.
// Assumes physics runs at a consistent 60fps as gravity is not scaled by dt.
let timeToPeak = (zVel / Configuration.Physics.gravityZ) / 60.0 // in seconds
```

**After:**
```swift
// --- Dynamic Jump Animation ---
// Calculate air time based on physics to sync animations.
// Assumes physics runs at a consistent 60fps as gravity is not scaled by dt.
// Use the same gravity as actual physics - reduced in space!
let gravity = weather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ
let timeToPeak = (zVel / gravity) / 60.0 // in seconds
```

---

### 3. Fix Bounce Animation Timing (`GameEntity.swift`)

**Location:** `bounce()` function, around line 677

**Before:**
```swift
// --- Dynamic Bounce Animation (same as jump) ---
let timeToPeak = (zVel / Configuration.Physics.gravityZ) / 60.0 // in seconds
```

**After:**
```swift
// --- Dynamic Bounce Animation (same as jump) ---
// Use the same gravity as actual physics - reduced in space!
let gravity = weather == .space ? Configuration.Physics.gravityZ * 0.3 : Configuration.Physics.gravityZ
let timeToPeak = (zVel / gravity) / 60.0 // in seconds
```

---

## Result

✅ **Slingshot trajectory now accurately predicts landing position in space**
- Trajectory dots account for 30% gravity (70% reduction)
- Crosshair landing indicator shows correct target
- Players can now aim accurately

✅ **Animation timing matches actual flight time**
- Jump animations properly sync with longer space flight times
- Bounce animations are correctly timed for space physics
- Visual feedback is consistent with gameplay

---

## Testing

### Test Case 1: Space Trajectory Accuracy
1. Enter space weather (score 25,000+)
2. Aim slingshot at a lily pad
3. **Expected:** Trajectory dots show accurate arc, frog lands where crosshair indicates
4. **Actual:** ✅ Trajectory is accurate

### Test Case 2: Normal Gravity Still Works
1. Play in any non-space weather (sunny, night, rain, winter, desert)
2. Aim slingshot at a lily pad
3. **Expected:** Trajectory remains accurate (unchanged behavior)
4. **Actual:** ✅ No regression

### Test Case 3: Animation Timing in Space
1. Jump in space weather
2. **Expected:** Jump animation completes as frog lands (not before)
3. **Actual:** ✅ Animation syncs with physics

---

## Technical Details

### Gravity Values
- **Normal gravity:** `0.8` (Configuration.Physics.gravityZ)
- **Space gravity:** `0.24` (0.8 × 0.3)
- **Reduction:** 70% weaker gravity in space

### Space Gravity Locations
The space gravity multiplier (`0.3`) is now consistently applied in:
1. ✅ Actual physics (`GameEntity.update()`)
2. ✅ Trajectory prediction (`GameScene.updateTrajectoryVisuals()`)
3. ✅ Jump animation timing (`GameEntity.jump()`)
4. ✅ Bounce animation timing (`GameEntity.bounce()`)

### Future Improvements
If you want to make this more maintainable, consider adding a helper to `Configuration.Physics`:

```swift
static func effectiveGravity(for weather: WeatherType) -> CGFloat {
    return weather == .space ? gravityZ * 0.3 : gravityZ
}
```

Then all four locations could use:
```swift
let gravity = Configuration.Physics.effectiveGravity(for: weather)
```

This centralizes the space gravity logic to one place.

---

## Files Modified

1. **GameScene.swift** - Fixed trajectory prediction in `updateTrajectoryVisuals()`
2. **GameEntity.swift** - Fixed animation timing in `jump()` and `bounce()`

---

## Related Documentation

- See `SPACE_FLOW_DIAGRAM.md` for space transition mechanics
- See `SPACE_TRANSITION_IMPLEMENTATION.md` for space weather implementation
- See `GameEntity.swift` line 229 for the original physics gravity reduction
