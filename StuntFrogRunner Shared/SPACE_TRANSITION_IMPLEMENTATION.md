# Space Weather Transition Implementation Guide

## Overview
This guide explains the complete flow for entering and exiting the space weather zone using the launch pad and warp pad.

## Key Principles

1. **Launch Pad** (Desert → Space)
   - Appears at score 2,900 in the desert weather zone
   - Disappears once the frog successfully lands on it
   - Triggers transition to space weather
   - Missing it results in game over

2. **Warp Pad** (Space → Day)
   - Appears at score 25,000 at the end of space weather
   - Is the ONLY way to exit space
   - Triggers transition back to sunny/day weather
   - Cannot be missed - stays visible until used

## Implementation Checklist

### 1. Add Tracking Variables to GameScene

```swift
class GameScene: SKScene {
    // ... existing properties ...
    
    // MARK: - Launch Pad Tracking (Desert → Space)
    private var hasSpawnedLaunchPad = false
    private var hasHitLaunchPad = false
    private var launchPadY: CGFloat = 0
    private var isLaunching = false
    private let launchPadMissDistance: CGFloat = 300
    
    // MARK: - Warp Pad Tracking (Space → Day)
    private var hasSpawnedWarpPad = false
    private var isWarping = false
}
```

### 2. Modify Pad Spawning Logic

In your `spawnNextPad()` or similar method, add these checks:

```swift
func spawnNextPad() {
    // FIRST: Check if we should spawn the launch pad (Desert → Space)
    if score >= Configuration.GameRules.launchPadSpawnScore && 
       score < Configuration.GameRules.spaceStartScore &&
       currentWeather == .desert && 
       !hasSpawnedLaunchPad {
        
        // Spawn launch pad in center
        let launchPad = Pad(
            position: CGPoint(x: Configuration.Dimensions.riverWidth / 2, y: nextPadY),
            radius: 60,
            type: .launchPad
        )
        launchPad.updateColor(weather: currentWeather)
        pads.append(launchPad)
        addChild(launchPad)
        
        hasSpawnedLaunchPad = true
        launchPadY = nextPadY
        
        // Don't spawn any more pads until launch happens
        return
    }
    
    // Don't spawn pads if waiting for launch pad interaction
    if hasSpawnedLaunchPad && !hasHitLaunchPad && score < Configuration.GameRules.spaceStartScore {
        return
    }
    
    // SECOND: Check if we should spawn the warp pad (Space → Day)
    if score >= Configuration.GameRules.warpPadSpawnScore && 
       currentWeather == .space && 
       !hasSpawnedWarpPad {
        
        // Spawn warp pad in center
        let warpPad = Pad(
            position: CGPoint(x: Configuration.Dimensions.riverWidth / 2, y: nextPadY),
            radius: 60,
            type: .warp
        )
        warpPad.updateColor(weather: currentWeather)
        pads.append(warpPad)
        addChild(warpPad)
        
        hasSpawnedWarpPad = true
        
        // Don't spawn any more pads until warp happens
        return
    }
    
    // Don't spawn pads if waiting for warp pad interaction
    if hasSpawnedWarpPad && !isWarping && currentWeather == .space {
        return
    }
    
    // THIRD: Continue with normal pad spawning
    // ... your existing pad spawning logic ...
}
```

### 3. Detect Landing on Special Pads

In your collision detection or landing logic:

```swift
// In your update() or wherever you check for pad landings
func checkSpecialPadLandings() {
    guard let currentPad = frog.onPad else { return }
    
    // Check for launch pad (Desert → Space)
    if currentPad.type == .launchPad && !hasHitLaunchPad {
        hasHitLaunchPad = true
        triggerLaunchSequence()
        return
    }
    
    // Check for warp pad (Space → Day)
    if currentPad.type == .warp && !isWarping {
        triggerWarpSequence()
        return
    }
}
```

Add this method call to your `update()` method:

```swift
override func update(_ currentTime: TimeInterval) {
    // ... existing update logic ...
    
    // Check for special pad interactions
    checkSpecialPadLandings()
    
    // Check if player missed the launch pad
    if hasSpawnedLaunchPad && !hasHitLaunchPad {
        checkLaunchPadMissed()
    }
    
    // ... rest of update logic ...
}
```

### 4. Implement Launch Pad Miss Detection

```swift
private func checkLaunchPadMissed() {
    // If frog has passed the launch pad by too much, they missed it
    if frog.position.y > launchPadY + launchPadMissDistance {
        handleMissedLaunchPad()
    }
}

private func handleMissedLaunchPad() {
    // Game over - missed the launch pad
    if gameMode == .endless {
        handleGameOver(raceResult: nil)
    } else if gameMode == .beatTheBoat {
        handleGameOver(raceResult: .lose(reason: .missedLaunchPad))
    }
}
```

