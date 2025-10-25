//
//  HapticFeedbackManager.swift
//  StuntFrogRunner iOS
//
//  Created by Jeff Mielke on 10/13/25.
//


import UIKit

class HapticFeedbackManager {
    
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    // MARK: - Impact Feedback (taps, hits, collisions)
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Notification Feedback (success, warning, error)
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    // MARK: - Selection Feedback (small changes)
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}