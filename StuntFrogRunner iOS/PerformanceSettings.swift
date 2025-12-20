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
    
    /// Cached device classification results to avoid repeated system calls
    private static var cachedLowEndDevice: Bool?
    private static var cachedVeryLowEndDevice: Bool?
    private static var cachedHighEndDevice: Bool?
    
    /// Returns true for devices older than iPhone 14 or equivalent
    static var isLowEndDevice: Bool {
        // Return cached value if available
        if let cached = cachedLowEndDevice {
            return cached
        }
        
        // Calculate and cache the result
        let result = calculateIsLowEndDevice()
        cachedLowEndDevice = result
        return result
    }
    
    /// Internal function to calculate device classification
    private static func calculateIsLowEndDevice() -> Bool {
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
        // iPhone 16 = iPhone17,x
        // iPhone 15 = iPhone15,x or iPhone16,x
        // iPhone 14 = iPhone14,x or iPhone15,x (14 Pro)
        // iPhone 13 = iPhone14,x
        // iPhone 12 = iPhone13,x
        // Treat iPhone 13 and older as low-end (iPhone 14 and newer are high-end)
        guard let modelIdentifier = identifier else { return false }
        
        print("📱 Detected device identifier: \(modelIdentifier)")
        
        // Extract model number (e.g., "iPhone13,2" -> 13)
        if modelIdentifier.hasPrefix("iPhone") {
            let components = modelIdentifier.components(separatedBy: CharacterSet.decimalDigits.inverted)
            if let majorVersion = components.compactMap({ Int($0) }).first {
                // iPhone 14 starts at iPhone14,x/iPhone15,x
                // iPhone 15 starts at iPhone15,x/iPhone16,x  
                // iPhone 16 starts at iPhone17,x
                let isLowEnd = majorVersion <= 13 // iPhone 13 and older are low-end
                print("📱 iPhone major version: \(majorVersion), classified as low-end: \(isLowEnd)")
                return isLowEnd
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
        // Return cached value if available
        if let cached = cachedVeryLowEndDevice {
            return cached
        }
        
        // Calculate and cache the result
        let result = calculateIsVeryLowEndDevice()
        cachedVeryLowEndDevice = result
        return result
    }
    
    /// Internal function to calculate very low-end device classification
    private static func calculateIsVeryLowEndDevice() -> Bool {
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
    
    /// Returns true for iPhone 15 Pro and newer (ProMotion 120Hz capable)
    static var isHighEndDevice: Bool {
        // Return cached value if available
        if let cached = cachedHighEndDevice {
            return cached
        }
        
        // Calculate and cache the result
        let result = calculateIsHighEndDevice()
        cachedHighEndDevice = result
        return result
    }
    
    /// Internal function to calculate high-end device classification
    private static func calculateIsHighEndDevice() -> Bool {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.processorCount >= 8
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
        
        // iPhone 15 Pro and newer (iPhone16,x for 15 Pro, iPhone17,x for 16)
        if modelIdentifier.hasPrefix("iPhone") {
            let components = modelIdentifier.components(separatedBy: CharacterSet.decimalDigits.inverted)
            if let majorVersion = components.compactMap({ Int($0) }).first {
                return majorVersion >= 16 // iPhone 15 Pro and newer
            }
        }
        
        return false
        #endif
    }
    
    /// Number of trajectory dots to show during aiming
    static var trajectoryDotCount: Int {
        if isVeryLowEndDevice { return 8 }
        if isLowEndDevice { return 10 }
        return 12  // Reduced from 15 for better performance
    }
    
    /// Size of ripple effect pool
    static var ripplePoolSize: Int {
        if isVeryLowEndDevice { return 6 }
        if isLowEndDevice { return 10 }
        return 12  // Reduced from 15 for better performance
    }
    
    /// Particle birth rate multiplier for weather effects
    static var particleMultiplier: CGFloat {
        if isVeryLowEndDevice { return 0.25 }
        if isLowEndDevice { return 0.5 }
        return 0.8  // Reduced from 1.0 - particles are expensive!
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
        // Even high-end devices don't need HUD updates at 120fps
        return 3  // Update at ~40fps instead of 120fps
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
        // PERFORMANCE: Plants are decorative only - disabled for better frame rates on iPhone
        // Enable on iPad where screen edges need more coverage
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        return isIPad && !isVeryLowEndDevice
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
    
    /// Get the actual device identifier string for debugging
    static var deviceIdentifier: String {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        let systemInfo = utsname()
        var systemInfoCopy = systemInfo
        uname(&systemInfoCopy)
        
        let identifier = withUnsafePointer(to: &systemInfoCopy.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        return identifier ?? "Unknown"
        #endif
    }
    
    /// Print device information and selected quality settings
    static func printDeviceInfo() {
        print("📱 Device Performance Profile:")
        print("   Device Identifier: \(deviceIdentifier)")
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
