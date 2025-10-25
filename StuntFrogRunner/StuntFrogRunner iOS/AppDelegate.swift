//
//  AppDelegate.swift
//  Stuntfrog Superstar
//
//  Application delegate for lifecycle management
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🚀 AppDelegate: Application launched")
        
        // Prevent device from sleeping during gameplay
        UIApplication.shared.isIdleTimerDisabled = true
        
        return true
    }
    
    // MARK: - UISceneSession Lifecycle
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("🎬 AppDelegate: Configuring scene session")
        
        // Create scene configuration
        let configuration = UISceneConfiguration(name: "Default Configuration",
                                                  sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        
        return configuration
    }
    
    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        print("🗑 AppDelegate: Scene sessions discarded")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Pause game when app goes to background
        NotificationCenter.default.post(name: Notification.Name("PauseGame"), object: nil)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save game state if needed
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Restore game state if needed
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Resume game or show menu
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Save any final game data
    }
}
