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
        
        // Frog Assets
        "frogSit",
        "frogLeap",
        "frogJump",
        "rocketRide",
        
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
        
        // Object Assets
        "log",
        
        // Enemy Assets
        "bee",
        "dragonfly",
        "ghostFrog",
        
        // VFX Assets
        "spark",
        "firefly"
    ]
    
    /// All audio assets to preload (sound effects)
    private let audioAssets: [String] = [
        "jump",
        "land",
        "coin",
        "hit",
        "splash"
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
        // Loads "loadingScreen.png"
        let imageView = UIImageView(image: UIImage(named: "loadingScreen"))
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black  // Fill letterbox areas with black
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading..."
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
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .lightGray
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
            // Update status
            await updateStatus("Loading textures...")
            
            // Preload visual assets using SpriteKit's texture preloading
            await preloadVisualAssets()
            
            // Update status
            await updateStatus("Loading sounds...")
            
            // Preload audio assets
            preloadAudioAssets()
            
            // Update status
            await updateStatus("Loading music...")
            
            // Preload music assets
            preloadMusicAssets()
            
            // Complete loading
            await updateStatus("Ready!")
            
            // Small delay to show "Ready!" status
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
        // Create SKTextures for all visual assets
        let textures = visualAssets.map { SKTexture(imageNamed: $0) }
        
        // Use SpriteKit's built-in texture preloading
        await withCheckedContinuation { continuation in
            SKTexture.preload(textures) {
                continuation.resume()
            }
        }
    }
    
    private func preloadAudioAssets() {
        // Preload sound effects through SoundManager
        SoundManager.shared.preloadSounds()
    }
    
    private func preloadMusicAssets() {
        // Preload music tracks by initializing AVAudioPlayers
        // This ensures the files are loaded into memory for faster playback
        for musicName in musicAssets {
            if let url = Bundle.main.url(forResource: musicName, withExtension: "mp3") {
                // Just verify the file exists and is accessible
                // The actual AVAudioPlayer will be created when music plays
                _ = try? Data(contentsOf: url, options: .mappedIfSafe)
            }
        }
    }
    
    private func setupUI() {
        // Add Background
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(loadingIndicator)
        containerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            // Background
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 300),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            loadingIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 15),
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
    }
}

