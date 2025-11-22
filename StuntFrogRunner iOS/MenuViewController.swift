import UIKit

class MenuViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - Background
    private lazy var backgroundImageView: UIImageView = {
        // Loads "menuScreen.png" from Assets or Bundle
        let imageView = UIImageView(image: UIImage(named: "menuScreen"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "STUNT FROG\nSUPERSTAR"
        label.numberOfLines = 2
        label.font = UIFont.systemFont(ofSize: 48, weight: .heavy)
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
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        button.setTitleColor(UIColor(red: 211/255, green: 84/255, blue: 0/255, alpha: 1), for: .normal)
        button.backgroundColor = UIColor(red: 241/255, green: 196/255, blue: 15/255, alpha: 1)
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handlePlay), for: .touchUpInside)
        return button
    }()
    
    private lazy var shopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("SHOP", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
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
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 155/255, green: 89/255, blue: 182/255, alpha: 1) // Purple
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleLeaderboard), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateStats()
        coordinator?.authenticateGameCenter()
    }
    
    private func setupUI() {
        // Add Background Image first
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)
        
        view.addSubview(titleLabel)
        view.addSubview(statsLabel)
        view.addSubview(playButton)
        view.addSubview(shopButton)
        view.addSubview(leaderboardButton)
        
        NSLayoutConstraint.activate([
            // Background Constraints (Fill Screen)
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -140),
            
            statsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            statsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 40),
            playButton.widthAnchor.constraint(equalToConstant: 200),
            playButton.heightAnchor.constraint(equalToConstant: 60),
            
            shopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shopButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 20),
            shopButton.widthAnchor.constraint(equalToConstant: 200),
            shopButton.heightAnchor.constraint(equalToConstant: 60),
            
            leaderboardButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            leaderboardButton.topAnchor.constraint(equalTo: shopButton.bottomAnchor, constant: 20),
            leaderboardButton.widthAnchor.constraint(equalToConstant: 200),
            leaderboardButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func updateStats() {
        let high = PersistenceManager.shared.highScore
        let coins = PersistenceManager.shared.totalCoins
        statsLabel.text = "High Score: \(high)m\nCoins: \(coins)"
    }
    
    @objc private func handlePlay() {
        HapticsManager.shared.playImpact(.medium)
        coordinator?.startGame()
    }
    
    @objc private func handleShop() {
        HapticsManager.shared.playImpact(.light)
        coordinator?.showShop()
    }
    
    @objc private func handleLeaderboard() {
        HapticsManager.shared.playImpact(.light)
        coordinator?.showLeaderboard()
    }
}
