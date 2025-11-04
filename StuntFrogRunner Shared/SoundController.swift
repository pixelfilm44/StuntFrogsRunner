//
//  SoundController.swift
//  Complete Top-down lily pad hopping game
//  Sound and music management system
//

import AVFoundation
import SpriteKit

/// Manages all audio for the game including background music, sound effects, and audio settings
class SoundController: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SoundController()
    
    // MARK: - Audio Players
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var soundEffectPlayers: [String: AVAudioPlayer] = [:]
    private var audioEngine: AVAudioEngine
    
    // MARK: - Audio Settings
    @Published var isMusicEnabled: Bool = true {
        didSet { updateMusicVolume() }
    }
    
    @Published var areSoundEffectsEnabled: Bool = true {
        didSet { updateSoundEffectsVolume() }
    }
    
    @Published var musicVolume: Float = 0.7 {
        didSet { updateMusicVolume() }
    }
    
    @Published var soundEffectsVolume: Float = 0.8 {
        didSet { updateSoundEffectsVolume() }
    }
    
    // MARK: - Audio Categories
    enum SoundEffect: String, CaseIterable {
        // Frog Actions
        case frogJump = "frog_jump"
        case frogLand = "frog_land"
        case frogSplash = "frog_splash"
        case frogCroak = "frog_croak"
        
        // Slingshot
        case slingshotPull = "slingshot_pull"
        case slingshotRelease = "slingshot_release"
        case slingshotStretch = "slingshot_stretch"
        
        // Environment
        case waterRipple = "water_ripple"
        case lilyPadBounce = "lily_pad_bounce"
        case collectPowerup = "collect_powerup"
        case backgroundNature = "nature_ambience"
        
        // UI & Feedback
        case buttonTap = "button_tap"
        case menuTransition = "menu_transition"
        case scoreIncrease = "score_increase"
        case gameOver = "game_over"
        case levelComplete = "level_complete"
        
        // Hazards & Obstacles
        case logHit = "log_hit"
        case turtleShell = "turtle_shell"
        case dangerZone = "danger_zone"
    }
    
    enum BackgroundMusic: String, CaseIterable {
        case mainMenu = "menu_music"
        case gameplay = "gameplay_music"
        case gameOver = "game_over_music"
        case peaceful = "peaceful_pond"
        case energetic = "energetic_hopping"
    }
    
    // MARK: - Initialization
    private init() {
        audioEngine = AVAudioEngine()
        setupAudioSession()
        loadUserPreferences()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Background Music Management
    func playBackgroundMusic(_ music: BackgroundMusic, fadeIn: Bool = true) {
        guard isMusicEnabled else { return }
        
        // Stop current music
        if let currentPlayer = backgroundMusicPlayer {
            if fadeIn {
                fadeOutMusic(currentPlayer) { [weak self] in
                    self?.startNewMusic(music)
                }
            } else {
                currentPlayer.stop()
                startNewMusic(music)
            }
        } else {
            startNewMusic(music)
        }
    }
    
    private func startNewMusic(_ music: BackgroundMusic) {
        guard let url = Bundle.main.url(forResource: music.rawValue, withExtension: "mp3") else {
            print("Could not find music file: \(music.rawValue).mp3")
            return
        }
        
        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.numberOfLoops = -1 // Loop infinitely
            backgroundMusicPlayer?.volume = isMusicEnabled ? musicVolume : 0.0
            backgroundMusicPlayer?.play()
        } catch {
            print("Error playing background music: \(error.localizedDescription)")
        }
    }
    
    func stopBackgroundMusic(fadeOut: Bool = true) {
        guard let player = backgroundMusicPlayer else { return }
        
        if fadeOut {
            fadeOutMusic(player) { [weak self] in
                self?.backgroundMusicPlayer = nil
            }
        } else {
            player.stop()
            backgroundMusicPlayer = nil
        }
    }
    
    func pauseBackgroundMusic() {
        backgroundMusicPlayer?.pause()
    }
    
    func resumeBackgroundMusic() {
        backgroundMusicPlayer?.play()
    }
    
    // MARK: - Sound Effects Management
    func playSoundEffect(_ effect: SoundEffect, volume: Float? = nil, pitch: Float = 1.0) {
        guard areSoundEffectsEnabled else { return }
        
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else {
            print("Could not find sound effect: \(effect.rawValue).wav")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            let effectiveVolume = volume ?? soundEffectsVolume
            player.volume = effectiveVolume
            player.enableRate = true
            player.rate = pitch
            player.play()
            
            // Store reference to prevent deallocation
            soundEffectPlayers[effect.rawValue] = player
            
            // Remove reference after playback
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) { [weak self] in
                self?.soundEffectPlayers.removeValue(forKey: effect.rawValue)
            }
            
        } catch {
            print("Error playing sound effect: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Game-Specific Sound Methods
    func playFrogJumpSound(intensity: Float = 1.0) {
        let pitch = 0.8 + (intensity * 0.4) // Vary pitch based on jump intensity
        playSoundEffect(.frogJump, pitch: pitch)
    }
    
    func playSlingshotSound(pullDistance: Float) {
        let normalizedDistance = min(pullDistance / 100.0, 1.0)
        let pitch = 0.7 + (normalizedDistance * 0.6)
        playSoundEffect(.slingshotPull, pitch: pitch)
    }
    
    func playWaterSplash(severity: Float = 1.0) {
        let volume = soundEffectsVolume * severity
        playSoundEffect(.frogSplash, volume: volume)
    }
    
    func playCollectSound() {
        playSoundEffect(.collectPowerup, pitch: 1.2)
    }
    
    func playScoreSound(scoreValue: Int) {
        let pitch = 1.0 + min(Float(scoreValue) / 1000.0, 0.5)
        playSoundEffect(.scoreIncrease, pitch: pitch)
    }
    
    // MARK: - Volume and Settings Management
    private func updateMusicVolume() {
        backgroundMusicPlayer?.volume = isMusicEnabled ? musicVolume : 0.0
    }
    
    private func updateSoundEffectsVolume() {
        // This affects new sound effects; existing ones keep their volume
        UserDefaults.standard.set(areSoundEffectsEnabled, forKey: "soundEffectsEnabled")
        UserDefaults.standard.set(soundEffectsVolume, forKey: "soundEffectsVolume")
    }
    
    // MARK: - Audio Fading
    private func fadeOutMusic(_ player: AVAudioPlayer, duration: TimeInterval = 1.0, completion: @escaping () -> Void) {
        let fadeSteps = 20
        let stepDuration = duration / Double(fadeSteps)
        let volumeStep = player.volume / Float(fadeSteps)
        
        var currentStep = 0
        
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            player.volume = max(0, player.volume - volumeStep)
            
            if currentStep >= fadeSteps {
                timer.invalidate()
                player.stop()
                completion()
            }
        }
    }
    
    // MARK: - User Preferences
    private func loadUserPreferences() {
        isMusicEnabled = UserDefaults.standard.bool(forKey: "musicEnabled")
        areSoundEffectsEnabled = UserDefaults.standard.bool(forKey: "soundEffectsEnabled")
        musicVolume = UserDefaults.standard.float(forKey: "musicVolume")
        soundEffectsVolume = UserDefaults.standard.float(forKey: "soundEffectsVolume")
        
        // Set defaults if not previously saved
        if UserDefaults.standard.object(forKey: "musicEnabled") == nil {
            isMusicEnabled = true
        }
        if UserDefaults.standard.object(forKey: "soundEffectsEnabled") == nil {
            areSoundEffectsEnabled = true
        }
        if UserDefaults.standard.object(forKey: "musicVolume") == nil {
            musicVolume = 0.7
        }
        if UserDefaults.standard.object(forKey: "soundEffectsVolume") == nil {
            soundEffectsVolume = 0.8
        }
    }
    
    func saveUserPreferences() {
        UserDefaults.standard.set(isMusicEnabled, forKey: "musicEnabled")
        UserDefaults.standard.set(areSoundEffectsEnabled, forKey: "soundEffectsEnabled")
        UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
        UserDefaults.standard.set(soundEffectsVolume, forKey: "soundEffectsVolume")
    }
    
    // MARK: - Game State Audio Management
    func handleGameStateChange(to newState: GameState) {
        switch newState {
        case .menu:
            playBackgroundMusic(.mainMenu)
        case .playing:
            playBackgroundMusic(.gameplay)
        case .paused:
            pauseBackgroundMusic()
        case .gameOver:
            playBackgroundMusic(.gameOver)
            playSoundEffect(.gameOver)
        }
    }
    
    // MARK: - Cleanup
    func stopAllAudio() {
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
        
        for (_, player) in soundEffectPlayers {
            player.stop()
        }
        soundEffectPlayers.removeAll()
    }
    
    deinit {
        stopAllAudio()
    }
}

// MARK: - GameState Extension
extension GameState {
    case menu, playing, paused, gameOver
}