//
//  WeatherIntegrationGuide.swift
//  StuntFrogRunner iOS
//
//  Guide for integrating weather system with your game
//  This file shows how to use the new weather configurations
//

import Foundation
import SpriteKit

/*
 WEATHER INTEGRATION GUIDE
 ========================
 
 This guide shows how to integrate the new weather system into your game.
 
 ## 1. Setting Up Weather
 
 In your GameScene's didMove(to view:) method:
 
 ```swift
 let weatherManager = WeatherManager.shared
 let effectsManager = EffectsManager(scene: self)
 
 // Set initial weather based on level
 let level = getCurrentLevel()
 let suggestedWeather = weatherManager.suggestWeatherForLevel(level)
 weatherManager.setWeather(suggestedWeather, effectsManager: effectsManager)
 ```
 
 ## 2. Using Weather-Specific Level Configurations
 
 Instead of using the regular level configurations, use weather-aware ones:
 
 ```swift
 // Old way:
 let levelConfig = LevelConfigurations.getAllConfigurations()[level]
 
 // New weather-aware way:
 let weatherManager = WeatherManager.shared
 let weatherConfig = weatherManager.getWeatherLevelConfig(level: level)
 
 // Or specify weather directly:
 let winterConfig = LevelConfigurations.createWeatherConfiguration(for: level, weather: .winter)
 ```
 
 ## 3. Applying Weather Effects to Lily Pads
 
 When creating lily pads, apply weather-specific effects:
 
 ```swift
 func createLilyPad(at position: CGPoint) -> LilyPad {
     let lilyPad = LilyPad(at: position)
     
     // Apply weather-specific texture
     let weather = WeatherManager.shared.weather
     let texture = WeatherManager.shared.getLilyPadTexture(weather: weather)
     lilyPad.sprite.texture = texture
     
     // Apply weather effects (ice, ripples, etc.)
     WeatherManager.shared.applyWeatherEffectsToLilyPad(lilyPad.sprite, weather: weather)
     
     return lilyPad
 }
 ```
 
 ## 4. Handling Slippery Lily Pads
 
 In your FrogController's landing logic:
 
 ```swift
 func landOnLilyPad(_ lilyPad: LilyPad) {
     let weatherManager = WeatherManager.shared
     
     // Regular landing logic
     performLanding(on: lilyPad)
     
     // Check for weather-specific effects
     if weatherManager.shouldPadsBeSlippery() {
         let slipFactor = weatherManager.getSlipFactor()
         applySlipEffect(factor: slipFactor)
     }
 }
 
 private func applySlipEffect(factor: CGFloat) {
     // Make the frog slide on the lily pad
     let slideDistance = factor * 100 // Adjust based on your needs
     let slideDirection = CGFloat.random(in: 0...(2 * .pi))
     
     let slideX = cos(slideDirection) * slideDistance
     let slideY = sin(slideDirection) * slideDistance
     
     let slideAction = SKAction.moveBy(x: slideX, y: slideY, duration: 0.5)
     slideAction.timingMode = .easeOut
     
     frogNode.run(slideAction)
 }
 ```
 
 ## 5. Handling Wind Effects
 
 Subscribe to wind force notifications in your GameScene:
 
 ```swift
 override func didMove(to view: SKView) {
     super.didMove(to: view)
     
     NotificationCenter.default.addObserver(
         self,
         selector: #selector(handleWindForce(_:)),
         name: NSNotification.Name("WindForceApplied"),
         object: nil
     )
 }
 
 @objc private func handleWindForce(_ notification: Notification) {
     guard let windForce = notification.object as? CGVector else { return }
     
     // Apply wind force to the frog
     let windAction = SKAction.moveBy(x: windForce.dx, y: windForce.dy, duration: 1.0)
     windAction.timingMode = .easeOut
     
     frogController.frogNode.run(windAction)
 }
 ```
 
 ## 6. Converting Water to Ice (Winter Weather)
 
 In your water/background rendering code:
 
 ```swift
 func updateWaterTextures() {
     let weatherManager = WeatherManager.shared
     
     if weatherManager.shouldConvertWaterToIce() {
         // Use ice textures instead of water
         let iceTexture = weatherManager.getAssetName(baseName: "water", weather: .winter)
         backgroundNode.texture = SKTexture(imageNamed: iceTexture)
         
         // Add ice effects
         addIceEffects()
     } else {
         // Use regular water texture
         let waterTexture = weatherManager.getWaterTexture(weather: weatherManager.weather)
         backgroundNode.texture = waterTexture
     }
 }
 ```
 
 ## 7. Weather Transitions Between Levels
 
 When advancing to a new level:
 
 ```swift
 func advanceToNextLevel() {
     let newLevel = currentLevel + 1
     let weatherManager = WeatherManager.shared
     let effectsManager = self.effectsManager // Your effects manager instance
     
     // Get appropriate weather for the new level
     let newWeather = weatherManager.suggestWeatherForLevel(newLevel)
     
     // Smooth transition to new weather
     weatherManager.transitionToWeather(newWeather, duration: 3.0, effectsManager: effectsManager)
     
     // Update level configuration with new weather
     let weatherConfig = weatherManager.getWeatherLevelConfig(level: newLevel)
     applyLevelConfiguration(weatherConfig)
 }
 ```
 
 ## 8. Testing Different Weather Types
 
 For testing purposes, you can cycle through weather types:
 
 ```swift
 // In your debug menu or during development
 func testWeatherCycling() {
     let weatherManager = WeatherManager.shared
     
     // Cycle to next weather type
     weatherManager.cycleToNextWeather()
     
     // Or set random weather
     weatherManager.setRandomWeather()
     
     // Or set specific weather
     weatherManager.setWeather(.stormy, effectsManager: effectsManager)
 }
 ```
 
 ## 9. Debugging Weather System
 
 To debug weather issues:
 
 ```swift
 func printWeatherDebugInfo() {
     let weatherManager = WeatherManager.shared
     weatherManager.printDebugInfo()
     
     // Also print level configuration debug info
     let level = getCurrentLevel()
     let weatherConfig = weatherManager.getWeatherLevelConfig(level: level)
     print("Weather Level Config: \(LevelEnemyConfigManager.getDebugInfo(for: level))")
 }
 ```
 
 ## Asset Requirements
 
 To use the weather system effectively, you'll need the following assets:
 
 ### Lily Pad Textures:
 - lilypad.png (default/day)
 - lilypad_night.png
 - lilypad_winter.png
 - lilypad_rain.png
 - lilypad_stormy.png
 
 ### Water/Background Textures:
 - water.png (default/day)
 - water_night.png
 - water_winter.png (ice texture)
 - water_rain.png
 - water_stormy.png
 
 ### Additional Effect Assets:
 - ice_overlay.png (for winter lily pad effects)
 - snowflake.png (for snow particles)
 - wind_particle.png (for wind effects)
 
 The system will automatically fall back to the default texture if weather-specific 
 assets are not available.
 
 ## Performance Considerations
 
 - Weather effects are automatically managed and cleaned up
 - Particle effects are limited to reasonable amounts
 - Use weather transitions sparingly to avoid overwhelming the player
 - Consider reducing particle intensity on lower-end devices
 
 ## Example: Complete Weather Integration
 
 Here's a complete example of how to integrate weather into a level:
 
 ```swift
 class GameScene: SKScene {
     let weatherManager = WeatherManager.shared
     var effectsManager: EffectsManager!
     
     override func didMove(to view: SKView) {
         super.didMove(to: view)
         
         // Initialize effects manager
         effectsManager = EffectsManager(scene: self)
         effectsManager.prepare()
         
         // Set initial weather
         let level = getCurrentLevel()
         let weather = weatherManager.suggestWeatherForLevel(level)
         weatherManager.setWeather(weather, effectsManager: effectsManager)
         
         // Apply weather-appropriate background
         let bgColor = weatherManager.getBackgroundColor(for: weather)
         backgroundColor = bgColor
         
         // Load weather-appropriate level configuration
         let levelConfig = weatherManager.getWeatherLevelConfig(level: level)
         applyLevelConfiguration(levelConfig)
         
         // Setup weather change notifications
         setupWeatherNotifications()
     }
     
     private func setupWeatherNotifications() {
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(weatherChanged(_:)),
             name: NSNotification.Name("WeatherChanged"),
             object: nil
         )
         
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(handleWindForce(_:)),
             name: NSNotification.Name("WindForceApplied"),
             object: nil
         )
     }
     
     @objc private func weatherChanged(_ notification: Notification) {
         guard let newWeather = notification.object as? WeatherType else { return }
         
         print("Weather changed to: \(newWeather.displayName)")
         
         // Update background color
         let bgColor = weatherManager.getBackgroundColor(for: newWeather)
         let colorAction = SKAction.colorize(with: bgColor, colorBlendFactor: 1.0, duration: 2.0)
         run(colorAction)
         
         // Update existing lily pads
         enumerateChildNodes(withName: "lilypad") { node, _ in
             self.weatherManager.applyWeatherEffectsToLilyPad(node, weather: newWeather)
         }
     }
     
     @objc private func handleWindForce(_ notification: Notification) {
         guard let windForce = notification.object as? CGVector else { return }
         // Apply wind to frog - implement based on your frog controller
     }
 }
 ```
 
 This integration provides a complete weather system that affects gameplay,
 visuals, and enemy spawning based on the current weather conditions.
 */

// This file serves as documentation and can be removed from the final build
// if you don't need the guide in your actual game code.