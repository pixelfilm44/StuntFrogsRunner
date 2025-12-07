//
//  PauseViewController.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 11/21/25.
//


import UIKit

class PauseViewController: UIViewController {
    
    weak var coordinator: GameCoordinator?
    
    // MARK: - UI Elements
    private lazy var containerView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "pauseBackdrop"))
        view.isUserInteractionEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "PAUSED"
        label.font = UIFont.systemFont(ofSize: 36, weight: .heavy)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var resumeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("RESUME", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.setBackgroundImage(UIImage(named: "primaryButton"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.widthAnchor.constraint(equalToConstant: 180).isActive = true
        button.addTarget(self, action: #selector(handleResume), for: .touchUpInside)
        return button
    }()
    
    private lazy var menuButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("QUIT TO MENU", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.setBackgroundImage(UIImage(named: "secondaryButton"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.widthAnchor.constraint(equalToConstant: 180).isActive = true
        button.addTarget(self, action: #selector(handleMenu), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(resumeButton)
        containerView.addSubview(menuButton)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),
            containerView.heightAnchor.constraint(equalToConstant: 250),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            resumeButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            resumeButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            menuButton.topAnchor.constraint(equalTo: resumeButton.bottomAnchor, constant: 15),
            menuButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func handleResume() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        dismiss(animated: false) {
            self.coordinator?.didRequestResume()
        }
    }
    
    @objc private func handleMenu() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        dismiss(animated: false) {
            self.coordinator?.showMenu()
        }
    }
}
