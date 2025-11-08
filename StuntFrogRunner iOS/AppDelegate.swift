//
//  AppDelegate.swift
//  Stuntfrog Superstar
//
//  Application delegate for lifecycle management
//

import UIKit

// MARK: - Game Lifecycle Notifications
extension Notification.Name {
    static let pauseGame = Notification.Name("PauseGame")
    static let saveGameState = Notification.Name("SaveGameState")
    static let prepareGameResume = Notification.Name("PrepareGameResume")
    static let appBecameActive = Notification.Name("AppBecameActive")
}

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
        print("⏸ AppDelegate: App will resign active - pausing game")
        // Pause game when app loses focus (switching apps, control center, notifications, etc.)
        NotificationCenter.default.post(name: .pauseGame, object: nil)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("🌙 AppDelegate: App entered background - ensuring game is paused")
        // Ensure game is paused and save current state
        NotificationCenter.default.post(name: .pauseGame, object: nil)
        NotificationCenter.default.post(name: .saveGameState, object: nil)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("🌅 AppDelegate: App will enter foreground - preparing to resume")
        // App is coming back from background, prepare for potential resume
        NotificationCenter.default.post(name: .prepareGameResume, object: nil)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("▶️ AppDelegate: App became active - ready to resume if appropriate")
        // App is fully active again - let game decide whether to auto-resume or show pause menu
        NotificationCenter.default.post(name: .appBecameActive, object: nil)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Save any final game data
    }
}
