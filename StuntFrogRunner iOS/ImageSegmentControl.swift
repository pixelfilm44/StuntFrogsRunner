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
        var config1 = UIButton.Configuration.plain()
        config1.image = UIImage(named: "icon1Off")?.resized(toScale: 0.3)
        button1.configuration = config1
        button1.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.image = button.isSelected ? 
                UIImage(named: "icon1On")?.resized(toScale: 0.3) :
                UIImage(named: "icon1Off")?.resized(toScale: 0.3)
            button.configuration = config
        }
        button1.tag = 0
        button1.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        
        // Configure Button 2
        var config2 = UIButton.Configuration.plain()
        config2.image = UIImage(named: "icon2Off")?.resized(toScale: 0.3)
        button2.configuration = config2
        button2.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.image = button.isSelected ? 
                UIImage(named: "icon2On")?.resized(toScale: 0.3) :
                UIImage(named: "icon2Off")?.resized(toScale: 0.3)
            button.configuration = config
        }
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
extension UIImage {
    func resized(toScale scale: CGFloat) -> UIImage? {
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

