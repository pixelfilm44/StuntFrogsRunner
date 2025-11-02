//
//  SceneDelegate.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/12/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else {
            print("❌ Failed to get windowScene")
            return
        }
        
        print("🐸 SceneDelegate: Setting up window...")
        
        // Create window
        window = UIWindow(windowScene: windowScene)
        window?.frame = windowScene.coordinateSpace.bounds
        
        // Create LoadingViewController first
        let loadingViewController = LoadingViewController()
        
        // Set loading completion handler to transition to game
        loadingViewController.onLoadingComplete = { [weak self] in
            self?.transitionToGame()
        }
        
        // Set as root view controller
        window?.rootViewController = loadingViewController
        window?.makeKeyAndVisible()
        
        print("✅ SceneDelegate: Window configured with loading screen")
        print("📱 Window bounds: \(window?.bounds ?? .zero)")
        print("🎬 Root VC: LoadingViewController")
    }
    
    private func transitionToGame() {
        print("🎮 SceneDelegate: Transitioning to game")
        
        // Create GameViewController
        let gameViewController = GameViewController()
        
        // Perform transition
        if let window = window {
            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: {
                window.rootViewController = gameViewController
            }, completion: { _ in
                print("✅ SceneDelegate: Transition to game complete")
            })
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {}
    
    func sceneDidBecomeActive(_ scene: UIScene) {}
    
    func sceneWillResignActive(_ scene: UIScene) {}
    
    func sceneWillEnterForeground(_ scene: UIScene) {}
    
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
