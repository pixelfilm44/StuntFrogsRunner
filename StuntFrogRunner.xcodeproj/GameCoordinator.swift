//
//  GameCoordinator.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 11/20/25.
//

import UIKit

/// Coordinates the flow of the game between menu, gameplay, and other screens
class GameCoordinator {
    
    // MARK: - Properties
    
    private let window: UIWindow
    
    // MARK: - Initialization
    
    init(window: UIWindow) {
        self.window = window
        print("🎮 GameCoordinator: Initialized with window")
    }
    
    // MARK: - Public Methods
    
    /// Starts the game flow by showing the initial screen
    func start() {
        print("🎮 GameCoordinator: start() called")
        
        // Show the menu as the initial screen
        showMenu()
    }
    
    /// Shows the main menu
    func showMenu() {
        print("🎮 GameCoordinator: Showing menu")
        
        let menuViewController = MenuViewController()
        menuViewController.coordinator = self
        
        window.rootViewController = menuViewController
        print("✅ GameCoordinator: Set MenuViewController as root")
    }
    
    /// Starts the game
    func startGame() {
        print("🎮 GameCoordinator: Starting game")
        
        let gameViewController = GameViewController()
        gameViewController.modalPresentationStyle = .fullScreen
        
        window.rootViewController?.present(gameViewController, animated: true) {
            print("✅ GameCoordinator: Game view presented")
        }
    }
}
