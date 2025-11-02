//
//  LoadingViewController.swift
//  Stuntfrog Superstar
//
//  Loading screen displayed during app launch
//

import UIKit

class LoadingViewController: UIViewController {
    
    // MARK: - UI Elements
    private let backgroundImageView = UIImageView()
    private let logoImageView = UIImageView()
    private let loadingLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let spinnerView = UIActivityIndicatorView(style: .large)
    
    // MARK: - Properties
    private var loadingProgress: Float = 0.0
    private var loadingTimer: Timer?
    
    // Completion handler to call when loading is done
    var onLoadingComplete: (() -> Void)?
    
    // MARK: - Lifecycle
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🎬 LoadingViewController: Setting up loading screen")
        setupUI()
        startLoadingSequence()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.black
        
        // Background setup
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.backgroundColor = UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1.0) // Fallback color
        view.addSubview(backgroundImageView)
        
        // Logo setup
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.backgroundColor = UIColor.clear
        // Try to load app icon or create a placeholder
        setupLogo()
        view.addSubview(logoImageView)
        
        // Loading label setup
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "STUNTFROG SUPERSTAR"
        loadingLabel.textColor = .white
        loadingLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        loadingLabel.textAlignment = .center
        loadingLabel.alpha = 0.0
        view.addSubview(loadingLabel)
        
        // Progress view setup
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor.systemGreen
        progressView.trackTintColor = UIColor.darkGray
        progressView.layer.cornerRadius = 2
        progressView.alpha = 0.0
        view.addSubview(progressView)
        
        // Spinner setup
        spinnerView.translatesAutoresizingMaskIntoConstraints = false
        spinnerView.color = .white
        spinnerView.hidesWhenStopped = true
        view.addSubview(spinnerView)
        
        setupConstraints()
    }
    
    private func setupLogo() {
        // Try to use the app icon
        if let appIcon = UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon-60") {
            logoImageView.image = appIcon
        } else {
            // Create a simple placeholder logo
            let logoText = "🐸"
            let font = UIFont.systemFont(ofSize: 120)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.systemGreen
            ]
            
            let size = logoText.size(withAttributes: attributes)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                logoText.draw(at: .zero, withAttributes: attributes)
            }
            logoImageView.image = image
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Background fills entire view
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Logo centered horizontally, positioned in upper third
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // Loading label below logo
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Progress view in lower portion
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Spinner centered on screen initially
            spinnerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinnerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 50)
        ])
    }
    
    // MARK: - Loading Logic
    
    private func startLoadingSequence() {
        print("🎬 LoadingViewController: Starting loading sequence")
        
        // Start with spinner
        spinnerView.startAnimating()
        
        // Animate in the logo and title
        UIView.animate(withDuration: 1.0, delay: 0.5, options: .curveEaseOut) {
            self.logoImageView.alpha = 1.0
            self.loadingLabel.alpha = 1.0
        }
        
        // Show progress bar after a delay and start actual loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showProgressBar()
            self.startActualLoading()
        }
    }
    
    private func showProgressBar() {
        // Fade out spinner, fade in progress bar
        UIView.animate(withDuration: 0.5) {
            self.spinnerView.alpha = 0.0
            self.progressView.alpha = 1.0
        } completion: { _ in
            self.spinnerView.stopAnimating()
        }
    }
    
    private func startActualLoading() {
        print("🎬 LoadingViewController: Starting actual loading tasks")
        
        // Set up LoadingManager callbacks
        LoadingManager.shared.onProgressUpdate = { [weak self] progress, taskName in
            DispatchQueue.main.async {
                self?.progressView.setProgress(progress, animated: true)
                self?.updateLoadingText(taskName)
            }
        }
        
        LoadingManager.shared.onLoadingComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.completeLoading()
            }
        }
        
        // Start loading
        LoadingManager.shared.startLoading()
    }
    
    private func updateLoadingText(_ text: String) {
        UIView.transition(with: loadingLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.loadingLabel.text = text
        }
    }
    
    private func completeLoading() {
        print("✅ LoadingViewController: Loading complete, transitioning to game")
        
        // Animate out the loading screen
        UIView.animate(withDuration: 0.5, animations: {
            self.view.alpha = 0.0
        }) { _ in
            // Call completion handler
            self.onLoadingComplete?()
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        loadingTimer?.invalidate()
        loadingTimer = nil
        print("🗑 LoadingViewController: Deallocated")
    }
}