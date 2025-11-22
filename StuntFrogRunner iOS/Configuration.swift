import UIKit
import SpriteKit

/// Centralized configuration for game balance, physics, and assets.
struct Configuration {
    
    struct Physics {
        static let gravityZ: CGFloat = 0.6
        static let frictionGround: CGFloat = 0.8
        static let frictionAir: CGFloat = 0.99
        static let baseJumpZ: CGFloat = 5.0
        static let maxDragDistance: CGFloat = 250.0
        
        static func dragPower(level: Int) -> CGFloat {
            return 0.08 + (CGFloat(level) * 0.0075)
        }
    }
    
    struct Dimensions {
        static let riverWidth: CGFloat = 600.0
        static let padRadius: CGFloat = 45.0
        static let frogRadius: CGFloat = 20.0
    }
    
    struct Colors {
        static let sunny = SKColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1)
        static let rain = SKColor(red: 44/255, green: 62/255, blue: 80/255, alpha: 1)
        static let night = SKColor(red: 12/255, green: 21/255, blue: 32/255, alpha: 1)
        static let winter = SKColor(red: 160/255, green: 190/255, blue: 220/255, alpha: 1)
    }
    
    struct GameRules {
        static let coinsForUpgradeTrigger = 10
        static let rocketDuration: TimeInterval = 7.0
        static let rocketLandingDuration: TimeInterval = 3.0
        static let bootsDuration: TimeInterval = 5.0
    }
    
    struct Shop {
        static let maxJumpLevel = 10
        static let maxHealthLevel = 5
        
        static func jumpUpgradeCost(currentLevel: Int) -> Int {
            return currentLevel * 100
        }
        
        static func healthUpgradeCost(currentLevel: Int) -> Int {
            return currentLevel * 250
        }
        
        // NEW: Log Jumper Cost
        static let logJumperCost = 300
    }
    
    struct GameCenter {
        static let leaderboardID = "TopScores"
    }
}

enum WeatherType: String, CaseIterable {
    case sunny, rain, night, winter
}
