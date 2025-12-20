import Foundation
import QuartzCore

/// A lightweight performance monitoring utility for tracking FPS and frame times.
/// Use this to identify performance bottlenecks in your game.
///
/// Usage:
/// ```swift
/// private let perfMonitor = PerformanceMonitor()
///
/// override func update(_ currentTime: TimeInterval) {
///     perfMonitor.markFrame()
///
///     // Your game logic...
///
///     // Log FPS every 60 frames
///     if frameCount % 60 == 0 {
///         print("📊 FPS: \(perfMonitor.getAverageFPS())")
///         print("📊 Frame time: \(perfMonitor.getAverageFrameTime() * 1000)ms")
///     }
/// }
/// ```
public class PerformanceMonitor {
    
    // MARK: - Properties
    
    private var lastFrameTime: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private let maxFrameHistory: Int
    private let slowFrameThreshold: CFTimeInterval // 16.67ms = 60 FPS
    
    /// Track slow frames for debugging
    private var slowFrameCount: Int = 0
    private var totalFrameCount: Int = 0
    
    // MARK: - Initialization
    
    /// Initialize the performance monitor
    /// - Parameters:
    ///   - historySize: Number of frames to average (default: 60)
    ///   - targetFPS: Target FPS for slow frame detection (default: 60)
    public init(historySize: Int = 60, targetFPS: Int = 60) {
        self.maxFrameHistory = historySize
        self.slowFrameThreshold = 1.0 / Double(targetFPS)
    }
    
    // MARK: - Public Methods
    
    /// Call this at the start of each frame to record timing
    public func markFrame() {
        let currentTime = CACurrentMediaTime()
        
        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            frameTimes.append(frameTime)
            
            // Keep only the most recent frames
            if frameTimes.count > maxFrameHistory {
                frameTimes.removeFirst()
            }
            
            // Track slow frames
            totalFrameCount += 1
            if frameTime > slowFrameThreshold {
                slowFrameCount += 1
                
                // Log extremely slow frames (> 33ms = < 30 FPS)
                if frameTime > 0.033 {
                    print("🐌 Very slow frame: \(String(format: "%.2f", frameTime * 1000))ms (\(String(format: "%.1f", 1.0 / frameTime)) FPS)")
                }
            }
        }
        
        lastFrameTime = currentTime
    }
    
    /// Get the average FPS over the frame history
    /// - Returns: Average frames per second
    public func getAverageFPS() -> Double {
        guard !frameTimes.isEmpty else { return 0 }
        let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        return 1.0 / avgFrameTime
    }
    
    /// Get the average frame time in seconds
    /// - Returns: Average time per frame in seconds
    public func getAverageFrameTime() -> Double {
        guard !frameTimes.isEmpty else { return 0 }
        return frameTimes.reduce(0, +) / Double(frameTimes.count)
    }
    
    /// Get the minimum (best) FPS in the frame history
    /// - Returns: Minimum FPS (highest frame time)
    public func getMinFPS() -> Double {
        guard let maxFrameTime = frameTimes.max() else { return 0 }
        return 1.0 / maxFrameTime
    }
    
    /// Get the maximum (worst) frame time in milliseconds
    /// - Returns: Maximum frame time in milliseconds
    public func getMaxFrameTime() -> Double {
        guard let maxFrameTime = frameTimes.max() else { return 0 }
        return maxFrameTime * 1000
    }
    
    /// Get the percentage of frames that were slow (below target FPS)
    /// - Returns: Percentage of slow frames (0.0 to 1.0)
    public func getSlowFramePercentage() -> Double {
        guard totalFrameCount > 0 else { return 0 }
        return Double(slowFrameCount) / Double(totalFrameCount)
    }
    
    /// Reset all tracking statistics
    public func reset() {
        lastFrameTime = 0
        frameTimes.removeAll()
        slowFrameCount = 0
        totalFrameCount = 0
    }
    
    /// Get a formatted performance summary string
    /// - Returns: Multi-line string with performance statistics
    public func getSummary() -> String {
        let avgFPS = getAverageFPS()
        let avgFrameTime = getAverageFrameTime() * 1000
        let minFPS = getMinFPS()
        let maxFrameTime = getMaxFrameTime()
        let slowPercentage = getSlowFramePercentage() * 100
        
        return """
        📊 Performance Summary:
        • Average FPS: \(String(format: "%.1f", avgFPS))
        • Average frame time: \(String(format: "%.2f", avgFrameTime))ms
        • Min FPS: \(String(format: "%.1f", minFPS))
        • Max frame time: \(String(format: "%.2f", maxFrameTime))ms
        • Slow frames: \(String(format: "%.1f", slowPercentage))%
        """
    }
    
    /// Print a detailed performance report to the console
    public func printReport() {
        print(getSummary())
    }
}

