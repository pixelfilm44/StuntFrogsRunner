import UIKit

class ShopViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - UI Elements
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 44/255, green: 62/255, blue: 80/255, alpha: 1)
        return view
    }()
    
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "FROG SHOP"
        label.font = UIFont.systemFont(ofSize: 36, weight: .heavy)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var coinsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .yellow
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("BACK", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
    }
    
    private func setupUI() {
        view.addSubview(containerView)
        containerView.frame = view.bounds
        containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        containerView.addSubview(headerLabel)
        containerView.addSubview(coinsLabel)
        containerView.addSubview(stackView)
        containerView.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            coinsLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            coinsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            backButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 150),
            backButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Add Items (Wait for refreshData to populate)
    }
    
    enum UpgradeType { case jump, health, logJumper }
    
    private func createItemView(type: UpgradeType) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.cgColor
        view.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        let title = UILabel()
        title.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        
        let desc = UILabel()
        desc.font = UIFont.systemFont(ofSize: 14)
        desc.textColor = .lightGray
        desc.translatesAutoresizingMaskIntoConstraints = false
        
        let costLabel = UILabel()
        costLabel.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        costLabel.textColor = .yellow
        costLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let buyButton = UIButton(type: .system)
        buyButton.backgroundColor = .green
        buyButton.setTitle("UPGRADE", for: .normal)
        buyButton.setTitleColor(.black, for: .normal)
        buyButton.layer.cornerRadius = 8
        buyButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Logic Setup
        let currentLevel: Int
        let cost: Int
        let maxLevel: Int
        var isPurchased = false
        
        switch type {
        case .jump:
            currentLevel = PersistenceManager.shared.jumpLevel
            cost = Configuration.Shop.jumpUpgradeCost(currentLevel: currentLevel)
            maxLevel = Configuration.Shop.maxJumpLevel
            title.text = "Gym Membership (Lvl \(currentLevel))"
            desc.text = "Increases Jump Power"
        case .health:
            currentLevel = PersistenceManager.shared.healthLevel
            cost = Configuration.Shop.healthUpgradeCost(currentLevel: currentLevel)
            maxLevel = Configuration.Shop.maxHealthLevel
            title.text = "Extra Heart (Lvl \(currentLevel))"
            desc.text = "Start with +1 HP"
        case .logJumper:
            isPurchased = PersistenceManager.shared.hasLogJumper
            cost = Configuration.Shop.logJumperCost
            maxLevel = 1
            currentLevel = isPurchased ? 1 : 0
            title.text = "Log Jumper"
            desc.text = "Land on Logs safely!"
        }
        
        let userCoins = PersistenceManager.shared.totalCoins
        
        if isPurchased {
            costLabel.text = "OWNED"
            buyButton.isEnabled = false
            buyButton.backgroundColor = .gray
            buyButton.setTitle("OWNED", for: .normal)
        } else if type != .logJumper && currentLevel >= maxLevel {
            costLabel.text = "MAXED"
            buyButton.isEnabled = false
            buyButton.backgroundColor = .gray
            buyButton.setTitle("MAXED", for: .normal)
        } else {
            costLabel.text = "\(cost) Coins"
            
            // NEW: Check affordability
            if userCoins < cost {
                buyButton.isEnabled = false
                buyButton.backgroundColor = UIColor.systemGray // Dimmed
                buyButton.setTitleColor(.lightGray, for: .disabled)
            }
        }
        
        buyButton.addAction(UIAction(handler: { [weak self] _ in
            self?.attemptPurchase(type: type, cost: cost)
        }), for: .touchUpInside)
        
        view.addSubview(title)
        view.addSubview(desc)
        view.addSubview(costLabel)
        view.addSubview(buyButton)
        
        NSLayoutConstraint.activate([
            // Title: Top Left
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            
            // Description: Below Title
            desc.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 5),
            desc.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            
            // Cost Label: NEW POSITION (Below Description, Left Aligned)
            costLabel.topAnchor.constraint(equalTo: desc.bottomAnchor, constant: 10),
            costLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            
            // Buy Button: Vertically Centered, Right Aligned
            buyButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            buyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            buyButton.widthAnchor.constraint(equalToConstant: 100),
            buyButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return view
    }
    
    private func refreshData() {
        let coins = PersistenceManager.shared.totalCoins
        coinsLabel.text = "Coins: \(coins)"
        
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stackView.addArrangedSubview(createItemView(type: .jump))
        stackView.addArrangedSubview(createItemView(type: .health))
        stackView.addArrangedSubview(createItemView(type: .logJumper))
    }
    
    private func attemptPurchase(type: UpgradeType, cost: Int) {
        if PersistenceManager.shared.spendCoins(cost) {
            HapticsManager.shared.playNotification(.success)
            SoundManager.shared.play("coin")
            
            switch type {
            case .jump: PersistenceManager.shared.upgradeJump()
            case .health: PersistenceManager.shared.upgradeHealth()
            case .logJumper: PersistenceManager.shared.unlockLogJumper()
            }
            
            refreshData()
        } else {
            HapticsManager.shared.playNotification(.error)
        }
    }
    
    @objc private func handleBack() {
        HapticsManager.shared.playImpact(.light)
        coordinator?.showMenu()
    }
}
