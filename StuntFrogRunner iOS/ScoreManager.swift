//
//  ScoreManager.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//

//
//  ScoreManager.swift
//  StuntFrog Runner
//
//  Manages score and high score

import Foundation
import GameKit

class ScoreManager {
    // MARK: - Shared Instance
    static let shared = ScoreManager()
    
    // MARK: - Properties
    var score: Int = 0 {
        didSet {
            onScoreChanged?(score)
            
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "HighScore")
                onHighScoreAchieved?(highScore)
                submitHighScoreToGameCenter(highScore)
            }
        }
    }
    
    // Level progression scoring
    private var sessionStartScore: Int = 0  // Score at the beginning of current session
    private var currentLevel: Int = 1
    private var levelsCompletedThisSession: Int = 0
    private var maxCompletedLevel: Int = 0  // Highest level ever completed
    
    var highScore: Int {
        didSet {
            onHighScoreChanged?(highScore)
        }
    }
    
    // MARK: - Callbacks
    var onScoreChanged: ((Int) -> Void)?
    var onHighScoreChanged: ((Int) -> Void)?
    var onHighScoreAchieved: ((Int) -> Void)?
    var onLevelProgressed: ((Int) -> Void)?  // Called when level advances
    
    // MARK: - Game Center
    /// Authenticate the local player for Game Center. Call this once early in app launch.
    func authenticateGameCenter(presentingViewControllerProvider: @escaping () -> UIViewController?) {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                // Present the Game Center login if needed
                presentingViewControllerProvider()?.present(viewController, animated: true)
            } else if let error = error {
                print("Game Center authentication failed: \(error.localizedDescription)")
            } else {
                print("Game Center authentication status: \(localPlayer.isAuthenticated ? "authenticated" : "not authenticated")")
            }
        }
    }

    /// Submit a score to the Game Center leaderboard with identifier "TopScores".
    func submitHighScoreToGameCenter(_ value: Int) {
        guard GKLocalPlayer.local.isAuthenticated else {
            print("Game Center: Local player not authenticated; skipping score submit.")
            return
        }
        let scoreReporter = GKScore(leaderboardIdentifier: "TopScores")
        scoreReporter.value = Int64(value)
        GKScore.report([scoreReporter]) { error in
            if let error = error {
                print("Failed to submit score to Game Center: \(error.localizedDescription)")
            } else {
                print("Successfully submitted score \(value) to Game Center leaderboard 'TopScores'.")
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        self.highScore = UserDefaults.standard.integer(forKey: "HighScore")
        
        // Load persistent level progression data
        self.maxCompletedLevel = UserDefaults.standard.integer(forKey: "MaxCompletedLevel")
        
        if GameConfig.enableScoreCarryover {
            self.currentLevel = max(1, UserDefaults.standard.integer(forKey: "CurrentLevel"))
            self.score = UserDefaults.standard.integer(forKey: "PersistentScore")
            self.sessionStartScore = score
            print("🎮 ScoreManager: Loaded persistent data - Level \(currentLevel), Score \(score)")
        } else {
            self.currentLevel = 1
            self.score = 0
            self.sessionStartScore = 0
        }
        
        print("🎮 ScoreManager: Max completed level = \(maxCompletedLevel)")
    }
    
    // MARK: - Score Management
    func addScore(_ points: Int) {
        score += points
        savePersistentData()
    }
    
    func resetScore() {
        // Only reset when starting a completely new game
        if GameConfig.enableScoreCarryover {
            print("🎮 ScoreManager: Starting new game - resetting all progress")
        }
        
        score = 0
        currentLevel = 1
        levelsCompletedThisSession = 0
        sessionStartScore = 0
        
        // Clear persistent data but keep max completed level
        UserDefaults.standard.removeObject(forKey: "CurrentLevel")
        UserDefaults.standard.removeObject(forKey: "PersistentScore")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Level Progression
    func getCurrentLevel() -> Int {
        return currentLevel
    }
    
    func completeLevel() {
        if GameConfig.enableScoreCarryover {
            currentLevel += 1
            levelsCompletedThisSession += 1
            
            // Update max completed level
            maxCompletedLevel = max(maxCompletedLevel, currentLevel - 1)
            
            // Award level completion bonus
            let bonus = GameConfig.levelCompletionBonus
            score += bonus
            
            print("🎮 ScoreManager: Level \(currentLevel - 1) completed!")
            print("🎮 Level completion bonus: +\(bonus) points")
            print("🎮 Advanced to Level \(currentLevel)")
            print("🎮 Max completed level: \(maxCompletedLevel)")
            print("🎮 Total score: \(score)")
            
            // Save progress
            savePersistentData()
            
            // Notify listeners
            onLevelProgressed?(currentLevel)
        }
    }
    
    func restartCurrentLevel() {
        // Reset score to the start of this session, but keep level progress
        if GameConfig.enableScoreCarryover {
            score = sessionStartScore
            print("🎮 ScoreManager: Restarting Level \(currentLevel) - score reset to session start: \(sessionStartScore)")
            savePersistentData()
        } else {
            resetScore()
        }
    }
    
    private func savePersistentData() {
        if GameConfig.enableScoreCarryover {
            UserDefaults.standard.set(currentLevel, forKey: "CurrentLevel")
            UserDefaults.standard.set(score, forKey: "PersistentScore")
            UserDefaults.standard.set(maxCompletedLevel, forKey: "MaxCompletedLevel")
            UserDefaults.standard.synchronize()
        }
    }
    
    func isHighScore() -> Bool {
        return score > highScore
    }
    
    // MARK: - Level Management
    
    /// Get the highest level ever completed by the player
    func getMaxCompletedLevel() -> Int {
        return maxCompletedLevel
    }
    
    /// Check if the player should continue from their last level or start fresh
    func shouldContinueFromLastLevel() -> Bool {
        return GameConfig.enableScoreCarryover && maxCompletedLevel > 0
    }
    
    /// Get the recommended starting level (either 1 for new players, or last completed + 1)
    func getRecommendedStartingLevel() -> Int {
        if shouldContinueFromLastLevel() {
            return min(maxCompletedLevel + 1, maxCompletedLevel + 1)  // Start from the next uncompleted level
        } else {
            return 1
        }
    }
    
    /// Start a new game from the beginning (Level 1)
    func startFreshGame() {
        score = 0
        currentLevel = 1
        levelsCompletedThisSession = 0
        sessionStartScore = 0
        
        // Clear current progress but keep max completed level
        UserDefaults.standard.removeObject(forKey: "CurrentLevel") 
        UserDefaults.standard.removeObject(forKey: "PersistentScore")
        UserDefaults.standard.synchronize()
        
        print("🎮 ScoreManager: Starting fresh game from Level 1")
    }
    
    /// Continue from the last completed level
    func continueFromLastLevel() {
        if shouldContinueFromLastLevel() {
            // Reset current progress but start from recommended level
            score = 0
            currentLevel = getRecommendedStartingLevel()
            levelsCompletedThisSession = 0
            sessionStartScore = 0
            
            // Clear persistent progress since we're starting fresh from higher level
            UserDefaults.standard.removeObject(forKey: "CurrentLevel")
            UserDefaults.standard.removeObject(forKey: "PersistentScore") 
            UserDefaults.standard.synchronize()
            
            print("🎮 ScoreManager: Continuing from Level \(currentLevel) (last completed: \(maxCompletedLevel))")
        } else {
            startFreshGame()
        }
    }
    
    /// Reset ALL progress including max completed level (for complete game reset)
    func resetAllProgress() {
        score = 0
        currentLevel = 1
        levelsCompletedThisSession = 0
        sessionStartScore = 0
        maxCompletedLevel = 0
        
        // Clear ALL persistent data
        UserDefaults.standard.removeObject(forKey: "CurrentLevel")
        UserDefaults.standard.removeObject(forKey: "PersistentScore")
        UserDefaults.standard.removeObject(forKey: "MaxCompletedLevel")
        UserDefaults.standard.synchronize()
        
        print("🎮 ScoreManager: ALL PROGRESS RESET - starting completely fresh")
    }
    
    /// Start the game at a specific level (for level selection)
    func startAtLevel(_ level: Int) {
        // Calculate the score that should be earned by reaching this level
        // Each level requires completing the previous level, so calculate cumulative score
        let baseScore = (level - 1) * GameConfig.levelCompletionBonus
        
        score = baseScore
        currentLevel = level
        levelsCompletedThisSession = 0
        sessionStartScore = baseScore
        
        // Update max completed level if we're starting at a higher level
        if level > 1 {
            maxCompletedLevel = max(maxCompletedLevel, level - 1)
        }
        
        // Clear any existing persistent data since we're starting at a specific level
        UserDefaults.standard.removeObject(forKey: "CurrentLevel")
        UserDefaults.standard.removeObject(forKey: "PersistentScore")
        UserDefaults.standard.set(maxCompletedLevel, forKey: "MaxCompletedLevel")
        UserDefaults.standard.synchronize()
        
        print("🎮 ScoreManager: Starting at Level \(level) with score \(score)")
        print("🎮 Max completed level updated to: \(maxCompletedLevel)")
    }
    
    /// Test method to manually set the max completed level (for testing)
    func debugSetMaxCompletedLevel(_ level: Int) {
        maxCompletedLevel = level
        UserDefaults.standard.set(maxCompletedLevel, forKey: "MaxCompletedLevel")
        UserDefaults.standard.synchronize()
        print("🧪 DEBUG: Set max completed level to \(level)")
    }
    
    /// Debug method to show current state
    func debugShowState() {
        print("🎮 SCOREMANAGER DEBUG STATE:")
        print("  - Current Level: \(currentLevel)")
        print("  - Score: \(score)")
        print("  - Max Completed Level: \(maxCompletedLevel)")
        print("  - Should Continue: \(shouldContinueFromLastLevel())")
        print("  - Recommended Starting Level: \(getRecommendedStartingLevel())")
        print("  - Score Carryover Enabled: \(GameConfig.enableScoreCarryover)")
    }
    
    // MARK: - Debug Methods for Level Continuation Testing
    
    /// Test method to simulate completing multiple levels for testing
    func debugSimulateProgressToLevel(_ targetLevel: Int) {
        print("🧪 DEBUG: Simulating progress to Level \(targetLevel)")
        
        for level in 1..<targetLevel {
            currentLevel = level
            completeLevel()
            print("📈 Simulated completion of Level \(level)")
        }
        
        debugShowState()
    }
}
