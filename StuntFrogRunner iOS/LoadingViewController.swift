import UIKit
import SpriteKit

class LoadingViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - Asset Lists
    
    /// All visual assets to preload
    private let visualAssets: [String] = [
        // UI Assets
        "loadingScreen",
        "star",
        "heart",
        "water",
        "waterNight",
        "waterSand",
        "waterSpace",
        "menuScreen",
        "backdrop",
        "StuntFrogTitle",
        "primaryButton",
        "secondaryButton",
        "shoppingButton",
        "leadersButton",
        "challengesButton",
        "helpButton",
        "supportButton",
        "closeButton",
        "toolTipBackdrop",
        "helpBackdrop",
        "storeBackdrop",
        "pauseBackdrop",
        "itemBackdrop",
        "badge",
        "goldBadge",
        
        // Frog Assets
        "frogSit",
        "frogSitLv",
        "frogJump1",
        "frogJump2",
        "frogJump3",
        "frogJump4",
        "frogJump5",
        "frogJump6",
        "frogJumpLv1",
        "frogJumpLv2",
        "frogJumpLv3",
        "frogJumpLv4",
        "frogJumpLv5",
        "frogJumpLv6",
        "frogDrown1",
        "frogDrown2",
        "frogDrown3",
        "frogRecoil",
        "cannon",
        
        // Frog Jump Variants (Cool, Wild, Extreme)
        "frogJumpCool1",
        "frogJumpCool2",
        "frogJumpCool3",
        "frogJumpCool4",
        "frogJumpCool5",
        "frogJumpCool6",
        "frogJumpCoolLv1",
        "frogJumpCoolLv2",
        "frogJumpCoolLv3",
        "frogJumpCoolLv4",
        "frogJumpCoolLv5",
        "frogJumpCoolLv6",
        "frogJumpWild1",
        "frogJumpWild2",
        "frogJumpWild3",
        "frogJumpWild4",
        "frogJumpWild5",
        "frogJumpWild6",
        "frogJumpWildLv1",
        "frogJumpWildLv2",
        "frogJumpWildLv3",
        "frogJumpWildLv4",
        "frogJumpWildLv5",
        "frogJumpWildLv6",
        "frogJumpExtreme1",
        "frogJumpExtreme2",
        "frogJumpExtreme3",
        "frogJumpExtreme4",
        "frogJumpExtreme5",
        "frogJumpExtreme6",
        "frogJumpExtremeLv1",
        "frogJumpExtremeLv2",
        "frogJumpExtremeLv3",
        "frogJumpExtremeLv4",
        "frogJumpExtremeLv5",
        "frogJumpExtremeLv6",
        
        // Frog Eat Animation
        "frogEat1",
        "frogEat2",
        "frogEat3",
        "frogEat4",
        "frogEat5",
        "frogLvEat1",
        "frogLvEat2",
        "frogLvEat3",
        "frogLvEat4",
        "frogLvEat5",
        
        // Rocket Animations
        "rocketRide1",
        "rocketRide2",
        "rocketRide3",
        "rocketRide4",
        "rocketRide5",
        "rocketExplode1",
        "rocketExplode2",
        "rocketExplode3",
        "rocketExplode4",
        "rocketExplode5",
        "rocketExplode6",
        
        // Frog Fall Animation (8 frames)
        "frogFall1",
        "frogFall2",
        "frogFall3",
        "frogFall4",
        "frogFall5",
        "frogFall6",
        "frogFall7",
        "frogFall8",
        "frogLvFall1",
        "frogLvFall2",
        "frogLvFall3",
        "frogLvFall4",
        "frogLvFall5",
        "frogLvFall6",
        "frogLvFall7",
        "frogLvFall8",
        
        // Snake Animation Assets - Sunny
        "snake1",
        "snake2",
        "snake3",
        "snake4",
        "snake5",
        
        // Snake Animation Assets - Night
        "snakeNight1",
        "snakeNight2",
        "snakeNight3",
        "snakeNight4",
        "snakeNight5",
        
        // Snake Animation Assets - Rain
        "snakeRain1",
        "snakeRain2",
        "snakeRain3",
        "snakeRain4",
        "snakeRain5",
        
        // Snake Animation Assets - Winter
        "snakeWinter1",
        "snakeWinter2",
        "snakeWinter3",
        "snakeWinter4",
        "snakeWinter5",
        
        // Snake Animation Assets - Desert
        "snakeDesert1",
        "snakeDesert2",
        "snakeDesert3",
        "snakeDesert4",
        "snakeDesert5",
        
        // Snake Animation Assets - Space
        "snakeSpace1",
        "snakeSpace2",
        "snakeSpace3",
        "snakeSpace4",
        "snakeSpace5",
        
        // Lilypad Assets - Standard
        "lilypadDay",
        "lilypadNight",
        "lilypadRain",
        "lilypadIce",
        "lilypadSnow",
        "lilypadDesert",
        "lilypadSpace",
        "launchPad",
        "lilypadGrave",
        
        // Lilypad Assets - Shrinking
        "lilypadShrink",
        "lilypadShrinkNight",
        "lilypadShrinkRain",
        "lilypadShrinkSnow",
        "lilypadShrinkSand",
        "lilypadShrinkSpace",
        
        // Lilypad Assets - Water Lily
        "lilypadWater",
        "lilypadWaterNight",
        "lilypadWaterRain",
        "lilypadWaterSnow",
        "lilypadWaterSand",
        "lilypadWaterSpace",
        
        // Lilypad Decoration
        "plantLeft",
        "plantRight",
        
        // Log Assets
        "log",
        "logNight",
        "logRain",
        "logWinter",
        "logDesert",
        "logSpace",
        
        // Enemy Assets - Bee
        "bee",
        "beeNight",
        "beeRain",
        "beeWinter",
        "beeDesert",
        "beeSpace",
        
        // Enemy Assets - Dragonfly
        "dragonfly",
        "dragonflyNight",
        "dragonflyRain",
        "dragonflyWinter",
        "dragonflyDesert",
        "asteroid",
        
        // Enemy Assets - Other
        "ghostFrog",
        
        // Crocodile Assets
        "crocodile",
        "crocodile1",
        "crocodile2",
        "crocodile3",
        "crocodile4",
        "crocodile5",
        
        // Cactus Assets
        "cactus",
        "cactusDesert",
        
        // Treasure and Collectibles
        "treasureChest",
        
        // Flotsam (Debris)
        "bottle",
        "boot",
        "twig",
        
        // VFX and Particle Assets
        "spark",
        "firefly",
        "smokeParticle",
        "particle"
    ]
    
    /// All audio assets to preload (sound effects)
    private let audioAssets: [String] = [
        "jump",
        "land",
        "coin",
        "hit",
        "splash",
        "swat",
        "chop",
        "treasure",
        "explosion"
    ]
    
    /// All music assets to preload
    private let musicAssets: [String] = [
        "menu_music",
        "day_music",
        "night_music",
        "rain_music",
        "winter_music"
        
    ]
    
    // MARK: - UI Elements
    
    private lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "loadingScreen"))
        imageView.contentMode = .scaleAspectFill // Fills the entire screen
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.numberOfLines = 2
        label.font = UIFont(name: "Fredoka-Bold", size: 44)
        label.textColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1)
        label.textAlignment = .center
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 3, height: 3)
        label.layer.shadowOpacity = 1.0
        label.layer.shadowRadius = 0.0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Looking for our hero..."
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .black
        // Shadow for readability
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 1, height: 1)
        label.layer.shadowOpacity = 1.0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        loadingIndicator.startAnimating()
        preloadAllAssets()
    }
    
    // MARK: - Asset Preloading
    
    private func preloadAllAssets() {
        Task {
            // Update status once at the beginning
            await updateStatus("Looking for our hero...")
            
            // Preload all asset types concurrently for a significant speed boost.
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.preloadVisualAssets()
                }
                
                group.addTask {
                    await self.preloadAudioAssets()
                }
                
                group.addTask {
                    await self.preloadMusicAssets()
                }
            }
            
            // All assets are now loaded.
            await updateStatus("Ready!")
            
            // Small delay to show "Ready!" status before transitioning.
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            await MainActor.run {
                loadingIndicator.stopAnimating()
                coordinator?.didFinishLoading()
            }
        }
    }
    
    @MainActor
    private func updateStatus(_ text: String) {
        statusLabel.text = text
    }
    
    private func preloadVisualAssets() async {
        // CRITICAL FIX: Process textures SEQUENTIALLY to avoid concurrent modification
        // of SpriteKit's internal collections during enumeration
        let batchSize = 20
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                // Process batches sequentially instead of concurrently
                self.preloadBatchSequentially(startIndex: 0, batchSize: batchSize) {
                    continuation.resume()
                }
            }
        }
    }
    
    /// Recursively preloads texture batches one at a time to avoid race conditions
    private func preloadBatchSequentially(startIndex: Int, batchSize: Int, completion: @escaping () -> Void) {
        // Base case: all batches processed
        guard startIndex < visualAssets.count else {
            completion()
            return
        }
        
        // Process current batch
        let endIndex = min(startIndex + batchSize, visualAssets.count)
        let batchAssets = Array(visualAssets[startIndex..<endIndex])
        
        // SAFETY: Filter out any textures that don't exist to avoid crashes
        // This prevents issues if an asset is missing or named incorrectly
        let textures = batchAssets.compactMap { assetName -> SKTexture? in
            // Check if the image exists before creating a texture
            if UIImage(named: assetName) != nil {
                return SKTexture(imageNamed: assetName)
            } else {
                print("⚠️ Warning: Missing texture asset: \(assetName)")
                return nil
            }
        }
        
        // Skip this batch if no valid textures
        guard !textures.isEmpty else {
            // Move to next batch
            self.preloadBatchSequentially(
                startIndex: startIndex + batchSize,
                batchSize: batchSize,
                completion: completion
            )
            return
        }
        
        // Preload this batch, then move to next batch
        SKTexture.preload(textures) { [weak self] in
            guard let self = self else {
                completion()
                return
            }
            
            // Recursively process next batch
            self.preloadBatchSequentially(
                startIndex: startIndex + batchSize,
                batchSize: batchSize,
                completion: completion
            )
        }
    }
    
    private func preloadAudioAssets() async {
        // This is a synchronous operation, but running it inside a `Task`
        // in the `TaskGroup` prevents it from blocking the main thread.
        SoundManager.shared.preloadSounds()
    }
    
    private func preloadMusicAssets() async {
        // Preloading music by touching the file data is I/O-bound.
        // Running this inside a `Task` is ideal.
        for musicName in musicAssets {
            if let url = Bundle.main.url(forResource: musicName, withExtension: "mp3") {
                // Just verify the file exists and is accessible.
                _ = try? Data(contentsOf: url, options: .mappedIfSafe)
            }
        }
    }
    
    private func setupUI() {
        // Add Background
        view.addSubview(backgroundImageView)
        
        // Use a UIStackView for simpler, more adaptive layout.
        let stackView = UIStackView(arrangedSubviews: [titleLabel, loadingIndicator, statusLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set specific spacing between the title and the loading indicator.
        stackView.setCustomSpacing(50, after: titleLabel)
        
        view.addSubview(stackView)
        
        // Adapt font sizes for different device types (iPhone vs. iPad).
        let titleFontSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 64 : 44
        let statusFontSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 20 : 14
        
        titleLabel.font = UIFont(name: "Fredoka-Bold", size: titleFontSize)
        statusLabel.font = UIFont.systemFont(ofSize: statusFontSize, weight: .medium)
        
        NSLayoutConstraint.activate([
            // Background should fill the view
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Center the stack view vertically and horizontally.
            stackView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            // Ensure stack view doesn't exceed the width of the screen.
            stackView.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.9)
        ])
    }
}
