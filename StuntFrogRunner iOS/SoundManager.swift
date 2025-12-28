import UIKit
import AVFoundation
import CoreHaptics
import SpriteKit

// MARK: - Sound Manager
class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()
    private var players: [String: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?
    private var currentMusic: String?
    private var weatherSFXPlayer: AVAudioPlayer?
    private var currentWeatherSFX: String?
    
    // Music track names
    enum Music: String, CaseIterable {
        case menu = "menu_music"
        case gameplay = "gameplay_music"
        case gameplay2 = "gameplay_music2"
        case gameplay3 = "gameplay_music3"
        case rocketFlight = "rocket_flight_music"
        case crocRomp = "crocRomp"
        case race = "race"
        case superJump = "superjump"
    }
    
    // Track to play after current track finishes (for sequential playback)
    private var nextMusic: Music?
    
    // Weather ambient sound effects
    enum WeatherSFX: String {
        case rain = "rain"
        case night = "night"
        case winter = "wind"
        case desert = "windrattle"
        case space = "space" // You'll need to create this audio file
    }
    
    private override init() {
        super.init()
    }
    
    func preloadSounds() {
        let sounds = ["jump", "land", "coin", "hit", "splash", "rocket", "ghost", "crocodileMashing", "crocodileRide", "thunder", "gameOver", "ouch", "laser","eat","splat"]
        for sound in sounds {
            if let url = Bundle.main.url(forResource: sound, withExtension: "mp3") {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    players[sound] = player
                }
            }
        }
    }
    
    func playThunder() {
        play("thunder")
    }
    
    func play(_ name: String) {
        guard let player = players[name] else { return }
        if player.isPlaying { player.stop(); player.currentTime = 0 }
        player.play()
    }
    
    // MARK: - Music Playback
    
    func playMusic(_ music: Music, fadeDuration: TimeInterval = 0.5) {
        let name = music.rawValue
        
        // Don't restart if already playing the same track
        guard currentMusic != name else { return }
        
        // Fade out current music if playing
        if let currentPlayer = musicPlayer, currentPlayer.isPlaying {
            fadeOut(player: currentPlayer, duration: fadeDuration) { [weak self] in
                self?.startMusic(name: name, fadeDuration: fadeDuration)
            }
        } else {
            startMusic(name: name, fadeDuration: fadeDuration)
        }
    }
    
    private func startMusic(name: String, fadeDuration: TimeInterval) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("Music file not found: \(name).mp3")
            return
        }
        
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.delegate = self
            
            // Set up random cycling for gameplay music tracks
            let gameplayTracks: [Music] = [.gameplay, .gameplay2, .gameplay3]
            if let currentTrack = Music(rawValue: name), gameplayTracks.contains(currentTrack) {
                musicPlayer?.numberOfLoops = 0 // Play once, then trigger next random track
                
                // Pick a random track that's different from the current one
                var availableTracks = gameplayTracks.filter { $0 != currentTrack }
                nextMusic = availableTracks.randomElement()
            } else {
                musicPlayer?.numberOfLoops = -1 // Loop indefinitely for non-gameplay tracks
                nextMusic = nil
            }
            
            musicPlayer?.volume = 0
            musicPlayer?.prepareToPlay()
            musicPlayer?.play()
            currentMusic = name
            
            // Fade in
            fadeIn(player: musicPlayer, duration: fadeDuration, targetVolume: 0.6)
        } catch {
            print("Failed to load music: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Check if this was the music player and we have a next track queued
        if player === musicPlayer, let next = nextMusic {
            startMusic(name: next.rawValue, fadeDuration: 0.5)
        }
    }
    
    func stopMusic(fadeDuration: TimeInterval = 0.5) {
        guard let player = musicPlayer, player.isPlaying else { return }
        nextMusic = nil  // Clear any queued track
        fadeOut(player: player, duration: fadeDuration) { [weak self] in
            self?.musicPlayer?.stop()
            self?.currentMusic = nil
        }
    }
    
    func pauseMusic() {
        musicPlayer?.pause()
    }
    
    func resumeMusic() {
        musicPlayer?.play()
    }
    
    func setMusicVolume(_ volume: Float) {
        musicPlayer?.volume = max(0, min(1, volume))
    }
    
    // MARK: - Unified Pause/Resume
    
    /// Pauses all audio (music and weather SFX) - useful when game is paused
    func pauseAll() {
        pauseMusic()
        pauseWeatherSFX()
    }
    
    /// Resumes all audio (music and weather SFX) - useful when game is unpaused
    func resumeAll() {
        resumeMusic()
        resumeWeatherSFX()
    }
    
    // MARK: - Stop All Sounds
    
    func stopAllSoundEffects() {
        for player in players.values {
            player.stop()
            player.currentTime = 0
        }
    }
    
    func stopAll(fadeDuration: TimeInterval = 0.5) {
        stopAllSoundEffects()
        stopWeatherSFX(fadeDuration: fadeDuration)
        stopMusic(fadeDuration: fadeDuration)
    }
    
    // MARK: - Weather Sound Effects
    
    /// Plays or transitions to weather-specific ambient sound effects.
    /// Pass `nil` to stop all weather SFX.
    func playWeatherSFX(_ sfx: WeatherSFX?, fadeDuration: TimeInterval = 0.5) {
        let name = sfx?.rawValue
        
        // Don't restart if already playing the same SFX
        guard currentWeatherSFX != name else { return }
        
        // Fade out current weather SFX if playing
        if let currentPlayer = weatherSFXPlayer, currentPlayer.isPlaying {
            fadeOut(player: currentPlayer, duration: fadeDuration) { [weak self] in
                if let sfxName = name {
                    self?.startWeatherSFX(name: sfxName, fadeDuration: fadeDuration)
                } else {
                    self?.weatherSFXPlayer = nil
                    self?.currentWeatherSFX = nil
                }
            }
        } else if let sfxName = name {
            startWeatherSFX(name: sfxName, fadeDuration: fadeDuration)
        } else {
            currentWeatherSFX = nil
        }
    }
    
    /// Convenience method to play weather SFX based on WeatherType.
    /// Automatically maps weather types to appropriate sound effects.
    func playWeatherSFX(for weather: WeatherType, fadeDuration: TimeInterval = 0.5) {
        let sfx: WeatherSFX?
        switch weather {
        case .rain:
            sfx = .rain
        case .night:
            sfx = .night
        case .winter:
            sfx = .winter
        case .desert:
            sfx = .desert
        case .space:
            sfx = .space
        case .sunny:
            sfx = nil  // No ambient sound for sunny weather
        }
        playWeatherSFX(sfx, fadeDuration: fadeDuration)
    }
    
    private func startWeatherSFX(name: String, fadeDuration: TimeInterval) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            print("Weather SFX file not found: \(name).mp3")
            return
        }
        
        do {
            weatherSFXPlayer = try AVAudioPlayer(contentsOf: url)
            weatherSFXPlayer?.numberOfLoops = -1 // Loop indefinitely
            weatherSFXPlayer?.volume = 0
            weatherSFXPlayer?.prepareToPlay()
            weatherSFXPlayer?.play()
            currentWeatherSFX = name
            
            // Fade in (lower volume than music so it doesn't overpower)
            fadeIn(player: weatherSFXPlayer, duration: fadeDuration, targetVolume: 0.4)
        } catch {
            print("Failed to load weather SFX: \(error.localizedDescription)")
        }
    }
    
    func stopWeatherSFX(fadeDuration: TimeInterval = 0.5) {
        guard let player = weatherSFXPlayer, player.isPlaying else {
            currentWeatherSFX = nil
            return
        }
        fadeOut(player: player, duration: fadeDuration) { [weak self] in
            self?.weatherSFXPlayer?.stop()
            self?.currentWeatherSFX = nil
        }
    }
    
    func pauseWeatherSFX() {
        weatherSFXPlayer?.pause()
    }
    
    func resumeWeatherSFX() {
        weatherSFXPlayer?.play()
    }
    
    func setWeatherSFXVolume(_ volume: Float) {
        weatherSFXPlayer?.volume = max(0, min(1, volume))
    }
    
    // MARK: - Fade Effects
    
    private func fadeIn(player: AVAudioPlayer?, duration: TimeInterval, targetVolume: Float) {
        guard let player = player else { return }
        
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = targetVolume / Float(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                player.volume = volumeStep * Float(i)
            }
        }
    }
    
    private func fadeOut(player: AVAudioPlayer, duration: TimeInterval, completion: @escaping () -> Void) {
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeStep = player.volume / Float(steps)
        let initialVolume = player.volume
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                player.volume = initialVolume - (volumeStep * Float(i))
                
                if i == steps {
                    completion()
                }
            }
        }
    }
}

