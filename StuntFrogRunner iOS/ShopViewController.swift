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
    
    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
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
        containerView.addSubview(scrollView)
        containerView.addSubview(backButton)
        
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            coinsLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            coinsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Scroll View - between coins label and back button
            scrollView.topAnchor.constraint(equalTo: coinsLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: backButton.topAnchor, constant: -20),
            
            // Stack View inside Scroll View
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -10),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            backButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 150),
            backButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    enum UpgradeType { case jump, health, logJumper, superJump, rocketJump, lifevestPack, honeyPack }
    
    private func createItemView(type: UpgradeType) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        cardView.layer.cornerRadius = 12
        cardView.layer.borderWidth = 2
        cardView.layer.borderColor = UIColor.white.cgColor
        cardView.clipsToBounds = true
        cardView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        let title = UILabel()
        title.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        
        let desc = UILabel()
        desc.font = UIFont.systemFont(ofSize: 14)
        desc.textColor = .lightGray
        desc.numberOfLines = 2
        desc.translatesAutoresizingMaskIntoConstraints = false
        
        let costLabel = UILabel()
        costLabel.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        costLabel.textColor = .yellow
        costLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let buyButton = UIButton(type: .system)
        buyButton.backgroundColor = .green
        buyButton.setTitle("UPGRADE", for: .normal)
        buyButton.setTitleColor(.black, for: .normal)
        buyButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        buyButton.layer.cornerRadius = 8
        buyButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Logic Setup
        var currentLevel: Int
        let cost: Int
        var maxLevel: Int
        var isPurchased = false
        var isUnlockItem = false  // NEW: Track if this unlocks upgrade menu options
        
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
        case .superJump:
            isPurchased = PersistenceManager.shared.hasSuperJump
            cost = Configuration.Shop.superJumpCost
            maxLevel = 1
            currentLevel = isPurchased ? 1 : 0
            isUnlockItem = true
            title.text = "Super Jump ⚡️"
            desc.text = "Double Jump Range + Invincible"
        case .rocketJump:
            isPurchased = PersistenceManager.shared.hasRocketJump
            cost = Configuration.Shop.rocketJumpCost
            maxLevel = 1
            currentLevel = isPurchased ? 1 : 0
            isUnlockItem = true
            title.text = "Rocket 🚀"
            desc.text = "Fly for 7 seconds"
        case .lifevestPack:
            let currentItems = PersistenceManager.shared.vestItems
            currentLevel = currentItems
            cost = Configuration.Shop.lifevest4PackCost
            maxLevel = -1 // Indicates no max level
            title.text = "Life Vest (4-Pack)"
            desc.text = "Get 4 Life Vests. You have: \(currentItems)"
        case .honeyPack:
            let currentItems = PersistenceManager.shared.honeyItems
            currentLevel = currentItems
            cost = Configuration.Shop.honey4PackCost
            maxLevel = -1 // Indicates no max level
            title.text = "Honey Jars (4-Pack)"
            desc.text = "Get 4 Honey Jars. You have: \(currentItems)"
        }
        
        let userCoins = PersistenceManager.shared.totalCoins
        
        // Style the card based on unlock status
        if isUnlockItem {
            if isPurchased {
                // Owned unlock items get a green border
                cardView.layer.borderColor = UIColor.systemGreen.cgColor
                cardView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
            } else {
                // Unpurchased unlock items get a purple/special border
                cardView.layer.borderColor = UIColor.systemPurple.cgColor
                cardView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.15)
            }
        }
        
        if isPurchased {
            costLabel.text = "OWNED"
            buyButton.isEnabled = false
            buyButton.backgroundColor = .gray
            buyButton.setTitle("OWNED", for: .normal)
        } else if !isUnlockItem && type != .logJumper && currentLevel >= maxLevel && maxLevel != -1 {
            costLabel.text = "MAXED"
            buyButton.isEnabled = false
            buyButton.backgroundColor = .gray
            buyButton.setTitle("MAXED", for: .normal)
        } else {
            costLabel.text = "\(cost) Coins"
            
            let buttonTitle: String
            switch type {
            case .lifevestPack, .honeyPack:
                buttonTitle = "BUY"
            case .logJumper, .superJump, .rocketJump:
                buttonTitle = isPurchased ? "OWNED" : "UNLOCK"
            default:
                buttonTitle = "UPGRADE"
            }
            buyButton.setTitle(buttonTitle, for: .normal)
            
            // Check affordability
            if userCoins < cost {
                buyButton.isEnabled = false
                buyButton.backgroundColor = UIColor.systemGray
                buyButton.setTitleColor(.lightGray, for: .disabled)
            }
        }
        
        buyButton.addAction(UIAction(handler: { [weak self] _ in
            self?.attemptPurchase(type: type, cost: cost)
        }), for: .touchUpInside)
        
        cardView.addSubview(title)
        cardView.addSubview(desc)
        cardView.addSubview(costLabel)
        cardView.addSubview(buyButton)
        
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 15),
            title.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            title.trailingAnchor.constraint(lessThanOrEqualTo: buyButton.leadingAnchor, constant: -10),
            
            desc.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 5),
            desc.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            desc.trailingAnchor.constraint(lessThanOrEqualTo: buyButton.leadingAnchor, constant: -10),
            
            costLabel.topAnchor.constraint(equalTo: desc.bottomAnchor, constant: 10),
            costLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 15),
            
            buyButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            buyButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -15),
            buyButton.widthAnchor.constraint(equalToConstant: 100),
            buyButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // NEW: Add badge for unlock items
        if isUnlockItem {
            let badge = createBadge(text: isPurchased ? "✓ UNLOCKED" : "🎁 UNLOCKS UPGRADE", isPurchased: isPurchased)
            cardView.addSubview(badge)
            
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
                badge.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -8)
            ])
        }
        
        return cardView
    }
    
    private func createBadge(text: String, isPurchased: Bool) -> UIView {
        let badge = UILabel()
        badge.text = text
        badge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = isPurchased ? UIColor.systemGreen : UIColor.systemPurple
        badge.layer.cornerRadius = 8
        badge.layer.masksToBounds = true
        badge.textAlignment = .center
        badge.translatesAutoresizingMaskIntoConstraints = false
        
        // Add padding
        badge.heightAnchor.constraint(equalToConstant: 18).isActive = true
        badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        
        // Custom padding via content insets simulation
        let container = UIView()
        container.backgroundColor = isPurchased ? UIColor.systemGreen : UIColor.systemPurple
        container.layer.cornerRadius = 10
        container.layer.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8)
        ])
        
        return container
    }
    
    private func createSectionHeader(title: String) -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 16, weight: .heavy)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let line = UIView()
        line.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        line.translatesAutoresizingMaskIntoConstraints = false
        
        header.addSubview(label)
        header.addSubview(line)
        
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 30),
            
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            
            line.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            line.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            line.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            line.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        return header
    }
    
    private func refreshData() {
        let coins = PersistenceManager.shared.totalCoins
        coinsLabel.text = "💰 Coins: \(coins)"
        
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Section: Permanent Upgrades
        stackView.addArrangedSubview(createSectionHeader(title: "PERMANENT UPGRADES"))
        stackView.addArrangedSubview(createItemView(type: .jump))
        stackView.addArrangedSubview(createItemView(type: .health))
        stackView.addArrangedSubview(createItemView(type: .logJumper))
        
        // Section: Upgrade Menu Unlocks
        stackView.addArrangedSubview(createSectionHeader(title: "UPGRADE MENU UNLOCKS"))
        stackView.addArrangedSubview(createItemView(type: .superJump))
        stackView.addArrangedSubview(createItemView(type: .rocketJump))
        
        // Section: Consumables
        stackView.addArrangedSubview(createSectionHeader(title: "CONSUMABLES"))
        stackView.addArrangedSubview(createItemView(type: .lifevestPack))
        stackView.addArrangedSubview(createItemView(type: .honeyPack))
    }
    
    private func attemptPurchase(type: UpgradeType, cost: Int) {
        if PersistenceManager.shared.spendCoins(cost) {
            HapticsManager.shared.playNotification(.success)
            SoundManager.shared.play("coin")
            
            switch type {
            case .jump: PersistenceManager.shared.upgradeJump()
            case .health: PersistenceManager.shared.upgradeHealth()
            case .logJumper: PersistenceManager.shared.unlockLogJumper()
            case .superJump: PersistenceManager.shared.unlockSuperJump()
            case .rocketJump: PersistenceManager.shared.unlockRocketJump()
            case .lifevestPack: PersistenceManager.shared.addVestItems(4)
            case .honeyPack: PersistenceManager.shared.addHoneyItems(4)
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
