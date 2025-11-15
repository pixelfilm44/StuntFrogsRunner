//
//  GameScene.swift
//  Complete Top-down lily pad hopping game
//  Refactored for better maintainability with separated concerns
//

import SpriteKit

class GameScene: SKScene {
    
    // Scoring based on upward progress
    private var lastWorldYForScore: CGFloat = 0
    private var hasInitializedScoreAnchor: Bool = false
    
    // MARK: - Core Managers (Existing)
    var frogController: FrogController!
    var slingshotController: SlingshotController!
    var worldManager: WorldManager!
    var spawnManager: SpawnManager!
    var collisionManager: CollisionManager!
    var effectsManager: EffectsManager!
    var uiManager: UIManager!
    
    // MARK: - New Manager Classes (Refactored)
    var healthManager: HealthManager!
    var scoreManager: ScoreManager!
    private var stateManager: GameStateManager!
    private var visualEffectsController: VisualEffectsController!
    var hudController: HUDController!
    private var abilityManager: AbilityManager!
    private var facingDirectionController: FacingDirectionController!
    private var landingController: LandingController!
    private var touchInputController: TouchInputController!
    private var gameLoopCoordinator: GameLoopCoordinator!
    private var soundController: SoundController!
    private var edgeSpikeBushManager: EdgeSpikeBushManager!
    
    var visualFX: VisualEffectsController!
    
    // MARK: - Scene Nodes
    private var menuBackdrop: SKShapeNode?
    private var backgroundNode: SKSpriteNode?
    var frogContainer: SKSpriteNode!
    var hudBar: SKShapeNode!
    var hudBarShadow: SKShapeNode?  // Track the shadow element separately
    let hudBarHeight: CGFloat = 160
    var heartsContainer: SKNode!
    var lifeVestsContainer: SKNode!
    var scrollSaverContainer: SKNode!
    
    // MARK: - Level Management
    private var currentLevel: Int = 1
    private var baseSpawnRateMultiplier: CGFloat = 1.0
    
    // MARK: - Level Travel Distance Tracking
    private var levelStartingFrogY: CGFloat = 0
    private var levelTravelDistance: CGFloat = 0
    private var totalSessionTravelDistance: CGFloat = 0
    private var levelTravelDistances: [Int: CGFloat] = [:]  // Store travel distance per level
    
    // MARK: - Level Timer
    private var levelStartTime: CFTimeInterval = 0
    private var levelTimeRemaining: Double = 0
    private var levelTimerActive: Bool = false
    
    // MARK: - Finish Line
    private var finishLine: FinishLine?
    private var hasSpawnedFinishLine: Bool = false
    private var frogPreviousY: CGFloat = 0
    private var levelStartingScore: Int = 0  // Track the score when the level started
    
    // MARK: - Parallax Background Elements
    private var rightTree: SKSpriteNode?
    private var leftTree: SKSpriteNode?
    
    // MARK: - Game Objects (in world space)
    var enemies: [Enemy] = []
    var tadpoles: [Tadpole] = []
    var bigHoneyPots: [BigHoneyPot] = []
    var lifeVests: [LifeVest] = []
    var lilyPads: [LilyPad] = []
    
    var maxHealth: Int {
        get { healthManager.maxHealth }
        set { healthManager.maxHealth = newValue }
    }

    // Tracks the currently pressed UI button node for press/release animation
    private var currentlyPressedButton: SKNode!
    
