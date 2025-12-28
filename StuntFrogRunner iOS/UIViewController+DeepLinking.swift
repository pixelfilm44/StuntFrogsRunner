//
//  UIViewController+DeepLinking.swift
//  StuntFrogRunner iOS
//
//  Created for deep linking support
//

import UIKit

extension UIViewController {
    /// Finds the topmost presented view controller in the hierarchy
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? navigation
        }
        
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        
        return self
    }
}

extension GameCoordinator {
    /// Shows the daily challenge screen from a deep link
    /// This method is called when a user taps a challenge link from a friend
    func showDailyChallengeFromDeepLink() {
        // Dismiss any presented view controllers
        if let window = window {
            window.rootViewController?.dismiss(animated: false) { [weak self] in
                // Show menu first (if not already showing)
                self?.showMenu()
                
                // Then navigate to daily challenge
                // Add a small delay to ensure menu is presented
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.startDailyChallenge()
                }
            }
        }
    }
}
