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

struct GLcolor {
    var r, g, b, a: Float
}
class GLGraphView: GLKView {
    private let baseEffect = GLKBaseEffect()
    private var vbo: GLuint = 0
    
    var lineWidth: GLfloat = 2.0
    var lineColor: GLcolor = GLcolor(r: 0.0, g: 0.0, b: 0.0, a: 1.0) {
        didSet {
            baseEffect.constantColor = GLKVector4Make(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
        }
    }
    
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
        baseEffect.constantColor = GLKVector4Make(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
        
        glGenBuffers(1, &vbo)
    }
    
    private var points: [GLpoint]!
    private var length: UInt!
    
    private var xScale: Float = 0.0
    private var yScale: Float = 0.0
    
    private var min: GLpoint!
    private var max: GLpoint!
    
    func setPoints(p: [GLpoint], length: UInt, min: GLpoint, max: GLpoint) {
        points = p
        self.length = length
        
        if length == 0 {
            setNeedsDisplay()
            return
        }
        
        EAGLContext.setCurrentContext(context)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo);
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(length * UInt(sizeof(GLpoint))), UnsafePointer(points), GLenum(GL_DYNAMIC_DRAW))
        
        xScale = 2.0/(max.x-min.x)
        
        let dataPerPixelY = (max.y-min.y)/GLfloat(self.bounds.size.height)
        let biasDataY = lineWidth*dataPerPixelY
        
        yScale = 2.0/((max.y-min.y)+biasDataY)
        
        self.max = max
        self.min = min
        
        setNeedsDisplay()
    }
    
    override func drawRect(rect: CGRect) {
        draw()
    }
    
    internal func draw() {
        if length == nil || length! == 0 {
            return
        }
        
        EAGLContext.setCurrentContext(context)
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        glDisable(GLenum(GL_DEPTH_TEST))

//        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
//        glEnable(GLenum(GL_BLEND))
        
        glLineWidth(lineWidth)
        
        var transform = GLKMatrix4MakeScale(xScale, yScale, 1.0)
        transform = GLKMatrix4Translate(transform, -min.x-(max.x-min.x)/2.0, -min.y-(max.y-min.y)/2.0, 0.0)
        baseEffect.transform.projectionMatrix = transform
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        baseEffect.prepareToDraw()
        
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue));
        glVertexAttribPointer(GLuint(GLKVertexAttrib.Position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GLpoint)), nil)
        
        glDrawArrays(GLenum(GL_LINE_STRIP), 0, GLsizei(length))
    }
}
