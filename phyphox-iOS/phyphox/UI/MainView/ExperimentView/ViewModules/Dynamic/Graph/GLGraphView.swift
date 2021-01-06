//
//  GLGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 21.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit
import GLKit
import OpenGLES

final class GLGraphView: GLKView {
    private let shader: GLGraphShaderProgram
    private let mapShader: GLMapShaderProgram
    
    private var vbo: GLuint = 0

    // Values used to transform the input values on the xy Plane into NDCs.
    private var xScale: GLfloat = 1.0
    private var yScale: GLfloat = 1.0
    private var zScale: GLfloat = 1.0
    
    private var min = GraphPoint3D<Double>.zero
    private var max = GraphPoint3D<Double>.zero
    
    private var mapIndexBuffer: UnsafeMutablePointer<GLuint>?
    private var mapIndexBufferSize: UInt = 0
    private var mapIB: GLuint = 0
    
    var lineWidth: [GLfloat] = [2.0] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var style: [GraphViewDescriptor.GraphStyle] = [.lines] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var lineColor: [GLcolor] = [GLcolor(r: 1.0, g: 1.0, b: 1.0, a: 1.0)] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var historyLength: UInt = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var mapWidth: UInt = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var timeOnX: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var timeOnY: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var systemTime: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var linearTime: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var mapTexture: GLuint = 0;
    var colorMap: [UIColor] = [] {
        didSet {
            let textureData = UnsafeMutablePointer<GLubyte>.allocate(capacity: colorMap.count*3)
            for (i, color) in colorMap.enumerated() {
                (textureData + 3*i).initialize(to: color.redByte)
                (textureData + 3*i+1).initialize(to: color.greenByte)
                (textureData + 3*i+2).initialize(to: color.blueByte)
            }
            
            if mapTexture == 0 {
                glGenTextures(GLsizei(1), &mapTexture)
            }
            glBindTexture(GLenum(GL_TEXTURE_2D), mapTexture)
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGB, GLsizei(colorMap.count), 1, 0, GLenum(GL_RGB), GLenum(GL_UNSIGNED_BYTE), textureData)
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLint(GL_LINEAR))
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLint(GL_LINEAR))
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLint(GL_CLAMP_TO_EDGE))
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLint(GL_CLAMP_TO_EDGE))
            glBindTexture(GLenum(GL_TEXTURE_2D), 0)

            textureData.deallocate()
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
        
        shader = GLGraphShaderProgram()
        mapShader = GLMapShaderProgram()
        
        self.points2D = []
        self.points3D = []
        self.timeReferenceSets = []
        
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
    
    private var points2D: [[GraphPoint2D<GLfloat>]]
    private var points3D: [[GraphPoint3D<GLfloat>]]
    private var timeReferenceSets: [[TimeReferenceSet]]
    
    func setPoints(points2D: [[GraphPoint2D<GLfloat>]], points3D: [[GraphPoint3D<GLfloat>]], min: GraphPoint3D<Double>, max: GraphPoint3D<Double>, timeReferenceSets: [[TimeReferenceSet]]) {
        self.points2D = points2D
        self.points3D = points3D
        self.timeReferenceSets = timeReferenceSets

        xScale = GLfloat(2.0/(max.x-min.x))
        yScale = GLfloat(2.0/(max.y-min.y))
        zScale = GLfloat(2.0/(max.z-min.z))
        
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
    
    private func prepareIndexBuffer(mapWidth: UInt, requiredIBSize: UInt) {
        if mapIB == 0 {
            glGenBuffers(GLsizei(1), &mapIB)
        }
        
        if requiredIBSize < 4 {
            return
        }
        if mapIndexBufferSize == 0 || requiredIBSize > mapIndexBufferSize {
            let newBuffer = UnsafeMutablePointer<GLuint>.allocate(capacity: Int(requiredIBSize))
            if let oldBuffer = mapIndexBuffer {
                newBuffer.moveInitialize(from: oldBuffer, count: Int(mapIndexBufferSize))
                oldBuffer.deallocate()
            }
            mapIndexBuffer = newBuffer
            
            for i in (mapIndexBufferSize/2)..<(requiredIBSize/2) {
                let line = i / (mapWidth + 1)
                let x = i % (mapWidth + 1)
                let index = Int(2*i)
                if x == mapWidth {
                    (mapIndexBuffer! + index).initialize(to: GLuint((line+1) * mapWidth + (x-1)))
                    (mapIndexBuffer! + index + 1).initialize(to: GLuint((line+1) * mapWidth))
                } else {
                    (mapIndexBuffer! + index).initialize(to: GLuint(line * mapWidth + x))
                    (mapIndexBuffer! + index + 1).initialize(to: GLuint((line+1) * mapWidth + x))
                }
            }
            
            mapIndexBufferSize = requiredIBSize
            
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), mapIB)
            glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), GLsizeiptr(mapIndexBufferSize * 4), mapIndexBuffer, GLenum(GL_DYNAMIC_DRAW))
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
        }
    }
    
    private func render() {
        EAGLContext.setCurrent(context)
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        let nSets = points2D.count
        
        if nSets == 0 {
            return
        }
        
        if yScale == 0.0 {
            yScale = 0.1
        }
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        
        let xTranslation = GLfloat(-min.x-(max.x-min.x)/2.0)
        let yTranslation = GLfloat(-min.y-(max.y-min.y)/2.0)
        let zTranslation = GLfloat(-min.z-(max.z-min.z)/2.0)
        
        if style[0] == .map {
            mapShader.use()

            mapShader.setScale(xScale, yScale, zScale)
            mapShader.setTranslation(xTranslation, yTranslation, zTranslation)
            
            let p = points3D[0]
            let length = p.count
            
            if length > 0 && mapWidth > 0 {
                let lines = (UInt(length)/mapWidth-1)
                let verticesPerLine = (2*mapWidth+2)
                let requiredIBSize = lines * verticesPerLine
                
                prepareIndexBuffer(mapWidth: mapWidth, requiredIBSize: requiredIBSize)
                
                if requiredIBSize > 0 {
                
                    glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(length * MemoryLayout<GraphPoint3D<GLfloat>>.size), p, GLenum(GL_DYNAMIC_DRAW))
                
                    glActiveTexture(GLenum(GL_TEXTURE0))
                    glBindTexture(GLenum(GL_TEXTURE_2D), mapTexture)
                    
                    glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), mapIB)
                    mapShader.drawElements(mode: GL_TRIANGLE_STRIP, start: 0, count: Int(requiredIBSize))
                    glBindTexture(GLenum(GL_TEXTURE_2D), 0)
                    glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
                }
            }
            
        } else {
        
            shader.use()
            
            shader.setScale(xScale, yScale)
            
            for i in (0..<points2D.count).reversed() {
                
                let p = points2D[i]
                let length = p.count
                
                if length == 0 {
                    continue
                }
                
                glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(length * MemoryLayout<GraphPoint2D<GLfloat>>.size), p, GLenum(GL_DYNAMIC_DRAW))
                
                let renderMode: Int32
                if historyLength > 1 {
                    shader.setPointSize(lineWidth[0])
                    glLineWidth(lineWidth[0])
                    if (i == nSets-1) {
                        shader.setColor(lineColor[0].r, lineColor[0].g, lineColor[0].b, lineColor[0].a)
                    } else {
                        shader.setColor(1.0, 1.0, 1.0, (Float(i)+1.0)*0.6/Float(historyLength))
                    }
                    switch style[0] {
                        case .dots: renderMode = GL_POINTS
                        case .vbars: renderMode = GL_TRIANGLE_STRIP
                        case .hbars: renderMode = GL_TRIANGLE_STRIP
                        default: renderMode = GL_LINE_STRIP
                    }
                } else {
                    shader.setPointSize(lineWidth[i])
                    glLineWidth(lineWidth[i])
                    shader.setColor(lineColor[i].r, lineColor[i].g, lineColor[i].b, lineColor[i].a)
                    switch style[i] {
                        case .dots: renderMode = GL_POINTS
                        case .vbars: renderMode = GL_TRIANGLES
                        case .hbars: renderMode = GL_TRIANGLES
                        default: renderMode = GL_LINE_STRIP
                    }
                }
                if timeOnX {
                    for timeReferenceSet in timeReferenceSets[i] {
                        let xOffset: Float
                        if systemTime && !linearTime {
                            xOffset = Float(timeReferenceSet.totalPauseGap)
                        } else if !systemTime && linearTime {
                            if timeReferenceSet.isPaused {
                                continue
                            }
                            xOffset = -Float(timeReferenceSet.totalPauseGap)
                        } else {
                            xOffset = 0.0
                        }
                        shader.setTranslation(xTranslation + xOffset, yTranslation)
                        shader.drawPositions(mode: renderMode, start: timeReferenceSet.index, count: timeReferenceSet.count, strideFactor: 1)
                    }
                } else if timeOnY {
                    for timeReferenceSet in timeReferenceSets[i] {
                        let yOffset: Float
                        if systemTime && !linearTime {
                            yOffset = Float(timeReferenceSet.totalPauseGap)
                        } else if !systemTime && linearTime {
                            if timeReferenceSet.isPaused {
                                continue
                            }
                            yOffset = -Float(timeReferenceSet.totalPauseGap)
                        } else {
                            yOffset = 0.0
                        }
                        shader.setTranslation(xTranslation, yTranslation + yOffset)
                        shader.drawPositions(mode: renderMode, start: timeReferenceSet.index, count: timeReferenceSet.count, strideFactor: 1)
                    }
                } else {
                    shader.setTranslation(xTranslation, yTranslation)
                    shader.drawPositions(mode: renderMode, start: 0, count: length, strideFactor: 1)
                }
            }
        }
    }

    deinit {
        mapIndexBuffer?.deallocate()
        glDeleteBuffers(1, &vbo)
    }
}
