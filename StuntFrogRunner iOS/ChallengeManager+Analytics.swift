//
//  ChallengeManager+Analytics.swift
//  StuntFrogRunner iOS
//
//  Analytics integration for challenge tracking
//

import Foundation

extension ChallengeManager {
    
    // MARK: - Challenge Analytics Methods
    
    /// Track challenge progress update
    func trackChallengeProgressUpdate(for challenge: Challenge) {
        // Only track significant progress milestones to avoid spam
        let progressPercent = Int(challenge.progressPercentage * 100)
        let milestones = [25, 50, 75, 90]
        
        if milestones.contains(progressPercent) {
            AnalyticsManager.shared.trackChallengeProgress(
                challengeId: challenge.id,
                progress: challenge.progress,
                requirement: challenge.requirement
            )
        }
    }
    
    /// Track challenge completion
    func trackChallengeComplete(challenge: Challenge) {
        AnalyticsManager.shared.trackChallengeCompleted(
            challengeId: challenge.id,
            challengeTitle: challenge.title,
            reward: challenge.reward.displayText
        )
    }
    
    /// Track when a challenge reward is claimed
    func trackRewardClaimed(challenge: Challenge) {
        AnalyticsManager.shared.trackSpecialEvent(
            name: "challenge_reward_claimed",
            parameters: [
                "challenge_id": challenge.id,
                "reward": challenge.reward.displayText
            ]
        )
    }
}

// MARK: - Integration Guide for ChallengeManager

/*
 
 INTEGRATION INSTRUCTIONS FOR ChallengeManager.swift
 ====================================================
 
 1. ADD to updateChallengeProgress() or similar method:
    ─────────────────────────────────────────────────────
    func updateProgress(for challengeId: String, progress: Int) {
        guard var challenge = challenges.first(where: { $0.id == challengeId }) else {
            return
        }
        
        challenge.progress = progress
        
        // Check if completed
        if !challenge.isCompleted && progress >= challenge.requirement {
            challenge.isCompleted = true
            trackChallengeComplete(challenge: challenge)  // <-- Add this
        } else {
            trackChallengeProgressUpdate(for: challenge)  // <-- Add this
        }
        
        // Update the challenge in array
        if let index = challenges.firstIndex(where: { $0.id == challengeId }) {
            challenges[index] = challenge
        }
        
        saveChallenges()
    }
 
 
 2. ADD to reward claiming:
    ─────────────────────────────────────────────────────
    func claimReward(for challengeId: String) {
        guard var challenge = challenges.first(where: { $0.id == challengeId }),
              challenge.isCompleted,
              !challenge.isRewardClaimed else {
            return
        }
        
        challenge.isRewardClaimed = true
        trackRewardClaimed(challenge: challenge)  // <-- Add this
        
        // Update the challenge
        if let index = challenges.firstIndex(where: { $0.id == challengeId }) {
            challenges[index] = challenge
        }
        
        // Apply the reward
        applyReward(challenge.reward)
        saveChallenges()
    }
 
 
 3. EXISTING method enhancements:
    ─────────────────────────────────────────────────────
    // Your existing recordScoreUpdate method:
    func recordScoreUpdate(currentScore: Int) {
        // Update score-related challenges
        for i in 0..<challenges.count {
            var challenge = challenges[i]
            
            if challenge.type == .singleRunScore {
                let previousProgress = challenge.progress
                challenge.progress = max(challenge.progress, currentScore)
                
                // Track if significant progress made
                if challenge.progress > previousProgress {
                    if !challenge.isCompleted && challenge.progress >= challenge.requirement {
                        challenge.isCompleted = true
                        trackChallengeComplete(challenge: challenge)  // <-- Add this
                    } else {
                        trackChallengeProgressUpdate(for: challenge)  // <-- Add this
                    }
                }
                
                challenges[i] = challenge
            }
        }
        
        saveChallenges()
    }
 
 
 4. TRACK real-time progress events:
    ─────────────────────────────────────────────────────
    // In recordEnemyDefeated():
    func recordEnemyDefeated() {
        stats.totalEnemiesDefeated += 1
        
        for i in 0..<challenges.count {
            var challenge = challenges[i]
            if challenge.type == .enemiesDefeated && !challenge.isCompleted {
                challenge.progress += 1
                
                if challenge.progress >= challenge.requirement {
                    challenge.isCompleted = true
                    trackChallengeComplete(challenge: challenge)  // <-- Add this
                } else {
                    trackChallengeProgressUpdate(for: challenge)  // <-- Add this
                }
                
                challenges[i] = challenge
            }
        }
        
        saveStats()
        saveChallenges()
    }
 
*/

