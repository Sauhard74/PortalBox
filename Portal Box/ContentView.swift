//
//  ContentView.swift
//  Portal Box
//
//  Created by Sauhard Gupta on 17/03/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {

    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    var body: some View {
        VStack {
            Model3D(named: "Scene", bundle: realityKitContentBundle)
                .padding(.bottom, 50)

            Text("Portal Box")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            Text("Experience multiple worlds through magical portals")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 30)

            Button(action: {
                showImmersiveSpace.toggle()
            }) {
                Text(showImmersiveSpace ? "Exit Portal Experience" : "Enter Portal Experience")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding()
                    .frame(width: 300)
                    .background(showImmersiveSpace ? Color.red.opacity(0.7) : Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .padding(.bottom, 20)
            
            Text("Instructions:")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.top, 10)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("• Walk through the portals to travel between worlds")
                Text("• Each side of the box leads to a different world")
                Text("• Explore each world's unique environment")
                Text("• Use pinch and drag gestures to move the box")
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
        .padding()
        .onChange(of: showImmersiveSpace) { _, newValue in
            Task {
                if newValue {
                    switch await openImmersiveSpace(id: "ImmersiveSpace") {
                    case .opened:
                        immersiveSpaceIsShown = true
                    case .error, .userCancelled:
                        fallthrough
                    @unknown default:
                        immersiveSpaceIsShown = false
                        showImmersiveSpace = false
                    }
                } else if immersiveSpaceIsShown {
                    await dismissImmersiveSpace()
                    immersiveSpaceIsShown = false
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}

