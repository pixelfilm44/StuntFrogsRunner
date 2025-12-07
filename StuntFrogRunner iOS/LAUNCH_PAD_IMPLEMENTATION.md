# Launch Pad Implementation Guide

## Overview
This document describes the implementation of a launch pad that appears at the end of the desert weather zone (around score 19,500). The frog must land on or pass over this launch pad while wearing the rocket power-up to successfully transition into space. Missing the launch pad results in game over.

## Changes Already Made

### 1. Configuration.swift ✅
Added new constants to `Configuration.GameRules`:
- `launchPadSpawnScore: Int = 19500` - Score at which the launch pad appears (end of desert)
- `spaceStartScore: Int = 20000` - Score at which space begins after successful launch
- `launchFadeOutDuration: TimeInterval = 1.0` - Duration of fade to black
- `launchFadeInDuration: TimeInterval = 1.0` - Duration of fade from black
- `launchBlackScreenDuration: TimeInterval = 0.5` - Pause while screen is black

### 2. GameState.swift ✅
**RaceLossReason enum:**
- Added `.missedLaunchPad` case

### 3. GameOverViewController.swift ✅
**Loss reason display:**
- Added case for `.missedLaunchPad`:
  - Title: "MISSED IT!"
  - Message: "You missed the launch pad."

### 4. GameEntity.swift (Already Exists)
**PadType enum:**
- `.launchPad` case already exists
- Launch pad texture already loaded: `launchPadTexture = SKTexture(imageNamed: "launchPad")`
- Launch pad visuals already implemented (120x120 size, rotating animation, pulsing effect)

## Required Implementation in GameScene

You need to add the following logic to your GameScene class:

### 1. Add Tracking Variables

```swift
class GameScene: SKScene {
    // ... existing properties ...
    
    /// Tracks if the launch pad has been spawned for the desert→space transition
    private var hasSpawnedLaunchPad = false
    
    /// Tracks if the frog has successfully hit the launch pad
    private var hasHitLaunchPad = false
    
    /// The Y position where the launch pad was spawned
    private var launchPadY: CGFloat = 0
    
    /// Maximum distance past the launch pad before it's considered "missed"
    private let launchPadMissDistance: CGFloat = 300
}
```

### 2. Spawn the Launch Pad

In your pad spawning logic (typically in `spawnNextPad()` or similar), check if you should spawn the launch pad:

```swift
func spawnNextPad() {
    // ... existing pad spawning logic ...
    
    // Check if we should spawn the launch pad (end of desert, before space)
    if score >= Configuration.GameRules.launchPadSpawnScore && 
       score < Configuration.GameRules.spaceStartScore &&
       currentWeather == .desert && 
       !hasSpawnedLaunchPad {
        
        // Spawn the launch pad in the center of the river
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
        
        return // Don't spawn any more pads until launch sequence completes
    }
    
    // Don't spawn normal pads if we're waiting for launch pad interaction
    if hasSpawnedLaunchPad && !hasHitLaunchPad && score < Configuration.GameRules.spaceStartScore {
        return
    }
    
    // ... continue with normal pad spawning ...
}
```

### 3. Detect Landing on Launch Pad

In your collision/landing detection logic, check for launch pad interaction:

```swift
// In your update() or collision detection method
func checkLaunchPadInteraction() {
    guard hasSpawnedLaunchPad && !hasHitLaunchPad else { return }
    
    // Check if frog landed on the launch pad
    if let currentPad = frog.onPad, currentPad.type == .launchPad {
        // Success! Start launch sequence
        hasHitLaunchPad = true
        triggerLaunchSequence()
        return
    }
    
    // Check if frog is using rocket and passes over/near the launch pad
    if frog.rocketState == .flying {
        let distanceFromLaunchPad = abs(frog.position.y - launchPadY)
        let horizontalDistance = abs(frog.position.x - (Configuration.Dimensions.riverWidth / 2))
        
        // If rocket passes near the launch pad (within pad radius horizontally)
        if frog.position.y >= launchPadY && 
           distanceFromLaunchPad < 100 && 
           horizontalDistance < 100 {
            hasHitLaunchPad = true
            triggerLaunchSequence()
            return
        }
    }
    
    // Check if frog has passed the launch pad without hitting it
    if frog.position.y > launchPadY + launchPadMissDistance {
        // Game over - missed the launch pad!
        handleMissedLaunchPad()
    }
}
```

Call this method in your `update()`:

```swift
override func update(_ currentTime: TimeInterval) {
    // ... existing update logic ...
    
    // Check launch pad interaction during desert→space transition
    checkLaunchPadInteraction()
    
    // ... rest of update logic ...
}
```

### 4. Implement the Launch Sequence

