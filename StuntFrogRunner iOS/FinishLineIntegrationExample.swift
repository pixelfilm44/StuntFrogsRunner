//
//  FinishLineIntegrationExample.swift
//  Example of how to integrate rocket cleanup when crossing finish line
//

// This is an example of how you should integrate the rocket cleanup
// into your main game loop. You'll need to adapt this to your actual GameScene.

/*
In your main GameScene's update method, you should have logic like this:

func update(_ currentTime: TimeInterval) {
    // ... your existing update logic ...
    
    // Check if finish line has been reached
    let currentScore = scoreManager.score // or however you access your score
    
    // IMPORTANT: Check if we just crossed the finish line this frame
    // You'll need to track whether you've already handled the finish line crossing
    if spawnManager.hasReachedFinishLine(currentScore: currentScore) && !finishLineCrossedThisLevel {
        finishLineCrossedThisLevel = true // Prevent multiple calls
        
        print("🏁 FINISH LINE REACHED! Current score: \(currentScore)")
        
        // CRITICAL: Handle rocket cleanup immediately when finish line is crossed
        spawnManager.handleFinishLineCrossed(
            frogController: frogController,
            lilyPads: lilyPads,
            sceneSize: size
        )
        
        // Then proceed with your existing level completion logic
        handleLevelComplete()
    }
    
    // ... rest of your update logic ...
}

// You should also reset the flag when starting a new level:
func startNewLevel() {
    finishLineCrossedThisLevel = false
    // ... your existing new level logic ...
}

*/

// Example variables you might need to add to your GameScene:
/*
class GameScene: SKScene {
    // ... existing properties ...
    
    // Add this flag to track finish line crossing
    private var finishLineCrossedThisLevel: Bool = false
    
    // ... rest of your class ...
}
*/