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
final class CameraModel{
    
    var x1: Float = 0.4
    var x2: Float = 0.6
    var y1: Float = 0.4
    var y2: Float = 0.6
    
    var panningIndexX: Int = 0
    var panningIndexY: Int = 0
    
    var modelGesture: GestureState = .none
    
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
    
    func initModel(model: CameraModel){
        service.initializeModel(model: model)
    }
    
    func endSession(){
        service.session.stopRunning()
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
    
    func pannned (locationY: CGFloat, locationX: CGFloat , state: GestureState) {
        let pr = CGPoint(x: locationX / metalView.metalView.frame.width, y: locationY / metalView.metalView.frame.height)
        let ps = pr.applying(metalRenderer.displayToCameraTransform)
        let x = Float(ps.x)
        let y = Float(ps.y)
        
        if state == .begin {
            let d11 = (x - x1)*(x - x1) + (y - y1)*(y -   y1)
            let d12 = (x - x1)*(x - x1) + (y - y2)*(y - y2)
            let d21 = (x - x2)*(x - x2) + (y - y1)*(y - y1)
            let d22 = (x - x2)*(x - x2) + (y - y2)*(y - y2)
            let dist:Float = 0.01
            if d11 < dist && d11 < d12 && d11 < d21 && d11 < d22 {
                panningIndexX = 1
                panningIndexY = 1
            } else if d12 < dist && d12 < d21 && d12 < d22 {
                panningIndexX = 1
                panningIndexY = 2
            } else if d21 < dist && d21 < d22 {
                panningIndexX = 2
                panningIndexY = 1
            } else if d22 < dist {
                panningIndexX = 2
                panningIndexY = 2
            } else {
                panningIndexX = 0
                panningIndexY = 0
            }
        } else if state == .end {
            if panningIndexX == 1 {
                x1 = x
            } else if panningIndexX == 2 {
                x2 = x
            }
            if panningIndexY == 1 {
                y1 = y
            } else if panningIndexY == 2 {
                y2 = y
            }
        } else {
            
        }
    }
    // 136 166
    // d11 = 136 - 0.4 * 136 - 0.4  + 166 - 0.4 * 166 - 0.4
    
    enum GestureState {
        case begin
        case end
        case none
    }
    
}

