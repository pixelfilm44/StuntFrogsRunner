//
//  RippleManager.swift
//  Stuntfrog Superstar
//
//  Manages water ripple effects with shader-based rendering
//

import SpriteKit

class RippleManager {
    // Maximum concurrent ripples (keep this reasonable for performance)
    private let maxRipples = 12
    
    // Ripple data arrays
    private var ripplePositions: [CGPoint] = []
    private var rippleStartTimes: [TimeInterval] = []
    private var rippleAmplitudes: [CGFloat] = []
    private var rippleFrequencies: [CGFloat] = []
    
    // Current time for ripple animation
    private var currentTime: TimeInterval = 0
    
    // Ripple lifetime in seconds
    private let rippleLifetime: TimeInterval = 2.0
    
    init() {
        // Pre-allocate arrays
        ripplePositions = Array(repeating: .zero, count: maxRipples)
        rippleStartTimes = Array(repeating: 0, count: maxRipples)
        rippleAmplitudes = Array(repeating: 0, count: maxRipples)
        rippleFrequencies = Array(repeating: 0, count: maxRipples)
    }
    
    /// Add a new ripple at the given position (in world coordinates)
    /// - Parameters:
    ///   - position: Position in world coordinates
    ///   - amplitude: Wave amplitude (default: 0.015 for subtle effect)
    ///   - frequency: Wave frequency (default: 8.0)
    func addRipple(at position: CGPoint, amplitude: CGFloat = 0.015, frequency: CGFloat = 8.0) {
        
        // Find oldest ripple to replace (simple round-robin)
        var oldestIndex = 0
        var oldestTime = rippleStartTimes[0]
        
        for i in 1..<maxRipples {
            if rippleStartTimes[i] < oldestTime {
                oldestTime = rippleStartTimes[i]
                oldestIndex = i
            }
        }
        
        // Store position in scene coordinates (NOT normalized)
        // The shader will handle the coordinate conversion
        ripplePositions[oldestIndex] = position
        rippleStartTimes[oldestIndex] = currentTime
        rippleAmplitudes[oldestIndex] = amplitude
        rippleFrequencies[oldestIndex] = frequency
    }
    
    /// Update time and clean up expired ripples
    func update(deltaTime: TimeInterval) {
        currentTime += deltaTime
        
        // Expire old ripples by setting their amplitude to 0
        for i in 0..<maxRipples {
            let age = currentTime - rippleStartTimes[i]
            if age > rippleLifetime {
                rippleAmplitudes[i] = 0
            }
        }
    }
    
