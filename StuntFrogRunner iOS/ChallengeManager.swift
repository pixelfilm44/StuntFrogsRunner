import Foundation

import Foundation

/// Represents a single game challenge
struct Challenge: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let requirement: Int
    let reward: ChallengeReward
    let type: ChallengeType
    var progress: Int
    var isCompleted: Bool
    var isRewardClaimed: Bool
    
    var progressPercentage: Double {
        return min(1.0, Double(progress) / Double(requirement))
    }
    
    var progressText: String {
        if isCompleted {
            return "Completed!"
        }
        return "\(progress)/\(requirement)"
    }
}

/// Types of challenge rewards
enum ChallengeReward: Codable, Equatable {
    case coins(Int)
    case upgrade(String)
    case permanentHealth
    
    var displayText: String {
        switch self {
        case .coins(let amount):
            return "\(amount) Coins"
        case .upgrade(let name):
            return "Free \(name)"
        case .permanentHealth:
            return "+1 Max Health"
        }
    }
}

/// Types of challenges that can be tracked
enum ChallengeType: String, Codable {
    case totalScore           // Cumulative score across all runs
    case singleRunScore       // Highest score in a single run
    case totalCoins           // Total coins collected ever
    case coinsInRun           // Coins collected in a single run
    case enemiesDefeated      // Enemies defeated using buffs
    case gamesPlayed          // Total games played
    case useRocket            // Use rocket powerup X times
    case surviveWeather       // Survive specific weather types
    case landOnPads           // Land on X pads in a single run
    case consecutiveJumps     // X jumps without falling in water
    case crocodileRides       // Complete crocodile rides
    case winningStreak        // Win X races in a row
}

/// Manages all game challenges and persists progress
class ChallengeManager {
    static let shared = ChallengeManager()
    
    private let defaults = UserDefaults.standard
    private let challengesKey = "sf_challenges"
    private let statsKey = "sf_challenge_stats"
    
    private(set) var challenges: [Challenge] = []
    private(set) var stats: ChallengeStats
    

    private init() {
        stats = ChallengeStats()
        loadChallenges()
        loadStats()
    }
    
    // MARK: - Challenge Definitions
    
