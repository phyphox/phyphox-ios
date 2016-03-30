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

public struct GraphPoint<T> {
    var x: T
    var y: T
}

public struct GLcolor {
    var r, g, b, a: Float
}

final class GLGraphView: GLKView {
    private let baseEffect = GLKBaseEffect()
    private var vbo: GLuint = 0
    
    private var length = 0
    
    private var xScale: Float = 0.0
    private var yScale: Float = 0.0
    
    private var min: GraphPoint<Double>!
    private var max: GraphPoint<Double>!
    
    var lineWidth: GLfloat = 2.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var drawDots: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var lineColor: GLcolor = GLcolor(r: 0.0, g: 0.0, b: 0.0, a: 1.0) {
        didSet {
            baseEffect.constantColor = GLKVector4Make(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
            
            setNeedsDisplay()
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
    
    #if DEBUG
    var points: [GraphPoint<GLfloat>]?
    #endif
    
    func setPoints(p: [GraphPoint<GLfloat>], min: GraphPoint<Double>, max: GraphPoint<Double>) {
        #if DEBUG
            points = p
        #endif
        length = p.count
        
        if length == 0 {
            setNeedsDisplay()
            return
        }
        
        EAGLContext.setCurrentContext(context)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo);
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(length * sizeof(GraphPoint<GLfloat>)), p, GLenum(GL_DYNAMIC_DRAW))
        
        xScale = Float(2.0/(max.x-min.x))
        
        let dataPerPixelY = Float((max.y-min.y)/Double(self.bounds.size.height))
        let biasDataY = lineWidth*dataPerPixelY
        
        yScale = Float(2.0/(Float(max.y-min.y)+biasDataY))
        
        self.max = max
        self.min = min
        
        setNeedsDisplay()
    }
    
    override func drawRect(rect: CGRect) {
        render()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        setNeedsDisplay()
    }
    
    internal func render() {
        if length == 0 {
            return
        }
        
        EAGLContext.setCurrentContext(context)
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
//        glHint(GLenum(GL_POINT_SMOOTH_HINT), GLenum(GL_NICEST))
//        glHint(GLenum(GL_LINE_SMOOTH_HINT), GLenum(GL_NICEST))
        
        glDisable(GLenum(GL_DEPTH_TEST))
        
//        glEnable(GLenum(GL_MULTISAMPLE))
//        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
//        glEnable(GLenum(GL_BLEND))
        
        glLineWidth(lineWidth)
//        glPointSize(lineWidth)
        
        if yScale == 0.0 {
            yScale = 0.1
        }
        
        var transform = GLKMatrix4MakeScale(xScale, yScale, 1.0)
        
        let xTranslaiton = Float(-min.x-(max.x-min.x)/2.0)
        let yTranslation = Float(-min.y-(max.y-min.y)/2.0)
        
        transform = GLKMatrix4Translate(transform, xTranslaiton, yTranslation, 0.0)
        baseEffect.transform.projectionMatrix = transform
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        baseEffect.prepareToDraw()
        
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue));
        glVertexAttribPointer(GLuint(GLKVertexAttrib.Position.rawValue), 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GraphPoint<GLfloat>)), nil)
        
        glDrawArrays(GLenum((drawDots ? GL_POINTS : GL_LINE_STRIP)), 0, GLsizei(length))
    }
}