// MARK: - Entity Count Tracker

/// Tracks the number of active entities for performance monitoring
public class EntityCountTracker {
    
    private var entityCounts: [String: Int] = [:]
    
    /// Update the count for a specific entity type
    /// - Parameters:
    ///   - type: The entity type name (e.g., "pads", "enemies")
    ///   - count: The current count
    public func updateCount(_ type: String, count: Int) {
        entityCounts[type] = count
    }
    
    /// Get the count for a specific entity type
    /// - Parameter type: The entity type name
    /// - Returns: The count, or 0 if not tracked
    public func getCount(_ type: String) -> Int {
        return entityCounts[type] ?? 0
    }
    
    /// Get the total count of all entities
    /// - Returns: Sum of all entity counts
    public func getTotalCount() -> Int {
        return entityCounts.values.reduce(0, +)
    }
    
    /// Get a summary of all entity counts
    /// - Returns: Dictionary of entity type to count
    public func getEntityCounts() -> [String: Int] {
        return entityCounts
    }
    
    /// Print entity counts to the console
    public func printCounts() {
        print("🎮 Entity Counts:")
        let sorted = entityCounts.sorted { $0.value > $1.value }
        for (type, count) in sorted {
            print("  • \(type): \(count)")
        }
        print("  • Total: \(getTotalCount())")
    }
    
    /// Reset all counts
    public func reset() {
        entityCounts.removeAll()
    }
}

// MARK: - Performance Profiler

/// A simple profiler for measuring time spent in specific code sections
public class PerformanceProfiler {
    
    private struct TimingInfo {
        var totalTime: CFTimeInterval = 0
        var callCount: Int = 0
        var averageTime: CFTimeInterval {
            guard callCount > 0 else { return 0 }
            return totalTime / Double(callCount)
        }
    }
    
    private var timings: [String: TimingInfo] = [:]
    private var startTimes: [String: CFTimeInterval] = [:]
    
    /// Begin timing a code section
    /// - Parameter section: Name of the section to time
    public func startTiming(_ section: String) {
        startTimes[section] = CACurrentMediaTime()
    }
    
    /// End timing a code section
    /// - Parameter section: Name of the section that was timed
    public func endTiming(_ section: String) {
        guard let startTime = startTimes[section] else {
            print("⚠️ Warning: endTiming called for '\(section)' without startTiming")
            return
        }
        
        let elapsed = CACurrentMediaTime() - startTime
        
        var info = timings[section] ?? TimingInfo()
        info.totalTime += elapsed
        info.callCount += 1
        timings[section] = info
        
        startTimes[section] = nil
    }
    
    /// Measure the execution time of a closure
    /// - Parameters:
    ///   - section: Name of the section being measured
    ///   - closure: The code to execute and measure
    public func measure(_ section: String, closure: () -> Void) {
        startTiming(section)
        closure()
        endTiming(section)
    }
    
    /// Get timing information for a specific section
    /// - Parameter section: Name of the section
    /// - Returns: Average time in milliseconds
    public func getAverageTime(_ section: String) -> Double {
        guard let info = timings[section] else { return 0 }
        return info.averageTime * 1000
    }
    
    /// Print a profiling report
    public func printReport() {
        print("⏱️ Performance Profile:")
        let sorted = timings.sorted { $0.value.averageTime > $1.value.averageTime }
        for (section, info) in sorted {
            let avgMs = info.averageTime * 1000
            let totalMs = info.totalTime * 1000
            print("  • \(section): \(String(format: "%.2f", avgMs))ms avg (\(info.callCount) calls, \(String(format: "%.2f", totalMs))ms total)")
        }
    }
    
    /// Reset all timing data
    public func reset() {
        timings.removeAll()
        startTimes.removeAll()
    }
}

// MARK: - Example Usage in GameScene

/*
 Add this to your GameScene.swift:
 
 private let perfMonitor = PerformanceMonitor()
 private let entityTracker = EntityCountTracker()
 private let profiler = PerformanceProfiler()
 
 override func update(_ currentTime: TimeInterval) {
     perfMonitor.markFrame()
     
     // Your existing code...
     
     // Track entity counts
     entityTracker.updateCount("activePads", count: activePads.count)
     entityTracker.updateCount("activeEnemies", count: activeEnemies.count)
     entityTracker.updateCount("activeCoins", count: activeCoins.count)
     
     // Profile specific sections
     profiler.measure("collision_detection") {
         collisionManager.update(...)
     }
     
     profiler.measure("visual_updates") {
         updateWaterVisuals()
         updateShores()
     }
     
     // Print report every 3 seconds
     if frameCount % 180 == 0 {
         perfMonitor.printReport()
         entityTracker.printCounts()
         profiler.printReport()
     }
 }
 */
