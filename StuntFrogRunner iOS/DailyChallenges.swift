import Foundation

// MARK: - Daily Challenges System
//
// This system manages daily challenges loaded from Google Sheets CSV.
//
// KEY FEATURES:
// - Automatically uses TODAY'S DATE by default
// - Fetches challenges from remote CSV (cached locally)
// - Falls back to procedurally generated challenges if remote data is missing
// - Supports test mode with nextDay()/prevDay() for testing future/past challenges
// - Auto-resets to today on app launch to prevent stuck dates
//
// USAGE:
//   let challenge = DailyChallenges.shared.getTodaysChallenge()
//
// TESTING:
//   DailyChallenges.shared.nextDay()  // Test tomorrow's challenge
//   DailyChallenges.shared.prevDay()  // Test yesterday's challenge
//   DailyChallenges.shared.resetToToday()  // Go back to today

// MARK: - Models

/// Represents a daily challenge configuration
struct DailyChallenge: Codable, Equatable {
    let date: String // Format: "yyyy-MM-dd"
    let seed: Int // Used for random generation consistency
    let climate: WeatherType
    let focusEnemyTypes: [EnemyFocusType]
    let focusPadTypes: [PadFocusType]
    let name: String
    let description: String
    
    enum EnemyFocusType: String, Codable {
        case bee
        case dragonfly
        case snake
        case crocodile
        case mixed
    }
    
    enum PadFocusType: String, Codable {
        case moving
        case shrinking
        case ice
        case normal
        case mixed
    }
}

/// Stores a player's performance on a daily challenge
struct DailyChallengeResult: Codable {
    let date: String
    var bestTime: TimeInterval
    var attempts: Int
    var completed: Bool
}

// MARK: - Manager Class

/// Manages daily challenge generation, persistence, and leaderboards
class DailyChallenges {
    static let shared = DailyChallenges()
    
    private let defaults = UserDefaults.standard
    private let resultsKey = "sf_daily_challenge_results"
    private let currentOffsetKey = "sf_daily_challenge_offset"
    private let cachedScheduleKey = "sf_daily_challenge_cached_schedule"
    private let lastFetchDateKey = "sf_daily_challenge_last_fetch_date"
    
    // 👇 PASTE YOUR GOOGLE SHEET CSV LINK HERE 👇
    private let challengeManifestURL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vQhxG1FChHjNlHuq6QlcBjacW_6veP8aoDeGCffjcXCYLNWpGIbqVWRTK9YT6jyF39JiI7nXkBuKTTn/pub?gid=0&single=true&output=csv"
    
    // Cache for loaded challenges: [DateString : Challenge]
    private var remoteSchedule: [String: DailyChallenge] = [:]
    
    // Track last fetch date to avoid excessive network calls
    private var lastFetchDate: String?
    
    // Flag to prevent simultaneous fetches
    private var isFetching: Bool = false
    
    // Testing offset for simulating different days
    private(set) var dayOffset: Int = 0
    
    private init() {
        // Load any previously set offset (defaults to 0 for normal use)
        dayOffset = defaults.integer(forKey: currentOffsetKey)
        
        // Optional: Auto-reset offset on app launch to ensure we use today's date
        // Comment this out if you want the offset to persist between launches
        if dayOffset != 0 {
            print("⚠️ Found test offset (\(dayOffset)), resetting to today's date")
            dayOffset = 0
            defaults.set(0, forKey: currentOffsetKey)
        }
        
        // Load cached schedule from disk
        loadCachedSchedule()
        
        // Load last fetch date
        lastFetchDate = defaults.string(forKey: lastFetchDateKey)
    }
    
    // MARK: - Network Fetching
    
