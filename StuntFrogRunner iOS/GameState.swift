import UIKit
import SpriteKit

enum GameState {
    case loading, menu, shop, challenges, initialUpgrade, playing, paused, upgradeSelection, gameOver
}

enum GameMode {
    case endless
    case beatTheBoat
}

enum RaceLossReason {
    case outrun
    case outOfHealth
    case drowned
}

enum RaceResult: Equatable {
    case win
    case lose(reason: RaceLossReason)
}

protocol GameCoordinatorDelegate: AnyObject {
    func didRequestResume()
    func didSelectUpgrade(_ upgradeId: String)
    func gameDidEnd(score: Int, coins: Int, raceResult: RaceResult?)
    func triggerUpgradeMenu(hasFullHealth: Bool)
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
    
    func triggerUpgradeMenu(hasFullHealth: Bool) {
        guard currentState == .playing else { return }
        currentState = .upgradeSelection
        let upgradeVC = UpgradeViewController()
        upgradeVC.coordinator = self
        upgradeVC.hasFullHealth = hasFullHealth
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
        if raceResult == nil {
            isNewHigh = PersistenceManager.shared.saveScore(score)
            // NEW: Submit to Game Center if new high score
            if isNewHigh {
                GameCenterManager.shared.submitScore(score, leaderboardID: Configuration.GameCenter.leaderboardID)
            }
        }
        
        PersistenceManager.shared.addCoins(coins)
        
        let gameOverVC = GameOverViewController()
        gameOverVC.score = score
        gameOverVC.runCoins = coins
        gameOverVC.isNewHighScore = isNewHigh
        gameOverVC.raceResult = raceResult
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
