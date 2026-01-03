//
//  SpaceBackgroundColors.swift
//  StuntFrogRunner iOS
//
//  Color reference for space weather theme
//

import UIKit

/// Color palette for space weather theme
/// Use these colors for consistency across all space-related visuals
struct SpaceWeatherColors {
    
    // MARK: - Background Gradient Colors (Top to Bottom)
    
    /// Very dark purple-black (top of screen)
    static let gradientTop = UIColor(red: 0.05, green: 0.0, blue: 0.1, alpha: 1.0)
    
    /// Dark purple (mid-top)
    static let gradientMidTop = UIColor(red: 0.1, green: 0.05, blue: 0.2, alpha: 1.0)
    
    /// Medium purple (center)
    static let gradientCenter = UIColor(red: 0.15, green: 0.08, blue: 0.25, alpha: 1.0)
    
    /// Rich purple (mid-bottom)
    static let gradientMidBottom = UIColor(red: 0.2, green: 0.1, blue: 0.3, alpha: 1.0)
    
    /// Dark purple-black (bottom of screen)
    static let gradientBottom = UIColor(red: 0.1, green: 0.05, blue: 0.15, alpha: 1.0)
    
    // MARK: - Scene Background Color
    
    /// Scene backgroundColor for space weather (very dark blue-black)
    static let sceneBackground = UIColor(red: 0.0, green: 0.0, blue: 0.05, alpha: 1.0)
    
    // MARK: - Star Colors
    
    /// Base color for stars (white with slight blue tint)
    static let starWhite = UIColor.white
    
    /// Blue-tinted stars (for variety)
    static let starBlue = UIColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 1.0)
    
    // MARK: - Complementary Colors (for UI elements in space weather)
    
    /// Accent color for space UI elements (bright purple)
    static let accentPurple = UIColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 1.0)
    
    /// Secondary accent (cyan - contrasts well with purple)
    static let accentCyan = UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
    
    // MARK: - Helper Methods
    
    /// Returns the full gradient color array for manual gradient creation
    static var gradientColors: [UIColor] {
        return [
            gradientTop,
            gradientMidTop,
            gradientCenter,
            gradientMidBottom,
            gradientBottom
        ]
    }
    
    /// Returns gradient locations (0.0 to 1.0) for the gradient colors
    static var gradientLocations: [CGFloat] {
        return [0.0, 0.25, 0.5, 0.75, 1.0]
    }
}

// MARK: - Visual Reference (Comments)

/*
 
 ═══════════════════════════════════════════════════════════════════
 SPACE WEATHER COLOR SCHEME - VISUAL REFERENCE
 ═══════════════════════════════════════════════════════════════════
 
 ┌─────────────────────────────────────────┐
 │   🌌 DEEP SPACE PURPLE GRADIENT 🌌      │
 └─────────────────────────────────────────┘
 
 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  TOP (Very Dark Purple-Black)
 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  RGB: 0.05, 0.0, 0.1
 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
        ⭐           ⭐                      (Scattered white stars)
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  MID-TOP (Dark Purple)
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  RGB: 0.1, 0.05, 0.2
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
    ⭐      ⭐            ⭐                 (More stars)
 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  CENTER (Medium Purple)
 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  RGB: 0.15, 0.08, 0.25
 ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  <- Richest purple color here
         ⭐       ⭐                         (Stars throughout)
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  MID-BOTTOM (Rich Purple)
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  RGB: 0.2, 0.1, 0.3
 ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
       ⭐               ⭐                  (Twinkling stars)
 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  BOTTOM (Dark Purple-Black)
 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  RGB: 0.1, 0.05, 0.15
 ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
 
 ═══════════════════════════════════════════════════════════════════
 
 KEY DESIGN PRINCIPLES:
 
 ✨ Gradient Flow: Creates depth by transitioning from near-black at
    edges to richer purple at center, mimicking deep space
 
 ⭐ Star Distribution: Random white dots of varying sizes and
    brightness scattered throughout for realism
 
 🎨 Color Temperature: Cool color palette (blues and purples) evokes
    the cold, vast emptiness of space
 
 💫 Parallax Effect: Stars move slower than camera, creating depth
    illusion as player progresses
 
 ═══════════════════════════════════════════════════════════════════
 
 RGB VALUES BREAKDOWN:
 
 Position    | Red  | Green | Blue | Effect
 ──────────────────────────────────────────────────────────────────
 Top         | 0.05 | 0.0   | 0.1  | Very dark, slight purple tint
 Mid-Top     | 0.1  | 0.05  | 0.2  | Darker purple becomes visible
 Center      | 0.15 | 0.08  | 0.25 | Richest purple (peak color)
 Mid-Bottom  | 0.2  | 0.1   | 0.3  | Strong purple presence
 Bottom      | 0.1  | 0.05  | 0.15 | Fade back to dark purple-black
 
 Notice the pattern: Blue channel is always highest, creating the
 purple tone. Red and green channels are kept low for darkness,
 with gradual increases toward center for the purple pop.
 
 ═══════════════════════════════════════════════════════════════════
 
 TESTING THE COLORS:
 
 To preview these colors, you can run this in a playground:
 
 ```swift
 import UIKit
 import PlaygroundSupport
 
 let view = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
 
 // Create gradient layer
 let gradientLayer = CAGradientLayer()
 gradientLayer.frame = view.bounds
 gradientLayer.colors = SpaceWeatherColors.gradientColors.map { $0.cgColor }
 gradientLayer.locations = SpaceWeatherColors.gradientLocations.map { NSNumber(value: $0) }
 view.layer.addSublayer(gradientLayer)
 
 // Add some "stars"
 for _ in 0..<50 {
     let star = UIView(frame: CGRect(x: 0, y: 0, width: 3, height: 3))
     star.backgroundColor = .white
     star.layer.cornerRadius = 1.5
     star.center = CGPoint(
         x: CGFloat.random(in: 0...400),
         y: CGFloat.random(in: 0...600)
     )
     star.alpha = CGFloat.random(in: 0.5...1.0)
     view.addSubview(star)
 }
 
 PlaygroundPage.current.liveView = view
 ```
 
 ═══════════════════════════════════════════════════════════════════
 
*/
