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
        
        // Load persistent level progression data if score carryover is enabled
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
        
        // Clear persistent data
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
            
            // Award level completion bonus
            let bonus = GameConfig.levelCompletionBonus
            score += bonus
            
            print("🎮 ScoreManager: Level \(currentLevel - 1) completed!")
            print("🎮 Level completion bonus: +\(bonus) points")
            print("🎮 Advanced to Level \(currentLevel)")
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
            UserDefaults.standard.synchronize()
        }
    }
    
    func isHighScore() -> Bool {
        return score > highScore
    }
}
