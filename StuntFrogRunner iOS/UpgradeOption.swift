import UIKit

enum UpgradeZone {
    case any
    case early  // < 1000m
    case mid    // 1000m - 2000m
    case late   // > 2000m
}

struct UpgradeOption {
    let id: String
    let name: String
    let desc: String
    let icon: String
    let iconImage: String?  // Optional image name for custom icons
    let zone: UpgradeZone
    
    init(id: String, name: String, desc: String, icon: String, iconImage: String? = nil, zone: UpgradeZone) {
        self.id = id
        self.name = name
        self.desc = desc
        self.icon = icon
        self.iconImage = iconImage
        self.zone = zone
    }
}

class UpgradeViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    /// Set to true if the player currently has full health (currentHealth == maxHealth)
    var hasFullHealth: Bool = false
    
    /// Set to true if the upgrade selection is for a race, to filter out certain items.
    var isForRace: Bool = false
    
    /// The distance traveled by the player, used to determine contextual upgrades.
    var distanceTraveled: Int = 0
    
    // Available Upgrades Pool
    private let baseOptions: [UpgradeOption] = [
        UpgradeOption(id: "HONEY", name: "Honey Jar", desc: "Block 1 Bee Attack", icon: "", iconImage: "honeyPot", zone: .any),
        UpgradeOption(id: "BOOTS", name: "Rain Boots", desc: "No Sliding for a rain season", icon: "", iconImage: "rainboots", zone: .mid),
        UpgradeOption(id: "HEART", name: "Heart Container", desc: "+1 Max HP & Heal", icon: "", iconImage: "heart", zone: .any),
        UpgradeOption(id: "HEARTBOOST", name: "Heart Boost", desc: "Refill All Hearts", icon: "", iconImage: "heartBoost", zone: .any),
        UpgradeOption(id: "VEST", name: "Life Vest", desc: "Float on Water (1 Use)", icon: "", iconImage: "lifevest", zone: .any),
        UpgradeOption(id: "AXE", name: "Woodcutter's Axe", desc: "Chops down 1 Log", icon: "",iconImage: "ax", zone: .late),
        UpgradeOption(id: "SWATTER", name: "Fly Swatter", desc: "Swats 1 Dragonfly", icon: "",iconImage: "swatter", zone: .late),
        UpgradeOption(id: "CROSS", name: "Holy Cross", desc: "Repels 1 Ghost", icon: "", iconImage: "cross", zone: .mid)
    ]
    
    // Purchasable Upgrades (only appear if unlocked in shop)
    private let superJumpOption = UpgradeOption(id: "SUPERJUMP", name: "Super Jump", desc: "Double Jump Range + Invincible", icon: "",iconImage: "lightning", zone: .any)
    private let rocketJumpOption = UpgradeOption(id: "ROCKET", name: "Rocket", desc: "Fly for 7s", icon: "", iconImage: "rocket", zone: .any)
    private let cannonBallOption = UpgradeOption(id: "CANNONBALL", name: "Cannon Ball", desc: "+1 Cannon Jump", icon: "", iconImage: "bomb", zone: .any)
    
    private var allOptions: [UpgradeOption] {
        let currentZone: UpgradeZone
        if distanceTraveled < 1000 {
            currentZone = .early
        } else if distanceTraveled < 2000 {
            currentZone = .mid
        } else {
            currentZone = .late
        }
        
        var options = baseOptions.filter {
            $0.zone == .any || $0.zone == currentZone
        }
        
        // Don't offer heart boost if player already has full health
        if hasFullHealth {
            options.removeAll { $0.id == "HEARTBOOST" }
        }
        
        if PersistenceManager.shared.hasSuperJump {
            options.append(superJumpOption)
        }
        // Do not allow rockets as an initial upgrade for races
        if PersistenceManager.shared.hasRocketJump && !isForRace {
            options.append(rocketJumpOption)
        }
        return options
    }
    
    // MARK: - UI Elements
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "LEVEL UP!"
        label.font = UIFont(name: Configuration.Fonts.primaryBold, size: 40)
        label.textColor = .yellow
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose a Bonus"
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        generateOptions()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 320),
            containerView.heightAnchor.constraint(equalToConstant: 300),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 25),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            stackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 25),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.heightAnchor.constraint(equalToConstant: 160)
        ])
    }
    
    private func generateOptions() {
        let options = allOptions
        var option1: UpgradeOption
        var option2: UpgradeOption
        
        // 20% chance to offer a Cannon Ball if the player has Cannon Jump unlocked
        let shouldOfferCannonball = PersistenceManager.shared.hasCannonJump && Double.random(in: 0...1) < 0.2
        
        if shouldOfferCannonball {
            option1 = cannonBallOption
            // Get a second option from the main pool. Force unwrap is safe
            // because `allOptions` will have many items.
            option2 = options.shuffled().first!
        } else {
            // Pick 2 distinct random options
            let shuffled = options.shuffled()
            option1 = shuffled[0]
            option2 = shuffled[1]
        }
        
        let card1 = createCard(for: option1)
        let card2 = createCard(for: option2)
        
        // Randomize the order so the cannonball isn't always on the left
        let cards = [card1, card2].shuffled()
        stackView.addArrangedSubview(cards[0])
        stackView.addArrangedSubview(cards[1])
    }
    
    private func createCard(for option: UpgradeOption) -> UIView {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 52/255, green: 73/255, blue: 94/255, alpha: 1) // #34495e
        button.layer.cornerRadius = 15
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.yellow.cgColor
        
        // Use image if iconImage is provided, otherwise use emoji label
        let iconView: UIView
        if let imageName = option.iconImage, let image = UIImage(named: imageName) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 50).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 50).isActive = true
            iconView = imageView
        } else {
            let iconLabel = UILabel()
            iconLabel.text = option.icon
            iconLabel.font = UIFont.systemFont(ofSize: 40)
            iconLabel.textAlignment = .center
            iconView = iconLabel
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = option.name
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = .yellow
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descLabel = UILabel()
        descLabel.text = option.desc
        descLabel.font = UIFont.systemFont(ofSize: 12)
        descLabel.textColor = .white
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 3
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(iconView)
        button.addSubview(nameLabel)
        button.addSubview(descLabel)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: button.topAnchor, constant: 20),
            
            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 5),
            nameLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -5),
            
            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            descLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 5),
            descLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -5)
        ])
        
        button.addAction(UIAction(handler: { [weak self] _ in
            self?.selectOption(option.id)
        }), for: .touchUpInside)
        
        return button
    }
    
    private func selectOption(_ id: String) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        coordinator?.didSelectUpgrade(id)
    }
}
