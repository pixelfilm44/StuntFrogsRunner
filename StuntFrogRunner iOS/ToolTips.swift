import SpriteKit

/// Manages the creation and display of tooltips that provide contextual help to the player.
public class ToolTips {

    /// A private dictionary to store the content for different tooltips.
    /// You can add all your game's tooltips here.
    private static var toolTipContent: [String: (title: String, message: String)] = [
        "welcome": (
            title: "Welcome!",
            message: "This is a sample tooltip. You can put instructions or helpful information here for the player."
        ),
        "first_powerup": (
            title: "Power-up!",
            message: "You've collected your first power-up. These will help you on your journey."
        ),
        "desert": (
            title: "Welcome to the desert!",
            message: "Don't fall inbetween pillars here. You will not survive."
        ),
        "rain": (
            title: "Don't slip in the rain.",
            message: "The lilypads are slippery now."
        ),
        "race": (
            title: "It's frog vs. boat.",
            message: "Try to keep up and survive."
        ),
        "heartOverload": (
            title: "You love too much.",
            message: "Sorry, but you can only have 6 hearts."
        )
        
        // Add more tooltips here with a unique key.
    ]

    /// Creates and displays a tooltip in the center of the scene, but only if the user hasn't seen it before.
    ///
    /// This method will pause the scene while the tooltip is visible. The game will resume
    /// when the player taps the "OK" button. Once a tooltip is shown, it's marked as "seen"
    /// and won't be shown again for that user.
    ///
    /// - Parameters:
    ///   - key: The key for the tooltip content to display, as defined in the `toolTipContent` dictionary.
    ///   - scene: The `SKScene` in which to display the tooltip.
    public static func showToolTip(forKey key: String, in scene: SKScene) {
        let defaultsKey = "tooltip_shown_\(key)"
        // Check if this tooltip has already been shown. If so, do nothing.
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else {
            return
        }

        guard let content = toolTipContent[key] else {
            print("Warning: Tooltip content for key '\(key)' not found.")
            return
        }

        // We need the view to determine the visible size and to generate textures.
        // If you are seeing this warning, consider calling showToolTip(forKey:in:) from
        // the scene's `didMove(to:)` method, after the scene has been presented.
        guard let view = scene.view else {
            print("Warning: Cannot show tooltip, scene is not part of a view hierarchy yet.")
            return
        }
        
        let viewSize = view.bounds.size

        // The UI should be attached to the camera if one is present, otherwise to the scene itself.
        // This ensures UI stays fixed on screen even if the camera moves.
        let uiContainer = scene.camera ?? scene

        // A semi-transparent overlay to dim the background, focusing the player on the tooltip.
        let overlay = SKSpriteNode(color: .black, size: viewSize)
        overlay.alpha = 0.6
        // If attached to camera, center is .zero. If to scene, center is scene's center.
        overlay.position = scene.camera != nil ? .zero : CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.zPosition = 999 // Below the tooltip, but above all other game elements.
        uiContainer.addChild(overlay)

        // Create and configure the tooltip node.
        let toolTipSize = CGSize(width: viewSize.width * 0.75, height: viewSize.height * 0.5)
        let toolTip = ToolTipNode(title: content.title, message: content.message, size: toolTipSize)
        toolTip.position = scene.camera != nil ? .zero : CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        toolTip.zPosition = 1000 // Ensure it's on top of everything.

        // When the tooltip is dismissed, we unpause the scene and remove the overlay.
        toolTip.onDismiss = {
            scene.isPaused = false
            overlay.removeFromParent()
        }
        
        // Store the final position, then set the initial state for our animation.
        let finalPosition = toolTip.position
        // Start off-screen to the right
        toolTip.position = CGPoint(x: finalPosition.x + view.bounds.width, y: finalPosition.y)
        toolTip.alpha = 0.0

        // Add the tooltip to the scene's UI container.
        uiContainer.addChild(toolTip)
        
        // Define the animation actions for a slide-in with a bounce effect.
        let overshootAmount: CGFloat = 30.0
        let overshootPosition = CGPoint(x: finalPosition.x - overshootAmount, y: finalPosition.y)

        let slideInAction = SKAction.move(to: overshootPosition, duration: 0.6)
        slideInAction.timingMode = .easeOut

        let bounceBackAction = SKAction.move(to: finalPosition, duration: 0.25)
        bounceBackAction.timingMode = .easeInEaseOut
        
        let slideAndBounce = SKAction.sequence([slideInAction, bounceBackAction])
        
        let fadeInAction = SKAction.fadeIn(withDuration: 0.2)
        
        let animationGroup = SKAction.group([slideAndBounce, fadeInAction])

        // Run the animation, and only pause the game after the tooltip is in place.
        toolTip.run(animationGroup) {
            scene.isPaused = true
        }

        // Mark this tooltip as shown so it won't appear again.
        UserDefaults.standard.set(true, forKey: defaultsKey)
    }

