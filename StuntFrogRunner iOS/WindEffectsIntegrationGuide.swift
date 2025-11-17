//
//  WindEffectsIntegrationGuide.swift
//  Integration guide for adding wind effects to your GameScene
//

import Foundation

/*

WIND EFFECTS INTEGRATION GUIDE
==============================

To integrate wind effects into your GameScene, follow these steps:

1. ADD PROPERTIES TO YOUR GAMESCENE
----------------------------------

Add these properties to your GameScene class:

```swift
class GameScene: SKScene {
    // Your existing properties...
    var frogController: FrogController?
    var soundController: SoundController?
    var worldManager: WorldManager? // If you have a world management system
    
    // ... rest of your GameScene
}
```

2. SETUP WIND NOTIFICATIONS IN DIDMOVE(TO:)
-------------------------------------------

In your GameScene's didMove(to:) method, add:

```swift
override func didMove(to view: SKView) {
    // Your existing setup code...
    
    // Set up wind force notifications
    setupWindForceNotifications()
}
```

3. CLEANUP NOTIFICATIONS IN WILLMOVE(FROM:)
------------------------------------------

In your GameScene's willMove(from:) method (create if it doesn't exist), add:

```swift
override func willMove(from view: SKView) {
    // Clean up wind notifications to prevent memory leaks
    cleanupWindForceNotifications()
    
    // Your existing cleanup code...
}
```

4. ENSURE PROPER REFERENCES
---------------------------

Make sure your GameScene has proper references to:
- frogController: Your FrogController instance
- soundController: Your SoundController instance (optional for wind sounds)
- worldManager: Your world management system (optional for visual effects)

5. OPTIONAL: ADD WIND SOUND EFFECTS
-----------------------------------

If you want wind interaction sounds, add wind sound files to your project and 
implement the `playWindInteraction` method in SoundController, or modify the
existing placeholder implementation in the extension.

6. TESTING THE WIND EFFECTS
---------------------------

Wind effects will automatically trigger when:
- Weather is set to .rain, .stormy, or .storm in your EffectsManager
- The EffectsManager creates wind gusts during these weather conditions
- Wind forces are applied to the frog based on its current state:
  * Jumping: Adjusts trajectory
  * Sliding on ice: Adds to slide velocity  
  * Floating in water: Gentle drift
  * Grounded on lily pad: Visual wobble only

7. CUSTOMIZATION
----------------

You can customize wind effects by modifying the impact factors in GameScene+WindEffects.swift:
- windImpact for jumping frog: Currently 0.3 (30% of wind force affects trajectory)
- windImpact for sliding frog: Currently 0.2 (20% of wind force added to slide)
- windImpact for floating frog: Currently 0.1 (10% of wind force for gentle drift)
- wobbleIntensity for grounded frog: Currently capped at 0.1 radians

TROUBLESHOOTING
===============

If wind effects aren't working:

1. Check that setupWindForceNotifications() is called in didMove(to:)
2. Verify that your GameScene has proper frogController reference
3. Ensure EffectsManager is creating wind effects (check console for "💨" logs)
4. Check that NotificationCenter observers are set up correctly
5. Verify that your GameScene class name matches the extension target

*/