### 5. Implement Launch Sequence (Desert → Space)

```swift
private func triggerLaunchSequence() {
    guard !isLaunching else { return }
    isLaunching = true
    
    // Pause the game
    isPaused = true
    
    // Play launch sound
    SoundManager.shared.playSFX(.rocketLaunch)
    
    // Create black overlay
    let blackOverlay = SKSpriteNode(color: .black, size: self.size)
    blackOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
    blackOverlay.zPosition = 9999
    blackOverlay.alpha = 0
    addChild(blackOverlay)
    
    // Fade to black
    let fadeOut = SKAction.fadeAlpha(to: 1.0, duration: Configuration.GameRules.launchFadeOutDuration)
    let wait = SKAction.wait(forDuration: Configuration.GameRules.launchBlackScreenDuration)
    
    // Transition to space
    let transition = SKAction.run { [weak self] in
        self?.transitionToSpace()
    }
    
    // Fade back in
    let fadeIn = SKAction.fadeAlpha(to: 0.0, duration: Configuration.GameRules.launchFadeInDuration)
    
    // Cleanup
    let cleanup = SKAction.run { [weak self] in
        blackOverlay.removeFromParent()
        self?.isPaused = false
        self?.isLaunching = false
        
        // IMPORTANT: Remove the launch pad so it doesn't appear again
        if let launchPadIndex = self?.pads.firstIndex(where: { $0.type == .launchPad }) {
            self?.pads[launchPadIndex].removeFromParent()
            self?.pads.remove(at: launchPadIndex)
        }
    }
    
    blackOverlay.run(SKAction.sequence([fadeOut, wait, transition, fadeIn, cleanup]))
}

private func transitionToSpace() {
    // Change weather to space
    currentWeather = .space
    updateWeatherVisuals()
    
    // Update score to space threshold if not already there
    if score < Configuration.GameRules.spaceStartScore {
        score = Configuration.GameRules.spaceStartScore
    }
    
    // The pad spawning will now create space-themed pads
}
```

### 6. Implement Warp Sequence (Space → Day)

```swift
private func triggerWarpSequence() {
    guard !isWarping else { return }
    isWarping = true
    
    // Pause the game
    isPaused = true
    
    // Play warp sound (if you have one)
    SoundManager.shared.playSFX(.warp)
    
    // Create black overlay
    let blackOverlay = SKSpriteNode(color: .black, size: self.size)
    blackOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
    blackOverlay.zPosition = 9999
    blackOverlay.alpha = 0
    addChild(blackOverlay)
    
    // Fade to black
    let fadeOut = SKAction.fadeAlpha(to: 1.0, duration: Configuration.GameRules.warpFadeOutDuration)
    let wait = SKAction.wait(forDuration: Configuration.GameRules.warpBlackScreenDuration)
    
    // Reset to day
    let reset = SKAction.run { [weak self] in
        self?.resetToDay()
    }
    
    // Fade back in
    let fadeIn = SKAction.fadeAlpha(to: 0.0, duration: Configuration.GameRules.warpFadeInDuration)
    
    // Cleanup
    let cleanup = SKAction.run { [weak self] in
        blackOverlay.removeFromParent()
        self?.isPaused = false
        self?.isWarping = false
    }
    
    blackOverlay.run(SKAction.sequence([fadeOut, wait, reset, fadeIn, cleanup]))
}

private func resetToDay() {
    // 1. Change weather to sunny
    currentWeather = .sunny
    updateWeatherVisuals()
    
    // 2. Clear all entities except frog
    pads.forEach { $0.removeFromParent() }
    pads.removeAll()
    
    enemies.forEach { $0.removeFromParent() }
    enemies.removeAll()
    
    coins.forEach { $0.removeFromParent() }
    coins.removeAll()
    
    snakes.forEach { $0.removeFromParent() }
    snakes.removeAll()
    
    crocodiles.forEach { $0.removeFromParent() }
    crocodiles.removeAll()
    
    treasureChests.forEach { $0.removeFromParent() }
    treasureChests.removeAll()
    
    flies.forEach { $0.removeFromParent() }
    flies.removeAll()
    
    // Clear any other entities you have (cacti, ghosts, etc.)
    
    // 3. Create a new starting pad for the frog
    let startPadY = frog.position.y + 200
    let startPad = Pad(
        position: CGPoint(x: Configuration.Dimensions.riverWidth / 2, y: startPadY),
        radius: 60,
        type: .normal
    )
    startPad.updateColor(weather: .sunny)
    pads.append(startPad)
    addChild(startPad)
    
    // 4. Reset frog to the new pad
    frog.position = startPad.position
    frog.zHeight = 0
    frog.velocity = .zero
    frog.zVelocity = 0
    frog.onPad = startPad
    
    // 5. Spawn new pads ahead
    for _ in 1...10 {
        spawnNextPad()
    }
    
    // 6. Reset warp pad tracker so it can spawn again if player reaches space again
    hasSpawnedWarpPad = false
    
    // 7. Reset launch pad tracker for potential future space trips
    hasSpawnedLaunchPad = false
    hasHitLaunchPad = false
}
```

