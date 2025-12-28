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
    
    /// The player's current maximum health (number of hearts)
    var currentMaxHealth: Int = 1
    
    /// Set to true if the upgrade selection is for a race, to filter out certain items.
    var isForRace: Bool = false
    
    /// Set to true if this is for a daily challenge
    var isDailyChallenge: Bool = false
    
    /// The current daily challenge (if isDailyChallenge is true)
    var currentDailyChallenge: DailyChallenge?
    
    /// The distance traveled by the player, used to determine contextual upgrades.
    var distanceTraveled: Int = 0
    
    /// The current weather/climate in the game - used to filter upgrades
    var currentWeather: WeatherType = .sunny
    
    // Available Upgrades Pool
    private let baseOptions: [UpgradeOption] = [
        UpgradeOption(id: "HONEY", name: "Honey Jar", desc: "Block 1 bee Attack", icon: "", iconImage: "honeyPot", zone: .any),
        UpgradeOption(id: "BOOTS", name: "Rain Boots", desc: "No sliding for a rain season", icon: "", iconImage: "rainboots", zone: .mid),
        UpgradeOption(id: "HEART", name: "Heart Container", desc: "+1 Max HP & heal", icon: "", iconImage: "heart", zone: .any),
        UpgradeOption(id: "HEARTBOOST", name: "Heart Boost", desc: "Refill all hearts", icon: "", iconImage: "heartBoost", zone: .any),
        UpgradeOption(id: "VEST", name: "Life Vest", desc: "Float on water once)", icon: "", iconImage: "lifevest", zone: .any),
        UpgradeOption(id: "AXE", name: "Woodcutter's Axe", desc: "Chops down 1 log/cactus", icon: "",iconImage: "ax", zone: .late),
        UpgradeOption(id: "SWATTER", name: "Fly Swatter", desc: "Swats 1 dragonfly", icon: "",iconImage: "swatter", zone: .late),
        UpgradeOption(id: "CROSS", name: "Holy Cross", desc: "Repels 1 ghost", icon: "", iconImage: "cross", zone: .any)
    ]
    
    // Purchasable Upgrades (only appear if unlocked in shop)
    private let superJumpOption = UpgradeOption(id: "SUPERJUMP", name: "Super Jump", desc: "Double jump range + invincible", icon: "",iconImage: "lightning", zone: .any)
    private let rocketJumpOption = UpgradeOption(id: "ROCKET", name: "Rocket", desc: "Fly for 10s", icon: "", iconImage: "rocket", zone: .any)
    private let cannonBallOption = UpgradeOption(id: "CANNONBALL", name: "Cannon Ball", desc: "+1 Cannon jump", icon: "", iconImage: "bomb", zone: .any)
    
    // Rare Treasure Chest Upgrades (5% chance each)
    private let doubleSuperJumpTimeOption = UpgradeOption(id: "DOUBLESUPERJUMPTIME", name: "⚡️ Legendary Super Charge", desc: "2x Super Jump Time (Permanent!)", icon: "⚡️", iconImage: "lightning", zone: .any)
    private let doubleRocketTimeOption = UpgradeOption(id: "DOUBLEROCKETTIME", name: "🚀 Legendary Rocket Fuel", desc: "2x rocket time (Permanent!)", icon: "🚀", iconImage: "rocket", zone: .any)
    
    private var allOptions: [UpgradeOption] {
        let currentZone: UpgradeZone
        if distanceTraveled < 1000 {
            currentZone = .early
        } else if distanceTraveled < 1500 {
            currentZone = .mid
        } else {
            currentZone = .late
        }
        
        var options = baseOptions.filter {
            $0.zone == .any || $0.zone == currentZone
        }
        
        // Determine the effective weather to use for filtering
        let effectiveWeather: WeatherType
        if isDailyChallenge, let challenge = currentDailyChallenge {
            effectiveWeather = challenge.climate
        } else {
            effectiveWeather = currentWeather
        }
        
        // Filter upgrades based on game context (weather, enemies, obstacles)
        options = options.filter { option in
            return isUpgradeUsableInCurrentContext(option.id, weather: effectiveWeather)
        }
        
        // Filter upgrades for daily challenges based on challenge configuration
        if isDailyChallenge, let challenge = currentDailyChallenge {
            options = options.filter { option in
                isUpgradeRelevantForChallenge(option.id, challenge: challenge)
            }
        }
        
        // Don't offer heart boost if player already has full health
        if hasFullHealth {
            options.removeAll { $0.id == "HEARTBOOST" }
        }
        
        // Don't offer heart container if player already has 6 heart containers (max)
        if currentMaxHealth >= 6 {
            options.removeAll { $0.id == "HEART" }
        }
        
        // Note: Super Jump is NOT added to regular pool - it only appears via the 20% special chance in generateOptions()
        
        // Do not allow rockets as an initial upgrade for races or daily challenges
        // Rockets have a 10% chance to appear
        if PersistenceManager.shared.hasRocketJump && !isForRace && !isDailyChallenge {
            if Double.random(in: 0...1) < 0.10 {
                // Check if rockets are usable in current context
                if isUpgradeUsableInCurrentContext("ROCKET", weather: effectiveWeather) {
                    options.append(rocketJumpOption)
                }
            }
        }
        
        // Add rare upgrades if they haven't been unlocked yet
        // These have a 5% base chance to appear
        if !PersistenceManager.shared.hasDoubleSuperJumpTime && PersistenceManager.shared.hasSuperJump {
            // Only offer if super jump is unlocked
            if Double.random(in: 0...1) < 0.05 {
                // Check if usable in current context
                if isUpgradeUsableInCurrentContext("DOUBLESUPERJUMPTIME", weather: effectiveWeather) {
                    // Check daily challenge relevance
                    if !isDailyChallenge || (currentDailyChallenge != nil && isUpgradeRelevantForChallenge("DOUBLESUPERJUMPTIME", challenge: currentDailyChallenge!)) {
                        options.append(doubleSuperJumpTimeOption)
                    }
                }
            }
        }
        
        if !PersistenceManager.shared.hasDoubleRocketTime && PersistenceManager.shared.hasRocketJump {
            // Only offer if rocket jump is unlocked
            if Double.random(in: 0...1) < 0.05 {
                // Check if usable in current context
                if isUpgradeUsableInCurrentContext("DOUBLEROCKETTIME", weather: effectiveWeather) {
                    // Check daily challenge relevance
                    if !isDailyChallenge || (currentDailyChallenge != nil && isUpgradeRelevantForChallenge("DOUBLEROCKETTIME", challenge: currentDailyChallenge!)) {
                        options.append(doubleRocketTimeOption)
                    }
                }
            }
        }
        
        return options
    }
    
    // MARK: - UI Elements
    
    /// Checks if an upgrade can be used in the current game context (based on weather, enemies, obstacles)
    private func isUpgradeUsableInCurrentContext(_ upgradeID: String, weather: WeatherType) -> Bool {
        switch upgradeID {
        case "HONEY":
            // Honey blocks bees - bees don't spawn in desert
            return weather != .desert
            
        case "CROSS":
            // Cross repels ghosts - ghosts only appear at night
            return weather == .night
            
        case "SWATTER":
            // Swatter swats dragonflies - dragonflies don't spawn in desert
            return weather != .desert
            
        case "BOOTS":
            // Rain boots prevent sliding - only useful in rain or winter (or on ice pads in winter)
            return weather == .rain || weather == .winter
            
        case "AXE":
            // Axe chops logs/cacti
            // Logs spawn in: sunny, night, rain, winter (not desert or space)
            // Cacti spawn in: desert only
            // So the axe is useful in all weathers except space (where neither spawn)
            return weather != .space
            
        case "VEST", "HEART", "HEARTBOOST":
            // Universal health/survival items - always useful
            return true
            
        case "SUPERJUMP", "ROCKET", "CANNONBALL":
            // Movement/mobility upgrades - always useful
            return true
            
        case "DOUBLESUPERJUMPTIME", "DOUBLEROCKETTIME":
            // Permanent upgrades for purchased items - always useful if unlocked
            return true
            
        default:
            // Unknown upgrade - allow it by default
            return true
        }
    }
    
    /// Checks if an upgrade is relevant for a specific daily challenge
    /// This considers both the challenge's weather and its specific enemy/pad focus
    private func isUpgradeRelevantForChallenge(_ upgradeID: String, challenge: DailyChallenge) -> Bool {
        // First check if it's usable in the challenge's weather
        guard isUpgradeUsableInCurrentContext(upgradeID, weather: challenge.climate) else {
            return false
        }
        
        // Then check challenge-specific relevance
        switch upgradeID {
        case "HONEY":
            // Only relevant if bees can spawn
            return DailyChallenges.shared.shouldSpawnEnemyType(.bee, in: challenge)
            
        case "SWATTER":
            // Only relevant if dragonflies can spawn
            return DailyChallenges.shared.shouldSpawnEnemyType(.dragonfly, in: challenge)
            
        case "CROSS":
            // Only relevant if night climate (ghosts spawn at night)
            return challenge.climate == .night
            
        case "BOOTS":
            // Relevant if there's rain, winter, or ice pads
            return challenge.focusPadTypes.contains(.ice) || 
                   challenge.climate == .rain || 
                   challenge.climate == .winter
            
        case "AXE":
            // Relevant in any weather except space (logs spawn in natural weathers, cacti in desert)
            return challenge.climate != .space
            
        case "VEST", "HEART", "HEARTBOOST":
            // Universal - always relevant
            return true
            
        case "SUPERJUMP", "ROCKET", "CANNONBALL":
            // Movement upgrades - always relevant
            return true
            
        case "DOUBLESUPERJUMPTIME":
            // Only relevant if super jump is unlocked
            return PersistenceManager.shared.hasSuperJump
            
        case "DOUBLEROCKETTIME":
            // Only relevant if rocket jump is unlocked
            return PersistenceManager.shared.hasRocketJump
            
        default:
            // Unknown upgrade - allow it by default
            return true
        }
    }
    
    // MARK: - UI Elements
    private lazy var containerView: UIView = {
        let view = UIView()
        
        // Add upgradeBackground.png as the background
        if let backgroundImage = UIImage(named: "pauseBackdrop") {
            let imageView = UIImageView(image: backgroundImage)
            imageView.contentMode = .scaleToFill
            imageView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(imageView)
            view.sendSubviewToBack(imageView)
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: view.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        view.backgroundColor = .clear
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
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
            containerView.widthAnchor.constraint(equalToConstant: 360),
            containerView.heightAnchor.constraint(equalToConstant: 440),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 50),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            stackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 300),
            stackView.heightAnchor.constraint(equalToConstant: 220)
        ])
    }
    
    private func generateOptions() {
        let options = allOptions
        var option1: UpgradeOption
        var option2: UpgradeOption
        var chance1: Double = 0
        var chance2: Double = 0
        
        // Determine effective weather for filtering
        let effectiveWeather: WeatherType = isDailyChallenge && currentDailyChallenge != nil 
            ? currentDailyChallenge!.climate 
            : currentWeather
        
        // 20% chance to offer Super Jump if the player has Super Jump unlocked
        // But never offer during daily challenges
        var shouldOfferSuperJump = PersistenceManager.shared.hasSuperJump 
            && !isDailyChallenge
            && Double.random(in: 0...1) < 0.2
            && isUpgradeUsableInCurrentContext("SUPERJUMP", weather: effectiveWeather)
        
        // 20% chance to offer a Cannon Ball if the player has Cannon Jump unlocked
        // Cannon balls are allowed in daily challenges (unlike super jump and rockets)
        var shouldOfferCannonball = PersistenceManager.shared.hasCannonJump 
            && Double.random(in: 0...1) < 0.2
            && isUpgradeUsableInCurrentContext("CANNONBALL", weather: effectiveWeather)
        
        // Filter out cannonball if not relevant to daily challenge
        if isDailyChallenge, let challenge = currentDailyChallenge {
            shouldOfferCannonball = shouldOfferCannonball && isUpgradeRelevantForChallenge("CANNONBALL", challenge: challenge)
        }
        
        if shouldOfferSuperJump && shouldOfferCannonball {
            // Both special options triggered - offer both
            option1 = superJumpOption
            option2 = cannonBallOption
            
            chance1 = calculateChance(for: option1, inPool: options, specialOffered: true)
            chance2 = calculateChance(for: option2, inPool: options, specialOffered: true)
        } else if shouldOfferSuperJump {
            // Offer super jump and one regular option
            option1 = superJumpOption
            option2 = options.shuffled().first!
            
            chance1 = calculateChance(for: option1, inPool: options, specialOffered: true)
            chance2 = calculateChance(for: option2, inPool: options, specialOffered: true)
        } else if shouldOfferCannonball {
            // Offer cannonball and one regular option
            option1 = cannonBallOption
            option2 = options.shuffled().first!
            
            chance1 = calculateChance(for: option1, inPool: options, specialOffered: true)
            chance2 = calculateChance(for: option2, inPool: options, specialOffered: true)
        } else {
            // Pick 2 distinct random options
            let shuffled = options.shuffled()
            option1 = shuffled[0]
            option2 = shuffled[1]
            
            chance1 = calculateChance(for: option1, inPool: options, specialOffered: false)
            chance2 = calculateChance(for: option2, inPool: options, specialOffered: false)
        }
        
        let card1 = createCard(for: option1, chance: chance1)
        let card2 = createCard(for: option2, chance: chance2)
        
        // Randomize the order so special options aren't always on the left
        let cards = [card1, card2].shuffled()
        stackView.addArrangedSubview(cards[0])
        stackView.addArrangedSubview(cards[1])
    }
    
    /// Calculate the probability of seeing a specific upgrade option
    private func calculateChance(for option: UpgradeOption, inPool pool: [UpgradeOption], specialOffered: Bool) -> Double {
        let hasSuperJump = PersistenceManager.shared.hasSuperJump
        let hasCannonball = PersistenceManager.shared.hasCannonJump
        let superJumpChance = 0.2
        let cannonballChance = 0.2
        
        if option.id == "SUPERJUMP" {
            // Super Jump: 20% chance it's offered
            return superJumpChance * 1.0
        }
        
        if option.id == "CANNONBALL" {
            // Cannonball: 20% chance it's offered
            return cannonballChance * 1.0
        }
        
        // For regular options in the pool
        let poolSize = Double(pool.count)
        
        if specialOffered {
            // When a special option is offered (super jump or cannonball):
            // This option is the "other" choice
            return (hasSuperJump ? superJumpChance : 0.0) + (hasCannonball ? cannonballChance : 0.0)
        } else {
            // When no special options are offered:
            // Calculate the probability considering both special options could have appeared
            let noSpecialsChance = (1.0 - (hasSuperJump ? superJumpChance : 0.0)) * (1.0 - (hasCannonball ? cannonballChance : 0.0))
            let selectionChance = 2.0 / poolSize
            return noSpecialsChance * selectionChance
        }
    }
    
    private func createCard(for option: UpgradeOption, chance: Double) -> UIView {
        let button = UIButton(type: .custom)
        
        // Check if this is a rare upgrade
        let isRare = (option.id == "DOUBLESUPERJUMPTIME" || option.id == "DOUBLEROCKETTIME")
        
        // Use goldBadge.png for rare items, badge.png for regular items
        let badgeImageName = isRare ? "goldBadge" : "badge"
        if let badgeImage = UIImage(named: badgeImageName) {
            button.setBackgroundImage(badgeImage, for: .normal)
        }
        
        // Optional: Keep a subtle background color as fallback
        button.backgroundColor = .clear
        
        button.layer.cornerRadius = 15
        button.clipsToBounds = true
        
        // Use image if iconImage is provided, otherwise use emoji label
        let iconView: UIView
        if let imageName = option.iconImage, let image = UIImage(named: imageName) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 40).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 60).isActive = true
            iconView = imageView
        } else {
            let iconLabel = UILabel()
            iconLabel.text = option.icon
            iconLabel.font = UIFont.systemFont(ofSize: 20)
            iconLabel.textAlignment = .center
            iconView = iconLabel
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = option.name
        nameLabel.font = UIFont.systemFont(ofSize: isRare ? 14 : 16, weight: .bold)
        nameLabel.textColor = isRare ? .white : .yellow
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
        
        // Add percentage chance label
        let chanceLabel = UILabel()
        let percentage = Int(chance * 100)
        chanceLabel.text = "\(percentage)%"
        chanceLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        chanceLabel.textColor = isRare ? UIColor(red: 255/255, green: 215/255, blue: 0/255, alpha: 1) : UIColor(white: 0.7, alpha: 1.0)
        chanceLabel.textAlignment = .center
        chanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(iconView)
        button.addSubview(nameLabel)
        button.addSubview(descLabel)
        button.addSubview(chanceLabel)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: button.topAnchor, constant: 20),
            
            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 5),
            nameLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -5),
            
            descLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            descLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 10),
            descLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -5),
            
            chanceLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 5),
            chanceLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor)
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
