import UIKit

import UIKit

class ChallengesViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - UI Elements
    
    private lazy var backgroundView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "challengesBackdrop")
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "CHALLENGES"
        label.font = UIFont(name: Configuration.Fonts.primaryHeavy, size: 30)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["In Progress", "Completed"])
        control.selectedSegmentIndex = 0
        control.backgroundColor = .blue
        
        
        
        // Set divider image (use a 1x1 transparent image to hide it)
        let dividerImage = UIImage()
        control.setDividerImage(dividerImage, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.register(ChallengeCell.self, forCellReuseIdentifier: ChallengeCell.reuseIdentifier)
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.setTitle("BACK", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
      button.setBackgroundImage(UIImage(named: "secondaryButton"), for: .normal)

        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        return button
    }()
    
    private var displayedChallenges: [Challenge] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        refreshChallenges()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshChallenges()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.addSubview(backgroundView)
        view.addSubview(titleLabel)
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 40),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: backButton.topAnchor, constant: -20),
            
            backButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 150),
            backButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func segmentChanged() {
        refreshChallenges()
    }
    
    @objc private func handleBack() {
        HapticsManager.shared.playImpact(.light)
        coordinator?.showMenu(animated: true)
    }
    
    private func refreshChallenges() {
        if segmentedControl.selectedSegmentIndex == 0 {
            displayedChallenges = ChallengeManager.shared.inProgressChallenges
        } else {
            displayedChallenges = ChallengeManager.shared.completedChallenges
        }
        tableView.reloadData()
    }
    
    private func claimReward(for challenge: Challenge) {
        let success = ChallengeManager.shared.claimReward(for: challenge.id)
        if success {
            HapticsManager.shared.playNotification(.success)
            
            // Show reward feedback
            let alert = UIAlertController(
                title: "🎉 Reward Claimed!",
                message: "You received: \(challenge.reward.displayText)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Awesome!", style: .default))
            present(alert, animated: true)
            
            refreshChallenges()
        }
    }
}

// MARK: - UITableViewDataSource

extension ChallengesViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedChallenges.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ChallengeCell.reuseIdentifier, for: indexPath) as? ChallengeCell else {
            return UITableViewCell()
        }
        
        let challenge = displayedChallenges[indexPath.row]
        cell.configure(with: challenge)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ChallengesViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let challenge = displayedChallenges[indexPath.row]
        
        if challenge.isCompleted && !challenge.isRewardClaimed {
            claimReward(for: challenge)
        }
    }
}

// MARK: - Challenge Cell

class ChallengeCell: UITableViewCell {
    
    static let reuseIdentifier = "ChallengeCell"
    
    private let containerView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "itemBackdrop")
        imageView.contentMode = .scaleToFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont(name: Configuration.Fonts.cardHeader, size: 18)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.black.withAlphaComponent(0.7)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressBar: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.trackTintColor = UIColor.blue.withAlphaComponent(0.2)
        progress.progressTintColor = UIColor(red: 0/255, green: 100/255, blue: 0/255, alpha: 1)
        progress.layer.cornerRadius = 4
        progress.clipsToBounds = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.blue.withAlphaComponent(0.8)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let rewardLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor.orange
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let claimBadge: UILabel = {
        let label = UILabel()
        label.text = "TAP TO CLAIM!"
        label.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        label.textColor = .green
        label.backgroundColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1)
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(progressBar)
        containerView.addSubview(progressLabel)
        containerView.addSubview(rewardLabel)
        containerView.addSubview(claimBadge)
        
        // Add shadow to containerView
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.3
        containerView.layer.masksToBounds = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: claimBadge.leadingAnchor, constant: -8),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            progressBar.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 10),
            progressBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            progressBar.trailingAnchor.constraint(equalTo: progressLabel.leadingAnchor, constant: -8),
            progressBar.heightAnchor.constraint(equalToConstant: 8),
            
            progressLabel.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            progressLabel.widthAnchor.constraint(equalToConstant: 80),
            
            rewardLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 8),
            rewardLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            claimBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            claimBadge.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            claimBadge.widthAnchor.constraint(equalToConstant: 100),
            claimBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with challenge: Challenge) {
        titleLabel.text = challenge.title
        descriptionLabel.text = challenge.description
        progressBar.progress = Float(challenge.progressPercentage)
        progressLabel.text = challenge.progressText
        rewardLabel.text = "🎁 \(challenge.reward.displayText)"
        
        // Show claim badge for completed but unclaimed challenges
        claimBadge.isHidden = !(challenge.isCompleted && !challenge.isRewardClaimed)
        
        // Style based on completion state
        if challenge.isRewardClaimed {
            containerView.alpha = 0.7
            rewardLabel.text = "✅ Claimed"
        } else if challenge.isCompleted {
            containerView.alpha = 1.0
            
            // Pulse animation for claimable rewards
            UIView.animate(withDuration: 0.8, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.claimBadge.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            })
        } else {
            containerView.alpha = 1.0
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        claimBadge.layer.removeAllAnimations()
        claimBadge.transform = .identity
        containerView.alpha = 1.0
    }
}