    // MARK: - Deinitializer
    deinit {
        print("🧹 GameScene deinitializing - cleaning up resources")
        
        // Clean up weather notifications
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("WeatherChanged"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("WindForceApplied"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SlipperyPadEffect"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("LightningEffect"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("StartGameAtLevel"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ResumeGame"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("QuitToMainMenu"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("StartNewGame"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RestartGame"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("BackToMainMenu"), object: nil)
        
        // Clear all callback closures to break retain cycles
        healthManager?.onHealthChanged = nil
        healthManager?.onHealthDepleted = nil
        healthManager?.onTadpolesChanged = nil
        healthManager?.onAbilityChargesChanged = nil
        
        scoreManager?.onScoreChanged = nil
        scoreManager?.onHighScoreAchieved = nil
        scoreManager?.onLevelProgressed = nil
        
        stateManager?.onStateChanged = nil
        stateManager?.onWaterStateChanged = nil
        
        landingController?.onLandingSuccess = nil
        landingController?.onLandingMissed = nil
        
        abilityManager?.onExtraHeartSelected = nil
        abilityManager?.onRefillHeartsSelected = nil
        abilityManager?.onLifeVestSelected = nil
        abilityManager?.onScrollSaverSelected = nil
        abilityManager?.onFlySwatterSelected = nil
        abilityManager?.onHoneyJarSelected = nil
        abilityManager?.onAxeSelected = nil
        abilityManager?.onRocketSelected = nil
        
        hudController?.onScoreGained = nil
        
        finishLine?.onCrossed = nil
        
        // Clear UIManager references - this could prevent retain cycles
        uiManager = nil
        
        // Force cleanup of all game objects
        forceCompleteCleanup()
        
        print("🧹 GameScene deinitialization complete")
    }
    
    // MARK: - Convenience Properties
    private var gameState: GameState {
        get { stateManager.currentState }
        set { stateManager.currentState = newValue }
    }
    
    var score: Int {
        get { scoreManager.score }
        set { scoreManager.score = newValue }
    }
    
    private var highScore: Int {
        scoreManager.highScore
    }
    
    // Public properties for accessing travel distance data
    var currentLevelTravelDistance: CGFloat {
        return levelTravelDistance
    }
    
    var sessionTotalTravelDistance: CGFloat {
        return totalSessionTravelDistance
    }
    
    var allLevelTravelDistances: [Int: CGFloat] {
        return levelTravelDistances
    }
    
    // Glide tuning constants
    private let glideLerp: CGFloat = 0.08
    private let worldGlideLerp: CGFloat = 0.12
    
    // Rocket final approach state
    private var isRocketFinalApproach: Bool = false
    
    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
     
        // Set initial background color based on weather (will be updated by weather system)
        let weatherManager = WeatherManager.shared
        backgroundColor = weatherManager.getBackgroundColor(for: .day) // Default to day initially
        
        physicsWorld.gravity = .zero
        
        setupManagers()
        setupGame()
        showMainMenu()
        
        if let shape = menuBackdrop {
            let inset: CGFloat = 24
            let backdropSize = CGSize(width: size.width - inset * 2, height: size.height - 220)
            let rect = CGRect(x: -backdropSize.width/2, y: -backdropSize.height/2, width: backdropSize.width, height: backdropSize.height)
            shape.path = CGPath(roundedRect: rect, cornerWidth: 24, cornerHeight: 24, transform: nil)
            shape.position = CGPoint(x: size.width/2, y: size.height/2 + 20)
        }
        
        
        
        // Pre-warm all haptic types
        HapticFeedbackManager.shared.impact(.light)
        HapticFeedbackManager.shared.impact(.medium)
        HapticFeedbackManager.shared.impact(.heavy)
        HapticFeedbackManager.shared.selectionChanged()
        HapticFeedbackManager.shared.notification(.success)
        HapticFeedbackManager.shared.notification(.warning)
        HapticFeedbackManager.shared.notification(.error)
  
    }
    
    // MARK: - Background Setup
  
    
    
    // MARK: - Managers Setup
    func setupManagers() {
        // Initialize existing managers
        frogController = FrogController(scene: self)
        slingshotController = SlingshotController(scene: self)

        worldManager = WorldManager(scene: self)
        effectsManager = EffectsManager(scene: self)
        uiManager = UIManager(scene: self)
        collisionManager = CollisionManager(scene: self, uiManager: nil, frogController: frogController)
        collisionManager.effectsManager = effectsManager
        collisionManager.uiManager = uiManager
        
        // Initialize new refactored managers
        healthManager = HealthManager(startingHealth: GameConfig.startingHealth)
        scoreManager = ScoreManager.shared
        stateManager = GameStateManager()
        soundController = SoundController.shared
        gameLoopCoordinator = GameLoopCoordinator()
        landingController = LandingController()
        touchInputController = TouchInputController()
        abilityManager = AbilityManager()
        edgeSpikeBushManager = EdgeSpikeBushManager(worldNode: worldManager.worldNode, scene: self)
        
        // WEATHER SYSTEM INITIALIZATION
        let weatherManager = WeatherManager.shared
        weatherManager.initializeForGame(gameStateManager: stateManager, effectsManager: effectsManager)
        
        // Set initial weather based on current level
        let initialWeather = weatherManager.suggestWeatherForLevel(currentLevel)
        weatherManager.setWeather(initialWeather, effectsManager: effectsManager)
        print("🌤️ Weather system initialized for level \(currentLevel) with \(initialWeather.displayName) weather")
        
        setupManagerCallbacks()
    }
    
    // MARK: - Manager Callbacks Setup
    private func setupManagerCallbacks() {
        // Health Manager Callbacks
        healthManager.onHealthChanged = { [weak self] newHealth, oldHealth in
            guard let self = self else { return }
            
            // Trigger heavy haptic only when losing health
            if newHealth < oldHealth {
                HapticFeedbackManager.shared.impact(.heavy)
                self.frogController.activateInvincibility(seconds: 3.0)
                self.visualEffectsController?.startInvincibilityFlicker()
            }
            
            self.updateHUD()
            
            // Start flashing when only 1 heart remains; stop when health recovers to 2 or more
            if newHealth == 1 {
                self.visualEffectsController?.startLowHealthFlash()
            } else {
                self.visualEffectsController?.stopLowHealthFlash()
            }
        }
        
        healthManager.onHealthDepleted = { [weak self] in
            guard let self = self else { return }
            self.visualEffectsController?.stopLowHealthFlash()
            self.playScaredSpinDropAndGameOver(reason: .healthDepleted)
        }
        
        healthManager.onMaxHealthChanged = { [weak self] _ in
            self?.updateHUD()
        }
        
        healthManager.onTadpolesChanged = { [weak self] tadpoles in
            guard let self = self else { return }
            self.uiManager.updateTadpoles(tadpoles)
            self.uiManager.updateStarProgress(current: tadpoles, threshold: GameConfig.tadpolesForAbility)
            self.updateHUD()
        }
        
        healthManager.onAbilityChargesChanged = { [weak self] in
            self?.updateHUD()
        }
        
        // Score Manager Callbacks
        scoreManager.onScoreChanged = { [weak self] score in
            self?.uiManager.updateScore(score)
        }
        
        scoreManager.onHighScoreAchieved = { [weak self] highScore in
            self?.uiManager.highlightScore(isHighScore: true)
        }
        
        scoreManager.onHighScoreChanged = { [weak self] _ in
            if self?.scoreManager.isHighScore() == false {
                self?.uiManager.highlightScore(isHighScore: false)
            }
        }
        
        scoreManager.onLevelProgressed = { [weak self] newLevel in
            print("🎮 ScoreManager reported level progression to Level \(newLevel)")
            // Update local level tracking to match ScoreManager
            self?.currentLevel = newLevel
        }
        
        // State Manager Callbacks
        stateManager.onStateChanged = { [weak self] newState, oldState in
            self?.handleStateChange(from: oldState, to: newState)
        }
        
        stateManager.onInputLocked = { [weak self] in
            // Cancel slingshot aiming when input gets locked
            if self?.slingshotController.slingshotActive == true {
                print("🎯 Input locked - automatically canceling slingshot aiming")
                self?.slingshotController.cancelCurrentAiming()
            }
        }
        
        stateManager.onWaterStateChanged = { [weak self] newState, oldState in
            self?.handleWaterStateChange(from: oldState, to: newState)
        }
        
        stateManager.onGameOver = { [weak self] reason in
            guard let self = self else { return }
            self.stopLevelTimer()  // Stop timer when game is over
            self.uiManager.hideSuperJumpIndicator()
            self.uiManager.hideRocketIndicator()
            self.healthManager.pendingAbilitySelection = false
            self.uiManager.showGameOverMenu(
                sceneSize: self.size,
                score: self.score,
                highScore: self.highScore,
                isNewHighScore: self.score == self.highScore && self.score > 0,
                reason: reason
            )
        }
        
        // Weather Manager Callbacks
        setupWeatherNotifications()
        setupWeatherEffectCallbacks()
        
        // Landing Controller Callbacks
        landingController.onLandingSuccess = { [weak self] pad in
            guard let self = self else { return }

            // Instrumentation and safety: clear actions/velocity and log positions

            self.frogController.frog.removeAllActions()
            self.frogController.frogShadow.removeAllActions()
            self.frogContainer.removeAllActions()
            self.frogController.velocity = .zero

            let frogWorldBefore = self.frogController.position
            let frogScreenBefore = self.convert(frogWorldBefore, from: self.worldManager.worldNode)
            let padWorld = pad.position
            let padScreen = self.convert(padWorld, from: self.worldManager.worldNode)

          

            // Perform land logic; snapping now done inside FrogController.landOnPad
            self.frogController.landOnPad(pad)

            let frogScreenAfter = self.convert(self.frogController.position, from: self.worldManager.worldNode)

            // Update grounded/water/jump state
            self.frogController.isJumping = false
            self.frogController.isGrounded = true
            self.frogController.inWater = false
            self.frogController.suppressWaterCollisionUntilNextJump = false

            // Effects and haptics at final screen position
            // Prefer slingshot pull magnitude for ripple intensity; fall back to distance if unavailable
            var intensity = self.slingshotController.lastPullIntensity
            if intensity <= 0.0 {
                // Fallback: compute from jump distance
                let jumpDistance = hypot(self.frogController.jumpTargetPos.x - self.frogController.jumpStartPos.x,
                                         self.frogController.jumpTargetPos.y - self.frogController.jumpStartPos.y)
                let maxDist = max(1.0, GameConfig.maxRegularJumpDistance)
                intensity = min(1.0, max(0.0, jumpDistance / maxDist))
            }
            self.effectsManager?.createLandingEffect(at: frogScreenAfter, intensity: intensity, lilyPad: pad)

            HapticFeedbackManager.shared.impact(.medium)

            // WEATHER INTEGRATION: Handle slippery pad effects
            self.handleSlipperyPadLanding(on: pad)

            // Handle Impact Jumps super power effect
            self.handleImpactJumpLanding(at: pad.position)

            // Set hasLandedOnce true after normal landing
            self.stateManager.hasLandedOnce = true

            // Clear locked facing on landing
            self.facingDirectionController?.clearLockedFacing()

            self.stateManager.splashTriggered = false

            // PERFORMANCE IMPROVEMENT: Spawn new objects only after successful jumps
            // This is much more efficient than spawning every few frames
            self.spawnManager.spawnObjects(
                sceneSize: self.size,
                lilyPads: &self.lilyPads,
                enemies: &self.enemies,
                tadpoles: &self.tadpoles,
                bigHoneyPots: &self.bigHoneyPots,
                lifeVests: &self.lifeVests,
                worldOffset: self.worldManager.worldNode.position.y,
                frogPosition: self.frogController.position,
                superJumpActive: self.frogController.superJumpActive
            )
            
            // PERFORMANCE IMPROVEMENT: Run cleanup after landing too
            // Clean up objects that are now behind the frog's new position
            self.spawnManager.performCleanup(
                lilyPads: &self.lilyPads,
                enemies: &self.enemies,
                frogPosition: self.frogController.position,
                sceneSize: self.size,
                worldNode: self.worldManager.worldNode
            )

            if self.healthManager.pendingAbilitySelection && self.gameState == .playing {
                // Keep the flag true until the UI actually appears so touches are ignored
                // and lock input during the animation window.
                self.stateManager.lockInput(for:1.0)
                let vfx = self.visualEffectsController!
                vfx.playUpgradeCue()

                // Pause spawning and clear enemies around the landing pad immediately
                // so the scene is calm while the animation plays.
                self.spawnManager.pauseSpawningAndClearEnemies(around: pad, enemies: &self.enemies, sceneSize: self.size)

                // Delay showing the ability selection to let the animation be seen.
                let delay = SKAction.wait(forDuration: 0.9)
                let abilitySelectionAction = SKAction.run { [weak self] in
                    guard let self = self else { 
                        // If self is nil, we can't clear the flag, but this shouldn't happen in normal gameplay
                        return 
                    }
                    
                    // IMPORTANT: Always clear the pending flag, even if we can't show UI
                    self.healthManager.pendingAbilitySelection = false
                    
                    // Only show ability selection if we're still in a valid state
                    if self.gameState == .playing {
                        self.gameState = .abilitySelection
                        self.uiManager.showAbilitySelection(sceneSize: self.size)
                    } else {
                        print("🚨 Ability selection cancelled due to game state change: \(self.gameState)")
                    }
                }
                
                // Store the action with a key so we can cancel it if needed
                let sequence = SKAction.sequence([delay, abilitySelectionAction])
                self.run(sequence, withKey: "abilitySelectionDelay")
            }
        }
        
        landingController.onLandingMissed = { [weak self] in
            self?.handleMissedLanding()
        }
        
        landingController.onUnsafePadLanding = { [weak self] in
            self?.handleUnsafePadLanding()
        }
        
        // Ability Manager Callbacks
        setupAbilityManagerCallbacks()
    }
    
    private func setupAbilityManagerCallbacks() {
        abilityManager.onExtraHeartSelected = { [weak self] in
            guard let self = self else { return }
            self.healthManager.increaseMaxHealth()
        }
        
        abilityManager.onSuperJumpSelected = { [weak self] in
            guard let self = self else { return }
            self.frogController.activateSuperJump()
            self.uiManager.showSuperJumpIndicator(sceneSize: self.size)
            
            // Start super jump music
            self.soundController.handleSuperJumpAbilityActivated()
        }
        
        abilityManager.onRefillHeartsSelected = { [weak self] in
            self?.healthManager.refillHealth()
        }
        
        abilityManager.onLifeVestSelected = { [weak self] in
            guard let self = self else { return }
            print("🦺 Life Vest ability selected - adding charge")
            self.frogController.lifeVestCharges = min(6, self.frogController.lifeVestCharges + 1)
            print("🦺 Life Vest charges now: \(self.frogController.lifeVestCharges)")
            self.updateHUD()
        }
        
        abilityManager.onScrollSaverSelected = { [weak self] in
            print("📜 Scroll Saver ability selected")
            self?.healthManager.addScrollSaverCharge()
        }
        
        abilityManager.onFlySwatterSelected = { [weak self] in
            print("🪰 Fly Swatter ability selected")
            self?.healthManager.addFlySwatterCharge()
        }
        
        abilityManager.onHoneyJarSelected = { [weak self] in
            print("🍯 Honey Jar ability selected")
            self?.healthManager.addHoneyJarCharge()
        }
        
        abilityManager.onAxeSelected = { [weak self] in
            print("🪓 Axe ability selected")
            self?.healthManager.addAxeCharge()
        }
        
        abilityManager.onRocketSelected = { [weak self] in
            guard let self = self else { return }
            self.frogController.activateRocket()
            self.uiManager.showRocketIndicator(sceneSize: self.size)
            
            // Start rocket flight music
            self.soundController.handleRocketAbilityActivated()
            
            self.touchInputController.initializeRocketTarget(frogContainerX: self.frogContainer.position.x)
            
            let centerX = self.size.width / 2
            let centerY = self.size.height / 2
            
            let moveToCenter = SKAction.move(to: CGPoint(x: centerX, y: centerY), duration: 0.5)
            moveToCenter.timingMode = .easeInEaseOut
            self.frogContainer.run(moveToCenter)
            
            self.frogContainer.zPosition = 100
            
            if let bg = self.backgroundNode { bg.zPosition = -1000 }
        }
    }
    
    // MARK: - Weather Notifications Setup
    private func setupWeatherNotifications() {
        // Listen for weather changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(weatherChanged(_:)),
            name: NSNotification.Name("WeatherChanged"),
            object: nil
        )
    }
    
    private func setupWeatherEffectCallbacks() {
        // Listen for wind force effects
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindForce(_:)),
            name: NSNotification.Name("WindForceApplied"),
            object: nil
        )
        
        // Listen for slippery pad effects
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSlipperyPadEffect(_:)),
            name: NSNotification.Name("SlipperyPadEffect"),
            object: nil
        )
        
        // Listen for lightning effects
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLightningEffect(_:)),
            name: NSNotification.Name("LightningEffect"),
            object: nil
        )
        
        // Listen for level selection from UIManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartGameAtLevel(_:)),
            name: NSNotification.Name("StartGameAtLevel"),
            object: nil
        )
        
        // Listen for pause menu actions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResumeGame),
            name: NSNotification.Name("ResumeGame"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQuitToMainMenu),
            name: NSNotification.Name("QuitToMainMenu"),
            object: nil
        )
        
        // Listen for new game start from UIManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartNewGame),
            name: NSNotification.Name("StartNewGame"),
            object: nil
        )
        
        // Listen for restart game from UIManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRestartGame),
            name: NSNotification.Name("RestartGame"),
            object: nil
        )
        
        // Listen for back to main menu from UIManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackToMainMenu),
            name: NSNotification.Name("BackToMainMenu"),
            object: nil
        )
    }
    
    @objc private func weatherChanged(_ notification: Notification) {
        guard let newWeather = notification.object as? WeatherType,
              let userInfo = notification.userInfo,
              let oldWeather = userInfo["oldWeather"] as? WeatherType else { return }
        
        print("🌤️ Weather changed from \(oldWeather.displayName) to \(newWeather.displayName)")
        
        // Update background color smoothly
        let weatherManager = WeatherManager.shared
        let bgColor = weatherManager.getBackgroundColor(for: newWeather)
        let colorAction = SKAction.colorize(with: bgColor, colorBlendFactor: 1.0, duration: 2.0)
        run(colorAction)
        
        // Update existing lily pads with weather effects
        updateExistingLilyPadsForWeather(newWeather)
        
        // Apply weather-specific gameplay effects
        applyWeatherGameplayEffects(newWeather)
        
        // Update spawn configuration for new weather
        updateSpawnConfigurationForWeather(newWeather)
    }
    
    @objc private func handleWindForce(_ notification: Notification) {
        guard let windForce = notification.object as? CGVector else { return }
        guard gameState == .playing else { return }
        
        // Apply wind force to the frog during jumps
        if frogController.isJumping {
            let windEffect = CGPoint(x: windForce.dx * 0.5, y: windForce.dy * 0.3)
            let adjustedTarget = CGPoint(
                x: frogController.jumpTargetPos.x + windEffect.x,
                y: frogController.jumpTargetPos.y + windEffect.y
            )
            
            // Update frog's trajectory
            frogController.adjustJumpTarget(to: adjustedTarget)
            
            // Show visual wind effect
            showFloatingText("Wind!", color: .systemCyan)
        }
    }
    
    @objc private func handleSlipperyPadEffect(_ notification: Notification) {
        guard let slipData = notification.userInfo,
              let slipFactor = slipData["slipFactor"] as? CGFloat else { return }
        
        // Apply slip effect to the frog
        applySlipEffectToFrog(factor: slipFactor)
    }
    
    @objc private func handleLightningEffect(_ notification: Notification) {
        // Create lightning flash effect
        let lightningFlash = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        lightningFlash.fillColor = UIColor.white.withAlphaComponent(0.8)
        lightningFlash.strokeColor = .clear
        lightningFlash.zPosition = 2000 // Above everything
        addChild(lightningFlash)
        
        // Flash and remove
        let fadeOut = SKAction.fadeOut(withDuration: 0.1)
        let remove = SKAction.removeFromParent()
        lightningFlash.run(SKAction.sequence([fadeOut, remove]))
        
        // Play thunder sound if available
        soundController.playIceCrack() // Temporary sound effect
        
        // Brief screen shake
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 5, y: 0, duration: 0.02),
            SKAction.moveBy(x: -10, y: 0, duration: 0.04),
            SKAction.moveBy(x: 5, y: 0, duration: 0.02)
        ])
        run(shake)
    }
    
    @objc private func handleStartGameAtLevel(_ notification: Notification) {
        guard let selectedLevel = notification.object as? Int else {
            print("❌ handleStartGameAtLevel: Invalid level object")
            return
        }
        
        print("🎮 Received start game notification for level \(selectedLevel)")
        
        // Save any pending tadpole coins before starting at specific level
        uiManager.savePendingTadpoleCoins()
        
        // Set the ScoreManager to the selected level
        scoreManager.startAtLevel(selectedLevel)
        
        // Set local level tracking to match
        currentLevel = selectedLevel
        
        // Set level starting score based on the selected level
        levelStartingScore = scoreManager.score
        print("🏁 Set level starting score to \(levelStartingScore) for Level \(selectedLevel)")
        
        // Start the game
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.startGame()
        }
    }
    
    @objc private func handleResumeGame() {
        print("🎮 Resume game notification received")
        gameState = .playing
        
        // Resume any paused systems
        worldManager.worldNode.isPaused = false
        
        // Play resume sound if available
        soundController.playSoundEffect(.buttonTap)
        
        print("🎮 Game resumed successfully")
    }
    
    @objc private func handleQuitToMainMenu() {
        print("🎮 Quit to main menu notification received")
        
        // Play button sound
        soundController.playSoundEffect(.buttonTap)
        
        // Return to main menu
        showMainMenu()
        
        print("🎮 Returned to main menu successfully")
    }
    
    @objc private func handleStartNewGame() {
        print("🎮 Start new game notification received")
        
        // Play button sound
        soundController.playSoundEffect(.buttonTap)
        
        // Start a completely new game
        startNewGame()
        
        print("🎮 New game started successfully")
    }
    
    @objc private func handleRestartGame() {
        print("🎮 Restart game notification received")
        
        // Play button sound
        soundController.playSoundEffect(.buttonTap)
        
        // Start a new game (same as start new game)
        startNewGame()
        
        print("🎮 Game restarted successfully")
    }
    
    @objc private func handleBackToMainMenu() {
        print("🎮 Back to main menu notification received")
        
        // Play button sound
        soundController.playSoundEffect(.buttonTap)
        
        // Return to main menu
        showMainMenu()
        
        print("🎮 Returned to main menu successfully")
    }
    
    private func updateExistingLilyPadsForWeather(_ weather: WeatherType) {
        // Apply weather effects to all existing lily pads
        enumerateChildNodes(withName: "lilypad") { node, _ in
            WeatherManager.shared.applyWeatherEffectsToLilyPad(node, weather: weather)
        }
        
        // Also update lily pads in the game objects array
        for lilyPad in lilyPads {
            WeatherManager.shared.applyWeatherEffectsToLilyPad(lilyPad.node, weather: weather)
        }
    }
    
    // MARK: - Weather Gameplay Effects
    
    private func applyWeatherGameplayEffects(_ weather: WeatherType) {
        let weatherManager = WeatherManager.shared
        
        // Handle water to ice conversion
        if weatherManager.shouldConvertWaterToIce() {
            stateManager.setWaterState(.ice)
            showFloatingText("Water freezes to ice!", color: .systemCyan)
        } else {
            stateManager.setWaterState(.water)
        }
        
        // Handle slippery pads effect
        if weatherManager.shouldPadsBeSlippery() {
            showFloatingText("Lily pads are slippery!", color: .systemYellow)
        }
        
        // Handle wind effects
        if weatherManager.isWindActive() {
            showFloatingText("Strong winds ahead!", color: .systemGray)
        }
        
        // Apply weather-specific visual effects through EffectsManager
        effectsManager?.updateWeatherEffects(for: weather)
    }
    
    private func updateSpawnConfigurationForWeather(_ weather: WeatherType) {
        // Get weather-specific level configuration
        let weatherManager = WeatherManager.shared
        let weatherConfig = weatherManager.getWeatherLevelConfig(level: currentLevel, weather: weather)
        
        // TODO: Update spawn manager with new configuration when method is implemented
        // spawnManager.updateWeatherConfiguration(weatherConfig)
        
        print("🌤️ Updated spawn configuration for \(weather.displayName) weather")
        print("🌤️ Global spawn multiplier: \(weatherConfig.globalSpawnRateMultiplier)")
        print("🌤️ Weather-adjusted enemy configs: \(weatherConfig.enemyConfigs.count) types")
    }
    
    private func applySlipEffectToFrog(factor: CGFloat) {
        guard frogController.isGrounded else { return }
        
        // Calculate slip velocity based on slip factor
        let baseSlideSpeed: CGFloat = 30.0 * factor // Scale by slip factor
        let slipDirection = CGFloat.random(in: 0...(2 * .pi))
        
        let slipVelocity = CGVector(
            dx: cos(slipDirection) * baseSlideSpeed,
            dy: sin(slipDirection) * baseSlideSpeed
        )
        
        // Delegate to FrogController's ice sliding functionality
        frogController.startSlidingOnIce(initialVelocity: slipVelocity)
        
        // Visual feedback
        showFloatingText("Slippery!", color: .systemBlue)
        effectsManager?.createSlipEffect(at: frogContainer.position)
        
        // Light haptic feedback
        HapticFeedbackManager.shared.impact(.light)
        
        print("🧊 GameScene applied slip effect - delegated to FrogController.startSlidingOnIce with velocity: \(slipVelocity)")
    }
    
    private func handleSlipperyPadLanding(on pad: LilyPad) {
        let weatherManager = WeatherManager.shared
        
        // Check if pads should be slippery in current weather
        if weatherManager.shouldPadsBeSlippery() {
            let slipFactor = weatherManager.getSlipFactor()
            
            // Apply slip effect with a small delay to let the landing complete
            let delay = SKAction.wait(forDuration: 0.2)
            let slipAction = SKAction.run { [weak self] in
                self?.applySlipEffectToFrog(factor: slipFactor)
            }
            run(SKAction.sequence([delay, slipAction]))
        }
    }
    
    // MARK: - Game Setup
        func setupGame() {
            // Setup world (scrolls down)
            if let bg = backgroundNode {
                bg.removeFromParent()
                bg.zPosition = -1000
                addChild(bg)
            }
            
            let world = worldManager.setupWorld(sceneSize: size)
            addChild(world)
            
            // Setup parallax background tree
            setupBackgroundTree()
            
            // Initialize scoring anchor based on initial world Y
            lastWorldYForScore = worldManager.worldNode.position.y
            hasInitializedScoreAnchor = true
            
            // Setup spawn manager
            spawnManager = SpawnManager(scene: self, worldNode: worldManager.worldNode)
            spawnManager.startGracePeriod(duration: 1.5)
            
            // Note: Enemy spawning now uses a pending array to avoid simultaneous access issues
            // Enemies are flushed to the main array safely in the update loop
            
            // Setup frog container
            let frogRootNode = frogController.setupFrog(sceneSize: size)
            let frogContainerSprite = SKSpriteNode(color: .clear, size: .zero)
            frogContainerSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            frogContainerSprite.zPosition = 110
            frogContainerSprite.position = CGPoint(x: size.width / 2, y: size.height * 0.4)
            frogRootNode.position = .zero
            frogContainerSprite.addChild(frogRootNode)
            frogContainer = frogContainerSprite
            addChild(frogContainerSprite)
            
            // Initialize visual effects controller now that frog is set up
            visualEffectsController = VisualEffectsController(
                frogContainer: frogContainer,
                frogSprite: frogController.frog as! SKSpriteNode,
                frogShadow: frogController.frogShadow  // ✅ FIXED: Now passing actual shadow reference instead of nil
            )
            
            // Initialize facing direction controller
            facingDirectionController = FacingDirectionController(frogNode: frogController.frog)
            
            // Setup UI
            uiManager.setupUI(sceneSize: size)
            
            // Create menu backdrop
            setupMenuBackdrop()
            
            // Create bottom HUD bar
            setupHUDBar()
        }
    private func setupMenuBackdrop() {
        if menuBackdrop == nil {
            let inset: CGFloat = 24
            let backdropSize = CGSize(width: size.width - inset * 2, height: size.height - 220)
            let rect = CGRect(x: -backdropSize.width/2, y: -backdropSize.height/2, width: backdropSize.width, height: backdropSize.height)
            let shape = SKShapeNode(rect: rect, cornerRadius: 24)
            shape.fillColor = UIColor(white: 0.05, alpha: 0.88)
            shape.strokeColor = UIColor.white.withAlphaComponent(0.12)
            shape.lineWidth = 1.0
            shape.zPosition = 190
            shape.position = CGPoint(x: size.width/2, y: size.height/2 + 20)
            shape.isUserInteractionEnabled = false
            shape.alpha = 0.0
            menuBackdrop = shape
            addChild(shape)
        }
    }
    
    private func setupHUDBar() {
        // Glassy oval tray centered above the bottom
        let trayWidth = size.width * 0.86
        let trayHeight: CGFloat = 160
        let trayRect = CGRect(x: -trayWidth/2, y: -trayHeight/2, width: trayWidth, height: trayHeight)
        let corner = trayHeight/2

        // Drop shadow (separate node so it doesn't clip the blur look)
        let shadow = SKShapeNode(path: CGPath(roundedRect: trayRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.35)
        shadow.strokeColor = .clear
        shadow.zPosition = 999
        shadow.position = CGPoint(x: size.width/2, y: trayHeight/2 - 6)
        hudBarShadow = shadow  // Store reference for visibility control
        addChild(shadow)

        // Main tray
        hudBar = SKShapeNode(path: CGPath(roundedRect: trayRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
        hudBar.fillColor = UIColor(red: 0.05, green: 0.35, blue: 0.32, alpha: 0.80)
        hudBar.strokeColor = UIColor.white.withAlphaComponent(0.45)
        hudBar.lineWidth = 2.0
        hudBar.zPosition = 1000
        hudBar.position = CGPoint(x: size.width/2, y: trayHeight/2)

       

        // Light bottom glow to suggest elevation
        let glow = SKShapeNode(ellipseOf: CGSize(width: trayWidth * 0.9, height: 40))
        glow.fillColor = UIColor.black.withAlphaComponent(0.25)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: -trayHeight/2 - 14)
        glow.zPosition = -1
        hudBar.addChild(glow)

        addChild(hudBar)

        // Containers layout: hearts top center, two ability rows beneath
        let contentTopY: CGFloat = trayHeight/2 - 28

        heartsContainer = SKNode()
        heartsContainer.position = CGPoint(x: 0, y: contentTopY)
        heartsContainer.name = "heartsContainer"
        hudBar.addChild(heartsContainer)

        // First ability row (left cluster)
        lifeVestsContainer = SKNode()
        lifeVestsContainer.position = CGPoint(x: -trayWidth * 0.28, y: contentTopY - 52)
        lifeVestsContainer.name = "lifeVestsContainer"
        hudBar.addChild(lifeVestsContainer)

        // Middle-left cluster: scroll saver
        scrollSaverContainer = SKNode()
        scrollSaverContainer.position = CGPoint(x: -trayWidth * 0.02, y: contentTopY - 52)
        scrollSaverContainer.name = "scrollSaverContainer"
        hudBar.addChild(scrollSaverContainer)

        // Initialize HUD controller
        hudController = HUDController()
        // Configure HUD controller with required references
        if let configurable = hudController as? HUDConfigurable {
            configurable.configure(
                gameScene: self,
                hudBar: hudBar,
                hudBarShadow: hudBarShadow,
                heartsContainer: heartsContainer,
                lifeVestsContainer: lifeVestsContainer,
                scrollSaverContainer: scrollSaverContainer
            )
        } else {
            // Fallback: try setting properties directly if exposed
            hudController.hudBar = hudBar
            hudController.hudBarShadow = hudBarShadow
            hudController.heartsContainer = heartsContainer
            hudController.lifeVestsContainer = lifeVestsContainer
            hudController.scrollSaverContainer = scrollSaverContainer
        }

        // Forward distance-based score gains from HUD to the single score source (ScoreManager)
        hudController.onScoreGained = { [weak self] gained in
            self?.scoreManager.addScore(gained)
        }
        
        // Handle rocket final approach state changes (last 3 seconds of rocket ride)
        hudController.onRocketFinalApproachChanged = { [weak self] inFinalApproach in
            self?.isRocketFinalApproach = inFinalApproach
        }

        updateHUD()
    }
    
    // MARK: - Background Tree Setup
    private func setupBackgroundTree() {
        
        // Create the right side tree aligned to the right edge of screen
        // First, try to load the treeRight.png image
        let treeTexture = SKTexture(imageNamed: "treeRight")
        
        // Check if we have a valid tree image, otherwise use placeholder
        if treeTexture.size().width > 1 && treeTexture.size().height > 1 {
            rightTree = SKSpriteNode(texture: treeTexture)
        }
        
        if let tree = rightTree {
            // Scale appropriately for the scene first so we can calculate proper position
            tree.setScale(0.3)
            
            // Position the tree aligned to the right edge of the screen
            // Using the tree's scaled width to position it properly at the edge
            let treeWidth = tree.size.width
            tree.position = CGPoint(
                x: size.width - (treeWidth * 0.9), // Right edge minus half tree width
                y: size.height * 0.3
            )
            
            // Layer behind the world but in front of background for depth
            tree.zPosition = 100  // Between background (-1000) and world (0)
            
            // Make it slightly transparent to emphasize it's in the background
            tree.alpha = 0.8
            
            addChild(tree)
            
        }
        // Create the left side tree aligned to the left edge of screen
        let leftTexture = SKTexture(imageNamed: "treeLeft")
        if leftTexture.size().width > 1 && leftTexture.size().height > 1 {
            leftTree = SKSpriteNode(texture: leftTexture)
        }
        if let ltree = leftTree {
            ltree.setScale(0.3)
            let treeWidth = ltree.size.width
            ltree.position = CGPoint(
                x: (treeWidth * 0.9),
                y: size.height * 0.3
            )
            ltree.zPosition = 100
            ltree.alpha = 0.8
            addChild(ltree)
        }
    }
    

    
    // MARK: - Background Tree Parallax Update
    private func updateBackgroundTreeParallax() {
        // Update both background trees if present
        let baseY = size.height * 0.3
        let parallaxFactor: CGFloat = 0.3
        let parallaxOffsetY = -frogController.position.y * parallaxFactor
        let currentTime = CFAbsoluteTimeGetCurrent()
        let swayY = cos(currentTime * 0.3) * 4.0
        let finalY = baseY + parallaxOffsetY + swayY

        if let rtree = rightTree {
            let treeWidth = rtree.size.width
            let fixedX = size.width - (treeWidth * 0.5)
            let margin: CGFloat = rtree.size.height * 0.5
            let clampedY = max(-margin, min(size.height + margin, finalY))
            rtree.position = CGPoint(x: fixedX, y: clampedY)
        }

        if let ltree = leftTree {
            let treeWidth = ltree.size.width
            let fixedX = (treeWidth * 0.5)
            let margin: CGFloat = ltree.size.height * 0.5
            let clampedY = max(-margin, min(size.height + margin, finalY))
            ltree.position = CGPoint(x: fixedX, y: clampedY)
        }
    }
    
    // MARK: - Background Tree Reset
    private func resetBackgroundTree() {
        // Reset right tree to its initial position at the right edge
        if let rtree = rightTree {
            let treeWidth = rtree.size.width
            let baseX = size.width - (treeWidth * 0.5)
            let baseY = size.height * 0.6
            rtree.position = CGPoint(x: baseX, y: baseY)
            rtree.alpha = 0.8
        }

        // Reset left tree to its initial position at the left edge
        if let ltree = leftTree {
            let treeWidth = ltree.size.width
            let baseX = (treeWidth * 0.5)
            let baseY = size.height * 0.6
            ltree.position = CGPoint(x: baseX, y: baseY)
            ltree.alpha = 0.8
        }

        print("🌳 Background trees reset. Right: \(String(describing: rightTree?.position)) Left: \(String(describing: leftTree?.position))")
    }
    
    // MARK: - HUD Update
    private func updateHUD() {
        hudController?.updateHUD(
            health: healthManager.health,
            maxHealth: healthManager.maxHealth,
            lifeVestCharges: frogController.lifeVestCharges,
            scrollSaverCharges: healthManager.scrollSaverCharges,
            flySwatterCharges: healthManager.flySwatterCharges,
            honeyJarCharges: healthManager.honeyJarCharges,
            axeCharges: healthManager.axeCharges,
            tadpolesCollected: healthManager.tadpolesCollected,
            tadpolesThreshold: GameConfig.tadpolesForAbility
        )
    }
    
    // MARK: - Game State Management
    private func handleStateChange(from oldState: GameState, to newState: GameState) {
        print("🎮 Game state changed from \(oldState) to \(newState)")
        uiManager.hideMenus()
        
        // Cancel any active slingshot aiming when state changes
        if slingshotController.slingshotActive && newState != .playing {
            print("🎯 Game state changed to \(newState) - canceling slingshot aiming")
            slingshotController.cancelCurrentAiming()
        }
        
        // Cancel pending ability selection if game state changes away from playing
        if newState != .playing && newState != .abilitySelection {
            if let _ = action(forKey: "abilitySelectionDelay") {
                print("🚨 Cancelling pending ability selection action due to state change to \(newState)")
                removeAction(forKey: "abilitySelectionDelay")
                healthManager.forceClearAbilitySelection(reason: "state change to \(newState)")
            }
        }
        
        // Handle audio state changes
        print("🎵 Calling soundController.handleGameStateChange(to: \(newState))")
        soundController.handleGameStateChange(to: newState)
        
        switch newState {
        case .menu:
            uiManager.setUIVisible(false)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 1.0, duration: 0.2))
            worldManager.worldNode.isPaused = true
        case .initialUpgradeSelection:
            print("🎮 State transition: Setting UI invisible for initial upgrade selection")
            uiManager.setUIVisible(false)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 0.9, duration: 0.2))
            worldManager.worldNode.isPaused = true
        case .playing:
            print("🎮 State transition: Setting UI visible and unpausing for playing state")
            uiManager.setUIVisible(true)
            menuBackdrop?.run(SKAction.fadeAlpha(to: 0.0, duration: 0.2))
            worldManager.worldNode.isPaused = false
            
            // If returning from ability selection, restore normal audio
            if oldState == .abilitySelection {
                soundController.resumeFromAbilitySelection()
            }
        case .paused, .abilitySelection, .gameOver:
          //  menuBackdrop?.run(SKAction.fadeAlpha(to: 0.9, duration: 0.2))
            worldManager.worldNode.isPaused = true
        }
    }
    
    private func handleWaterStateChange(from oldState: WaterState, to newState: WaterState) {
        // Visual or audio feedback when water state changes
        switch newState {
        case .water:
            showFloatingText("Water Mode: Watch for splashes!", color: .systemBlue)
            print("💧 Water state changed to WATER - frog can drown")
        case .ice:
            showFloatingText("Ice Mode: Slide to safety!", color: .systemCyan)
            SoundController.shared.playIceCrack()
            print("🧊 Water state changed to ICE - frog will slide")
        }
        
        // Reset frog state when switching water modes
        if frogController.onIce && newState == .water {
            frogController.forceStopSliding()
        }
    }
    
    func showMainMenu() {
        // Menu now handles its own dimming and structure. Backdrop fade is kept for consistency.
        stopLevelTimer()  // Stop timer when going to main menu
        menuBackdrop?.alpha = 1.0
        frogContainer.alpha = 1.0
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        healthManager.pendingAbilitySelection = false
        
        // Hide level indicator during menu
        childNode(withName: "levelIndicator")?.removeFromParent()
        
        // Hide background tree during menu
        rightTree?.alpha = 0.0
        
        // Resume spawning if we're exiting ability selection
        spawnManager.resumeSpawningAfterAbilitySelection()
        
        // Ensure spawn state and pad tadpole flags are reset when returning to menu
        spawnManager.reset(for: &lilyPads, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests)
        
        gameState = .menu
        uiManager.showMainMenu(sceneSize: size)
    }
    
    // MARK: - Game Start
    func startNewGame() {
        print("🎮 Starting completely new game - resetting all progress")
        // Save any pending tadpole coins before starting new game
        uiManager.savePendingTadpoleCoins()
        
        // Force reset all progress for a brand new game
        scoreManager.startFreshGame()
        
        // CRITICAL FIX: Reset level starting score for completely new games
        levelStartingScore = 0
        print("🏁 Reset level starting score to 0 for new game")
        
        // Reset travel distance tracking for new session
        totalSessionTravelDistance = 0
        levelTravelDistances.removeAll()
        print("📏 Reset travel distance tracking for new session")
        
        // TEST: Verify level configuration system is working
        testLevelConfigSystem()
        
        startGame()
    }
    
    func startGameFromLastLevel() {
        print("🎮 Continuing from last completed level")
        // Save any pending tadpole coins before continuing
        uiManager.savePendingTadpoleCoins()
        
        // Continue from the last completed level
        scoreManager.continueFromLastLevel()
        
        // CRITICAL FIX: Set level starting score based on the current score when continuing
        levelStartingScore = scoreManager.score
        print("🏁 Set level starting score to \(levelStartingScore) for continuing game")
        
        // TEST: Verify level configuration system is working
        testLevelConfigSystem()
        
        startGame()
    }
    
    func startGame() {
        print("GameScene.startGame() ENTERED")
        print("🔍 Current gameState: \(gameState)")
        
        // Reset level system only for completely new games (not level progression)
        if gameState == .menu || gameState == .gameOver {
            // Sync currentLevel with ScoreManager's level
            currentLevel = scoreManager.getCurrentLevel()
            baseSpawnRateMultiplier = 1.0 + (CGFloat(currentLevel - 1) * 0.1)
            print("🎮 Starting game at Level \(currentLevel) (from ScoreManager)")
            print("🎮 Base spawn rate multiplier: \(String(format: "%.2f", baseSpawnRateMultiplier))x")
            print("🎮 This should show initial upgrade selection")
            
            // CRITICAL FIX: Set the starting score for finish line calculations
            levelStartingScore = scoreManager.score
            print("🏁 Level starting score set to: \(levelStartingScore)")
            
            // Initialize travel distance tracking for new level
            levelStartingFrogY = 0  // Will be set when frog is positioned
            levelTravelDistance = 0
            print("📏 Travel distance tracking initialized for Level \(currentLevel)")
            
            // WEATHER INTEGRATION: Set appropriate weather for the starting level
            let weatherManager = WeatherManager.shared
            let levelWeather = weatherManager.suggestWeatherForLevel(currentLevel)
            weatherManager.setWeather(levelWeather, effectsManager: effectsManager)
            print("🌤️ Set weather for Level \(currentLevel): \(levelWeather.displayName)")
        } else {
            print("🎮 Continuing from state \(gameState) - no level reset")
            
            // Still ensure weather is appropriate for current level
            let weatherManager = WeatherManager.shared
            let currentWeather = weatherManager.weather
            let expectedWeather = weatherManager.suggestWeatherForLevel(currentLevel)
            
            if currentWeather != expectedWeather {
                print("🌤️ Adjusting weather from \(currentWeather.displayName) to \(expectedWeather.displayName) for Level \(currentLevel)")
                weatherManager.setWeather(expectedWeather, effectsManager: effectsManager)
            }
        }
        
        // CRITICAL FIX: Apply super power bonuses to starting health
        let baseHealth = GameConfig.startingHealth
        let bonusHealth = uiManager.getBonusMaxHealth()
        let startingHealthWithBonuses = baseHealth + bonusHealth
        
        print("❤️ Starting health calculation:")
        print("  - Base health: \(baseHealth)")
        print("  - Super power bonus: \(bonusHealth)")
        print("  - Total starting health: \(startingHealthWithBonuses)")
        
        healthManager.reset(startingHealth: startingHealthWithBonuses)
        
        // Apply all other super power effects at game start
        applySuperPowerEffects()
        
        visualEffectsController.stopLowHealthFlash()
        uiManager.updateStarProgress(current: 0, threshold: GameConfig.tadpolesForAbility)
        
        stateManager.cancelPendingGameOver()
        
        // Cancel any pending ability selection actions from previous game
        if let _ = action(forKey: "abilitySelectionDelay") {
            print("🚨 Cancelling pending ability selection action from previous game")
            removeAction(forKey: "abilitySelectionDelay")
        }
        
        frogController.lifeVestCharges = 0
        uiManager.hideMenus()  // Clear any special track state that might be lingering from previous game
        soundController.handleSpecialAbilityEnded()
        
        gameLoopCoordinator.reset()
        landingController.reset()
        touchInputController.reset()
        
        // Reset spawn-related state and clear any lingering pad-tadpole links
        spawnManager.reset(for: &lilyPads, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests)
        
        // Reset edge spike bushes
        edgeSpikeBushManager.reset()
        
        // Reset finish line
        finishLine?.node.removeFromParent()
        finishLine = nil
        hasSpawnedFinishLine = false
        frogPreviousY = 0
        
        worldManager.reset()
        
        // Reset background tree position
        resetBackgroundTree()
        
        // Reset scoring anchor after world reset
        lastWorldYForScore = worldManager.worldNode.position.y
        
        // Update spawn manager with current level's spawn rate multiplier
        spawnManager.updateSpawnRateMultiplier(baseSpawnRateMultiplier)
        
        // Ensure spawning is resumed for new game
        spawnManager.resumeSpawningAfterAbilitySelection()
        hasInitializedScoreAnchor = true
        // First show the initial upgrade selection
        gameState = .initialUpgradeSelection
        uiManager.showInitialUpgradeSelection(sceneSize: size)
    }
    
    // MARK: - Super Power Effects Application
    /// Apply all super power effects at game start
    private func applySuperPowerEffects() {
        print("🚀 Applying super power effects...")
        
        // Reset impact jumps for the current level
        uiManager.resetImpactJumpsForNewLevel(currentLevel)
        
        // Reset ghost escapes for the current level
        uiManager.resetGhostEscapesForNewLevel(currentLevel)
        
        // Log all current super power levels for debugging
        for powerType in SuperPowerType.allCases {
            let level = uiManager.getSuperPowerLevel(powerType)
            if level > 0 {
                print("  - \(powerType.name): Level \(level)")
                switch powerType {
                case .jumpRange:
                    print("    Effect: \(uiManager.getJumpRangeMultiplier())x jump range")
                case .jumpRecoil:
                    print("    Effect: -\(uiManager.getJumpRecoilReduction())s jump cooldown")
                case .maxHealth:
                    print("    Effect: +\(uiManager.getBonusMaxHealth()) max health")
                case .superJumpFocus:
                    print("    Effect: +\(uiManager.getSuperJumpExtension())s super jump duration")
                case .ghostMagic:
                    print("    Effect: \(uiManager.getGhostEscapesRemaining()) ghost escapes available")
                case .impactJumps:
                    print("    Effect: \(uiManager.getImpactJumpDestroysRemaining()) impact destroys remaining")
                }
            }
        }
        
        print("🚀 Super power effects applied successfully")
    }
    
    // MARK: - Super Power Gameplay Effects
    /// Handle Impact Jumps super power effect when frog lands
    func handleImpactJumpLanding(at landingPosition: CGPoint) {
        // Check if frog has impact jumps remaining
        let remainingImpacts = uiManager.getImpactJumpDestroysRemaining()
        guard remainingImpacts > 0 else { return }
        
        print("💥 Impact Jump triggered! Remaining: \(remainingImpacts)")
        
        // Define impact radius - larger for higher levels
        let impactRadius: CGFloat = 150.0
        
        // Destroy enemies within impact radius
        var destroyedCount = 0
        for i in (0..<enemies.count).reversed() {
            let enemy = enemies[i]
            let dx = enemy.position.x - landingPosition.x
            let dy = enemy.position.y - landingPosition.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance <= impactRadius {
                // Add score for destroyed enemy
                switch enemy.type {
                case .snake:
                    scoreManager.addScore(200)
                case .bee:
                    scoreManager.addScore(100)
                case .dragonfly:
                    scoreManager.addScore(150)
                case .log:
                    scoreManager.addScore(50)
                case .spikeBush, .edgeSpikeBush:
                    scoreManager.addScore(100)
                case .chaser:
                    scoreManager.addScore(300)
                }
                
                // Play destruction effect at screen position
                let screenPos = convert(enemy.position, from: worldManager.worldNode)
                effectsManager?.createExplosionEffect(at: screenPos)
                
                // Remove from lily pad tracking if applicable
                if let targetPad = enemy.targetLilyPad {
                    targetPad.removeEnemyType(enemy.type)
                }
                
                // Remove enemy
                enemy.stopAnimation()
                enemy.node.removeFromParent()
                enemies.remove(at: i)
                destroyedCount += 1
                
                print("💥 Impact destroyed \(enemy.type.rawValue)")
            }
        }
        
        if destroyedCount > 0 {
            // Consume one impact jump charge
            uiManager.useImpactJumpDestroy()
            
            // Play impact effect and sound
            SoundController.shared.playSoundEffect(.frogLand, volume: 1.0)
            HapticFeedbackManager.shared.impact(.heavy)
            
            // Show floating text
            showFloatingText("💥 Impact Jump! \(destroyedCount) destroyed", color: .systemRed)
            showFloatingScore("+\(destroyedCount * 100) IMPACT BONUS", color: .systemRed)
            
            print("💥 Impact Jump destroyed \(destroyedCount) enemies! Remaining impacts: \(uiManager.getImpactJumpDestroysRemaining())")
        }
    }
    
    /// Handle Ghost Magic super power effect to escape from enemies
    func tryGhostEscape() -> Bool {
        let remainingEscapes = uiManager.getGhostEscapesRemaining()
        guard remainingEscapes > 0 else { return false }
        print("👻 Ghost Escape triggered! Remaining: \(remainingEscapes)")
        
        // Use one ghost escape charge
        healthManager.useGhostEscape()
        
        // Make frog temporarily invincible and visually ghost-like
        frogController.activateInvincibility(seconds: 2.0)
        // Create a ghost-like visual effect (make frog semi-transparent briefly)
        let ghostEffect = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.1),
            SKAction.wait(forDuration: 1.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ])
        frogController.frog.run(ghostEffect)
        
        // Play ghost sound and effects
        SoundController.shared.playSoundEffect(.frogLand, volume: 0.5) // TODO: Add ghost sound
        HapticFeedbackManager.shared.impact(.medium)
        
        // Show floating text with remaining count
        let newRemainingEscapes = uiManager.getGhostEscapesRemaining()
        showFloatingText("👻 Ghost Bust! (\(newRemainingEscapes) left)", color: .systemPurple)
        
        print("👻 Ghost Escape used! Remaining escapes: \(newRemainingEscapes)")
        return true
    }
        
    
    
    // This method is called after the player selects their initial upgrade
    func proceedToGameplay() {
        print("GameScene.proceedToGameplay() ENTERED")
        print("🎯 Current game state before transition: \(gameState)")
        
        print("After hideMenus()")
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        menuBackdrop?.run(SKAction.fadeOut(withDuration: 0.2))
       // stateManager.createIceLevel()
        
        // CRITICAL FIX: Reset audio state and start gameplay music immediately
        // This ensures music plays even when coming from game over screen
        soundController.stopBackgroundMusic(fadeOut: false)
        soundController.startGameplayMusic()
        print("🎵 Gameplay music started immediately in startGame()")
        
        // Make sure background is present and sized
        if let bg = backgroundNode, let texture = bg.texture {
            if bg.parent == nil { addChild(bg) }
            bg.zPosition = -1000
            let texSize = texture.size()
            let scaleX = size.width / texSize.width
            let scaleY = size.height / texSize.height
            let scale = max(scaleX, scaleY)
            bg.size = CGSize(width: texSize.width * scale, height: texSize.height * scale)
            bg.position = CGPoint(x: size.width/2, y: size.height/2)
        }
        
        // Transition to playing state
        gameState = .playing
        print("🎯 Game state set to playing: \(gameState)")
        
        // Lock input briefly to allow for smooth transition
        stateManager.lockInput(for: 0.2)
        print("🔒 Input locked for 0.2 seconds during transition")
        
        // Show current level indicator
        showLevelIndicator()
        
        slingshotController.cancelCurrentAiming()
        
        // Reset managers
        // Don't reset score here - it should be managed by the caller
        // proceedToGameplay is used for both new games and level progression
        uiManager.highlightScore(isHighScore: false)
       
        
        stateManager.splashTriggered = false
        frogController.superJumpActive = false
        uiManager.hideSuperJumpIndicator()
        frogController.rocketActive = false
        uiManager.hideRocketIndicator()
        frogController.invincible = false
        stateManager.hasLandedOnce = false
        isRocketFinalApproach = false
        
      
        
        frogController.rocketFramesRemaining = 0
        frogController.suppressWaterCollisionUntilNextJump = false
        frogController.inWater = false
        
        frogContainer.zPosition = 50
        
        // COMPREHENSIVE CLEANUP: Remove all existing nodes before clearing arrays
        print("🧹 Removing all existing world nodes from proceedToGameplay...")
        for enemy in enemies {
            enemy.node.removeFromParent()
        }
        for tadpole in tadpoles {
            tadpole.node.removeFromParent()
        }
        for bigHoneyPot in bigHoneyPots {
            bigHoneyPot.node.removeFromParent()
        }
        for lifeVest in lifeVests {
            lifeVest.node.removeFromParent()
        }
        for lilyPad in lilyPads {
            lilyPad.node.removeFromParent()
        }
        
        enemies.removeAll()
        tadpoles.removeAll()
        bigHoneyPots.removeAll()
        lifeVests.removeAll()
        lilyPads.removeAll()
        
        // CRITICAL FIX: Clear spatial grid after clearing lily pads array
        // This prevents old lily pads from blocking new spawns
        spawnManager.clearSpatialGrid()
        print("🧹 Spatial grid cleared in proceedToGameplay")
        
        
        
        let startWorldPos = CGPoint(x: size.width / 2, y: 0)
        
        let startPad = makeLilyPad(position: startWorldPos, radius: 60)
        startPad.node.position = startPad.position
        startPad.node.zPosition = 10
        worldManager.worldNode.addChild(startPad.node)
        lilyPads.append(startPad)
        
        // CRITICAL FIX: Add starting pad to spatial grid
        spawnManager.addToSpatialGrid(startPad)
        
        let desiredScreenPos = CGPoint(x: size.width / 2, y: size.height * 0.4)
        worldManager.worldNode.position = CGPoint(
            x: desiredScreenPos.x - startWorldPos.x,
            y: desiredScreenPos.y - startWorldPos.y
        )
        frogContainer.position = desiredScreenPos
        
        frogController.frog.removeAllActions()
        frogController.frogShadow.removeAllActions()
        frogContainer.removeAllActions()
        
        frogController.resetToStartPad(startPad: startPad, sceneSize: size)
        
        // Initialize travel distance tracking
        levelStartingFrogY = frogController.position.y
        levelTravelDistance = 0
        print("📏 Travel distance tracking started - starting Y: \(levelStartingFrogY)")
        
        facingDirectionController.resetFacing()
        
        frogContainer.alpha = 1.0
        frogController.frog.alpha = 1.0
        frogController.frogShadow.alpha = 0.3
        
        // Show background tree during gameplay with gentle fade-in
        rightTree?.alpha = 0.0
        rightTree?.run(SKAction.fadeAlpha(to: 0.8, duration: 1.0))
        
        spawnManager.spawnInitialObjects(
            sceneSize: size,
            lilyPads: &lilyPads,
            enemies: &enemies,
            tadpoles: &tadpoles,
            bigHoneyPots: &bigHoneyPots,
            lifeVests: &lifeVests,
            worldOffset: worldManager.worldNode.position.y
        )
        
        // Ensure spawning is resumed for new game
        spawnManager.resumeSpawningAfterAbilitySelection()
        
        // Initialize level timer
        startLevelTimer()
        
        //updateHUD()
        
        print("✅ Game started! Frog world position: \(frogController.position)")
        print("✅ Final game state: \(gameState)")
        print("✅ Input locked: \(stateManager.inputLocked)")
        print("✅ Frog grounded: \(frogController.isGrounded)")
        print("✅ proceedToGameplay() completed successfully")
    }
    
    // MARK: - Game Over
    func gameOver(_ reason: GameOverReason) {
        stateManager.triggerGameOver(reason)
    }
    
    // MARK: - Level Timer Management
    
    private func startLevelTimer() {
        levelStartTime = CACurrentMediaTime()
        levelTimeRemaining = GameConfig.levelTimeLimit
        levelTimerActive = true
        print("⏱️ Started level timer: \(GameConfig.levelTimeLimit) seconds")
    }
    
    private func updateLevelTimer() {
        guard levelTimerActive else { return }
        
        let currentTime = CACurrentMediaTime()
        let elapsedTime = currentTime - levelStartTime
        levelTimeRemaining = max(0, GameConfig.levelTimeLimit - elapsedTime)
        
        // Update timer display
        hudController.updateTimer(timeRemaining: levelTimeRemaining)
        
        // Check if time is up
        if levelTimeRemaining <= 0 {
            levelTimerActive = false
            hudController.hideTimer()
            print("⏱️ Time's up! Game over.")
            gameOver(.timeUp)
        }
    }
    
    private func stopLevelTimer() {
        levelTimerActive = false
        hudController.hideTimer()
        print("⏱️ Level timer stopped")
    }
    
    private func calculateTimeBonus() -> Int {
        guard levelTimeRemaining > 0 else { return 0 }
        
        let secondsRemaining = Int(ceil(levelTimeRemaining))
        let bonus = secondsRemaining * GameConfig.timeBonus
        
        print("⏱️ Time bonus: \(secondsRemaining) seconds × \(GameConfig.timeBonus) points = \(bonus) points")
        return bonus
    }
    
    // MARK: - Ability Selection
    func selectAbility(_ abilityStr: String) {
        print("🎯 Selecting ability: \(abilityStr)")
        
        // Debug: Show what ability manager is receiving
        print("🎯 Calling abilityManager.selectAbility with: '\(abilityStr)'")
        
        abilityManager.selectAbility(abilityStr)
        healthManager.pendingAbilitySelection = false
        
        // Show visual feedback for the selected ability
        if abilityStr.contains("extraHeart") {
            showFloatingText("Extra Heart!", color: .systemRed)
        } else if abilityStr.contains("superJump") {
            showFloatingText("Super Jump!", color: .systemYellow)
        } else if abilityStr.contains("refillHearts") {
            showFloatingText("Hearts Restored!", color: .systemGreen)
        } else if abilityStr.contains("lifeVest") {
            showFloatingText("Life Vest!", color: .systemBlue)
        } else if abilityStr.contains("scrollSaver") {
            showFloatingText("Scroll Saver!", color: .systemCyan)
        } else if abilityStr.contains("flySwatter") {
            showFloatingText("Fly Swatter!", color: .systemOrange)
        } else if abilityStr.contains("honeyJar") {
            showFloatingText("Honey Protection!", color: .systemYellow)
        } else if abilityStr.contains("axe") {
            showFloatingText("Axe!", color: .systemBrown)
        } else if abilityStr.contains("rocket") {
            showFloatingText("Rocket Boost!", color: .systemPurple)
        } else {
            print("🚨 Unknown ability type: \(abilityStr)")
            showFloatingText("Unknown Ability", color: .systemGray)
        }
        
        // Update HUD to reflect the new ability/upgrade
        print("🔄 Updating HUD after ability selection")
        updateHUD()
        
        // Resume spawning when ability selection ends
        spawnManager.resumeSpawningAfterAbilitySelection()
        
        // Hide the ability selection menu
        uiManager.hideMenus()
        
        gameState = .playing
        print("✅ Ability selection complete, game state: \(gameState)")
    }
    
    // MARK: - Initial Upgrade Selection
    func handleInitialUpgradeSelection(_ buttonName: String) {
        // Parse the upgrade type from button name
        let upgradeString = buttonName.replacingOccurrences(of: "initialUpgrade_", with: "")
        
        print("🎯 Selecting initial upgrade: \(upgradeString)")
        
        // Apply the selected upgrade using the same ability manager system as selectAbility
        // Match the AbilityType enum values used in UIManager
        switch upgradeString {
        case "lifeVest":  // Fixed: was "lifeVests" (plural)
            abilityManager.onLifeVestSelected?()
            showFloatingText("Life Vest Added!", color: .systemYellow)
        case "honeyJar":  // Fixed: was "honeypot"
            abilityManager.onHoneyJarSelected?()
            showFloatingText("Honey Protection Added!", color: .systemOrange)
        case "extraHeart":
            abilityManager.onExtraHeartSelected?()
            showFloatingText("Extra Heart Added!", color: .systemRed)
        default:
            print("Unknown initial upgrade: \(upgradeString)")
            // Still proceed to gameplay even if upgrade is unknown
        }
        
        // Update HUD to reflect the new upgrade (same as selectAbility)
        print("🔄 Updating HUD after initial upgrade selection")
        updateHUD()
        
        // Hide the upgrade selection and proceed to gameplay
        uiManager.hideMenus()
        
        // Add a small delay to ensure UI transition completes smoothly
        let delay = SKAction.wait(forDuration: 0.1)
        let proceedAction = SKAction.run { [weak self] in
            self?.proceedToGameplay()
        }
        run(SKAction.sequence([delay, proceedAction]))
    }
    
    // MARK: - Performance Tracking
    private var lastFrameTime: TimeInterval = 0
    private var frameTimes: [TimeInterval] = []
    private let maxFrameTimesSamples = 60  // Track last 60 frames
    
    // MARK: - Cached Values for Performance
    private var cachedLeftWorldX: CGFloat = -100
    private var cachedRightWorldX: CGFloat = 100
    
    // MARK: - Update Loop
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        
        // PERFORMANCE: Track frame times to identify stutters
        if lastFrameTime > 0 {
            let deltaTime = currentTime - lastFrameTime
            frameTimes.append(deltaTime)
            if frameTimes.count > maxFrameTimesSamples {
                frameTimes.removeFirst()
            }
            
            // Alert on frame drops (> 20ms = < 50 FPS)
            if deltaTime > 0.020 && gameLoopCoordinator.getFrameCount() % 60 == 0 {
                let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
                let fps = 1.0 / avgFrameTime
                print("⚠️  Frame drop detected: \(String(format: "%.1f", deltaTime * 1000))ms (Avg FPS: \(String(format: "%.1f", fps)))")
            }
        }
        lastFrameTime = currentTime
        
        // PERFORMANCE MONITORING: Log object counts occasionally
        if gameLoopCoordinator.getFrameCount() % 600 == 0 { // Every 10 seconds at 60fps
            // OPTIMIZED: Count types in single pass instead of multiple filters
            var logCount = 0, beeCount = 0, snakeCount = 0, dragonflyCount = 0, spikeBushCount = 0
            for enemy in enemies {
                switch enemy.type {
                case .log: logCount += 1
                case .bee: beeCount += 1  
                case .snake: snakeCount += 1
                case .dragonfly: dragonflyCount += 1
                case .spikeBush: spikeBushCount += 1
                case .edgeSpikeBush: break // Counted separately
                case .chaser: break
        
                }
            }
            let padCount = lilyPads.count
            let tadpoleCount = tadpoles.count
            let totalNodes = scene?.children.count ?? 0
            
            print("🔧 Performance Snapshot:")
            print("   - Total scene nodes: \(totalNodes)")
            print("   - Lily pads: \(padCount)")
            print("   - Logs: \(logCount), Bees: \(beeCount), Snakes: \(snakeCount)")
            print("   - Dragonflies: \(dragonflyCount), Spike bushes: \(spikeBushCount)")
            print("   - Tadpoles: \(tadpoleCount)")
            print("   - Frame: \(gameLoopCoordinator.getFrameCount())")
            
            // Alert if object counts are getting excessive
            if totalNodes > 200 {
                print("⚠️  HIGH NODE COUNT: \(totalNodes) nodes in scene")
            }
            if logCount > 15 {
                print("⚠️  HIGH LOG COUNT: \(logCount) logs active")
            }
            
            // CRITICAL: Emergency cleanup if we have way too many objects
            if padCount > 50 || logCount > 25 || totalNodes > 400 {
                print("🚨 EMERGENCY: Object count dangerously high - triggering force cleanup")
                print("   - Pads: \(padCount), Logs: \(logCount), Total nodes: \(totalNodes)")
                forceCompleteCleanup()
                
                // Respawn essential objects
                spawnManager.spawnInitialObjects(
                    sceneSize: size,
                    lilyPads: &lilyPads,
                    enemies: &enemies,
                    tadpoles: &tadpoles,
                    bigHoneyPots: &bigHoneyPots,
                    lifeVests: &lifeVests,
                    worldOffset: worldManager.worldNode.position.y
                )
            }
        }
        
        // PERFORMANCE: Only update background if it's not already configured
        if let bg = backgroundNode, bg.parent == nil {
            addChild(bg)
            if let texture = bg.texture {
                let texSize = texture.size()
                let scaleX = size.width / texSize.width
                let scaleY = size.height / texSize.height
                let scale = max(scaleX, scaleY)
                bg.size = CGSize(width: texSize.width * scale, height: texSize.height * scale)
                bg.position = CGPoint(x: size.width/2, y: size.height/2)
            }
        }
        
        gameLoopCoordinator.incrementFrame()
        let frameCount = gameLoopCoordinator.getFrameCount()
        
        // Update level timer
        updateLevelTimer()
        
        // Debug state every 10 seconds if frog seems stuck
        if frameCount % 600 == 0 { // Every 10 seconds at 60fps
            if !frogController.isGrounded && !frogController.inWater && !frogController.isJumping && !frogController.rocketActive {
                debugFrogState()
                print("🚨 Frog appears to be in stuck state - attempting recovery")
                
                // Force unlock input if it's been locked too long
                if stateManager.inputLocked {
                    stateManager.forceUnlockInput()
                }
                
                // Also cancel any stuck slingshot aiming
                if slingshotController.slingshotActive {
                    print("🎯 Found stuck slingshot during recovery - canceling")
                    slingshotController.cancelCurrentAiming()
                }
                
                // Try to recover the frog state
                _ = attemptStateRecovery()
            }
            
            // Check for stuck ability selection state
            if healthManager.pendingAbilitySelection && gameState == .playing && 
               frogController.isGrounded && !frogController.isJumping {
                print("🚨 Detected stuck pendingAbilitySelection - clearing")
                
                // Cancel any pending ability selection actions
                if let _ = action(forKey: "abilitySelectionDelay") {
                    print("🚨 Also cancelling stuck ability selection action")
                    removeAction(forKey: "abilitySelectionDelay")
                }
                
                healthManager.forceClearAbilitySelection(reason: "periodic stuck detection")
            }
        }
        
        // PERFORMANCE: Spawn objects only after successful jumps (handled in landing callback)
        // Removed frequent spawn calls from update loop for better performance
           
        // PERFORMANCE: Cleanup now handled on landing events instead of time-based
        // This is much more efficient than running cleanup every N frames
        
        if stateManager.inputLocked { return }
        
        // Dynamic scroll speed calculation
        var dynamicScroll: CGFloat = 0
        if frogController.rocketActive {
            // Check if we're in the final approach (last 3 seconds of rocket ride)
            if isRocketFinalApproach {
                // Slow down to 50% speed during final approach to help user find a lilypad
                dynamicScroll = GameConfig.rocketFinalApproachScrollSpeed
            } else {
                dynamicScroll = GameConfig.rocketScrollSpeed
            }
            
            // If we're within the rocket landing grace period after landing, slow even more
            if landingController.rocketLandingGraceFrames > 0 {
                dynamicScroll = GameConfig.rocketLandingSlowScrollSpeed
            }
            
            frogController.position.y += dynamicScroll

            let rocketScore = Int(dynamicScroll * 3)
            scoreManager.addScore(rocketScore)

            if frameCount % 20 == 0 {
                showFloatingScore("+\(rocketScore)", color: .orange)
            }
        } else {
            // No auto-scroll until the player has made and completed the first landing
            // Also stop auto-scroll while grounded/idle (not jumping)
            if stateManager.hasLandedOnce && !(frogController.isGrounded && !frogController.isJumping) {
                let speedTiers = score / GameConfig.scoreIntervalForSpeedIncrease
                let calculatedSpeed = GameConfig.scrollSpeed + (CGFloat(speedTiers) * GameConfig.scrollSpeedIncrement)
                dynamicScroll = min(GameConfig.maxScrollSpeed, calculatedSpeed)
            } else {
                dynamicScroll = 0
            }
        }
        
        // No automatic vertical scroll; world y is derived from frog centering
        
        // Keep frog centered on screen; move world around it
        let screenCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        frogContainer.position = screenCenter
        // Position world so that frog's world position maps to the screen center
        worldManager.worldNode.position.x = screenCenter.x - frogController.position.x
        worldManager.worldNode.position.y = screenCenter.y - frogController.position.y
        
        // PERFORMANCE: Update parallax background every 3 frames for smoother but efficient motion
        if frameCount % 3 == 0 {
            updateBackgroundTreeParallax()
        }
        
        // Distance-based scoring: when the world moves downward relative to the screen, the frog advanced upward in world space.
        if hasInitializedScoreAnchor {
            // World node y decreases as we move "forward" (frog up). Compute positive progress.
            let prev = lastWorldYForScore
            let curr = worldManager.worldNode.position.y
            let deltaWorldY = prev - curr // positive when world moved down
            if deltaWorldY > 0 {
                hudController?.updateScoreForVerticalScroll(deltaY: deltaWorldY)
                
                // Track travel distance - positive deltaWorldY means frog moved upward
                levelTravelDistance += deltaWorldY
                totalSessionTravelDistance += deltaWorldY
                
                // Store the travel distance for this level
                levelTravelDistances[currentLevel] = levelTravelDistance
                
                // Debug output every ~100 units of travel to avoid spam
                if Int(levelTravelDistance) % 100 < Int(levelTravelDistance - deltaWorldY) % 100 {
                    print("📏 Level \(currentLevel) travel: \(Int(levelTravelDistance)) units (session: \(Int(totalSessionTravelDistance)))")
                }
            }
            lastWorldYForScore = curr
        } else {
            lastWorldYForScore = worldManager.worldNode.position.y
            hasInitializedScoreAnchor = true
        }
        
        // Replace scroll score add with no double scoring
        _ = worldManager.updateScrolling(isJumping: frogController.isJumping)
        
        // Horizontal movement during rocket only
        if frogController.rocketActive {
            touchInputController.updateRocketSteering(
                frogContainerX: frogContainer.position.x,
                sceneWidth: size.width
            )
            
            if let targetX = touchInputController.glideTargetScreenX {
                let currentX = frogContainer.position.x
                frogContainer.position.x = currentX + (targetX - currentX) * glideLerp
                
                let newWorld = convert(CGPoint(x: frogContainer.position.x, y: frogContainer.position.y),
                                       to: worldManager.worldNode)
                frogController.position.x = newWorld.x
            }
            
            // World positioning to allow horizontal movement
            let offsetFromCenter = frogContainer.position.x - (size.width / 2)
            let desiredWorldX = -offsetFromCenter * 0.4
            worldManager.worldNode.position.x += (desiredWorldX - worldManager.worldNode.position.x) * worldGlideLerp
        }
        
        let frogScreenPoint = frogContainer.position
        let frogScreenY = frogContainer.position.y
        let failThreshold: CGFloat = -40
        
        // Check for scrolled off screen
        if frogScreenY < failThreshold && gameState == .playing && !frogController.rocketActive && landingController.rocketLandingGraceFrames <= 0 {
            handleScrolledOffScreen(frogScreenPoint: frogScreenPoint)
        }
        
        frogController.updateJump()
        
        // Update ice sliding if active
        if frogController.onIce {
            frogController.updateSliding()
            
            // OPTIMIZED: Only check lily pad collision every 3 frames during sliding to reduce overhead
            if frameCount % 3 == 0 {
                let slideCollisionDistance: CGFloat = 60
                let slideCollisionDistanceSq = slideCollisionDistance * slideCollisionDistance // Avoid sqrt
                
                for pad in lilyPads {
                    let dx = frogController.position.x - pad.position.x
                    let dy = frogController.position.y - pad.position.y
                    let distanceSq = dx*dx + dy*dy // Use squared distance to avoid expensive sqrt
                    
                    if distanceSq < slideCollisionDistanceSq {
                        // Stop sliding and land on the pad
                        frogController.forceStopSliding()
                        frogController.landOnPad(pad)
                        
                        // Play landing sound and effect
                        SoundController.shared.playFrogLand()
                        effectsManager?.createLandingEffect(at: convert(frogController.position, from: worldManager.worldNode), intensity: 0.5, lilyPad: pad)
                        HapticFeedbackManager.shared.impact(.light)
                        
                        showFloatingText("Landed!", color: .systemGreen)
                        print("🧊 Frog slid into lily pad and stopped")
                        break
                    }
                }
            }
        }
        
        // Update the frog's facing direction based on movement/state
        facingDirectionController.updateFacingDirection(
            isPlaying: gameState == .playing,
            rocketActive: frogController.rocketActive,
            frogContainerPosition: frogContainer.position,
            glideTargetScreenX: touchInputController.glideTargetScreenX,
            frogVelocity: frogController.velocity
        )
        
