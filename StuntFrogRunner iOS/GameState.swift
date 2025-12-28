import UIKit
import SpriteKit

enum GameState {
    case loading, menu, shop, challenges, initialUpgrade, playing, paused, upgradeSelection, gameOver
}

enum GameMode: Equatable {
    case endless
    case beatTheBoat
    case dailyChallenge(DailyChallenge)
}

enum RaceLossReason {
    case outrun
    case outOfHealth
    case drowned
    case missedLaunchPad
}

enum RaceResult: Equatable {
    case win
    case lose(reason: RaceLossReason)
}

protocol GameCoordinatorDelegate: AnyObject {
    func didRequestResume()
    func didSelectUpgrade(_ upgradeId: String)
    func gameDidEnd(score: Int, coins: Int, raceResult: RaceResult?)
    func triggerUpgradeMenu(hasFullHealth: Bool, distanceTraveled: Int, currentWeather: WeatherType, currentMaxHealth: Int)
    func showShop()
    func didFinishLoading()
    func pauseGame()
    func authenticateGameCenter()
    func showLeaderboard()
    func showChallenges()
    func startRace()
}

class GameCoordinator: GameCoordinatorDelegate {
    
    weak var window: UIWindow?
    var currentState: GameState = .loading
    private var pendingGameMode: GameMode = .endless
    
    let storage = UserDefaults.standard
    
    // Track the race win streak
    private var raceWinStreak: Int = 0
    
    // Track daily challenge start time
    private var dailyChallengeStartTime: Date?
    
    init(window: UIWindow?) {
        self.window = window
    }
    
    func start() {
        showLoading()
    }
    
    // ... (Loading logic same as previous) ...
    
    func showLoading() {
        currentState = .loading
        let loadingVC = LoadingViewController()
        loadingVC.coordinator = self
        window?.rootViewController = loadingVC
    }
    
    func didFinishLoading() {
        showMenu(animated: true)
    }
    
    func showMenu(animated: Bool = false) {
        // Reset the win streak when returning to the main menu
        raceWinStreak = 0
        
        currentState = .menu
        let menuVC = MenuViewController()
        menuVC.coordinator = self
        
        if animated {
            UIView.transition(with: window!, duration: 0.5, options: .transitionCrossDissolve, animations: {
                self.window?.rootViewController = menuVC
            }, completion: nil)
        } else {
            window?.rootViewController = menuVC
        }
    }
    
    // MARK: - Game Center Logic
    
    func authenticateGameCenter() {
        guard let rootVC = window?.rootViewController else { return }
        GameCenterManager.shared.authenticateLocalPlayer(presentingVC: rootVC)
    }
    
    func showLeaderboard() {
        guard let rootVC = window?.rootViewController else { return }
        GameCenterManager.shared.showLeaderboard(presentingVC: rootVC, leaderboardID: Configuration.GameCenter.leaderboardID)
    }
    
    func showChallenges() {
        currentState = .challenges
        let challengesVC = ChallengesViewController()
        challengesVC.coordinator = self
        UIView.transition(with: window!, duration: 0.3, options: .transitionFlipFromRight, animations: {
            self.window?.rootViewController = challengesVC
        }, completion: nil)
    }
    
    // ... (Shop, Start Game, Launch Game, Trigger Upgrade, Pause logic same as previous) ...
    
    func showShop() {
        currentState = .shop
        let shopVC = ShopViewController()
        shopVC.coordinator = self
        shopVC.modalPresentationStyle = .fullScreen
        UIView.transition(with: window!, duration: 0.3, options: .transitionFlipFromRight, animations: {
            self.window?.rootViewController = shopVC
        }, completion: nil)
    }
    
