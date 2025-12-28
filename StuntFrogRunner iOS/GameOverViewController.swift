import UIKit
import GameKit

class GameOverViewController: UIViewController {
    
    // Data passed from Coordinator
    var score: Int = 0
    var runCoins: Int = 0
    var isNewHighScore: Bool = false
    var raceResult: RaceResult?
    var winStreak: Int = 0
    var isDailyChallenge: Bool = false
    var dailyChallengeCompleted: Bool = false
    var completionTime: TimeInterval = 0  // Store the completion time for challenges
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - UI Elements
    private lazy var containerView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "gameOverBackdrop"))
        view.isUserInteractionEnabled = true // Required for buttons inside
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "WIPEOUT!"
        label.font = UIFont(name: Configuration.Fonts.gameOverTitle.name, size: 32)
        label.textColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        // Shadow
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 2, height: 2)
        label.layer.shadowOpacity = 1.0
        label.layer.shadowRadius = 0.0
        return label
    }()
    
    private lazy var scoreLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: Configuration.Fonts.gameOverScore.name, size: Configuration.Fonts.gameOverScore.size)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2 // Allow for multiline text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var highScoreLabel: UILabel = {
        let label = UILabel()
        label.text = "NEW HIGH SCORE!"
        label.font = UIFont(name: Configuration.Fonts.gameOverSubtext.name, size: Configuration.Fonts.gameOverSubtext.size)
        label.textColor = .yellow
        label.textAlignment = .center
        label.isHidden = true // Hidden by default
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var coinsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: Configuration.Fonts.gameOverSubtext.name, size: 14)
        label.textColor = .lightGray
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("TRY AGAIN", for: .normal)
        button.titleLabel?.font = UIFont(name: Configuration.Fonts.gameOverButton.name, size: Configuration.Fonts.gameOverButton.size)
        button.setTitleColor(.white, for: .normal)
        button.setBackgroundImage(UIImage(named: "primaryButton"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        button.widthAnchor.constraint(equalToConstant: 220).isActive = true
        button.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        return button
    }()
    
    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("MENU", for: .normal)
        button.titleLabel?.font = UIFont(name: Configuration.Fonts.gameOverButton.name, size: Configuration.Fonts.gameOverButton.size)
        button.setTitleColor(.white, for: .normal)
        button.setBackgroundImage(UIImage(named: "secondaryButton"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        button.widthAnchor.constraint(equalToConstant: 220).isActive = true
        button.addTarget(self, action: #selector(handleMenu), for: .touchUpInside)
        return button
    }()
    
    private lazy var challengeFriendButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("CHALLENGE FRIEND", for: .normal)
        button.titleLabel?.font = UIFont(name: Configuration.Fonts.gameOverButton.name, size: Configuration.Fonts.gameOverButton.size)
        button.setTitleColor(UIColor(red: 93/255, green: 173/255, blue: 226/255, alpha: 1), for: .normal)
        button.setBackgroundImage(UIImage(named: "secondaryButton"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 55).isActive = true
        button.widthAnchor.constraint(equalToConstant: 220).isActive = true
        button.addTarget(self, action: #selector(handleChallengeFriend), for: .touchUpInside)
        button.isHidden = true  // Only shown for completed daily challenges
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Prepare for animation: start off-screen to the left and invisible
        containerView.transform = CGAffineTransform(translationX: -view.bounds.width, y: 0)
        containerView.alpha = 0.0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Animate the view sliding in from the left with a bounce effect
        UIView.animate(withDuration: 0.7,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.8,
                       options: .curveEaseOut,
                       animations: {
            self.containerView.transform = .identity
            self.containerView.alpha = 1.0
        }, completion: nil)
    }
    
    private func configureData() {
        if isDailyChallenge {
            // Daily challenge mode UI
            highScoreLabel.isHidden = true
            scoreLabel.font = scoreLabel.font.withSize(20)
            
            if dailyChallengeCompleted {
                titleLabel.text = "COMPLETE!"
                titleLabel.textColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1) // Green
                retryButton.setTitle("TRY AGAIN", for: .normal)
                
                // Show challenge friend button
                challengeFriendButton.isHidden = false
                
                let bestTime = DailyChallenges.shared.getTodaysBestTime()
                let minutes = Int(bestTime) / 60
                let seconds = Int(bestTime) % 60
                let milliseconds = Int((bestTime.truncatingRemainder(dividingBy: 1)) * 100)
                
                scoreLabel.text = String(format: "Time: %d:%02d.%02d\nDistance: %dm", minutes, seconds, milliseconds, score)
                coinsLabel.text = "No coins in daily challenges"
            } else {
                titleLabel.text = "DIDN'T MAKE IT!"
                
                titleLabel.textColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1) // Red
                retryButton.setTitle("TRY AGAIN", for: .normal)
                scoreLabel.text = "Distance: \(score)m\nTarget: 1000m"
                coinsLabel.text = "Complete the challenge to set a time!"
                challengeFriendButton.isHidden = true
            }
        } else if let result = raceResult {
            // Race mode UI
            highScoreLabel.isHidden = true
            scoreLabel.font = scoreLabel.font.withSize(17)
            
            switch result {
            case .win:
                titleLabel.text = "YOU WIN!"
                titleLabel.textColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1) // Green
                retryButton.setTitle("REMATCH!", for: .normal)
                if winStreak > 0 {
                    scoreLabel.text = "You beat the boat!\nWin Streak: \(winStreak)"
                } else {
                    scoreLabel.text = "You beat the boat!"
                }
                
            case .lose(let reason):
                titleLabel.textColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1) // Red
                retryButton.setTitle("RACE AGAIN", for: .normal)
                
                switch reason {
                case .outrun:
                    titleLabel.text = "TOO SLOW!"
                    scoreLabel.text = "The boat won."
                case .outOfHealth:
                    titleLabel.text = "WIPED OUT!"
                    scoreLabel.text = "You lost all your hearts."
                case .drowned:
                    titleLabel.text = "SPLASH!"
                    scoreLabel.text = "You drowned in the river."
                case .missedLaunchPad:
                    titleLabel.text = "MISSED IT!"
                    scoreLabel.text = "You missed the launch pad."
                }
            }
            
            let total = PersistenceManager.shared.totalCoins
            coinsLabel.text = "+ \(runCoins) Coins\nWallet: \(total)"
        } else {
            // Endless mode UI
            titleLabel.text = "WIPEOUT!"
            scoreLabel.text = "\(score)m"
            retryButton.setTitle("TRY AGAIN", for: .normal)
            
            highScoreLabel.isHidden = !isNewHighScore
            if isNewHighScore {
                // Simple animation
                UIView.animate(withDuration: 0.5, delay: 0, options: [.autoreverse, .repeat], animations: {
                    self.highScoreLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                }, completion: nil)
            }
            
            let total = PersistenceManager.shared.totalCoins
            coinsLabel.text = "+ \(runCoins) Coins\nWallet: \(total)"
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        view.addSubview(containerView)
        
        // Create a stack view to hold all content for easy vertical centering
        let contentStackView = UIStackView(arrangedSubviews: [
            titleLabel,
            scoreLabel,
            highScoreLabel,
            coinsLabel,
            retryButton,
            challengeFriendButton,
            menuButton
        ])
        contentStackView.axis = .vertical
        contentStackView.alignment = .center
        contentStackView.spacing = 0 // We'll use custom spacing
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.setCustomSpacing(14, after: titleLabel)
        contentStackView.setCustomSpacing(8, after: scoreLabel)
        contentStackView.setCustomSpacing(16, after: highScoreLabel)
        contentStackView.setCustomSpacing(10, after: coinsLabel)
        contentStackView.setCustomSpacing(12, after: retryButton)
        contentStackView.setCustomSpacing(12, after: challengeFriendButton)
        
        containerView.addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 340),
            containerView.heightAnchor.constraint(equalToConstant: 440),
            
            // Center the content stack vertically and horizontally
            contentStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    @objc private func handleRetry() {
        HapticsManager.shared.playImpact(.medium)
        dismiss(animated: true) {
            if self.isDailyChallenge {
                self.coordinator?.startDailyChallenge()
            } else if self.raceResult != nil {
                self.coordinator?.startRace()
            } else {
                self.coordinator?.startGame()
            }
        }
    }
    
    @objc private func handleMenu() {
        HapticsManager.shared.playImpact(.light)
        dismiss(animated: true) {
            self.coordinator?.showMenu()
        }
    }
    
    @objc private func handleChallengeFriend() {
        HapticsManager.shared.playImpact(.medium)
        
        // Check if Game Center is authenticated
        guard GKLocalPlayer.local.isAuthenticated else {
            showGameCenterNotAuthenticatedAlert()
            return
        }
        
        // Present the friend picker with challenge composer
        presentFriendChallengeComposer()
    }
    
    private func showGameCenterNotAuthenticatedAlert() {
        let alert = UIAlertController(
            title: "Game Center Required",
            message: "Please sign in to Game Center to challenge friends.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func presentFriendChallengeComposer() {
        // Get the challenge details
        let challenge = DailyChallenges.shared.getTodaysChallenge()
        let bestTime = DailyChallenges.shared.getTodaysBestTime()
        
        // Create the shareable message
        let shareText = GameCenterChallengeManager.shared.createShareableText(
            challengeName: challenge.name,
            time: bestTime
        )
        
        // Present options for sharing
        let alertController = UIAlertController(
            title: "Challenge Friends",
            message: "How would you like to share your challenge?",
            preferredStyle: .actionSheet
        )
        
        // Option 1: Share via iOS Share Sheet (Messages, social media, etc.)
        alertController.addAction(UIAlertAction(title: "Share...", style: .default) { [weak self] _ in
            self?.showManualChallengeShareSheet(message: shareText)
        })
        
        // Option 2: Copy to clipboard
        alertController.addAction(UIAlertAction(title: "Copy Challenge Text", style: .default) { [weak self] _ in
            let challenge = DailyChallenges.shared.getTodaysChallenge()
            let bestTime = DailyChallenges.shared.getTodaysBestTime()
            let message = GameCenterChallengeManager.shared.createChallengeMessage(
                challengeName: challenge.name,
                time: bestTime
            )
            let deepLinkURL = GameCenterChallengeManager.shared.createChallengeDeepLinkURL()
            let fullText = "\(message)\n\n\(deepLinkURL)"
            
            UIPasteboard.general.string = fullText
            GameCenterChallengeManager.shared.recordChallengeSent()
            
            // Show copied confirmation
            let copiedAlert = UIAlertController(
                title: "Copied!",
                message: "Your challenge has been copied to the clipboard. Paste it anywhere to challenge your friends!",
                preferredStyle: .alert
            )
            copiedAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(copiedAlert, animated: true)
        })
        
        // Option 3: View Game Center Friends (iOS 14+)
        if #available(iOS 14.0, *) {
            alertController.addAction(UIAlertAction(title: "View Game Center Friends", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.pendingChallengeMessage = shareText
                let gcViewController = GKGameCenterViewController(state: .localPlayerFriendsList)
                gcViewController.gameCenterDelegate = self
                self.present(gcViewController, animated: true)
            })
        }
        
        // Cancel option
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad - set the source for the popover
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = challengeFriendButton
            popover.sourceRect = challengeFriendButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func showManualChallengeShareSheet(message: String) {
        // Use the challenge manager to create shareable content
        let challenge = DailyChallenges.shared.getTodaysChallenge()
        let bestTime = DailyChallenges.shared.getTodaysBestTime()
        
        // Create the message text
        let shareMessage = GameCenterChallengeManager.shared.createChallengeMessage(
            challengeName: challenge.name,
            time: bestTime
        )
        
        // Create the deep link URL as an actual URL object
        let deepLinkString = GameCenterChallengeManager.shared.createChallengeDeepLinkURL()
        
        // Share both the message and URL separately so iOS can make the URL tappable
        var activityItems: [Any] = [shareMessage]
        if let deepLinkURL = URL(string: deepLinkString) {
            activityItems.append(deepLinkURL)
        }
        
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = challengeFriendButton
            popover.sourceRect = challengeFriendButton.bounds
        }
        
        // Track when share sheet is presented
        activityVC.completionWithItemsHandler = { [weak self] activityType, completed, _, _ in
            if completed {
                GameCenterChallengeManager.shared.recordChallengeSent()
                print("✅ Challenge shared via \(activityType?.rawValue ?? "unknown")")
            }
        }
        
        present(activityVC, animated: true)
    }
    
    // Store the pending challenge message
    private var pendingChallengeMessage: String?
}

