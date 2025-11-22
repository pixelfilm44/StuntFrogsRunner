import UIKit
import GameKit

// FIX: Updated protocol from GKGameCenterViewControllerDelegate to GKGameCenterControllerDelegate
class GameCenterManager: NSObject, GKGameCenterControllerDelegate {
    
    static let shared = GameCenterManager()
    
    private override init() {}
    
    // MARK: - Authentication
    
    func authenticateLocalPlayer(presentingVC: UIViewController) {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { gcAuthVC, error in
            if let vc = gcAuthVC {
                // Game Center needs to show a login screen
                presentingVC.present(vc, animated: true)
            } else if localPlayer.isAuthenticated {
                // User is authenticated
                print("Game Center: Authenticated")
            } else {
                // Error or cancelled
                if let error = error {
                    print("Game Center Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Score Submission
    
    func submitScore(_ score: Int, leaderboardID: String) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        
        // Submit score to the specific leaderboard
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]) { error in
            if let error = error {
                print("Error submitting score: \(error.localizedDescription)")
            } else {
                print("Score \(score) submitted to \(leaderboardID)")
            }
        }
    }
    
    // MARK: - Leaderboard UI
    
    func showLeaderboard(presentingVC: UIViewController, leaderboardID: String) {
        let gcVC = GKGameCenterViewController(state: .leaderboards)
        // FIX: This assignment now works because we conform to GKGameCenterControllerDelegate
        gcVC.gameCenterDelegate = self
        gcVC.leaderboardIdentifier = leaderboardID
        presentingVC.present(gcVC, animated: true)
    }
    
    // MARK: - GKGameCenterControllerDelegate
    
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
