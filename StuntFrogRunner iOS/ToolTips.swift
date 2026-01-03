import SpriteKit

/// Protocol for scenes that can determine when it's safe to show tooltips
public protocol TooltipSafetyChecking {
    func isSafeForTooltip() -> Bool
}

/// Protocol for modal nodes that want to explicitly block tooltips
/// Modals can conform to this protocol and set isBlockingTooltips = true
public protocol TooltipBlocking {
    var isBlockingTooltips: Bool { get }
}

/// Manages the creation and display of tooltips that provide contextual help to the player.
public class ToolTips {
    
    // MARK: - Tooltip Queue Management
    
    /// Tracks whether a tooltip is currently being displayed
    private static var isShowingTooltip: Bool = false
    
    /// Queue of pending tooltips waiting to be displayed
    private static var tooltipQueue: [(key: String, scene: SKScene)] = []
    
    /// Tracks retry attempts to prevent infinite loops
    private static var retryAttempts: [String: Int] = [:]
    private static let maxRetryAttempts = 10
    
    // MARK: - Entity Encounter Tracking
    
    /// Tracks which entity types have been seen to prevent redundant checks
    private static var seenEntityTypes: Set<String> = []
    
    /// Resets the entity encounter tracking (useful for testing or new playthroughs)
    public static func resetEntityEncounters() {
        seenEntityTypes.removeAll()
    }
    
    /// Processes the next tooltip in the queue if no tooltip is currently showing
    private static func processNextTooltip() {
        // Only process if no tooltip is showing and queue has items
        guard !isShowingTooltip, !tooltipQueue.isEmpty else { return }
        
        // Get the next tooltip from the queue
        let nextTooltip = tooltipQueue.removeFirst()
        
        // Show it immediately (this will set isShowingTooltip to true)
        showToolTipImmediately(forKey: nextTooltip.key, in: nextTooltip.scene)
    }
    
