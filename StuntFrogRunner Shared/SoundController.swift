//
//  SoundController.swift
//  Complete Top-down lily pad hopping game
//  Sound and music management system
//

import Foundation
import AVFoundation
internal import Combine

/// Manages all audio for the game including background music, sound effects, and audio settings
class SoundController: ObservableObject {

    private var currentBackgroundTrack: BackgroundMusic? = nil
    private var isPlayingSpecialTrack: Bool = false

    private var loopingPlayers: [SoundEffect: AVAudioPlayer] = [:]

    
    
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
    
    @Published var soundEffectsVolume: Float = 0.2 {
        didSet { updateSoundEffectsVolume() }
    }
    
    // MARK: - Audio Categories
    enum SoundEffect: String, CaseIterable {
        // Frog Actions
        case frogJump = "frog_jump"
        case frogLand = "frog_land"
        case frogSplash = "frog_splash"
        case frogCroak = "frog_croak"
        case frogSlide = "frog_slide"  // New ice sliding sound
        
        // Slingshot
        case slingshotPull = "slingshot_pull"
        case slingshotRelease = "slingshot_release"
        case slingshotStretch = "slingshot_stretch"
        
        // Environment
        case waterRipple = "water_ripple"
        case iceSlide = "ice_slide"  // New ice sliding sound
        case iceCrack = "ice_crack"  // New ice interaction sound
        case lilyPadBounce = "lily_pad_bounce"
        case collectPowerup = "collect_powerup"
        case backgroundNature = "nature_ambience"
        
        // Weather Effects
        case rain = "rain"
        case thunder = "thunder"
        case windStorm = "wind"
        case night = "night"
        
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
        case ghostly = "ghostly"
        case specialReward = "special_collect"
    }
    
    enum BackgroundMusic: String, CaseIterable {
        case mainMenu = "menu_music"
        case gameplay = "gameplay_music"
        case gameOver = "game_over_music"
        case peaceful = "peaceful_pond"
        case energetic = "energetic_hopping"
        case rocketFlight = "rocket_flight_music"
        case superJump = "super_jump_music"
        
        // Weather-specific background music
        case nightMusic = "night_music"
        case rainyMusic = "rainy_music"
        case stormMusic = "storm_music"
        case icyMusic = "icy_music"
    }
    
    // MARK: - Initialization
    private init() {
        print("🎵 Initializing SoundController...")
        self.audioEngine = AVAudioEngine()
        self.setupAudioSession()
        self.loadUserPreferences()
        print("🎵 SoundController initialized successfully")
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session setup successful")
        } catch {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Background Music Management
    func playBackgroundMusic(_ music: BackgroundMusic, fadeIn: Bool = true) {
        print("🎼 playBackgroundMusic requested: \(music.rawValue), fadeIn: \(fadeIn), isMusicEnabled: \(isMusicEnabled)")
        guard isMusicEnabled else { return }
        if currentBackgroundTrack == music {
            print("ℹ️ Requested music is already playing: \(music.rawValue)")
            return
        }
        
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
        print("🎼 startNewMusic requested: \(music.rawValue)")
        guard let url = Bundle.main.url(forResource: music.rawValue, withExtension: "mp3") else {
            print("Could not find music file: \(music.rawValue).mp3")
            return
        }
        
        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.numberOfLoops = -1 // Loop infinitely
            backgroundMusicPlayer?.volume = isMusicEnabled ? musicVolume : 0.0
            let didPlay = backgroundMusicPlayer?.play() ?? false
            currentBackgroundTrack = music
            print("🎼 Now playing: \(music.rawValue), didPlay: \(didPlay), volume: \(backgroundMusicPlayer?.volume ?? -1)")
        } catch {
            print("Error playing background music: \(error.localizedDescription)")
        }
    }
    
    func stopBackgroundMusic(fadeOut: Bool = true) {
        guard let player = backgroundMusicPlayer else { return }
        
        if fadeOut {
            fadeOutMusic(player) { [weak self] in
                self?.backgroundMusicPlayer = nil
                self?.currentBackgroundTrack = nil
                self?.isPlayingSpecialTrack = false
            }
        } else {
            player.stop()
            backgroundMusicPlayer = nil
            currentBackgroundTrack = nil
            isPlayingSpecialTrack = false
        }
    }
    
