# Daily Challenge Game Center Integration

## Overview
This document describes the implementation of Game Center leaderboard integration for daily challenges. When players complete a daily challenge, their completion time is now automatically submitted to a dedicated Game Center leaderboard.

## Changes Made

### 1. Configuration.swift
Added a new leaderboard ID constant for daily challenges:

```swift
struct GameCenter {
    static let leaderboardID = "TopScores"
    static let dailyChallengeLeaderboardID = "DailyChallenge"  // NEW
}
```

### 2. GameState.swift (GameCoordinator)
Updated the `gameDidEnd` method to submit daily challenge times to Game Center:

```swift
if score >= 2000 {
    challengeCompleted = true
    if let startTime = dailyChallengeStartTime {
        let timeElapsed = Date().timeIntervalSince(startTime)
        DailyChallenges.shared.recordRun(timeInSeconds: timeElapsed, completed: true)
        print("✅ Daily challenge completed in \(String(format: "%.1f", timeElapsed))s")
        
        // Submit time to Game Center (convert to milliseconds for leaderboard)
        let timeInMilliseconds = Int(timeElapsed * 1000)
        GameCenterManager.shared.submitScore(timeInMilliseconds, leaderboardID: Configuration.GameCenter.dailyChallengeLeaderboardID)
        print("🎮 Submitted daily challenge time to Game Center: \(timeInMilliseconds)ms")
    }
    // ... rest of completion logic
}
```

## How It Works

1. **Timer Start**: When a daily challenge begins, `dailyChallengeStartTime` is set to the current date/time in the `startDailyChallenge()` method.

2. **Completion Check**: When the game ends, if the player reached the 2000m goal, the challenge is considered completed.

3. **Time Calculation**: The completion time is calculated by subtracting the start time from the current time.

4. **Score Conversion**: The time in seconds is converted to milliseconds for Game Center submission (lower scores = better on the leaderboard).

5. **Game Center Submission**: The time is submitted to the "DailyChallenge" leaderboard using `GameCenterManager.shared.submitScore()`.

## Game Center Setup Requirements

To use this feature, you'll need to configure Game Center in App Store Connect:

1. Go to App Store Connect > Your App > Services > Game Center
2. Create a new leaderboard with ID: **"DailyChallenge"**
3. Set the leaderboard properties:
   - **Type**: Classic
   - **Score Format**: Elapsed Time (Milliseconds)
   - **Sort Order**: Low to High (best time wins)
   - **Score Range**: 0 to whatever makes sense for your game
   - **Display Name**: "Daily Challenge"

## Leaderboard Display Format

Since the score is stored in milliseconds, Game Center will automatically display it as a time in the format:
- MM:SS.mmm (e.g., "2:34.567" for 154,567 milliseconds)

Players with the fastest completion times will rank highest on the leaderboard.

## Testing

To test this feature:

1. Ensure Game Center authentication is working
2. Start a daily challenge from the main menu
3. Complete the challenge (reach 2000m)
4. Check the console for the log message: "🎮 Submitted daily challenge time to Game Center: XXXms"
5. Verify the score appears in the Game Center leaderboard

## Notes

- Only completed challenges (score >= 2000) are submitted to Game Center
- Failed attempts are recorded locally but NOT submitted to Game Center
- Times are stored in milliseconds to provide precision for speedrunners
- The leaderboard is global across all dates - it's not date-specific
- If you want date-specific leaderboards, you would need to create a separate leaderboard for each day (not recommended due to management overhead)
