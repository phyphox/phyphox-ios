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

struct GraphPoint<T: Numeric> {
    var x: T
    var y: T
}

extension GraphPoint {
    static var zero: GraphPoint {
        return GraphPoint(x: 0, y: 0)
    }
}

struct GLcolor {
    var r, g, b, a: Float
}

final class ShaderProgram {
    private let programHandle: GLuint
    
    private let positionAttributeHandle: GLuint
    private let translationUniformHandle: GLint
    private let scaleUniformHandle: GLint
    private let pointSizeUniformHandle: GLint
    private let colorUniformHandle: GLint
    
    init() {
        let vertexStr = try! String(contentsOfFile: Bundle.main.path(forResource: "VertexShader", ofType: "glsl")!)
        let fragmentStr = try! String(contentsOfFile: Bundle.main.path(forResource: "FragmentShader", ofType: "glsl")!)
        
        let vertexShady = vertexStr.cString(using: String.Encoding.utf8)!
        var vertexPointer:UnsafePointer<GLchar>? = UnsafePointer<GLchar>(vertexShady)
        
        let fragmentShady = fragmentStr.cString(using: String.Encoding.utf8)!
        var fragmentPointer:UnsafePointer<GLchar>? = UnsafePointer<GLchar>(fragmentShady)
        
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
    
    func setScale(_ x: GLfloat, _ y: GLfloat) {
        glUniform2f(scaleUniformHandle, x, y)
    }
    
    func setPointSize(_ size: GLfloat) {
        glUniform1f(pointSizeUniformHandle, size)
    }
    
    func setTranslation(_ x: GLfloat, _ y: GLfloat) {
        glUniform2f(translationUniformHandle, x, y)
    }
    
    func setColor(_ r: GLfloat, _ g: GLfloat, _ b: GLfloat, _ a: GLfloat) {
        glUniform4f(colorUniformHandle, r, g, b, a)
    }
    
    func drawPositions(mode: Int32, start: Int, count: Int) {
        glVertexAttribPointer(positionAttributeHandle, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GraphPoint<GLfloat>>.size), nil)

        glDrawArrays(GLenum(mode), GLint(start), GLsizei(count))
    }
}

final class GLGraphView: GLKView {
    private let shader: ShaderProgram
    
    private var vbo: GLuint = 0

    // Values used to transform the input values on the xy Plane into NDCs.
    private var xScale: GLfloat = 1.0
    private var yScale: GLfloat = 1.0
    
    private var min = GraphPoint<Double>.zero
    private var max = GraphPoint<Double>.zero
    
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
    
    var lineColor: GLcolor = GLcolor(r: 1.0, g: 1.0, b: 1.0, a: 1.0) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var historyLength: UInt = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override convenience init(frame: CGRect) {
        self.init(frame: frame, context: EAGLContext(api: .openGLES2)!)
    }
    
    convenience init() {
        self.init(frame: .zero)
    }

    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
    
    override init(frame: CGRect, context: EAGLContext) {
        context.isMultiThreaded = true
        
        EAGLContext.setCurrent(context)
        
        shader = ShaderProgram()
        
        self.points = []
        
        super.init(frame: frame, context: context)
        
        self.drawableColorFormat = .RGBA8888

        // 2D drawing, no depth information needed
        self.drawableDepthFormat = .formatNone
        self.drawableStencilFormat = .formatNone

        self.drawableMultisample = .multisample4X
        self.isOpaque = false
        self.enableSetNeedsDisplay = true
        
        glClearColor(0.0, 0.0, 0.0, 0.0)
        
        glGenBuffers(1, &vbo)
    }
    
    private var points: [[GraphPoint<GLfloat>]]
    
    func setPoints(_ points: [[GraphPoint<GLfloat>]], min: GraphPoint<Double>, max: GraphPoint<Double>) {
        self.points = points

        xScale = GLfloat(2.0/(max.x-min.x))

        let dataPerPixelY = GLfloat((max.y-min.y)/Double(bounds.size.height))
        let biasDataY = lineWidth * dataPerPixelY

        yScale = GLfloat(2.0/(Float(max.y-min.y)+biasDataY))

        self.max = max
        self.min = min
        
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        render()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        setNeedsDisplay()
    }
    
    func render() {
        EAGLContext.setCurrent(context)
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        let nSets = points.count
        
        if nSets == 0 {
            return
        }
        
        if yScale == 0.0 {
            yScale = 0.1
        }
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        
        shader.use()
        
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        
        let xTranslation = GLfloat(-min.x-(max.x-min.x)/2.0)
        let yTranslation = GLfloat(-min.y-(max.y-min.y)/2.0)
        
        shader.setScale(xScale, yScale)
        shader.setTranslation(xTranslation, yTranslation)
        shader.setPointSize(lineWidth)
        
        glLineWidth(lineWidth)
        
        for (i,p) in points.enumerated() {
            let length = p.count
            
            if length == 0 {
                continue
            }
            
            glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(length * MemoryLayout<GraphPoint<GLfloat>>.size), p, GLenum(GL_DYNAMIC_DRAW))
            
            if (i == nSets-1) {
                shader.setColor(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
            } else {
                shader.setColor(1.0, 1.0, 1.0, (Float(i)+1.0)*0.6/Float(historyLength))
            }
            
            shader.drawPositions(mode: (drawDots ? GL_POINTS : GL_LINE_STRIP), start: 0, count: length)
        }
    }
}
