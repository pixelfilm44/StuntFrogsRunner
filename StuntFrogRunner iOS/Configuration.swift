import UIKit
import SpriteKit

/// Centralized configuration for game balance, physics, and assets.
struct Configuration {
    
    struct Physics {
        static let gravityZ: CGFloat = 0.5
        static let frictionGround: CGFloat = 0.8
        static let frictionAir: CGFloat = 0.90
        static let baseJumpZ: CGFloat = 4.0
        static let maxDragDistance: CGFloat = 300.0  // Reduced from 150 - shorter drag needed for full power
        
        static func dragPower(level: Int) -> CGFloat {
            return 0.12 + (CGFloat(level) * 0.0075)  // 0.08 orig
        }
    }
    
    struct Dimensions {
        static let riverWidth: CGFloat = 600.0
        static let minPadRadius: CGFloat = 55.0
        static let maxPadRadius: CGFloat = 105.0
        static let padSpacing: CGFloat = 25.0  // Minimum gap between lily pads
        static let movingPadMinDistance: CGFloat = 25.0  // Minimum distance between moving lilypads and other pads
        static let frogRadius: CGFloat = 20.0
        
        // MARK: - Water and Shore Layout
        
        /// Extra width on each side for water to extend under shores
        static var waterShoreOverlap: CGFloat {
            return UIDevice.current.userInterfaceIdiom == .pad ? 750.0 : 200.0
        }
        
        /// Total water background width (river + overlap on both sides)
        static let waterBackgroundWidth: CGFloat = riverWidth + (waterShoreOverlap * 2)
        
        /// Multiplier to reduce the physics body size relative to visual size
        /// Lower values = smaller hit zone (0.6 = 60% of visual size)
        static let padPhysicsRadiusMultiplier: CGFloat = 0.6
        
        /// Generates a random pad radius between min and max
        static func randomPadRadius() -> CGFloat {
            return CGFloat.random(in: minPadRadius...maxPadRadius)
        }
    }
    
    
    
    struct Colors {
            static let sunny = SKColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1)
            static let rain = SKColor(red: 44/255, green: 62/255, blue: 80/255, alpha: 1)
            static let night = SKColor(red: 8/255, green: 15/255, blue: 40/255, alpha: 0.75)
            static let winter = SKColor(red: 160/255, green: 190/255, blue: 220/255, alpha: 1)
            
            // Desert void colors - dark gradient from brown to black
            static let desertTop = SKColor(red: 40/255, green: 30/255, blue: 20/255, alpha: 1.0)      // Dark brown
            static let desertBottom = SKColor(red: 10/255, green: 8/255, blue: 5/255, alpha: 1.0)    // Near black with brown tint
            
            // Legacy flat desert color (no longer used)
            static let desert = SKColor(red: 240/255, green: 210/255, blue: 120/255, alpha: 0.5)
            
            // NOTE: This is no longer used as scene backgroundColor to avoid dark overlay
            // Kept for reference/consistency with other weather colors
            static let space = SKColor(red: 100/255, green: 110/255, blue: 180/255, alpha: 1.0)
            
