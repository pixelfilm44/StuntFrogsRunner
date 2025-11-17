# WorldManager Integration Guide

## Overview
The `WorldManager` has been updated to handle star fields and fireflies as part of the water background during night weather. These elements now move with the world coordinates, providing a more immersive experience.

## Key Changes Made

### 1. Removed Dependencies
- ❌ Removed `nightOverlayNode` references 
- ❌ Removed `isNightOverlayActive` checks
- ✅ Now directly manages night effects within world coordinates

### 2. New Star Field Integration
```swift
// Star field is automatically created for night weather
func setupWorld(sceneSize: CGSize, weather: WeatherType = .day) -> SKNode {
    worldNode = SKNode()
    createWaterBackground(sceneSize: sceneSize, weather: weather)
    
    // Night effects are automatically added
    if weather == .night {
        createStarField(for: weather)
    }
    
    return worldNode
}
```

### 3. Firefly Management in World Space
- Fireflies are now created at fixed world positions
- They move with the background during scrolling
- Automatic memory management with distance-based cleanup

## Integration with GameScene

### Basic Setup
```swift
class GameScene: SKScene {
    var worldManager: WorldManager!
    var currentWeather: WeatherType = .day
    
    override func didMove(to view: SKView) {
        worldManager = WorldManager(scene: self)
        let worldNode = worldManager.setupWorld(sceneSize: size, weather: currentWeather)
        addChild(worldNode)
    }
}
```

### Weather Change Handling
```swift
func changeWeather(to newWeather: WeatherType) {
    currentWeather = newWeather
    
    // Update world for new weather (handles stars/fireflies automatically)
    worldManager.updateWorldForWeather(newWeather)
    
    // Update other weather effects through EffectsManager
    effectsManager.updateWeatherEffects(newWeather)
}
```

### Firefly Updates During Gameplay
```swift
func update(_ currentTime: TimeInterval) {
    // Update fireflies as frog moves during night weather
    if currentWeather == .night {
        // Convert frog screen position to world position
        let frogWorldPosition = convert(frog.position, to: worldManager.worldNode)
        worldManager.updateFirefliesForPosition(frogWorldPosition)
    }
}
```

## New Public Methods

### Weather-Based World Updates
```swift
// Update world for weather change without full recreation
worldManager.updateWorldForWeather(.night)

// Update just water textures
worldManager.updateWaterTextureForWeather(.winter)
```

### Firefly Management
```swift
// Manual firefly generation (usually automatic)
worldManager.generateFirefliesInWorldArea(
    centerWorldPosition: CGPoint(x: 0, y: 200), 
    areaRadius: 300
)

// Cleanup distant fireflies for memory management
worldManager.cleanupDistantFireflies(
    from: frogPosition, 
    maxDistance: 600
)

// Remove all fireflies (weather change cleanup)
worldManager.removeAllFireflies()
```

### Star Management
```swift
// Remove all stars (weather change cleanup)
worldManager.removeAllStars()
```

## Coordinate System Notes

### World vs Scene Coordinates
- **Stars & Fireflies**: Positioned in world coordinates, move with background
- **Game Objects**: Usually in scene coordinates
- **Conversions**: Use `convert(_:to:)` between coordinate systems

```swift
// Convert frog position from scene to world coordinates
let frogWorldPos = convert(frog.position, to: worldManager.worldNode)

// Convert world position to scene coordinates  
let scenePos = convert(worldPos, from: worldManager.worldNode)
```

## Performance Considerations

### Automatic Memory Management
- Fireflies beyond 600 units are automatically removed
- Stars are created once per weather change, not continuously
- Water tile recycling continues to work normally

### Optimization Tips
```swift
// Call firefly updates sparingly, not every frame
var lastFireflyUpdate: TimeInterval = 0
func update(_ currentTime: TimeInterval) {
    if currentWeather == .night && currentTime - lastFireflyUpdate > 1.0 {
        lastFireflyUpdate = currentTime
        worldManager.updateFirefliesForPosition(frogWorldPosition)
    }
}
```

## Integration with Existing Weather System

### Weather Manager Integration
```swift
// In your weather change handler
func handleWeatherChange(to newWeather: WeatherType) {
    // Update world manager for new weather
    worldManager.updateWorldForWeather(newWeather)
    
    // Continue with existing weather effects
    effectsManager.transitionToWeather(newWeather)
    soundController.updateAmbienceForWeather(newWeather)
}
```

### Effects Manager Coordination
- WorldManager handles: Water textures, stars, fireflies
- EffectsManager handles: Night overlay, particle effects, lighting
- Both systems work together for complete night experience

## Debugging & Testing

### Visual Debugging
```swift
// Check what's in the world
worldManager.worldNode.enumerateChildNodes(withName: "firefly") { node, _ in
    print("Firefly at: \(node.position)")
}

worldManager.worldNode.enumerateChildNodes(withName: "star") { node, _ in
    print("Star at: \(node.position)")
}
```

### Test Night Effects
```swift
// Force night weather for testing
worldManager.updateWorldForWeather(.night)

// Generate test fireflies around specific area
worldManager.generateFirefliesInWorldArea(
    centerWorldPosition: CGPoint.zero, 
    areaRadius: 200
)
```

## Common Issues & Solutions

### Issue: Stars/Fireflies Not Visible
```swift
// Check z-positions
// Stars: z-position 1 (above water, below lily pads)  
// Fireflies: z-position 15 (above lily pads, below UI)

// Ensure world node is added to scene
addChild(worldManager.worldNode)
```

### Issue: Fireflies Not Moving with Background
- Fireflies are placed in world coordinates automatically
- Make sure you're using `worldManager.worldNode` as parent

### Issue: Memory Issues with Many Fireflies
- Automatic cleanup happens at 600 unit distance
- Reduce firefly generation frequency if needed
- Check firefly count: `worldManager.worldNode.childNode(withName: "firefly")`

## Migration from EffectsManager

If you were previously using EffectsManager for stars/fireflies:

### Before
```swift
effectsManager.startNightOverlay()  // Created stars & fireflies
```

### After
```swift
worldManager.updateWorldForWeather(.night)  // Creates stars & fireflies
effectsManager.startNightOverlay()  // Just handles overlay & lighting
```

## Best Practices

1. **Weather Changes**: Always use `updateWorldForWeather()` for complete updates
2. **Performance**: Update fireflies every 1-2 seconds, not every frame  
3. **Coordinates**: Remember that stars/fireflies use world coordinates
4. **Memory**: Let automatic cleanup handle distant fireflies
5. **Integration**: Coordinate with EffectsManager for complete night experience

## Summary

The updated WorldManager provides:
- ✅ Seamless integration of night effects with water background
- ✅ Automatic stars and firefly creation for night weather
- ✅ Memory-efficient firefly management  
- ✅ Proper world coordinate positioning
- ✅ Easy integration with existing weather systems
- ✅ Performance-optimized updates

Stars and fireflies now move naturally with the scrolling water background, creating a more immersive night pond environment.