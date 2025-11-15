//
//  LevelSystemIntegrationExample.swift
//  StuntFrogRunner iOS
//
//  Example showing how to integrate the new discrete level system
//  This file demonstrates how to set up level management with automatic weather changes
//

import Foundation
import SpriteKit

/*
 INTEGRATION EXAMPLE: How to set up the new discrete level system
 ================================================================
 
 This example shows how to integrate the GameStateManager with your game scene
 and spawn manager to get automatic level progression and weather changes.
 */

class ExampleGameScene: SKScene {
    
    // MARK: - Managers
    let gameStateManager = GameStateManager()
    var spawnManager: SpawnManager!
    let weatherManager = WeatherManager.shared
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // Initialize SpawnManager with required parameters
        spawnManager = SpawnManager(scene: self, worldNode: self)
        
        // STEP 1: Connect SpawnManager to GameStateManager
        spawnManager.gameStateManager = gameStateManager
        spawnManager.scene = self
        
        // STEP 2: Set up level change callback
        gameStateManager.onLevelChanged = { [weak self] newLevel, oldLevel in
            print("🎯 Game advanced from level \(oldLevel) to level \(newLevel)")
            
            // Weather automatically updates via WeatherManager.updateWeatherForLevel()
            // which is called from GameStateManager.updateWeatherForCurrentLevel()
            
            // You can add other level-specific changes here:
            self?.updateBackgroundForLevel(newLevel)
            self?.playLevelAdvanceSound()
            self?.showLevelAdvanceUI(newLevel)
        }
        
        // STEP 3: Set up score change callback (optional)
        gameStateManager.onScoreChanged = { [weak self] newScore, oldScore in
            print("💰 Score changed from \(oldScore) to \(newScore)")
            // Update UI, check achievements, etc.
        }
        
        // STEP 4: Initialize weather system with the game state manager
        weatherManager.initializeForGame(gameStateManager: gameStateManager)
        
        startNewGame()
    }
    
    // MARK: - Game Control Methods
    
    func startNewGame() {
        // Reset everything to starting state
        gameStateManager.reset()  // This sets level to 1 and score to 0
        
        // Reset spawn manager (this no longer manages level internally)
        var emptyArrays: ([LilyPad], [Tadpole], [BigHoneyPot], [LifeVest]) = ([], [], [], [])
        spawnManager.reset(for: &emptyArrays.0, tadpoles: &emptyArrays.1, bigHoneyPots: &emptyArrays.2, lifeVests: &emptyArrays.3)
        
        gameStateManager.startPlaying()
        print("🎮 New game started - Level: \(gameStateManager.currentLevel)")
    }
    
    // EXAMPLE: Manual level advancement (e.g., when player reaches certain objectives)
    func checkForLevelAdvancement() {
        // Option 1: Manual level advancement based on game objectives
        if playerReachedFinishLine() {
            gameStateManager.advanceToNextLevel()
        }
        
        // Option 2: Score-based level advancement (optional)
        gameStateManager.checkForLevelAdvancement(basedOnScore: true, pointsPerLevel: 25000)
    }
    
    // EXAMPLE: Score updates (separate from level)
    func updatePlayerScore(points: Int) {
        let newScore = gameStateManager.totalScore + points
        gameStateManager.updateScore(newScore)
        
        // Check if this score increase warrants a level advance
        checkForLevelAdvancement()
    }
    
    // EXAMPLE: Set specific level for testing
    func jumpToLevel(_ level: Int) {
        gameStateManager.setLevel(level)
        print("🎯 Jumped to level \(level) - Weather: \(weatherManager.weather.displayName)")
    }
    
    // MARK: - Level-Specific Updates
    
    private func updateBackgroundForLevel(_ level: Int) {
        // Update background based on current weather (which auto-updates with level)
        let bgColor = weatherManager.getBackgroundColor(for: weatherManager.weather)
        let colorAction = SKAction.colorize(with: bgColor, colorBlendFactor: 1.0, duration: 2.0)
        run(colorAction)
    }
    
    private func playLevelAdvanceSound() {
        // Play level advance sound effect
        print("🔊 Playing level advance sound")
    }
    
    private func showLevelAdvanceUI(_ level: Int) {
        // Show level advance UI with weather information
        let weather = weatherManager.weather
        print("📢 Level \(level) - \(weather.displayName) weather activated!")
    }
    
    // MARK: - Game Logic Helpers
    
    private func playerReachedFinishLine() -> Bool {
        // Your game logic to determine if player reached finish line
        return false // Placeholder
    }
}

/*
 KEY BENEFITS OF THE NEW SYSTEM:
 ===============================
 
 1. DISCRETE LEVEL CONTROL:
    - Levels are no longer tied to score calculations
    - You can advance levels based on any criteria you want
    - More predictable and controllable progression
 
 2. AUTOMATIC WEATHER CHANGES:
    - Weather automatically updates when level changes
    - No need to manually calculate or set weather
    - Weather progression is consistent and predictable
 
 3. SEPARATION OF CONCERNS:
    - Level management is separate from scoring
    - Weather management is automatic
    - Spawn management uses the current level directly
 
 4. FLEXIBLE PROGRESSION:
    - Can advance levels based on objectives, not just score
    - Can still use score-based advancement if desired
    - Easy to test specific levels
 
 5. CONSISTENT STATE MANAGEMENT:
    - All game state is managed in one place (GameStateManager)
    - Callbacks allow other systems to react to changes
    - Easy to reset and maintain state consistency
 
 MIGRATION FROM OLD SYSTEM:
 =========================
 
 OLD WAY (score-based):
 ```
 let level = (currentScore / 25000) + 1
 let config = LevelConfigurations.getAllConfigurations()[level]
 ```
 
 NEW WAY (discrete level):
 ```
 let level = gameStateManager.currentLevel
 let config = weatherManager.getWeatherLevelConfig(level: level)
 ```
 
 The SpawnManager now automatically uses the discrete level from GameStateManager,
 and weather changes are handled automatically when the level changes.
 */