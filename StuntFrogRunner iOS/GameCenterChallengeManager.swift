import Foundation
import GameKit

// MARK: - Game Center Challenge Manager
//
// This manager handles creating and sending challenges to Game Center friends
// for daily challenges in StuntFrog.
//
// FEATURES:
// - Creates formatted challenge messages with player times
// - Supports multiple sharing methods (Game Center, Share Sheet, Clipboard)
// - Tracks challenge statistics
// - Handles Game Center authentication gracefully
//
// USAGE:
//   let manager = GameCenterChallengeManager.shared
//   manager.createChallenge(challengeName: "Sunny Bee Bonanza", time: 125.43)

class GameCenterChallengeManager {
    static let shared = GameCenterChallengeManager()
    
    private let defaults = UserDefaults.standard
    private let challengesSentKey = "sf_challenges_sent_count"
    private let challengesReceivedKey = "sf_challenges_received_count"
    
    private init() {}
    
    // MARK: - Challenge Creation
    
    /// Creates a challenge message for a completed daily challenge
    /// - Parameters:
    ///   - challengeName: The name of the daily challenge
    ///   - time: The completion time in seconds
    ///   - date: The date of the challenge (defaults to today)
    /// - Returns: A formatted challenge message
    func createChallengeMessage(challengeName: String, time: TimeInterval, date: String? = nil) -> String {
        let timeString = formatTime(time)
        let dateStr = date ?? DailyChallenges.shared.getCurrentDate()
        
        let messages = [
            "I just crushed '\(challengeName)' in \(timeString)! Think you can beat me? 🐸",
            "Completed '\(challengeName)' in \(timeString)! Your turn! 💪",
            "Just set a time of \(timeString) on '\(challengeName)'! Can you do better? 🏆",
            "Beat '\(challengeName)' in \(timeString)! I dare you to try! 🎯"
        ]
        
        return messages.randomElement() ?? messages[0]
    }
    
    /// Formats a time interval into MM:SS.MS format
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    // MARK: - Challenge Sharing
    
    /// Creates a shareable text with challenge details
    /// - Parameters:
    ///   - challengeName: The name of the daily challenge
    ///   - time: The completion time in seconds
    /// - Returns: Full shareable text including app promotion
    func createShareableText(challengeName: String, time: TimeInterval) -> String {
        let message = createChallengeMessage(challengeName: challengeName, time: time)
        let deepLinkURL = createChallengeDeepLinkURL()
        return "\(message)\n\n\(deepLinkURL)"
    }
    
    /// Creates a deep link URL string (just the URL, no label text)
    /// - Parameter date: Optional specific challenge date (defaults to today)
    /// - Returns: Just the URL string
    func createChallengeDeepLinkURL(date: String? = nil) -> String {
        let challengeDate = date ?? DailyChallenges.shared.getCurrentDate()
        return "stuntfrog://challenge/\(challengeDate)"
    }
    
    /// Creates a deep link URL for the current daily challenge (legacy method)
    /// - Parameter date: Optional specific challenge date (defaults to today)
    /// - Returns: A URL string that opens the app to the challenge
    func createChallengeDeepLink(date: String? = nil) -> String {
        let url = createChallengeDeepLinkURL(date: date)
        return "Tap here to accept: \(url)"
    }
    
    /// Creates a universal link (if you have a website)
    /// This would require configuring Associated Domains in your app
    /// - Parameter date: Optional specific challenge date (defaults to today)
    /// - Returns: A universal link URL string
    func createUniversalLink(date: String? = nil) -> String {
        let challengeDate = date ?? DailyChallenges.shared.getCurrentDate()
        
        // Universal links work even if the app isn't installed
        // Format: https://stuntfrog.app/challenge/YYYY-MM-DD
        // Note: You'll need to set up Apple App Site Association file on your domain
        let universalLink = "https://stuntfrog.app/challenge/\(challengeDate)"
        
        return universalLink
    }
    
    // MARK: - Statistics
    
    /// Records that a challenge was sent
    func recordChallengeSent() {
        let count = getChallengesSentCount()
        defaults.set(count + 1, forKey: challengesSentKey)
        print("📤 Challenge sent (total: \(count + 1))")
    }
    
    /// Returns the total number of challenges sent by this player
    func getChallengesSentCount() -> Int {
        return defaults.integer(forKey: challengesSentKey)
    }
    
    /// Records that a challenge was received
    func recordChallengeReceived() {
        let count = getChallengesReceivedCount()
        defaults.set(count + 1, forKey: challengesReceivedKey)
        print("📥 Challenge received (total: \(count + 1))")
    }
    
    /// Returns the total number of challenges received by this player
    func getChallengesReceivedCount() -> Int {
        return defaults.integer(forKey: challengesReceivedKey)
    }
    
