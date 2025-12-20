# Shore Transparency Guide

## Overview

The shore PNG files must have **transparency (alpha channel)** to allow the water gradient to show through underneath. This creates a realistic layered effect where the water is visible beneath the shore elements.

## Layer Stack (Bottom to Top)

```
┌─────────────────────────────────────┐
│  5. Game Elements (pads, frog)      │  ← z = Layer.pad (0)
├─────────────────────────────────────┤
│  4. Shore PNGs (with transparency)  │  ← z = -100 + 0.1
├─────────────────────────────────────┤
│  3. Water Gradient Background       │  ← z = -100
├─────────────────────────────────────┤
│  2. Scene Background                │  ← backgroundColor = .clear
└─────────────────────────────────────┘
```

## Shore PNG Transparency Structure

### Recommended Opacity Levels

```
Left Shore (shoreLeft.png):

┌────────────────────────────────┐
│ Trees/Grass    │               │
│ (100% opaque)  │   Water Edge  │
│                │   (0% opaque) │
│ ████████████   │               │
│ ████████████   │  ░░░░░░░░░░░  │
│ ████████████   │  ░░░░░░░░░░░  │  
│                │               │
│ Dirt/Ground    │  Transparency │
│ (80% opaque)   │  Gradient     │
│ ▓▓▓▓▓▓▓▓▓▓▓    │  ░░░░░░░░░░░  │
│ ▓▓▓▓▓▓▓▓▓▓▓    │  ░░░░░░░░░░░  │
└────────────────────────────────┘
  ← Outer edge      River edge →
     Decorative        Seamless
```

### Color and Opacity Zones

1. **Outer Decorative Edge** (Left side for shoreLeft.png)
   - Trees, grass, rocks: **100% opaque**
   - These should be solid and clearly visible
   
2. **Middle Ground** (Center area)
   - Dirt, sand, earth: **60-80% opaque**
   - Allows some water to show through for depth
   
3. **Water's Edge** (Right side for shoreLeft.png)
   - Transition zone: **20-40% opaque**
   - Gradual fade to let water dominate
   
4. **Seamless Edge** (Rightmost pixels)
   - Pure transparency: **0% opaque**
   - Blends seamlessly with water

## Creating the Transparency Effect

### Method 1: Layer Masks in Photoshop/Procreate

1. Create your shore artwork on a transparent canvas
2. Add a **layer mask** to the shore layer
3. Use a **gradient tool** on the mask:
   - Black (transparent) on the river edge
   - White (opaque) on the outer edge
   - This creates a smooth transparency gradient

### Method 2: Opacity Painting

1. Draw your shore elements (grass, rocks, dirt)
2. Use a **soft eraser** at varying opacities:
   - Outer edge: Don't erase (100% opaque)
   - Middle: Erase lightly (80% opaque)
   - Water edge: Erase heavily (20% opaque)
   - River edge: Erase completely (0% opaque)

### Method 3: Alpha Channel Editing

1. Create your shore artwork
2. Edit the **alpha channel** directly
3. Paint black-to-white gradient:
   - Black = transparent
   - White = opaque
   - Gray = semi-transparent

## Photoshop Recipe for shoreLeft.png

```
1. New Document: 300px W × 600px H, transparent background
2. Layer 1 - Base Ground:
   - Fill with brown (#8B5A2B)
   - Opacity: 70%
   - Add dirt texture overlay

3. Layer 2 - Grass Clumps (Left edge):
   - Paint grass tufts in green (#4A7C3E)
   - Keep at 100% opacity
   - Position at x: 0-80

4. Layer 3 - Rocks/Details:
   - Add small rocks, pebbles
   - Keep at 100% opacity
   - Scatter randomly

5. Layer Mask - Transparency Gradient:
   - Select all layers (except background)
   - Add layer mask
   - Gradient tool: Black-to-White
   - Direction: Right (river edge) to Left (outer edge)
   - This creates the transparency fade

6. Edge Refinement:
   - Right edge (river): Should be 100% transparent
   - Use soft brush at low opacity to blend

7. Test Tiling:
   - Duplicate and stack vertically
   - Ensure seamless top/bottom connection

8. Export:
   - File → Export → Export As
   - Format: PNG
   - Check "Transparency" option
   - Save as shoreLeft.png (@2x, @3x variants)
```

## Testing Transparency

### In Photoshop/Design Software
1. Add a **blue rectangle** layer beneath your shore
2. The blue should show through the transparent areas
3. Adjust opacity until water is visible but shore is prominent

### In Xcode
1. Import your PNG
2. View in asset catalog - checkerboard should show through transparent areas
3. Run on iPad - water gradient should be visible beneath shore

## Common Mistakes

### ❌ Shore is 100% Opaque
**Problem**: Water completely hidden, looks like a solid wall
**Solution**: Add transparency gradient from river edge inward

### ❌ Shore is Too Transparent
**Problem**: Shore barely visible, looks like floating grass
**Solution**: Increase opacity of decorative elements (grass, rocks)

### ❌ Hard Edge Instead of Gradient
**Problem**: Sharp line between opaque and transparent areas
**Solution**: Use soft brush/gradient for smooth transition

### ❌ Inconsistent Alpha Channel
**Problem**: Random transparent spots, patchy appearance
**Solution**: Review alpha channel, ensure smooth gradient

## Visual Example

```
Cross-section view of left shore:

Outer                                River
Edge                                 Edge
←                                       →

████████  Opaque trees/grass (100%)
████████
▓▓▓▓▓▓▓▓  Semi-opaque ground (70%)
▓▓▓▓▓▓▓▓
░░░░░░░░  Transparent edge (30%)
░░░░░░░░
········  Fully transparent (0%)
········

Water shows through here ↑
```

## Advanced: Dynamic Opacity Based on Weather

You can create weather-specific versions with different opacity levels:

- **Sunny**: 70% base opacity (clear, visible)
- **Rain**: 85% base opacity (wet, darker)
- **Night**: 60% base opacity (mysterious, ethereal)
- **Winter**: 50% base opacity (icy, translucent)

## Verification Checklist

Before exporting your shore PNGs:

- [ ] Transparent areas have alpha channel properly set
- [ ] Outer decorative elements are 100% opaque
- [ ] Middle ground is 60-80% opaque
- [ ] River edge fades to 0% opacity
- [ ] Top and bottom edges tile seamlessly
- [ ] File format is PNG (not JPG)
- [ ] Transparency checkbox is enabled in export settings
- [ ] Blue test layer shows through transparent areas
- [ ] @2x and @3x variants created

## Final Export Settings

### Photoshop
- Format: PNG-24 (not PNG-8)
- Transparency: ✓ Enabled
- Interlaced: ✗ Disabled
- Convert to sRGB: ✓ Enabled

### Procreate
- Share → PNG
- Ensure transparent background (not white)

### GIMP
- Export as PNG
- Compression level: 9
- Save background color: ✗ Unchecked
- Save color values from transparent pixels: ✓ Checked

## Result

When properly implemented, you should see:
- Solid, visible shore decorations (grass, rocks, trees)
- Water gradient visible beneath the shore
- Smooth transition from shore to water
- Realistic depth and layering effect
- No hard edges or visible seams
