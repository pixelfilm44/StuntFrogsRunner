# Warp Pad Implementation Guide

## Overview
This document describes the implementation of a warp pad that appears at the end of the space weather zone. When the frog lands on it, the game will fade to black, then fade back in, resetting to daytime weather with the frog on a fresh lily pad.

## Changes Made

### 1. Configuration.swift
Added new constants to `Configuration.GameRules`:
- `warpPadSpawnScore: Int = 25000` - Score at which the warp pad appears
- `warpFadeOutDuration: TimeInterval = 1.0` - Duration of fade to black
- `warpFadeInDuration: TimeInterval = 1.0` - Duration of fade from black
- `warpBlackScreenDuration: TimeInterval = 0.5` - Pause while screen is black

### 2. GameEntity.swift
**PadType enum:**
- Added `.warp` case to `PadType` enum

**Pad texture loading:**
- Added `private static let warpPadTexture = SKTexture(imageNamed: "warpPad")`

**Pad setupVisuals():**
- Added warp pad visualization with:
  - 120x120 size (same as launch pad)
  - Continuous rotation animation (2-second full rotation)
  - Pulsing alpha effect (fades between 0.7 and 1.0)

## Required Implementation in GameScene

You need to add the following logic to your GameScene class:

### 1. Spawn the Warp Pad
In your pad spawning logic, check if the score has reached `Configuration.GameRules.warpPadSpawnScore` and if the current weather is `.space`. If so, spawn a warp pad:

```swift
// Example in your spawnPad() or similar method
if score >= Configuration.GameRules.warpPadSpawnScore && currentWeather == .space && !hasSpawnedWarpPad {
    let warpPad = Pad(position: CGPoint(x: riverWidth / 2, y: spawnY), radius: 60, type: .warp)
    pads.append(warpPad)
    addChild(warpPad)
    hasSpawnedWarpPad = true // Track that we've spawned it
}
```

### 2. Detect Landing on Warp Pad
In your frog landing detection logic (where you check `frog.land(on: pad, weather: currentWeather)`), add a check for warp pad:

```swift
// In your collision/landing detection
if let pad = frog.onPad, pad.type == .warp {
    triggerWarpTransition()
}
```

### 3. Implement the Warp Transition
Create a method to handle the warp transition:

```swift
private var isWarping = false

private func triggerWarpTransition() {
    guard !isWarping else { return }
    isWarping = true
    
    // Pause game physics
    isPaused = true
    
    // Create a black overlay node
    let blackOverlay = SKSpriteNode(color: .black, size: self.size)
    blackOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
    blackOverlay.zPosition = 9999 // Above everything
    blackOverlay.alpha = 0
    addChild(blackOverlay)
    
    // Fade to black
    let fadeOut = SKAction.fadeAlpha(to: 1.0, duration: Configuration.GameRules.warpFadeOutDuration)
    
    // Wait while black
    let wait = SKAction.wait(forDuration: Configuration.GameRules.warpBlackScreenDuration)
    
    // Reset game state to daytime
    let reset = SKAction.run { [weak self] in
        self?.resetToDay()
    }
    
    // Fade from black
    let fadeIn = SKAction.fadeAlpha(to: 0.0, duration: Configuration.GameRules.warpFadeInDuration)
    
    // Clean up and resume
    let cleanup = SKAction.run { [weak self] in
        blackOverlay.removeFromParent()
        self?.isPaused = false
        self?.isWarping = false
    }
    
    // Run the sequence
    blackOverlay.run(SKAction.sequence([fadeOut, wait, reset, fadeIn, cleanup]))
}

private func resetToDay() {
    // 1. Change weather to sunny
    currentWeather = .sunny
    updateWeatherVisuals()
    
    // 2. Clear all existing pads, enemies, coins, etc.
    pads.forEach { $0.removeFromParent() }
    pads.removeAll()
    
    enemies.forEach { $0.removeFromParent() }
    enemies.removeAll()
    
    coins.forEach { $0.removeFromParent() }
    coins.removeAll()
    
    // Add similar cleanup for snakes, crocodiles, treasure chests, etc.
    
    // 3. Position frog on a new starting lily pad at current height
    let startPadY = frog.position.y + 200 // Place pad slightly ahead of frog
    let startPad = Pad(position: CGPoint(x: riverWidth / 2, y: startPadY), 
                      radius: 60, 
                      type: .normal)
    startPad.updateColor(weather: .sunny)
    pads.append(startPad)
    addChild(startPad)
    
    // Reset frog position to center of new pad
    frog.position = startPad.position
    frog.zHeight = 0
    frog.velocity = .zero
    frog.zVelocity = 0
    frog.onPad = startPad
    
    // 4. Spawn new pads ahead
    for i in 1...10 {
        spawnNextPad() // Use your existing pad spawning logic
    }
    
    // 5. Reset warp pad tracker so it can spawn again later
    hasSpawnedWarpPad = false
}
```

### 4. Update Weather Transition Logic
Make sure your weather transition logic doesn't automatically transition from space back to day. The warp pad should be the only way to leave space:

```swift
// In your weather update logic
func updateWeather(forScore score: Int) {
    // ... your existing weather logic ...
    
    // Don't automatically transition out of space - only via warp pad
    if currentWeather == .space {
        return // Stay in space until warp pad is used
    }
}
```

### 5. Add a Tracking Variable
Add this property to your GameScene class:

```swift
private var hasSpawnedWarpPad = false
```

## Visual Assets Required

Make sure you have a `warpPad.png` image in your asset catalog. The image should:
- Be a square (recommended: 512x512 or 1024x1024)
- Show a portal/warp/teleportation visual
- Look good when rotating (circular design recommended)
- Stand out from other pads (bright colors, glowing effects, etc.)

## Testing

To test the warp pad quickly, you can temporarily change the spawn score:
```swift
// In Configuration.swift (for testing only)
static let warpPadSpawnScore: Int = 1000 // Lower score for testing
```

Or use the debug starting score:
```swift
// In Configuration.Debug
static let startingScore: Int = 24900 // Start just before warp pad appears
```

## Notes

- The warp pad only appears once per space visit
- After warping, the game continues with the same score (the frog has "warped" through space-time)
- All entities (enemies, coins, hazards) are cleared during the warp
- The frog keeps all buffs, health, and upgrades through the warp
- Weather cycles can continue normally after returning to day
