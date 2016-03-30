//
//  MetalGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 24.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import MetalKit
import UIKit

@available(iOS 9.0, *)
final class MetalGraphView: MTKView {
    
    private var rps: MTLRenderPipelineState! = nil
    private let commandQueue: MTLCommandQueue
    private var vertex_buffer: MTLBuffer!
    
    private var xScale = 1.0
    private var yScale = 1.0
    
    private var min: (Double, Double) = (0, 0)
    private var max: (Double, Double) = (0, 0)
    
    private var length = 0
    
    override init(frame frameRect: CGRect, device: MTLDevice!) {
        precondition(device != nil)
        
        commandQueue = device.newCommandQueue()
        
        let library = device!.newDefaultLibrary()!
        let vertex_func = library.newFunctionWithName("vertex_func")
        let frag_func = library.newFunctionWithName("fragment_func")
        
        let rpld = MTLRenderPipelineDescriptor()
        rpld.vertexFunction = vertex_func
        rpld.fragmentFunction = frag_func
        rpld.colorAttachments[0].pixelFormat = .BGRA8Unorm
        rpld.sampleCount = 4
        
        do {
            try rps = device.newRenderPipelineStateWithDescriptor(rpld)
        } catch let error {
            print("Error: \(error)")
        }
        
        super.init(frame: frameRect, device: device)
        
        self.sampleCount = 4 //4x MSAA
        self.framebufferOnly = true
        self.colorPixelFormat = .BGRA8Unorm
        self.enableSetNeedsDisplay = true
        self.preferredFramesPerSecond = 0
        self.opaque = false
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required convenience init(coder: NSCoder) {
        self.init()
    }
    
    convenience init(frame: CGRect) {
        self.init(frame: frame, device: MTLCreateSystemDefaultDevice())
    }
    
    class func metalGraphAvailable() -> Bool {
        return MTLCreateSystemDefaultDevice() != nil// && iOS9
    }
    
    /*
     Points array must be: [x0, y0 ... xn, yn]
     */
    func setPoints(p: [Float], min: (Double, Double), max: (Double, Double)) {
        let data_size = p.count * sizeof(Float)
        vertex_buffer = device!.newBufferWithBytes(p, length: data_size, options: [])
        
        length = p.count/2
        
        xScale = 2.0/(max.0-min.0)
        yScale = 2.0/(max.1-min.1)
        
        self.min = min
        self.max = max
        
        setNeedsDisplay()
    }
    
    
    override func drawRect(rect: CGRect) {
        render()
    }
    
    func render() {
        if currentDrawable == nil || length == 0 {
            return
        }
        
        if let rpd = currentRenderPassDescriptor {
            rpd.colorAttachments[0].loadAction = .Clear
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
            
            let command_buffer = commandQueue.commandBuffer()
            
            let command_encoder = command_buffer.renderCommandEncoderWithDescriptor(rpd)
            
            let w = Double(rpd.colorAttachments[0].texture!.width)//*xScale
            let h = Double(rpd.colorAttachments[0].texture!.height)//*yScale
            
            //für [0.0, 2.0, 1.0, 0.0]
            // command_encoder.setViewport(MTLViewport(originX: -w*3.0, originY: 0.0, width: w*4.0, height: h*2*(max.0-min.0), znear: 0.0, zfar: 0.0))

            //Für [0.0, 1.0, 90.0, 0.0
            // command_encoder.setViewport(MTLViewport(originX: -w, originY: 0.0, width: 2.0*w, height: h*2.0*(max.0-min.0), znear: 0.0, zfar: 0.0))
            
            //This bullshit doesn't work
            command_encoder.setViewport(MTLViewport(originX: -w, originY: 0.0, width: 2*w, height: h, znear: 0.0, zfar: 0.0))
//            command_encoder.setScissorRect(MTLScissorRect(x: 0, y: 0, width: Int(w), height: Int(h)))
                
            command_encoder.setRenderPipelineState(rps)
            command_encoder.setVertexBuffer(vertex_buffer, offset: 0, atIndex: 0)
            command_encoder.drawPrimitives(.LineStrip, vertexStart: 0, vertexCount: length, instanceCount: 1)
            command_encoder.endEncoding()
            
            command_buffer.presentDrawable(currentDrawable!)
            command_buffer.commit()
        }
    }
    
}
