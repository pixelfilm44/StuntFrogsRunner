import UIKit
import SpriteKit

enum GameState {
    case loading, menu, shop, initialUpgrade, playing, paused, upgradeSelection, gameOver
}

protocol GameCoordinatorDelegate: AnyObject {
    func didRequestResume()
    func didSelectUpgrade(_ upgradeId: String)
    func gameDidEnd(score: Int, coins: Int)
    func triggerUpgradeMenu()
    func showShop()
    func didFinishLoading()
    func pauseGame()
    // NEW:
    func authenticateGameCenter()
    func showLeaderboard()
}

class GameCoordinator: GameCoordinatorDelegate {
    
    weak var window: UIWindow?
    var currentState: GameState = .loading
    
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
        currentState = .initialUpgrade
        let upgradeVC = UpgradeViewController()
        upgradeVC.coordinator = self
        upgradeVC.modalPresentationStyle = .overFullScreen
        upgradeVC.modalTransitionStyle = .crossDissolve
        window?.rootViewController?.present(upgradeVC, animated: false)
    }
    
    private func launchGame(with initialUpgradeId: String?) {
        currentState = .playing
        let skView = SKView(frame: window?.bounds ?? .zero)
        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .aspectFill
        scene.coordinator = self
        
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
    
    func triggerUpgradeMenu() {
        guard currentState == .playing else { return }
        currentState = .upgradeSelection
        let upgradeVC = UpgradeViewController()
        upgradeVC.coordinator = self
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
            launchGame(with: upgradeId)
        } else {
            window?.rootViewController?.dismiss(animated: false, completion: {
                NotificationCenter.default.post(name: .didSelectUpgrade, object: nil, userInfo: ["id": upgradeId])
                self.didRequestResume()
            })
        }
    }
    
    func gameDidEnd(score: Int, coins: Int) {
        guard currentState != .gameOver else { return }
        currentState = .gameOver
        
        let isNewHigh = PersistenceManager.shared.saveScore(score)
        PersistenceManager.shared.addCoins(coins)
        
        // NEW: Submit to Game Center if new high score
        if isNewHigh {
            GameCenterManager.shared.submitScore(score, leaderboardID: Configuration.GameCenter.leaderboardID)
        }
        
        let gameOverVC = GameOverViewController()
        gameOverVC.score = score
        gameOverVC.runCoins = coins
        gameOverVC.isNewHighScore = isNewHigh
        gameOverVC.coordinator = self
        gameOverVC.modalPresentationStyle = .overFullScreen
        gameOverVC.modalTransitionStyle = .crossDissolve
        
        window?.rootViewController?.present(gameOverVC, animated: true)
    }
}

extension Notification.Name {
    static let didSelectUpgrade = Notification.Name("didSelectUpgrade")
}
