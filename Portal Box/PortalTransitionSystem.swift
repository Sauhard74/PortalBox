//
//  PortalTransitionSystem.swift
//  Portal Box
//
//  Created by You on the current date
//

import RealityKit
import SwiftUI

// Portal Transition System
class PortalTransitionSystem {
    // Reference to all worlds for transitions
    var allWorlds: [Entity] = []
    
    // Method to set all worlds for the transition system
    func setWorlds(_ worlds: [Entity]) {
        self.allWorlds = worlds
    }
    
    func handlePortalTransition(portal: Entity, targetWorld: Entity) {
        // Disable this portal's transition temporarily to prevent multiple transitions
        portal.components[PortalTransitionComponent.self]?.isActive = false
        
        // Create transition effect
        let effect = createPortalTransitionEffect()
        portal.addChild(effect)
        
        // Perform the world transition
        transitionToWorld(targetWorld)
        
        // Re-enable transition after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            portal.components[PortalTransitionComponent.self]?.isActive = true
            effect.removeFromParent()
        }
    }
    
    private func transitionToWorld(_ targetWorld: Entity) {
        // Hide all worlds
        for world in allWorlds {
            world.isEnabled = false
        }
        
        // Show only the target world
        targetWorld.isEnabled = true
    }
    
    private func createPortalTransitionEffect() -> Entity {
        let effect = Entity()
        
        // Create particle effect for portal transition
        let particlesMesh = MeshResource.generateSphere(radius: 0.1)
        let particlesMaterial = UnlitMaterial(color: .white)
        let particlesEntity = ModelEntity(mesh: particlesMesh, materials: [particlesMaterial])
        
        // Add animation - simplified version without AnimationResource.move
        var transform = particlesEntity.transform
        transform.scale = [3, 3, 3]
        transform.rotation = simd_quatf(angle: .pi * 2, axis: [0, 1, 0])
        
        // Simple scale animation
        particlesEntity.scale = [0.1, 0.1, 0.1]
        
        // Animate using a timer instead of AnimationResource
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let currentScale = particlesEntity.scale
            let newScale = currentScale * 1.1
            particlesEntity.scale = newScale
            
            if newScale.x > 3.0 {
                timer.invalidate()
            }
        }
        
        effect.addChild(particlesEntity)
        return effect
    }
} 