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
        
        // Create GameViewController programmatically
        let gameViewController = GameViewController()
        
        // Set as root view controller
        window?.rootViewController = gameViewController
        window?.makeKeyAndVisible()
        
        print("✅ SceneDelegate: Window configured and visible")
        print("📱 Window bounds: \(window?.bounds ?? .zero)")
        print("🎮 Root VC: \(String(describing: window?.rootViewController))")
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {}
    
    func sceneDidBecomeActive(_ scene: UIScene) {}
    
    func sceneWillResignActive(_ scene: UIScene) {}
    
    func sceneWillEnterForeground(_ scene: UIScene) {}
    
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
