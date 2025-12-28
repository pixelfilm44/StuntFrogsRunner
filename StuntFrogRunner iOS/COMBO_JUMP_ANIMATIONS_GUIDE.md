# Combo Jump Animations Guide

## Overview
The frog now displays progressively wilder jump animations as your combo increases! This feature maintains strong performance by preloading all textures and using efficient texture selection.

## How It Works

### Combo Tiers
The animation system uses 4 distinct animation tiers based on your combo count:

1. **Base Jump (Combo 0-2)** - Standard jump animation
   - Uses existing `frogJump1` through `frogJump6` images
   - Scale multiplier: 1.5x

2. **Cool Jump (Combo 3-5)** - Slightly more dynamic
   - Images: `frogJumpCool1` through `frogJumpCool6`
   - Fallback: Uses base animation if images not found
   - Scale multiplier: 1.7x

3. **Wild Jump (Combo 6-9)** - More energetic animations
   - Images: `frogJumpWild1` through `frogJumpWild6`
   - Fallback: Uses cool animation if images not found
   - Scale multiplier: 2.0x

4. **Extreme Jump (Combo 10+)** - Wildest animations!
   - Images: `frogJumpExtreme1` through `frogJumpExtreme6`
   - Fallback: Uses wild animation if images not found
   - Scale multiplier: 2.3x

### Life Vest Variants
Each tier also has life vest (Lv) variants that display when the frog has a vest buff:
- `frogJumpCoolLv1-6`
- `frogJumpWildLv1-6`
- `frogJumpExtremeLv1-6`

## Adding Custom Animations

### Image Naming Convention
To add your custom jump animations, create image assets with these exact names:

**Without Life Vest:**
- `frogJumpCool1.png` to `frogJumpCool6.png`
- `frogJumpWild1.png` to `frogJumpWild6.png`
- `frogJumpExtreme1.png` to `frogJumpExtreme6.png`

**With Life Vest:**
- `frogJumpCoolLv1.png` to `frogJumpCoolLv6.png`
- `frogJumpWildLv1.png` to `frogJumpWildLv6.png`
- `frogJumpExtremeLv1.png` to `frogJumpExtremeLv6.png`

### Image Requirements
- **Format:** PNG with transparency
- **Frames:** Exactly 6 frames per animation set
- **Progression:** Frame 1 = takeoff, Frame 3-4 = peak, Frame 6 = landing
- **Size:** Match existing frog sprite dimensions for consistency
- **Style:** Each tier should be visibly more dynamic than the previous

### Graceful Degradation
The system automatically falls back to simpler animations if images are missing:
- Missing Extreme → Uses Wild
- Missing Wild → Uses Cool
- Missing Cool → Uses Base
- Missing Base → Will display blank (shouldn't happen with existing assets)

This ensures the game never crashes from missing animation assets!

## Performance Considerations

### Preloading
All textures are preloaded as static properties in the `Frog` class during app initialization. This means:
- ✅ Zero loading time during gameplay
- ✅ No frame drops when switching animations
- ✅ Minimal memory overhead (only loaded once)

### Texture Selection
The `selectJumpAnimationTextures(comboCount:)` method efficiently selects the appropriate texture set using a simple switch statement. This is:
- ✅ O(1) constant time operation
- ✅ No dynamic texture loading
- ✅ No performance impact regardless of combo level

### Memory Impact
Each animation set adds ~6 textures to memory:
- Base: Already exists (no additional memory)
- Cool: +6 textures (~200KB per set)
- Wild: +6 textures (~200KB per set)
- Extreme: +6 textures (~200KB per set)
- Life Vest variants: +18 textures (~600KB total)

Total additional memory: **~1.2MB** (negligible on modern devices)

## Implementation Details

### Code Changes

**GameEntity.swift:**
- Added 4 texture set arrays (cool, wild, extreme + life vest variants)
- Added `selectJumpAnimationTextures(comboCount:)` helper method
- Modified `jump()` to accept `comboCount` parameter and select appropriate textures
- Modified `bounce()` to accept `comboCount` parameter for consistency
- Increased scale multipliers for higher combo tiers (1.5x → 2.3x)

**GameScene.swift:**
- Updated `frog.jump()` call to pass current `comboCount`
- Updated `frog.bounce()` call to pass current `comboCount`

### Where Combo is Tracked
The `comboCount` variable in `GameScene.swift` is updated in the `didLand(on:)` method:
- Increments on successful landing within combo timeout (1.5 seconds)
- Resets to 0 on combo break or when taking damage
- Displayed to player via `showComboPopup(at:count:)`

## Testing Tips

1. **Test with base animations first** - Verify existing animations still work
2. **Test fallback behavior** - Remove higher-tier images to verify fallback works
3. **Test performance** - Run on lower-end devices to ensure smooth 60fps
4. **Test life vest** - Verify both vest and non-vest variants display correctly
5. **Test combo progression** - Play through and watch animations evolve naturally

## Design Recommendations

### Animation Progression Ideas

**Cool (3-5 combos):**
- Add slight rotation/spin
- More exaggerated leg kick
- Small sparkle effects on frog

**Wild (6-9 combos):**
- Full rotation/flip
- Stretched limbs for dynamic pose
- Trailing motion blur effect

**Extreme (10+ combos):**
- Multiple rotations
- Crazy poses (splits, superman, etc.)
- Particle effects, stars, or energy trails
- Consider slight squash-and-stretch distortion

### Animation Timing
Each animation plays for the duration of the jump's air time, which varies by:
- Jump intensity (how far you pull)
- Super jump buff (faster, higher)
- Weather (space has reduced gravity = longer air time)

Make sure your 6 frames work well across different timing durations!

## Future Enhancements

Possible additions without impacting performance:
- Sound effect variations per combo tier
- Particle effects that scale with combo
- Screen shake intensity based on combo
- Camera zoom adjustments for extreme combos
- Combo-specific landing effects

---

**Questions or Issues?**
Check the implementation in:
- `GameEntity.swift` lines ~115-200 (texture definitions)
- `GameEntity.swift` lines ~719-800 (jump method)
- `GameScene.swift` line ~6801 (jump call)
