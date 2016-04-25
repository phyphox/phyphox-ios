//
//  GLGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 21.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
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

private final class ShaderProgram {
    private let programHandle: GLuint
    
    private let positionAttributeHandle: GLuint
    private let translationUniformHandle: GLint
    private let scaleUniformHandle: GLint
    private let pointSizeUniformHandle: GLint
    private let colorUniformHandle: GLint
    
    init() {
        let vertexStr = try! String(contentsOfFile: NSBundle.mainBundle().pathForResource("VertexShader", ofType: "glsl")!)
        let fragmentStr = try! String(contentsOfFile: NSBundle.mainBundle().pathForResource("FragmentShader", ofType: "glsl")!)
        
        let vertexShady = vertexStr.cStringUsingEncoding(NSUTF8StringEncoding)!
        var vertexPointer = UnsafePointer<GLchar>(vertexShady)
        
        let fragmentShady = fragmentStr.cStringUsingEncoding(NSUTF8StringEncoding)!
        var fragmentPointer = UnsafePointer<GLchar>(fragmentShady)
        
        let vertexShader = glCreateShader(GLenum(GL_VERTEX_SHADER))
        glShaderSource(vertexShader, GLsizei(1), &vertexPointer, nil)
        glCompileShader(vertexShader)
        
        let fragmentShader = glCreateShader(GLenum(GL_FRAGMENT_SHADER))
        glShaderSource(fragmentShader, GLsizei(1), &fragmentPointer, nil)
        glCompileShader(fragmentShader)
        
        var compileSuccess: GLint = 0
        
        glGetShaderiv(vertexShader, GLenum(GL_COMPILE_STATUS), &compileSuccess)
        if (compileSuccess == GL_FALSE) {
            print("Failed to compile vertex shader!")
        }
        
        glGetShaderiv(fragmentShader, GLenum(GL_COMPILE_STATUS), &compileSuccess)
        if (compileSuccess == GL_FALSE) {
            print("Failed to compile fragment shader!")
        }
        
        programHandle = glCreateProgram()
        
        glAttachShader(programHandle, vertexShader)
        glAttachShader(programHandle, fragmentShader)
        
        glDeleteShader(vertexShader)
        glDeleteShader(fragmentShader)
        
        glLinkProgram(programHandle)
        
        positionAttributeHandle = GLuint(glGetAttribLocation(programHandle, "position"))
        scaleUniformHandle = GLint(glGetUniformLocation(programHandle, "scale"))
        pointSizeUniformHandle = GLint(glGetUniformLocation(programHandle, "pointSize"))
        translationUniformHandle = GLint(glGetUniformLocation(programHandle, "translation"))
        colorUniformHandle = GLint(glGetUniformLocation(programHandle, "inColor"))
        
        glEnableVertexAttribArray(positionAttributeHandle)
    }
    
    func use() {
        glUseProgram(programHandle)
    }
    
    func setScale(x: GLfloat, _ y: GLfloat) {
        glUniform2f(scaleUniformHandle, x, y)
    }
    
    func setPointSize(size: GLfloat) {
        glUniform1f(pointSizeUniformHandle, size)
    }
    
    func setTranslation(x: GLfloat, _ y: GLfloat) {
        glUniform2f(translationUniformHandle, x, y)
    }
    
    func setColor(r: GLfloat, _ g: GLfloat, _ b: GLfloat, _ a: GLfloat) {
        glUniform4f(colorUniformHandle, r, g, b, a)
    }
    
    func drawPositions(mode: Int32, _ count: Int) {
        glVertexAttribPointer(positionAttributeHandle, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(sizeof(GraphPoint<GLfloat>)), nil)
        
        glDrawArrays(GLenum(mode), 0, GLsizei(count))
    }
}

final class GLGraphView: GLKView {
    private let shader: ShaderProgram
    
    private var vbo: GLuint = 0
    
    private var length = 0
    
    private var xScale: GLfloat = 1.0
    private var yScale: GLfloat = 1.0
    
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
        context.multiThreaded = true
        
        EAGLContext.setCurrentContext(context)
        
        shader = ShaderProgram()
        
        super.init(frame: frame, context: context)
        
        self.drawableColorFormat = .RGBA8888
        self.drawableDepthFormat = .Format24
        self.drawableStencilFormat = .Format8
        self.drawableMultisample = .Multisample4X //Anti aliasing
        self.opaque = false
        self.enableSetNeedsDisplay = true
        
        glClearColor(0.0, 0.0, 0.0, 0.0)
        
        glGenBuffers(1, &vbo)
    }
    
    #if DEBUG
    var points: [GraphPoint<GLfloat>]?
    #endif
    
    func setPoints(p: [GraphPoint<GLfloat>]?, min: GraphPoint<Double>?, max: GraphPoint<Double>?) {
        #if DEBUG
            points = p
        #endif
        length = p?.count ?? 0
        
        if length == 0 {
            setNeedsDisplay()
            return
        }
        
        EAGLContext.setCurrentContext(context)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        
        if p != nil {
            glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(length * sizeof(GraphPoint<GLfloat>)), p!, GLenum(GL_DYNAMIC_DRAW))
        }
        else {
            glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(0), nil, GLenum(GL_DYNAMIC_DRAW))
        }
        
        if max != nil && min != nil {
            xScale = GLfloat(2.0/(max!.x-min!.x))
            
            let dataPerPixelY = GLfloat((max!.y-min!.y)/Double(bounds.size.height))
            let biasDataY = lineWidth*dataPerPixelY
            
            yScale = GLfloat(2.0/(Float(max!.y-min!.y)+biasDataY))
        }
        else {
            xScale = 1.0
            yScale = 1.0
        }
        
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
        EAGLContext.setCurrentContext(context)
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        if length == 0 {
            return
        }
        
        if yScale == 0.0 {
            yScale = 0.1
        }
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        
        shader.use()
        
//        glEnable(GLenum(GL_POINT_SMOOTH))
//        glEnable(GLenum(GL_LINE_SMOOTH))
//        glEnable(GLenum(GL_BLEND))
//        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        
        let xTranslation = GLfloat(-min.x-(max.x-min.x)/2.0)
        let yTranslation = GLfloat(-min.y-(max.y-min.y)/2.0)
        
        shader.setColor(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
        shader.setScale(xScale, yScale)
        shader.setTranslation(xTranslation, yTranslation)
        shader.setPointSize(lineWidth)
        
        glLineWidth(lineWidth)
        
        shader.drawPositions((drawDots ? GL_POINTS : GL_LINE_STRIP), length)
    }
}