    /// Checks if any modals are currently visible in the scene
    /// This ensures tooltips don't overlap with other UI elements like daily challenge intros
    /// - Parameter scene: The scene to check for existing modals
    /// - Returns: True if any modal overlays are currently visible
    private static func hasVisibleModals(in scene: SKScene) -> Bool {
        // Check the UI container (camera or scene) for any existing overlays or modals
        let uiContainer = scene.camera ?? scene
        
        // Look for high z-position overlays (typically used by modals)
        // Check z-positions >= 900 to catch most modal implementations
        for child in uiContainer.children {
            // Check if this node explicitly blocks tooltips via protocol
            if let blockingNode = child as? TooltipBlocking, blockingNode.isBlockingTooltips {
                return true
            }
            
            if child.zPosition >= 900 {
                // Filter out our own tooltip overlays (they'll be cleaned up properly)
                // Check for typical modal indicators: large sprites, specific names, or high alpha overlays
                if let sprite = child as? SKSpriteNode,
                   sprite.size.width > 100 && sprite.size.height > 100,
                   sprite.alpha > 0.3 {
                    return true
                }
                
                // Check for custom modal node types (your specific modals might have unique names)
                if let nodeName = child.name,
                   nodeName.lowercased().contains("modal") ||
                   nodeName.lowercased().contains("banner") ||
                   nodeName.lowercased().contains("challenge") ||
                   nodeName.lowercased().contains("intro") {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Checks if a specific entity type has triggered its tooltip already
    /// - Parameter entityType: The type of entity (e.g., "fly", "bee", "ghost")
    /// - Returns: True if this entity type has already triggered a tooltip
    public static func hasSeenEntity(_ entityType: String) -> Bool {
        return seenEntityTypes.contains(entityType)
    }
    
    /// Marks an entity type as seen (called internally when tooltip is shown)
    private static func markEntityAsSeen(_ entityType: String) {
        seenEntityTypes.insert(entityType)
    }
    
    /// Checks if any entities of specified types are visible and triggers tooltips
    /// Call this from your game's update loop for performance-efficient checking
    /// - Parameters:
    ///   - entities: Array of entities to check (must have position and name/type properties)
    ///   - scene: The game scene
    ///   - visibleRect: The visible portion of the scene (camera's visible area)
    public static func checkForEntityEncounters<T>(
        entities: [T],
        scene: SKScene,
        visibleRect: CGRect,
        entityTypeGetter: (T) -> String?,
        entityPositionGetter: (T) -> CGPoint
    ) {
        // Early exit if scene isn't ready or player is dragging
        guard let _ = scene.view else { return }
        
        // Check each entity efficiently
        for entity in entities {
            guard let entityType = entityTypeGetter(entity) else { continue }
            
            // Skip if we've already seen this entity type
            if hasSeenEntity(entityType) { continue }
            
            // Check if entity is within visible bounds
            let position = entityPositionGetter(entity)
            if !visibleRect.contains(position) { continue }
            
            // Map entity type to tooltip key
            let tooltipKey = entityTypeToTooltipKey(entityType)
            guard tooltipKey != nil else { continue }
            
            // Show tooltip and mark as seen
            markEntityAsSeen(entityType)
            showToolTip(forKey: tooltipKey!, in: scene)
            
            // Only show one tooltip per frame for better UX
            break
        }
    }
    
    /// Maps entity type strings to tooltip keys
    private static func entityTypeToTooltipKey(_ entityType: String) -> String? {
        switch entityType.uppercased() {
        case "FLY":
            return "flies"
        case "BEE":
            return "bees"
        case "GHOST":
            return "ghosts"
        case "DRAGONFLY":
            return "dragonflies"
        case "LOG":
            return "logs"
        case "GRAVE":
            return "ghosts"  // Show ghost tooltip when grave appears
        default:
            return nil
        }
    }

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
            message: "I don't think a lifevest will save me from falling between these pillars. So let's just not move anymore."
        ),
        "rain": (
            title: "Don't slip in the rain.",
            message: "The lilypads are slippery now. Maybe we should stop moving all together?"
        ),
        "bees": (
            title: "Bees",
            message: "I'm allergic to bees, please keep me away from them."
        ),
        "flies": (
            title: "Flies",
            message: "I love a good fly treat in the morning!"
        ),
        "ghosts": (
            title: "Ghosts",
            message: "Are those graves? Better stay away from those..."
        ),
        "dragonflies": (
            title: "Dragonflies",
            message: "Are those dragonflies coming for me? Move be out of the way now!"
        ),
        "race": (
            title: "",
            message: "Please be gentle and don't fling too fast. It's ok if the boat wins."
        ),
        "tadpole": (
            title: "",
            message: "I saved a tadpole. Mission accomplished. Let's go home!"
        ),
        "treasure": (
            title: "",
            message: "Woo hoo! I'm rich. We can go home now!"
        ),
        "logs": (
            title: "",
            message: "To be clear, I cannot jump through logs. I will hit my head and it will hurt...unless I have an axe. Then, different story."
        ),
        "cactus": (
            title: "",
            message: "Cactus hurt and they have those prickly things that stay in my but and hurt more. So unless I have an axe, be very careful. Better yet, let's go home."
        ),
        "water": (
            title: "",
            message: "Ah, my skin is getting wet! I can't swim. Quick, fling me out of here!"
        ),
        "heartOverload": (
            title: "You love too much.",
            message: "Sorry, but you can only have 6 hearts."
        ),
        "4pack": (
            title: "",
            message: "I can only carry 1 4 pack per run. Others will be saved for later."
        )
        
        // Add more tooltips here with a unique key.
    ]

    /// Creates and displays a tooltip in the center of the scene, but only if the user hasn't seen it before.
    ///
    /// This method will queue the tooltip if another one is currently showing. Once the current tooltip
    /// is dismissed, the queued tooltips will be shown in order.
    ///
    /// The game will be paused while the tooltip is visible and resume when the player taps the "OK" button.
    /// Once a tooltip is shown, it's marked as "seen" and won't be shown again for that user.
    ///
    /// **Important:** Tooltips will only be shown when the frog is safely on a lilypad, not during
    /// sling/drag actions or while jumping/flying through the air.
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
        
        // Check retry count to prevent infinite loops
        let currentRetries = retryAttempts[key] ?? 0
        guard currentRetries < maxRetryAttempts else {
            print("⚠️ Tooltip '\(key)' exceeded max retry attempts. Canceling to prevent infinite loop.")
            retryAttempts.removeValue(forKey: key)
            return
        }
        
        // Check if any other modals are currently visible
        // This prevents tooltips from overlapping with daily challenge intros, etc.
        if hasVisibleModals(in: scene) {
            retryAttempts[key] = currentRetries + 1
            // Defer the tooltip until other modals are dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showToolTip(forKey: key, in: scene)
            }
            return
        }
        
        // IMPORTANT: Only show tooltips when the frog is safely on a lilypad
        // This prevents interrupting gameplay during critical moments
        if scene is GameScene {
            // Check if the frog is in a safe state for tooltips
            if !isFrogInSafeStateForTooltip(in: scene) {
                retryAttempts[key] = currentRetries + 1
                // Defer the tooltip until the frog is in a safe state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showToolTip(forKey: key, in: scene)
                }
                return
            }
        }
        
