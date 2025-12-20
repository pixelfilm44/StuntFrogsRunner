import UIKit
import MessageUI

class MenuViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - Background
    private lazy var backgroundImageView: UIImageView = {
        // Loads "background.png" from Assets or Bundle
        let imageView = UIImageView(image: UIImage(named: "backdrop"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "StuntFrogTitle"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var statsLabel1: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        // Add shadow for readability over background image
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var statsValue1: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "Fredoka-Bold", size: 24)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        // Add shadow for readability over background image
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var statsLabel2: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        // Add shadow for readability over background image
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var statsValue2: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "Fredoka-Bold", size: 24)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        // Add shadow for readability over background image
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var playButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage(named: "primaryButton"), for: .normal)
        button.setTitle("PLAY", for: .normal)
        button.titleLabel?.font = UIFont(name: "Fredoka-Bold", size: 28)
        // "Darker Yellow" for the font
        button.setTitleColor(UIColor(red: 186/255, green: 96/255, blue: 2/255, alpha: 1), for: .normal)
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 4
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handlePlay), for: .touchUpInside)
        return button
    }()
    
    private lazy var raceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("RACE", for: .normal)
        button.setBackgroundImage(UIImage(named: "secondaryButton"), for: .normal)

        button.titleLabel?.font = UIFont(name: "Fredoka-Bold", size: 24)
        // Light blue text
        button.setTitleColor(UIColor(red: 93/255, green: 173/255, blue: 226/255, alpha: 1), for: .normal)
       
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 5
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleRace), for: .touchUpInside)
        return button
    }()
    
    private lazy var shopButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "shoppingButton"), for: .normal)
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 3
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleShop), for: .touchUpInside)
        return button
    }()
    
    private lazy var leaderboardButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "leadersButton"), for: .normal)
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 3
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleLeaderboard), for: .touchUpInside)
        return button
    }()
    
    private lazy var challengesButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "challengesButton"), for: .normal)
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 3
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleChallenges), for: .touchUpInside)
        return button
    }()
    
    private lazy var challengeBadge: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.backgroundColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var helpButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage(named: "helpButton"), for: .normal)

        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 3
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleHelp), for: .touchUpInside)
        return button
    }()
    
    private lazy var feedbackButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setBackgroundImage(UIImage(named: "supportButton"), for: .normal)

        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 3
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleFeedback), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupButtonAnimations()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateStats()
        updateChallengeBadge()
        coordinator?.authenticateGameCenter()
        SoundManager.shared.playMusic(.menu)
        animateTitleOnLoad()
    }
    
    private func updateChallengeBadge() {
        let unclaimed = ChallengeManager.shared.unclaimedChallengesCount
        if unclaimed > 0 {
            challengeBadge.text = "\(unclaimed)"
            challengeBadge.isHidden = false
        } else {
            challengeBadge.isHidden = true
        }
    }
    
    private func setupUI() {
        // Add Background Image first
        view.addSubview(backgroundImageView)
        
        view.addSubview(titleImageView)
        view.addSubview(playButton)
        view.addSubview(raceButton)
        view.addSubview(helpButton)
        view.addSubview(feedbackButton)
        
        // Create a horizontal stack view for shop, challenges, and leaderboard buttons
        let secondaryActionsStackView = UIStackView(arrangedSubviews: [shopButton, challengesButton, leaderboardButton])
        secondaryActionsStackView.axis = .horizontal
        secondaryActionsStackView.distribution = .equalSpacing
        secondaryActionsStackView.alignment = .center
        secondaryActionsStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(secondaryActionsStackView)

        // The challenge badge needs to be on top of other views
        view.addSubview(challengeBadge)
        
        // Create vertical stack views for each stat
        let highScoreStackView = UIStackView(arrangedSubviews: [statsLabel1, statsValue1])
        highScoreStackView.axis = .vertical
        highScoreStackView.alignment = .center
        highScoreStackView.spacing = 4
        
        let coinsStackView = UIStackView(arrangedSubviews: [statsLabel2, statsValue2])
        coinsStackView.axis = .vertical
        coinsStackView.alignment = .center
        coinsStackView.spacing = 4
        
        // Create a horizontal stack view to hold both stat stacks
        let statsContainerStackView = UIStackView(arrangedSubviews: [highScoreStackView, coinsStackView])
        statsContainerStackView.axis = .horizontal
        statsContainerStackView.distribution = .fillEqually
        statsContainerStackView.alignment = .center
        statsContainerStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsContainerStackView)
        
        // A layout guide to define the flexible space for the title image
        let titleAreaGuide = UILayoutGuide()
        view.addLayoutGuide(titleAreaGuide)

        NSLayoutConstraint.activate([
            // Background Constraints (Fill Screen)
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Center title horizontally
            titleImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            // Set max width to 85% of safe area width to prevent touching edges on wide screens
            titleImageView.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.95),
            
            // The guide will fill the space between the top buttons and the stats section
            titleAreaGuide.topAnchor.constraint(equalTo: feedbackButton.bottomAnchor, constant: 10),
            titleAreaGuide.bottomAnchor.constraint(equalTo: statsContainerStackView.topAnchor, constant: -10),
            
            // Center the title image view vertically within this guide
            titleImageView.centerYAnchor.constraint(equalTo: titleAreaGuide.centerYAnchor),
            // Also constrain its height to not exceed the guide's height (with some padding)
            titleImageView.heightAnchor.constraint(lessThanOrEqualTo: titleAreaGuide.heightAnchor, multiplier: 0.8),

            // Help button - top right corner
            helpButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            helpButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            helpButton.widthAnchor.constraint(equalToConstant: 44),
            helpButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Feedback button - top left corner
            feedbackButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            feedbackButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            feedbackButton.widthAnchor.constraint(equalToConstant: 44),
            feedbackButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Icon buttons at the very bottom
            secondaryActionsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            secondaryActionsStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 50),
            secondaryActionsStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -50),
            
            // Race button above the icon buttons
            raceButton.bottomAnchor.constraint(equalTo: secondaryActionsStackView.topAnchor, constant: -25),
            raceButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            raceButton.widthAnchor.constraint(equalToConstant: 200),
            raceButton.heightAnchor.constraint(equalToConstant: 60),

            // Play button above the race button
            playButton.bottomAnchor.constraint(equalTo: raceButton.topAnchor, constant: -12),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 225),
            playButton.heightAnchor.constraint(equalToConstant: 70),
            
            // Stats container above the play button
            statsContainerStackView.bottomAnchor.constraint(equalTo: playButton.topAnchor, constant: -20),
            statsContainerStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            statsContainerStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

            // Explicit size for the image buttons
            shopButton.widthAnchor.constraint(equalToConstant: 45),
            shopButton.heightAnchor.constraint(equalToConstant: 45),
            challengesButton.widthAnchor.constraint(equalToConstant: 45),
            challengesButton.heightAnchor.constraint(equalToConstant: 45),
            leaderboardButton.widthAnchor.constraint(equalToConstant: 45),
            leaderboardButton.heightAnchor.constraint(equalToConstant: 45),

            // Badge constraints relative to the challenges button
            challengeBadge.topAnchor.constraint(equalTo: challengesButton.topAnchor, constant: -8),
            challengeBadge.trailingAnchor.constraint(equalTo: challengesButton.trailingAnchor, constant: 8),
            challengeBadge.widthAnchor.constraint(equalToConstant: 24),
            challengeBadge.heightAnchor.constraint(equalToConstant: 24),
        ])
    }
    
    // MARK: - View Animations
    
    private func animateTitleOnLoad() {
        // Start with the title scaled up and faded out
        titleImageView.transform = CGAffineTransform(scaleX: 3.2, y: 3.2)
        titleImageView.alpha = 0

        // Animate to the final state with a spring effect
        UIView.animate(withDuration: 0.8,
                       delay: 0.2,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 1,
                       options: .allowUserInteraction,
                       animations: {
            self.titleImageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            self.titleImageView.alpha = 1
        })
    }
    
    // MARK: - Button Animations
    
    private func setupButtonAnimations() {
        let buttons = [playButton, raceButton, shopButton, leaderboardButton, challengesButton, helpButton, feedbackButton]
        for button in buttons {
            button.addTarget(self, action: #selector(buttonPressed), for: .touchDown)
            button.addTarget(self, action: #selector(buttonReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
    }
    
    @objc private func buttonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction]) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 2, options: [.curveEaseInOut, .allowUserInteraction]) {
            sender.transform = .identity
        }
    }
    
    private func updateStats() {
        let high = PersistenceManager.shared.highScore
        let coins = PersistenceManager.shared.totalCoins
        statsLabel1.text = "High Score:"
        statsValue1.text = "\(high)"
        statsLabel2.text = "Coins:"
        statsValue2.text = "\(coins)"
    }
    
    @objc private func handlePlay() {
        HapticsManager.shared.playImpact(.medium)
        
        // Show help modal on first play
        if !PersistenceManager.shared.hasSeenHelp {
            showHelpModal(startGameOnDismiss: true)
            
            
        } else {
            coordinator?.startGame()
        }
    }
    
    @objc private func handleRace() {
        HapticsManager.shared.playImpact(.light)
        coordinator?.startRace()
    }
    
    @objc private func handleShop() {
        HapticsManager.shared.playImpact(.light)
        coordinator?.showShop()
    }
    
    @objc private func handleLeaderboard() {
        HapticsManager.shared.playImpact(.light)
        coordinator?.showLeaderboard()
    }
    
    @objc private func handleChallenges() {
        HapticsManager.shared.playImpact(.light)
        coordinator?.showChallenges()
    }
    
    @objc private func handleHelp() {
        HapticsManager.shared.playImpact(.light)
        showHelpModal(startGameOnDismiss: false)
    }
    
    @objc private func handleFeedback() {
        HapticsManager.shared.playImpact(.light)
        
        guard MFMailComposeViewController.canSendMail() else {
            let alert = UIAlertController(title: "Cannot Send Mail", message: "Your device is not configured to send email.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        mailComposer.setToRecipients(["jmielke@gmail.com"])
        mailComposer.setSubject("StuntFrog Feedback")
        
        present(mailComposer, animated: true)
    }
    
    private func showHelpModal(startGameOnDismiss: Bool) {
        let helpVC = HelpViewController()
        ToolTips.resetToolTipHistory()
        helpVC.modalPresentationStyle = .overFullScreen
        helpVC.modalTransitionStyle = .crossDissolve
        helpVC.onDismiss = { [weak self] in
            PersistenceManager.shared.markHelpAsSeen()
            if startGameOnDismiss {
                self?.coordinator?.startGame()
            }
        }
        present(helpVC, animated: true)
    }
}

extension MenuViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
