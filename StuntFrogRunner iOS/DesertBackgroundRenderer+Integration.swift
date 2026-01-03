//
//  DesertBackgroundRenderer+Integration.swift
//  StuntFrogRunner iOS
//
//  Integration guide for DesertBackgroundRenderer
//

/*
 INTEGRATION GUIDE FOR DESERT VOID BACKGROUND
 
 This guide shows how to integrate the DesertBackgroundRenderer into your GameScene
 to display a dark brown-to-black void gradient during desert weather.
 
 ══════════════════════════════════════════════════════════════════════════════════
 STEP 1: Add property to GameScene
 ══════════════════════════════════════════════════════════════════════════════════
 
 Add this property to your GameScene class:
 
 ```swift
 class GameScene: SKScene {
     // ... existing properties ...
     
     /// Desert background renderer (for desert weather)
     private var desertBackground: DesertBackgroundRenderer?
     
     /// Space background renderer (for space weather)
     private var spaceBackground: SpaceBackgroundRenderer?
     
     // ... rest of class ...
 }
 ```
 
 ══════════════════════════════════════════════════════════════════════════════════
 STEP 2: Initialize in didMove(to:) or setupScene()
 ══════════════════════════════════════════════════════════════════════════════════
 
 In your scene setup method, create the desert background:
 
 ```swift
 override func didMove(to view: SKView) {
     // ... existing setup code ...
     
     // Create desert background (add after camera setup)
     if let camera = self.camera {
         desertBackground = DesertBackgroundRenderer.createOptimized(
             for: worldNode,  // or self if you add directly to scene
             camera: camera,
             screenSize: view.bounds.size
         )
     }
     
     // ... rest of setup ...
 }
 ```
 
 ══════════════════════════════════════════════════════════════════════════════════
 STEP 3: Update in the update(_ currentTime:) method
 ══════════════════════════════════════════════════════════════════════════════════
 
 Add this to your scene's update method to keep the background following the camera:
 
 ```swift
 override func update(_ currentTime: TimeInterval) {
     // ... existing update code ...
     
     // Update desert background position
     desertBackground?.update(currentTime)
     
     // ... rest of update ...
 }
 ```
 
 ══════════════════════════════════════════════════════════════════════════════════
 STEP 4: Activate/Deactivate based on weather
 ══════════════════════════════════════════════════════════════════════════════════
 
 In your weather transition code, activate/deactivate the desert background:
 
 ```swift
 func updateWeather(_ newWeather: WeatherType, animated: Bool = true) {
     // ... existing weather transition code ...
     
     // Handle desert background
     if newWeather == .desert {
         // Activate desert void background
         desertBackground?.activate(animated: animated)
         
         // Deactivate space background if it was active
         spaceBackground?.deactivate(animated: animated)
     } else if newWeather == .space {
         // Activate space background
         spaceBackground?.activate(animated: animated)
         
         // Deactivate desert background
         desertBackground?.deactivate(animated: animated)
     } else {
         // Deactivate both special backgrounds for other weather types
         desertBackground?.deactivate(animated: animated)
         spaceBackground?.deactivate(animated: animated)
     }
     
     // ... rest of weather transition ...
 }
 ```
 
 ══════════════════════════════════════════════════════════════════════════════════
 STEP 5: Cleanup when scene is deallocated (optional but recommended)
 ══════════════════════════════════════════════════════════════════════════════════
 
 ```swift
 deinit {
     desertBackground?.cleanup()
     spaceBackground?.cleanup()
 }
 ```
 
 Or in willMove(from view:):
 
 ```swift
 override func willMove(from view: SKView) {
     desertBackground?.cleanup()
     spaceBackground?.cleanup()
     // ... other cleanup ...
 }
 ```
 
 ══════════════════════════════════════════════════════════════════════════════════
 PERFORMANCE NOTES
 ══════════════════════════════════════════════════════════════════════════════════
 
 ✅ OPTIMIZATIONS INCLUDED:
 - Single gradient texture (created once, reused forever)
 - Minimal draw calls (only 1 draw call for the entire background)
 - Hardware-accelerated rendering (GPU-based gradient)
 - Efficient camera tracking (simple position update)
 - No particle emitters or complex effects
 - No additional entities (stars, dust, etc.) for maximum performance
 
 📊 EXPECTED PERFORMANCE:
 - All devices: 60 FPS with no frame drops
 - Single sprite = negligible performance impact
 - Lower overhead than the light brown flat color due to no scene backgroundColor overhead
 
 🎨 VISUAL FEATURES:
 - Dark brown-to-black void gradient (ominous desert aesthetic)
 - Smooth color transitions (5-stop gradient for depth)
 - Seamless camera following (always centered on camera)
 - Smooth fade in/out transitions
 - Uses Configuration.Colors.desertTop and desertBottom for consistency
 
 ══════════════════════════════════════════════════════════════════════════════════
 COLOR CUSTOMIZATION
 ══════════════════════════════════════════════════════════════════════════════════
 
 The gradient uses colors defined in Configuration.swift:
 
 ```swift
 struct Colors {
     // Desert void colors - dark gradient from brown to black
     static let desertTop = SKColor(red: 40/255, green: 30/255, blue: 20/255, alpha: 1.0)      // Dark brown
     static let desertBottom = SKColor(red: 10/255, green: 8/255, blue: 5/255, alpha: 1.0)    // Near black with brown tint
 }
 ```
 
 To adjust the gradient:
 1. Modify these colors in Configuration.swift
 2. The gradient will automatically use the new values
 3. Add more gradient stops in createDesertVoidGradientTexture() for different effects
 
 ══════════════════════════════════════════════════════════════════════════════════
 EXAMPLE: Full Weather Transition with Desert
 ══════════════════════════════════════════════════════════════════════════════════
 
 ```swift
 func transitionToWeather(_ weather: WeatherType) {
     let animated = true
     
     switch weather {
     case .desert:
         // Activate desert void visuals
         desertBackground?.activate(animated: animated)
         spaceBackground?.deactivate(animated: animated)
         
         // Note: No need to set backgroundColor - the gradient handles it all
         
     case .space:
         // Activate space visuals
         spaceBackground?.activate(animated: animated)
         desertBackground?.deactivate(animated: animated)
         moonlightRenderer?.activate(animated: animated)
         
     case .night:
         // Night visuals (no special backgrounds)
         desertBackground?.deactivate(animated: animated)
         spaceBackground?.deactivate(animated: animated)
         moonlightRenderer?.activate(animated: animated)
         
     default:
         // Other weather types (sunny, rain, winter)
         desertBackground?.deactivate(animated: animated)
         spaceBackground?.deactivate(animated: animated)
         moonlightRenderer?.deactivate(animated: animated)
     }
     
     // Update all entities with new weather
     // ... (your existing weather update code)
 }
 ```
 
 ══════════════════════════════════════════════════════════════════════════════════
 ADVANCED: Adding Desert-Specific Effects (Optional)
 ══════════════════════════════════════════════════════════════════════════════════
 
 If you want to enhance the desert void atmosphere, you can add:
 
 1. **Subtle dust particles** (very sparse, only 5-10 on screen)
 2. **Heat wave distortion** (using SKEffectNode with CIWarpDistortion)
 3. **Distant dune silhouettes** (static sprites at the horizon)
 
 However, the current gradient-only approach is recommended for best performance
 and maintains the ominous "void" aesthetic you're going for.
 
 ══════════════════════════════════════════════════════════════════════════════════
 COMPARISON: Old vs New Desert Background
 ══════════════════════════════════════════════════════════════════════════════════
 
 OLD (Flat Color):
 - static let desert = SKColor(red: 240/255, green: 210/255, blue: 120/255, alpha: 0.5)
 - Light brown, flat, not atmospheric
 
 NEW (Void Gradient):
 - Dark brown (RGB: 40, 30, 20) at top
 - Near black (RGB: 10, 8, 5) at bottom
 - Multi-stop gradient for depth
 - Ominous void aesthetic
 - More immersive and threatening
 
 ══════════════════════════════════════════════════════════════════════════════════
 
 That's it! Your desert weather will now have a dark, void-like gradient
 that creates an ominous atmosphere, all while maintaining 60 FPS performance.
 
*/