// MARK: - GKGameCenterControllerDelegate

extension GameOverViewController: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true) {
            // If user selected friends, send them a notification
            // Note: In a real implementation, you'd want to track which friends were selected
            // and send them an in-game notification or challenge via your backend
            
            if self.pendingChallengeMessage != nil {
                // Show confirmation
                let alert = UIAlertController(
                    title: "Share Your Challenge",
                    message: "Want to share your time with friends? You can copy your challenge message and send it via Messages, Discord, or any app!",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "Copy Message", style: .default) { _ in
                    if self.pendingChallengeMessage != nil {
                        let challenge = DailyChallenges.shared.getTodaysChallenge()
                        let bestTime = DailyChallenges.shared.getTodaysBestTime()
                        let message = GameCenterChallengeManager.shared.createChallengeMessage(
                            challengeName: challenge.name,
                            time: bestTime
                        )
                        let deepLinkURL = GameCenterChallengeManager.shared.createChallengeDeepLinkURL()
                        let fullMessage = "\(message)\n\n\(deepLinkURL)"
                        
                        UIPasteboard.general.string = fullMessage
                        
                        // Track challenge sent
                        GameCenterChallengeManager.shared.recordChallengeSent()
                        
                        // Show copied confirmation
                        let copiedAlert = UIAlertController(
                            title: "Copied!",
                            message: "Your challenge message has been copied. Paste it anywhere to challenge your friends!",
                            preferredStyle: .alert
                        )
                        copiedAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(copiedAlert, animated: true)
                    }
                })
                
                alert.addAction(UIAlertAction(title: "Share", style: .default) { _ in
                    if let message = self.pendingChallengeMessage {
                        self.showManualChallengeShareSheet(message: message)
                    }
                })
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                
                self.present(alert, animated: true)
            }
            
            self.pendingChallengeMessage = nil
        }
    }
}

