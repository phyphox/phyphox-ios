//
//  MetalView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 24.11.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation
import MetalKit
import SwiftUI


@available(iOS 13.0, *)
struct CameraMetalView: UIViewRepresentable {
    
    let metalView: MTKView = MTKView()
    
    
    func makeCoordinator() -> Coordinator {
        print("MetalView: makeCoordinator")
        return Coordinator(renderer: MetalRenderer(parent: self, renderer: metalView))
    
    func makeUIView(context: UIViewRepresentableContext<CameraMetalView>) -> MTKView {
        print("MetalView: makeUIView")
        metalView.delegate = context.coordinator
    
        metalView.preferredFramesPerSecond = 60
        //metalView.enableSetNeedsDisplay = true
        
        //metalView.framebufferOnly = false
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
       
        metalView.drawableSize = CGSize(width: 100.0, height: 100.0)
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<CameraMetalView>) {
        
    }
    
    
    
}

