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
}

class GameStateManager {
    // MARK: - Properties
    var currentState: GameState = .menu {
        didSet {
            onStateChanged?(currentState, oldValue)
        }
    }
    
    var lastGameOverReason: GameOverReason?
    var pendingGameOverWorkItem: DispatchWorkItem?
    
    // MARK: - Flags
    var inputLocked: Bool = false
    var splashTriggered: Bool = false
    var hasLandedOnce: Bool = false
    
    // MARK: - Callbacks
    var onStateChanged: ((GameState, GameState) -> Void)?
    var onGameOver: ((GameOverReason) -> Void)?
    
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
        lastGameOverReason = nil
        pendingGameOverWorkItem?.cancel()
        pendingGameOverWorkItem = nil
        inputLocked = false
        splashTriggered = false
        hasLandedOnce = false
    }
}