// MARK: - Haptics Manager
class HapticsManager {
    static let shared = HapticsManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
    }
    
    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light: impactLight.impactOccurred()
        case .medium: impactMedium.impactOccurred()
        case .heavy: impactHeavy.impactOccurred()
        default: break
        }
    }
    
    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
    }
}

// MARK: - VFX Manager
/// Handles particle emitters for weather and interactions.
class VFXManager {
    static let shared = VFXManager()
    
    private var thunderTimer: Timer?
    private weak var currentScene: SKScene?
    private var lightningOverlay: SKSpriteNode?
    
    // Properties for weather transitions
    private var weatherOverlay: SKSpriteNode?
    private var activeEmitter: SKEmitterNode?
    
    private init() {}
    
    // MARK: - Weather Transitions
    
    /// Smoothly transitions the visual weather effects over a duration.
    func transitionWeather(from oldWeather: WeatherType, to newWeather: WeatherType, in scene: GameScene, duration: TimeInterval) {
        self.currentScene = scene

        // 1. Transition weather sound effects
        SoundManager.shared.playWeatherSFX(for: newWeather, fadeDuration: duration)

        // 2. Setup or update the screen overlay for darkness/color tinting
        if self.weatherOverlay == nil, let cam = scene.camera {
            let overlay = SKSpriteNode(color: .clear, size: scene.size)
            overlay.zPosition = Layer.overlay
            self.weatherOverlay = overlay
            cam.addChild(overlay)
        }

        let targetColor = overlayColor(for: newWeather)
        let colorAction = SKAction.colorize(with: targetColor, colorBlendFactor: 1.0, duration: duration)
        weatherOverlay?.run(colorAction)
        
        // 2. Fade out the old particle emitter
        if let oldEmitter = activeEmitter {
            let fadeOutAction = SKAction.customAction(withDuration: duration) { node, elapsedTime in
                guard let emitter = node as? SKEmitterNode, let initialRate = emitter.userData?["initialRate"] as? CGFloat else { return }
                let progress = elapsedTime / CGFloat(duration)
                emitter.particleBirthRate = initialRate * (1.0 - progress)
            }
            let removeAction = SKAction.removeFromParent()
            oldEmitter.run(SKAction.sequence([fadeOutAction, removeAction]))
            self.activeEmitter = nil
        }

        // 3. Fade in the new particle emitter
        if let newEmitter = createEmitter(for: newWeather, in: scene) {
            let targetBirthRate = newEmitter.particleBirthRate
            newEmitter.userData = ["initialRate": targetBirthRate]
            newEmitter.particleBirthRate = 0
            
            scene.weatherNode.addChild(newEmitter)
            self.activeEmitter = newEmitter
            
            let fadeInAction = SKAction.customAction(withDuration: duration) { node, elapsedTime in
                guard let emitter = node as? SKEmitterNode else { return }
                let progress = elapsedTime / CGFloat(duration)
                emitter.particleBirthRate = targetBirthRate * progress
            }
            newEmitter.run(fadeInAction)
        }

        // 4. Manage the thunder cycle
        if newWeather == .rain {
            let wait = SKAction.wait(forDuration: duration)
            let startThunder = SKAction.run { [weak self] in
                self?.startThunderCycle(in: scene)
            }
            scene.run(SKAction.sequence([wait, startThunder]))
        } else {
            stopThunderCycle()
        }
    }
    