            static let blackVoid = SKColor.black
        }
    /// Centralized font configuration for all UI elements
    ///
    /// Usage examples:
    /// ```swift
    /// // SpriteKit (SKLabelNode)
    /// let label = SKLabelNode(fontNamed: Configuration.Fonts.hudScore.name)
    /// label.fontSize = Configuration.Fonts.hudScore.size
    ///
    /// // UIKit
    /// label.font = Configuration.Fonts.menuTitle
    /// button.titleLabel?.font = Configuration.Fonts.shopBackButton
    /// ```
    struct Fonts {
        // MARK: - Font Names
        static let primaryBold = "Nunito-Bold"
        static let primaryHeavy = "Fredoka-Bold"
        static let cardHeader = "Nunito-ExtraBold"

        
        
        // MARK: - SpriteKit Fonts (SKLabelNode)
        
        /// Primary HUD score display
        static let hudScore: (name: String, size: CGFloat) = (primaryBold, 36)
        
        /// Coin counter in HUD
        static let hudCoins: (name: String, size: CGFloat) = (primaryBold, 24)
        
        /// Descend button
        static let descendButton: (name: String, size: CGFloat) = (primaryBold, 24)
        
        /// Pause icon
        static let pauseIcon: (name: String, size: CGFloat) = (primaryHeavy, 24)
        
        /// Achievement card title
        static let achievementTitle: (name: String, size: CGFloat) = (primaryHeavy, 16)
        
        /// Achievement card name
        static let achievementName: (name: String, size: CGFloat) = (primaryBold, 18)
        
        /// Power-up/buff indicator labels
        static let buffIndicator: (name: String, size: CGFloat) = (primaryBold, 14)
        
        /// Healing indicator (+❤️)
        static let healingIndicator: (name: String, size: CGFloat) = (primaryHeavy, 28)
        
        /// Treasure chest reward display
        static let treasureReward: (name: String, size: CGFloat) = (primaryHeavy, 24)
        
        /// Coin collection reward (+⭐️)
        static let coinReward: (name: String, size: CGFloat) = (primaryHeavy, 28)
        
        // MARK: - UIKit Fonts
        
        /// Menu screen title (STUNT FROG SUPERSTAR)
        static let menuTitle: (name: String, size: CGFloat) = (primaryBold, 46)
        
        /// Menu screen stats text
        static let menuStats = UIFont.systemFont(ofSize: 16, weight: .medium)
        
        /// Play button
        static let menuPlayButton: (name: String, size: CGFloat) = (primaryBold, 36)
        
        /// Shop, Leaderboard, Challenges buttons
        static let menuSecondaryButton = UIFont.systemFont(ofSize: 24, weight: .bold)
        
        /// Challenge badge notification
        static let menuChallengeBadge: (name: String, size: CGFloat) = (primaryBold, 14)
        
        /// Help button
        static let menuHelpButton = UIFont.systemFont(ofSize: 24, weight: .bold)
        
        /// Shop header (FROG SHOP)
        static let shopHeader: (name: String, size: CGFloat) = (primaryHeavy, 36)
        
        /// Shop coins counter
        static let shopCoins = UIFont.systemFont(ofSize: 20, weight: .bold)
        
        /// Shop upgrade card title
        static let shopCardTitle: (name: String, size: CGFloat) = (primaryHeavy, 20)
        
        /// Shop upgrade card cost
        static let shopCardCost = UIFont.systemFont(ofSize: 18, weight: .heavy)
        
        /// Shop upgrade button
        static let shopUpgradeButton = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        /// Shop badge (NEW, OWNED)
        static let shopBadge = UIFont.systemFont(ofSize: 10, weight: .bold)
        
        /// Shop level indicator
        static let shopLevelIndicator = UIFont.systemFont(ofSize: 9, weight: .bold)
        
        /// Shop section title
        static let shopSectionTitle = UIFont.systemFont(ofSize: 16, weight: .heavy)
        
        /// Shop back button
        static let shopBackButton = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        /// Challenges screen title
        static let challengesTitle : (name: String, size: CGFloat) = (primaryHeavy, 32)
        
        /// Challenges back button
        static let challengesBackButton = UIFont.systemFont(ofSize: 20, weight: .bold)
        
        /// Challenge card title
        static let challengeCardTitle = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        /// Challenge card description
        static let challengeCardDescription = UIFont.systemFont(ofSize: 14, weight: .regular)
        
        /// Challenge card progress
        static let challengeCardProgress = UIFont.systemFont(ofSize: 12, weight: .medium)
        
        /// Challenge card reward
        static let challengeCardReward = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        /// Challenge claim badge
        static let challengeClaimBadge = UIFont.systemFont(ofSize: 12, weight: .heavy)
        
        /// Game over screen title (WIPEOUT!)
        static let gameOverTitle : (name: String, size: CGFloat) = (primaryHeavy, 32)
        
        /// Game over score display
        static let gameOverScore: (name: String, size: CGFloat) = (primaryBold, 18)
        
        /// Game over high score banner
        static let gameOverHighScore: (name: String, size: CGFloat) = (primaryBold, 18)
        
        static let gameOverSubtext: (name: String, size: CGFloat) = (primaryBold, 18)

        /// Game over coins display
        static let gameOverCoins: (name: String, size: CGFloat) = (primaryBold, 18)
        
        /// Game over retry/menu buttons
        static let gameOverButton: (name: String, size: CGFloat) = (primaryBold, 20)
        
        static let button = UIFont.systemFont(ofSize: 14, weight: .semibold)

    }
    
    // MARK: - Weather Thresholds
    struct Weather {
        /// Score at which each weather pattern begins
        /// Adjust these values to change how long you spend in each biome
        /// Note: Each 100 score = 10 meters traveled
        static let sunnyStart: Int = 0      // Sunny: 0-500 (50m)
        static let nightStart: Int = 500    // Night: 500-1000 (50m)
        static let rainStart: Int = 1000    // Rain: 1000-1600 (60m)
        static let winterStart: Int = 1600  // Winter: 1600-2400 (80m)
        static let desertStart: Int = 2400  // Desert: 2400-3000 (60m)
        static let spaceStart: Int = 3000   // Space: 3000-4000 (100m)
        // After space at 4000, warp back to sunny
        
        /// Returns the weather type for a given score
        static func weatherForScore(_ score: Int) -> WeatherType {
            if score >= spaceStart { return .space }
            if score >= desertStart { return .desert }
            if score >= winterStart { return .winter }
            if score >= rainStart { return .rain }
            if score >= nightStart { return .night }
            return .sunny
        }
        
        /// Transition duration when weather changes
        static let transitionDuration: TimeInterval = 2.0
    }
    
    struct GameRules {
        static let coinsForUpgradeTrigger = 10
        static let rocketDuration: TimeInterval = 10.0
        static let rocketLandingDuration: TimeInterval = 5.0
        static let bootsDuration: TimeInterval = 5.0
        static let superJumpDuration: TimeInterval = 10.0
        
        // MARK: - Beat the Boat Challenge
        static let boatRaceFinishY: CGFloat = 20000.0 // Base race length (1000 for first race)
        static let boatSpeed: CGFloat = 2.8 // Adjust for balanced difficulty
        static let boatRaceReward: Int = 100
        static let cannonJumpsPerRun = 3

        // MARK: - Weather-Specific Rules
        
        /// Determines if falling in water is instant death for a given weather type.
        static func isInstantDeathWater(for weather: WeatherType) -> Bool {
            return weather == .desert
        }
        
        /// Desert biome rules:
        /// - No bees or dragonflies spawn (replaced by snakes)
        /// - No rain/precipitation
        /// - Snakes spawn on lily pads starting at score 2400
        /// - Instant death when falling in water
        
        // MARK: - Launch Pad Settings (Desert → Space)
        
        /// Score at which the launch pad appears (end of desert, before space transition)
        /// Launch pad appears 100m before space begins
        static let launchPadSpawnScore: Int = Weather.spaceStart - 100
        
        /// Score at which space begins (after successful launch pad jump)
        static let spaceStartScore: Int = Weather.spaceStart
        
        /// Duration of fade to black transition during launch
        static let launchFadeOutDuration: TimeInterval = 1.0
        
        /// Duration of fade from black transition during launch
        static let launchFadeInDuration: TimeInterval = 1.0
        
        /// Pause duration while screen is fully black during launch
        static let launchBlackScreenDuration: TimeInterval = 0.5
        
        // MARK: - Warp Pad Settings (End of Space → Return to Day)
        
        /// Score at which the warp pad appears (end of space)
        static let warpPadSpawnScore: Int = 4000
        
        /// Duration of fade to black transition
        static let warpFadeOutDuration: TimeInterval = 1.0
        
        /// Duration of fade from black transition
        static let warpFadeInDuration: TimeInterval = 1.0
        
        /// Pause duration while screen is fully black
        static let warpBlackScreenDuration: TimeInterval = 0.5
    }
    
    /// Progressive difficulty settings - scales every 500m traveled
    struct Difficulty {
        /// Distance interval (in score units) for difficulty increases
        static let scalingInterval: Int = 500
        
        /// Returns the current difficulty level (0 = easiest, increases every 500m)
        static func level(forScore score: Int) -> Int {
            return score / scalingInterval
        }
        
        // MARK: - Enemy Spawning (Bees/Dragonflies - Not in Desert)
        
        /// Base probability of spawning an enemy (at level 0)
        static let baseEnemyProbability: Double = 0.15
        /// Additional enemy probability per difficulty level
        static let enemyProbabilityPerLevel: Double = 0.25
        /// Maximum enemy spawn probability
        static let maxEnemyProbability: Double = 0.65
        
        static func enemyProbability(forLevel level: Int, weather: WeatherType) -> Double {
            // No bees or dragonflies in desert - replaced by snakes
            guard weather != .desert else { return 0.0 }
            return min(maxEnemyProbability, baseEnemyProbability + (Double(level) * enemyProbabilityPerLevel))
        }
        
        // MARK: - Log Spawning
        
        /// Difficulty level when logs start appearing
        static let logStartLevel: Int = 1
        /// Base probability of spawning a log (once unlocked) - increased for more frequent spawns
        static let baseLogProbability: Double = 0.35
        /// Additional log probability per level after unlock
        static let logProbabilityPerLevel: Double = 0.05
        /// Maximum log spawn probability - increased for more frequent spawns
        static let maxLogProbability: Double = 0.70
        /// Weather conditions where logs can spawn (natural settings, not desert/space)
        static let logWeathers: Set<WeatherType> = [.sunny, .night, .rain, .winter]
        
        static func logProbability(forLevel level: Int) -> Double {
            guard level >= logStartLevel else { return 0.0 }
            let effectiveLevel = level - logStartLevel
            return min(maxLogProbability, baseLogProbability + (Double(effectiveLevel) * logProbabilityPerLevel))
        }
        
        // MARK: - Enemy Types (Not in Desert)
        
        /// Difficulty level when dragonflies start appearing
        static let dragonflyStartLevel: Int = 2
        /// Probability of dragonfly (vs bee) once unlocked, scales with level
        static func dragonflyProbability(forLevel level: Int, weather: WeatherType) -> Double {
            guard weather != .desert else { return 0.0 }
            guard level >= dragonflyStartLevel else { return 0.0 }
            let effectiveLevel = level - dragonflyStartLevel
            return min(0.5, 0.4 + (Double(effectiveLevel) * 0.1))
        }
        
        // MARK: - Pad Types
        
        /// Difficulty level when moving pads start appearing
        static let movingPadStartLevel: Int = 1
        static let movingPadProbability: Double = 0.15
        /// Weather conditions where moving pads can spawn
        static let movingPadWeathers: Set<WeatherType> = [.sunny, .night, .rain, .winter,.space]
        
        /// Difficulty level when ice pads start appearing
        static let icePadStartLevel: Int = 2
        static let icePadProbability: Double = 0.1
        /// Weather conditions where ice pads can spawn (only in winter)
        static let icePadWeathers: Set<WeatherType> = [.winter]
        
        /// Difficulty level when shrinking pads start appearing
        static let shrinkingPadStartLevel: Int = 1
        /// Shrinking probability scales with level
        static func shrinkingProbability(forLevel level: Int) -> Double {
            guard level >= shrinkingPadStartLevel else { return 0.0 }
            let effectiveLevel = level - shrinkingPadStartLevel
            return min(0.35, 0.05 + (Double(effectiveLevel) * 0.05))
        }
        /// Weather conditions where shrinking pads can spawn
        static let shrinkingPadWeathers: Set<WeatherType> = [.sunny, .night, .rain, .winter ]
        
        /// Checks if a specific pad type can spawn in the given weather
        static func canSpawnPadType(_ padType: PadType, in weather: WeatherType) -> Bool {
            switch padType {
            case .moving:
                return movingPadWeathers.contains(weather)
            case .ice:
                return icePadWeathers.contains(weather)
            case .shrinking:
                return shrinkingPadWeathers.contains(weather)
            case .log:
                return logWeathers.contains(weather)
            default:
                return true // Normal pads, graves, special pads, etc. can spawn in any weather
            }
        }
        
        /// Enum defining pad types (for type-safe weather checking)
        enum PadType {
            case normal, moving, ice, log, grave, shrinking, waterLily, launchPad, warp
        }
        
        // MARK: - Crocodile Spawning
        
        /// Minimum score before crocodiles can appear
        static let crocodileMinScore: Int = 2500
        /// Maximum number of crocodiles that can appear in a single run
        static let crocodileMaxPerRun: Int = 2
        /// Probability of spawning a crocodile near a water lily pad. Zero in desert.
        static func crocodileSpawnProbability(for weather: WeatherType) -> Double {
            guard weather != .desert else { return 0.0 }
            return 0.15
        }
        
        // MARK: - Snake Spawning (Desert Only)
        
        /// Minimum score before snakes can appear (start of desert biome)
        static let snakeStartScore: Int = Weather.desertStart
        /// Base probability of spawning a snake in desert (once unlocked)
        static let baseSnakeProbability: Double = 0.15
        /// Additional snake probability per level after unlock
        static let snakeProbabilityPerLevel: Double = 0.02
        /// Maximum snake spawn probability
        static let maxSnakeProbability: Double = 0.40
        /// Maximum snakes on screen at once
        static let snakeMaxOnScreen: Int = 3
        
        /// Calculates the probability of a snake spawning. Snakes spawn primarily in desert, but start appearing slightly before the cutscene.
        static func snakeProbability(forScore score: Int, weather: WeatherType) -> Double {
            // Allow snakes to start spawning at the score threshold, even if desert cutscene hasn't played yet
            guard score >= snakeStartScore else {
                return 0.0
            }
            
            let snakeStartLevel = snakeStartScore / scalingInterval
            let currentLevel = level(forScore: score)
            let effectiveLevel = currentLevel - snakeStartLevel
            
            // Higher probability in desert, but still spawn in other weathers at reduced rate
            let weatherMultiplier: Double = weather == .desert ? 1.0 : 0.5
            let baseProbability = min(maxSnakeProbability, baseSnakeProbability + (Double(effectiveLevel) * snakeProbabilityPerLevel))
            let finalProbability = baseProbability * weatherMultiplier
            
            return finalProbability
        }
        
        // MARK: - Cactus Spawning (Desert Only)
        
        /// Minimum score before cacti can appear in the desert
        static let cactusStartScore: Int = Weather.desertStart
        /// Base probability of a cactus spawning on a lily pad (once unlocked)
        static let baseCactusProbability: Double = 0.80
        /// Additional cactus probability per difficulty level
        static let cactusProbabilityPerLevel: Double = 0.80
        /// Maximum cactus spawn probability
        static let maxCactusProbability: Double = 0.80
        
        /// Calculates the probability of a cactus spawning. Returns 0 if not in desert score range.
        /// Checks both weather AND score to handle the desert cutscene transition properly.
        static func cactusProbability(forScore score: Int, weather: WeatherType) -> Double {
            // Check if score is in desert range (between desert start and space start)
            let isInDesertScore = score >= cactusStartScore && score < Weather.spaceStart
            // Allow spawning if EITHER the weather is desert OR we're in the desert score range
            guard (weather == .desert || isInDesertScore), score >= cactusStartScore else { return 0.0 }
            let cactusStartLevel = cactusStartScore / scalingInterval
            let currentLevel = level(forScore: score)
            let effectiveLevel = currentLevel - cactusStartLevel
            return min(maxCactusProbability, baseCactusProbability + (Double(effectiveLevel) * cactusProbabilityPerLevel))
        }
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
        
        static let logJumperCost = 300
        static let superJumpCost = 500
        static let rocketJumpCost = 500
        static let lifevest4PackCost = 100
        static let honey4PackCost = 20
        static let cannonJumpCost = 1000
        static let cross4PackCost = 20
        static let swatter4PackCost = 20
        static let axe4PackCost = 20
        static let comboBoostCost = 500
    }
    
    struct GameCenter {
        static let leaderboardID = "TopScores"
        static let dailyChallengeLeaderboardID = "DailyChallenge"
    }
    
    // MARK: - Debug Settings
    struct Debug {
        /// Set this to a non-zero value to start the game at a specific score for testing
        /// Examples:
        /// - 3000: Start at snake spawn threshold (space biome)
        /// - 10000: Start in desert
        /// - 19500: Start near space transition
        /// - 20000: Start in space
        static let startingScore: Int = 0  // Set to 0 to disable
        
        /// Enable to see weather transitions more quickly
        static let debugMode: Bool = false
    }
}

enum WeatherType: String, CaseIterable, Codable {
    case sunny, night, rain, winter, desert, space
    
    /// Returns whether this weather type can have precipitation (rain/snow)
    var hasPrecipitation: Bool {
        switch self {
        case .rain, .winter:
            return true
        case .sunny, .night, .desert, .space:
            return false
        }
    }
}
