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

class ScoreManager {
    // MARK: - Properties
    var score: Int = 0 {
        didSet {
            onScoreChanged?(score)
            
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "HighScore")
                onHighScoreAchieved?(highScore)
            }
        }
    }
    
    var highScore: Int {
        didSet {
            onHighScoreChanged?(highScore)
        }
    }
    
    // MARK: - Callbacks
    var onScoreChanged: ((Int) -> Void)?
    var onHighScoreChanged: ((Int) -> Void)?
    var onHighScoreAchieved: ((Int) -> Void)?
    
    // MARK: - Initialization
    init() {
        self.highScore = UserDefaults.standard.integer(forKey: "HighScore")
    }
    
    // MARK: - Score Management
    func addScore(_ points: Int) {
        score += points
    }
    
    func resetScore() {
        score = 0
    }
    
    func isHighScore() -> Bool {
        return score > highScore
    }
}