    private func overlayColor(for weather: WeatherType) -> UIColor {
        switch weather {
        case .sunny:
            return .clear
        case .night:
            return .black.withAlphaComponent(0.65)
        case .rain:
            return .black.withAlphaComponent(0.35)
        case .winter:
            return .white.withAlphaComponent(0.25)
        case .desert:
            return .orange.withAlphaComponent(0.20)
        case .space:
            return .black.withAlphaComponent(0.85) // Very dark for space
        }
    }

    private func createEmitter(for weather: WeatherType, in scene: SKScene) -> SKEmitterNode? {
        let sceneSize = scene.size
        let emitter: SKEmitterNode?
        
        switch weather {
        case .rain:
            emitter = createRainEmitter(width: sceneSize.width)
            // Position well above the top of the screen to ensure full coverage
            emitter?.position = CGPoint(x: 0, y: sceneSize.height / 2 + 100)
        case .winter:
            emitter = createSnowEmitter(width: sceneSize.width)
            // Position well above the top of the screen to ensure full coverage
            emitter?.position = CGPoint(x: 0, y: sceneSize.height / 2 + 100)
        case .night:
            emitter = createFirefliesEmitter(width: sceneSize.width, height: sceneSize.height)
            emitter?.position = .zero
            emitter?.zPosition = Layer.pad + 1 // Fireflies should be in the world, not stuck to screen
        case .space:
            emitter = createStarsEmitter(width: sceneSize.width, height: sceneSize.height)
            emitter?.position = .zero
            emitter?.zPosition = Layer.pad + 1
        case .sunny:
            emitter = nil
        case .desert:
            emitter = nil
        }
        return emitter
    }
    
    // MARK: - Thunder & Lightning
    