        // Reset retry counter since we're about to show the tooltip
        retryAttempts.removeValue(forKey: key)
        
        // If a tooltip is currently showing, add this one to the queue
        if isShowingTooltip {
            // Check if this tooltip is already in the queue to avoid duplicates
            let alreadyQueued = tooltipQueue.contains(where: { $0.key == key })
            if !alreadyQueued {
                tooltipQueue.append((key: key, scene: scene))
            }
            return
        }
        
        // No tooltip is showing, display immediately
        showToolTipImmediately(forKey: key, in: scene)
    }
    
    /// Internal method that actually displays the tooltip without queueing
    private static func showToolTipImmediately(forKey key: String, in scene: SKScene) {
        let defaultsKey = "tooltip_shown_\(key)"
        
        // Mark that we're now showing a tooltip
        isShowingTooltip = true

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
       // let toolTipSize = CGSize(width: viewSize.width * 0.75, height: viewSize.height * 0.5)
        
        let toolTipSize = CGSize(width: 300, height: 275)
        let toolTip = ToolTipNode(title: content.title, message: content.message, size: toolTipSize)
        toolTip.position = scene.camera != nil ? .zero : CGPoint(x: scene.size.width / 2, y: scene.size.height / 2 + 50) 
        toolTip.zPosition = 1000 // Ensure it's on top of everything.

        // When the tooltip is dismissed, we unpause the scene, remove the overlay,
        // and process the next tooltip in the queue if any.
        toolTip.onDismiss = {
            scene.isPaused = false
            overlay.removeFromParent()
            
            // Mark that no tooltip is showing and process the next one in queue
            isShowingTooltip = false
            processNextTooltip()
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
        
        // Wait for animation to complete, then pause the game
        // This ensures the tooltip is fully visible before freezing the scene
        let pauseAction = SKAction.run {
            scene.isPaused = true
        }
        let fullSequence = SKAction.sequence([animationGroup, pauseAction])
        
        // Run the animation (don't pause until animation completes)
        toolTip.run(fullSequence)

        // Mark this tooltip as shown so it won't appear again.
        UserDefaults.standard.set(true, forKey: defaultsKey)
    }

    /// Triggers a tooltip for collecting specific items (like tadpoles or treasure)
    /// - Parameters:
    ///   - itemType: The type of item collected (e.g., "tadpole", "treasure")
    ///   - scene: The game scene
    public static func onItemCollected(_ itemType: String, in scene: SKScene) {
        let tooltipKey = itemTypeToTooltipKey(itemType)
        guard let key = tooltipKey else { return }
        
        // Check if already seen
        if hasSeenEntity(itemType) { return }
        
        // Mark as seen and show tooltip
        markEntityAsSeen(itemType)
        showToolTip(forKey: key, in: scene)
    }
    
    /// Maps item type strings to tooltip keys for collection events
    private static func itemTypeToTooltipKey(_ itemType: String) -> String? {
        switch itemType.lowercased() {
        case "tadpole":
            return "tadpole"
        case "treasure", "treasurechest":
            return "treasure"
        default:
            return nil
        }
    }
    
    /// Triggers a tooltip when the frog falls into water for the first time
    /// Call this from the didFallIntoWater() delegate method
    /// - Parameter scene: The game scene
    public static func onFrogFellIntoWater(in scene: SKScene) {
        let entityType = "water"
        let tooltipKey = "water"
        
        // Check if already seen
        if hasSeenEntity(entityType) { return }
        
        // Mark as seen and show tooltip
        markEntityAsSeen(entityType)
        showToolTip(forKey: tooltipKey, in: scene)
    }
    
    /// Triggers the ghost tooltip when a grave lilypad first appears on screen
    /// Call this when a grave pad becomes visible to warn about potential ghosts
    /// - Parameter scene: The game scene
    public static func onGraveLilypadAppeared(in scene: SKScene) {
        let entityType = "GRAVE"
        let tooltipKey = "ghosts"
        
        // Check if already seen
        if hasSeenEntity(entityType) { return }
        
        // Mark as seen and show tooltip
        markEntityAsSeen(entityType)
        showToolTip(forKey: tooltipKey, in: scene)
    }
    
    /// Resets the tracking for all tooltips, allowing them to be shown again.
    ///
    /// This is useful for development or if you add a "Reset Tutorial" button for players.
    public static func resetToolTipHistory() {
        for key in toolTipContent.keys {
            let defaultsKey = "tooltip_shown_\(key)"
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
        // Also reset entity encounter tracking
        resetEntityEncounters()
        
        // Clear the queue and reset the showing state
        tooltipQueue.removeAll()
        isShowingTooltip = false
        
        // Clear retry attempts
        retryAttempts.removeAll()
    }
    
    // MARK: - Frog State Checking
    
    /// Checks if the frog is in a safe state to show tooltips (on a lilypad, not jumping or being dragged)
    /// 
    /// Uses the `TooltipSafetyChecking` protocol to determine if the scene is ready for tooltips.
    /// 
    /// - Parameter scene: The game scene to check
    /// - Returns: True if it's safe to show a tooltip, false otherwise
    public static func isFrogInSafeStateForTooltip(in scene: SKScene) -> Bool {
        // Check if the scene conforms to our protocol
        if let tooltipScene = scene as? TooltipSafetyChecking {
            return tooltipScene.isSafeForTooltip()
        }
        
        // Default to true for scenes that don't implement the protocol (menu scenes, etc.)
        return true
    }
}

/// A custom `SKNode` that displays a modal-style tooltip with a title, message, and an OK button.
/// This class is an internal implementation detail of the `ToolTips` manager.
private class ToolTipNode: SKSpriteNode {

    /// A callback closure that is executed when the tooltip is dismissed.
    var onDismiss: (() -> Void)?

    init(title: String, message: String, size: CGSize) {
        let texture = SKTexture(imageNamed: "toolTipBackdrop")
        super.init(texture: texture, color: .clear, size: size)

        self.isUserInteractionEnabled = true

        // Create and configure the message label - vertically centered, no title.
        let messageLabel = SKLabelNode()
        messageLabel.text = message
        messageLabel.fontSize = 18
        messageLabel.fontColor = .black
        messageLabel.verticalAlignmentMode = .center
        messageLabel.horizontalAlignmentMode = .center
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.preferredMaxLayoutWidth = self.size.width - 80
        messageLabel.position = CGPoint(x: 0, y: 44) // Moved up 24 pixels from original position (20 + 24)
        messageLabel.zPosition = 1 // Ensure it's above the background
        addChild(messageLabel)
        
        // Apply comic-like font AFTER adding to parent and setting all other properties
        // Try "Chalkboard SE" first (available on iOS), fallback to "Marker Felt" or "Comic Sans MS"
        if UIFont(name: "ChalkboardSE-Bold", size: 18) != nil {
            messageLabel.fontName = "ChalkboardSE-Bold"
        } else if UIFont(name: "MarkerFelt-Wide", size: 18) != nil {
            messageLabel.fontName = "MarkerFelt-Wide"
        } else {
            messageLabel.fontName = "Noteworthy-Bold" // Another comic-like fallback
        }

        // Create and configure the OK button.
        let buttonSize = CGSize(width: 140, height: 50)
        
        // Try to load the button image, but fallback to a colored rectangle if it doesn't exist
        let okButton: SKSpriteNode
        let buttonTexture = SKTexture(imageNamed: "primaryButton")
        if buttonTexture.size() != .zero {
            okButton = SKSpriteNode(texture: buttonTexture)
            okButton.size = buttonSize
        } else {
            // Fallback: Create a rounded rectangle button with color
            okButton = SKSpriteNode(color: UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0), 
                                   size: buttonSize)
            // Add a subtle border effect
            let border = SKShapeNode(rectOf: buttonSize, cornerRadius: 8)
            border.strokeColor = .white
            border.lineWidth = 2
            border.fillColor = .clear
            okButton.addChild(border)
        }
        
        // Increased padding from the bottom edge (changed from 60 to 80)
        okButton.position = CGPoint(x: 0, y: -self.size.height / 2 - 100)
        okButton.name = "okButton" // Name the button for reliable touch handling.
        addChild(okButton)

        let okButtonLabel = SKLabelNode()
        okButtonLabel.text = "OK"
        okButtonLabel.fontSize = 24
        okButtonLabel.fontColor = .white
        okButtonLabel.verticalAlignmentMode = .center
        okButtonLabel.horizontalAlignmentMode = .center
        okButtonLabel.position = CGPoint(x: 0, y: 0)
        okButtonLabel.zPosition = 1 // Ensure label is above button
        okButton.addChild(okButtonLabel)
        
        // Apply font after adding to parent (same timing fix as above)
        okButtonLabel.fontName = "AvenirNext-Bold"
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
