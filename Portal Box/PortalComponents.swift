//
//  PortalComponents.swift
//  Portal Box
//
//  Created by You on the current date
//

import RealityKit
import SwiftUI

// Component for the portal window
struct PortalComponent: Component {
    var target: Entity
}

// Component for world identification
struct WorldComponent: Component {}

// Component for portal transitions
struct PortalTransitionComponent: Component {
    var isActive: Bool = true
    var targetWorld: Entity
    var transitionDistance: Float = 0.3 // Distance threshold to trigger transition
}

// Define PortalMaterial
struct PortalMaterial: Material {
    var roughness: Float = 1.0
    var metallic: Float = 0.0
    var tintColor: UIColor = .white.withAlphaComponent(0.5)
    var tintOpacity: Float = 0.5
} 