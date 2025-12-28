//
//  DailyChallengeIntegration.swift
//  Integration guide for GameScene
//
//  This file contains code snippets showing how to integrate daily challenges
//  into your GameScene. These are examples - adapt them to fit your actual
//  GameScene structure.
//

import SpriteKit

/*

// MARK: - Example 1: Detecting Daily Challenge Mode

In your GameScene, check if you're in daily challenge mode:

```swift
var gameMode: GameMode = .endless
var currentChallenge: DailyChallenge?

override func didMove(to view: SKView) {
    super.didMove(to: view)
    
    // Check if this is a daily challenge
    if case .dailyChallenge(let challenge) = gameMode {
        currentChallenge = challenge
        setupDailyChallenge(challenge)
    }
}

private func setupDailyChallenge(_ challenge: DailyChallenge) {
    print("🎯 Daily Challenge: \(challenge.name)")
    print("   Climate: \(challenge.climate)")
    print("   Enemies: \(challenge.focusEnemyTypes)")
    print("   Pads: \(challenge.focusPadTypes)")
    
    // Lock the weather to the challenge climate
    currentWeather = challenge.climate
    
    // Display challenge info to player
    showChallengeStartBanner(challenge)
}
```

// MARK: - Example 2: Weather Control

Force weather to stay consistent:

```swift
func updateWeather() {
    // In daily challenge mode, never change weather
    if currentChallenge != nil {
        return // Weather is locked
    }
    
    // Normal weather progression for endless mode
    let newWeather = Configuration.Weather.weatherForScore(score)
    if newWeather != currentWeather {
        transitionToWeather(newWeather)
    }
}
```

// MARK: - Example 3: Enemy Spawning

Adjust enemy spawn rates based on challenge:

```swift
func shouldSpawnEnemy() -> Bool {
    guard let challenge = currentChallenge else {
        // Normal difficulty scaling for endless mode
        let level = Configuration.Difficulty.level(forScore: score)
        let probability = Configuration.Difficulty.enemyProbability(
            forLevel: level, 
            weather: currentWeather
        )
        return Double.random(in: 0...1) < probability
    }
    
    // Daily challenge mode - use challenge-specific probability
    let distanceMeters = score / 10 // Convert score to meters
    let probability = DailyChallenges.shared.getEnemySpawnProbability(
        for: challenge,
        distance: distanceMeters
    )
    return Double.random(in: 0...1) < probability
}

func spawnEnemy() {
    guard let challenge = currentChallenge else {
        // Normal enemy type selection
        spawnRandomEnemy()
        return
    }
    
    // Daily challenge mode - respect enemy focus
    let enemyType: EnemyType
    if challenge.focusEnemyTypes.contains(.bee) {
        enemyType = .bee
    } else if challenge.focusEnemyTypes.contains(.dragonfly) {
        enemyType = .dragonfly
    } else {
        // Mixed - random selection
        enemyType = Bool.random() ? .bee : .dragonfly
    }
    
    spawnEnemyOfType(enemyType)
}
```

// MARK: - Example 4: Lily Pad Spawning

Adjust pad types based on challenge:

```swift
func generateNewLilyPad(at position: CGPoint) -> Pad {
    guard let challenge = currentChallenge else {
        // Normal pad generation
        return generateNormalPad(at: position)
    }
    
    // Daily challenge mode - use challenge-specific pad probabilities
    let padType = selectPadTypeForChallenge(challenge)
    return createPad(ofType: padType, at: position)
}

func selectPadTypeForChallenge(_ challenge: DailyChallenge) -> PadType {
    // Check what pad focus this challenge has
    if challenge.focusPadTypes.contains(.moving) {
        let prob = DailyChallenges.shared.getPadSpawnProbability(for: .moving, in: challenge)
        if Double.random(in: 0...1) < prob {
            return .moving
        }
    }
    
    if challenge.focusPadTypes.contains(.shrinking) {
        let prob = DailyChallenges.shared.getPadSpawnProbability(for: .shrinking, in: challenge)
        if Double.random(in: 0...1) < prob {
            return .shrinking
        }
    }
    
    if challenge.focusPadTypes.contains(.ice) {
        let prob = DailyChallenges.shared.getPadSpawnProbability(for: .ice, in: challenge)
        if Double.random(in: 0...1) < prob {
            return .ice
        }
    }
    
    // Default to normal pad
    return .normal
}
```

// MARK: - Example 5: Win Condition & Finish Line

Check for challenge completion and show finish line:

```swift
var finishLineNode: SKNode?
let finishLineDistance: CGFloat = 2000 * 10 // 2000m converted to score

func update(_ currentTime: TimeInterval) {
    // ... existing update logic ...
    
    // Spawn finish line when player gets close (200m away)
    if let challenge = currentChallenge, finishLineNode == nil, score >= 18000 {
        spawnFinishLine()
    }
    
    // Check for daily challenge completion
    if let challenge = currentChallenge, score >= 20000 {
        // Player reached 2000m - challenge complete!
        handleDailyChallengeComplete()
    }
}

private func spawnFinishLine() {
    guard currentChallenge != nil else { return }
    
    let finishLine = SKNode()
    finishLine.name = "finishLine"
    
    // Calculate world position for 2000m mark
    let finishY = currentPlayerY + (finishLineDistance - CGFloat(score))
    
    // Create checkered pattern banner
    let bannerWidth: CGFloat = size.width * 1.2
    let bannerHeight: CGFloat = 60
    let squareSize: CGFloat = 30
    
    // Background banner
    let banner = SKSpriteNode(color: .white, size: CGSize(width: bannerWidth, height: bannerHeight))
    banner.position = CGPoint(x: size.width / 2, y: 0)
    banner.zPosition = Layer.background + 5 // Behind player but in front of pads
    
    // Add checkered pattern
    let squaresAcross = Int(bannerWidth / squareSize) + 1
    for i in 0..<squaresAcross {
        let x = CGFloat(i) * squareSize - bannerWidth / 2 + squareSize / 2
        
        // Top row
        let topSquare = SKSpriteNode(color: i % 2 == 0 ? .black : .white, 
                                     size: CGSize(width: squareSize, height: squareSize))
        topSquare.position = CGPoint(x: x, y: squareSize / 2)
        banner.addChild(topSquare)
        
        // Bottom row (inverse pattern)
        let bottomSquare = SKSpriteNode(color: i % 2 == 0 ? .white : .black, 
                                        size: CGSize(width: squareSize, height: squareSize))
        bottomSquare.position = CGPoint(x: x, y: -squareSize / 2)
        banner.addChild(bottomSquare)
    }
    
    finishLine.addChild(banner)
    
    // Add "FINISH" text
    let finishLabel = SKLabelNode(fontNamed: "Fredoka-Bold")
    finishLabel.text = "FINISH"
    finishLabel.fontSize = 36
    finishLabel.fontColor = .cyan
    finishLabel.position = CGPoint(x: size.width / 2, y: 5)
    finishLabel.zPosition = Layer.background + 6
    
    // Add outline/stroke effect
    let outlineLabel = SKLabelNode(fontNamed: "Fredoka-Bold")
    outlineLabel.text = "FINISH"
    outlineLabel.fontSize = 36
    outlineLabel.fontColor = .black
    outlineLabel.position = CGPoint(x: 0, y: 0)
    outlineLabel.zPosition = -1
    for xOffset in [-2.0, 2.0] {
        for yOffset in [-2.0, 2.0] {
            let shadow = SKLabelNode(fontNamed: "Fredoka-Bold")
            shadow.text = "FINISH"
            shadow.fontSize = 36
            shadow.fontColor = .black
            shadow.position = CGPoint(x: xOffset, y: yOffset)
            shadow.zPosition = -1
            finishLabel.addChild(shadow)
        }
    }
    
    finishLine.addChild(finishLabel)
    
    // Add distance marker
    let distanceLabel = SKLabelNode(fontNamed: "Nunito-Bold")
    distanceLabel.text = "2000m"
    distanceLabel.fontSize = 18
    distanceLabel.fontColor = .yellow
    distanceLabel.position = CGPoint(x: size.width / 2, y: -40)
    distanceLabel.zPosition = Layer.background + 6
    finishLine.addChild(distanceLabel)
    
    // Position the entire finish line node
    finishLine.position = CGPoint(x: 0, y: finishY)
    
    // Add pulsing animation
    let pulse = SKAction.sequence([
        SKAction.scale(to: 1.05, duration: 0.5),
        SKAction.scale(to: 1.0, duration: 0.5)
    ])
    finishLabel.run(SKAction.repeatForever(pulse))
    
    // Add shimmer effect to banner
    let shimmer = SKAction.sequence([
        SKAction.fadeAlpha(to: 0.8, duration: 0.3),
        SKAction.fadeAlpha(to: 1.0, duration: 0.3)
    ])
    banner.run(SKAction.repeatForever(shimmer))
    
    finishLineNode = finishLine
    addChild(finishLine)
    
    print("🏁 Finish line spawned at \(finishY)")
}

private func handleDailyChallengeComplete() {
    print("🏆 Daily Challenge Complete!")
    
    // Add celebratory effects when crossing finish line
    showCompletionEffects()
    
    // End the game successfully after a brief delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.endGame(successful: true)
    }
}

private func showCompletionEffects() {
    guard let finishLine = finishLineNode else { return }
    
    // Confetti explosion
    let emitter = SKEmitterNode()
    emitter.particleTexture = SKTexture(imageNamed: "spark") // Use your particle texture
    emitter.particleBirthRate = 200
    emitter.numParticlesToEmit = 100
    emitter.particleLifetime = 2.0
    emitter.emissionAngle = .pi / 2
    emitter.emissionAngleRange = .pi * 2
    emitter.particleSpeed = 200
    emitter.particleSpeedRange = 100
    emitter.particleAlpha = 1.0
    emitter.particleAlphaRange = 0.5
    emitter.particleAlphaSpeed = -0.5
    emitter.particleScale = 0.3
    emitter.particleScaleRange = 0.2
    emitter.particleColorBlendFactor = 1.0
    emitter.particleColor = .yellow
    emitter.particleColorSequence = nil
    emitter.position = CGPoint(x: size.width / 2, y: finishLine.position.y)
    emitter.zPosition = Layer.ui
    addChild(emitter)
    
    // Remove emitter after particles die
    emitter.run(SKAction.sequence([
        SKAction.wait(forDuration: 3.0),
        SKAction.removeFromParent()
    ]))
    
    // Flash effect
    let flash = SKSpriteNode(color: .white, size: size)
    flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
    flash.alpha = 0
    flash.zPosition = Layer.overlay
    addChild(flash)
    
    flash.run(SKAction.sequence([
        SKAction.fadeAlpha(to: 0.6, duration: 0.1),
        SKAction.fadeAlpha(to: 0, duration: 0.3),
        SKAction.removeFromParent()
    ]))
}
```

// MARK: - Example 6: Visual Feedback

Show challenge progress:

```swift
func setupDailyChallengeHUD() {
    guard currentChallenge != nil else { return }
    
    // Add a progress bar or distance counter
    let progressLabel = SKLabelNode(fontNamed: Configuration.Fonts.hudScore.name)
    progressLabel.fontSize = 18
    progressLabel.position = CGPoint(x: size.width / 2, y: size.height - 100)
    progressLabel.name = "challengeProgress"
    progressLabel.zPosition = Layer.ui
    addChild(progressLabel)
}

func updateChallengeProgress() {
    guard currentChallenge != nil else { return }
    
    let distanceMeters = score / 10
    let progress = min(100, Int((Double(distanceMeters) / 2000.0) * 100))
    
    if let progressLabel = childNode(withName: "challengeProgress") as? SKLabelNode {
        progressLabel.text = "\(distanceMeters)m / 2000m (\(progress)%)"
    }
}
```

// MARK: - Example 7: Challenge Start Banner

Show challenge info at start:

```swift
private func showChallengeStartBanner(_ challenge: DailyChallenge) {
    // Create a banner showing the challenge name and description
    let banner = SKSpriteNode(color: .black.withAlphaComponent(0.8), size: CGSize(width: size.width * 0.9, height: 120))
    banner.position = CGPoint(x: size.width / 2, y: size.height / 2)
    banner.zPosition = Layer.overlay
    
    let titleLabel = SKLabelNode(fontNamed: "Fredoka-Bold")
    titleLabel.text = challenge.name
    titleLabel.fontSize = 24
    titleLabel.fontColor = .cyan
    titleLabel.position = CGPoint(x: 0, y: 20)
    banner.addChild(titleLabel)
    
    let descLabel = SKLabelNode(fontNamed: "Nunito-Bold")
    descLabel.text = challenge.description
    descLabel.fontSize = 16
    descLabel.fontColor = .white
    descLabel.position = CGPoint(x: 0, y: -10)
    banner.addChild(descLabel)
    
    let goalLabel = SKLabelNode(fontNamed: "Nunito-Bold")
    goalLabel.text = "Goal: Reach 2000m"
    goalLabel.fontSize = 14
    goalLabel.fontColor = .yellow
    goalLabel.position = CGPoint(x: 0, y: -35)
    banner.addChild(goalLabel)
    
    addChild(banner)
    
    // Fade out after 3 seconds
    let sequence = SKAction.sequence([
        SKAction.wait(forDuration: 3.0),
        SKAction.fadeOut(withDuration: 0.5),
        SKAction.removeFromParent()
    ])
    banner.run(sequence)
}
```

// MARK: - Example 8: Seeded Random Generation

Use the challenge seed for consistent generation:

```swift
// Store a seeded generator per challenge
var challengeRNG: SeededRandomNumberGenerator?

func setupDailyChallenge(_ challenge: DailyChallenge) {
    // Create RNG with challenge seed
    challengeRNG = SeededRandomNumberGenerator(seed: UInt64(abs(challenge.seed)))
    
    // Now use this for all random decisions in the challenge
}

func generateChallengeElement() -> SomeElement {
    guard var rng = challengeRNG else {
        return generateNormalElement()
    }
    
    // Use the seeded RNG instead of the default random
    let value = Int.random(in: 1...10, using: &rng)
    
    // Update the stored RNG with the new state
    challengeRNG = rng
    
    return createElement(withValue: value)
}
```

*/

// MARK: - Helper Extensions

extension GameMode {
    var isDailyChallenge: Bool {
        if case .dailyChallenge = self {
            return true
        }
        return false
    }
    
    var isEndless: Bool {
        if case .endless = self {
            return true
        }
        return false
    }
    
    var isRace: Bool {
        if case .beatTheBoat = self {
            return true
        }
        return false
    }
}