### 7. Update Weather Transition Logic

Make sure weather doesn't auto-transition to/from space:

```swift
func updateWeather(forScore score: Int) {
    // ... your existing weather transitions for sunny, night, rain, winter, desert ...
    
    // IMPORTANT: Don't automatically transition to space
    // Space can only be entered via the launch pad
    if score >= Configuration.GameRules.launchPadSpawnScore && 
       score < Configuration.GameRules.spaceStartScore &&
       currentWeather == .desert {
        // Stay in desert until launch sequence completes
        return
    }
    
    // IMPORTANT: Don't automatically transition out of space
    // Space can only be exited via the warp pad
    if currentWeather == .space {
        // Stay in space until warp sequence completes
        return
    }
    
    // Only set space weather if triggered by launch sequence
    if score >= Configuration.GameRules.spaceStartScore && currentWeather != .space {
        // This should only happen through launch sequence
        // or if using debug starting score
        currentWeather = .space
        updateWeatherVisuals()
    }
}
```

### 8. Reset Tracking Variables on New Game

```swift
func resetGame() {
    // ... existing reset logic ...
    
    // Reset launch pad tracking
    hasSpawnedLaunchPad = false
    hasHitLaunchPad = false
    isLaunching = false
    launchPadY = 0
    
    // Reset warp pad tracking
    hasSpawnedWarpPad = false
    isWarping = false
}
```

## Game Flow Summary

1. **Desert phase (2,400 - 2,900)**: Normal desert gameplay
2. **Launch pad appears (2,900)**: Single pad in center of river
3. **Player must land on launch pad**: Failure = game over
4. **Launch sequence**: Fade to black → enter space → fade in
5. **Space phase (3,000 - 25,000)**: Normal space gameplay with space pads
6. **Warp pad appears (25,000)**: Single pad in center
7. **Player lands on warp pad**: No other way to leave space
8. **Warp sequence**: Fade to black → reset to sunny day → fade in
9. **Continue playing**: Back in sunny weather, can cycle through weathers again

## Testing Tips

```swift
// Test launch pad quickly
Configuration.Debug.startingScore = 2850  // Start just before launch pad

// Test warp pad quickly
Configuration.Debug.startingScore = 24900  // Start just before warp pad

// Test space weather directly (skips launch pad requirement)
Configuration.Debug.startingScore = 3000  // Start in space
```

## Visual Feedback Suggestions

Consider adding these visual cues to help players:

1. **Launch pad approach**: Show warning text "LAUNCH PAD AHEAD!" when score reaches 2,850
2. **Launch pad visual**: Make it large, glowing, with rocket symbols
3. **Warp pad approach**: Show text "WARP PAD AHEAD!" when score reaches 24,950
4. **Warp pad visual**: Make it swirling, portal-like, highly visible
5. **Space entrance**: Show "ENTERING SPACE!" text during fade
6. **Space exit**: Show "RETURNING TO EARTH!" text during fade

## Common Issues

### Issue: Launch pad doesn't appear
- Check that `currentWeather == .desert`
- Check that score is >= 2,900 and < 3,000
- Check that `hasSpawnedLaunchPad` is false

### Issue: Can't leave space
- Make sure warp pad spawns at score 25,000
- Check that normal pad spawning is blocked while warp pad is waiting
- Verify warp pad detection is working in collision logic

### Issue: Launch pad appears in space
- Make sure launch pad spawn check includes `currentWeather == .desert`
- Verify weather doesn't auto-transition before launch sequence

### Issue: Multiple launch/warp pads appear
- Ensure `hasSpawnedLaunchPad` and `hasSpawnedWarpPad` are set to true immediately after spawning
- Add early returns after spawning special pads

## Notes

- Both pads should appear **in the center** of the river for visibility
- The launch pad is **mandatory** - missing it ends the game
- The warp pad is **the only exit** from space - it's not optional
- After warping back to day, the player can potentially reach space again by surviving to score 2,900+
- Score and buffs are preserved through the warp transition
- All enemies and hazards are cleared during the warp

This creates a roguelike loop where skilled players can repeatedly cycle through weather zones!
