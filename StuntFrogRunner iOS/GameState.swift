//
//  GameState.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//


//
//  GameStateManager.swift
//  StuntFrog Runner
//
//  Manages game states and transitions

import Foundation

enum GameState {
    case menu
    case initialUpgradeSelection  // New state for start-of-game upgrade selection
    case playing
    case paused
    case abilitySelection
    case gameOver
}

enum GameOverReason {
    case splash
    case healthDepleted
    case scrolledOffScreen
    case tooSlow
    case timeUp
}

enum WaterState {
    case water  // Normal water behavior - frog can drown
    case ice    // Ice behavior - frog slides instead of drowning
}



class GameStateManager {
    // MARK: - Properties
    var currentState: GameState = .menu {
        didSet {
            onStateChanged?(currentState, oldValue)
        }
    }
    
    // MARK: - Level Management
    var currentLevel: Int = 1 {
        didSet {
            if currentLevel != oldValue {
                print("🎯 Level changed from \(oldValue) to \(currentLevel)")
                onLevelChanged?(currentLevel, oldValue)
                updateWeatherForCurrentLevel()
            }
        }
    }
    
    var totalScore: Int = 0 {
        didSet {
            onScoreChanged?(totalScore, oldValue)
        }
    }
    
    // MARK: - Water State Management
    var waterState: WaterState = .water {
        didSet {
            print("💧 Water state changed to: \(waterState)")
            onWaterStateChanged?(waterState, oldValue)
        }
    }
    
    // MARK: - Weather Management
    var currentWeather: WeatherType = .day {
        didSet {
            print("🌤️ Weather changed to: \(currentWeather)")
            onWeatherChanged?(currentWeather, oldValue)
            updateStateForWeather()
        }
    }
    
    var lastGameOverReason: GameOverReason?
    var pendingGameOverWorkItem: DispatchWorkItem?
    
    // MARK: - Flags
    var inputLocked: Bool = false {
        didSet {
            if inputLocked && !oldValue {
                // Input just got locked - notify slingshot controller
                onInputLocked?()
            }
        }
    }
    var splashTriggered: Bool = false
    var hasLandedOnce: Bool = false
    
    // MARK: - Callbacks
    var onStateChanged: ((GameState, GameState) -> Void)?
    var onLevelChanged: ((Int, Int) -> Void)?
    var onScoreChanged: ((Int, Int) -> Void)?
    var onWaterStateChanged: ((WaterState, WaterState) -> Void)?
    var onWeatherChanged: ((WeatherType, WeatherType) -> Void)?
    var onGameOver: ((GameOverReason) -> Void)?
    var onInputLocked: (() -> Void)?  // New callback for when input gets locked
    
    // MARK: - State Management
    func transitionToMenu() {
        currentState = .menu
    }
    
    func startPlaying() {
        currentState = .playing
        inputLocked = false
    }
    
    func pauseGame() {
        currentState = .paused
    }
    
    func showAbilitySelection() {
        currentState = .abilitySelection
    }
    
    // MARK: - Level Management
    func advanceToNextLevel() {
        currentLevel += 1
    }
    
    func setLevel(_ level: Int) {
        currentLevel = max(1, level)  // Ensure level is at least 1
    }
    
    func updateScore(_ newScore: Int) {
        totalScore = newScore
    }
    
    /// Check if player has earned enough points to advance to the next level
    /// You can customize this logic based on your progression system
    func checkForLevelAdvancement(basedOnScore: Bool = false, pointsPerLevel: Int = 25000) {
        if basedOnScore {
            let calculatedLevel = max(1, (totalScore / pointsPerLevel) + 1)
            if calculatedLevel > currentLevel {
                setLevel(calculatedLevel)
            }
        }
        // Otherwise, level advancement is manual via advanceToNextLevel()
    }
    
