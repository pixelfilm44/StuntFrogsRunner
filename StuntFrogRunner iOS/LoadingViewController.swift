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
        "menuScreen",
        "primaryButton",
        "secondaryButton",
        "waterSand",
        "toolTipBackdrop",
        
        // Frog Assets
        "frogSit",
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
        "frogDrown4",
        "frogDrown5",
        "frogDrown6",
        "frogRecoil",
        "rocketRide",
        "snake1",
        "snake2",
        "snake3",
        "snake4",
        "snake5",
        
        // Lilypad Assets
        "lilypadDay",
        "lilypadNight",
        "lilypadRain",
        "lilypadIce",
        "lilypadSnow",
        "lilypadGrave",
        "lilypadShrink",
        "lilypadWater",
        "lilypadWaterNight",
        "lilypadWaterRain",
        "lilypadWaterSnow",
        "lilypadWaterSand",
        
        // Object Assets
        "log",
        
        // Enemy Assets
        "bee",
        "dragonfly",
        "ghostFrog",
        
        // VFX Assets
        "spark",
        "firefly",
        "helpBackdrop"
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
        "treasure"
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
        label.text = "Loading Assets..."
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
            await updateStatus("Loading Assets...")
            
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
        let textures = visualAssets.map { SKTexture(imageNamed: $0) }
        
        // Use Swift's modern concurrency to await SpriteKit's preloading.
        await withCheckedContinuation { continuation in
            SKTexture.preload(textures) {
                continuation.resume()
            }
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