    /// Resets the tracking for all tooltips, allowing them to be shown again.
    ///
    /// This is useful for development or if you add a "Reset Tutorial" button for players.
    public static func resetToolTipHistory() {
        for key in toolTipContent.keys {
            let defaultsKey = "tooltip_shown_\(key)"
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }
}

/// A custom `SKNode` that displays a modal-style tooltip with a title, message, and an OK button.
/// This class is an internal implementation detail of the `ToolTips` manager.
private class ToolTipNode: SKSpriteNode {

    /// A callback closure that is executed when the tooltip is dismissed.
    var onDismiss: (() -> Void)?

    init(title: String, message: String, size: CGSize) {
        let texture = SKTexture(imageNamed: "pauseBackdrop")
        super.init(texture: texture, color: .clear, size: size)

        self.isUserInteractionEnabled = true

        // Create and configure the title label.
        let titleLabel = SKLabelNode(fontNamed: "Fredoka-Bold")
        titleLabel.text = title
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white
        // Ensure title wraps if it's too long, respecting horizontal margins.
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 0
        titleLabel.preferredMaxLayoutWidth = self.size.width - 60
        titleLabel.verticalAlignmentMode = .top
        titleLabel.position = CGPoint(x: 0, y: self.size.height / 2 - 80) // 40pt top margin
        addChild(titleLabel)

        // Create and configure the message label.
        let messageLabel = SKLabelNode(fontNamed: "Avenir-Medium")
        messageLabel.text = message
        messageLabel.fontSize = 17
        messageLabel.fontColor = .white
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.numberOfLines = 0
        messageLabel.preferredMaxLayoutWidth = self.size.width - 60
        // Position this label dynamically below the title for a robust layout.
        messageLabel.verticalAlignmentMode = .top
        let titleBottomY = titleLabel.frame.minY
        messageLabel.position = CGPoint(x: 0, y: titleBottomY - 20) // 20pt padding below title
        addChild(messageLabel)

        // Create and configure the OK button.
        let buttonSize = CGSize(width: 120, height: 50)
        let okButton = SKSpriteNode(imageNamed: "secondaryButton")
        okButton.size = buttonSize
        okButton.position = CGPoint(x: 0, y: -self.size.height / 2 + 120)
        okButton.name = "okButton" // Name the button for reliable touch handling.
        addChild(okButton)

        let okButtonLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        okButtonLabel.text = "OK"
        okButtonLabel.fontSize = 22
        okButtonLabel.fontColor = .white
        okButtonLabel.position = CGPoint(x: 0, y: -8) // Minor adjustment for vertical centering
        okButton.addChild(okButtonLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        let tappedNode = atPoint(location)
        
        // Check if the tapped node is the OK button or its label.
        if tappedNode.name == "okButton" || tappedNode.parent?.name == "okButton" {
             dismiss()
        }
    }

    /// Handles the dismissal of the tooltip by running the callback and removing the node from the scene.
    private func dismiss() {
        onDismiss?()
        self.removeFromParent()
    }
}