    private func updateWeatherForCurrentLevel() {
        // Apply weather configuration based on level using the convenient creation methods
        configureWeatherForLevel(currentLevel)
        
        // Also notify the WeatherManager for any additional weather system updates
        let weatherManager = WeatherManager.shared
        weatherManager.updateWeatherForLevel(currentLevel)
    }
    
    /// Configure weather and water state for a specific level using the creation methods
    private func configureWeatherForLevel(_ level: Int) {
        // Define weather patterns for levels (you can customize this logic)
        switch level {
        case 1:
            createDayLevel()      // ☀️ Standard sunny day for beginners
        case 2:
            createDayLevel()      // ☀️ Keep it simple for level 2
        case 3:
            createNightLevel()    // 🌙 Introduce night setting
        case 4:
            createRainyLevel()    // 🌧️ Add rain effects and difficulty
        case 5:
            createIcyLevel()      // ❄️ Winter effects with ice behavior
        case 6:
            createStormyLevel()   // ⛈️ Lightning and storm effects
        case 7:
            createNightLevel()    // 🌙 Back to night but more challenging
        case 8:
            createStormyLevel()   // ⛈️ Maximum challenge with storms
        default:
            // For levels beyond 8, cycle through weather patterns
            let weatherCycle = (level - 1) % 5
            switch weatherCycle {
            case 0:
                createDayLevel()      // ☀️ 
            case 1:
                createNightLevel()    // 🌙
            case 2:
                createRainyLevel()    // 🌧️
            case 3:
                createIcyLevel()      // ❄️
            case 4:
                createStormyLevel()   // ⛈️
            default:
                createDayLevel()      // ☀️ Fallback
            }
        }
        
        print("🎮 Level \(level) configured with weather: \(currentWeather) and water state: \(waterState)")
    }
    
    // MARK: - Water State Management
    func setWaterState(_ newState: WaterState) {
        waterState = newState
    }
    
    func toggleWaterState() {
        switch waterState {
        case .water:
            waterState = .ice
        case .ice:
            waterState = .water
        }
    }
    
    // MARK: - Convenience Methods for Level Design
    func createWaterLevel() {
        waterState = .water
        print("🌊 Level configured with WATER - frog can drown")
    }
    
    func createIceLevel() {
        waterState = .ice
        print("🧊 Level configured with ICE - frog will slide instead of drowning")
    }
    
    // MARK: - Weather Configuration Methods
    func setWeather(_ weather: WeatherType) {
        currentWeather = weather
    }
    
    /// Manually configure weather for the current level (useful for testing or special scenarios)
    func applyWeatherConfigurationForCurrentLevel() {
        configureWeatherForLevel(currentLevel)
    }
    
    /// Start a new level with automatic weather configuration
    func startNewLevel(_ level: Int) {
        setLevel(level)
        // Weather configuration is automatically applied via the level setter
        print("🚀 Started new level \(level) with weather: \(currentWeather)")
    }
    
    // IMPORTANT: The weather creation methods are now automatically called when levels change!
    // - createDayLevel(), createNightLevel(), createRainyLevel(), createIcyLevel(), createStormyLevel()
    // - Weather patterns: Level 1-2 = Day, Level 3 = Night, Level 4 = Rain, Level 5 = Winter, Level 6+ = Storm cycles
    
    func createDayLevel() {
        currentWeather = .day
        waterState = .water
        print("☀️ Level configured for DAY - sunny weather with standard assets")
    }
    
    func createNightLevel() {
        currentWeather = .night
        waterState = .water
        print("🌙 Level configured for NIGHT - dark atmosphere with night assets")
    }
    
    func createRainyLevel() {
        currentWeather = .rain
        waterState = .water
        print("🌧️ Level configured for RAIN - rain effects with modified water/lilypad assets")
    }
    
    func createIcyLevel() {
        currentWeather = .winter
        waterState = .ice  // Automatically set water to ice behavior
        print("❄️ Level configured for WINTER - icy effects with ice water behavior")
    }
    
