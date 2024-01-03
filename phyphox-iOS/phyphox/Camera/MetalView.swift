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
    
    func makeUIView(context: UIViewRepresentableContext<CameraMetalView>) -> MTKView {
        print("MetalView: makeUIView")
        //metalView.delegate = context.coordinator
    
        metalView.preferredFramesPerSecond = 60
        
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            metalView.device = metalDevice
        }
        
        metalView.preferredFramesPerSecond = 60

        //metalView.framebufferOnly = false
        
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
       
        metalView.drawableSize = metalView.frame.size
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<CameraMetalView>) {
        
    }
    
}

