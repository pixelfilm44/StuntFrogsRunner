import UIKit

class MenuViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - Background
    private lazy var backgroundImageView: UIImageView = {
        // Loads "menuScreen.png" from Assets or Bundle
        let imageView = UIImageView(image: UIImage(named: "StuntFrogTitle"))
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black  // Fill letterbox areas with black
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.numberOfLines = 2
        label.font = UIFont(name: "Fredoka-Bold", size: 60)
        label.textColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1)
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 3, height: 3)
        label.layer.shadowOpacity = 1.0
        label.layer.shadowRadius = 0.0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var statsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        // Add shadow for readability over background image
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("PLAY", for: .normal)
        button.titleLabel?.font = UIFont(name: "Fredoka-Bold", size: 36)
        button.setTitleColor(UIColor(red: 211/255, green: 84/255, blue: 0/255, alpha: 1), for: .normal)
        button.backgroundColor = UIColor(red: 241/255, green: 196/255, blue: 15/255, alpha: 1)
        button.layer.cornerRadius = 37
        button.layer.borderWidth = 6
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handlePlay), for: .touchUpInside)
        return button
    }()
    
    private lazy var raceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("RACE", for: .normal)
        button.titleLabel?.font = UIFont(name: "Fredoka-Bold", size: 24)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 26/255, green: 188/255, blue: 156/255, alpha: 1) // Teal color
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleRace), for: .touchUpInside)
        return button
    }()
    
    private lazy var shopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("SHOP", for: .normal)
        button.titleLabel?.font = UIFont(name: "Fredoka-Bold", size: 24)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1)
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleShop), for: .touchUpInside)
        return button
    }()
    
    private lazy var leaderboardButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("LEADERS", for: .normal)
        button.titleLabel?.font = UIFont(name: "Fredoka-Bold", size: 24)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 155/255, green: 89/255, blue: 182/255, alpha: 1) // Purple
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleLeaderboard), for: .touchUpInside)
        return button
    }()
    
    private lazy var challengesButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("CHALLENGES", for: .normal)
        button.titleLabel?.font = UIFont(name: "Fredoka-Bold", size: 24) 
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 230/255, green: 126/255, blue: 34/255, alpha: 1) // Orange
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
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
        let button = UIButton(type: .system)
        button.setTitle("?", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 52/255, green: 73/255, blue: 94/255, alpha: 1)
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleHelp), for: .touchUpInside)
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
        view.sendSubviewToBack(backgroundImageView)
        
        view.addSubview(titleLabel)
        view.addSubview(statsLabel)
        view.addSubview(playButton)
        view.addSubview(raceButton)
        view.addSubview(shopButton)
        view.addSubview(leaderboardButton)
        view.addSubview(challengesButton)
        view.addSubview(challengeBadge)
        view.addSubview(helpButton)
        
        NSLayoutConstraint.activate([
            // Background Constraints (Fill Screen)
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            
            statsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            statsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 30),
            playButton.widthAnchor.constraint(equalToConstant: 300),
            playButton.heightAnchor.constraint(equalToConstant: 90),
            
            raceButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            raceButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 15),
            raceButton.widthAnchor.constraint(equalToConstant: 200),
            raceButton.heightAnchor.constraint(equalToConstant: 60),
            
            shopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shopButton.topAnchor.constraint(equalTo: raceButton.bottomAnchor, constant: 15),
            shopButton.widthAnchor.constraint(equalToConstant: 200),
            shopButton.heightAnchor.constraint(equalToConstant: 60),
            
            challengesButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            challengesButton.topAnchor.constraint(equalTo: shopButton.bottomAnchor, constant: 15),
            challengesButton.widthAnchor.constraint(equalToConstant: 200),
            challengesButton.heightAnchor.constraint(equalToConstant: 60),
            
            challengeBadge.topAnchor.constraint(equalTo: challengesButton.topAnchor, constant: -8),
            challengeBadge.trailingAnchor.constraint(equalTo: challengesButton.trailingAnchor, constant: 8),
            challengeBadge.widthAnchor.constraint(equalToConstant: 24),
            challengeBadge.heightAnchor.constraint(equalToConstant: 24),
            
            leaderboardButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            leaderboardButton.topAnchor.constraint(equalTo: challengesButton.bottomAnchor, constant: 15),
            leaderboardButton.widthAnchor.constraint(equalToConstant: 200),
            leaderboardButton.heightAnchor.constraint(equalToConstant: 60),
            
            // Help button - top right corner
            helpButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            helpButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            helpButton.widthAnchor.constraint(equalToConstant: 44),
            helpButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Button Animations
    
    private func setupButtonAnimations() {
        let buttons = [playButton, raceButton, shopButton, leaderboardButton, challengesButton, helpButton]
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
        statsLabel.text = "High Score: \(high)m\nCoins: \(coins)"
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
    
    private func showHelpModal(startGameOnDismiss: Bool) {
        let helpVC = HelpViewController()
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