    // MARK: - Game Center Status
    
    /// Checks if Game Center is available and authenticated
    var isGameCenterAvailable: Bool {
        return GKLocalPlayer.local.isAuthenticated
    }
    
    /// Returns the local player's display name
    var localPlayerName: String? {
        return GKLocalPlayer.local.displayName
    }
    
    /// Returns the local player's Game Center ID
    var localPlayerID: String? {
        return GKLocalPlayer.local.gamePlayerID
    }
    
    // MARK: - Leaderboard Submission (Future Enhancement)
    
    /// Submits a daily challenge score to a Game Center leaderboard
    /// - Parameters:
    ///   - time: The completion time in seconds
    ///   - challengeDate: The date string for the challenge
    ///   - completion: Called with success/failure result
    func submitToLeaderboard(time: TimeInterval, challengeDate: String, completion: ((Bool, Error?) -> Void)? = nil) {
        guard isGameCenterAvailable else {
            print("❌ Game Center not available for leaderboard submission")
            completion?(false, NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Game Center not authenticated"]))
            return
        }
        
        // Create a unique leaderboard ID for each daily challenge
        // Format: com.yourapp.daily.YYYY-MM-DD
        // Update this in GameCenterChallengeManager.swift
        let leaderboardID = "com.stuntfrog.DailyChallenge"
        
        // Convert time to an integer score (milliseconds)
        // Lower scores are better for time-based challenges
        let scoreValue = Int(time * 1000)
        
        if #available(iOS 14.0, *) {
            GKLeaderboard.submitScore(
                scoreValue,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID]
            ) { error in
                if let error = error {
                    print("❌ Failed to submit score: \(error.localizedDescription)")
                    completion?(false, error)
                } else {
                    print("✅ Score submitted to leaderboard: \(leaderboardID)")
                    completion?(true, nil)
                }
            }
        } else {
            // Fallback for iOS 13
            let score = GKScore(leaderboardIdentifier: leaderboardID)
            score.value = Int64(scoreValue)
            
            GKScore.report([score]) { error in
                if let error = error {
                    print("❌ Failed to submit score: \(error.localizedDescription)")
                    completion?(false, error)
                } else {
                    print("✅ Score submitted to leaderboard: \(leaderboardID)")
                    completion?(true, nil)
                }
            }
        }
    }
    
    // MARK: - Friend Loading
    
    /// Loads the player's Game Center friends
    /// - Parameter completion: Called with array of friend players or error
    @available(iOS 14.0, *)
    func loadFriends(completion: @escaping ([GKPlayer]?, Error?) -> Void) {
        GKLocalPlayer.local.loadFriends { friends, error in
            if let error = error {
                print("❌ Failed to load friends: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let friendPlayers = friends as? [GKPlayer] else {
                completion([], nil)
                return
            }
            
            print("✅ Loaded \(friendPlayers.count) friends")
            completion(friendPlayers, nil)
        }
    }
    
    // MARK: - Challenge Validation
    
    /// Validates if a challenge can be sent
    /// - Returns: Tuple of (canSend, errorMessage)
    func validateChallengeEligibility() -> (canSend: Bool, errorMessage: String?) {
        guard isGameCenterAvailable else {
            return (false, "Please sign in to Game Center to challenge friends.")
        }
        
        // Could add additional validation here:
        // - Check if player has friends
        // - Check if challenge was already completed today
        // - Rate limiting (max challenges per day)
        
        return (true, nil)
    }
    
    // MARK: - Analytics
    
    /// Returns challenge statistics for display
    func getChallengeStats() -> (sent: Int, received: Int) {
        return (getChallengesSentCount(), getChallengesReceivedCount())
    }
    
    /// Resets all challenge statistics (for testing only)
    func resetStats() {
        defaults.removeObject(forKey: challengesSentKey)
        defaults.removeObject(forKey: challengesReceivedKey)
        print("🔄 Challenge statistics reset")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a challenge is successfully sent to a friend
    static let challengeSentToFriend = Notification.Name("challengeSentToFriend")
    
    /// Posted when a challenge is received from a friend
    static let challengeReceivedFromFriend = Notification.Name("challengeReceivedFromFriend")
}

// MARK: - Challenge Info

/// Data structure for tracking challenge information
struct ChallengeInfo: Codable {
    let challengeName: String
    let challengeDate: String
    let senderID: String
    let senderName: String
    let time: TimeInterval
    let timestamp: Date
    
    init(challengeName: String, challengeDate: String, senderID: String, senderName: String, time: TimeInterval) {
        self.challengeName = challengeName
        self.challengeDate = challengeDate
        self.senderID = senderID
        self.senderName = senderName
        self.time = time
        self.timestamp = Date()
    }
}