    /// Get shader uniforms for current ripple state (for initial shader setup)
    func getShaderUniforms() -> [SKUniform] {
        var uniforms: [SKUniform] = []
        
        // Pack ripple data into uniforms using vector_float3 (SIMD3)
        // Position X values
        let posX = ripplePositions.map { Float($0.x) }
        uniforms.append(SKUniform(name: "u_ripple_x", vectorFloat3: vector_float3(posX[0], posX[1], posX[2])))
        uniforms.append(SKUniform(name: "u_ripple_x2", vectorFloat3: vector_float3(posX[3], posX[4], posX[5])))
        uniforms.append(SKUniform(name: "u_ripple_x3", vectorFloat3: vector_float3(posX[6], posX[7], posX[8])))
        uniforms.append(SKUniform(name: "u_ripple_x4", vectorFloat3: vector_float3(posX[9], posX[10], posX[11])))
        
        // Position Y values
        let posY = ripplePositions.map { Float($0.y) }
        uniforms.append(SKUniform(name: "u_ripple_y", vectorFloat3: vector_float3(posY[0], posY[1], posY[2])))
        uniforms.append(SKUniform(name: "u_ripple_y2", vectorFloat3: vector_float3(posY[3], posY[4], posY[5])))
        uniforms.append(SKUniform(name: "u_ripple_y3", vectorFloat3: vector_float3(posY[6], posY[7], posY[8])))
        uniforms.append(SKUniform(name: "u_ripple_y4", vectorFloat3: vector_float3(posY[9], posY[10], posY[11])))
        
        // Amplitudes
        let amps = rippleAmplitudes.map { Float($0) }
        uniforms.append(SKUniform(name: "u_ripple_amp", vectorFloat3: vector_float3(amps[0], amps[1], amps[2])))
        uniforms.append(SKUniform(name: "u_ripple_amp2", vectorFloat3: vector_float3(amps[3], amps[4], amps[5])))
        uniforms.append(SKUniform(name: "u_ripple_amp3", vectorFloat3: vector_float3(amps[6], amps[7], amps[8])))
        uniforms.append(SKUniform(name: "u_ripple_amp4", vectorFloat3: vector_float3(amps[9], amps[10], amps[11])))
        
        // Ages (time since ripple started)
        let ages = rippleStartTimes.map { Float(currentTime - $0) }
        uniforms.append(SKUniform(name: "u_ripple_age", vectorFloat3: vector_float3(ages[0], ages[1], ages[2])))
        uniforms.append(SKUniform(name: "u_ripple_age2", vectorFloat3: vector_float3(ages[3], ages[4], ages[5])))
        uniforms.append(SKUniform(name: "u_ripple_age3", vectorFloat3: vector_float3(ages[6], ages[7], ages[8])))
        uniforms.append(SKUniform(name: "u_ripple_age4", vectorFloat3: vector_float3(ages[9], ages[10], ages[11])))
        
        // Frequencies
        let freqs = rippleFrequencies.map { Float($0) }
        uniforms.append(SKUniform(name: "u_ripple_freq", vectorFloat3: vector_float3(freqs[0], freqs[1], freqs[2])))
        uniforms.append(SKUniform(name: "u_ripple_freq2", vectorFloat3: vector_float3(freqs[3], freqs[4], freqs[5])))
        uniforms.append(SKUniform(name: "u_ripple_freq3", vectorFloat3: vector_float3(freqs[6], freqs[7], freqs[8])))
        uniforms.append(SKUniform(name: "u_ripple_freq4", vectorFloat3: vector_float3(freqs[9], freqs[10], freqs[11])))
        
        return uniforms
    }
    
    /// Get ripple positions array (for coordinate conversion)
    func getRipplePositions() -> [CGPoint] {
        return ripplePositions
    }
    
    /// Get ripple data as vector_float3 arrays for shader updates
    func getRippleData() -> (amplitudes: [vector_float3], ages: [vector_float3], frequencies: [vector_float3]) {
        let amps = rippleAmplitudes.map { Float($0) }
        let ages = rippleStartTimes.map { Float(currentTime - $0) }
        let freqs = rippleFrequencies.map { Float($0) }
        
        let amplitudes = [
            vector_float3(amps[0], amps[1], amps[2]),
            vector_float3(amps[3], amps[4], amps[5]),
            vector_float3(amps[6], amps[7], amps[8]),
            vector_float3(amps[9], amps[10], amps[11])
        ]
        
        let ageVectors = [
            vector_float3(ages[0], ages[1], ages[2]),
            vector_float3(ages[3], ages[4], ages[5]),
            vector_float3(ages[6], ages[7], ages[8]),
            vector_float3(ages[9], ages[10], ages[11])
        ]
        
        let freqVectors = [
            vector_float3(freqs[0], freqs[1], freqs[2]),
            vector_float3(freqs[3], freqs[4], freqs[5]),
            vector_float3(freqs[6], freqs[7], freqs[8]),
            vector_float3(freqs[9], freqs[10], freqs[11])
        ]
        
        return (amplitudes, ageVectors, freqVectors)
    }
    
    /// Reset all ripples (useful for game reset)
    func reset() {
        currentTime = 0
        for i in 0..<maxRipples {
            rippleAmplitudes[i] = 0
            rippleStartTimes[i] = 0
        }
    }
}