    /// Starts the thunder and lightning effect cycle for rain weather.
    /// Lightning strikes occur at random intervals with screen flashes and thunder sounds.
    /// - Parameters:
    ///   - scene: The scene to display lightning effects in
    ///   - minInterval: Minimum seconds between lightning strikes (default 4)
    ///   - maxInterval: Maximum seconds between lightning strikes (default 12)
    func startThunderCycle(in scene: SKScene, minInterval: TimeInterval = 8, maxInterval: TimeInterval = 12) {
        stopThunderCycle()
        currentScene = scene
        scheduleNextThunder(minInterval: minInterval, maxInterval: maxInterval)
    }
    
    /// Stops the thunder and lightning cycle.
    func stopThunderCycle() {
        thunderTimer?.invalidate()
        thunderTimer = nil
        lightningOverlay?.removeFromParent()
        lightningOverlay = nil
        currentScene = nil
    }
    
    func spawnImpactWave(at position: CGPoint, in scene: SKScene) {
        // Try to find worldNode, but fallback to scene if not found
        let parentNode = scene.childNode(withName: "//worldNode") ?? scene
        
        // Create the wave ring
        let wave = SKShapeNode(circleOfRadius: 30)
        wave.position = position
        wave.strokeColor = .purple
        wave.fillColor = .purple.withAlphaComponent(0.3)
        wave.lineWidth = 15
        wave.zPosition = 1000 // High zPosition to ensure visibility
        wave.alpha = 1.0 // Start fully visible
        parentNode.addChild(wave)
        
        // Scale up dramatically (4x size, not just 40 pixels)
        let scaleUp = SKAction.scale(to: 12.0, duration: 1.5)
        scaleUp.timingMode = .easeOut
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        
        let group = SKAction.group([scaleUp, fadeOut])
        let remove = SKAction.removeFromParent()
        
        wave.run(SKAction.sequence([group, remove]))
    }

    
    private func scheduleNextThunder(minInterval: TimeInterval, maxInterval: TimeInterval) {
        let interval = TimeInterval.random(in: minInterval...maxInterval)
        thunderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.triggerLightning()
            self?.scheduleNextThunder(minInterval: minInterval, maxInterval: maxInterval)
        }
    }
    
    /// Triggers a single lightning strike with flash and thunder sound.
    func triggerLightning() {
        guard let scene = currentScene, let camera = scene.camera else { return }
        
        // Create or reuse the lightning overlay
        if lightningOverlay == nil {
            let overlay = SKSpriteNode(color: .white, size: scene.size)
            overlay.position = .zero  // Center on camera (camera is already at screen center)
            overlay.zPosition = 9999 // Above everything
            overlay.alpha = 0
            overlay.blendMode = .add
            camera.addChild(overlay)  // Add to camera instead of scene
            lightningOverlay = overlay
        }
        
        guard let overlay = lightningOverlay else { return }
        
        // Lightning flash sequence - multiple quick flashes for realism
        let flash1 = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.8, duration: 0.05),
            SKAction.fadeAlpha(to: 0.2, duration: 0.05),
        ])
        let flash2 = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.03),
            SKAction.fadeAlpha(to: 0.3, duration: 0.08),
        ])
        let flash3 = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.04),
            SKAction.fadeOut(withDuration: 0.3),
        ])
        
        let fullFlash = SKAction.sequence([flash1, flash2, flash3])
        overlay.run(fullFlash)
        
        // Play thunder sound with a slight delay (light travels faster than sound)
        let thunderDelay = TimeInterval.random(in: 0.1...0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + thunderDelay) {
            SoundManager.shared.playThunder()
            // Haptic feedback for thunder rumble
            HapticsManager.shared.playImpact(.heavy)
        }
    }
    
    /// Creates a lightning bolt sprite effect (optional visual enhancement).
    /// - Parameters:
    ///   - startPoint: Top point of the lightning bolt
    ///   - endPoint: Bottom point of the lightning bolt
    ///   - scene: The scene to add the bolt to
    func createLightningBolt(from startPoint: CGPoint, to endPoint: CGPoint, in scene: SKScene) {
        let path = createLightningPath(from: startPoint, to: endPoint)
        
        let bolt = SKShapeNode(path: path)
        bolt.strokeColor = .white
        bolt.lineWidth = 3
        bolt.glowWidth = 8
        bolt.zPosition = 9998
        bolt.alpha = 1.0
        
        scene.addChild(bolt)
        
        // Quick flash and fade
        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ])
        bolt.run(fadeOut)
    }
    
    private func createLightningPath(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        
        let segments = 8
        let dx = (end.x - start.x) / CGFloat(segments)
        let dy = (end.y - start.y) / CGFloat(segments)
        
        var currentPoint = start
        for i in 1..<segments {
            let offsetX = CGFloat.random(in: -30...30)
            let nextPoint = CGPoint(
                x: start.x + dx * CGFloat(i) + offsetX,
                y: start.y + dy * CGFloat(i)
            )
            path.addLine(to: nextPoint)
            currentPoint = nextPoint
        }
        path.addLine(to: end)
        
        return path
    }
    
    func spawnSplash(at position: CGPoint, in scene: SKScene) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(imageNamed: "spark") // Uses default circle if missing
        emitter.particleBirthRate = 100
        emitter.numParticlesToEmit = 15
        emitter.particleLifetime = 0.4
        emitter.particlePosition = position
        emitter.particleSpeed = 100
        emitter.particleSpeedRange = 50
        emitter.emissionAngle = CGFloat.pi / 2
        emitter.emissionAngleRange = CGFloat.pi / 3
        emitter.particleAlpha = 0.6
        emitter.particleAlphaSpeed = -1.0
        emitter.particleScale = 0.3
        emitter.particleColor = .white
        scene.addChild(emitter)
        
        let wait = SKAction.wait(forDuration: 1.0)
        let remove = SKAction.removeFromParent()
        emitter.run(SKAction.sequence([wait, remove]))
    }
    
    /// Spawns a puff of smoke/cloud for the air jump ability.
    /// - Parameters:
    ///   - position: World position to spawn the puff.
    ///   - parentNode: The node to add the effect to (typically the world node).
    func spawnAirJumpPuff(at position: CGPoint, parentNode: SKNode) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = SKTexture(imageNamed: "spark") // A generic small white particle
        emitter.position = position
        emitter.zPosition = Layer.frog - 1 // Just behind the frog

        // Burst properties
        emitter.particleBirthRate = 400 // High birth rate for a quick burst
        emitter.numParticlesToEmit = 25
        emitter.particleLifetime = 0.4
        emitter.particleLifetimeRange = 0.1

        // Motion properties: expand outward in a circle
        emitter.particleSpeed = 100
        emitter.particleSpeedRange = 50
        emitter.emissionAngleRange = .pi * 2 // 360 degrees

        // Appearance properties
        emitter.particleScale = 0.2
        emitter.particleScaleRange = 0.1
        emitter.particleScaleSpeed = 0.3 // Grow slightly
        
        emitter.particleAlpha = 0.7
        emitter.particleAlphaSpeed = -1.5 // Fade out
        
        emitter.particleColor = .white
        emitter.particleColorBlendFactor = 1.0

        parentNode.addChild(emitter)

        // Auto cleanup after the effect is finished
        let cleanupAction = SKAction.sequence([
            SKAction.wait(forDuration: 1.0), // Wait for all particles to die
            SKAction.removeFromParent()
        ])
        emitter.run(cleanupAction)
    }
    
    // Programmatic Weather Emitters
    func createRainEmitter(width: CGFloat) -> SKEmitterNode {
        let node = SKEmitterNode()
        node.particleTexture = SKTexture(imageNamed: "spark")
        node.particleBirthRate = 200 // Increased to cover more area
        node.particleLifetime = 2.0 // Increased lifetime for better coverage
        node.particlePositionRange = CGVector(dx: width * 1.2, dy: 0) // Wider coverage
        node.particleSpeed = 600
        node.particleSpeedRange = 100
        node.emissionAngle = -CGFloat.pi / 2 // Down
        node.particleAlpha = 0.5
        node.particleScale = 0.1
        node.particleScaleRange = 0.05
        node.particleColor = .white
        node.particleColorBlendFactor = 1.0
        return node
    }
    
    func createSnowEmitter(width: CGFloat) -> SKEmitterNode {
        let node = SKEmitterNode()
        node.particleTexture = SKTexture(imageNamed: "snowflake")
        node.particleBirthRate = 30 // Increased to cover more area
        node.particleLifetime = 6.0 // Increased lifetime for better coverage
        node.particlePositionRange = CGVector(dx: width * 1.2, dy: 0) // Wider coverage
        node.particleSpeed = 80
        node.particleSpeedRange = 40
        node.emissionAngle = -CGFloat.pi / 2
        node.emissionAngleRange = CGFloat.pi / 4 // Drift
        node.xAcceleration = 50 // Wobble
        node.particleAlpha = 0.8
        node.particleScale = 0.2
        node.particleScaleRange = 0.1
        node.particleColor = .white
        return node
    }
    
    func createFirefliesEmitter(width: CGFloat, height: CGFloat) -> SKEmitterNode {
        let node = SKEmitterNode()
        node.particleTexture = SKTexture(imageNamed: "firefly")
        node.particleBirthRate = 5
        node.particleLifetime = 5.0
        // Emit mainly from top, but fireflies linger
        node.particlePositionRange = CGVector(dx: width, dy: height/2)
        node.particleSpeed = 20
        node.particleSpeedRange = 10
        node.emissionAngleRange = CGFloat.pi * 2 // All directions
        node.xAcceleration = 20
        node.yAcceleration = 20
        
        // Pulse/Blink effect via alpha sequence
        let sequence = SKKeyframeSequence(keyframeValues: [0, 1, 0.2, 1, 0], times: [0, 0.2, 0.5, 0.8, 1])
        node.particleAlphaSequence = sequence
        
        node.particleScale = 0.15
        node.particleColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1) // Bright yellow
        node.particleColorBlendFactor = 1.0
        return node
    }
    
    func createStarsEmitter(width: CGFloat, height: CGFloat) -> SKEmitterNode {
        let node = SKEmitterNode()
        node.particleTexture = SKTexture(imageNamed: "spark")
        node.particleBirthRate = 3
        node.particleLifetime = 8.0
        // Stars appear throughout the screen
        node.particlePositionRange = CGVector(dx: width, dy: height)
        node.particleSpeed = 5
        node.particleSpeedRange = 3
        node.emissionAngleRange = CGFloat.pi * 2
        
        // Twinkling effect via alpha sequence
        let twinkle = SKKeyframeSequence(keyframeValues: [0.3, 1.0, 0.5, 1.0, 0.3], times: [0, 0.25, 0.5, 0.75, 1])
        node.particleAlphaSequence = twinkle
        
        node.particleScale = 0.1
        node.particleScaleRange = 0.05
        node.particleColor = .white
        node.particleColorBlendFactor = 1.0
        node.particleColorRedRange = 0.2
        node.particleColorBlueRange = 0.3  // Slight color variation for realism
        return node
    }
    
    /// Spawns a performant debris explosion effect when crocodile destroys objects.
    /// Uses GPU-accelerated particles for smooth performance.
    /// - Parameters:
    ///   - position: World position where debris spawns
    ///   - scene: The scene to add the effect to
    ///   - color: Primary color of the debris (green for lily pads, brown for logs)
    ///   - intensity: Scale factor for the effect (1.0 = normal, higher = more particles)
    func spawnDebris(at position: CGPoint, in scene: SKScene, color: UIColor = .green, intensity: CGFloat = 1.0) {
        // Main debris emitter - chunks flying outward
        let debrisEmitter = SKEmitterNode()
        debrisEmitter.particleTexture = SKTexture(imageNamed: "spark")
        debrisEmitter.position = position
        debrisEmitter.zPosition = Layer.item + 5
        
        // Burst of particles
        debrisEmitter.particleBirthRate = 200 * intensity
        debrisEmitter.numParticlesToEmit = Int(25 * intensity)
        debrisEmitter.particleLifetime = 0.8
        debrisEmitter.particleLifetimeRange = 0.3
        
        // Explode outward in all directions
        debrisEmitter.particleSpeed = 200
        debrisEmitter.particleSpeedRange = 100
        debrisEmitter.emissionAngleRange = CGFloat.pi * 2  // Full 360 degrees
        
        // Arc and fall with gravity
        debrisEmitter.yAcceleration = -400
        
        // Spin the debris chunks
        debrisEmitter.particleRotationSpeed = 5.0
        debrisEmitter.particleRotationRange = CGFloat.pi * 2
        
        // Size variation for chunks
        debrisEmitter.particleScale = 0.4
        debrisEmitter.particleScaleRange = 0.3
        debrisEmitter.particleScaleSpeed = -0.3  // Shrink as they fly
        
        // Color and fade
        debrisEmitter.particleColor = color
        debrisEmitter.particleColorBlendFactor = 1.0
        debrisEmitter.particleAlpha = 1.0
        debrisEmitter.particleAlphaSpeed = -1.0
        
        scene.addChild(debrisEmitter)
        
        // Secondary splash/spray emitter for water effect
        let splashEmitter = SKEmitterNode()
        splashEmitter.particleTexture = SKTexture(imageNamed: "spark")
        splashEmitter.position = position
        splashEmitter.zPosition = Layer.item + 4
        
        splashEmitter.particleBirthRate = 150 * intensity
        splashEmitter.numParticlesToEmit = Int(20 * intensity)
        splashEmitter.particleLifetime = 0.5
        splashEmitter.particleLifetimeRange = 0.2
        
        // Spray upward and outward
        splashEmitter.particleSpeed = 150
        splashEmitter.particleSpeedRange = 80
        splashEmitter.emissionAngle = CGFloat.pi / 2  // Upward
        splashEmitter.emissionAngleRange = CGFloat.pi / 2  // Wide spray
        
        splashEmitter.yAcceleration = -300
        
        splashEmitter.particleScale = 0.15
        splashEmitter.particleScaleRange = 0.1
        
        // Water-colored droplets
        splashEmitter.particleColor = .white
        splashEmitter.particleColorBlendFactor = 1.0
        splashEmitter.particleAlpha = 0.7
        splashEmitter.particleAlphaSpeed = -1.5
        
        scene.addChild(splashEmitter)
        
        // Auto-cleanup after effects complete
        let cleanup = SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.removeFromParent()
        ])
        debrisEmitter.run(cleanup)
        splashEmitter.run(cleanup)
    }
    
    /// Spawns a larger, more dramatic debris effect for when crocodile is actively eating.
    /// Creates a continuous chomping effect with debris flying in the crocodile's movement direction.
    func spawnChompDebris(at position: CGPoint, in scene: SKScene, movementDirection: CGVector) {
        // Calculate the angle based on movement (debris flies backward from direction of travel)
        let movementAngle = atan2(movementDirection.dy, movementDirection.dx)
        let debrisAngle = movementAngle + CGFloat.pi  // Opposite direction
        
        // Chunky debris flying backward
        let chunkEmitter = SKEmitterNode()
        chunkEmitter.particleTexture = SKTexture(imageNamed: "spark")
        chunkEmitter.position = position
        chunkEmitter.zPosition = Layer.item + 5
        
        chunkEmitter.particleBirthRate = 80
        chunkEmitter.numParticlesToEmit = 12
        chunkEmitter.particleLifetime = 0.6
        chunkEmitter.particleLifetimeRange = 0.2
        
        // Spray backward from movement direction
        chunkEmitter.particleSpeed = 180
        chunkEmitter.particleSpeedRange = 60
        chunkEmitter.emissionAngle = debrisAngle
        chunkEmitter.emissionAngleRange = CGFloat.pi / 3  // ~60 degree spread
        
        chunkEmitter.yAcceleration = -350
        
        chunkEmitter.particleRotationSpeed = 8.0
        chunkEmitter.particleRotationRange = CGFloat.pi * 2
        
        chunkEmitter.particleScale = 0.35
        chunkEmitter.particleScaleRange = 0.25
        chunkEmitter.particleScaleSpeed = -0.4
        
        // Mix of green/brown colors for organic debris
        chunkEmitter.particleColor = UIColor(red: 0.4, green: 0.6, blue: 0.2, alpha: 1.0)
        chunkEmitter.particleColorBlendFactor = 1.0
        chunkEmitter.particleColorRedRange = 0.3
        chunkEmitter.particleColorGreenRange = 0.2
        chunkEmitter.particleAlpha = 1.0
        chunkEmitter.particleAlphaSpeed = -1.2
        
        scene.addChild(chunkEmitter)
        
        // Quick cleanup
        let cleanup = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.removeFromParent()
        ])
        chunkEmitter.run(cleanup)
    }
    
    /// Spawns celebratory sparkle particles for treasure chest openings.
    /// Creates a golden burst effect with expanding and fading particles.
    func spawnSparkles(at position: CGPoint, in scene: SKScene) {
        // Golden sparkle burst emitter
        let sparkleEmitter = SKEmitterNode()
        sparkleEmitter.particleTexture = SKTexture(imageNamed: "spark")
        sparkleEmitter.position = position
        sparkleEmitter.zPosition = Layer.item + 10
        
        // Burst of sparkles
        sparkleEmitter.particleBirthRate = 200
        sparkleEmitter.numParticlesToEmit = 40
        sparkleEmitter.particleLifetime = 1.0
        sparkleEmitter.particleLifetimeRange = 0.3
        
        // Explode outward in all directions
        sparkleEmitter.particleSpeed = 120
        sparkleEmitter.particleSpeedRange = 60
        sparkleEmitter.emissionAngleRange = CGFloat.pi * 2  // Full 360 degrees
        
        // Float upward slightly
        sparkleEmitter.yAcceleration = 50
        
        // Sparkle and fade
        sparkleEmitter.particleScale = 0.3
        sparkleEmitter.particleScaleRange = 0.15
        sparkleEmitter.particleScaleSpeed = -0.2
        
        // Golden yellow color
        sparkleEmitter.particleColor = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        sparkleEmitter.particleColorBlendFactor = 1.0
        sparkleEmitter.particleColorRedRange = 0.1
        sparkleEmitter.particleColorGreenRange = 0.2
        
        // Twinkle effect with alpha
        let alphaSequence = SKKeyframeSequence(keyframeValues: [0.0, 1.0, 0.5, 1.0, 0.0], times: [0, 0.1, 0.5, 0.7, 1.0])
        sparkleEmitter.particleAlphaSequence = alphaSequence
        
        scene.addChild(sparkleEmitter)
        
        // Add a secondary ring burst for extra flair
        let ringEmitter = SKEmitterNode()
        ringEmitter.particleTexture = SKTexture(imageNamed: "spark")
        ringEmitter.position = position
        ringEmitter.zPosition = Layer.item + 9
        
        ringEmitter.particleBirthRate = 150
        ringEmitter.numParticlesToEmit = 20
        ringEmitter.particleLifetime = 0.6
        ringEmitter.particleLifetimeRange = 0.2
        
        // Expand outward in a ring
        ringEmitter.particleSpeed = 200
        ringEmitter.particleSpeedRange = 20
        ringEmitter.emissionAngleRange = CGFloat.pi * 2
        
        ringEmitter.particleScale = 0.2
        ringEmitter.particleScaleSpeed = 0.3  // Grow as they expand
        
        // White/yellow glow
        ringEmitter.particleColor = .white
        ringEmitter.particleColorBlendFactor = 1.0
        ringEmitter.particleAlpha = 0.8
        ringEmitter.particleAlphaSpeed = -1.5
        
        scene.addChild(ringEmitter)
        
        // Auto-cleanup
        let cleanup = SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.removeFromParent()
        ])
        sparkleEmitter.run(cleanup)
        ringEmitter.run(cleanup)
    }
    
    // MARK: - Water Ripple Effects (Optimized for Multiple Simultaneous Ripples)
    
    /// Spawns animated water ripples parented to a lily pad or other node.
    /// Uses GPU-accelerated SKAction animations for optimal performance.
    /// The ripples will automatically follow the parent node's position if it moves.
    /// Optimized to allow many ripples to play simultaneously without performance impact.
    /// - Parameters:
    ///   - parentNode: The node to parent the ripples to (e.g., a lily pad)
    ///   - color: The color of the ripples (adjust based on weather/environment)
    ///   - rippleCount: Number of concentric ripples to spawn (default 3)
    ///   - offset: Optional position offset from the parent's center (default .zero means center of parent)
    func spawnRippleEffect(parentedTo parentNode: SKNode, color: UIColor = .white, rippleCount: Int = 2, offset: CGPoint = .zero) {
        // Create ripples directly on the parent node without an intermediate container
        // This reduces node count and improves performance for multiple simultaneous ripples
        for i in 0..<rippleCount {
            let ripple = SKShapeNode(circleOfRadius: 25)
            ripple.strokeColor = color.withAlphaComponent(0.7)
            ripple.fillColor = .clear
            ripple.lineWidth = 3
            ripple.position = offset  // Position relative to parent
            ripple.zPosition = -5  // Below the lily pad (relative to parent's zPosition)
            ripple.alpha = 0  // Start invisible for fade-in effect
            
            // Add directly to parent node
            parentNode.addChild(ripple)
            
            // Stagger the ripples slightly for a wave effect
            let delay = Double(i) * 0.15
            
            // Animate the ripple expanding and fading out
            let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            let expand = SKAction.scale(to: 5.0, duration: 1.0)
            let fadeOut = SKAction.fadeOut(withDuration: 1.0)
            let group = SKAction.group([expand, fadeOut])
            
            let sequence = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                fadeIn,
                group,
                SKAction.removeFromParent()  // Auto-cleanup
            ])
            
            ripple.run(sequence)
        }
    }
    
    /// Spawns larger, more dramatic ripples for drowning or splash events.
    /// Parented to a node so they follow movement if needed.
    /// Optimized for multiple simultaneous ripples.
    /// - Parameters:
    ///   - parentNode: The node to parent the ripples to
    ///   - color: The color of the ripples
    ///   - rippleCount: Number of concentric ripples (default 4 for more drama)
    ///   - offset: Optional position offset from parent's center
    func spawnDramaticRipples(parentedTo parentNode: SKNode, color: UIColor = .white, rippleCount: Int = 4, offset: CGPoint = .zero) {
        let delayBetweenRipples: TimeInterval = 0.15
        
        for i in 0..<rippleCount {
            let ripple = SKShapeNode(circleOfRadius: 20)
            ripple.strokeColor = color.withAlphaComponent(0.8)
            ripple.fillColor = .clear
            ripple.lineWidth = 3
            ripple.position = offset
            ripple.zPosition = -5  // Below parent
            ripple.alpha = 0
            
            // Add directly to parent node for performance
            parentNode.addChild(ripple)
            
            let delay = SKAction.wait(forDuration: delayBetweenRipples * Double(i))
            let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.05)
            let expand = SKAction.scale(to: 4.0 + CGFloat(i) * 0.5, duration: 0.8)
            expand.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.8)
            let expandAndFade = SKAction.group([expand, fade])
            let remove = SKAction.removeFromParent()
            
            ripple.run(SKAction.sequence([delay, fadeIn, expandAndFade, remove]))
        }
    }
}
