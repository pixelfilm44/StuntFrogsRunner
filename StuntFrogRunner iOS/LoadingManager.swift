//
//  LoadingManager.swift
//  Stuntfrog Superstar
//
//  Manages app loading tasks and resources
//

import Foundation
import UIKit
import GameKit
import AVFoundation

class LoadingManager {
    
    // MARK: - Properties
    static let shared = LoadingManager()
    private var loadingTasks: [LoadingTask] = []
    private var completedTasks = 0
    
    // Progress callback
    var onProgressUpdate: ((Float, String) -> Void)?
    var onLoadingComplete: (() -> Void)?
    
    private init() {}
    
    // MARK: - Loading Task Structure
    
    struct LoadingTask {
        let name: String
        let task: (@escaping () -> Void) -> Void
    }
    
    // MARK: - Public Methods
    
    func startLoading() {
        print("🔄 LoadingManager: Starting loading tasks")
        
        completedTasks = 0
        setupLoadingTasks()
        executeLoadingTasks()
    }
    
    // MARK: - Private Methods
    
    private func setupLoadingTasks() {
        loadingTasks = [
            LoadingTask(name: "Connecting to Game Center") { [weak self] completion in
                // Authenticate Game Center early in the loading process
                ScoreManager.shared.authenticateGameCenter { [weak self] in
                    // Return the presenting view controller (LoadingViewController in this case)
                    return self?.getPresentingViewController()
                }
                
                // Give Game Center a moment to authenticate, then continue
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🎮 LoadingManager: Game Center authentication initiated")
                    completion()
                }
            },
            
            LoadingTask(name: "Initializing Game Engine") { [weak self] completion in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    // Simulate game engine initialization
                    print("🎮 LoadingManager: Game engine initialized")
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            },
            
            LoadingTask(name: "Loading Textures") { [weak self] completion in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) {
                    // Simulate texture loading
                    self?.preloadTextures()
                    print("🖼 LoadingManager: Textures loaded")
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            },
            
            LoadingTask(name: "Loading Audio") { [weak self] completion in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
                    // Simulate audio loading
                    self?.preloadAudio()
                    print("🔊 LoadingManager: Audio loaded")
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            },
            
            LoadingTask(name: "Preparing Game Data") { [weak self] completion in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
                    // Simulate game data preparation
                    print("📊 LoadingManager: Game data prepared")
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            },
            
            LoadingTask(name: "Finalizing") { [weak self] completion in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                    // Simulate final setup
                    print("✨ LoadingManager: Setup finalized")
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        ]
    }
    
    private func executeLoadingTasks() {
        guard !loadingTasks.isEmpty else {
            onLoadingComplete?()
            return
        }
        
        let totalTasks = loadingTasks.count
        
        for (index, task) in loadingTasks.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2) {
                self.onProgressUpdate?(Float(self.completedTasks) / Float(totalTasks), task.name)
                
                task.task { [weak self] in
                    self?.completedTasks += 1
                    
                    let progress = Float(self?.completedTasks ?? 0) / Float(totalTasks)
                    self?.onProgressUpdate?(progress, task.name)
                    
                    if self?.completedTasks == totalTasks {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.onLoadingComplete?()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Asset Preloading
    
    private func getPresentingViewController() -> UIViewController? {
        // Get the current root view controller (LoadingViewController)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.rootViewController
        }
        return nil
    }
    
    private func preloadTextures() {
        // Here you could preload game textures
        // For example:
        // let _ = UIImage(named: "frog_sprite")
        // let _ = UIImage(named: "background_1")
        // etc.
    }
    
    private func preloadAudio() {
        // Preload all sound effects
        let soundEffects: [String] = [
            // Frog Actions
            "frog_jump",
            "frog_land", 
            "frog_splash",
            "frog_croak",
            
            // Slingshot
            "slingshot_pull",
            "slingshot_release",
            "slingshot_stretch",
            
            // Environment
            "water_ripple",
            "lily_pad_bounce",
            "collect_powerup",
            "nature_ambience",
            
            // UI & Feedback
            "button_tap",
            "menu_transition",
            "score_increase",
            "game_over",
            "level_complete",
            
            // Hazards & Obstacles
            "log_hit",
            "turtle_shell",
            "danger_zone"
        ]
        
        // Preload all background music
        let backgroundMusic: [String] = [
            "menu_music",
            "gameplay_music", 
            "game_over_music",
            "peaceful_pond",
            "energetic_hopping",
            "rocket_flight_music",
            "super_jump_music"
        ]
        
        // Preload sound effects
        for soundName in soundEffects {
            if let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") {
                do {
                    let _ = try AVAudioPlayer(contentsOf: url)
                    print("🔊 Preloaded sound effect: \(soundName)")
                } catch {
                    print("⚠️ Failed to preload sound effect \(soundName): \(error.localizedDescription)")
                }
            } else {
                print("⚠️ Sound effect file not found: \(soundName).mp3")
            }
        }
        
        // Preload background music
        for musicName in backgroundMusic {
            if let url = Bundle.main.url(forResource: musicName, withExtension: "mp3") {
                do {
                    let _ = try AVAudioPlayer(contentsOf: url)
                    print("🎵 Preloaded background music: \(musicName)")
                } catch {
                    print("⚠️ Failed to preload background music \(musicName): \(error.localizedDescription)")
                }
            } else {
                print("⚠️ Background music file not found: \(musicName).mp3")
            }
        }
    }
}