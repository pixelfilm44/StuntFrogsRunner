//
//  LilyPadPlacementOptimizations.swift
//  Additional performant overlap prevention techniques
//

import Foundation
import SpriteKit

// MARK: - Alternative 1: Poisson Disk Sampling for Natural Distribution

/// Generates lily pad positions using Poisson disk sampling for natural spacing
/// This ensures minimum distance between pads without clustering
class PoissonDiskSampler {
    private let minDistance: CGFloat
    private let maxDistance: CGFloat
    private let maxAttempts: Int
    
    init(minDistance: CGFloat, maxDistance: CGFloat, maxAttempts: Int = 30) {
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        self.maxAttempts = maxAttempts
    }
    
    /// Generate a lily pad position that maintains minimum distance from existing pads
    func generatePosition(near anchor: CGPoint, existing: [LilyPad], bounds: CGRect) -> CGPoint? {
        for _ in 0..<maxAttempts {
            // Generate random position in annulus (ring) around anchor
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: minDistance...maxDistance)
            
            let candidate = CGPoint(
                x: anchor.x + cos(angle) * distance,
                y: anchor.y + sin(angle) * distance
            )
            
            // Check bounds
            guard bounds.contains(candidate) else { continue }
            
            // Check minimum distance from all existing pads
            var valid = true
            for pad in existing {
                let dx = candidate.x - pad.position.x
                let dy = candidate.y - pad.position.y
                let dist = sqrt(dx * dx + dy * dy)
                
                if dist < minDistance + pad.radius {
                    valid = false
                    break
                }
            }
            
            if valid {
                return candidate
            }
        }
        
        return nil // No valid position found
    }
}

// MARK: - Alternative 2: Pre-computed Valid Positions

/// Pre-computes and caches valid lily pad positions to avoid runtime calculations
class LilyPadPositionCache {
    private var validPositions: [CGPoint] = []
    private var currentIndex = 0
    
    /// Pre-compute valid positions for a given area
    func precompute(bounds: CGRect, minSpacing: CGFloat, gridResolution: CGFloat = 50) {
        validPositions.removeAll()
        
        let stepX = gridResolution
        let stepY = gridResolution
        
        var y = bounds.minY + minSpacing
        while y < bounds.maxY - minSpacing {
            var x = bounds.minX + minSpacing
            while x < bounds.maxX - minSpacing {
                let candidate = CGPoint(x: x, y: y)
                validPositions.append(candidate)
                x += stepX
            }
            y += stepY
        }
        
        // Shuffle for natural distribution
        validPositions.shuffle()
        currentIndex = 0
    }
    
    /// Get the next pre-computed valid position
    func nextPosition() -> CGPoint? {
        guard currentIndex < validPositions.count else { return nil }
        let position = validPositions[currentIndex]
        currentIndex += 1
        return position
    }
    
    /// Check if a position is far enough from existing lily pads
    func isValidPosition(_ position: CGPoint, existing: [LilyPad], minDistance: CGFloat) -> Bool {
        for pad in existing {
            let dx = position.x - pad.position.x
            let dy = position.y - pad.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < minDistance + pad.radius {
                return false
            }
        }
        return true
    }
}

// MARK: - Alternative 3: Distance-squared optimization

extension SpawnManager {
    /// Optimized overlap check using squared distances (avoids expensive sqrt calls)
    private func isOverlappingExistingOptimized(position: CGPoint, candidateRadius: CGFloat, lilyPads: [LilyPad], extraPadding: CGFloat = 12) -> Bool {
        for pad in lilyPads {
            let dx = position.x - pad.position.x
            let dy = position.y - pad.position.y
            let distanceSquared = dx * dx + dy * dy
            let minSeparation = pad.radius + candidateRadius + extraPadding
            let minSeparationSquared = minSeparation * minSeparation
            
            if distanceSquared < minSeparationSquared {
                return true
            }
        }
        return false
    }
    