    func createStormyLevel() {
        currentWeather = .stormy
        waterState = .water
        print("⛈️ Level configured for STORMY - lightning and rain effects with storm assets")
    }
    
    private func updateStateForWeather() {
        // Automatically adjust water state when weather changes to winter
        if currentWeather == .winter && waterState != .ice {
            waterState = .ice
        }
    }
    
    /*
     USAGE EXAMPLES:
     
     // LEVEL MANAGEMENT:
     // Advance to next level manually
     gameStateManager.advanceToNextLevel()
     
     // Set specific level
     gameStateManager.setLevel(5)
     
     // Update score (separate from level)
     gameStateManager.updateScore(15000)
     
     // Optional: Check for level advancement based on score
     gameStateManager.checkForLevelAdvancement(basedOnScore: true, pointsPerLevel: 25000)
     
     // Get current level
     let currentLevel = gameStateManager.currentLevel
     
     // WATER STATE MANAGEMENT:
     // Create a standard water level (default behavior)
     stateManager.createWaterLevel()
     
     // Create an ice level where the frog slides instead of drowning
     stateManager.createIceLevel()
     
     // Toggle between water types programmatically
     stateManager.toggleWaterState()
     
     // Set specific water state
     stateManager.setWaterState(.ice)
     stateManager.setWaterState(.water)
     
     // Check current water state
     if stateManager.waterState == .ice {
         print("Currently on ice!")
     }
     
     // WEATHER CONFIGURATION:
     // Create weather-specific levels with appropriate assets and effects
     stateManager.createDayLevel()      // ☀️ Standard sunny day
     stateManager.createNightLevel()    // 🌙 Dark with night assets
     stateManager.createRainyLevel()    // 🌧️ Rain effects + modified assets
     stateManager.createIcyLevel()      // ❄️ Winter effects + ice behavior
     stateManager.createStormyLevel()   // ⛈️ Lightning + rain + storm assets
     
     // Set specific weather
     stateManager.setWeather(.night)
     stateManager.setWeather(.stormy)
     
     // Check current weather
     if stateManager.currentWeather == .rain {
         print("It's raining!")
     }
     
     // Weather automatically adjusts water state when needed:
     stateManager.setWeather(.winter)  // This also sets waterState to .ice
     
     // CALLBACKS FOR LEVEL CHANGES:
     stateManager.onLevelChanged = { newLevel, oldLevel in
         print("Level changed from \(oldLevel) to \(newLevel)")
         // Weather will automatically update via WeatherManager
     }
     */
    
    func triggerGameOver(_ reason: GameOverReason, delay: TimeInterval = 0) {
        lastGameOverReason = reason
        
        pendingGameOverWorkItem?.cancel()
        
        if delay > 0 {
            let work = DispatchWorkItem { [weak self] in
                self?.completeGameOver(reason)
            }
            pendingGameOverWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            completeGameOver(reason)
        }
    }
    
    private func completeGameOver(_ reason: GameOverReason) {
        currentState = .gameOver
        onGameOver?(reason)
    }
    
    func cancelPendingGameOver() {
        pendingGameOverWorkItem?.cancel()
        pendingGameOverWorkItem = nil
    }
    
    // MARK: - Input Management
    func lockInput(for duration: TimeInterval = 0.3) {
        inputLocked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.inputLocked = false
        }
    }
    
    func forceUnlockInput() {
        inputLocked = false
        print("🔓 Input forcefully unlocked")
    }
    
    // MARK: - Reset
    func reset() {
        currentState = .menu
        currentLevel = 1  // Reset to level 1
        totalScore = 0    // Reset score
        waterState = .water  // Reset to default water state
        currentWeather = .day  // Reset to default weather
        lastGameOverReason = nil
        pendingGameOverWorkItem?.cancel()
        pendingGameOverWorkItem = nil
        inputLocked = false
        splashTriggered = false
        hasLandedOnce = false
        
        // Apply weather configuration for level 1
        configureWeatherForLevel(1)
    }
}
