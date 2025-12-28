//
//  SceneDelegate.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 11/20/25.
//


import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var gameCoordinator: GameCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("🔵 SceneDelegate: scene(_:willConnectTo:) called")
        
        // 1. Capture the scene
        guard let windowScene = (scene as? UIWindowScene) else {
            print("❌ SceneDelegate: Failed to cast to UIWindowScene")
            return
        }
        print("✅ SceneDelegate: Got windowScene")
        
        // 2. Create the window manually (No Storyboards used for maximum control)
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        print("✅ SceneDelegate: Created window with bounds: \(window.bounds)")
        
        // 3. Initialize the Coordinator
        // The Coordinator handles setting the rootViewController, so we just pass the window
        gameCoordinator = GameCoordinator(window: window)
        print("✅ SceneDelegate: Created GameCoordinator")
        
        // 4. Start the Game Flow
        gameCoordinator?.start()
        print("✅ SceneDelegate: Called start() on coordinator")
        
        // 5. Make Key and Visible
        // Defer this to the next run loop to avoid mutating collections during enumeration
        DispatchQueue.main.async {
            window.makeKeyAndVisible()
            print("✅ SceneDelegate: Made window key and visible")
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Release resources if the scene is disconnected
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Resume game if paused
        // In the future: gameCoordinator?.didRequestResume()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Pause the game when the app is interrupted or enters the background.
        print("🔵 SceneDelegate: sceneWillResignActive - Pausing game")
        gameCoordinator?.pauseGame()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Undo changes made on entering the background
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    // MARK: - Deep Linking
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url)
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Handle universal links
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            handleDeepLink(url)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("🔗 Deep link received: \(url)")
        print("🔗 URL scheme: \(url.scheme ?? "none")")
        print("🔗 URL host: \(url.host ?? "none")")
        print("🔗 URL path: \(url.path)")
        
        // Parse URL: stuntfrog://challenge/YYYY-MM-DD
        // or: https://stuntfrog.app/challenge/YYYY-MM-DD
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        let pathComponents = url.path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        print("🔗 Path components: \(pathComponents)")
        
        // Handle custom URL scheme: stuntfrog://challenge/YYYY-MM-DD
        if scheme == "stuntfrog" {
            if host == "challenge" {
                // Format: stuntfrog://challenge/2025-12-28
                let challengeDate = pathComponents.first
                print("🔗 Challenge date from path: \(challengeDate ?? "today")")
                
                GameCenterChallengeManager.shared.recordChallengeReceived()
                handleChallengeDeepLink(date: challengeDate)
                return
            }
        }
        
        // Handle universal links: https://stuntfrog.app/challenge/YYYY-MM-DD
        if scheme == "https" || scheme == "http" {
            if pathComponents.first == "challenge" {
                let challengeDate = pathComponents.count > 1 ? pathComponents[1] : nil
                print("🔗 Challenge date from universal link: \(challengeDate ?? "today")")
                
                GameCenterChallengeManager.shared.recordChallengeReceived()
                handleChallengeDeepLink(date: challengeDate)
                return
            }
        }
        
        print("❌ Invalid URL format or unrecognized deep link")
    }
    
    private func handleChallengeDeepLink(date: String?) {
        // If a specific date is provided, could validate it matches today's challenge
        // For now, just open today's challenge
        
        print("🎮 Opening daily challenge from deep link")
        
        // Ensure we have a coordinator
        guard let coordinator = gameCoordinator else {
            print("❌ No coordinator available")
            return
        }
        
        // Show an alert welcoming them to the challenge
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Challenge Accepted! 🐸",
                message: "Ready to take on today's daily challenge?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Let's Go!", style: .default) { _ in
                // Navigate to the daily challenge
                coordinator.showDailyChallengeFromDeepLink()
            })
            
            alert.addAction(UIAlertAction(title: "Later", style: .cancel))
            
            // Present on the topmost view controller
            if let topVC = self.window?.rootViewController?.topMostViewController() {
                topVC.present(alert, animated: true)
            }
        }
    }
}
