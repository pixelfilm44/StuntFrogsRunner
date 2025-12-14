//
//  ImageSegmentControl.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 12/13/25.
//


import UIKit

class ImageSegmentControl: UIStackView {
    
    // Define your buttons
    private let button1 = UIButton()
    private let button2 = UIButton()
    
    // Callback to handle changes
    var onSegmentChanged: ((Int) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.axis = .horizontal
        self.distribution = .fillEqually
        self.spacing = 20 // Custom spacing between your PNGs
        
        // Configure Button 1
        button1.setImage(UIImage(named: "icon1Off"), for: .normal)
        button1.setImage(UIImage(named: "icon1On"), for: .selected)
        button1.tag = 0
        button1.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        
        // Configure Button 2
        button2.setImage(UIImage(named: "icon2Off"), for: .normal)
        button2.setImage(UIImage(named: "icon2On"), for: .selected)
        button2.tag = 1
        button2.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        
        // Default selection
        button1.isSelected = true
        
        self.addArrangedSubview(button1)
        self.addArrangedSubview(button2)
    }
    
    @objc private func buttonTapped(_ sender: UIButton) {
        // Deselect all buttons
        self.arrangedSubviews.forEach { ($0 as? UIButton)?.isSelected = false }
        
        // Select the tapped one
        sender.isSelected = true
        
        // Trigger action
        onSegmentChanged?(sender.tag)
    }
}