    /// Fetches the challenge schedule from Google Sheets
    func fetchDailyChallenges(completion: @escaping (Bool) -> Void) {
        // Prevent duplicate simultaneous fetches
        guard !isFetching else {
            print("⚠️ Already fetching daily challenges, skipping duplicate request")
            completion(false)
            return
        }
        
        guard let url = URL(string: challengeManifestURL) else {
            completion(false)
            return
        }
        
        isFetching = true
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            // Always reset the fetching flag when done
            defer {
                self.isFetching = false
            }
            
            guard let data = data, error == nil else {
                print("⚠️ Failed to fetch daily challenges: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            if let content = String(data: data, encoding: .utf8) {
                self.parseCSV(content)
                self.lastFetchDate = self.getCurrentDateString()
                
                // Save to cache
                self.saveCachedSchedule()
                self.defaults.set(self.lastFetchDate, forKey: self.lastFetchDateKey)
                
                print("✅ Successfully loaded \(self.remoteSchedule.count) challenges from remote.")
                
                DispatchQueue.main.async {
                    completion(true)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
        task.resume()
    }
    
    /// Refreshes challenges if we haven't fetched today yet
    func refreshIfNeeded(completion: ((Bool) -> Void)? = nil) {
        let today = getCurrentDateString()
        
        // If we have cached data and already fetched today, no need to fetch again
        if lastFetchDate == today && !remoteSchedule.isEmpty {
            print("✅ Daily challenges already loaded for today (\(remoteSchedule.count) challenges)")
            completion?(true)
            return
        }
        
        // New day detected or no cached data - fetch from remote
        print("📅 New day detected or no cache, refreshing daily challenges...")
        fetchDailyChallenges { success in
            completion?(success)
        }
    }
    
    private func parseCSV(_ content: String) {
        let rows = content.components(separatedBy: "\n")
        var newSchedule: [String: DailyChallenge] = [:]
        
        // Skip header row (index 0)
        for i in 1..<rows.count {
            let row = rows[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if row.isEmpty { continue }
            
            // basic CSV parsing
            let columns = row.components(separatedBy: ",")
            
            if columns.count >= 7 {
                let dateStr = columns[0].trimmingCharacters(in: .whitespaces)
                let name = columns[1].replacingOccurrences(of: "\"", with: "")
                let desc = columns[2].replacingOccurrences(of: "\"", with: "")
                let climateStr = columns[3].trimmingCharacters(in: .whitespaces).lowercased()
                let enemyStr = columns[4].trimmingCharacters(in: .whitespaces)
                let padStr = columns[5].trimmingCharacters(in: .whitespaces)
                let seedStr = columns[6].trimmingCharacters(in: .whitespaces)
                
                // Parsing Enums & Arrays (Splitting by | for multiple items)
                let climate = WeatherType(rawValue: climateStr) ?? .sunny
                
                let enemies: [DailyChallenge.EnemyFocusType] = enemyStr.components(separatedBy: "|").compactMap {
                    DailyChallenge.EnemyFocusType(rawValue: $0.trimmingCharacters(in: .whitespaces))
                }
                
                let pads: [DailyChallenge.PadFocusType] = padStr.components(separatedBy: "|").compactMap {
                    DailyChallenge.PadFocusType(rawValue: $0.trimmingCharacters(in: .whitespaces))
                }
                
                let seed = Int(seedStr) ?? dateStr.hashValue
                
                let challenge = DailyChallenge(
                    date: dateStr,
                    seed: seed,
                    climate: climate,
                    focusEnemyTypes: enemies.isEmpty ? [.mixed] : enemies,
                    focusPadTypes: pads.isEmpty ? [.mixed] : pads,
                    name: name,
                    description: desc
                )
                
                newSchedule[dateStr] = challenge
            }
        }
        
        self.remoteSchedule = newSchedule
    }
    
    // MARK: - Persistence
    
    private func saveCachedSchedule() {
        if let data = try? JSONEncoder().encode(remoteSchedule) {
            defaults.set(data, forKey: cachedScheduleKey)
            print("💾 Cached \(remoteSchedule.count) challenges to disk")
        }
    }
    
    private func loadCachedSchedule() {
        guard let data = defaults.data(forKey: cachedScheduleKey),
              let cached = try? JSONDecoder().decode([String: DailyChallenge].self, from: data) else {
            print("ℹ️ No cached challenges found")
            return
        }
        
        remoteSchedule = cached
        print("💾 Loaded \(cached.count) cached challenges from disk")
    }
    
    // MARK: - Day Offset Management (For Testing Only)
    
    /// Advances to the next day (for testing future challenges)
    func nextDay() {
        dayOffset += 1
        defaults.set(dayOffset, forKey: currentOffsetKey)
        print("🧪 Advanced to day offset: \(dayOffset) (Testing Mode)")
        NotificationCenter.default.post(name: Notification.Name("DailyChallengeUpdated"), object: nil)
    }
    
    /// Goes back to the previous day (for testing past challenges)
    func prevDay() {
        dayOffset -= 1
        defaults.set(dayOffset, forKey: currentOffsetKey)
        print("🧪 Went back to day offset: \(dayOffset) (Testing Mode)")
        NotificationCenter.default.post(name: Notification.Name("DailyChallengeUpdated"), object: nil)
    }
    
    /// Resets to today's actual date (disables testing mode)
    func resetToToday() {
        if dayOffset != 0 {
            dayOffset = 0
            defaults.set(dayOffset, forKey: currentOffsetKey)
            print("✅ Reset to today's date (Disabled Testing Mode)")
            NotificationCenter.default.post(name: Notification.Name("DailyChallengeUpdated"), object: nil)
        } else {
            print("ℹ️ Already using today's date")
        }
    }
    
    /// Returns true if currently using a test offset
    func isUsingTestOffset() -> Bool {
        return dayOffset != 0
    }
    
    // MARK: - Challenge Retrieval
    
    private func getCurrentDateString() -> String {
        let today = Date()
        
        // Apply offset only if explicitly set (for testing)
        if dayOffset != 0 {
            let calendar = Calendar.current
            if let adjustedDate = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                print("🧪 Using test offset: \(dayOffset) days -> \(dateString(from: adjustedDate))")
                return dateString(from: adjustedDate)
            }
        }
        
        return dateString(from: today)
    }
    
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    /// Gets today's daily challenge (Checks remote first, then falls back to local)
    func getTodaysChallenge() -> DailyChallenge {
        let dateStr = getCurrentDateString()
        let actualToday = getTodaysActualDate()
        
        // 1. Check if we have a Google Sheet configuration for this day
        if let remoteChallenge = remoteSchedule[dateStr] {
            if dateStr != actualToday {
                print("✅ Using REMOTE challenge for \(dateStr) (Test Mode - actual date: \(actualToday)): \(remoteChallenge.name)")
            } else {
                print("✅ Using REMOTE challenge for \(dateStr): \(remoteChallenge.name)")
            }
            return remoteChallenge
        }
        
        // 2. Fallback: Generate one locally so the game never breaks
        print("⚠️ No remote challenge found for \(dateStr), using FALLBACK generation")
        return generateFallbackChallenge(for: dateStr)
    }
    
    /// Generates a consistent local challenge if remote data is missing
    private func generateFallbackChallenge(for dateStr: String) -> DailyChallenge {
        // Use the date string to create a consistent seed
        let seed = dateStr.hashValue
        var generator = SeededRandomNumberGenerator(seed: UInt64(abs(seed)))
        
        // Randomly select a climate
        let availableClimates: [WeatherType] = [.sunny, .night, .rain, .winter]
        let climate = availableClimates.randomElement(using: &generator) ?? .sunny
        
        // Select enemy focus
        let enemyFocus: [DailyChallenge.EnemyFocusType]
        if Bool.random(using: &generator) {
            let singleEnemy = [DailyChallenge.EnemyFocusType.bee, .dragonfly].randomElement(using: &generator) ?? .bee
            enemyFocus = [singleEnemy]
        } else {
            enemyFocus = [.mixed]
        }
        
        // Select pad focus
        let padFocus: [DailyChallenge.PadFocusType]
        let focusRoll = Double.random(in: 0...1, using: &generator)
        if focusRoll < 0.30 {
            let availablePadTypes: [DailyChallenge.PadFocusType] = [.moving, .shrinking, .ice, .normal]
            let singlePad = availablePadTypes.randomElement(using: &generator) ?? .normal
            padFocus = [singlePad]
        } else {
            padFocus = [.mixed]
        }
        
        // Generate name/description
        let (name, description) = generateNameAndDescription(
            climate: climate,
            enemies: enemyFocus,
            pads: padFocus,
            using: &generator
        )
        
        return DailyChallenge(
            date: dateStr,
            seed: seed,
            climate: climate,
            focusEnemyTypes: enemyFocus,
            focusPadTypes: padFocus,
            name: name,
            description: description
        )
    }
    
    private func generateNameAndDescription(
        climate: WeatherType,
        enemies: [DailyChallenge.EnemyFocusType],
        pads: [DailyChallenge.PadFocusType],
        using generator: inout SeededRandomNumberGenerator
    ) -> (name: String, description: String) {
        
        var name = ""
        var description = ""
        
        if enemies.contains(.bee) {
            let beeNames = ["Bee Bonanza", "Swarm Survival", "Buzzing Madness", "Bee Invasion"]
            name = beeNames.randomElement(using: &generator) ?? "Bee Challenge"
            description = "Bees everywhere! Watch out for the swarm!"
        } else if enemies.contains(.dragonfly) {
            let dragonflyNames = ["Dragonfly Dash", "Wings of Fury", "Aerial Assault", "Sky Hunters"]
            name = dragonflyNames.randomElement(using: &generator) ?? "Dragonfly Challenge"
            description = "Fast and fierce dragonflies dominate the skies!"
        } else {
            let mixedNames = ["Chaos Run", "Mixed Mayhem", "Survival Sprint", "Gauntlet Run"]
            name = mixedNames.randomElement(using: &generator) ?? "Mixed Challenge"
            description = "A variety of threats await!"
        }
        
        if pads.contains(.moving) {
            name = "Moving " + name
            description += " And the pads won't stay still!"
        } else if pads.contains(.shrinking) {
            name = "Shrinking " + name
            description += " Pads are disappearing fast!"
        } else if pads.contains(.ice) {
            name = "Slippery " + name
            description += " Ice pads make movement treacherous!"
        }
        
        let climatePrefix: String
        switch climate {
        case .sunny: climatePrefix = "Sunny"
        case .night: climatePrefix = "Midnight"
        case .rain: climatePrefix = "Rainy"
        case .winter: climatePrefix = "Frozen"
        case .desert: climatePrefix = "Desert"
        case .space: climatePrefix = "Space"
        }
        
        name = "\(climatePrefix) \(name)"
        return (name, description)
    }
    
    // MARK: - Challenge Results
    
    func recordRun(timeInSeconds: TimeInterval, completed: Bool) {
        let dateStr = getCurrentDateString()
        var result = getResult(for: dateStr)
        
        result.attempts += 1
        if completed {
            let wasAlreadyCompleted = result.completed
            result.completed = true
            
            if timeInSeconds < result.bestTime || result.bestTime == 0 {
                result.bestTime = timeInSeconds
                print("🏆 New daily challenge best time: \(String(format: "%.1f", timeInSeconds))s")
            }
            
            if !wasAlreadyCompleted {
                let coinReward = 100
                PersistenceManager.shared.addCoins(coinReward)
                print("💰 Earned \(coinReward) coins for completing daily challenge!")
                
                NotificationCenter.default.post(
                    name: .dailyChallengeCompleted,
                    object: nil,
                    userInfo: ["time": timeInSeconds, "date": dateStr, "coinReward": coinReward]
                )
            }
        }
        
        saveResult(result, for: dateStr)
    }
    
    private func getResult(for dateStr: String) -> DailyChallengeResult {
        guard let data = defaults.data(forKey: resultsKey),
              let allResults = try? JSONDecoder().decode([String: DailyChallengeResult].self, from: data),
              let result = allResults[dateStr] else {
            return DailyChallengeResult(date: dateStr, bestTime: 0, attempts: 0, completed: false)
        }
        return result
    }
    
    private func saveResult(_ result: DailyChallengeResult, for dateStr: String) {
        var allResults: [String: DailyChallengeResult] = [:]
        
        if let data = defaults.data(forKey: resultsKey),
           let existing = try? JSONDecoder().decode([String: DailyChallengeResult].self, from: data) {
            allResults = existing
        }
        
        allResults[dateStr] = result
        
        if let data = try? JSONEncoder().encode(allResults) {
            defaults.set(data, forKey: resultsKey)
        }
    }
    
    func getTodaysBestTime() -> TimeInterval {
        let dateStr = getCurrentDateString()
        let result = getResult(for: dateStr)
        return result.completed ? result.bestTime : 0
    }
    
    func getTodaysAttempts() -> Int {
        let dateStr = getCurrentDateString()
        return getResult(for: dateStr).attempts
    }
    
    func hasCompletedToday() -> Bool {
        let dateStr = getCurrentDateString()
        return getResult(for: dateStr).completed
    }
    
    func getAllResults() -> [DailyChallengeResult] {
        guard let data = defaults.data(forKey: resultsKey),
              let allResults = try? JSONDecoder().decode([String: DailyChallengeResult].self, from: data) else {
            return []
        }
        return allResults.values.sorted { $0.date > $1.date }
    }
    
    // MARK: - Challenge Configuration Helpers
    
    func getEnemySpawnProbability(for challenge: DailyChallenge, distance: Int) -> Double {
        let distanceProgress = min(1.0, Double(distance) / 1000.0)
        let baseProb = 0.10 + (distanceProgress * 0.30)
        
        if challenge.focusEnemyTypes.contains(.bee) || challenge.focusEnemyTypes.contains(.dragonfly) {
            return baseProb * 18.5  // Tripled from 7.5 to 22.5
        }
        return baseProb * 7.0  // Tripled from 3.0 to 9.0
    }
    
    func getPadSpawnProbability(for padType: DailyChallenge.PadFocusType, in challenge: DailyChallenge) -> Double {
        if challenge.focusPadTypes.contains(padType) {
            return 0.80
        } else if challenge.focusPadTypes.contains(.mixed) {
            return 0.20
        }
        return 0.05
    }
    
    func shouldSpawnEnemyType(_ enemyType: DailyChallenge.EnemyFocusType, in challenge: DailyChallenge) -> Bool {
        if challenge.focusEnemyTypes.contains(enemyType) {
            return true
        }
        if challenge.focusEnemyTypes.contains(.mixed) {
            return true
        }
        return false
    }
    
    // MARK: - Upgrade Filtering
    
    func getRelevantUpgradeIDs(for challenge: DailyChallenge) -> [String] {
        var relevantUpgrades: [String] = []
        
        // Universal upgrades that are always useful
        let evergreenUpgrades = ["HEART", "HEARTBOOST", "VEST", "SUPERJUMP", "CANNONBALL"]
        relevantUpgrades.append(contentsOf: evergreenUpgrades)
        
        // Rocket is only useful if not in a climate that prevents flying (always allowed for challenges)
        relevantUpgrades.append("ROCKET")
        
        // Enemy-specific upgrades
        if shouldSpawnEnemyType(.bee, in: challenge) {
            relevantUpgrades.append("HONEY")
        }
        
        if shouldSpawnEnemyType(.dragonfly, in: challenge) {
            relevantUpgrades.append("SWATTER")
        }
        
        // Cross only works against ghosts, which only spawn at night
        if challenge.climate == .night {
            relevantUpgrades.append("CROSS")
        }
        
        // Boots prevent sliding on ice/rain
        if challenge.focusPadTypes.contains(.ice) || challenge.climate == .rain || challenge.climate == .winter {
            relevantUpgrades.append("BOOTS")
        }
        
        // Axe chops logs (natural weathers) and cacti (desert)
        // Only exclude from space where neither spawn
        if challenge.climate != .space {
            relevantUpgrades.append("AXE")
        }
        
        // Legendary permanent upgrades (only if base upgrade is unlocked)
        // These are checked separately in UpgradeViewController
        relevantUpgrades.append("DOUBLESUPERJUMPTIME")
        relevantUpgrades.append("DOUBLEROCKETTIME")
        
        return relevantUpgrades
    }
    
    func isUpgradeRelevant(_ upgradeID: String, for challenge: DailyChallenge) -> Bool {
        return getRelevantUpgradeIDs(for: challenge).contains(upgradeID)
    }
    
    // MARK: - Debug Helpers
    
    /// Returns the number of challenges loaded from remote
    func getLoadedChallengeCount() -> Int {
        return remoteSchedule.count
    }
    
    /// Returns all loaded challenge dates (for debugging)
    func getLoadedChallengeDates() -> [String] {
        return remoteSchedule.keys.sorted()
    }
    
    /// Check if a specific date has a remote challenge
    func hasRemoteChallenge(for date: String) -> Bool {
        return remoteSchedule[date] != nil
    }
    
    /// Get the challenge source (remote vs fallback)
    func getChallengeSource() -> String {
        let dateStr = getCurrentDateString()
        return remoteSchedule[dateStr] != nil ? "Remote CSV" : "Local Fallback"
    }
    
    /// Get the current date string being used (useful for debugging)
    func getCurrentDate() -> String {
        return getCurrentDateString()
    }
    
    /// Get the actual today's date (without offset)
    func getTodaysActualDate() -> String {
        return dateString(from: Date())
    }
}

// MARK: - Seeded Random Number Generator

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dailyChallengeCompleted = Notification.Name("dailyChallengeCompleted")
}