```swift
private var isLaunching = false

private func triggerLaunchSequence() {
    guard !isLaunching else { return }
    isLaunching = true
    
    // Pause game physics
    isPaused = true
    
    // Play launch sound effect (if you have one)
    SoundManager.shared.playSFX(.rocketLaunch)
    
    // Create a black overlay node
    let blackOverlay = SKSpriteNode(color: .black, size: self.size)
    blackOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
    blackOverlay.zPosition = 9999 // Above everything
    blackOverlay.alpha = 0
    addChild(blackOverlay)
    
    // Fade to black
    let fadeOut = SKAction.fadeAlpha(to: 1.0, duration: Configuration.GameRules.launchFadeOutDuration)
    
    // Wait while black
    let wait = SKAction.wait(forDuration: Configuration.GameRules.launchBlackScreenDuration)
    
    // Transition to space
    let transition = SKAction.run { [weak self] in
        self?.transitionToSpace()
    }
    
    // Fade from black
    let fadeIn = SKAction.fadeAlpha(to: 0.0, duration: Configuration.GameRules.launchFadeInDuration)
    
    // Clean up and resume
    let cleanup = SKAction.run { [weak self] in
        blackOverlay.removeFromParent()
        self?.isPaused = false
        self?.isLaunching = false
    }
    
    // Run the sequence
    blackOverlay.run(SKAction.sequence([fadeOut, wait, transition, fadeIn, cleanup]))
}

private func transitionToSpace() {
    // 1. Change weather to space
    currentWeather = .space
    updateWeatherVisuals()
    
    // 2. Update score to space threshold (if not already there)
    if score < Configuration.GameRules.spaceStartScore {
        score = Configuration.GameRules.spaceStartScore
    }
    
    // 3. Continue spawning pads normally in space
    // The pad spawning will now see currentWeather == .space and spawn space pads
}
```

### 5. Handle Missed Launch Pad

```swift
private func handleMissedLaunchPad() {
    // Game over - player missed the launch pad
    
    // In endless mode, this is a regular game over
    if gameMode == .endless {
        // You might want to show a special message or just treat it as drowning
        handleGameOver(raceResult: nil)
    } 
    // In race mode, this is a race loss
    else if gameMode == .beatTheBoat {
        handleGameOver(raceResult: .lose(reason: .missedLaunchPad))
    }
}
```

### 6. Update Weather Transition Logic

Make sure your weather update logic doesn't automatically transition from desert to space:

```swift
func updateWeather(forScore score: Int) {
    // ... existing weather logic for sunny, night, rain, winter, desert ...
    
    // Don't automatically transition to space - only via launch pad
    if score >= Configuration.GameRules.launchPadSpawnScore && 
       score < Configuration.GameRules.spaceStartScore &&
       currentWeather == .desert {
        // Stay in desert until launch sequence completes
        return
    }
    
    // Only enter space after successful launch
    if score >= Configuration.GameRules.spaceStartScore && currentWeather != .space {
        // This should only happen if triggered by launch sequence
        // or if using debug starting score
        currentWeather = .space
        updateWeatherVisuals()
    }
}
```

### 7. Reset on New Game

Make sure to reset the launch pad tracking variables when starting a new game:

```swift
func resetGame() {
    // ... existing reset logic ...
    
    hasSpawnedLaunchPad = false
    hasHitLaunchPad = false
    isLaunching = false
    launchPadY = 0
}
```

## Visual Assets Required

Make sure you have a `launchPad.png` image in your asset catalog. The image should:
- Be a square (recommended: 512x512 or 1024x1024)
- Show a rocket launch pad / platform visual
- Look distinct from lily pads (metallic/technological appearance)
- Work well with the desert theme (sandy platform with rocket launch markings)

## Game Flow

1. **Desert Phase (10,000 - 19,500)**: Normal desert gameplay with sand pads, cacti, instant-death water
2. **Launch Pad Appears (19,500)**: Launch pad spawns in the center of the river
3. **Critical Jump**: Player must:
   - Land on the launch pad, OR
   - Pass over/near it while using the rocket power-up
4. **Success**: Screen fades to black, transitions to space, fades back in
5. **Failure**: If player passes the launch pad by more than 300 units without hitting it → Game Over
6. **Space Phase (20,000+)**: Normal space gameplay continues

## Testing

To test the launch pad quickly:

```swift
// In Configuration.Debug
static let startingScore: Int = 19400 // Start just before launch pad

// Or lower the spawn threshold temporarily
// In Configuration.GameRules
static let launchPadSpawnScore: Int = 500 // For quick testing
```

## Notes

- The launch pad appears only once per game run
- Unlike the warp pad, the launch pad is **required** - missing it ends the game
- In endless mode, missing the launch pad should be treated similarly to drowning (game over with current score)
- In race mode, missing it should use the new `.missedLaunchPad` loss reason
- The rocket power-up provides an alternative way to "hit" the launch pad by flying over/near it
- Consider providing visual cues (arrows, particles, text) to alert the player that the launch pad is critical

## Alternative: Make Launch Pad Optional

If you want the launch pad to be optional (just a cool bonus), you could:
1. Remove the "missed launch pad" check
2. Allow automatic transition to space at score 20,000
3. Make hitting the launch pad give a bonus (coins, health restore, etc.)

To implement this alternative, simply don't call `handleMissedLaunchPad()` and let the weather naturally transition at 20,000.
