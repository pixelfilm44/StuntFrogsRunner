import UIKit

class GameOverViewController: UIViewController {
    
    // Data passed from Coordinator
    var score: Int = 0
    var runCoins: Int = 0
    var isNewHighScore: Bool = false
    var raceResult: RaceResult?
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - UI Elements
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "WIPEOUT!"
        label.font = UIFont.systemFont(ofSize: 42, weight: .heavy)
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
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var highScoreLabel: UILabel = {
        let label = UILabel()
        label.text = "NEW HIGH SCORE!"
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = .yellow
        label.textAlignment = .center
        label.isHidden = true // Hidden by default
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var coinsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .lightGray
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("TRY AGAIN", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        button.setTitleColor(UIColor(red: 211/255, green: 84/255, blue: 0/255, alpha: 1), for: .normal)
        button.backgroundColor = UIColor(red: 241/255, green: 196/255, blue: 15/255, alpha: 1)
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        button.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        return button
    }()
    
    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("MENU", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1)
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.white.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        button.addTarget(self, action: #selector(handleMenu), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureData()
    }
    
    private func configureData() {
        if let result = raceResult {
            // Race mode UI
            highScoreLabel.isHidden = true
            retryButton.setTitle("RACE AGAIN", for: .normal)
            
            switch result {
            case .win:
                titleLabel.text = "YOU WIN!"
                titleLabel.textColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1) // Green
                scoreLabel.text = "You beat the boat!"
            case .lose(let reason):
                titleLabel.textColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1) // Red
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
                }
            }
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
        }
        
        let total = PersistenceManager.shared.totalCoins
        coinsLabel.text = "+ \(runCoins) Coins\nWallet: \(total)"
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(scoreLabel)
        containerView.addSubview(highScoreLabel)
        containerView.addSubview(coinsLabel)
        containerView.addSubview(retryButton)
        containerView.addSubview(menuButton)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 320),
            containerView.heightAnchor.constraint(equalToConstant: 400),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            scoreLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            scoreLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            highScoreLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 5),
            highScoreLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            coinsLabel.topAnchor.constraint(equalTo: highScoreLabel.bottomAnchor, constant: 15),
            coinsLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            retryButton.topAnchor.constraint(equalTo: coinsLabel.bottomAnchor, constant: 30),
            retryButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            menuButton.topAnchor.constraint(equalTo: retryButton.bottomAnchor, constant: 15),
            menuButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func handleRetry() {
        HapticsManager.shared.playImpact(.medium)
        dismiss(animated: true) {
            if self.raceResult != nil {
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
}
