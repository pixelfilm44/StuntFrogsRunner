//
//  DesertBackgroundColors.swift
//  StuntFrogRunner iOS
//
//  Visual reference for desert void gradient colors
//

/*
 
 DESERT VOID GRADIENT - COLOR REFERENCE
 ══════════════════════════════════════════════════════════════════════════════
 
 The desert background uses a 5-stop gradient from dark brown to near-black.
 This creates an ominous "void" atmosphere that matches the instant-death water.
 
 ┌──────────────────────────────────┐
 │  TOP OF SCREEN                   │
 │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │  Stop 1: Dark brown (RGB 40, 30, 20)
 │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │
 │  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  │  Stop 2: Medium-dark brown (RGB 30, 22, 15)
 │  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  │
 │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  Stop 3: Very dark brown (RGB 20, 15, 10)
 │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
 │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │  Stop 4: Near black with tint (RGB 15, 12, 8)
 │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
 │  █████████████████████████████  │  Stop 5: Near black (RGB 10, 8, 5)
 │  BOTTOM OF SCREEN                │
 └──────────────────────────────────┘
 
 COLOR VALUES (iOS UIColor)
 ══════════════════════════════════════════════════════════════════════════════
 
 Stop 1 (Top):        RGB(40/255,  30/255,  20/255) = #28 1E 14
 Stop 2:              RGB(30/255,  22/255,  15/255) = #1E 16 0F
 Stop 3 (Middle):     RGB(20/255,  15/255,  10/255) = #14 0F 0A
 Stop 4:              RGB(15/255,  12/255,   8/255) = #0F 0C 08
 Stop 5 (Bottom):     RGB(10/255,   8/255,   5/255) = #0A 08 05
 
 CONFIGURATION COLORS
 ══════════════════════════════════════════════════════════════════════════════
 
 Configuration.Colors.desertTop    = SKColor(red: 40/255, green: 30/255, blue: 20/255, alpha: 1.0)
 Configuration.Colors.desertBottom = SKColor(red: 10/255, green:  8/255, blue:  5/255, alpha: 1.0)
 
 The intermediate stops (2, 3, 4) are calculated in DesertBackgroundRenderer
 to create a smooth transition between top and bottom.
 
 VISUAL CHARACTERISTICS
 ══════════════════════════════════════════════════════════════════════════════
 
 ✓ Very dark, almost black at the bottom
 ✓ Slight brown tint throughout (maintains desert theme)
 ✓ Smooth gradient prevents banding
 ✓ Creates sense of endless void/abyss
 ✓ Matches the "instant death" water mechanic
 ✓ High contrast makes game elements pop
 ✓ Ominous and threatening atmosphere
 
 COMPARISON TO OLD DESERT
 ══════════════════════════════════════════════════════════════════════════════
 
 OLD: RGB(240, 210, 120) @ 50% alpha → Light tan/sand color, bright, friendly
 NEW: RGB(40, 30, 20) → RGB(10, 8, 5)  → Dark brown to black, ominous, threatening
 
 The new gradient is approximately 20-24x darker than the old flat color.
 
 ADJUSTING THE GRADIENT
 ══════════════════════════════════════════════════════════════════════════════
 
 To make it lighter (less void-like):
 - Increase RGB values in Configuration.Colors.desertTop/Bottom
 - Example: desertTop = RGB(60, 45, 30) for a lighter brown
 
 To make it darker (more void-like):
 - Decrease RGB values
 - Example: desertBottom = RGB(5, 4, 3) for nearly pure black
 
 To change the brown tint:
 - Adjust the ratio between R, G, B values
 - Current ratio: R:G:B ≈ 4:3:2 (brown tint)
 - For more red: R:G:B ≈ 5:3:2 (rust tint)
 - For neutral: R:G:B ≈ 1:1:1 (pure gray/black)
 
 To add more gradient stops:
 - Edit createDesertVoidGradientTexture() in DesertBackgroundRenderer.swift
 - Add more colors to the colors array
 - Add corresponding positions to the locations array
 
 TESTING THE COLORS
 ══════════════════════════════════════════════════════════════════════════════
 
 Quick test to see the gradient colors:
 
 1. Set Configuration.Debug.startingScore = 2400
 2. Run the game
 3. Desert background should appear immediately
 4. If too dark/light, adjust Configuration.Colors.desertTop/Bottom
 5. Rebuild and test again
 
 PERFORMANCE
 ══════════════════════════════════════════════════════════════════════════════
 
 The gradient is created once at initialization and cached as an SKTexture.
 No runtime color calculations - extremely performant.
 
 Memory usage: ~1-2MB for the gradient texture (depends on screen size)
 CPU usage: Nearly zero (only position updates)
 GPU usage: Single sprite draw call
 
 */
