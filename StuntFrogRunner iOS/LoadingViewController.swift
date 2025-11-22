import UIKit

class LoadingViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - UI Elements
    
    private lazy var backgroundImageView: UIImageView = {
        // Loads "loadingScreen.png"
        let imageView = UIImageView(image: UIImage(named: "loadingScreen"))
        imageView.contentMode = .scaleAspectFill
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
        label.text = "STUNT FROG\nSUPERSTAR"
        label.numberOfLines = 2
        label.font = UIFont.systemFont(ofSize: 42, weight: .heavy)
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.loadingIndicator.stopAnimating()
            self?.coordinator?.didFinishLoading()
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
