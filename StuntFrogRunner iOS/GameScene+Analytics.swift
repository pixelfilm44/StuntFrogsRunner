//
//  GameScene+Analytics.swift
//  StuntFrogRunner iOS
//
//  Analytics integration helper methods for GameScene
//

import Foundation

extension GameScene {
    
    // MARK: - Stored Properties (Add these to main GameScene class)
    
    /// Storage key for game start time
    private static var gameStartTimeKey: UInt8 = 0
    
    /// The time when the current game session started
    var gameStartTime: TimeInterval {
        get {
            objc_getAssociatedObject(self, &Self.gameStartTimeKey) as? TimeInterval ?? 0
        }
        set {
            objc_setAssociatedObject(self, &Self.gameStartTimeKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// Storage key for total enemies defeated
    private static var totalEnemiesDefeatedKey: UInt8 = 0
    
    /// Total enemies defeated in this run
    var totalEnemiesDefeated: Int {
        get {
            objc_getAssociatedObject(self, &Self.totalEnemiesDefeatedKey) as? Int ?? 0
        }
        set {
            objc_setAssociatedObject(self, &Self.totalEnemiesDefeatedKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// The current difficulty level (if not already defined in GameScene)
    /// Override this if GameScene has its own difficultyLevel property
    var difficultyLevel: Int {
        // You can customize this logic based on your game's difficulty system
        // For now, return a default value (0 = normal)
        // You could also derive this from game state, e.g.:
        // 0 = easy, 1 = normal, 2 = hard, etc.
        return 0
    }
    
    // MARK: - Analytics Tracking Methods
    
    /// Call this at the start of resetGame() to track game session
    func trackGameStart() {
        gameStartTime = Date().timeIntervalSince1970
        
        AnalyticsManager.shared.trackGameStart(
            mode: gameMode,
            difficulty: difficultyLevel
        )
    }
    
    /// Call this in your game over sequence
    func trackGameEnd() {
        let duration = Date().timeIntervalSince1970 - gameStartTime
        
        AnalyticsManager.shared.trackGameEnd(
            mode: gameMode,
            score: score,
            coins: coinsCollectedThisRun,
            duration: duration,
            padsLanded: padsLandedThisRun,
            enemiesDefeated: totalEnemiesDefeated,
            maxCombo: maxComboThisRun,
            raceResult: raceResult
        )
        
        // Track daily challenge specific events
        if case .dailyChallenge(let challenge) = gameMode {
            if score >= 2000 {
                AnalyticsManager.shared.trackDailyChallengeCompleted(
                    challengeId: challenge.date,
                    timeSeconds: challengeElapsedTime,
                    seed: challenge.seed
                )
            } else {
                AnalyticsManager.shared.trackDailyChallengeFailure(
                    challengeId: challenge.date,
                    distanceReached: score,
                    timeSeconds: challengeElapsedTime
                )
            }
        }
    }
    
    /// Track distance milestones as player progresses
    func trackDistanceMilestone(_ distance: Int) {
        // Only track significant milestones to avoid spam
        let milestones = [100, 200, 500, 1000, 1500, 2000, 2500, 3000, 5000]
        if milestones.contains(distance) {
            AnalyticsManager.shared.trackDistanceMilestone(
                distance: distance,
                mode: gameMode
            )
        }
    }
    
    /// Track weather changes
    func trackWeatherChange(from oldWeather: WeatherType, to newWeather: WeatherType) {
        AnalyticsManager.shared.trackWeatherTransition(
            from: oldWeather,
            to: newWeather,
            atDistance: score
        )
    }
    
    /// Track combo achievements
    func trackCombo() {
        AnalyticsManager.shared.trackComboAchieved(
            comboCount: comboCount,
            score: score
        )
    }
    
    /// Track crocodile ride events
    func trackCrocodileRideComplete() {
        AnalyticsManager.shared.trackCrocodileRide(
            completed: true,
            distance: score
        )
    }
    
    /// Track power-up collection/usage
    func trackPowerUpCollected(_ type: String) {
        AnalyticsManager.shared.trackPowerUpUsed(
            type: type,
            context: "collected"
        )
    }
    
    /// Track power-up activation
    func trackPowerUpActivated(_ type: String) {
        AnalyticsManager.shared.trackPowerUpUsed(
            type: type,
            context: "activated"
        )
    }
    
    /// Track special events
    func trackSpaceLaunch() {
        AnalyticsManager.shared.trackSpecialEvent(
            name: "space_launch",
            parameters: ["distance": score]
        )
    }
    
    func trackWarpBack() {
        AnalyticsManager.shared.trackSpecialEvent(
            name: "warp_back",
            parameters: ["distance": score]
        )
    }
    
    func trackDesertTransition() {
        AnalyticsManager.shared.trackSpecialEvent(
            name: "desert_transition",
            parameters: ["distance": score]
        )
    }
    
    func trackTreasureChestOpened(reward: TreasureChest.Reward) {
        let rewardName: String
        switch reward {
        case .heartsRefill:
            rewardName = "hearts_refill"
        case .lifevest4Pack:
            rewardName = "lifevest_4pack"
        case .cross4Pack:
            rewardName = "cross_4pack"
        case .axe4Pack:
            rewardName = "axe_4pack"
        case .swatter4Pack:
            rewardName = "swatter_4pack"
        }
        
        AnalyticsManager.shared.trackSpecialEvent(
            name: "treasure_chest_opened",
            parameters: [
                "reward": rewardName,
                "distance": score
            ]
        )
    }
}

// MARK: - Integration Points for GameScene.swift

/*
 
 INTEGRATION INSTRUCTIONS
 ========================
 
 Add these tracking calls to your existing GameScene.swift methods:
 
 1. ADD TO resetGame() method:
    ─────────────────────────────────────────────────────
    // Near the beginning of resetGame(), add:
    trackGameStart()
 
 
 2. ADD TO game over sequences:
    ─────────────────────────────────────────────────────
    // In playDrowningSequence(), playEnemyDeathSequence(), etc.
    // Right before calling coordinator?.gameDidEnd(), add:
    trackGameEnd()
 
 
 3. ADD TO score update in update() method:
    ─────────────────────────────────────────────────────
    let currentScore = Int(frog.position.y / 10)
    if currentScore > score {
        score = currentScore
        scoreLabel.text = "\(score)m"
        
        // Track milestones
        trackDistanceMilestone(currentScore)
        
        // Existing challenge tracking...
        ChallengeManager.shared.recordScoreUpdate(currentScore: score)
    }
 
 
 4. ADD TO setWeather() method:
    ─────────────────────────────────────────────────────
    private func setWeather(_ type: WeatherType, duration: TimeInterval = 1.0) {
        let oldWeather = self.currentWeather
        self.currentWeather = type
        
        // Track weather change
        if oldWeather != type {
            trackWeatherChange(from: oldWeather, to: type)
        }
        
        // ... rest of existing code
    }
 
 
 5. ADD TO combo tracking in didLand(on:) method:
    ─────────────────────────────────────────────────────
    if comboCount >= 3 {
        showComboPopup(at: frog.position, count: comboCount)
        trackCombo()  // <-- Add this
    }
 
 
 6. ADD TO crocodile ride completion:
    ─────────────────────────────────────────────────────
    func didCompleteCrocodileRide(crocodile: Crocodile) {
        // ... existing code ...
        
        // Track challenge progress
        ChallengeManager.shared.recordCrocodileRideCompleted()
        trackCrocodileRideComplete()  // <-- Add this
        
        // ... rest of code
    }
 
 
 7. ADD TO power-up collection in applyUpgrade() method:
    ─────────────────────────────────────────────────────
    func applyUpgrade(_ type: String) {
        trackPowerUpCollected(type)  // <-- Add this at the start
        
        switch type {
        case "HEART":
            // ... existing code ...
        case "ROCKET":
            // ... existing code ...
            trackPowerUpActivated("ROCKET")  // <-- Add for instant activation
        // ... etc
        }
    }
 
 
 8. ADD TO special events:
    ─────────────────────────────────────────────────────
    // In launchToSpace():
    trackSpaceLaunch()
    
    // In warpBackToDay():
    trackWarpBack()
    
    // In endDesertCutscene():
    trackDesertTransition()
    
    // In didCollect(treasureChest:):
    trackTreasureChestOpened(reward: reward)
 
 
 9. PROPERTIES HANDLED:
    ─────────────────────────────────────────────────────
    // gameStartTime and totalEnemiesDefeated are now handled via associated objects
    // in this extension. If you prefer, you can add them directly to GameScene:
    // private var gameStartTime: TimeInterval = 0
    // private var totalEnemiesDefeated: Int = 0
    
    // Note: difficultyLevel currently returns "normal" by default.
    // Override it in GameScene if you have a difficulty system.
 
 
10. TRACK enemies defeated:
    ─────────────────────────────────────────────────────
    // Create a helper method or track in existing collision methods:
    private func incrementEnemyDefeatedCount() {
        totalEnemiesDefeated += 1
    }
    
    // Call this in:
    // - didCrash(into enemy:) when destroying
    // - didDestroyEnemyWithSwatter()
    // - didDestroyEnemyWithHoney()
    // - Anywhere else enemies are defeated
 
*/
