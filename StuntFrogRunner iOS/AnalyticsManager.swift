//
//  AnalyticsManager.swift
//  StuntFrogRunner iOS
//
//  Created for Google Analytics Integration
//

import Foundation
import FirebaseAnalytics

/// Manages all analytics tracking throughout the app
/// Uses Firebase Analytics as the backend for Google Analytics 4
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    // MARK: - Session & Retention Events
    
    /// Track app launch/session start
    func trackAppLaunch() {
        Analytics.logEvent("app_launch", parameters: nil)
    }
    
    /// Track when user views the main menu
    func trackMenuView() {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: "main_menu",
            AnalyticsParameterScreenClass: "MenuViewController"
        ])
    }
    
    /// Track when user views the shop
    func trackShopView() {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: "shop",
            AnalyticsParameterScreenClass: "ShopViewController"
        ])
    }
    
    // MARK: - Game Events
    
    /// Track game start with mode
    func trackGameStart(mode: GameMode, difficulty: Int = 0) {
        let modeString: String
        switch mode {
        case .endless:
            modeString = "endless"
        case .beatTheBoat:
            modeString = "beat_the_boat"
        case .dailyChallenge(let challenge):
            modeString = "daily_challenge"
            Analytics.logEvent("daily_challenge_start", parameters: [
                "challenge_date": challenge.date,
                "challenge_seed": challenge.seed,
                "climate": challenge.climate.rawValue
            ])
        }
        
        Analytics.logEvent("game_start", parameters: [
            "game_mode": modeString,
            "difficulty": difficulty
        ])
    }
    
    /// Track game end with comprehensive stats
    func trackGameEnd(
        mode: GameMode,
        score: Int,
        coins: Int,
        duration: TimeInterval,
        padsLanded: Int,
        enemiesDefeated: Int,
        maxCombo: Int,
        raceResult: RaceResult? = nil
    ) {
        let modeString: String
        switch mode {
        case .endless:
            modeString = "endless"
        case .beatTheBoat:
            modeString = "beat_the_boat"
        case .dailyChallenge:
            modeString = "daily_challenge"
        }
        
        var parameters: [String: Any] = [
            "game_mode": modeString,
            AnalyticsParameterScore: score,
            "coins_earned": coins,
            "duration_seconds": Int(duration),
            "pads_landed": padsLanded,
            "enemies_defeated": enemiesDefeated,
            "max_combo": maxCombo
        ]
        
        // Add race result if applicable
        if let result = raceResult {
            switch result {
            case .win:
                parameters["race_result"] = "win"
            case .lose(let reason):
                parameters["race_result"] = "lose"
                parameters["race_lose_reason"] = String(describing: reason)
            }
        }
        
        Analytics.logEvent("game_end", parameters: parameters)
        
        // Also log as level_end for better Google Analytics 4 reporting
        Analytics.logEvent(AnalyticsEventLevelEnd, parameters: [
            AnalyticsParameterLevelName: modeString,
            AnalyticsParameterSuccess: raceResult == nil ? 1 : (raceResult == .win ? 1 : 0),
            AnalyticsParameterScore: score
        ])
    }
    
    /// Track milestone achievements (every 100m, 500m, 1000m, etc.)
    func trackDistanceMilestone(distance: Int, mode: GameMode) {
        let modeString: String
        switch mode {
        case .endless:
            modeString = "endless"
        case .beatTheBoat:
            modeString = "beat_the_boat"
        case .dailyChallenge:
            modeString = "daily_challenge"
        }
        
        Analytics.logEvent("distance_milestone", parameters: [
            "distance": distance,
            "game_mode": modeString
        ])
    }
    
    /// Track power-up usage
    func trackPowerUpUsed(type: String, context: String = "gameplay") {
        Analytics.logEvent("power_up_used", parameters: [
            "power_up_type": type.lowercased(),
            "context": context
        ])
    }
    
    /// Track weather transitions
    func trackWeatherTransition(from: WeatherType, to: WeatherType, atDistance: Int) {
        Analytics.logEvent("weather_change", parameters: [
            "from_weather": from.rawValue,
            "to_weather": to.rawValue,
            "distance": atDistance
        ])
    }
    
    /// Track combo achievements
    func trackComboAchieved(comboCount: Int, score: Int) {
        // Only track significant combos to avoid spam
        if comboCount >= 5 {
            Analytics.logEvent("combo_achieved", parameters: [
                "combo_count": comboCount,
                "score_at_combo": score
            ])
        }
        
        // Track combo invincibility separately
        if comboCount >= 25 {
            Analytics.logEvent("combo_invincibility_activated", parameters: [
                "score": score
            ])
        }
    }
    
    /// Track crocodile ride events
    func trackCrocodileRide(completed: Bool, distance: Int) {
        Analytics.logEvent("crocodile_ride", parameters: [
            "completed": completed,
            "distance": distance
        ])
    }
    
    /// Track special events (space launch, warp back, etc.)
    func trackSpecialEvent(name: String, parameters: [String: Any] = [:]) {
        Analytics.logEvent(name, parameters: parameters)
    }
    
    // MARK: - Purchase Events
    
    /// Track in-app purchase
    func trackPurchase(productId: String, price: Double, currency: String = "USD", itemName: String) {
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterTransactionID: UUID().uuidString,
            AnalyticsParameterValue: price,
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterItemID: productId,
            AnalyticsParameterItemName: itemName
        ])
    }
    
    /// Track in-game coin spending
    func trackVirtualCurrencySpent(itemName: String, amount: Int, itemCategory: String) {
        Analytics.logEvent(AnalyticsEventSpendVirtualCurrency, parameters: [
            AnalyticsParameterItemName: itemName,
            AnalyticsParameterVirtualCurrencyName: "coins",
            AnalyticsParameterValue: amount,
            "item_category": itemCategory
        ])
    }
    
    /// Track upgrade purchases
    func trackUpgradePurchase(upgradeName: String, level: Int, cost: Int) {
        Analytics.logEvent("upgrade_purchase", parameters: [
            "upgrade_name": upgradeName,
            "upgrade_level": level,
            "cost": cost
        ])
    }
    
    /// Track consumable purchases from shop
    func trackConsumablePurchase(itemType: String, quantity: Int, cost: Int) {
        Analytics.logEvent("consumable_purchase", parameters: [
            "item_type": itemType,
            "quantity": quantity,
            "cost": cost
        ])
        
        // Also log as virtual currency spend
        trackVirtualCurrencySpent(itemName: itemType, amount: cost, itemCategory: "consumable")
    }
    
    // MARK: - Challenge Events
    
    /// Track challenge progress
    func trackChallengeProgress(challengeId: String, progress: Int, requirement: Int) {
        Analytics.logEvent("challenge_progress", parameters: [
            "challenge_id": challengeId,
            "progress": progress,
            "requirement": requirement,
            "progress_percent": Int((Double(progress) / Double(requirement)) * 100)
        ])
    }
    
    /// Track challenge completion
    func trackChallengeCompleted(challengeId: String, challengeTitle: String, reward: String) {
        Analytics.logEvent("challenge_completed", parameters: [
            "challenge_id": challengeId,
            "challenge_title": challengeTitle,
            "reward": reward
        ])
        
        // Also log as achievement unlocked
        Analytics.logEvent(AnalyticsEventUnlockAchievement, parameters: [
            AnalyticsParameterAchievementID: challengeId
        ])
    }
    
    /// Track daily challenge completion
    func trackDailyChallengeCompleted(challengeId: String, timeSeconds: Double, seed: Int) {
        Analytics.logEvent("daily_challenge_completed", parameters: [
            "challenge_id": challengeId,
            "completion_time": Int(timeSeconds),
            "seed": seed
        ])
    }
    
    /// Track daily challenge failure
    func trackDailyChallengeFailure(challengeId: String, distanceReached: Int, timeSeconds: Double) {
        Analytics.logEvent("daily_challenge_failed", parameters: [
            "challenge_id": challengeId,
            "distance_reached": distanceReached,
            "time_elapsed": Int(timeSeconds)
        ])
    }
    
    // MARK: - User Engagement
    
    /// Track tutorial completion
    func trackTutorialCompleted() {
        Analytics.logEvent(AnalyticsEventTutorialComplete, parameters: nil)
    }
    
    /// Track first time events
    func trackFirstTimeEvent(eventName: String) {
        Analytics.logEvent("first_time_\(eventName)", parameters: [
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    /// Track social sharing
    func trackShare(contentType: String, score: Int) {
        Analytics.logEvent(AnalyticsEventShare, parameters: [
            AnalyticsParameterContentType: contentType,
            "score": score
        ])
    }
    
    // MARK: - User Properties
    
    /// Set user properties for segmentation
    func setUserProperty(name: String, value: String) {
        Analytics.setUserProperty(value, forName: name)
    }
    
    /// Track player progression level
    func setPlayerLevel(level: Int) {
        setUserProperty(name: "player_level", value: "\(level)")
    }
    
    /// Track total games played
    func setTotalGamesPlayed(count: Int) {
        setUserProperty(name: "total_games_played", value: "\(count)")
    }
    
    /// Track player type based on engagement
    func setPlayerType(type: PlayerType) {
        setUserProperty(name: "player_type", value: type.rawValue)
    }
    
    // MARK: - Error Tracking
    
    /// Track errors that occur during gameplay
    func trackError(error: Error, context: String) {
        Analytics.logEvent("app_error", parameters: [
            "error_description": error.localizedDescription,
            "context": context
        ])
    }
}

// MARK: - Supporting Types

enum PlayerType: String {
    case new = "new"              // < 5 games
    case casual = "casual"        // 5-20 games
    case regular = "regular"      // 20-50 games
    case dedicated = "dedicated"  // 50-100 games
    case veteran = "veteran"      // 100+ games
}

// MARK: - GameMode Extension for Analytics

extension GameMode {
    var analyticsName: String {
        switch self {
        case .endless:
            return "endless"
        case .beatTheBoat:
            return "beat_the_boat"
        case .dailyChallenge:
            return "daily_challenge"
        }
    }
}

// MARK: - RaceResult Extension for Analytics

extension RaceResult {
    var analyticsResult: String {
        switch self {
        case .win:
            return "win"
        case .lose(let reason):
            return "lose_\(String(describing: reason))"
        }
    }
}
