//
//  HelpViewController.swift
//  StuntFrogRunner iOS
//

import UIKit

struct HelpSlide {
    let title: String
    let description: String
    let imageName: String?
    let emoji: String
}

class HelpViewController: UIViewController {
    
    var onDismiss: (() -> Void)?
    
    private let slides: [HelpSlide] = [
        HelpSlide(
            title: "Welcome!",
            description: "You're a stunt frog superstar! Your goal is to run as far as you can while avoiding obstacles and collecting coins.",
            imageName: "stuntfrogProfile",
            emoji: ""
        ),
        HelpSlide(
            title: "Sling away",
            description: "Pull back on the frog to jump over obstacles and land on lilypads. Time your jumps carefully to avoid the water. This frog can't swim.",
            imageName: "point",
            emoji: ""
        ),
        HelpSlide(
            title: "Collect Coins",
            description: "Grab coins along the way to spend in the shop on upgrades and power-ups.",
            imageName: "star",
            emoji: ""
        ),
        HelpSlide(
            title: "Avoid Obstacles",
            description: "Watch out for logs, bees, dragonflies and other hazards. Each hit costs you health!",
            imageName: "bee",
            emoji: ""
        ),
        HelpSlide(
            title: "Upgrades & Challenges",
            description: "Visit the shop to upgrade your jump and health. Complete challenges for bonus rewards!",
            imageName: nil,
            emoji: "⬆️"
        )
    ]
    
    private var currentPage = 0
    
    // MARK: - UI Elements
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 30/255, green: 30/255, blue: 40/255, alpha: 1)
        view.layer.cornerRadius = 24
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor.white.cgColor
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("✕", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 231/255, green: 76/255, blue: 60/255, alpha: 1)
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        return button
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = slides.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.3)
        pageControl.currentPageIndicatorTintColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.addTarget(self, action: #selector(pageControlTapped), for: .valueChanged)
        return pageControl
    }()
    
    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("NEXT →", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1)
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleNext), for: .touchUpInside)
        return button
    }()
    
    private lazy var prevButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("← PREV", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 100/255, green: 100/255, blue: 110/255, alpha: 1)
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handlePrev), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSlides()
        updateNavigationButtons()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        view.addSubview(containerView)
        containerView.addSubview(closeButton)
        containerView.addSubview(scrollView)
        containerView.addSubview(pageControl)
        containerView.addSubview(prevButton)
        containerView.addSubview(nextButton)
        
        scrollView.addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            // Container - centered modal
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            
            // Close button - top right
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -10),
            
            // Content StackView inside ScrollView
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // Page Control
            pageControl.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: prevButton.topAnchor, constant: -15),
            
            // Navigation buttons
            prevButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            prevButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            prevButton.widthAnchor.constraint(equalToConstant: 100),
            prevButton.heightAnchor.constraint(equalToConstant: 40),
            
            nextButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            nextButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            nextButton.widthAnchor.constraint(equalToConstant: 100),
            nextButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupSlides() {
        for (index, slide) in slides.enumerated() {
            let slideView = createSlideView(for: slide, index: index)
            contentStackView.addArrangedSubview(slideView)
            slideView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        }
    }
    
    private func createSlideView(for slide: HelpSlide, index: Int) -> UIView {
        let slideContainer = UIView()
        slideContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Visual element - either an image or emoji
        let visualView: UIView
        if let imageName = slide.imageName, let image = UIImage(named: imageName) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            visualView = imageView
        } else {
            let emojiLabel = UILabel()
            emojiLabel.text = slide.emoji
            emojiLabel.font = UIFont.systemFont(ofSize: 72)
            emojiLabel.textAlignment = .center
            emojiLabel.translatesAutoresizingMaskIntoConstraints = false
            visualView = emojiLabel
        }
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = slide.title
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .heavy)
        titleLabel.textColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Description label
        let descriptionLabel = UILabel()
        descriptionLabel.text = slide.description
        descriptionLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        descriptionLabel.textColor = .white
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        slideContainer.addSubview(visualView)
        slideContainer.addSubview(titleLabel)
        slideContainer.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            visualView.centerXAnchor.constraint(equalTo: slideContainer.centerXAnchor),
            visualView.topAnchor.constraint(equalTo: slideContainer.topAnchor, constant: 20),
            visualView.heightAnchor.constraint(equalToConstant: 72),
            visualView.widthAnchor.constraint(lessThanOrEqualToConstant: 72),
            
            titleLabel.centerXAnchor.constraint(equalTo: slideContainer.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: visualView.bottomAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: slideContainer.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: slideContainer.trailingAnchor, constant: -20),
            
            descriptionLabel.centerXAnchor.constraint(equalTo: slideContainer.centerXAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            descriptionLabel.leadingAnchor.constraint(equalTo: slideContainer.leadingAnchor, constant: 25),
            descriptionLabel.trailingAnchor.constraint(equalTo: slideContainer.trailingAnchor, constant: -25)
        ])
        
        return slideContainer
    }
    
    private func updateNavigationButtons() {
        prevButton.isHidden = currentPage == 0
        
        if currentPage == slides.count - 1 {
            nextButton.setTitle("GOT IT!", for: .normal)
            nextButton.backgroundColor = UIColor(red: 241/255, green: 196/255, blue: 15/255, alpha: 1)
            nextButton.setTitleColor(UIColor(red: 211/255, green: 84/255, blue: 0/255, alpha: 1), for: .normal)
        } else {
            nextButton.setTitle("NEXT →", for: .normal)
            nextButton.backgroundColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1)
            nextButton.setTitleColor(.white, for: .normal)
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleClose() {
        HapticsManager.shared.playImpact(.light)
        dismiss(animated: true) {
            self.onDismiss?()
        }
    }
    
    @objc private func handleNext() {
        HapticsManager.shared.playImpact(.light)
        
        if currentPage == slides.count - 1 {
            // Last page - dismiss
            handleClose()
        } else {
            currentPage += 1
            scrollToPage(currentPage)
            pageControl.currentPage = currentPage
            updateNavigationButtons()
        }
    }
    
    @objc private func handlePrev() {
        HapticsManager.shared.playImpact(.light)
        
        if currentPage > 0 {
            currentPage -= 1
            scrollToPage(currentPage)
            pageControl.currentPage = currentPage
            updateNavigationButtons()
        }
    }
    
    @objc private func pageControlTapped() {
        scrollToPage(pageControl.currentPage)
        currentPage = pageControl.currentPage
        updateNavigationButtons()
    }
    
    private func scrollToPage(_ page: Int) {
        let offsetX = CGFloat(page) * scrollView.bounds.width
        scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
    }
}

// MARK: - UIScrollViewDelegate

extension HelpViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / scrollView.bounds.width)
        currentPage = page
        pageControl.currentPage = page
        updateNavigationButtons()
    }
}
