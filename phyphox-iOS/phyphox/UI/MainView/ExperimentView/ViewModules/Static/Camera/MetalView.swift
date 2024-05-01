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
       
        //Fix: As the imagebuffer width * height is 480 and 180, we need to set the drawable size of MTKView same. Else, the drawable size will be 1080 * 1256 (for example) and due to the large render buffer, the frame starts dropping. TODO: Need to test it and remove the hard dependency.
        
        //let h = metalView.drawableSize.height
        //let w = metalView.drawableSize.width
        //metalView.drawableSize = CGSize(width: w / 2, height: h / 2)
    
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: UIViewRepresentableContext<CameraMetalView>) {
        
    }
    
}

