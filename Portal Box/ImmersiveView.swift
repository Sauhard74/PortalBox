//
//  ImmersiveView.swift
//  Portal Box
//
//  Created by Sarang Borude on 8/10/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

// Portal Transition Component
struct PortalTransitionComponent: Component {
    var isActive: Bool = true
    var targetWorld: Entity
    var transitionDistance: Float = 0.3
}

// Portal Transition System
class PortalTransitionSystem: System {
    static let query = EntityQuery(where: .has(PortalTransitionComponent.self) && .has(CollisionComponent.self))
    
    // Reference to all worlds for transitions
    var allWorlds: [Entity] = []
    
    required init(scene: RealityKit.Scene) {}
    
    func update(context: SceneUpdateContext) {
        let entities = context.scene.performQuery(Self.query)
        
        for entity in entities {
            guard let transitionComponent = entity.components[PortalTransitionComponent.self],
                  transitionComponent.isActive,
                  let collisionEvents = entity.collision?.collisionEvents else {
                continue
            }
            
            for event in collisionEvents {
                if event.type == .began {
                    // Check if the colliding entity is the camera/user
                    if event.entityA.name == "Camera" || event.entityB.name == "Camera" {
                        handlePortalTransition(portal: entity, targetWorld: transitionComponent.targetWorld)
                    }
                }
            }
        }
    }
    
    private func handlePortalTransition(portal: Entity, targetWorld: Entity) {
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
        
        // Add animation
        var particlesTransform = particlesEntity.transform
        let animation = AnimationResource.move(
            from: particlesTransform,
            to: Transform(scale: [3, 3, 3], rotation: simd_quatf(angle: .pi * 2, axis: [0, 1, 0])),
            duration: 1.0,
            timingFunction: .easeInOut
        )
        
        particlesEntity.playAnimation(animation, transitionDuration: 0.5, startsPaused: false)
        
        effect.addChild(particlesEntity)
        return effect
    }
    
    // Method to set all worlds for the transition system
    func setWorlds(_ worlds: [Entity]) {
        self.allWorlds = worlds
    }
}

@MainActor
struct ImmersiveView: View {
    
    @State private var box = Entity() // to store our box
    
    @State private var world1 = Entity()
    @State private var world2 = Entity()
    @State private var world3 = Entity()
    @State private var world4 = Entity()
    
    // Store all worlds for easy access
    @State private var allWorlds: [Entity] = []
    
    // State for tracking gesture interaction
    @State private var isBoxGrabbed = false
    @State private var initialBoxPosition: SIMD3<Float>?
    
    var body: some View {
        RealityView { content, attachments in
            // Add the initial RealityKit content
            if let scene = try? await Entity(named: "PortalBoxScene", in: realityKitContentBundle) {
                content.add(scene)

                guard let box = scene.findEntity(named: "Box") else {
                    fatalError("Could not find Box entity in the scene")
                }
                
                // change the position and scale of the box
                self.box = box
                box.position = [0, 1, -2] // meters
                box.scale *= [1,2,1]
                
                // Make the box interactive
                makeBoxInteractive(box)
    
                let worlds = await createWorlds()
                content.add(worlds)
                
                // Store all worlds for transition system
                allWorlds = [world1, world2, world3, world4]
                
                let portals = createPortals()
                content.add(portals)
                
                await addContentToWorlds()
                
                // Register the portal transition system
                let portalSystem = PortalTransitionSystem()
                portalSystem.setWorlds(allWorlds)
                
                // We can't directly access the scene's systems, so we'll use a different approach
                // Store the system reference and manually call it in a timer
                setupPortalSystem(portalSystem, in: content)
            }
        }
        .gesture(
            // Add a pinch gesture to move the box
            DragGesture()
                .targetedToEntity(box)
                .onChanged { value in
                    if !isBoxGrabbed {
                        isBoxGrabbed = true
                        initialBoxPosition = box.position
                    }
                    
                    // Calculate new position based on drag
                    if let initialPosition = initialBoxPosition {
                        // Convert the translation to SIMD3<Float>
                        let translation = SIMD3<Float>(
                            Float(value.translation.width) * 0.01,
                            Float(value.translation.height) * -0.01, // Invert Y axis
                            0 // Keep Z unchanged for simplicity
                        )
                        box.position = initialPosition + translation
                    }
                }
                .onEnded { _ in
                    isBoxGrabbed = false
                    initialBoxPosition = nil
                }
        )
    }
    
