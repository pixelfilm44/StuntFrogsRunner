# Snake Animation Implementation

## Overview
This implementation adds view-based animation for snakes in the game. Snakes will only start their animation when they come into the visible frame, which can help with performance and create a more dynamic visual experience.

## Key Features

### 1. Lazy Animation Loading
- Snakes are created without starting their animation immediately
- Animation only begins when the snake enters the visible screen area
- Uses a `hasBeenVisible` flag to optimize performance and prevent re-checking

### 2. Automatic Visibility Detection
- The system automatically checks snake visibility during the game loop
- Visibility is checked in two places:
  - `SpawnManager.spawnObjects()` - Every 10 frames for new spawns
  - `GameLoopCoordinator.updateEnemies()` - Every frame for all snakes

### 3. Performance Optimizations
- **One-time check**: Once a snake has been visible and starts animating, it won't be checked again
- **Batch processing**: All snakes are checked in a single loop iteration
- **Margin buffer**: Uses 100px margins above/below screen for smooth transitions

### 4. Manual Control
- `forceStartAnimation()` method for testing or special cases
- `isSnakeAnimated` property to check animation state
- `stopAnimation()` method properly resets state when enemies are removed

## Implementation Details

### Enemy Class Changes
```swift
// New properties
private var isAnimationStarted: Bool = false
private var hasBeenVisible: Bool = false

// New methods
func updateVisibilityAnimation(worldOffset: CGFloat, sceneHeight: CGFloat)
func forceStartAnimation()
var isSnakeAnimated: Bool
```

### Integration Points

#### SpawnManager
- Checks snake visibility every 10 frames in `spawnObjects()`
- Calls `updateVisibilityAnimation()` for all snake enemies

#### GameLoopCoordinator  
- Updated `updateEnemies()` method with optional visibility parameters
- Calls snake animation updates when parameters are available

#### GameScene
- Passes `worldOffset` and `sceneHeight` to `GameLoopCoordinator.updateEnemies()`

## Visibility Calculation
The visible range is calculated as:
```swift
let visibleMinY = -worldOffset - 100  // Small margin below screen
let visibleMaxY = -worldOffset + sceneHeight + 100  // Small margin above screen
```

## Testing
Comprehensive test suite in `SnakeAnimationTests.swift` covers:
- ✅ Snake doesn't animate on creation
- ✅ Snake starts animating when visible  
- ✅ Snake doesn't animate when outside visible range
- ✅ Force animation works for testing
- ✅ Non-snake enemies are unaffected
- ✅ Performance optimization prevents re-checking

## Usage Example
```swift
// Snake is created (no animation yet)
let snake = Enemy(type: .snake, position: CGPoint(x: 100, y: 1000), speed: 50)

// During game loop, when snake comes into view:
snake.updateVisibilityAnimation(worldOffset: worldOffset, sceneHeight: sceneHeight)

// Animation automatically starts when visible
print("Snake animated: \(snake.isSnakeAnimated)") // true

// For testing/debugging:
snake.forceStartAnimation()
```

This implementation provides a smooth, performant way to handle snake animations based on visibility while maintaining backward compatibility with existing game systems.