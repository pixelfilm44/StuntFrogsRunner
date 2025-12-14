# Swatter Attack Implementation Guide

## Overview
The swatter attack system allows the frog to swat dragonflies with a performant, visually appealing animation. When the frog has a swatter buff and encounters a dragonfly, it automatically swats it, causing the dragonfly to fly backward in a spiral and disappear.

## Files Created/Modified

### New File: `SwatterAttackAnimation.swift`
A complete animation system following the same pattern as `HoneyAttackAnimation.swift` and `AxeAttackAnimation.swift`.

**Key Features:**
- Object pooling for swatter projectiles (5 in pool)
- 5-frame animation system running at ~60fps
- Quick swat motion (0.06s per frame)
- Visual effects: motion lines, star burst, speed lines, particles
- Dragonfly flies backward with wobble and spin

**Animation Sequence:**
1. **Frame 1**: Frog wind-up (quick recoil back)
2. **Frame 2**: Frog swat motion (forward lunge with downward swat)
3. **Frame 3**: Launch swatter projectile with arc and spin
4. **Frame 4**: Dragonfly hit reaction (shake, pulse, white flash)
5. **Frame 5**: Dragonfly flies away backward (spiral, wobble, fade)

### Modified File: `CollisionManagerDelegate.swift`

#### Protocol Addition
```swift
protocol CollisionManagerDelegate: AnyObject {
    // ... existing methods ...
    func didDestroyDragonflyWithSwatter(_ dragonfly: Enemy)
}
```

#### Collision Detection Logic
Added in `checkEntityCollisions()` method, right after honey attack logic:

```swift
// Check swatter attack on dragonflies (before invincibility check so swatter always works)
if frog.buffs.swatter > 0 {
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
            dragonflyToDestroy = enemy
            break // Only attack one dragonfly per frame
        }
    }
    
    // Execute swatter attack outside the loop to avoid concurrent modification
    if let dragonfly = dragonflyToDestroy {
        // Mark as being destroyed IMMEDIATELY
        dragonfly.isBeingDestroyed = true
        
        // Trigger swatter attack animation
        frog.swatDragonfly(dragonfly) {
            // Dragonfly will be removed after animation completes
            dragonfly.removeFromParent()
        }
        // Mark dragonfly for removal (delegate should handle array cleanup)
        delegate?.didDestroyDragonflyWithSwatter(dragonfly)
    }
}
```

## Usage

### Initialization
Initialize the swatter pool at app startup (similar to honey/axe):

```swift
// In GameScene or wherever you initialize animations
SwatterAttackAnimation.initializePool()
```

### Giving the Frog a Swatter
```swift
frog.buffs.swatter += 1  // Give frog one swatter
frog.buffs.swatter += 4  // Give frog 4 swatters (treasure chest reward)
```

### Automatic Attack
When the frog has `buffs.swatter > 0` and a dragonfly comes within range (~80 pixels), the swatter attack triggers automatically. The system:
1. Decrements `frog.buffs.swatter` by 1
2. Plays the swat animation
3. Dragonfly flies away backward
4. Calls `didDestroyDragonflyWithSwatter()` delegate method

### Manual Attack (Optional)
You can also manually trigger a swat:

```swift
frog.swatDragonfly(dragonfly) {
    print("Dragonfly swatted!")
}
```

## Delegate Implementation

In your `GameScene` or controller that implements `CollisionManagerDelegate`:

```swift
func didDestroyDragonflyWithSwatter(_ dragonfly: Enemy) {
    // Remove dragonfly from tracking array
    enemies.removeAll { $0 === dragonfly }
    
    // Optional: Play sound effect (already done in animation)
    // Optional: Award points
    // Optional: Update UI showing swatter count
}
```

## Visual Effects

The swatter attack includes several visual effects:
- **Motion lines**: 6 radiating lines showing impact
- **Star burst**: Central yellow/white star with expansion
- **Speed lines**: 4 horizontal whoosh lines
- **Particles**: 10 yellow particles bursting outward
- **Dragonfly motion**: Backward arc with wobble, spin, shrink, and fade

## Performance Notes

- Uses object pooling (5 swatters in pool)
- All animations use pre-calculated timing
- Minimal overhead: ~1 dragonfly attack per frame maximum
- Compatible with 60fps gameplay
- No memory leaks (projectiles returned to pool)

## Attack Range

- **Range**: ~80 pixels (60 + frogRadius)
- **Z-Height tolerance**: 40 pixels vertical difference
- **Priority**: Only one dragonfly per frame
- **Auto-trigger**: Activates when dragonfly enters range

## Comparison to Other Attacks

| Attack | Target | Range | Speed | Effect |
|--------|--------|-------|-------|--------|
| Honey | Bees | ~80px | 0.3s flight | Fade/rotate/float up |
| Axe | Snakes/Cacti/Logs | ~80px | 0.25s flight | Slice/chop/break apart |
| Swatter | Dragonflies | ~80px | 0.15s flight | Fly backward/spiral |
| Cross | Ghosts | ~100px | 0.3s flight | Holy light/dissolve |

## Integration Checklist

- [x] Create `SwatterAttackAnimation.swift`
- [x] Add delegate method `didDestroyDragonflyWithSwatter()`
- [x] Add collision detection logic in `CollisionManager`
- [x] Add `Frog.swatDragonfly()` extension method
- [ ] Initialize pool in GameScene: `SwatterAttackAnimation.initializePool()`
- [ ] Implement delegate method in GameScene
- [ ] Add swatter pickup/reward logic
- [ ] Update UI to show swatter count
- [ ] Test with dragonflies in different weather conditions

## Required Assets

Make sure these assets exist in your asset catalog:
- `swatter.png` - The fly swatter image (40x40 recommended)
- Dragonfly images already exist:
  - `dragonfly.png` (sunny)
  - `dragonflyNight.png`
  - `dragonflyRain.png`
  - `dragonflyWinter.png`
  - `dragonflyDesert.png`
  - `asteroid.png` (space weather)

## Testing

1. Give frog a swatter: `frog.buffs.swatter = 1`
2. Spawn a dragonfly nearby
3. Jump toward the dragonfly
4. Watch for automatic swat animation
5. Verify dragonfly flies backward and disappears
6. Check swatter count decremented: `frog.buffs.swatter == 0`

## Notes

- Swatter attack triggers **before** invincibility check (like honey and axe)
- Only one dragonfly can be swatted per frame
- Dragonflies must have `type == "DRAGONFLY"` to be swattable
- Already-destroyed dragonflies (`isBeingDestroyed == true`) are skipped
- Animation includes sound effect (`SoundManager.shared.play("hit")`)