    private func setupPortalSystem(_ system: PortalTransitionSystem, in content: RealityViewContent) {
        // We'll manually check for collisions between portals and the camera
        // This is a workaround since we can't directly register the system with the scene
        
        // Create a timer to periodically check for collisions
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Find all portals
            for portal in findAllPortals(in: content) {
                guard let transitionComponent = portal.components[PortalTransitionComponent.self],
                      transitionComponent.isActive else {
                    continue
                }
                
                // Check if camera is close to the portal
                // This is a simplified collision detection
                if isCameraCloseToPortal(portal) {
                    system.handlePortalTransition(portal: portal, targetWorld: transitionComponent.targetWorld)
                }
            }
        }
        
        // Store the timer somewhere to prevent it from being deallocated
        // For simplicity, we're not handling timer cleanup here
    }
    
    private func findAllPortals(in content: RealityViewContent) -> [Entity] {
        // Find all entities with PortalTransitionComponent
        var portals: [Entity] = []
        
        // Check world1Portal through world4Portal
        if let portal1 = box.findEntity(named: "Portal1"),
           portal1.components[PortalTransitionComponent.self] != nil {
            portals.append(portal1)
        }
        
        if let portal2 = box.findEntity(named: "Portal2"),
           portal2.components[PortalTransitionComponent.self] != nil {
            portals.append(portal2)
        }
        
        if let portal3 = box.findEntity(named: "Portal3"),
           portal3.components[PortalTransitionComponent.self] != nil {
            portals.append(portal3)
        }
        
        if let portal4 = box.findEntity(named: "Portal4"),
           portal4.components[PortalTransitionComponent.self] != nil {
            portals.append(portal4)
        }
        
        return portals
    }
    
    private func isCameraCloseToPortal(_ portal: Entity) -> Bool {
        // This is a simplified collision detection
        // In a real app, you would use proper collision detection
        
        // Get the camera position (this is an approximation)
        // In a real app, you would get the actual camera position
        let cameraPosition = SIMD3<Float>(0, 0, 0) // Origin as approximation
        
        // Calculate distance between camera and portal
        let distance = simd_distance(cameraPosition, portal.position)
        
        // Check if camera is close enough to the portal
        return distance < 0.5 // Threshold in meters
    }
    
    private func makeBoxInteractive(_ box: Entity) {
        // Add an input target component to make it interactive
        box.components.set(InputTargetComponent())
    }
    
    func createWorlds() async -> Entity {
        let worlds = Entity()
        
        //Make world 1
        world1 = Entity()
        world1.name = "World1"
        world1.components.set(WorldComponent())
        let skybox1 = await createSkyboxEntity(texture: "skybox1")
        world1.addChild(skybox1)
        worlds.addChild(world1)
        
        //Make world 2
        world2 = Entity()
        world2.name = "World2"
        world2.components.set(WorldComponent())
        let skybox2 = await createSkyboxEntity(texture: "skybox2")
        world2.addChild(skybox2)
        worlds.addChild(world2)
        
        //Make world 3
        world3 = Entity()
        world3.name = "World3"
        world3.components.set(WorldComponent())
        let skybox3 = await createSkyboxEntity(texture: "skybox3")
        world3.addChild(skybox3)
        worlds.addChild(world3)
        
        //Make world 4
        world4 = Entity()
        world4.name = "World4"
        world4.components.set(WorldComponent())
        let skybox4 = await createSkyboxEntity(texture: "skybox4")
        world4.addChild(skybox4)
        worlds.addChild(world4)
        
        // Initially hide all worlds except the first one
        world2.isEnabled = false
        world3.isEnabled = false
        world4.isEnabled = false
        
        return worlds
    }
    
    func createPortals() -> Entity {
        /// Create 4 portals
        let portals = Entity()
        
        let world1Portal = createPortal(target: world1)
        world1Portal.name = "Portal1"
        portals.addChild(world1Portal)
        guard let anchorPortal1 = box.findEntity(named: "AnchorPortal1") else {
            fatalError("Cannot find portal anchor 1")
        }
        anchorPortal1.addChild(world1Portal)
        world1Portal.transform.rotation = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
        
        let world2Portal = createPortal(target: world2)
        world2Portal.name = "Portal2"
        portals.addChild(world2Portal)
        guard let anchorPortal2 = box.findEntity(named: "AnchorPortal2") else {
            fatalError("Cannot find portal anchor 2")
        }
        anchorPortal2.addChild(world2Portal)
        world2Portal.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        
        let world3Portal = createPortal(target: world3)
        world3Portal.name = "Portal3"
        portals.addChild(world3Portal)
        guard let anchorPortal3 = box.findEntity(named: "AnchorPortal3") else {
            fatalError("Cannot find portal anchor 3")
        }
        anchorPortal3.addChild(world3Portal)
        
        let portal3RotX = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
        let portal3RotY = simd_quatf(angle: -.pi/2, axis: [0, 1, 0])
        world3Portal.transform.rotation = portal3RotY * portal3RotX // ORDER Matters!!!!
        
        let world4Portal = createPortal(target: world4)
        world4Portal.name = "Portal4"
        portals.addChild(world4Portal)
        guard let anchorPortal4 = box.findEntity(named: "AnchorPortal4") else {
            fatalError("Cannot find portal anchor 4")
        }
        anchorPortal4.addChild(world4Portal)
        
        let portal4RotX = simd_quatf(angle: .pi/2, axis: [1, 0, 0])
        let portal4RotY = simd_quatf(angle: .pi/2, axis: [0, 1, 0])
        world4Portal.transform.rotation = portal4RotY * portal4RotX// ORDER Matters!!!!
        
        return portals
    }
    
    func createPortal(target: Entity) -> Entity {
        let portalMesh = MeshResource.generatePlane(width:1, depth:1) // meters
        let portalMaterial = createPortalMaterial()
        let portal = ModelEntity(mesh: portalMesh, materials: [portalMaterial])
        portal.components.set(PortalComponent(target: target))
        
        // Add transition component
        portal.components.set(PortalTransitionComponent(targetWorld: target))
        
        return portal
    }
    
    func createPortalMaterial() -> RealityKit.Material {
        var material = SimpleMaterial(color: .white.withAlphaComponent(0.5), isMetallic: false)
        material.roughness = 1.0
        return material
    }
    
    func addContentToWorlds() async {
        // Add more content to the worlds
        
        if let world1Scene = try? await Entity(named: "World1Scene", in: realityKitContentBundle) {
            world1Scene.position = [0, 3, 0]
            world1.addChild(world1Scene)
        }
        
        if let world2Scene = try? await Entity(named: "World2Scene", in: realityKitContentBundle) {
            world2Scene.position = [0, 3, 0]
            world2.addChild(world2Scene)
        }
        
        if let world3Scene = try? await Entity(named: "World3Scene", in: realityKitContentBundle) {
            world3Scene.position = [0, 10, 0]
            world3.addChild(world3Scene)
        }
        
        if let world4Scene = try? await Entity(named: "World4Scene", in: realityKitContentBundle) {
            world4Scene.position = [0, 10, 0]
            world4.addChild(world4Scene)
        }
    }
    
    func createSkyboxEntity(texture: String) async -> Entity {
        // Try to load the texture resource
        let resource: TextureResource
        do {
            resource = try await TextureResource(named: texture)
        } catch {
            print("Error loading skybox texture \(texture): \(error)")
            // Fallback to a solid color if texture loading fails
            let entity = Entity()
            var material = UnlitMaterial(color: .blue)
            entity.components.set(ModelComponent(mesh: .generateSphere(radius: 1000), materials: [material]))
            entity.scale *= .init(x: -1, y: 1, z: 1)
            return entity
        }
        
        var material = UnlitMaterial()
        material.color = .init(texture: .init(resource))
        
        let entity = Entity()
        entity.components.set(ModelComponent(mesh: .generateSphere(radius: 1000), materials: [material]))
        entity.scale *= .init(x: -1, y: 1, z: 1)
        return entity
    }
}

// Define PortalMaterial if it's not already defined elsewhere
struct PortalMaterial: Material {
    var roughness: Float = 1.0
    var metallic: Float = 0.0
    var tintColor: UIColor = .white.withAlphaComponent(0.5)
    var tintOpacity: Float = 0.5
}

// SIMD3 extension for vector addition
extension SIMD3 where Scalar == Float {
    static func + (left: SIMD3<Float>, right: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(left.x + right.x, left.y + right.y, left.z + right.z)
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
}

