//
//  GLGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 21.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit
import GLKit
import OpenGLES

struct GLpoint {
    var x: GLfloat
    var y: GLfloat
}

class GLGraphView: GLKView {
    private let baseEffect = GLKBaseEffect()
    private var vbo: GLuint = 0
    
    override convenience init(frame: CGRect) {
        self.init(frame: frame, context: EAGLContext(API: .OpenGLES2))
    }
    
    convenience init() {
        self.init(frame: .zero)
    }

    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
    
    override init(frame: CGRect, context: EAGLContext) {
        super.init(frame: frame, context: context)
        
        baseEffect.useConstantColor = GLboolean(GL_TRUE)
        
        self.drawableColorFormat = .RGBA8888
        self.drawableDepthFormat = .Format24
        self.drawableStencilFormat = .Format8
        self.drawableMultisample = .Multisample4X //Anti aliasing
        self.opaque = false
        self.enableSetNeedsDisplay = true
        
        EAGLContext.setCurrentContext(context)
        
        //Background color & line color
        glClearColor(0.0, 0.0, 0.0, 0.0)
        baseEffect.constantColor = GLKVector4Make(0.0, 0.0, 0.0, 1.0)
        
        glGenBuffers(1, &vbo)
    }
    
    private var points: UnsafePointer<GLpoint>!
    private var length: UInt!
    
    private var xscale: Float = 0.0
    private var yscale: Float = 0.0
    
    private var min: GLpoint!
    private var max: GLpoint!
    
    func setPoints(p: UnsafePointer<GLpoint>, length: UInt, min: GLpoint, max: GLpoint) {
        if length == 0 {
            return
        }
        
        points = p
        self.length = length
        
        EAGLContext.setCurrentContext(context)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo);
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(length * UInt(sizeof(GLpoint))), points, GLenum(GL_DYNAMIC_DRAW))
        
        xscale = 2.0/(max.x-min.x)
        yscale = 2.0/(max.y-min.y)
        
        self.max = max
        self.min = min
        
        setNeedsDisplay()
    }
    
    override func drawRect(rect: CGRect) {
        draw()
    }
    
    internal func draw() {
        if length == nil {
            return
        }
        
        EAGLContext.setCurrentContext(context)
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        var transform = GLKMatrix4MakeScale(xscale, yscale, 1.0)
        transform = GLKMatrix4Translate(transform, -min.x-(max.x-min.x)/2.0, -min.y-(max.y-min.y)/2.0, 0.0)
        baseEffect.transform.projectionMatrix = transform
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo);
        baseEffect.prepareToDraw()
        
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue));
        glVertexAttribPointer(GLuint(GLKVertexAttrib.Position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_TRUE), GLsizei(sizeof(GLpoint)), nil)
        glLineWidth(2.0)
        glDrawArrays(GLenum(GL_LINE_STRIP), 0, GLsizei(length))
    }
}
