//
//  WeatherManager.swift
//  StuntFrogRunner iOS
//
//  Weather system manager for dynamic weather effects and asset management
//

import Foundation
import SpriteKit

/// Manages weather systems, asset loading, and gameplay effects
class WeatherManager {
    static let shared = WeatherManager()
    
    private var currentWeather: WeatherType = .day
    private var weatherConfig: WeatherConfiguration?
    private weak var effectsManager: EffectsManager?
    
    // Weather transition properties
    private var isTransitioning = false
    private var transitionDuration: TimeInterval = 2.0
    
    private init() {}
    
    // MARK: - Weather Management
    
    /// Initialize weather system for game start
    func initializeForGame(gameStateManager: GameStateManager? = nil, effectsManager: EffectsManager? = nil) {
        // Set initial weather based on starting level
        let startingLevel = gameStateManager?.currentLevel ?? 1
        let initialWeather = suggestWeatherForLevel(startingLevel)
        setWeather(initialWeather, effectsManager: effectsManager)
        print("🌤️ Weather system initialized for level \(startingLevel) with \(initialWeather.displayName) weather")
    }
    
    /// Update weather based on current level (called automatically when level changes)
    func updateWeatherForLevel(_ level: Int, effectsManager: EffectsManager? = nil) {
        let appropriateWeather = suggestWeatherForLevel(level)
        
        // Only change weather if it's different from current
        guard appropriateWeather != currentWeather else { 
            print("🌤️ Level \(level): Weather remains \(currentWeather.displayName)")
            return 
        }
        
        print("🌤️ Level \(level): Transitioning weather from \(currentWeather.displayName) to \(appropriateWeather.displayName)")
        transitionToWeather(appropriateWeather, duration: 2.0, effectsManager: effectsManager)
    }
    
    /// Set the current weather and apply all effects
    func setWeather(_ weather: WeatherType, effectsManager: EffectsManager? = nil) {
        let oldWeather = currentWeather
        currentWeather = weather
        self.effectsManager = effectsManager
        
        print("🌤️ Weather changing from \(oldWeather.displayName) to \(weather.displayName)")
        
        // Create weather configuration
        weatherConfig = WeatherConfiguration(weatherType: weather)
        
        // Apply visual effects
        effectsManager?.updateWeatherEffects(for: weather)
        
        // Post notification for other systems
        NotificationCenter.default.post(
            name: NSNotification.Name("WeatherChanged"),
            object: weather,
            userInfo: ["oldWeather": oldWeather, "config": weatherConfig as Any]
        )
    }
    
