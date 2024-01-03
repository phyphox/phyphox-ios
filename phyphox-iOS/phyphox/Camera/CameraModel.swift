//
//  CameraModel.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 13.11.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation
import MetalKit

@available(iOS 14.0, *)
final class CameraModel: ObservableObject {
    private let service = CameraService()
    var metalView =  CameraMetalView()
   
    var metalRenderer: MetalRenderer
    var session: AVCaptureSession
    
    
    init() {
        self.session = service.session
        self.metalRenderer = MetalRenderer(parent: metalView, renderer: metalView.metalView)
    }

    
    func configure(){
        service.checkForPermisssion()
        service.configure()
        
        metalView.metalView.delegate = metalRenderer
        service.metalRender = metalRenderer
    }
    
    func getScale() -> CGFloat {
        service.zoomScale
    }
    
    func setScale(scale: CGFloat) {
        service.zoomScale = scale
    }
    
    func switchCamera(){
        service.changeCamera()
    }
    
    func getMetalView() -> MTKView {
        return service.metalView
    }
    
    func getCIImage() -> CGImage {
        return service.image!
    }
    
    func autoExposure() {}
    
    func shutterSpeed() {}
    
    func aperture() {}
    
    func iso() {}
   
    func exposure() {}
    
    func zoom() {}
    
    func whiteBalance() {}
    
}
