# GameScene Update Required

## Action Required
The `GameCoordinatorDelegate` protocol has been updated to include weather and health information. You need to update your `GameScene` to pass these parameters when triggering upgrade menus.

## What Changed

### Protocol Signature
```swift
// OLD
func triggerUpgradeMenu(hasFullHealth: Bool, distanceTraveled: Int)

// NEW
func triggerUpgradeMenu(hasFullHealth: Bool, distanceTraveled: Int, currentWeather: WeatherType, currentMaxHealth: Int)
```

## Required Changes in GameScene

### Find this code in your GameScene:
```swift
coordinator?.triggerUpgradeMenu(
    hasFullHealth: frog.currentHealth == frog.maxHealth,
    distanceTraveled: score
)
```

### Replace it with:
```swift
coordinator?.triggerUpgradeMenu(
    hasFullHealth: frog.currentHealth == frog.maxHealth,
    distanceTraveled: score,
    currentWeather: currentWeather,  // Your GameScene's weather variable
    currentMaxHealth: frog.maxHealth
)
```

## Notes
- Make sure your `GameScene` has a `currentWeather: WeatherType` property that tracks the current weather
- The `frog.maxHealth` property should contain the maximum number of hearts (typically 1-6)
- If you have multiple places where upgrades are triggered, update all of them

## Testing
After making this change:
1. Build the project
2. Start a game
3. Collect 10 coins to trigger an upgrade
4. Verify that upgrades are contextual (e.g., no Cross unless at night)
5. Test in different weather conditions
6. Test daily challenges to ensure filtering works there too