//        let scrollScore = worldManager.updateScrolling(isJumping: frogController.isJumping)
//        scoreManager.addScore(scrollScore)
        
        if !frogController.isJumping && !frogController.isGrounded && !frogController.inWater {
            let landingResult = landingController.checkLanding(
                frogPosition: frogController.position,
                lilyPads: lilyPads,
                isJumping: frogController.isJumping,
                isGrounded: frogController.isGrounded
            )
        }
        
        if frogController.isGrounded, let pad = frogController.currentLilyPad, pad.type == .pulsing, !pad.isSafeToLand {
            if frogController.suppressWaterCollisionUntilNextJump {
            } else {
                handleUnsafePadLanding()
            }
            return
        }
        
        // PERFORMANCE: Reduce frequency of expensive collision updates  
        if frameCount % 2 == 0 {  // Run collision updates every other frame
            // Update enemies with collision handling
            updateEnemies(frogScreenPoint: frogScreenPoint)
        }
        
        // PERFORMANCE: Update edge spike bushes less frequently to reduce overhead
        if frameCount % 4 == 0 {  // Every 4th frame instead of every other frame
            // Update and check collisions with edge spike bushes
            edgeSpikeBushManager.updateAndSpawn(
                worldOffset: worldManager.worldNode.position.y,
                sceneSize: size,
                frogPosition: frogController.position
            )
            
            // Check collisions with edge spike bushes using the collision manager
            let edgeSpikeBushes = edgeSpikeBushManager.getAllEdgeSpikeBushes()
            for bush in edgeSpikeBushes {
                if collisionManager.checkCollision(enemy: bush, frogPosition: frogController.position, frogIsJumping: frogController.isJumping) {
                    if !frogController.invincible && !frogController.rocketActive {
                        handleEdgeSpikeBushCollision()
                        break // Only process one collision per frame
                    }
                }
            }
        }
        
        // PERFORMANCE: Cache coordinate conversions to avoid expensive matrix math every frame
        if frameCount % 5 == 0 {  // Update world bounds every 5 frames instead of every frame
            cachedLeftWorldX = convert(CGPoint(x: -100, y: 0), to: worldManager.worldNode).x
            cachedRightWorldX = convert(CGPoint(x: size.width + 100, y: 0), to: worldManager.worldNode).x
        }
        
        gameLoopCoordinator.updateEnemies(
            enemies: &enemies,
            lilyPads: &lilyPads,
            frogPosition: frogController.position,
            leftWorldX: cachedLeftWorldX,
            rightWorldX: cachedRightWorldX,
            worldOffset: worldManager.worldNode.position.y,
            sceneHeight: size.height
        )
        
        // THREAD SAFETY: Flush any pending enemies to avoid simultaneous access issues
        spawnManager.flushPendingEnemies(to: &enemies)
        
        // Update tadpoles
        collisionManager.updateTadpoles(
            tadpoles: &tadpoles,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            worldOffset: worldManager.worldNode.position.y,
            screenHeight: size.height,
            rocketActive: frogController.rocketActive,
            onCollect: { [weak self] in
                self?.handleTadpoleCollect()
            }
        )
        
        // Update big honey pots
        collisionManager.updateBigHoneyPots(
            bigHoneyPots: &bigHoneyPots,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            worldOffset: worldManager.worldNode.position.y,
            screenHeight: size.height,
            rocketActive: frogController.rocketActive,
            onCollect: { [weak self] in
                self?.handleBigHoneyPotCollect()
            }
        )
        
        // Update life vests
        collisionManager.updateLifeVests(
            lifeVests: &lifeVests,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            worldOffset: worldManager.worldNode.position.y,
            screenHeight: size.height,
            rocketActive: frogController.rocketActive,
            onCollect: { [weak self] in
                self?.handleLifeVestCollect()
            }
        )
        
        // SAFETY: Validate BigHoneyPot placements periodically to prevent water spawning
        if frameCount % 30 == 0 {  // Validate every 30 frames (0.5 seconds at 60fps)
            collisionManager.validateBigHoneyPotPlacements(bigHoneyPots: &bigHoneyPots, lilyPads: lilyPads)
            collisionManager.validateLifeVestPlacements(lifeVests: &lifeVests, lilyPads: lilyPads)
            
            // Optional debug logging (can be enabled/disabled as needed)
            #if DEBUG
            if frameCount % 300 == 0 {  // Debug report every 5 seconds
                collisionManager.debugBigHoneyPotPlacements(bigHoneyPots: bigHoneyPots)
                collisionManager.debugLifeVestPlacements(lifeVests: lifeVests)
            }
            #endif
        }
        
        // PERFORMANCE: Update lily pads every other frame to reduce overhead
        if frameCount % 2 == 1 {  // Alternate with enemy updates
            collisionManager.updateLilyPads(
                lilyPads: &lilyPads,
                worldOffset: worldManager.worldNode.position.y,
                screenHeight: size.height,
                frogPosition: frogController.position
            )
        }
        
        // MARK: - Finish Line Logic
        // Check if travel distance has reached threshold and spawn finish line if not already spawned
        // UPDATED: Use travel distance instead of score for finish line spawning
        let requiredDistance = LevelEnemyConfigManager.getRequiredTravelDistance(for: currentLevel)
        
        if levelTravelDistance >= requiredDistance && !hasSpawnedFinishLine {
            print("🏁 Spawning finish line after \(Int(levelTravelDistance)) units travel (required: \(Int(requiredDistance))) for Level \(currentLevel)")
            spawnFinishLine()
        }
        
        // Check for finish line crossing
        if let finishLine = finishLine {
            // CRITICAL: Only check for crossing if we haven't already triggered level completion
            if action(forKey: "levelTransition") == nil {
                let crossed = finishLine.checkCrossing(frogPosition: frogController.position, frogPreviousY: frogPreviousY)
                
                // PERFORMANCE: Only do debug output every 180 frames (3 seconds) when near finish line
                if crossed {
                    print("🏁 Finish line crossed detected in update loop")
                    handleFinishLineCrossed()
                } else if gameLoopCoordinator.getFrameCount() % 180 == 0 {
                    let currentY = frogController.position.y
                    let finishY = finishLine.position.y
                    if abs(currentY - finishY) < 200 {
                        print("🏁 Near finish line: frogY=\(Int(currentY)), finishY=\(Int(finishY)), distance=\(Int(finishY - currentY))")
                    }
                }
            }
        }
        
        // Store frog's current Y position for next frame's finish line crossing detection
        frogPreviousY = frogController.position.y
        
        frogController.updateInvincibility()
        if !frogController.invincible {
            visualEffectsController.stopInvincibilityFlicker()
        }
        
        frogController.updateSuperJump(indicator: uiManager.superJumpIndicator)
        if !frogController.superJumpActive {
            uiManager.hideSuperJumpIndicator()
        }
        
        frogController.updateRocket(indicator: uiManager.rocketIndicator)
        
        // Update HUD for rocket final approach (last 3 seconds)
        if frogController.rocketActive {
            let timeRemaining = TimeInterval(frogController.rocketFramesRemaining) / 60.0
            hudController?.updateRocketFinalApproach(timeRemaining: timeRemaining)
            
            // Show land button when 4 seconds or less remain (240 frames at 60 fps)
            if frogController.rocketFramesRemaining <= 240 {
                if uiManager.rocketLandButton == nil {
                    uiManager.showRocketLandButton(sceneSize: size)
                }
            } else {
                uiManager.hideRocketLandButton()
            }
        } else {
            // Clear the banner when rocket is not active
            hudController?.updateRocketFinalApproach(timeRemaining: nil)
            uiManager.hideRocketLandButton()
        }
        
        // Check if rocket just ended: decide landing outcome
        if !frogController.rocketActive && frogContainer.zPosition > 50 {
            handleRocketEnd()
        }
        
        landingController.updatePauseFrames()
    }
    
    // MARK: - Enemy Update
    private func updateEnemies(frogScreenPoint: CGPoint) {
        collisionManager.updateEnemies(
            enemies: &enemies,
            frogPosition: frogController.position,
            frogScreenPosition: frogScreenPoint,
            rocketActive: frogController.rocketActive,
            frogIsJumping: frogController.isJumping,
            worldOffset: worldManager.worldNode.position.y,
            lilyPads: &lilyPads,
            onHit: { [weak self] enemy -> HitOutcome in
                return self?.handleEnemyHit(enemy: enemy) ?? .hitOnly
            },
            onLogBounce: { [weak self] enemy in
                self?.handleLogBounce(enemy: enemy)
            }
        )
    }
    
    private func handleEnemyHit(enemy: Enemy) -> HitOutcome {
        var consumedProtection = false
        var destroyCause: AbilityType? = nil
        
        if enemy.type == EnemyType.bee && healthManager.useHoneyJarCharge() {
            consumedProtection = true
            destroyCause = .honeyJar
            showFloatingText("Yum Yum!", color: .systemYellow)
            // Honey jar protects fully from bees: remove bee, no heart lost, no invincibility side effects.
            return .destroyed(cause: .honeyJar)
        } else if enemy.type == EnemyType.log && healthManager.useAxeCharge() {
            consumedProtection = true
            destroyCause = .axe
            showFloatingText("Chop!", color: .systemGreen)
        } else if enemy.type == EnemyType.dragonfly && healthManager.useFlySwatterCharge() {
            consumedProtection = true
            destroyCause = nil
            showFloatingText("Swat!", color: .systemOrange)
        }
        
        // Try ghost escape if no other protection was used
        if !consumedProtection && enemy.type == EnemyType.chaser && tryGhostEscape() {
            consumedProtection = true
            // Ghost escape destroys chasers
            return .destroyed(cause: nil)
        }
        
        // Logs: if we have an axe, chop and pass through; otherwise, bonk/bounce without losing a heart
        if enemy.type == EnemyType.log {
            if consumedProtection, destroyCause == .axe {
                return .destroyed(cause: .axe)
            } else {
                return .hitOnly
            }
        }
        
        if !consumedProtection {
            healthManager.damageHealth()
            // Show scared reaction on the frog for a brief moment
            frogController.showScared(duration: 1.0)
        }
        
        frogController.activateInvincibility()
        
        // Handle spike bushes - they damage the frog but remain in place
        if enemy.type == EnemyType.spikeBush || enemy.type == EnemyType.edgeSpikeBush {
            // Spike bushes damage frog but don't get destroyed
            return .hitOnly
        }
        
        // Always remove bees, dragonflies, and snakes when they hit the frog
        if enemy.type == EnemyType.bee || enemy.type == EnemyType.dragonfly || enemy.type == EnemyType.snake {
            return .destroyed(cause: destroyCause)
        }
        
        if consumedProtection {
            return .destroyed(cause: destroyCause)
        } else {
            return .hitOnly
        }
    }
    
 func handleLogBounce(enemy: Enemy) {
        let dx = frogController.position.x - enemy.position.x
        let dy = frogController.position.y - enemy.position.y
        let len = max(0.001, sqrt(dx*dx + dy*dy))
        let nx = dx / len
        let ny = dy / len
        
        let v = frogController.velocity
        let dot = v.dx * nx + v.dy * ny
        var reflected = CGVector(dx: v.dx - 2 * dot * nx,
                                 dy: v.dy - 2 * dot * ny)
        reflected.dx *= 0.7
        reflected.dy *= 0.7
        
        let separation: CGFloat = 8
        let sepPos = CGPoint(x: frogController.position.x + nx * separation,
                             y: frogController.position.y + ny * separation)
        frogController.position = sepPos
        
        let reflLen = max(0.001, sqrt(reflected.dx * reflected.dx + reflected.dy * reflected.dy))
        let rnx = reflected.dx / reflLen
        let rny = reflected.dy / reflLen
        let reboundDistance: CGFloat = 120
        let reboundTarget = CGPoint(x: sepPos.x + rnx * reboundDistance,
                                    y: sepPos.y + rny * reboundDistance)
        
        frogController.startJump(to: reboundTarget)
        
        frogController.superJumpActive = false
        uiManager.hideSuperJumpIndicator()
        
        effectsManager?.createBonkLabel(at: frogContainer.position)
        HapticFeedbackManager.shared.impact(.heavy)
    }
    
    private func handleEdgeSpikeBushCollision() {
        // Try ghost escape first
        if tryGhostEscape() {
            return // Ghost escape successful, no damage taken
        }
        
        // Damage the frog's health
        healthManager.damageHealth()
        
        // Show scared reaction on the frog
        frogController.showScared(duration: 1.0)
        
        // Activate invincibility frames
        frogController.activateInvincibility()
        
        // Play ice crack sound to indicate hitting the spike bushes
        soundController.playIceCrack()
        
        // Add some visual feedback
        showFloatingText("Ouch!", color: .systemRed)
        
        // Heavy haptic feedback
        HapticFeedbackManager.shared.impact(.heavy)
    }
    
    // MARK: - Tadpole Collection
    private func handleTadpoleCollect() {
        if frogController.rocketActive { return }
        
        let abilityTriggered = healthManager.collectTadpole()
        scoreManager.addScore(100)
        soundController.playCollectSound()
        soundController.playScoreSound(scoreValue: 100)
        
        // Award tadpole coins for Super Powers system
        uiManager.pendingTadpoleCoins += 1
        
        showFloatingScore("+100", color: .systemYellow)
        
        if abilityTriggered {
            print("🎯 Ability triggered! pendingAbilitySelection: \(healthManager.pendingAbilitySelection)")
            print("🎯 Current frog state - isGrounded: \(frogController.isGrounded), isJumping: \(frogController.isJumping)")
            print("🎯 Game state: \(gameState)")
            
            // If frog is already grounded (not jumping), trigger ability selection immediately
            if frogController.isGrounded && !frogController.isJumping && gameState == .playing {
                print("🎯 Frog is grounded - triggering ability selection immediately")
                
                // Lock input during the animation window
                stateManager.lockInput(for: 1.0)
                let vfx = visualEffectsController!
                vfx.playUpgradeCue()

                // Pause spawning and clear enemies immediately for a calm scene
                if let currentPad = frogController.currentLilyPad {
                    spawnManager.pauseSpawningAndClearEnemies(around: currentPad, enemies: &enemies, sceneSize: size)
                }

                // Delay showing the ability selection to let the animation be seen
                let delay = SKAction.wait(forDuration: 0.9)
                let abilitySelectionAction = SKAction.run { [weak self] in
                    guard let self = self else { 
                        return 
                    }
                    
                    // Clear the pending flag and show UI
                    self.healthManager.pendingAbilitySelection = false
                    
                    if self.gameState == .playing {
                        self.gameState = .abilitySelection
                        self.uiManager.showAbilitySelection(sceneSize: self.size)
                        print("🎯 Ability selection shown immediately after tadpole collection")
                    } else {
                        print("🚨 Ability selection cancelled due to game state change: \(self.gameState)")
                    }
                }
                
                let sequence = SKAction.sequence([delay, abilitySelectionAction])
                run(sequence, withKey: "abilitySelectionDelay")
            } else {
                print("🎯 Frog not grounded - ability selection will be shown on next landing")
            }
        }
    }
    
    // MARK: - Big Honey Pot Collection
    private func handleBigHoneyPotCollect() {
        if frogController.rocketActive { return }
        
        // Max out honey jar charges (set to 4 as specified)
        healthManager.maxOutHoneyJarCharges()
        
        // Give significant score bonus for collecting big honey pot
        scoreManager.addScore(500)
        soundController.playCollectSound()
        soundController.playScoreSound(scoreValue: 500)
        
        showFloatingScore("+500 - Honey Maxed!", color: .systemOrange)
        
        // Visual feedback
        showFloatingText("Honey Pot Maxed!", color: .systemOrange)
        
        // Light haptic feedback for positive collection
        HapticFeedbackManager.shared.impact(.medium)
    }
    
    // MARK: - Life Vest Collection
    private func handleLifeVestCollect() {
        if frogController.rocketActive { return }
        
        // Refill all 4 lifevest slots as specified
        frogController.lifeVestCharges = 4
        
        // Give significant score bonus for collecting life vest
        scoreManager.addScore(400)
        soundController.playCollectSound()
        soundController.playScoreSound(scoreValue: 400)
        
        showFloatingScore("+400 - Life Vests Refilled!", color: .systemBlue)
        
        // Visual feedback
        showFloatingText("Life Vests Refilled!", color: .systemBlue)
        
        // Update HUD to show refilled life vest charges
        updateHUD()
        
        // Light haptic feedback for positive collection
        HapticFeedbackManager.shared.impact(.medium)
    }
    
    // MARK: - Scrolled Off Screen
    private func handleScrolledOffScreen(frogScreenPoint: CGPoint) {
        if healthManager.useScrollSaverCharge() {
            let targetWorldY = -worldManager.worldNode.position.y + size.height * 0.75
            let safeX = max(80, min(size.width - 80, frogController.position.x))
            let newPadPos = CGPoint(x: safeX, y: targetWorldY)
            let rescuePad = makeLilyPad(position: newPadPos, radius: CGFloat.random(in: GameConfig.minLilyPadRadius...GameConfig.maxLilyPadRadius))
            rescuePad.node.position = rescuePad.position
            rescuePad.node.zPosition = 10
            worldManager.worldNode.addChild(rescuePad.node)
            lilyPads.append(rescuePad)
            frogController.position = newPadPos
            frogController.landOnPad(rescuePad)
            // Rescue pad landing: small-to-medium ripple to feel gentle
            effectsManager?.createLandingEffect(at: convert(newPadPos, from: worldManager.worldNode), intensity: 0.4, lilyPad: rescuePad)
            showFloatingText("Scroll Saver -1", color: .systemYellow)
        } else {
            HapticFeedbackManager.shared.notification(.error)
            gameOver(.tooSlow)
        }
    }
    
    // MARK: - Rocket End
    private func handleRocketEnd() {
        frogContainer.zPosition = 50
        
        if let padUnderFrog = landingController.checkRocketLanding(
            frogPosition: frogController.position,
            lilyPads: lilyPads
        ) {
            // Successful landing
            frogController.landOnPad(padUnderFrog)
            frogController.isGrounded = true
            frogController.inWater = false
            // Rocket landings use a medium-high intensity ripple
            effectsManager?.createLandingEffect(at: frogContainer.position, intensity: 0.75, lilyPad: padUnderFrog)
            HapticFeedbackManager.shared.impact(.medium)
            landingController.setRocketGracePeriod(frames: 180) // 3 seconds of slow scroll grace
            facingDirectionController.clearLockedFacing()
            
            // PERFORMANCE IMPROVEMENT: Spawn new objects after rocket landing too
            spawnManager.spawnObjects(
                sceneSize: size,
                lilyPads: &lilyPads,
                enemies: &enemies,
                tadpoles: &tadpoles,
                bigHoneyPots: &bigHoneyPots,
                lifeVests: &lifeVests,
                worldOffset: worldManager.worldNode.position.y,
                frogPosition: frogController.position,
                superJumpActive: frogController.superJumpActive
            )
            
            // PERFORMANCE IMPROVEMENT: Cleanup after rocket landing
            spawnManager.performCleanup(
                lilyPads: &lilyPads,
                enemies: &enemies,
                frogPosition: frogController.position,
                sceneSize: size,
                worldNode: worldManager.worldNode
            )
        } else {
            // Missed landing
            handleMissedLanding()
        }
    }
    
    // MARK: - Rocket Land Button Handler
    private func handleRocketLandButtonTap() {
        guard frogController.rocketActive else { return }
        
        // Check if there's a lily pad nearby to land on
        if let padUnderFrog = landingController.checkRocketLanding(
            frogPosition: frogController.position,
            lilyPads: lilyPads
        ) {
            // Successful landing - force end the rocket ride
            frogController.forceRocketLanding()
            frogContainer.zPosition = 50
            frogController.landOnPad(padUnderFrog)
            frogController.isGrounded = true
            frogController.inWater = false
            // Rocket land button landings use a medium-high intensity ripple
            effectsManager?.createLandingEffect(at: frogContainer.position, intensity: 0.75, lilyPad: padUnderFrog)
            HapticFeedbackManager.shared.impact(.medium)
            landingController.setRocketGracePeriod(frames: 180)
            facingDirectionController.clearLockedFacing()
            
            // Hide the land button
            uiManager.hideRocketLandButton()
            
            // Show success feedback
            showFloatingText("Nice Landing!", color: .systemGreen)
            
            // PERFORMANCE IMPROVEMENT: Spawn new objects after manual rocket landing
            spawnManager.spawnObjects(
                sceneSize: size,
                lilyPads: &lilyPads,
                enemies: &enemies,
                tadpoles: &tadpoles,
                bigHoneyPots: &bigHoneyPots,
                lifeVests: &lifeVests,
                worldOffset: worldManager.worldNode.position.y,
                frogPosition: frogController.position,
                superJumpActive: frogController.superJumpActive
            )
            
            // PERFORMANCE IMPROVEMENT: Cleanup after manual rocket landing
            spawnManager.performCleanup(
                lilyPads: &lilyPads,
                enemies: &enemies,
                frogPosition: frogController.position,
                sceneSize: size,
                worldNode: worldManager.worldNode
            )
        } else {
            // No lily pad nearby - show feedback but don't land
            showFloatingText("No lily pad nearby!", color: .systemRed)
        }
    }
    
    // MARK: - Landing Helpers
    private func handleUnsafePadLanding() {
        if stateManager.splashTriggered { return }
        stateManager.splashTriggered = true
        
        if frogController.suppressWaterCollisionUntilNextJump {
            print("🌊 Suppressing water collision until next jump")
            healthManager.pendingAbilitySelection = false
            return
        }
        
        // Check water state to determine behavior
        switch stateManager.waterState {
        case .ice:
            handleIceLanding()
        case .water:
            handleUnsafePadWaterSplash()
        }
    }
    
    private func handleUnsafePadWaterSplash() {
        frogController.splash()
        facingDirectionController.clearLockedFacing()
        HapticFeedbackManager.shared.notification(.error)
        effectsManager?.createSplashEffect(at: frogContainer.position)
        
        // Check for life vest charges (same logic as handleWaterSplash)
        if frogController.lifeVestCharges > 0 {
            frogController.lifeVestCharges -= 1
            updateHUD()
            stateManager.cancelPendingGameOver()
            healthManager.pendingAbilitySelection = false
            // CRITICAL FIX: Don't suppress water collision when the frog should be floating
            // This allows the frog to continue floating with proper physics
            frogController.suppressWaterCollisionUntilNextJump = false
            stateManager.splashTriggered = false
            showFloatingText("Life Vest -1", color: .systemYellow)
            
            // Ensure frog is properly floating with correct state
            frogController.inWater = true
            frogController.isGrounded = false
            frogController.isJumping = false
            print("🦎 Life vest rescue: Frog continues floating (can jump from water)")
        } else {
            healthManager.pendingAbilitySelection = false
            self.playScaredSpinDropAndGameOver(reason: .splash)
        }
    }
    
    private func handleMissedLanding() {
        if stateManager.splashTriggered { return }
        stateManager.splashTriggered = true
        
        if frogController.suppressWaterCollisionUntilNextJump {
            print("🌊 Suppressing water collision until next jump")
            healthManager.pendingAbilitySelection = false
            return
        }
        
        print("🔍 handleMissedLanding - waterState: \(stateManager.waterState)")
        
        // Check water state to determine behavior
        switch stateManager.waterState {
        case .ice:
            print("🧊 Routing to ice landing")
            handleIceLanding()
        case .water:
            print("💧 Routing to water splash")
            handleWaterSplash()
        }
    }
    
    private func handleWaterSplash() {
        frogController.splash()
        facingDirectionController.clearLockedFacing()
        HapticFeedbackManager.shared.notification(.error)
        effectsManager?.createSplashEffect(at: frogContainer.position)
        
        if frogController.inWater {
            if frogController.lifeVestCharges > 0 {
                frogController.lifeVestCharges -= 1
                updateHUD()
                stateManager.cancelPendingGameOver()
                healthManager.pendingAbilitySelection = false
                // CRITICAL FIX: Don't suppress water collision when the frog should be floating
                // This allows the frog to continue floating with proper physics
                frogController.suppressWaterCollisionUntilNextJump = false
                stateManager.splashTriggered = false
                showFloatingText("Life Vest -1", color: .systemYellow)
                
                // Ensure frog is properly floating with correct state
                frogController.inWater = true
                frogController.isGrounded = false
                frogController.isJumping = false
                print("🦎 Life vest water rescue: Frog continues floating (can jump from water)")
            } else {
                // No life vest - frog should sink and cause game over
                frogController.inWater = false
                frogController.isGrounded = false
                frogController.isJumping = false
                healthManager.pendingAbilitySelection = false
                self.playScaredSpinDropAndGameOver(reason: .splash)
            }
        } else {
            // Frog not in water state - this means no life vest was available
            healthManager.pendingAbilitySelection = false
            self.playScaredSpinDropAndGameOver(reason: .splash)
        }
    }
    
    private func handleIceLanding() {
        print("🧊 handleIceLanding CALLED")
        
        // Reset splash trigger since ice doesn't cause drowning
        stateManager.splashTriggered = false
        
        // Return to idle pose on land - use the frog controller's methods
        frogController.setToIdlePose()
        
        // Start sliding on ice with velocity based on slingshot pull intensity
        let pullIntensity = self.slingshotController.lastPullIntensity
        let baseSlideSpeed: CGFloat = 15.0 // Base sliding speed
        let slideSpeed = pullIntensity * baseSlideSpeed
        
        // Use the frog's current velocity direction, but scale by pull intensity
        let currentVel = frogController.velocity
        let velMagnitude = sqrt(currentVel.dx * currentVel.dx + currentVel.dy * currentVel.dy)
        
        let slideVelocity: CGVector
        if velMagnitude > 0 {
            // Normalize current velocity and scale by slide speed
            let normalizedVel = CGVector(dx: currentVel.dx / velMagnitude, dy: currentVel.dy / velMagnitude)
            slideVelocity = CGVector(dx: normalizedVel.dx * slideSpeed, dy: normalizedVel.dy * slideSpeed)
        } else {
            // Fallback: slide forward with pull intensity
            slideVelocity = CGVector(dx: 0, dy: slideSpeed)
        }
        
        frogController.startSlidingOnIce(initialVelocity: slideVelocity)
        facingDirectionController.clearLockedFacing()
        
        // Create ice crack effect instead of splash
        effectsManager?.createIceEffect(at: frogController.position)
        
        // Play ice sounds
        SoundController.shared.playIceCrack()
        
        // Light haptic feedback for ice landing
        HapticFeedbackManager.shared.impact(.light)
        
        
        
    }
    
    private func triggerSplashOnce(gameOverDelay: TimeInterval) {
        if stateManager.splashTriggered { return }
        stateManager.splashTriggered = true
        
        frogController.splash()
        facingDirectionController.clearLockedFacing()
        HapticFeedbackManager.shared.notification(.error)
        effectsManager?.createSplashEffect(at: frogContainer.position)
        
        healthManager.pendingAbilitySelection = false
        self.playScaredSpinDropAndGameOver(reason: .splash)
    }
    
    // MARK: - Lily Pad Creation (for special cases only)
    private func makeLilyPad(position: CGPoint, radius: CGFloat) -> LilyPad {
        // For start pad and rescue pad, always create normal pads
        let lilyPad = LilyPad(position: position, radius: radius, type: .normal)
        
        // Apply current weather effects to the newly created lily pad
        let weatherManager = WeatherManager.shared
        WeatherManager.shared.applyWeatherEffectsToLilyPad(lilyPad.node, weather: weatherManager.weather)
        
        return lilyPad
    }
    
    // MARK: - UI Helpers
    private func showFloatingScore(_ text: String, color: UIColor) {
        let label = SKLabelNode(text: text)
        label.fontName = "ArialRoundedMTBold"
        label.fontSize = 22
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(
            x: frogContainer.position.x + CGFloat.random(in: -20...20),
            y: frogContainer.position.y + CGFloat.random(in: 20...40)
        )
        label.zPosition = 999
        addChild(label)
        
        let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.8)
        let scale = SKAction.scale(to: 1.2, duration: 0.8)
        label.run(SKAction.sequence([
            SKAction.group([rise, fade, scale]),
            SKAction.removeFromParent()
        ]))
    }
    
    private func showLevelIndicator() {
        // Create a small level indicator in the top-left corner
        let levelLabel = SKLabelNode(text: "Level \(currentLevel)")
        levelLabel.fontName = "ArialRoundedMT"
        levelLabel.fontSize = 18
        levelLabel.fontColor = .white
        levelLabel.position = CGPoint(x: 50, y: size.height - 50)
        levelLabel.zPosition = 1001
        levelLabel.name = "levelIndicator"
        
        // Remove any existing level indicator
        childNode(withName: "levelIndicator")?.removeFromParent()
        
        addChild(levelLabel)
    }
    
    // MARK: - Finish Line Management
    
    private func spawnFinishLine() {
        hasSpawnedFinishLine = true
        
        print("🏁 Spawning finish line - current frog position: (\(Int(frogController.position.x)), \(Int(frogController.position.y)))")
        
        // Find the highest lily pad that's still accessible to the frog
        var bestPads: [LilyPad] = []
        let searchRange = frogController.position.y + 200 ... frogController.position.y + 600
        
        for pad in lilyPads {
            if searchRange.contains(pad.position.y) {
                bestPads.append(pad)
            }
        }
        
        print("🏁 Found \(bestPads.count) lily pads in range \(Int(searchRange.lowerBound))...\(Int(searchRange.upperBound))")
        
        // Sort by distance from frog and pick a good candidate
        bestPads.sort { pad1, pad2 in
            let dist1 = abs(pad1.position.y - (frogController.position.y + 400))
            let dist2 = abs(pad2.position.y - (frogController.position.y + 400))
            return dist1 < dist2
        }
        
        // Position the finish line
        let finishLineY: CGFloat
        let finishLineX: CGFloat
        
        if let bestPad = bestPads.first {
            // Place finish line above the lily pad
            finishLineY = bestPad.position.y + 80
            finishLineX = bestPad.position.x
            print("🏁 Placing finish line near lily pad at (\(Int(bestPad.position.x)), \(Int(bestPad.position.y)))")
        } else {
            // Default position if no suitable lily pad is found
            finishLineY = frogController.position.y + 400
            finishLineX = frogController.position.x
            print("🏁 No suitable lily pad found, placing finish line at default position")
        }
        
        let finishLinePosition = CGPoint(x: finishLineX, y: finishLineY)
        
        // Create the finish line
        finishLine = FinishLine(
            position: finishLinePosition,
            width: GameConfig.finishLineWidth
        )
        
        // Set up crossing callback (this is redundant with the checkCrossing method but kept for safety)
        finishLine?.onCrossed = { [weak self] in
            print("🏁 onCrossed callback triggered!")
            self?.handleFinishLineCrossed()
        }
        
        // Add to world node so it moves with the world
        if let finishLineNode = finishLine?.node {
            worldManager.worldNode.addChild(finishLineNode)
            print("🏁 Finish line node added to world at position: \(finishLinePosition)")
        } else {
            print("🚨 ERROR: Failed to create finish line node!")
        }
        
        // Show a message to the player
        showFloatingScore("🏁 FINISH LINE!", color: .systemGreen)
        
        // Play a special sound (if available)
        soundController.playCollectSound()
        
        print("🏁 Finish line spawned successfully!")
        print("🏁 Final position: (\(Int(finishLinePosition.x)), \(Int(finishLinePosition.y)))")
        print("🏁 Distance from frog: \(Int(finishLinePosition.y - frogController.position.y)) units")
    }
    
    private func handleFinishLineCrossed() {
        // CRITICAL: Prevent multiple triggers of finish line crossing
        guard let finishLine = finishLine else {
            print("🚨 handleFinishLineCrossed called but no finish line exists!")
            return
        }
        
        print("🏁 Frog crossed the finish line! Level \(currentLevel) complete!")
        print("🏁 Current score: \(score)")
        print("📏 Level \(currentLevel) travel distance: \(Int(levelTravelDistance)) units")
        
        // Calculate and award time bonus
        let timeBonus = calculateTimeBonus()
        if timeBonus > 0 {
            scoreManager.addScore(timeBonus)
            showFloatingScore("+\(timeBonus) TIME BONUS", color: .cyan)
        }
        
        // Stop the level timer
        stopLevelTimer()
        
        // IMMEDIATELY remove the finish line to prevent multiple triggers
        finishLine.node.removeFromParent()
        self.finishLine = nil
        hasSpawnedFinishLine = true // Keep this true until we start the next level
        
        // Complete level in ScoreManager (this handles level progression and bonus scoring)
        scoreManager.completeLevel()
        
        // Show completion message and updated score
        showFloatingScore("LEVEL COMPLETE!", color: .systemGreen)
        showFloatingScore("+\(GameConfig.levelCompletionBonus) BONUS", color: .systemYellow)
        
        // Play completion sound
        soundController.playCollectSound()
        
        // Heavy haptic feedback
        HapticFeedbackManager.shared.impact(.heavy)
        
        // Transition to next level after a short delay
        let delay = SKAction.wait(forDuration: 0.5)
        let nextLevel = SKAction.run { [weak self] in
            print("🏁 About to start next level from Level \(self?.scoreManager.getCurrentLevel() ?? -1)")
            self?.startNextLevel()
        }
        run(SKAction.sequence([delay, nextLevel]), withKey: "levelTransition")
    }
    
    private func startNextLevel() {
        print("🎮 Starting next level...")
        
       
        
        let oldLevel = currentLevel
        
        // Get current level from ScoreManager (it was already incremented in completeLevel())
        currentLevel = scoreManager.getCurrentLevel()
        baseSpawnRateMultiplier = 1.0 + (CGFloat(currentLevel - 1) * 0.1)
        
        print("🎯 Advanced from Level \(oldLevel) to Level \(currentLevel)")
        print("📈 Enemy spawn rate multiplier: \(String(format: "%.1f", baseSpawnRateMultiplier))x (base + \(String(format: "%.0f", (baseSpawnRateMultiplier - 1.0) * 100))%)")
        
        // Print detailed level configuration information
        print("🎮 New Level Configuration:")
        print(LevelEnemyConfigManager.getDebugInfo(for: currentLevel))
        
        // WEATHER INTEGRATION: Update weather for new level
        let weatherManager = WeatherManager.shared
        let newWeather = weatherManager.suggestWeatherForLevel(currentLevel)
        let currentWeather = weatherManager.weather
        
        if newWeather != currentWeather {
            print("🌤️ Level \(currentLevel): Transitioning weather from \(currentWeather.displayName) to \(newWeather.displayName)")
            weatherManager.transitionToWeather(newWeather, duration: 3.0, effectsManager: effectsManager)
        } else {
            print("🌤️ Level \(currentLevel): Weather remains \(currentWeather.displayName)")
        }
        
        // Remove finish line
        finishLine?.node.removeFromParent()
        finishLine = nil
        hasSpawnedFinishLine = false
        
        // Cancel any pending level transitions
        removeAction(forKey: "levelTransition")
        
        // Remove any existing level labels to prevent overlap
        enumerateChildNodes(withName: "levelLabel") { node, _ in
            node.removeFromParent()
        }
        enumerateChildNodes(withName: "difficultyLabel") { node, _ in
            node.removeFromParent()
        }
        
        // Show level advancement message
        let levelLabel = SKLabelNode(text: "LEVEL \(currentLevel)")
        levelLabel.fontName = "ArialRoundedMTBold"
        levelLabel.fontSize = 48
        levelLabel.fontColor = .systemYellow
        levelLabel.position = CGPoint(x: size.width/2, y: size.height/2 + 30 + 100)
        levelLabel.zPosition = 1000
        levelLabel.name = "levelLabel" // Add name for easy removal
        addChild(levelLabel)
        
        // Show difficulty increase subtitle
        let difficultyLabel = SKLabelNode(text: "Enemy spawn rate +10%")
        difficultyLabel.fontName = "ArialRoundedMTBold"
        difficultyLabel.fontSize = 24
        difficultyLabel.fontColor = .systemOrange
        difficultyLabel.position = CGPoint(x: size.width/2, y: size.height/2 + 100)
        difficultyLabel.zPosition = 1000
        difficultyLabel.name = "difficultyLabel" // Add name for easy removal
        addChild(difficultyLabel)
        
        // Animate the level labels
        for label in [levelLabel, difficultyLabel] {
            label.setScale(0)
            let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
            let scaleNormal = SKAction.scale(to: 1.0, duration: 0.2)
            let wait = SKAction.wait(forDuration: 1.5)
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            
            label.run(SKAction.sequence([
                scaleUp, scaleNormal, wait, fadeOut, remove
            ]))
        }
        
        // Update spawn manager with new level's spawn rate multiplier
        spawnManager.updateSpawnRateMultiplier(baseSpawnRateMultiplier)
        
        // WEATHER INTEGRATION: Update spawn manager with weather configuration 
        // This will apply weather-specific enemy spawn rates and rules
        let weatherConfig = weatherManager.getWeatherLevelConfig(level: currentLevel)
        // TODO: Implement weather configuration in SpawnManager
        // spawnManager.updateWeatherConfiguration(weatherConfig)
        print("🌤️ Weather config loaded for Level \(currentLevel): \(weatherManager.weather.displayName)")
        
        // Update the level indicator in the corner
        showLevelIndicator()
        
        // Continue playing without resetting the game completely
        // Just reset necessary game objects while preserving level progression
        continueLevelProgression()
    }
    
    // MARK: - Level Progression Helper
    private func continueLevelProgression() {
        print("🎮 Continuing level progression...")
        print("🧹 Starting comprehensive cleanup for Level \(currentLevel)...")
        
        // STEP 1: Complete visual cleanup - remove all existing nodes from world
        print("🧹 Removing all existing world nodes...")
        for enemy in enemies {
            enemy.node.removeFromParent()
        }
        for tadpole in tadpoles {
            tadpole.node.removeFromParent()
        }
        for bigHoneyPot in bigHoneyPots {
            bigHoneyPot.node.removeFromParent()
        }
        for lifeVest in lifeVests {
            lifeVest.node.removeFromParent()
        }
        for lilyPad in lilyPads {
            lilyPad.node.removeFromParent()
        }
        
        // STEP 2: Clear game object arrays
        print("🧹 Clearing object arrays...")
        enemies.removeAll()
        tadpoles.removeAll()
        bigHoneyPots.removeAll()
        lifeVests.removeAll()
        lilyPads.removeAll()
        
        // STEP 3: Clear spatial grid after clearing lily pads array
        print("🧹 Clearing spatial grid...")
        spawnManager.clearSpatialGrid()
        
        // STEP 4: Reset world manager completely
        print("🧹 Resetting world manager...")
        worldManager.reset()
        
        // STEP 5: Reset all level-specific state
        print("🧹 Resetting level state...")
        hasSpawnedFinishLine = false
        frogPreviousY = 0
        isRocketFinalApproach = false
        
        // CRITICAL FIX: Set new level starting score for finish line calculations
        levelStartingScore = scoreManager.score
        print("🏁 New level starting score set to: \(levelStartingScore)")
        
        // Reset travel distance tracking for new level
        levelStartingFrogY = frogController.position.y
        levelTravelDistance = 0
        print("📏 Travel distance tracking reset for Level \(currentLevel) - starting Y: \(levelStartingFrogY)")
        
        // STEP 6: Reset spawn manager state for new level
        print("🧹 Resetting spawn manager state...")
        spawnManager.reset(for: &lilyPads, tadpoles: &tadpoles, bigHoneyPots: &bigHoneyPots, lifeVests: &lifeVests)
        
        // STEP 7: Reset frog state for new level
        print("🐸 Resetting frog state for new level...")
        frogController.superJumpActive = false
        frogController.rocketActive = false
        frogController.invincible = false
        frogController.inWater = false
        frogController.onIce = false
        frogController.isJumping = false
        frogController.suppressWaterCollisionUntilNextJump = false
        frogController.velocity = .zero
        frogController.slideVelocity = .zero
        
        // Hide all ability indicators
        uiManager.hideSuperJumpIndicator()
        uiManager.hideRocketIndicator()
        uiManager.hideRocketLandButton()
        
        // STEP 8: Create fresh starting pad at current position
        print("🪷 Creating new starting pad...")
        let startWorldPos = CGPoint(x: size.width / 2, y: frogController.position.y)
        let startPad = makeLilyPad(position: startWorldPos, radius: 60)
        startPad.node.position = startPad.position
        startPad.node.zPosition = 10
        worldManager.worldNode.addChild(startPad.node)
        lilyPads.append(startPad)
        
        // STEP 9: Add starting pad to spatial grid
        spawnManager.addToSpatialGrid(startPad)
        print("🪷 Starting pad added to spatial grid at: \(startWorldPos)")
        
        // STEP 10: Land frog on the new starting pad
        frogController.landOnPad(startPad)
        frogController.isGrounded = true
        print("🐸 Frog landed on new starting pad")
        
        // STEP 11: Spawn fresh initial objects for the new level
        print("🎯 Spawning initial objects for Level \(currentLevel)...")
        spawnManager.spawnInitialObjects(
            sceneSize: size,
            lilyPads: &lilyPads,
            enemies: &enemies,
            tadpoles: &tadpoles,
            bigHoneyPots: &bigHoneyPots,
            lifeVests: &lifeVests,
            worldOffset: worldManager.worldNode.position.y
        )
        
        // STEP 12: Resume spawning with new level parameters
        spawnManager.resumeSpawningAfterAbilitySelection()
        print("🎯 Spawning resumed with \(String(format: "%.1f", baseSpawnRateMultiplier))x rate multiplier")
        
        // STEP 13: Start timer for new level
        startLevelTimer()
        
        // STEP 13.5: Advance the finish line for the next level
        spawnManager.advanceToNextLevel(currentScore: score)

        // STEP 14: Show initial upgrade selection for new level
        gameState = .initialUpgradeSelection
        uiManager.showInitialUpgradeSelection(sceneSize: size)
        
        print("✅ Level \(currentLevel) progression complete!")
        print("📊 Final state: \(lilyPads.count) lily pads, \(enemies.count) enemies, \(tadpoles.count) tadpoles")
        
        // Verify cleanup was successful
        let cleanupSuccessful = verifyLevelCleanup()
        if !cleanupSuccessful {
            print("🚨 WARNING: Level cleanup verification failed!")
        }
    }
    
    private func showFloatingText(_ text: String, color: UIColor) {
        let label = SKLabelNode(text: text)
        label.fontName = "ArialRoundedMTBold"
        label.fontSize = 24
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = frogContainer.position
        label.zPosition = 999
        addChild(label)
        
        let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([rise, fade])
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([group, remove]))
    }
    
    // MARK: - Recovery Helpers
    private func findNearbyLilyPad() -> LilyPad? {
        let frogPos = frogController.position
        let maxDistance: CGFloat = 100 // Search within 100 units
        
        return lilyPads.first { pad in
            let dx = frogPos.x - pad.position.x
            let dy = frogPos.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            return distance <= maxDistance
        }
    }
    
    private func attemptStateRecovery() -> Bool {
        // Only attempt recovery if frog is not jumping and not in rocket mode
        guard !frogController.isJumping && !frogController.rocketActive else {
            return false
        }
        
        print("⚠️ Attempting state recovery - checking for nearby lily pad")
        
        if let nearbyPad = findNearbyLilyPad() {
            print("✅ Recovery: Found nearby lily pad, setting grounded state")
            frogController.landOnPad(nearbyPad)
            return true
        } else {
            print("❌ Recovery: No nearby lily pad found")
            return false
        }
    }
    
    private func debugFrogState() {
        print("🐸 DEBUG - Frog State:")
        print("  - isGrounded: \(frogController.isGrounded)")
        print("  - isJumping: \(frogController.isJumping)")
        print("  - inWater: \(frogController.inWater)")
        print("  - onIce: \(frogController.onIce)")
        print("  - slideVelocity: \(frogController.slideVelocity)")
        print("  - rocketActive: \(frogController.rocketActive)")
        print("  - currentLilyPad: \(frogController.currentLilyPad != nil ? "YES" : "NO")")
        print("  - inputLocked: \(stateManager.inputLocked)")
        print("  - waterState: \(stateManager.waterState)")
        print("  - gameState: \(gameState)")
        print("  - pendingAbilitySelection: \(healthManager.pendingAbilitySelection)")
    }
    
    // MARK: - Debug Methods
    
    // Debug function specifically for slingshot input blocking
    func debugSlingshotBlocking() {
        print("🔍 SLINGSHOT DEBUG:")
        print("  - gameState: \(gameState)")
        print("  - inputLocked: \(stateManager.inputLocked)")
        print("  - pendingAbilitySelection: \(healthManager.pendingAbilitySelection)")
        print("  - isGrounded: \(frogController.isGrounded)")
        print("  - isJumping: \(frogController.isJumping)")
        print("  - inWater: \(frogController.inWater)")
        print("  - onIce: \(frogController.onIce)")
        print("  - rocketActive: \(frogController.rocketActive)")
        print("  - currentLilyPad: \(frogController.currentLilyPad != nil ? "YES" : "NO")")
        print("  - canAcceptSlingshotInput: \(canAcceptSlingshotInput())")
        print("  - currentLevel: \(currentLevel)")
        print("  - spawnRateMultiplier: \(String(format: "%.2f", baseSpawnRateMultiplier))x")
        
        // Additional detailed checks
        if gameState != .playing {
            print("  ❌ BLOCKED: Game not in playing state")
        }
        if stateManager.inputLocked {
            print("  ❌ BLOCKED: Input is locked")
        }
        if healthManager.pendingAbilitySelection {
            print("  ❌ BLOCKED: Ability selection pending")
            
            // SAFETY CHECK: If we've been pending for too long and game state is normal, force clear it
            if gameState == .playing && frogController.isGrounded && !frogController.isJumping {
                print("  🚨 SAFETY: Clearing stuck pendingAbilitySelection")
                healthManager.forceClearAbilitySelection(reason: "stuck detection in debug")
            }
        }
        if frogController.rocketActive {
            print("  ❌ BLOCKED: Rocket is active")
        }
        if !frogController.isGrounded && !frogController.inWater && !frogController.onIce {
            print("  ❌ BLOCKED: Frog not grounded/inWater/onIce")
        }
        if canAcceptSlingshotInput() {
            print("  ✅ Slingshot input should be ALLOWED")
        } else {
            print("  ❌ Slingshot input is BLOCKED")
        }
    }
    
    // MARK: - Input Validation Helpers
    private func canAcceptSlingshotInput() -> Bool {
        return frogController.isGrounded || frogController.inWater || frogController.onIce
    }
    
    private func debugWaterStateAndTouch() {
        print("🔍 WATER STATE DEBUG:")
        print("  - waterState: \(stateManager.waterState)")
        print("  - isGrounded: \(frogController.isGrounded)")
        print("  - isJumping: \(frogController.isJumping)")
        print("  - inWater: \(frogController.inWater)")
        print("  - onIce: \(frogController.onIce)")
        print("  - slideVelocity: \(frogController.slideVelocity)")
        print("  - canAcceptInput: \(canAcceptSlingshotInput())")
    }
    
    // Manual recovery function for testing/debugging
    func manualRecovery() {
        debugFrogState()
        debugSlingshotBlocking()  // Also call the new debug function
        stateManager.forceUnlockInput()
        
        // Clear stuck ability selection state
        if healthManager.pendingAbilitySelection {
            print("🚨 Manual recovery: Clearing stuck pendingAbilitySelection")
            healthManager.forceClearAbilitySelection(reason: "manual recovery")
        }
        
        if attemptStateRecovery() {
            print("✅ Manual recovery successful")
        } else {
            print("❌ Manual recovery failed")
        }
    }
    
    // MARK: - Ice Testing Methods
    func testIceMode() {
        print("🧊 TESTING ICE MODE")
        stateManager.createIceLevel()
        debugWaterStateAndTouch()
    }
    
    func forceIceSliding() {
        print("🧊 FORCING ICE SLIDING")
        let testVelocity = CGVector(dx: 5.0, dy: 2.0)
        frogController.startSlidingOnIce(initialVelocity: testVelocity)
        debugWaterStateAndTouch()
    }
    
    // Call this method to test ice sliding directly
    func quickIceTest() {
        print("🧊 QUICK ICE TEST")
        stateManager.setWaterState(.ice)
        print("🧊 Water state set to ice: \(stateManager.waterState)")
        
        // Force the frog into a sliding state
        let slideVelocity = CGVector(dx: 4.0, dy: -2.0)
        frogController.startSlidingOnIce(initialVelocity: slideVelocity)
        
        print("🧊 Frog should now be sliding - onIce: \(frogController.onIce)")
        print("🧊 Slide velocity: \(frogController.slideVelocity)")
    }
    
    // Check and fix stuck ability selection
    func checkAndFixAbilitySelection() {
        print("🔧 ABILITY SELECTION CHECK:")
        print("  - pendingAbilitySelection: \(healthManager.pendingAbilitySelection)")
        print("  - gameState: \(gameState)")
        print("  - isGrounded: \(frogController.isGrounded)")
        print("  - isJumping: \(frogController.isJumping)")
        print("  - spawningPaused: \(spawnManager.isSpawningPaused)")  // Fixed property access
        
        if healthManager.pendingAbilitySelection && gameState == .playing && 
           frogController.isGrounded && !frogController.isJumping {
            print("🚨 FIXING: Clearing stuck pendingAbilitySelection")
            healthManager.forceClearAbilitySelection(reason: "manual check and fix")
        } else {
            print("✅ Ability selection state looks normal")
        }
    }
    
    // Test method to check current ice/spawn state
    func debugIceSpawnState() {
        print("🧊 ICE SPAWN STATE DEBUG:")
        print("  - waterState: \(stateManager.waterState)")
        print("  - frog onIce: \(frogController.onIce)")
        print("  - slide velocity: \(frogController.slideVelocity)")
        print("  - frog position: \(frogController.position)")
        print("  - lily pads ahead count: \(lilyPads.filter { $0.position.y > frogController.position.y }.count)")
    }
    
    // MARK: - Level Testing Methods
    
    /// Verify level cleanup was successful
    func verifyLevelCleanup() -> Bool {
        print("🔍 LEVEL CLEANUP VERIFICATION:")
        
        var allClear = true
        
        // Check arrays are empty
        if !enemies.isEmpty {
            print("  ❌ Enemies array not empty: \(enemies.count) remaining")
            allClear = false
        }
        if !tadpoles.isEmpty {
            print("  ❌ Tadpoles array not empty: \(tadpoles.count) remaining")
            allClear = false
        }
        if !bigHoneyPots.isEmpty {
            print("  ❌ BigHoneyPots array not empty: \(bigHoneyPots.count) remaining")
            allClear = false
        }
        if !lifeVests.isEmpty {
            print("  ❌ LifeVests array not empty: \(lifeVests.count) remaining")
            allClear = false
        }
        if !lilyPads.isEmpty {
            print("  ❌ LilyPads array not empty: \(lilyPads.count) remaining")
            allClear = false
        }
        
        // Check world node has no orphaned children
        let worldChildren = worldManager.worldNode.children
        let enemyNodes = worldChildren.filter { $0.name?.contains("enemy") == true || $0.name?.contains("log") == true || $0.name?.contains("bee") == true }
        let tadpoleNodes = worldChildren.filter { $0.name?.contains("tadpole") == true }
        let padNodes = worldChildren.filter { $0.name?.contains("lilypad") == true || $0.name?.contains("pad") == true }
        
        if !enemyNodes.isEmpty {
            print("  ❌ Orphaned enemy nodes in world: \(enemyNodes.count)")
            allClear = false
        }
        if !tadpoleNodes.isEmpty {
            print("  ❌ Orphaned tadpole nodes in world: \(tadpoleNodes.count)")
            allClear = false
        }
        if padNodes.count > 1 { // Allow 1 for the starting pad
            print("  ❌ Too many lily pad nodes in world: \(padNodes.count) (expected 1 starting pad)")
            allClear = false
        }
        
        // Check finish line state
        if finishLine != nil {
            print("  ❌ Finish line not cleared")
            allClear = false
        }
        if hasSpawnedFinishLine && currentLevel > 1 {
            print("  ❌ hasSpawnedFinishLine not reset for new level")
            allClear = false
        }
        
        if allClear {
            print("  ✅ Level cleanup verification PASSED")
        } else {
            print("  ❌ Level cleanup verification FAILED")
        }
        
        return allClear
    }
    
    /// Force cleanup all game objects (emergency method)
    func forceCompleteCleanup() {
        print("🚨 FORCE CLEANUP: Removing ALL game objects")
        
        // Remove all nodes from world that might be game objects
        let worldChildren = worldManager.worldNode.children
        for child in worldChildren {
            if let name = child.name,
               name.contains("enemy") || name.contains("log") || name.contains("bee") || 
               name.contains("snake") || name.contains("dragonfly") || name.contains("bush") ||
               name.contains("tadpole") || name.contains("lilypad") || name.contains("pad") ||
               name.contains("honey") || name.contains("vest") ||
               name.contains("finish") {
                child.removeFromParent()
                print("  🗑️ Removed orphaned node: \(name)")
            }
        }
        
        // Clear all arrays
        enemies.removeAll()
        tadpoles.removeAll()
        bigHoneyPots.removeAll()
        lifeVests.removeAll()
        lilyPads.removeAll()
        
        // Clear spatial grid
        spawnManager.clearSpatialGrid()
        
        // Reset finish line
        finishLine?.node.removeFromParent()
        finishLine = nil
        hasSpawnedFinishLine = false
        
        print("🚨 Force cleanup complete")
    }
    
    /// Test method to manually advance to next level (for debugging)
    func testAdvanceLevel() {
        print("🧪 TESTING: Manually advancing to next level")
        handleFinishLineCrossed()
    }
    
    /// Test method to manually spawn finish line (for debugging)
    func testSpawnFinishLine() {
        print("🧪 TESTING: Manually spawning finish line")
        spawnFinishLine()
    }
    
    /// Test method to simulate starting at different travel distances (for testing finish line logic)
    func testFinishLineAtTravelDistance(_ startingDistance: CGFloat) {
        print("🧪 TESTING: Setting level travel distance to \(Int(startingDistance))")
        levelTravelDistance = startingDistance
        hasSpawnedFinishLine = false // Reset so finish line can spawn again
        
        let requiredDistance = LevelEnemyConfigManager.getRequiredTravelDistance(for: currentLevel)
        print("🧪 Finish line should appear when travel distance reaches: \(Int(requiredDistance)) units")
        debugFinishLineState()
    }
    
    /// Debug finish line state
    func debugFinishLineState() {
        print("🏁 FINISH LINE DEBUG:")
        print("   - Score: \(score)")
        print("   - Current Level: \(currentLevel)")
        print("   - Level Travel Distance: \(Int(levelTravelDistance)) units")
        let requiredDistance = LevelEnemyConfigManager.getRequiredTravelDistance(for: currentLevel)
        print("   - Required Travel Distance: \(Int(requiredDistance)) units")
        print("   - Distance Progress: \(Int(levelTravelDistance))/\(Int(requiredDistance)) (\(String(format: "%.1f", (levelTravelDistance / requiredDistance) * 100))%)")
        print("   - Distance Remaining: \(Int(max(0, requiredDistance - levelTravelDistance))) units")
        print("   - Has spawned: \(hasSpawnedFinishLine)")
        print("   - Finish line exists: \(finishLine != nil)")
        print("   - Frog position Y: \(Int(frogController.position.y))")
        print("   - Previous frog Y: \(Int(frogPreviousY))")
        
        if let finishLine = finishLine {
            print("   - Finish line Y: \(Int(finishLine.position.y))")
            print("   - Finish line X: \(Int(finishLine.position.x))")
            print("   - Distance to finish: \(Int(finishLine.position.y - frogController.position.y))")
        }
        
        if let levelTransitionAction = action(forKey: "levelTransition") {
            print("   - Level transition in progress: YES")
        } else {
            print("   - Level transition in progress: NO")
        }
    }
    
    /// Debug ghost escapes state
    func debugGhostEscapesState() {
        print("👻 GHOST ESCAPES DEBUG:")
        let totalEscapes = uiManager.getGhostEscapes()
        let usedEscapes = healthManager.ghostEscapesUsed
        let remainingEscapes = uiManager.getGhostEscapesRemaining()
        
        print("   - Super power level: \(uiManager.getSuperPowerLevel(.ghostMagic))")
        print("   - Total escapes available: \(totalEscapes)")
        print("   - Used this level: \(usedEscapes)")
        print("   - Remaining: \(remainingEscapes)")
        print("   - Current level: \(currentLevel)")
        
        // Test the functionality
        if remainingEscapes > 0 {
            print("   ✅ Ghost escape should work")
        } else {
            print("   ❌ No ghost escapes available")
        }
    }
    
    /// Test method to get current level info with new configuration system
    func debugLevelInfo() {
        print("🎯 LEVEL INFO:")
        print("  - Current Level: \(currentLevel)")
        print("  - Base Spawn Rate Multiplier: \(String(format: "%.2f", baseSpawnRateMultiplier))x")
        print("  - Increase from Level 1: +\(String(format: "%.0f", (baseSpawnRateMultiplier - 1.0) * 100))%")
        print("  - SpawnManager Multiplier: \(String(format: "%.2f", spawnManager.levelSpawnRateMultiplier))x")
        print("")
        print("🎮 Level Configuration Details:")
        print(LevelEnemyConfigManager.getDebugInfo(for: currentLevel))
    }
    
    // MARK: - Travel Distance Debug Methods
    
    /// Get the travel distance for the current level
    func getCurrentLevelTravelDistance() -> CGFloat {
        return levelTravelDistance
    }
    
    /// Get the total travel distance for the current session
    func getTotalSessionTravelDistance() -> CGFloat {
        return totalSessionTravelDistance
    }
    
    /// Get travel distance for a specific level
    func getTravelDistanceForLevel(_ level: Int) -> CGFloat {
        return levelTravelDistances[level] ?? 0
    }
    
    /// Get all level travel distances
    func getAllLevelTravelDistances() -> [Int: CGFloat] {
        return levelTravelDistances
    }
    
    /// Debug method to show travel distance information
    func debugTravelDistances() {
        print("📏 TRAVEL DISTANCE DEBUG:")
        print("  - Current Level: \(currentLevel)")
        print("  - Current Level Distance: \(Int(levelTravelDistance)) units")
        print("  - Session Total Distance: \(Int(totalSessionTravelDistance)) units")
        print("  - Starting Frog Y: \(Int(levelStartingFrogY))")
        print("  - Current Frog Y: \(Int(frogController.position.y))")
        print("  - Frog Y Change: \(Int(frogController.position.y - levelStartingFrogY))")
        
        // Show required distance for current level
        let requiredDistance = LevelEnemyConfigManager.getRequiredTravelDistance(for: currentLevel)
        print("  - Required Distance (Level \(currentLevel)): \(Int(requiredDistance)) units")
        print("  - Progress: \(String(format: "%.1f", (levelTravelDistance / requiredDistance) * 100))%")
        
        print("")
        print("  📊 All Level Distances:")
        let sortedLevels = levelTravelDistances.keys.sorted()
        for level in sortedLevels {
            let distance = levelTravelDistances[level] ?? 0
            let required = LevelEnemyConfigManager.getRequiredTravelDistance(for: level)
            print("    Level \(level): \(Int(distance))/\(Int(required)) units (\(String(format: "%.1f", (distance / required) * 100))%)")
        }
        
        if levelTravelDistances.isEmpty {
            print("    (No completed levels)")
        }
        
        // Calculate average distance per level (excluding current incomplete level)
        let completedDistances = levelTravelDistances.filter { $0.key < currentLevel }
        if !completedDistances.isEmpty {
            let totalCompleted = completedDistances.values.reduce(0, +)
            let averageDistance = totalCompleted / CGFloat(completedDistances.count)
            print("  📈 Average distance per completed level: \(Int(averageDistance)) units")
        }
        
        // Show upcoming level requirements
        print("")
        print("  🔮 Upcoming Level Requirements:")
        for level in (currentLevel + 1)...(currentLevel + 3) {
            let required = LevelEnemyConfigManager.getRequiredTravelDistance(for: level)
            print("    Level \(level): \(Int(required)) units required")
        }
    }
    
    /// Reset travel distance tracking (for testing)
    func debugResetTravelDistances() {
        print("📏 RESETTING all travel distance data")
        totalSessionTravelDistance = 0
        levelTravelDistance = 0
        levelTravelDistances.removeAll()
        levelStartingFrogY = frogController.position.y
        print("📏 Travel distances reset - new starting Y: \(levelStartingFrogY)")
    }
    
    /// Test method to preview configurations for upcoming levels
    func debugPreviewLevels(range: ClosedRange<Int>) {
        print("🔮 LEVEL PREVIEW:")
        LevelEnemyConfigManager.printDebugInfo(for: range)
    }
    
    /// Test method to manually set the current level (for testing configurations)
    func debugSetLevel(_ level: Int) {
        print("🧪 TESTING: Manually setting level to \(level)")
        currentLevel = level
        
        // Update spawn manager
        baseSpawnRateMultiplier = 1.0 + (CGFloat(level - 1) * 0.1)
        spawnManager.updateSpawnRateMultiplier(baseSpawnRateMultiplier)
        
        // Show level indicator
        showLevelIndicator()
        
        // Print new configuration
        debugLevelInfo()
    }
    
    /// Force test the level configuration system in real-time
    func testLevelConfigSystem() {
        print("🧪 TESTING LEVEL CONFIG SYSTEM:")
        
        // Test level calculation
        let testScore = score
        let calculatedLevel = max(1, (testScore / 25000) + 1)
        print("  - Current score: \(testScore)")
        print("  - Calculated level: \(calculatedLevel)")
        print("  - GameScene currentLevel: \(currentLevel)")
        
        // Test configuration retrieval
        let config = LevelEnemyConfigManager.getConfig(for: calculatedLevel)
        print("  - Global spawn multiplier: \(config.globalSpawnRateMultiplier)")
        print("  - Max enemies on screen: \(config.maxEnemiesPerScreen)")
        print("  - Enemy types configured: \(config.enemyConfigs.count)")
        
        for enemyConfig in config.enemyConfigs {
            let finalRate = enemyConfig.spawnRate * config.globalSpawnRateMultiplier
            print("    - \(enemyConfig.enemyType): rate=\(String(format: "%.3f", enemyConfig.spawnRate)) -> final=\(String(format: "%.3f", finalRate)), max=\(enemyConfig.maxCount), water=\(enemyConfig.canSpawnInWater), pads=\(enemyConfig.canSpawnOnPads)")
        }
        
        // Force spawn manager to use this level
        if let gameScene = spawnManager.scene as? GameScene {
            print("  - SpawnManager has access to GameScene: YES")
            print("  - SpawnManager can read score: \(gameScene.score)")
        } else {
            print("  - SpawnManager has access to GameScene: NO")
        }
        
        // Test specific Level 1 expectations
        if calculatedLevel == 1 {
            let beeConfig = config.enemyConfigs.first { $0.enemyType == .bee }
            if let bee = beeConfig {
                print("✅ Level 1 BEE config found: rate=\(bee.spawnRate), max=\(bee.maxCount)")
            } else {
                print("❌ Level 1 BEE config NOT FOUND!")
            }
            
            let otherTypes = config.enemyConfigs.filter { $0.enemyType != .bee }
            if otherTypes.isEmpty {
                print("✅ Level 1 correctly has ONLY bees")
            } else {
                print("❌ Level 1 has other enemy types: \(otherTypes.map { $0.enemyType })")
            }
        }
    }
    
    /// Test method to show all enemy spawn rates for current level
    func debugCurrentLevelEnemyRates() {
        print("🐛 ENEMY SPAWN RATES FOR LEVEL \(currentLevel):")
        let allowedTypes = LevelEnemyConfigManager.getAllowedEnemyTypes(for: currentLevel)
        
        for enemyType in allowedTypes {
            let spawnRate = LevelEnemyConfigManager.getSpawnRate(for: enemyType, at: currentLevel)
            let maxCount = LevelEnemyConfigManager.getMaxCount(for: enemyType, at: currentLevel)
            let canSpawnOnPads = LevelEnemyConfigManager.canSpawnOnPads(enemyType: enemyType, at: currentLevel)
            let canSpawnInWater = LevelEnemyConfigManager.canSpawnInWater(enemyType: enemyType, at: currentLevel)
            
            print("  \(enemyType):")
            print("    - Spawn Rate: \(String(format: "%.3f", spawnRate))")
            print("    - Max Count: \(maxCount)")
            print("    - On Pads: \(canSpawnOnPads)")
            print("    - In Water: \(canSpawnInWater)")
        }
    }
    
    // TEMPORARY: Override input validation to allow ice sliding
    private func shouldAllowSlingshotInput() -> Bool {
        let result = frogController.isGrounded || frogController.inWater || frogController.onIce
        if !result {
            print("🚫 Input blocked - isGrounded: \(frogController.isGrounded), inWater: \(frogController.inWater), onIce: \(frogController.onIce)")
        }
        return result
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Debug water state when touches begin
        if gameState == .playing {
            debugWaterStateAndTouch()
        }
        
        let nodesAtPoint = nodes(at: location)
        
        // DEBUG: Print touch information when in menu state with tutorial potentially open
        if gameState == .menu {
            print("🔍 MENU TOUCH DEBUG:")
            print("   - Touch location: \(location)")
            print("   - Game state: \(gameState)")
            print("   - Nodes at point: \(nodesAtPoint.count)")
            for (index, node) in nodesAtPoint.enumerated() {
                print("     \(index): \(type(of: node)) - name: '\(node.name ?? "nil")' - zPos: \(node.zPosition)")
            }
            
            // Check if tutorial modal exists
            if let tutorialModal = uiManager.tutorialModal {
                print("   - Tutorial modal exists: ✅")
                print("   - Tutorial modal position: \(tutorialModal.position)")
                print("   - Tutorial modal zPosition: \(tutorialModal.zPosition)")
                print("   - Tutorial modal children: \(tutorialModal.children.count)")
                for child in tutorialModal.children {
                    if let name = child.name {
                        print("     - Child: \(name) at \(child.position)")
                    }
                }
            } else {
                print("   - Tutorial modal exists: ❌")
            }
        }
        
        // DEBUG: Print touch information for troubleshooting
        if gameState == .initialUpgradeSelection {
            print("🔍 INITIAL UPGRADE TOUCH DEBUG:")
            print("   - Touch location: \(location)")
            print("   - Game state: \(gameState)")
            print("   - Nodes at point: \(nodesAtPoint.count)")
            for (index, node) in nodesAtPoint.enumerated() {
                print("     \(index): \(type(of: node)) - name: '\(node.name ?? "nil")' - frame: \(node.frame)")
            }
        }
        
        // DEBUG: Print all nodes at touch point when ability menu is showing
        if gameState == .abilitySelection {
            print("🔍 TOUCH DEBUG: Touch at \(location) in gameState: \(gameState)")
            print("🔍 TOUCH DEBUG: Found \(nodesAtPoint.count) nodes at touch point:")
            for (index, node) in nodesAtPoint.enumerated() {
                print("  \(index): \(type(of: node)) - name: '\(node.name ?? "nil")' - zPos: \(node.zPosition) - frame: \(node.frame)")
            }
            
            // Also check if ability layer exists and is accessible
            if let abilityLayer = uiManager.abilityLayer {
                print("🔍 ABILITY LAYER DEBUG:")
                print("  - Ability layer exists: ✅")
                print("  - Position: \(abilityLayer.position)")
                print("  - zPosition: \(abilityLayer.zPosition)")
                print("  - Alpha: \(abilityLayer.alpha)")
                print("  - isUserInteractionEnabled: \(abilityLayer.isUserInteractionEnabled)")
                print("  - Children count: \(abilityLayer.children.count)")
                
                // List ability buttons
                for child in abilityLayer.children {
                    if let name = child.name, name.hasPrefix("ability_") {
                        print("    - Button: \(name) at \(child.position), frame: \(child.frame)")
                    }
                }
            } else {
                print("🔍 ABILITY LAYER DEBUG: ❌ No ability layer found!")
            }
        }
        
        // Use UIManager's enhanced touch handling for menu and paused states
        if gameState == .menu || gameState == .paused {
            print("🔍 Delegating touch to UIManager for state: \(gameState)")
            uiManager.handleTouch(touch, phase: .began, in: self)
            
            // IMPORTANT: Don't return early - we need to check for tutorial modal buttons
            // The tutorial modal might be open even when game state is .menu
        } else if gameState == .abilitySelection || gameState == .initialUpgradeSelection {
            // IMPORTANT: Notify UIManager but allow GameScene to continue handling ability/upgrade taps
            print("🔍 Notifying UIManager for ability/upgrade selection state: \(gameState)")
            uiManager.handleTouch(touch, phase: .began, in: self)
        }
        
        // Press feedback for UI buttons (nodes named with known button names or ability_ prefix)
        if let tapped = nodesAtPoint.first(where: { node in
            guard let name = node.name else { return false }
            return name == "playGameButton" ||
                   name == "continueGameButton" ||
                   name == "newGameButton" ||
                   name == "levelSelectorButton" ||
                   name == "leaderboardButton" ||
                   name == "tutorialButton" ||
                   name == "closeTutorialButton" ||
                   name == "superPowersButton" ||
                   name == "pauseButton" ||
                   name == "continueButton" ||
                   name == "resumeButton" ||
                   name == "quitButton" ||
                   name == "quitToMenuButton" ||
                   name == "tryAgainButton" ||
                   name == "restartButton" ||
                   name == "backToMenuButton" ||
                   name == "rocketLandButton" ||
                   name.hasPrefix("ability_") ||
                   name.hasPrefix("levelButton_") ||
                   name.hasPrefix("initialUpgrade_")
        }) {
            // Animate press on the button's root node (use parent if label/sprite was hit)
            let buttonRoot = tapped.name == "tapTarget" ? tapped.parent ?? tapped : tapped
            currentlyPressedButton = buttonRoot
            uiManager.handleButtonPress(node: buttonRoot)
        }
        
        // Check for UI button taps FIRST
        for node in nodesAtPoint {
            if let nodeName = node.name {
                print("🔍 Found node with name: \(nodeName)")
                
                // Handle New Game button DIRECTLY (bypass level selection system)
                if nodeName == "newGameButton" {
                    soundController.playSoundEffect(.buttonTap)
                    startNewGame()
                    return
                }
                
                // Handle Continue Game button DIRECTLY
                if nodeName == "continueGameButton" {
                    soundController.playSoundEffect(.buttonTap)
                    startGameFromLastLevel()
                    return
                }
                
                // Route other menu buttons through UIManager for consistent handling
                if ["playGameButton", "levelSelectorButton", 
                    "leaderboardButton", "tutorialButton", "closeTutorialButton", "superPowersButton",
                    "closeLevelSelectionButton"].contains(nodeName) {
                    print("🔍 Routing \(nodeName) to UIManager")
                    soundController.playSoundEffect(.buttonTap)
                    uiManager.handleNamedButtonTap(nodeName)
                    return
                }
                
                // Handle level selection buttons (these go through level selection system)
                if nodeName.hasPrefix("levelButton_") {
                    soundController.playSoundEffect(.buttonTap)
                    uiManager.handleNamedButtonTap(nodeName)
                    return
                }
                
                // Legacy handler for playGameButton (fallback)
                if nodeName == "playGameButton" {
                    soundController.playSoundEffect(.buttonTap)
                    startNewGame()
                    return
                }
                if nodeName == "profileButton" || nodeName == "settingsButton" || nodeName == "audioButton" {
                    soundController.playSoundEffect(.buttonTap)
                    // Placeholder for future navigation
                    print("Tapped \(nodeName), navigating...")
                    return
                }
                if nodeName == "exitButton" || nodeName == "backToMenuButton" {
                    soundController.playSoundEffect(.buttonTap)
                    showMainMenu()
                    return
                }
                if nodeName == "tryAgainButton" || nodeName == "restartButton" {
                    soundController.playSoundEffect(.buttonTap)
                    startNewGame()
                    return
                }
                
                // Ability selection buttons - HANDLE REGARDLESS OF GAME STATE
                if nodeName.hasPrefix("ability_") {
                    soundController.playSoundEffect(.buttonTap)
                    print("🎯 Ability button tapped: \(nodeName)")
                    
                    // Extract the ability type from the button name (remove "ability_" prefix)
                    let abilityTypeString = String(nodeName.dropFirst("ability_".count))
                    print("🎯 Extracted ability type: \(abilityTypeString)")
                    
                    selectAbility(abilityTypeString)
                    return
                }
                
                // Initial upgrade selection buttons
                if nodeName.hasPrefix("initialUpgrade_") {
                    print("🎯 Initial upgrade button detected: \(nodeName)")
                    soundController.playSoundEffect(.buttonTap)
                    handleInitialUpgradeSelection(nodeName)
                    return
                }
                // Pause button handler
                           if nodeName == "pauseButton" {
                               soundController.playSoundEffect(.buttonTap)
                               gameState = .paused
                               uiManager.showPauseMenu(sceneSize: size)
                               return
                           }
                
                // Rocket land button handler
                if nodeName == "rocketLandButton" {
                    soundController.playSoundEffect(.buttonTap)
                    handleRocketLandButtonTap()
                    return
                }
            }
        }
        
        // BACKUP: Manually check ability layer if we're in ability selection and no nodes were found
        if gameState == .abilitySelection && nodesAtPoint.isEmpty {
            print("🔍 BACKUP CHECK: No nodes found at touch point, manually checking ability layer")
            if let abilityLayer = uiManager.abilityLayer {
                // Convert touch location to ability layer's coordinate space
                let layerLocation = convert(location, to: abilityLayer)
                print("🔍 BACKUP CHECK: Touch at \(location) converts to \(layerLocation) in ability layer space")
                
                // Check each ability button manually
                for child in abilityLayer.children {
                    if let nodeName = child.name, nodeName.hasPrefix("ability_") {
                        if child.contains(layerLocation) {
                            print("🔍 BACKUP CHECK: Found ability button \(nodeName) contains touch point")
                            soundController.playSoundEffect(.buttonTap)
                            let abilityTypeString = String(nodeName.dropFirst("ability_".count))
                            selectAbility(abilityTypeString)
                            return
                        }
                    }
                }
                print("🔍 BACKUP CHECK: No ability buttons contain the touch point")
            }
        }
        
        // Only check gameplay touches if we're in playing state
        guard gameState == .playing else {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: gameState=\(gameState)")
            return
        }
        
        // Rocket steering
        if frogController.rocketActive {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch routed to rocket steering")
            let screenCenter = size.width / 2
            if location.x > screenCenter + 40 {
                touchInputController.applyTapNudge(isRightSide: true, sceneWidth: size.width)
            } else if location.x < screenCenter - 40 {
                touchInputController.applyTapNudge(isRightSide: false, sceneWidth: size.width)
            }
            _ = touchInputController.handleTouchBegan(touch, in: self.view, sceneSize: size, rocketActive: frogController.rocketActive)
            return
        }
        
        if stateManager.inputLocked {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: inputLocked")
            return
        }
        
        if healthManager.pendingAbilitySelection {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: ability selection pending")
            return
        }
        
        if !(frogController.isGrounded || frogController.inWater) {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: not grounded/inWater (isGrounded=\(frogController.isGrounded), isJumping=\(frogController.isJumping))")
            return
        
       
        }
        
        // Slingshot handling - only if grounded or in water
        print("🎯 Slingshot touch began at: \(location)")
        let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
        slingshotController.handleTouchBegan(at: location, frogScreenPosition: frogScreenPoint)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // If finger moves significantly, cancel press state
        if let pressed = currentlyPressedButton {
            let pressedFrame = pressed.calculateAccumulatedFrame()
            if !pressedFrame.insetBy(dx: -20, dy: -20).contains(location) {
                uiManager.handleButtonRelease(node: pressed)
                currentlyPressedButton = nil
            }
        }
        
        guard gameState == .playing else {
            return
        }
        
        if stateManager.inputLocked {
            return
        }
        
        if healthManager.pendingAbilitySelection {
            return
        }
        
        if frogController.rocketActive {
            return
        }
        
        if !(frogController.isGrounded || frogController.inWater) {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: not grounded/inWater (isGrounded=\(frogController.isGrounded), isJumping=\(frogController.isJumping))")
            return
        }
        
        let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
        slingshotController.handleTouchMoved(to: location)
        // ADD THIS: Draw the slingshot visuals
              slingshotController.drawSlingshot(
                  frogScreenPosition: frogScreenPoint,
                  frogWorldPosition: frogController.position,
                  superJumpActive: frogController.superJumpActive,
                  lilyPads: lilyPads,
                  worldNode: worldManager.worldNode,
                  scene: self,
                  worldOffset: worldManager.worldNode.position.y,
                  jumpRangeMultiplier: uiManager.getJumpRangeMultiplier()
              )
        updateFacingFromAiming(location: location)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Release visual for any pressed button
        if let pressed = currentlyPressedButton {
            uiManager.handleButtonRelease(node: pressed)
            currentlyPressedButton = nil
        }
        
        // Use UIManager's enhanced touch handling for menu and paused states
        if gameState == .menu || gameState == .paused {
            uiManager.handleTouch(touch, phase: .ended, in: self)
            // IMPORTANT: Don't return early - we need to continue processing for tutorial modal buttons
        } else if gameState == .abilitySelection || gameState == .initialUpgradeSelection {
            // IMPORTANT: Notify UIManager but allow GameScene to continue handling ability/upgrade taps
            uiManager.handleTouch(touch, phase: .ended, in: self)
        }
        
        // TUTORIAL MODAL BUTTON FIX: Check for tutorial close button in menu state
        if gameState == .menu || gameState == .paused {
            let nodesAtPoint = nodes(at: location)
            for node in nodesAtPoint {
                if let nodeName = node.name {
                    print("🔍 TouchesEnded - Found node: \(nodeName)")
                    
                    if nodeName == "closeTutorialButton" {
                        print("🔍 TouchesEnded - Handling closeTutorialButton")
                        soundController.playSoundEffect(.buttonTap)
                        uiManager.handleNamedButtonTap(nodeName)
                        return
                    }
                }
            }
        }
        
        if gameState == .playing && frogController.rocketActive {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch routed to rocket steering")
            _ = touchInputController.handleTouchEnded(touch, in: self.view, sceneSize: size, rocketActive: frogController.rocketActive, hudBarHeight: hudBarHeight)
            return
        }
        
        guard gameState == .playing else {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: gameState=\(gameState)")
            return
        }
        
        if stateManager.inputLocked {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: inputLocked")
            return
        }
        
        if healthManager.pendingAbilitySelection {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: ability selection pending")
            return
        }
        
        if !(frogController.isGrounded || frogController.inWater) {
            print("ÃƒÂ¢Ã¢â‚¬ÂºÃ¢â‚¬ÂÃƒÂ¯Ã‚Â¸Ã‚Â Touch ignored: not grounded/inWater (isGrounded=\(frogController.isGrounded), isJumping=\(frogController.isJumping))")
            return
        }
        
        if frogController.isGrounded || frogController.inWater {
            let frogScreenPoint = convert(frogController.position, from: worldManager.worldNode)
            
            if let targetWorldPos = slingshotController.handleTouchEnded(
                at: location,
                frogScreenPosition: frogScreenPoint,
                frogWorldPosition: frogController.position,
                worldOffset: worldManager.worldNode.position.y,
                superJumpActive: frogController.superJumpActive,
                jumpRangeMultiplier: uiManager.getJumpRangeMultiplier()
            ) {
                print("ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â¸ Jumping to: \(targetWorldPos)")
                frogController.startJump(to: targetWorldPos)
                facingDirectionController?.lockCurrentFacing()
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let pressed = currentlyPressedButton {
            uiManager.handleButtonRelease(node: pressed)
            currentlyPressedButton = nil
        }
        
        // Use UIManager's enhanced touch handling for menu and paused states
        if let touch = touches.first {
            if gameState == .menu || gameState == .paused {
                uiManager.handleTouch(touch, phase: .cancelled, in: self)
                return
            } else if gameState == .abilitySelection || gameState == .initialUpgradeSelection {
                // IMPORTANT: Notify UIManager but allow GameScene to continue handling ability/upgrade taps
                uiManager.handleTouch(touch, phase: .cancelled, in: self)
            }
        }
        
        // IMPORTANT: Cancel any active slingshot aiming when touches are cancelled
        if slingshotController.slingshotActive {
            print("🎯 Touch cancelled - canceling slingshot aiming")
            slingshotController.cancelCurrentAiming()
        }
    }
    
    private func updateFacingFromAiming(location: CGPoint) {
        if canAcceptSlingshotInput() {
            let start = convert(frogController.position, from: worldManager.worldNode)
            let pull = CGPoint(x: location.x - start.x, y: location.y - start.y)
            if pull.x != 0 || pull.y != 0 {
                facingDirectionController.setFacingFromPull(pullDirection: pull)
            }
        }
    }
    
    // MARK: - Game Over Animation Helper
    private func playScaredSpinDropAndGameOver(reason: GameOverReason) {
        // Prevent duplicate triggers
        guard gameState == .playing else {
            gameOver(reason)
            return
        }

        stateManager.lockInput(for: 0.5)  // Reduced from 2.0 to 0.5 seconds to prevent extended input loss
        frogController.showScared(duration: 2.0)

        frogController.frog.removeAllActions()
        frogController.frogShadow.removeAllActions()
        frogContainer.removeAllActions()

        frogContainer.zPosition = max(frogContainer.zPosition, 500)

        let spin = SKAction.rotate(byAngle: .pi * 2.0, duration: 0.5)
        spin.timingMode = .easeInEaseOut
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.2)
        scaleUp.timingMode = .easeOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        scaleDown.timingMode = .easeIn
        let wobble = SKAction.sequence([scaleUp, scaleDown])

        let dropTarget = CGPoint(x: frogContainer.position.x, y: -size.height * 0.4)
        let drop = SKAction.move(to: dropTarget, duration: 0.6)
        drop.timingMode = .easeIn
        let fade = SKAction.fadeOut(withDuration: 0.5)
        let groupSpinWobble = SKAction.group([spin, wobble])

        HapticFeedbackManager.shared.notification(.error)

        let sequence = SKAction.sequence([
            groupSpinWobble,
            SKAction.group([drop, fade])
        ])

        frogContainer.run(sequence) { [weak self] in
            guard let self = self else { return }
            self.frogController.frog.alpha = 1.0
            self.frogController.frogShadow.alpha = 0.0
            self.gameOver(reason)
        }
    }
    
    // MARK: - Level Continuation Debug Methods
    
    /// Debug method to show current level continuation state
    func debugLevelContinuation() {
        print("🎮 LEVEL CONTINUATION DEBUG:")
        scoreManager.debugShowState()
        print("  - GameScene currentLevel: \(currentLevel)")
        print("  - GameScene baseSpawnRateMultiplier: \(String(format: "%.2f", baseSpawnRateMultiplier))x")
    }
    
    /// Test method to simulate completing levels for testing continuation
    func debugSimulateProgress() {
        print("🧪 TESTING: Simulating progress through levels")
        scoreManager.debugSimulateProgressToLevel(5)
        
        print("🧪 After simulation - checking main menu state:")
        debugLevelContinuation()
        
        // Force refresh the main menu to see the changes
        showMainMenu()
    }
    
    /// Test method to reset all progress for testing
    func debugResetAllProgress() {
        print("🧪 TESTING: Resetting ALL progress")
        scoreManager.resetAllProgress()
        debugLevelContinuation()
        
        // Force refresh the main menu to see the changes
        showMainMenu()
    }
    
    // MARK: - Weather Debug Methods
    
    /// Debug current weather system state
    func debugWeatherSystem() {
        let weatherManager = WeatherManager.shared
        print("🌤️ WEATHER SYSTEM DEBUG:")
        print("  - Current Level: \(currentLevel)")
        print("  - Current Weather: \(weatherManager.weather.displayName)")
        print("  - Suggested Weather for Level: \(weatherManager.suggestWeatherForLevel(currentLevel).displayName)")
        print("  - Slippery Pads: \(weatherManager.shouldPadsBeSlippery())")
        
        if weatherManager.shouldPadsBeSlippery() {
            print("    - Slip Factor: \(weatherManager.getSlipFactor())")
        }
        
        print("  - Wind Active: \(weatherManager.isWindActive())")
        print("  - Ice Conversion: \(weatherManager.shouldConvertWaterToIce())")
        print("  - Water State: \(stateManager.waterState)")
        
        // Show weather-specific level configuration
        let weatherConfig = weatherManager.getWeatherLevelConfig(level: currentLevel)
        print("  - Weather Level Config:")
        print("    - Global Spawn Multiplier: \(weatherConfig.globalSpawnRateMultiplier)")
        print("    - Max Enemies: \(weatherConfig.maxEnemiesPerScreen)")
        print("    - Enemy Configs: \(weatherConfig.enemyConfigs.count)")
        
        weatherManager.printDebugInfo()
    }
    
    /// Test method to cycle through different weather types
    func testWeatherCycling() {
        let weatherManager = WeatherManager.shared
        print("🌤️ TESTING: Cycling to next weather type")
        weatherManager.cycleToNextWeather()
        debugWeatherSystem()
    }
    
    /// Test method to set specific weather
    func testSetWeather(_ weather: WeatherType) {
        let weatherManager = WeatherManager.shared
        print("🌤️ TESTING: Setting weather to \(weather.displayName)")
        weatherManager.setWeather(weather, effectsManager: effectsManager)
        debugWeatherSystem()
        
        // Apply weather effects to current scene
        updateExistingLilyPadsForWeather(weather)
        applyWeatherGameplayEffects(weather)
    }
    
    /// Test method to trigger weather transition
    func testWeatherTransition(to weather: WeatherType) {
        let weatherManager = WeatherManager.shared
        print("🌤️ TESTING: Transitioning weather to \(weather.displayName)")
        weatherManager.transitionToWeather(weather, duration: 1.0, effectsManager: effectsManager)
    }
    
    /// Test method to show weather suggestions for different levels
    func testWeatherSuggestions(levels: Range<Int>) {
        let weatherManager = WeatherManager.shared
        print("🌤️ WEATHER SUGGESTIONS:")
        
        for level in levels {
            let suggestedWeather = weatherManager.suggestWeatherForLevel(level)
            let weatherConfig = weatherManager.getWeatherLevelConfig(level: level, weather: suggestedWeather)
            print("  Level \(level): \(suggestedWeather.displayName) (multiplier: \(weatherConfig.globalSpawnRateMultiplier))")
        }
    }
    
    /// Test method to simulate weather effects
    func testWeatherEffects() {
        let weatherManager = WeatherManager.shared
        let currentWeather = weatherManager.weather
        
        print("🌤️ TESTING: Weather effects for \(currentWeather.displayName)")
        
        // Test slippery pad effect
        if weatherManager.shouldPadsBeSlippery() {
            print("  - Testing slippery pad effect...")
            let slipFactor = weatherManager.getSlipFactor()
            applySlipEffectToFrog(factor: slipFactor)
        }
        
        // Test wind effect
        if weatherManager.isWindActive() {
            print("  - Testing wind effect...")
            let windForce = CGVector(dx: CGFloat.random(in: -50...50), dy: CGFloat.random(in: -30...30))
            NotificationCenter.default.post(name: NSNotification.Name("WindForceApplied"), object: windForce)
        }
        
        // Test lightning effect
        if currentWeather.gameplayEffects.contains(where: { effect in
            if case .lightning = effect { return true }
            return false
        }) {
            print("  - Testing lightning effect...")
            NotificationCenter.default.post(name: NSNotification.Name("LightningEffect"), object: nil)
        }
    }
    
    /// Debug method to show weather progression through levels
    func debugWeatherProgression() {
        print("🌤️ WEATHER PROGRESSION THROUGH LEVELS:")
        let weatherManager = WeatherManager.shared
        
        for level in 1...20 {
            let weather = weatherManager.suggestWeatherForLevel(level)
            let config = weatherManager.getWeatherLevelConfig(level: level, weather: weather)
            let effects = weather.gameplayEffects
            
            print("Level \(level): \(weather.displayName)")
            print("  - Spawn Multiplier: \(String(format: "%.2f", config.globalSpawnRateMultiplier))x")
            print("  - Effects: \(effects.count) active")
            
            for effect in effects {
                switch effect {
                case .slipperyPads(let factor):
                    print("    • Slippery Pads (factor: \(factor))")
                case .windForce:
                    print("    • Wind Force")
                case .iceConversion:
                    print("    • Ice Conversion")
                case .rainParticles:
                    print("    • Rain Particles")
                case .lightning:
                    print("    • Lightning")
                case .reducedVisibility(let amount):
                    print("    • Reduced Visibility (\(Int(amount * 100))%)")
                }
            }
        }
    }
}

