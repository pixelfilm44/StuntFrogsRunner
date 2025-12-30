import UIKit

class ShopViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - UI Elements
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "storeBackdrop")
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "FROG SHOP"
    
        label.font = UIFont(name: Configuration.Fonts.primaryHeavy, size: 30)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var coinIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "star")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var coinsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .yellow
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Add shadow
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 2)
        label.layer.shadowOpacity = 0.6
        label.layer.shadowRadius = 3
        
        return label
    }()
    
    private lazy var coinsStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [coinIconImageView, coinsLabel])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
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
        button.setBackgroundImage(UIImage(named: "secondaryButton"), for: .normal)

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
        
        containerView.addSubview(backgroundImageView)
        backgroundImageView.frame = containerView.bounds
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        containerView.addSubview(headerLabel)
        containerView.addSubview(coinsStackView)
        containerView.addSubview(scrollView)
        containerView.addSubview(backButton)
        
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            coinsStackView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            coinsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            coinIconImageView.widthAnchor.constraint(equalToConstant: 24),
            coinIconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // Scroll View - between coins label and back button
            scrollView.topAnchor.constraint(equalTo: coinsStackView.bottomAnchor, constant: 20),
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
    
    enum UpgradeType { case jump, health, logJumper, superJump, rocketJump, lifevestPack, honeyPack, cannonJump, crossPack, swatterPack, axePack }
    
    private func createItemView(type: UpgradeType) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .clear
        cardView.clipsToBounds = false
        cardView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        // Add shadow
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowOpacity = 0.3
        cardView.layer.shadowRadius = 6
        
        // Add background image
        let backgroundImageView = UIImageView()
        backgroundImageView.image = UIImage(named: "itemBackdrop")
        backgroundImageView.contentMode = .scaleToFill
        backgroundImageView.clipsToBounds = true
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(backgroundImageView)
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: cardView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])
        
        let title = UILabel()
       
        title.font = UIFont(name: Configuration.Fonts.cardHeader, size: 18)
        title.textColor = .black
        title.translatesAutoresizingMaskIntoConstraints = false
        
        let desc = UILabel()
        desc.font = UIFont.systemFont(ofSize: 14)
        desc.textColor = .black
        desc.numberOfLines = 2
        desc.translatesAutoresizingMaskIntoConstraints = false
        
        let costLabel = UILabel()
        costLabel.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        costLabel.textColor = .yellow
        costLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let buyButton = UIButton(type: .custom)
        buyButton.setBackgroundImage(UIImage(named: "primaryButton"), for: .normal)
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
            desc.text = "Land on logs safely!"
        case .cannonJump:
            isPurchased = PersistenceManager.shared.hasCannonJump
            cost = Configuration.Shop.cannonJumpCost
            maxLevel = 1
            currentLevel = isPurchased ? 1 : 0
            title.text = "Cannon Jump"
            desc.text = "Act as a cannon ball +3 times per run/race!"
            
        case .superJump:
            isPurchased = PersistenceManager.shared.hasSuperJump
            cost = Configuration.Shop.superJumpCost
            maxLevel = 1
            currentLevel = isPurchased ? 1 : 0
            isUnlockItem = true
            title.text = "Super Jump ⚡️"
            desc.text = "Double jump range + invincible"
        case .rocketJump:
            isPurchased = PersistenceManager.shared.hasRocketJump
            cost = Configuration.Shop.rocketJumpCost
            maxLevel = 1
            currentLevel = isPurchased ? 1 : 0
            isUnlockItem = true
            title.text = "Rocket 🚀"
            desc.text = "Fly for 10 seconds"
        case .lifevestPack:
            let currentItems = PersistenceManager.shared.vestItems
            currentLevel = currentItems
            cost = Configuration.Shop.lifevest4PackCost
            maxLevel = -1 // Indicates no max level
            title.text = "Life Vest (4-Pack)"
            desc.text = "Get a life vest pack. You have: \(currentItems)"
        case .honeyPack:
            let currentItems = PersistenceManager.shared.honeyItems
            currentLevel = currentItems
            cost = Configuration.Shop.honey4PackCost
            maxLevel = -1 // Indicates no max level
            title.text = "Honey Jars (4-Pack)"
            desc.text = "Get a honey jar pack. You have: \(currentItems)"
        case .crossPack:
            let currentItems = PersistenceManager.shared.crossItems
            currentLevel = currentItems
            cost = Configuration.Shop.cross4PackCost
            maxLevel = -1 // Indicates no max level
            title.text = "Crosses (4-Pack)"
            desc.text = "Protect against snakes. You have: \(currentItems)"
        case .swatterPack:
            let currentItems = PersistenceManager.shared.swatterItems
            currentLevel = currentItems
            cost = Configuration.Shop.swatter4PackCost
            maxLevel = -1 // Indicates no max level
            title.text = "Dragonfly Swatters (4-Pack)"
            desc.text = "Swat away dragonflies. You have: \(currentItems)"
        case .axePack:
            let currentItems = PersistenceManager.shared.axeItems
            currentLevel = currentItems
            cost = Configuration.Shop.axe4PackCost
            maxLevel = -1 // Indicates no max level
            title.text = "Axes (4-Pack)"
            desc.text = "Chop through logs/cactus/snakes. You have: \(currentItems)"
        }
        
        let userCoins = PersistenceManager.shared.totalCoins
        
        // Note: Special styling removed - now using itemBackdrop.png for all items
        
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
            case .lifevestPack, .honeyPack, .crossPack, .swatterPack, .axePack:
                buttonTitle = "BUY"
            case .logJumper, .superJump, .rocketJump, .cannonJump:
                buttonTitle = isPurchased ? "OWNED" : "UNLOCK"
            default:
                buttonTitle = "UPGRADE"
            }
            buyButton.setTitle(buttonTitle, for: .normal)
            
            // Check affordability
            if userCoins < cost {
                buyButton.isEnabled = false
                buyButton.backgroundColor = UIColor.systemGray
                buyButton.setTitleColor(.darkGray, for: .disabled)
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
            title.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            title.trailingAnchor.constraint(lessThanOrEqualTo: buyButton.leadingAnchor, constant: -10),
            
            desc.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 5),
            desc.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            desc.trailingAnchor.constraint(lessThanOrEqualTo: buyButton.leadingAnchor, constant: -10),
            
            costLabel.topAnchor.constraint(equalTo: desc.bottomAnchor, constant: 10),
            costLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 32),
            
            buyButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            buyButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -32),
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
        badge.textColor = .black
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
        label.textColor = .black
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
        label.textColor = UIColor.black.withAlphaComponent(0.7)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let line = UIView()
        line.backgroundColor = UIColor.black.withAlphaComponent(0.3)
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
        coinsLabel.text = "\(coins)"
        
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Section: Permanent Upgrades
        stackView.addArrangedSubview(createSectionHeader(title: "PERMANENT UPGRADES"))
        stackView.addArrangedSubview(createItemView(type: .jump))
        stackView.addArrangedSubview(createItemView(type: .health))
        stackView.addArrangedSubview(createItemView(type: .logJumper))
        stackView.addArrangedSubview(createItemView(type: .cannonJump))
        
        // Section: Upgrade Menu Unlocks
        stackView.addArrangedSubview(createSectionHeader(title: "UPGRADE MENU UNLOCKS"))
        stackView.addArrangedSubview(createItemView(type: .superJump))
        stackView.addArrangedSubview(createItemView(type: .rocketJump))
        
        // Section: Consumables
        stackView.addArrangedSubview(createSectionHeader(title: "CONSUMABLES"))
        stackView.addArrangedSubview(createItemView(type: .lifevestPack))
        stackView.addArrangedSubview(createItemView(type: .honeyPack))
        stackView.addArrangedSubview(createItemView(type: .crossPack))
        stackView.addArrangedSubview(createItemView(type: .swatterPack))
        stackView.addArrangedSubview(createItemView(type: .axePack))
    }
    
    private func attemptPurchase(type: UpgradeType, cost: Int) {
        if PersistenceManager.shared.spendCoins(cost) {
            HapticsManager.shared.playNotification(.success)
            SoundManager.shared.play("coin")
            
            // Track if this is a 4-pack item and check if user already has items before purchase
            var shouldShow4PackTooltip = false
            
            switch type {
            case .jump: PersistenceManager.shared.upgradeJump()
            case .health: PersistenceManager.shared.upgradeHealth()
            case .logJumper: PersistenceManager.shared.unlockLogJumper()
            case .superJump: PersistenceManager.shared.unlockSuperJump()
            case .rocketJump: PersistenceManager.shared.unlockRocketJump()
            case .lifevestPack:
                // Check if they already have 4+ items (buying second 4-pack)
                if PersistenceManager.shared.vestItems >= 4 {
                    shouldShow4PackTooltip = true
                }
                PersistenceManager.shared.addVestItems(4)
            case .honeyPack:
                // Check if they already have 4+ items (buying second 4-pack)
                if PersistenceManager.shared.honeyItems >= 4 {
                    shouldShow4PackTooltip = true
                }
                PersistenceManager.shared.addHoneyItems(4)
            case .cannonJump: PersistenceManager.shared.unlockCannonJump()
            case .crossPack:
                // Check if they already have 4+ items (buying second 4-pack)
                if PersistenceManager.shared.crossItems >= 4 {
                    shouldShow4PackTooltip = true
                }
                PersistenceManager.shared.addCrossItems(4)
            case .swatterPack:
                // Check if they already have 4+ items (buying second 4-pack)
                if PersistenceManager.shared.swatterItems >= 4 {
                    shouldShow4PackTooltip = true
                }
                PersistenceManager.shared.addSwatterItems(4)
            case .axePack:
                // Check if they already have 4+ items (buying second 4-pack)
                if PersistenceManager.shared.axeItems >= 4 {
                    shouldShow4PackTooltip = true
                }
                PersistenceManager.shared.addAxeItems(4)
            }
            
            refreshData()
            
            // Show tooltip if user is buying their second or subsequent 4-pack
            if shouldShow4PackTooltip {
                show4PackMultipleTooltipIfNeeded()
            }
        } else {
            HapticsManager.shared.playNotification(.error)
        }
    }
    
    /// Shows a tooltip explaining the 4-pack usage limit (once per run) on first purchase
    private func show4PackTooltipIfNeeded() {
        let tooltipKey = "shop_4pack_explanation"
        let defaultsKey = "tooltip_shown_\(tooltipKey)"
        
        // Only show once ever
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }
        
        // Mark as shown
        UserDefaults.standard.set(true, forKey: defaultsKey)
        
        // Show an alert explaining 4-pack usage
        let alert = UIAlertController(
            title: "",
            message: "I can only carry 1 4 pack per run. Others will be saved for later.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            HapticsManager.shared.playImpact(.light)
        }
        alert.addAction(okAction)
        
        present(alert, animated: true)
    }
    
    /// Shows a tooltip when user buys multiple 4-packs, explaining they can only carry one at a time
    private func show4PackMultipleTooltipIfNeeded() {
        let tooltipKey = "shop_4pack_multiple"
        let defaultsKey = "tooltip_shown_\(tooltipKey)"
        
        // Only show once ever
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }
        
        // Mark as shown
        UserDefaults.standard.set(true, forKey: defaultsKey)
        
        // Show an alert explaining carrying limit
        let alert = UIAlertController(
            title: "",
            message: "I can only carry 1 4 pack of an item at a time.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            HapticsManager.shared.playImpact(.light)
        }
        alert.addAction(okAction)
        
        present(alert, animated: true)
    }
    
    /// Displays a modal tooltip explaining 4-pack usage rules
    
    @objc private func handleBack() {
        HapticsManager.shared.playImpact(.light)
        coordinator?.showMenu()
    }
}
