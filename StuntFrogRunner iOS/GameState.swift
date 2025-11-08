//
//  GameState.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/25/25.
//


//
//  GameStateManager.swift
//  StuntFrog Runner
//
//  Manages game states and transitions

import Foundation

enum GameState {
    case menu
    case initialUpgradeSelection  // New state for start-of-game upgrade selection
    case playing
    case paused
    case abilitySelection
    case gameOver
}

enum GameOverReason {
    case splash
    case healthDepleted
    case scrolledOffScreen
    case tooSlow
    case timeUp
}

enum WaterState {
    case water  // Normal water behavior - frog can drown
    case ice    // Ice behavior - frog slides instead of drowning
}

class GameStateManager {
    // MARK: - Properties
    var currentState: GameState = .menu {
        didSet {
            onStateChanged?(currentState, oldValue)
        }
    }
    
    // MARK: - Water State Management
    var waterState: WaterState = .water {
        didSet {
            print("💧 Water state changed to: \(waterState)")
            onWaterStateChanged?(waterState, oldValue)
        }
    }
    
    var lastGameOverReason: GameOverReason?
    var pendingGameOverWorkItem: DispatchWorkItem?
    
    // MARK: - Flags
    var inputLocked: Bool = false {
        didSet {
            if inputLocked && !oldValue {
                // Input just got locked - notify slingshot controller
                onInputLocked?()
            }
        }
    }
    var splashTriggered: Bool = false
    var hasLandedOnce: Bool = false
    
    // MARK: - Callbacks
    var onStateChanged: ((GameState, GameState) -> Void)?
    var onWaterStateChanged: ((WaterState, WaterState) -> Void)?
    var onGameOver: ((GameOverReason) -> Void)?
    var onInputLocked: (() -> Void)?  // New callback for when input gets locked
    
    // MARK: - State Management
    func transitionToMenu() {
        currentState = .menu
    }
    
    func startPlaying() {
        currentState = .playing
        inputLocked = false
    }
    
    func pauseGame() {
        currentState = .paused
    }
    
    func showAbilitySelection() {
        currentState = .abilitySelection
    }
    
    // MARK: - Water State Management
    func setWaterState(_ newState: WaterState) {
        waterState = newState
    }
    
    func toggleWaterState() {
        switch waterState {
        case .water:
            waterState = .ice
        case .ice:
            waterState = .water
        }
    }
    
    // MARK: - Convenience Methods for Level Design
    func createWaterLevel() {
        waterState = .water
        print("🌊 Level configured with WATER - frog can drown")
    }
    
    func createIceLevel() {
        waterState = .ice
        print("🧊 Level configured with ICE - frog will slide instead of drowning")
    }
    
    /*
     USAGE EXAMPLES:
     
     // Create a standard water level (default behavior)
     stateManager.createWaterLevel()
     
     // Create an ice level where the frog slides instead of drowning
     stateManager.createIceLevel()
     
     // Toggle between water types programmatically
     stateManager.toggleWaterState()
     
     // Set specific water state
     stateManager.setWaterState(.ice)
     stateManager.setWaterState(.water)
     
     // Check current water state
     if stateManager.waterState == .ice {
         print("Currently on ice!")
     }
     */
    
    func triggerGameOver(_ reason: GameOverReason, delay: TimeInterval = 0) {
        lastGameOverReason = reason
        
        pendingGameOverWorkItem?.cancel()
        
        if delay > 0 {
            let work = DispatchWorkItem { [weak self] in
                self?.completeGameOver(reason)
            }
            pendingGameOverWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            completeGameOver(reason)
        }
    }
    
    private func completeGameOver(_ reason: GameOverReason) {
        currentState = .gameOver
        onGameOver?(reason)
    }
    
    func cancelPendingGameOver() {
        pendingGameOverWorkItem?.cancel()
        pendingGameOverWorkItem = nil
    }
    
    // MARK: - Input Management
    func lockInput(for duration: TimeInterval = 0.3) {
        inputLocked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.inputLocked = false
        }
    }
    
    func forceUnlockInput() {
        inputLocked = false
        print("🔓 Input forcefully unlocked")
    }
    
    // MARK: - Reset
    func reset() {
        currentState = .menu
        waterState = .water  // Reset to default water state
        lastGameOverReason = nil
        pendingGameOverWorkItem?.cancel()
        pendingGameOverWorkItem = nil
        inputLocked = false
        splashTriggered = false
        hasLandedOnce = false
    }
}
