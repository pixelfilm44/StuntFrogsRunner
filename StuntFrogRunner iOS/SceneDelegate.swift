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
        window.makeKeyAndVisible()
        print("✅ SceneDelegate: Made window key and visible")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Release resources if the scene is disconnected
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Resume game if paused
        // In the future: gameCoordinator?.didRequestResume()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Pause the game (e.g., incoming phone call)
        // In the future: gameCoordinator?.pauseGame()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Undo changes made on entering the background
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}