//
//  PerformanceSettings.swift
//  StuntFrogRunner iOS
//
//  Created on 12/12/2025.
//  Performance settings for optimizing gameplay on different devices
//

import UIKit
import SpriteKit

/// Manages performance settings based on device capabilities
/// Automatically adjusts quality settings to maintain 60 FPS on older devices
struct PerformanceSettings {
    
    // MARK: - Device Detection
    
    /// Returns true for devices older than iPhone 14 or equivalent
    static var isLowEndDevice: Bool {
        let systemInfo = utsname()
        var systemInfoCopy = systemInfo
        uname(&systemInfoCopy)
        
        let identifier = withUnsafePointer(to: &systemInfoCopy.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        // For simulator, use processor count as proxy
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.processorCount < 6
        #else
        
        // Check for older iPhone models
        // iPhone 15 = iPhone15,x or iPhone16,x
        // iPhone 14 = iPhone14,x or iPhone15,x (14 Pro)
        // iPhone 13 = iPhone14,x
        // iPhone 12 = iPhone13,x
        // Treat iPhone 14 and older as low-end
        guard let modelIdentifier = identifier else { return false }
        
        // Extract model number (e.g., "iPhone13,2" -> 13)
        if modelIdentifier.hasPrefix("iPhone") {
            let components = modelIdentifier.components(separatedBy: CharacterSet.decimalDigits.inverted)
            if let majorVersion = components.compactMap({ Int($0) }).first {
                return majorVersion <= 15 // iPhone 14 and older (includes iPhone14,x and iPhone15,x models)
            }
        }
        
        // For iPad, check generation
        if modelIdentifier.hasPrefix("iPad") {
            let components = modelIdentifier.components(separatedBy: CharacterSet.decimalDigits.inverted)
            if let majorVersion = components.compactMap({ Int($0) }).first {
                return majorVersion < 13 // iPad Pro 2021 and older
            }
        }
        
        return false
        #endif
    }
    
    /// Returns true for very old devices that need aggressive optimization
    static var isVeryLowEndDevice: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let systemInfo = utsname()
        var systemInfoCopy = systemInfo
        uname(&systemInfoCopy)
        
        let identifier = withUnsafePointer(to: &systemInfoCopy.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        guard let modelIdentifier = identifier else { return false }
        
        // iPhone 11 and older (iPhone12,x and below)
        if modelIdentifier.hasPrefix("iPhone") {
            let components = modelIdentifier.components(separatedBy: CharacterSet.decimalDigits.inverted)
            if let majorVersion = components.compactMap({ Int($0) }).first {
                return majorVersion < 12
            }
        }
        
        return false
        #endif
    }
    
    // MARK: - Quality Settings
    
    /// Number of trajectory dots to show during aiming
    static var trajectoryDotCount: Int {
        if isVeryLowEndDevice { return 10 }
        if isLowEndDevice { return 12 }
        return 20
    }
    
    /// Size of ripple effect pool
    static var ripplePoolSize: Int {
        if isVeryLowEndDevice { return 8 }
        if isLowEndDevice { return 12 }
        return 20
    }
    
    /// Particle birth rate multiplier for weather effects
    static var particleMultiplier: CGFloat {
        if isVeryLowEndDevice { return 0.25 }
        if isLowEndDevice { return 0.5 }
        return 1.0
    }
    
    /// Water animation quality (affects tile count and animation smoothness)
    static var waterQuality: WaterQuality {
        if isVeryLowEndDevice { return .low }
        if isLowEndDevice { return .medium }
        return .high
    }
    
    /// How often to update HUD elements (in frames)
    /// Higher values = less frequent updates = better performance
    static var hudUpdateInterval: Int {
        if isVeryLowEndDevice { return 4 }
        if isLowEndDevice { return 3 }
        return 1 // Every frame
    }
    
    /// How often to cleanup offscreen entities (in frames)
    static var cleanupInterval: Int {
        if isVeryLowEndDevice { return 60 }
        if isLowEndDevice { return 45 }
        return 30
    }
    
    /// Whether to show background visual effects (moonlight, space glow, etc.)
    static var showBackgroundEffects: Bool {
        return !isVeryLowEndDevice
    }
    
    /// Maximum number of active leaves floating on screen
    static var maxLeaves: Int {
        if isVeryLowEndDevice { return 3 }
        if isLowEndDevice { return 6 }
        return 15
    }
    
    /// How often to update water tile positions (in frames)
    static var waterUpdateInterval: Int {
        if isVeryLowEndDevice { return 4 }
        if isLowEndDevice { return 3 }
        return 2
    }
    
    /// Whether to enable leaf decorations
    static var enableLeafDecorations: Bool {
        return !isLowEndDevice
    }
    
    /// Whether to enable plant decorations on screen edges
    static var enablePlantDecorations: Bool {
        return !isLowEndDevice
    }
    
    /// Maximum ripples to spawn per impact
    static var maxRipplesPerImpact: Int {
        if isVeryLowEndDevice { return 1 }
        if isLowEndDevice { return 2 }
        return 3
    }
    
    /// Whether to use simplified animations for entities
    static var useSimplifiedAnimations: Bool {
        return isLowEndDevice
    }
    
    /// Whether to use texture atlases for improved batching
    static var useTextureAtlases: Bool {
        return true // Always use when available
    }
    
    /// Shadow quality level
    static var shadowQuality: ShadowQuality {
        if isVeryLowEndDevice { return .none }
        if isLowEndDevice { return .low }
        return .medium
    }
    
    // MARK: - Enums
    
    enum WaterQuality {
        case low    // Fewer tiles, less animation
        case medium // Standard tiles, normal animation
        case high   // More tiles, smooth animation
        
        var tileMultiplier: CGFloat {
            switch self {
            case .low: return 2.0
            case .medium: return 2.5
            case .high: return 3.0
            }
        }
        
        var animationEnabled: Bool {
            return self != .low
        }
    }
    
    enum ShadowQuality {
        case none   // No shadows
        case low    // Simplified shadows
        case medium // Standard shadows
        case high   // Full shadows with blur
    }
    
    // MARK: - Debug Info
    
    /// Print device information and selected quality settings
    static func printDeviceInfo() {
        print("📱 Device Performance Profile:")
        print("   Low End Device: \(isLowEndDevice)")
        print("   Very Low End Device: \(isVeryLowEndDevice)")
        print("   Processor Count: \(ProcessInfo.processInfo.processorCount)")
        print("   Trajectory Dots: \(trajectoryDotCount)")
        print("   Ripple Pool Size: \(ripplePoolSize)")
        print("   Particle Multiplier: \(particleMultiplier)")
        print("   Water Quality: \(waterQuality)")
        print("   HUD Update Interval: \(hudUpdateInterval) frames")
        print("   Background Effects: \(showBackgroundEffects)")
    }
    
    // MARK: - Apply Settings
    
    /// Apply performance settings to a game scene
    static func apply(to scene: GameScene) {
        print("🎮 Applying performance settings to scene...")
        
        // Adjust particle effects based on device capability
        scene.weatherNode.alpha = particleMultiplier
        
        // Log the settings being applied
        printDeviceInfo()
        
        print("✅ Performance settings applied")
    }
}