    /// Fast distance check with early termination for distant pads
    private func isOverlappingExistingWithEarlyExit(position: CGPoint, candidateRadius: CGFloat, lilyPads: [LilyPad], extraPadding: CGFloat = 12) -> Bool {
        let maxRadius = candidateRadius + extraPadding + GameConfig.maxLilyPadRadius
        let maxRadiusSquared = maxRadius * maxRadius
        
        for pad in lilyPads {
            let dx = position.x - pad.position.x
            let dy = position.y - pad.position.y
            
            // Early exit for obviously distant pads
            if abs(dx) > maxRadius || abs(dy) > maxRadius {
                continue
            }
            
            let distanceSquared = dx * dx + dy * dy
            
            // Early exit if definitely too far
            if distanceSquared > maxRadiusSquared {
                continue
            }
            
            // Only compute exact separation for close pads
            let minSeparation = pad.radius + candidateRadius + extraPadding
            let minSeparationSquared = minSeparation * minSeparation
            
            if distanceSquared < minSeparationSquared {
                return true
            }
        }
        return false
    }
}

// MARK: - Alternative 4: Quadtree Implementation

/// A quadtree for spatial partitioning of lily pads
/// More sophisticated than grid but potentially better for uneven distributions
class LilyPadQuadtree {
    private let bounds: CGRect
    private let maxObjectsPerNode: Int
    private let maxDepth: Int
    private var depth: Int
    
    private var objects: [LilyPad] = []
    private var nodes: [LilyPadQuadtree] = []
    
    init(bounds: CGRect, maxObjectsPerNode: Int = 10, maxDepth: Int = 5, depth: Int = 0) {
        self.bounds = bounds
        self.maxObjectsPerNode = maxObjectsPerNode
        self.maxDepth = maxDepth
        self.depth = depth
    }
    
    /// Insert a lily pad into the quadtree
    func insert(_ pad: LilyPad) {
        if !bounds.contains(pad.position) {
            return
        }
        
        if objects.count < maxObjectsPerNode || depth >= maxDepth {
            objects.append(pad)
            return
        }
        
        if nodes.isEmpty {
            split()
        }
        
        for node in nodes {
            node.insert(pad)
        }
    }
    
    /// Query lily pads within a circular region
    func query(center: CGPoint, radius: CGFloat) -> [LilyPad] {
        var result: [LilyPad] = []
        
        // Check if query circle intersects with this node's bounds
        let queryBounds = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        
        guard bounds.intersects(queryBounds) else {
            return result
        }
        
        // Add objects from this node that are within the radius
        for pad in objects {
            let dx = center.x - pad.position.x
            let dy = center.y - pad.position.y
            let distanceSquared = dx * dx + dy * dy
            
            if distanceSquared <= radius * radius {
                result.append(pad)
            }
        }
        
        // Recursively query child nodes
        for node in nodes {
            result.append(contentsOf: node.query(center: center, radius: radius))
        }
        
        return result
    }
    
    /// Clear all lily pads from the quadtree
    func clear() {
        objects.removeAll()
        nodes.removeAll()
    }
    
    private func split() {
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        let x = bounds.minX
        let y = bounds.minY
        
        nodes = [
            LilyPadQuadtree(bounds: CGRect(x: x, y: y, width: halfWidth, height: halfHeight), 
                           maxObjectsPerNode: maxObjectsPerNode, maxDepth: maxDepth, depth: depth + 1),
            LilyPadQuadtree(bounds: CGRect(x: x + halfWidth, y: y, width: halfWidth, height: halfHeight), 
                           maxObjectsPerNode: maxObjectsPerNode, maxDepth: maxDepth, depth: depth + 1),
            LilyPadQuadtree(bounds: CGRect(x: x, y: y + halfHeight, width: halfWidth, height: halfHeight), 
                           maxObjectsPerNode: maxObjectsPerNode, maxDepth: maxDepth, depth: depth + 1),
            LilyPadQuadtree(bounds: CGRect(x: x + halfWidth, y: y + halfHeight, width: halfWidth, height: halfHeight), 
                           maxObjectsPerNode: maxObjectsPerNode, maxDepth: maxDepth, depth: depth + 1)
        ]
        
        // Redistribute objects to child nodes
        for obj in objects {
            for node in nodes {
                node.insert(obj)
            }
        }
        objects.removeAll()
    }
}