// MARK: - DailyChallenges Analytics Extension

extension DailyChallenges {
    
    /// Track when player views daily challenge details
    func trackDailyChallengeViewed(challenge: DailyChallenge) {
        AnalyticsManager.shared.trackSpecialEvent(
            name: "daily_challenge_viewed",
            parameters: [
                "challenge_id": challenge.id,
                "climate": challenge.climate.rawValue,
                "difficulty": challenge.difficulty.rawValue
            ]
        )
    }
    
    /// Track when player starts a daily challenge
    func trackDailyChallengeStarted(challenge: DailyChallenge) {
        AnalyticsManager.shared.trackSpecialEvent(
            name: "daily_challenge_started",
            parameters: [
                "challenge_id": challenge.id,
                "climate": challenge.climate.rawValue,
                "difficulty": challenge.difficulty.rawValue,
                "seed": challenge.seed
            ]
        )
    }
    
    /// Track personal best on daily challenge
    func trackPersonalBest(challenge: DailyChallenge, timeSeconds: Double) {
        AnalyticsManager.shared.trackSpecialEvent(
            name: "daily_challenge_personal_best",
            parameters: [
                "challenge_id": challenge.id,
                "time": Int(timeSeconds)
            ]
        )
    }
}

/*
 
 INTEGRATION INSTRUCTIONS FOR DailyChallenges.swift
 ===================================================
 
 1. ADD tracking when challenge is selected:
    ─────────────────────────────────────────────────────
    func selectChallenge(_ challenge: DailyChallenge) {
        selectedChallenge = challenge
        trackDailyChallengeViewed(challenge: challenge)  // <-- Add this
    }
 
 
 2. ADD tracking when challenge starts:
    ─────────────────────────────────────────────────────
    // In the method that launches the daily challenge game:
    func startDailyChallenge() {
        guard let challenge = selectedChallenge else { return }
        trackDailyChallengeStarted(challenge: challenge)  // <-- Add this
        
        // Launch game with challenge mode
        // ...
    }
 
 
 3. ADD tracking for personal bests:
    ─────────────────────────────────────────────────────
    func recordRun(timeInSeconds: Double, completed: Bool) {
        guard let challenge = getCurrentDailyChallenge() else { return }
        
        // ... existing code to save run ...
        
        // Check if it's a personal best
        if completed {
            let existingBest = getPersonalBest(for: challenge.id)
            if existingBest == nil || timeInSeconds < existingBest! {
                trackPersonalBest(challenge: challenge, timeSeconds: timeInSeconds)  // <-- Add this
            }
        }
    }
 
*/

// MARK: - Challenge Statistics Tracking

extension ChallengeStats {
    
    /// Generate analytics report from stats
    func generateAnalyticsReport() -> [String: Any] {
        return [
            "total_distance": totalDistance,
            "total_coins": totalCoins,
            "total_enemies_defeated": totalEnemiesDefeated,
            "total_games": totalGames,
            "crocodile_rides": crocodileRidesCompleted,
            "rockets_used": rocketsUsed,
            "highest_combo": highestCombo,
            "best_single_run": bestSingleRunScore
        ]
    }
    
    /// Track lifetime statistics periodically
    func trackLifetimeStats() {
        let stats = generateAnalyticsReport()
        AnalyticsManager.shared.trackSpecialEvent(
            name: "lifetime_stats_snapshot",
            parameters: stats
        )
    }
}

/*
 
 INTEGRATION FOR LIFETIME STATS
 ================================
 
 Call this periodically (e.g., every 10 games or weekly):
 
    ChallengeManager.shared.stats.trackLifetimeStats()
 
*/