    func startGame() {
        pendingGameMode = .endless
        currentState = .initialUpgrade
        let upgradeVC = UpgradeViewController()
        upgradeVC.coordinator = self
        // At game start, the frog always has full health, so don't offer heart refill
        upgradeVC.hasFullHealth = true
        upgradeVC.currentWeather = .sunny // Game always starts at sunny
        upgradeVC.currentMaxHealth = PersistenceManager.shared.healthLevel
        upgradeVC.modalPresentationStyle = .overFullScreen
        upgradeVC.modalTransitionStyle = .crossDissolve
        window?.rootViewController?.present(upgradeVC, animated: false)
    }
    
    func startRace() {
        pendingGameMode = .beatTheBoat
        currentState = .initialUpgrade
        let upgradeVC = UpgradeViewController()
        upgradeVC.coordinator = self
        upgradeVC.hasFullHealth = true
        upgradeVC.isForRace = true // Prevent rockets from being an option in races
        upgradeVC.currentWeather = .sunny // Races start at sunny
        upgradeVC.currentMaxHealth = PersistenceManager.shared.healthLevel
        upgradeVC.modalPresentationStyle = .overFullScreen
        upgradeVC.modalTransitionStyle = .crossDissolve
        window?.rootViewController?.present(upgradeVC, animated: false)
    }
    
    func startDailyChallenge() {
        let challenge = DailyChallenges.shared.getTodaysChallenge()
        pendingGameMode = .dailyChallenge(challenge)
        dailyChallengeStartTime = Date()
        
        currentState = .initialUpgrade
        let upgradeVC = UpgradeViewController()
        upgradeVC.coordinator = self
        upgradeVC.hasFullHealth = true
        upgradeVC.isDailyChallenge = true
        upgradeVC.currentDailyChallenge = challenge
        upgradeVC.currentWeather = challenge.climate // Use the challenge's climate
        upgradeVC.currentMaxHealth = PersistenceManager.shared.healthLevel
        upgradeVC.modalPresentationStyle = .overFullScreen
        upgradeVC.modalTransitionStyle = .crossDissolve
        window?.rootViewController?.present(upgradeVC, animated: false)
    }
    