    private func createDefaultChallenges() -> [Challenge] {
        return [
            // Distance Challenges
            Challenge(
                id: "distance_100",
                title: "First Steps",
                description: "Travel 200m in a single run",
                requirement: 200,
                reward: .coins(50),
                type: .singleRunScore,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            Challenge(
                id: "distance_500",
                title: "Getting There",
                description: "Travel 1000m in a single run",
                requirement: 1000,
                reward: .coins(100),
                type: .singleRunScore,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            Challenge(
                id: "distance_5000",
                title: "Marathon Frog",
                description: "Travel 5000m in a single run",
                requirement: 5000,
                reward: .coins(300),
                type: .singleRunScore,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            Challenge(
                id: "distance_total_15000",
                title: "World Traveler",
                description: "Travel 15,000m total across all runs",
                requirement: 15000,
                reward: .coins(1500),
                type: .totalScore,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            
            // Coin Challenges
            Challenge(
                id: "coins_collect_50",
                title: "Coin Collector",
                description: "Collect 50 coins total",
                requirement: 50,
                reward: .coins(25),
                type: .totalCoins,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            Challenge(
                id: "coins_collect_200",
                title: "Treasure Hunter",
                description: "Collect 200 coins total",
                requirement: 200,
                reward: .coins(100),
                type: .totalCoins,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            Challenge(
                id: "coins_run_20",
                title: "Lucky Run",
                description: "Collect 20 coins in a single run",
                requirement: 20,
                reward: .coins(75),
                type: .coinsInRun,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            
            // Combat Challenges
            Challenge(
                id: "enemies_10",
                title: "Bug Swatter",
                description: "Defeat 10 enemies using items",
                requirement: 10,
                reward: .coins(100),
                type: .enemiesDefeated,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            Challenge(
                id: "enemies_50",
                title: "Exterminator",
                description: "Defeat 50 enemies using items",
                requirement: 50,
                reward: .coins(250),
                type: .enemiesDefeated,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            
            // Games Played Challenges
            Challenge(
                id: "games_10",
                title: "Regular Player",
                description: "Play 10 games",
                requirement: 10,
                reward: .coins(100),
                type: .gamesPlayed,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            Challenge(
                id: "games_50",
                title: "Dedicated Frog",
                description: "Play 50 games",
                requirement: 50,
                reward: .permanentHealth,
                type: .gamesPlayed,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            
            // Rocket Challenges
            Challenge(
                id: "rocket_5",
                title: "Rocket Rider",
                description: "Use rockets 5 times",
                requirement: 5,
                reward: .coins(100),
                type: .useRocket,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            
            // Pad Landing Challenges
            Challenge(
                id: "pads_50",
                title: "Hopper",
                description: "Land on 50 pads in a single run",
                requirement: 50,
                reward: .coins(150),
                type: .landOnPads,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            
            // Consecutive Jumps
            Challenge(
                id: "consecutive_20",
                title: "Perfect Balance",
                description: "Make 20 consecutive jumps without falling",
                requirement: 20,
                reward: .coins(200),
                type: .consecutiveJumps,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            
            // Crocodile Ride Challenges
            Challenge(
                id: "croc_ride_1",
                title: "Croc Surfer",
                description: "Complete your first crocodile ride",
                requirement: 1,
                reward: .coins(100),
                type: .crocodileRides,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            Challenge(
                id: "croc_ride_5",
                title: "Reptile Wrangler",
                description: "Complete 5 crocodile rides",
                requirement: 5,
                reward: .coins(250),
                type: .crocodileRides,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),
            Challenge(
                id: "croc_ride_15",
                title: "Crocodile Dundee",
                description: "Complete 15 crocodile rides",
                requirement: 15,
                reward: .coins(500),
                type: .crocodileRides,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            ),

            // Winning Streak Challenges
            Challenge(
                id: "winning_streak_3",
                title: "On a Roll",
                description: "Win 3 races in a row",
                requirement: 3,
                reward: .coins(500),
                type: .winningStreak,
                progress: 0,
                isCompleted: false,
                isRewardClaimed: false
            )
        ]
    }
    
    // MARK: - Persistence
    
    private func loadChallenges() {
        if let data = defaults.data(forKey: challengesKey),
           let saved = try? JSONDecoder().decode([Challenge].self, from: data) {
            challenges = saved
            
            // Merge with any new challenges that might have been added
            let defaultChallenges = createDefaultChallenges()
            let existingIds = Set(challenges.map { $0.id })
            
            for defaultChallenge in defaultChallenges {
                if !existingIds.contains(defaultChallenge.id) {
                    challenges.append(defaultChallenge)
                }
            }
        } else {
            challenges = createDefaultChallenges()
        }
        saveChallenges()
    }
    
    private func saveChallenges() {
        if let data = try? JSONEncoder().encode(challenges) {
            defaults.set(data, forKey: challengesKey)
        }
    }
    
    private func loadStats() {
        if let data = defaults.data(forKey: statsKey),
           let saved = try? JSONDecoder().decode(ChallengeStats.self, from: data) {
            stats = saved
        }
    }
    
    private func saveStats() {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: statsKey)
        }
    }
    
    // MARK: - Progress Tracking

 
    
    /// Call when a game ends to update challenge progress
    func recordGameEnd(score: Int, coinsCollected: Int, padsLanded: Int, consecutiveJumps: Int, consecutiveRaces: Int) {
        stats.totalScore += score
        stats.totalCoins += coinsCollected
        stats.gamesPlayed += 1
        
        // Update best records
        if score > stats.bestSingleRunScore {
            stats.bestSingleRunScore = score
        }
        if coinsCollected > stats.bestCoinsInRun {
            stats.bestCoinsInRun = coinsCollected
        }
        if padsLanded > stats.bestPadsInRun {
            stats.bestPadsInRun = padsLanded
        }
        if consecutiveJumps > stats.bestConsecutiveJumps {
            stats.bestConsecutiveJumps = consecutiveJumps
        }
        if consecutiveRaces > stats.bestConsecutiveRaces {
            stats.bestConsecutiveRaces = consecutiveRaces
        }
        
        saveStats()
        updateAllChallenges()
    }
    
    /// Call when an enemy is defeated
    func recordEnemyDefeated() {
        stats.enemiesDefeated += 1
        // Note: Don't save to disk here for performance - stats are saved on game end
        updateChallenges(ofType: .enemiesDefeated)
    }
    
    /// Call when rocket is used
    func recordRocketUsed() {
        stats.rocketsUsed += 1
        // Note: Don't save to disk here for performance - stats are saved on game end
        updateChallenges(ofType: .useRocket)
    }
    
    /// Call when a crocodile ride is successfully completed
    func recordCrocodileRideCompleted() {
        stats.crocodileRidesCompleted += 1
        // Note: Don't save to disk here for performance - stats are saved on game end
        updateChallenges(ofType: .crocodileRides)
    }
    
    /// Call when landing on a pad (real-time tracking)
    func recordPadLanded(totalThisRun: Int) {
        if totalThisRun > stats.bestPadsInRun {
            stats.bestPadsInRun = totalThisRun
            updateChallenges(ofType: .landOnPads)
        }
    }
    
    /// Call when making consecutive jumps (real-time tracking)
    func recordConsecutiveJumps(count: Int) {
        if count > stats.bestConsecutiveJumps {
            stats.bestConsecutiveJumps = count
            updateChallenges(ofType: .consecutiveJumps)
        }
    }
    
    /// Call when collecting coins (real-time tracking)
    func recordCoinsCollected(totalThisRun: Int, totalOverall: Int) {
        var updated = false
        if totalThisRun > stats.bestCoinsInRun {
            stats.bestCoinsInRun = totalThisRun
            updated = true
        }
        stats.totalCoins = totalOverall
        if updated {
            updateChallenges(ofType: .coinsInRun)
        }
        updateChallenges(ofType: .totalCoins)
    }
    
    /// Call when score increases (real-time tracking)
    func recordScoreUpdate(currentScore: Int) {
        if currentScore > stats.bestSingleRunScore {
            stats.bestSingleRunScore = currentScore
            updateChallenges(ofType: .singleRunScore)
        }
    }
    
    /// Sets the current winning streak and updates relevant challenges.
    /// Call this when a race ends (win or lose) or when the streak should be reset.
    func setWinningStreak(_ streak: Int) {
        stats.currentWinningStreak = streak
        
        // Update the all-time best streak if this one is better.
        if streak > stats.bestConsecutiveRaces {
            stats.bestConsecutiveRaces = streak
        }
        
        // Saving and updating challenges ensures the UI and progress are consistent.
        saveStats()
        updateChallenges(ofType: .winningStreak)
    }
    
    private func updateAllChallenges() {
        for i in challenges.indices {
            updateChallengeProgress(at: i)
        }
        saveChallenges()
    }
    
    private func updateChallenges(ofType type: ChallengeType) {
        for i in challenges.indices where challenges[i].type == type {
            updateChallengeProgress(at: i)
        }
        saveChallenges()
    }
    
    private func updateChallengeProgress(at index: Int) {
        guard !challenges[index].isCompleted else { return }
        
        let newProgress: Int
        switch challenges[index].type {
        case .totalScore:
            newProgress = stats.totalScore
        case .singleRunScore:
            newProgress = stats.bestSingleRunScore
        case .totalCoins:
            newProgress = stats.totalCoins
        case .coinsInRun:
            newProgress = stats.bestCoinsInRun
        case .enemiesDefeated:
            newProgress = stats.enemiesDefeated
        case .gamesPlayed:
            newProgress = stats.gamesPlayed
        case .useRocket:
            newProgress = stats.rocketsUsed
        case .surviveWeather:
            newProgress = stats.weathersSurvived
        case .landOnPads:
            newProgress = stats.bestPadsInRun
        case .consecutiveJumps:
            newProgress = stats.bestConsecutiveJumps
        case .crocodileRides:
            newProgress = stats.crocodileRidesCompleted
        case .winningStreak:
            newProgress = stats.currentWinningStreak
        }
        
        challenges[index].progress = newProgress
        
        if newProgress >= challenges[index].requirement {
            challenges[index].isCompleted = true
            // Broadcast achievement completion
            NotificationCenter.default.post(
                name: .challengeCompleted,
                object: nil,
                userInfo: ["challenge": challenges[index]]
            )
        }
    }
    
    // MARK: - Rewards
    
    /// Claims the reward for a completed challenge
    /// Returns true if reward was successfully claimed
    func claimReward(for challengeId: String) -> Bool {
        guard let index = challenges.firstIndex(where: { $0.id == challengeId }),
              challenges[index].isCompleted,
              !challenges[index].isRewardClaimed else {
            return false
        }
        
        // Grant the reward
        switch challenges[index].reward {
        case .coins(let amount):
            PersistenceManager.shared.addCoins(amount)
        case .upgrade:
            // Upgrades are granted as one-time items at game start
            // Store in UserDefaults for next game
            var pendingUpgrades = defaults.stringArray(forKey: "sf_pending_upgrades") ?? []
            if case .upgrade(let upgradeId) = challenges[index].reward {
                pendingUpgrades.append(upgradeId)
                defaults.set(pendingUpgrades, forKey: "sf_pending_upgrades")
            }
        case .permanentHealth:
            PersistenceManager.shared.upgradeHealth()
        }
        
        challenges[index].isRewardClaimed = true
        saveChallenges()
        return true
    }
    
    /// Returns any pending upgrade rewards and clears them
    func consumePendingUpgrades() -> [String] {
        let pending = defaults.stringArray(forKey: "sf_pending_upgrades") ?? []
        defaults.removeObject(forKey: "sf_pending_upgrades")
        return pending
    }
    
    // MARK: - Queries
    
    var unclaimedChallengesCount: Int {
        return challenges.filter { $0.isCompleted && !$0.isRewardClaimed }.count
    }
    
    var completedChallenges: [Challenge] {
        return challenges.filter { $0.isCompleted }
    }
    
    var inProgressChallenges: [Challenge] {
        return challenges.filter { !$0.isCompleted }
    }
    
    // MARK: - Debug
    
    func resetAllChallenges() {
        challenges = createDefaultChallenges()
        stats = ChallengeStats()
        saveChallenges()
        saveStats()
    }
}

/// Tracks cumulative statistics for challenge progress
struct ChallengeStats: Codable {
    var totalScore: Int = 0
    var bestSingleRunScore: Int = 0
    var totalCoins: Int = 0
    var bestCoinsInRun: Int = 0
    var enemiesDefeated: Int = 0
    var gamesPlayed: Int = 0
    var rocketsUsed: Int = 0
    var weathersSurvived: Int = 0
    var bestPadsInRun: Int = 0
    var bestConsecutiveJumps: Int = 0
    var bestConsecutiveRaces: Int = 0
    var crocodileRidesCompleted: Int = 0
    var currentWinningStreak: Int = 0
}
