//
//  AppDelegate.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 11/20/25.
//


import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var gameCoordinator: GameCoordinator?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🚀 AppDelegate: didFinishLaunchingWithOptions called")
        
        
        for family in UIFont.familyNames {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  - \(name)")
            }
        }

        // Preload assets as early as possible to prevent lag during gameplay start
        SoundManager.shared.preloadSounds()
        print("✅ AppDelegate: Sounds preloaded")
        
        // Load daily challenges (uses cached data if available)
        DailyChallenges.shared.refreshIfNeeded { success in
            if success {
                print("✅ AppDelegate: Daily challenges ready")
            } else {
                print("⚠️ AppDelegate: Using cached/fallback challenges")
            }
        }
        
        // IMPORTANT: Don't create window here if using scenes
        // The window will be created in SceneDelegate
        print("⚠️ AppDelegate: Not creating window - waiting for scene delegate")
        
        return true
    }

    // MARK: UISceneSession Lifecycle - Only called if app uses scenes
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("🔵 AppDelegate: configurationForConnecting called - app is configured for scenes!")
        print("   Session role: \(connectingSceneSession.role)")
        
        // Return a configuration that specifies SceneDelegate
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        config.sceneClass = UIWindowScene.self
        
        print("   ✅ Set config.delegateClass to: \(String(describing: config.delegateClass))")
        print("   ✅ Set config.sceneClass to: \(String(describing: config.sceneClass))")
        print("   This should cause SceneDelegate.scene(_:willConnectTo:) to be called")
        
        return config
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        print("🔵 AppDelegate: didDiscardSceneSessions called")
    }
}