    private func launchGame(with initialUpgradeId: String?, gameMode: GameMode) {
        currentState = .playing
        let skView = SKView(frame: window?.bounds ?? .zero)
        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .aspectFill
        scene.coordinator = self
        scene.gameMode = gameMode
        
        // If it's a race, configure it with the current streak data
        if case .beatTheBoat = gameMode {
            scene.boatSpeedMultiplier = 1.0 + (CGFloat(raceWinStreak) * 0.10)
            scene.raceRewardBonus = raceWinStreak * 100
        }
        
        if let upgradeId = initialUpgradeId {
            scene.initialUpgrade = upgradeId
        }
        
        let gameVC = GameViewController()
        gameVC.view = skView
        skView.presentScene(scene)
        
        UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.window?.rootViewController = gameVC
        }, completion: nil)
    }
    
    func triggerUpgradeMenu(hasFullHealth: Bool, distanceTraveled: Int, currentWeather: WeatherType, currentMaxHealth: Int) {
        guard currentState == .playing else { return }
        currentState = .upgradeSelection
        let upgradeVC = UpgradeViewController()
        upgradeVC.coordinator = self
        upgradeVC.hasFullHealth = hasFullHealth
        upgradeVC.distanceTraveled = distanceTraveled
        upgradeVC.currentWeather = currentWeather
        upgradeVC.currentMaxHealth = currentMaxHealth
        
        // Set daily challenge info if in daily challenge mode
        if case .dailyChallenge(let challenge) = pendingGameMode {
            upgradeVC.isDailyChallenge = true
            upgradeVC.currentDailyChallenge = challenge
        }
        
        upgradeVC.modalPresentationStyle = .overFullScreen
        upgradeVC.modalTransitionStyle = .crossDissolve
        window?.rootViewController?.present(upgradeVC, animated: false)
    }
    
    func pauseGame() {
        guard currentState == .playing else { return }
        currentState = .paused
        let pauseVC = PauseViewController()
        pauseVC.coordinator = self
        pauseVC.modalPresentationStyle = .overFullScreen
        pauseVC.modalTransitionStyle = .crossDissolve
        window?.rootViewController?.present(pauseVC, animated: false)
    }
    
    func didRequestResume() {
        currentState = .playing
    }
    
    func didSelectUpgrade(_ upgradeId: String) {
        if currentState == .initialUpgrade {
            launchGame(with: upgradeId, gameMode: pendingGameMode)
        } else {
            window?.rootViewController?.dismiss(animated: false, completion: {
                NotificationCenter.default.post(name: .didSelectUpgrade, object: nil, userInfo: ["id": upgradeId])
                self.didRequestResume()
            })
        }
    }
    
    func gameDidEnd(score: Int, coins: Int, raceResult: RaceResult?) {
        guard currentState != .gameOver else { return }
        currentState = .gameOver
        
        // Stop all sound effects when game ends
        SoundManager.shared.stopAllSoundEffects()
        SoundManager.shared.stopWeatherSFX()
        
        var isNewHigh = false
        var isDailyChallengeMode = false
        var challengeCompleted = false
        
        // Check if this was a daily challenge
        if case .dailyChallenge = pendingGameMode {
            isDailyChallengeMode = true
            // Daily challenges are 1000m (score of 2000)
            if score >= 1000 {
                challengeCompleted = true
                if let startTime = dailyChallengeStartTime {
                    let timeElapsed = Date().timeIntervalSince(startTime)
                    DailyChallenges.shared.recordRun(timeInSeconds: timeElapsed, completed: true)
                    print("✅ Daily challenge completed in \(String(format: "%.1f", timeElapsed))s")
                    
                    // Submit time to Game Center (convert to milliseconds for leaderboard)
                    let timeInMilliseconds = Int(timeElapsed * 1000)
                    GameCenterManager.shared.submitScore(timeInMilliseconds, leaderboardID: Configuration.GameCenter.dailyChallengeLeaderboardID)
                    print("🎮 Submitted daily challenge time to Game Center: \(timeInMilliseconds)ms")
                }
                // Award 100 coins for completing the daily challenge
                PersistenceManager.shared.addCoins(100)
                print("🪙 Awarded 100 coins for completing daily challenge!")
            } else {
                // Record failed attempt
                DailyChallenges.shared.recordRun(timeInSeconds: 0, completed: false)
            }
        } else if raceResult == nil {
            // Endless mode
            isNewHigh = PersistenceManager.shared.saveScore(score)
            if isNewHigh {
                GameCenterManager.shared.submitScore(score, leaderboardID: Configuration.GameCenter.leaderboardID)
            }
            // Reset race streak if returning from endless mode
            raceWinStreak = 0
            ChallengeManager.shared.setWinningStreak(0)
        } else {
            // Race mode
            if case .win = raceResult {
                raceWinStreak += 1
            } else {
                raceWinStreak = 0
            }
            ChallengeManager.shared.setWinningStreak(raceWinStreak)
        }
        
        // Only add coins in non-daily-challenge modes
        if !isDailyChallengeMode {
            PersistenceManager.shared.addCoins(coins)
        }
        
        let gameOverVC = GameOverViewController()
        gameOverVC.score = score
        gameOverVC.runCoins = coins
        gameOverVC.isNewHighScore = isNewHigh
        gameOverVC.raceResult = raceResult
        gameOverVC.isDailyChallenge = isDailyChallengeMode
        gameOverVC.dailyChallengeCompleted = challengeCompleted
        
        // Pass the new win streak to the game over screen if it was a race
        if raceResult != nil {
            gameOverVC.winStreak = self.raceWinStreak
        }
        
        gameOverVC.coordinator = self
        gameOverVC.modalPresentationStyle = .overFullScreen
        gameOverVC.modalTransitionStyle = .crossDissolve
        
        window?.rootViewController?.present(gameOverVC, animated: true)
    }
}

extension Notification.Name {
    static let didSelectUpgrade = Notification.Name("didSelectUpgrade")
    static let challengeCompleted = Notification.Name("challengeCompleted")
}