    /// Transition smoothly between weather types
    func transitionToWeather(_ weather: WeatherType, duration: TimeInterval = 2.0, effectsManager: EffectsManager? = nil) {
        guard weather != currentWeather else { 
            print("🌤️ Weather transition skipped - already at \(weather.displayName)")
            return 
        }
        
        print("🌤️ Starting weather transition to \(weather.displayName) over \(duration) seconds")
        
        // Apply weather change immediately for gameplay systems
        setWeather(weather, effectsManager: effectsManager)
        
        isTransitioning = true
        transitionDuration = duration
        
        // Mark transition as complete after visual effects have time to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isTransitioning = false
            print("🌤️ Weather transition complete")
        }
    }
    
    /// Immediately change weather without transition (for testing/debugging)
    func forceWeatherChange(_ weather: WeatherType, effectsManager: EffectsManager? = nil) {
        print("🌤️ FORCE: Immediately changing weather to \(weather.displayName)")
        setWeather(weather, effectsManager: effectsManager)
    }
    
    /// Get the current weather type
    var weather: WeatherType {
        return currentWeather
    }
    
    /// Get the current weather configuration
    var configuration: WeatherConfiguration? {
        return weatherConfig
    }
    
    // MARK: - Asset Management
    
    /// Get the appropriate texture name for weather-specific assets
    func getAssetName(baseName: String, weather: WeatherType = .day) -> String {
        let suffix = weather.assetSuffix
        return baseName + suffix
    }
    
    /// Load weather-appropriate lily pad texture
    func getLilyPadTexture(weather: WeatherType = .day) -> SKTexture {
        let textureName = getAssetName(baseName: "lilypad", weather: weather)
        return SKTexture(imageNamed: textureName)
    }
    
    /// Load weather-appropriate water texture
    func getWaterTexture(weather: WeatherType = .day) -> SKTexture {
        let textureName = getAssetName(baseName: "water", weather: weather)
        return SKTexture(imageNamed: textureName)
    }
    
    /// Get weather-appropriate background color
    func getBackgroundColor(for weather: WeatherType) -> UIColor {
        switch weather {
        case .day:
            return UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0) // Light blue sky
        case .night:
            return UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0) // Dark blue night
        case .winter:
            return UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0) // Pale winter sky
            
        case .ice:
            return UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0) // Pale winter sky
        case .rain:
            return UIColor(red: 0.4, green: 0.4, blue: 0.6, alpha: 1.0) // Gray rainy sky
        case .stormy:
            return UIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1.0) // Dark stormy sky
            
        case .storm:
            return UIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1.0) // Dark stormy sky
        }
    }
    
    // MARK: - Gameplay Effects
    
    /// Check if lily pads should be slippery in current weather
    func shouldPadsBeSlippery() -> Bool {
        return currentWeather.gameplayEffects.contains { effect in
            if case .slipperyPads = effect {
                return true
            }
            return false
        }
    }
    
    /// Get slip factor for lily pads in current weather
    func getSlipFactor() -> CGFloat {
        for effect in currentWeather.gameplayEffects {
            if case .slipperyPads(let factor) = effect {
                return factor
            }
        }
        return 0.0
    }
    
    /// Check if wind effects should be active
    func isWindActive() -> Bool {
        return currentWeather.gameplayEffects.contains { effect in
            if case .windForce = effect {
                return true
            }
            return false
        }
    }
    
    /// Check if water should be converted to ice
    func shouldConvertWaterToIce() -> Bool {
        return currentWeather.gameplayEffects.contains { effect in
            if case .iceConversion = effect {
                return true
            }
            return false
        }
    }
    
    /// Apply weather-specific effects to a lily pad
    func applyWeatherEffectsToLilyPad(_ lilyPad: SKNode, weather: WeatherType = .day) {
        // Remove existing weather effects
        lilyPad.childNode(withName: "weatherEffect")?.removeFromParent()
        
        switch weather {
        case .winter:
            // Add ice overlay
            let iceOverlay = SKSpriteNode(imageNamed: "ice_overlay")
            iceOverlay.name = "weatherEffect"
            iceOverlay.alpha = 0.2
            iceOverlay.zPosition = 1
            lilyPad.addChild(iceOverlay)
            
        case .rain, .stormy:
            // Add water ripples effect
            let ripple = SKShapeNode(circleOfRadius: 60)
            ripple.name = "weatherEffect"
            ripple.strokeColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3)
            ripple.fillColor = .clear
            ripple.lineWidth = 2
            ripple.zPosition = 1
            
            // Animate ripples
            let scaleUp = SKAction.scale(to: 1.5, duration: 1.0)
            let fadeOut = SKAction.fadeOut(withDuration: 1.0)
            let rippleAction = SKAction.sequence([
                SKAction.group([scaleUp, fadeOut]),
                SKAction.removeFromParent()
            ])
            ripple.run(SKAction.repeatForever(rippleAction))
            
            lilyPad.addChild(ripple)
            
        default:
            break
        }
    }
    
    // MARK: - Level Integration
    
    /// Get weather-appropriate level configuration
    func getWeatherLevelConfig(level: Int, weather: WeatherType? = nil) -> LevelEnemyConfig {
        let weatherType = weather ?? currentWeather
        return LevelConfigurations.createWeatherConfiguration(for: level, weather: weatherType)
    }
    
    /// Suggest appropriate weather for a level
    func suggestWeatherForLevel(_ level: Int) -> WeatherType {
        // Default progression through weather types
        switch level {
        case 1...2: return .day
        case 3...4: return .night
        case 5: return .rain
        case 6: return .stormy  // Introduce stormy weather earlier
        case 7...8: return .winter
        default:
            // Cycle through more challenging weather for higher levels
            let weatherTypes: [WeatherType] = [.stormy, .winter, .rain, .stormy]
            return weatherTypes[(level - 9) % weatherTypes.count]
        }
    }
    
    // MARK: - Debug Utilities
    
    /// Get debug information about current weather
    func getDebugInfo() -> String {
        var info = "🌤️ Weather Manager Debug Info:\n"
        info += "Current Weather: \(currentWeather.displayName) (\(currentWeather.rawValue))\n"
        info += "Is Transitioning: \(isTransitioning)\n"
        info += "Gameplay Effects:\n"
        
        for effect in currentWeather.gameplayEffects {
            switch effect {
            case .slipperyPads(let factor):
                info += "  - Slippery Pads (factor: \(factor))\n"
            case .windForce:
                info += "  - Wind Force Active\n"
            case .iceConversion:
                info += "  - Ice Conversion Active\n"
            case .rainParticles:
                info += "  - Rain Particles Active\n"
            case .lightning:
                info += "  - Lightning Active\n"
            case .reducedVisibility(let amount):
                info += "  - Reduced Visibility (\(amount * 100)%)\n"
            }
        }
        
        if let config = weatherConfig {
            info += "Configuration:\n"
            info += "  - Wind Strength: \(config.windStrength)\n"
            info += "  - Wind Direction: \(config.windDirection)\n"
            info += "  - Slip Duration: \(config.slipDuration)s\n"
            info += "  - Ice Thickness: \(config.iceThickness)\n"
            info += "  - Particle Intensity: \(config.particleIntensity)\n"
        }
        
        return info
    }
    
    /// Print debug info to console
    func printDebugInfo() {
        print(getDebugInfo())
    }
}

// MARK: - Convenience Extensions

extension WeatherManager {
    /// Quick method to cycle to the next weather type (for testing)
    func cycleToNextWeather() {
        let allWeathers = WeatherType.allCases
        if let currentIndex = allWeathers.firstIndex(of: currentWeather) {
            let nextIndex = (currentIndex + 1) % allWeathers.count
            let nextWeather = allWeathers[nextIndex]
            setWeather(nextWeather, effectsManager: effectsManager)
        }
    }
    
    /// Set random weather (for testing/variety)
    func setRandomWeather() {
        if let randomWeather = WeatherType.allCases.randomElement() {
            setWeather(randomWeather, effectsManager: effectsManager)
        }
    }
}