    func pauseBackgroundMusic() {
        backgroundMusicPlayer?.pause()
    }
    
    func resumeBackgroundMusic() {
        backgroundMusicPlayer?.play()
    }
    
    func playLooping(_ effect: SoundEffect, volume: Float = 1.0) {
        // If already looping, just update volume and return
        if let player = loopingPlayers[effect] {
            player.volume = volume
            if !player.isPlaying { player.play() }
            return
        }
    }

        

    func stopLooping(_ effect: SoundEffect) {
        loopingPlayers[effect]?.stop()
        loopingPlayers[effect] = nil
    }

    // Optionally: stop all loops
    func stopAllLoops() {
        loopingPlayers.values.forEach { $0.stop() }
        loopingPlayers.removeAll()
    }
    
    
    // MARK: - Sound Effects Management
    func playSoundEffect(_ effect: SoundEffect, volume: Float? = nil, pitch: Float = 1.0) {
        print("🔊 Attempting to play sound effect: \(effect.rawValue)")
        guard areSoundEffectsEnabled else { 
            print("🔇 Sound effects are disabled")
            return 
        }
        
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3") else {
            print("❌ Could not find sound effect: \(effect.rawValue).mp3")
            // For missing frog_slide, use a fallback sound
            if effect == .frogSlide {
                print("🔄 Using fallback sound for frog_slide")
                playSoundEffect(.frogLand, volume: volume, pitch: max(0.7, (pitch ?? 1.0) - 0.2))
            }
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            let effectiveVolume = volume ?? soundEffectsVolume
            player.volume = effectiveVolume
            player.enableRate = true
            player.rate = pitch
            let didStart = player.play()
            
            print("🔊 Sound effect \(effect.rawValue) - Started: \(didStart), Volume: \(effectiveVolume), Pitch: \(pitch)")
            
            // Create a unique key to avoid overwriting concurrent sounds
            let uniqueKey = "\(effect.rawValue)_\(UUID().uuidString.prefix(8))"
            
            // Store reference to prevent deallocation
            soundEffectPlayers[uniqueKey] = player
            
            // Remove reference after playbook with safety check and stronger weak reference handling
            let duration = max(player.duration, 1.0) // Ensure minimum duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) { [weak self] in
                guard let self = self else { return }
                self.soundEffectPlayers.removeValue(forKey: uniqueKey)
            }
            
        } catch {
            print("❌ Error playing sound effect: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Game-Specific Sound Methods
    func playFrogJumpSound(intensity: Float = 1.0) {
        let pitch = 0.8 + (intensity * 0.4) // Vary pitch based on jump intensity
        playSoundEffect(.frogJump, pitch: pitch)
    }
    
    func playFrogLand(intensity: Float = 1.0) {
        let pitch = 0.9 + (intensity * 0.2) // Vary pitch based on landing intensity
        playSoundEffect(.frogLand, pitch: pitch)
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
    
    func playIceSlide(velocity: Float = 1.0) {
        let pitch = 0.8 + (velocity * 0.4) // Vary pitch based on sliding speed
        let volume = soundEffectsVolume * min(1.0, velocity)
        playSoundEffect(.iceSlide, volume: volume, pitch: pitch)
    }
    
    func playIceCrack() {
        playSoundEffect(.iceCrack, pitch: Float.random(in: 0.9...1.1))
    }
    
    func playFrogSlide(intensity: Float = 1.0) {
        let pitch = 0.9 + (intensity * 0.3)
        playSoundEffect(.frogSlide, pitch: pitch)
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
        // Don't save areSoundEffectsEnabled since it's always true
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
        // Load with proper defaults
        if UserDefaults.standard.object(forKey: "musicEnabled") == nil {
            isMusicEnabled = true
        } else {
            isMusicEnabled = UserDefaults.standard.bool(forKey: "musicEnabled")
        }
        
        // Always enable sound effects - no user preference for this
        // Clear any existing preference that might be set to false
        UserDefaults.standard.removeObject(forKey: "soundEffectsEnabled")
        areSoundEffectsEnabled = true
        
        if UserDefaults.standard.object(forKey: "musicVolume") == nil {
            musicVolume = 0.7
        } else {
            musicVolume = UserDefaults.standard.float(forKey: "musicVolume")
        }
        
        if UserDefaults.standard.object(forKey: "soundEffectsVolume") == nil {
            soundEffectsVolume = 0.2
        } else {
            soundEffectsVolume = UserDefaults.standard.float(forKey: "soundEffectsVolume")
        }
        
        print("🎵 Loaded preferences - Music: \(isMusicEnabled), SFX: \(areSoundEffectsEnabled), MusicVol: \(musicVolume), SFXVol: \(soundEffectsVolume)")
    }
    
    func saveUserPreferences() {
        UserDefaults.standard.set(isMusicEnabled, forKey: "musicEnabled")
        // Don't save areSoundEffectsEnabled since it's always true
        UserDefaults.standard.set(musicVolume, forKey: "musicVolume")
        UserDefaults.standard.set(soundEffectsVolume, forKey: "soundEffectsVolume")
    }
    
    // MARK: - Game State Audio Management
    func handleGameStateChange(to newState: GameState) {
        if isPlayingSpecialTrack {
            switch newState {
            case .paused:
                pauseBackgroundMusic()
                return
            case .abilitySelection, .initialUpgradeSelection:
                // Lower volume but keep current special track
                backgroundMusicPlayer?.volume = (isMusicEnabled ? musicVolume : 0.0) * 0.5
                return
            default:
                // Ignore other state-driven music changes while a special track is active
                print("🔒 Special track active (\(currentBackgroundTrack?.rawValue ?? "none")); ignoring state change to \(newState)")
                return
            }
        }
        
        switch newState {
        case .menu:
            playBackgroundMusic(.mainMenu)
        case .initialUpgradeSelection:
            let currentWeather = WeatherManager.shared.weather
            playWeatherMusic(for: currentWeather)
            // Keep menu music playing during initial upgrade selection
        case .playing:
            // Use weather-appropriate music instead of hardcoded gameplay music
            let currentWeather = WeatherManager.shared.weather
            playWeatherMusic(for: currentWeather)
        case .paused:
            pauseBackgroundMusic()
        case .abilitySelection:
            // Keep current music but lower volume
            backgroundMusicPlayer?.volume = (isMusicEnabled ? musicVolume : 0.0) * 0.5
        case .gameOver:
            playBackgroundMusic(.gameOver)
            playSoundEffect(.gameOver)
        }
    }
    
    func resumeFromAbilitySelection() {
        // Restore normal volume when returning from ability selection
        if isPlayingSpecialTrack {
            backgroundMusicPlayer?.volume = isMusicEnabled ? musicVolume : 0.0
        } else {
            updateMusicVolume()
        }
    }
    
    // MARK: - Special Ability Audio Management
    func playRocketFlightMusic() {
        print("🚀 Playing rocket flight music")
        isPlayingSpecialTrack = true
        playBackgroundMusic(.rocketFlight, fadeIn: true)
    }
    
    func playSuperJumpMusic() {
        print("⚡ Playing super jump music")
        isPlayingSpecialTrack = true
        playBackgroundMusic(.superJump, fadeIn: true)
    }
    
    func returnToGameplayMusic() {
        print("🎮 Returning to normal gameplay music")
        isPlayingSpecialTrack = false
        // Use weather-appropriate music instead of hardcoded gameplay music
        let currentWeather = WeatherManager.shared.weather
        playWeatherMusic(for: currentWeather)
    }
    
    // MARK: - Explicit Starters (for callers that don't want to rely on state changes)
    /// Explicitly start gameplay background music and clear any special-track state.
    func startGameplayMusic() {
        print("🎮 startGameplayMusic() called explicitly")
        isPlayingSpecialTrack = false
        let currentWeather = WeatherManager.shared.weather
        
        playWeatherMusic(for: currentWeather)
    }
    
    /// Call this when the frog activates rocket ability
    func handleRocketAbilityActivated() {
        playRocketFlightMusic()
        playSoundEffect(.collectPowerup, pitch: 0.8) // Lower pitch for rocket activation
    }
    
    /// Call this when the frog activates super jump ability
    func handleSuperJumpAbilityActivated() {
        playSuperJumpMusic()
        playSoundEffect(.frogJump, pitch: 1.5) // Higher pitch for super jump
    }
    
    /// Call this when special abilities end
    func handleSpecialAbilityEnded() {
        returnToGameplayMusic()
    }
    
    // MARK: - Weather Audio Management
    func playWeatherMusic(for weather: WeatherType) {
        print("🎵 playWeatherMusic called for weather: \(weather), isMusicEnabled: \(isMusicEnabled)")
        guard isMusicEnabled else { 
            print("🎵 Music is disabled, skipping weather music")
            return 
        }
        
        let musicTrack: BackgroundMusic
        switch weather {
        case .day:
            musicTrack = .gameplay
        case .night:
            musicTrack = .nightMusic
        case .rain:
            musicTrack = .rainyMusic
        case .ice:
            musicTrack = .icyMusic
        case .storm:
            musicTrack = .stormMusic
        case .winter:
            musicTrack = .icyMusic
        case .stormy:
            musicTrack = .stormMusic
        }
        
        print("🎵 Selected music track: \(musicTrack.rawValue) for weather: \(weather)")
        print("🎵 Current background track before change: \(currentBackgroundTrack?.rawValue ?? "nil")")
        
        // Check if the music file exists before attempting to play
        guard Bundle.main.url(forResource: musicTrack.rawValue, withExtension: "mp3") != nil else {
            print("❌ Music file not found: \(musicTrack.rawValue).mp3")
            // Fallback to gameplay music if weather-specific music doesn't exist
            if musicTrack != .gameplay {
                print("🎵 Falling back to gameplay music")
                playBackgroundMusic(.gameplay, fadeIn: false)
            }
            return
        }
        
        // Don't call stopAllAudio() as it interferes with immediate playback
        // Instead, just stop background music and let playBackgroundMusic handle the transition
        stopBackgroundMusic(fadeOut: false)
        
        // Force play the weather-specific music by temporarily clearing the current track
        currentBackgroundTrack = nil
        print("🎵 About to call playBackgroundMusic with: \(musicTrack.rawValue)")
        playBackgroundMusic(musicTrack, fadeIn: false)
        print("🎵 Called playBackgroundMusic, current track should now be: \(currentBackgroundTrack?.rawValue ?? "nil")")
    }
    
    func playWeatherAmbience(for weather: WeatherType) {
        switch weather {
        case .day:
            playSoundEffect(.backgroundNature, volume: 0.3)
            
        case .night:
            playSoundEffect(.night, volume: 0.4)
            
        case .rain:
            playSoundEffect(.rain, volume: 0.5)
            
        case .ice:
            playSoundEffect(.iceCrack, volume: 0.2)
            
        case .storm:
            playSoundEffect(.windStorm, volume: 0.4)
            // Thunder will be played by lightning effects
            
        case .winter:
            playSoundEffect(.iceCrack, volume: 0.2)
            
        case .stormy:
            playSoundEffect(.windStorm, volume: 0.4)
            // Thunder will be played by lightning effects
        }
        
        print("🌦️ Playing weather ambience for \(weather)")
    }
    
    func playThunder() {
        playSoundEffect(.thunder, volume: 0.6, pitch: Float.random(in: 0.8...1.2))
    }
    
    // MARK: - Cleanup
    func stopAllAudio() {
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
        currentBackgroundTrack = nil
        isPlayingSpecialTrack = false
        
        // Safely stop all sound effects
        let playersToStop = soundEffectPlayers
        soundEffectPlayers.removeAll()
        
        for (_, player) in playersToStop {
            player.stop()
        }
    }
    
    deinit {
        stopAllAudio()
    }
    
    // MARK: - Wind Effects Sound
    
    /// Play wind interaction sound when wind affects the frog
    func playWindInteraction(intensity: Float) {
        // You can implement this with an appropriate wind sound effect
        // For now, we'll use an existing sound as a placeholder
        playSoundEffect(.windStorm, volume: min(intensity * 0.3, 0.2))
    }
}

