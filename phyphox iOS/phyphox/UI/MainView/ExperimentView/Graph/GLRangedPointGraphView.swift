//
//  GLRangedPointGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 08.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import UIKit
import GLKit
import OpenGLES

final class GLRangedPointGraphView: GLKView {
    private let shader: ShaderProgram

    private var vbo: GLuint
    private var indexVbo: GLuint

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

        var dataBuffer: GLuint = 0
        var indexBuffer: GLuint = 1

        glGenBuffers(1, &dataBuffer)
        glGenBuffers(1, &indexBuffer)

        self.vbo = dataBuffer
        self.indexVbo = indexBuffer
        
        super.init(frame: frame, context: context)

        self.drawableColorFormat = .RGBA8888

        // 2D drawing, no depth information needed
        self.drawableDepthFormat = .formatNone
        self.drawableStencilFormat = .formatNone

        self.drawableMultisample = .multisample4X
        self.isOpaque = false
        self.enableSetNeedsDisplay = true

        glClearColor(0.0, 0.0, 0.0, 0.0)
    }

    private var points: [GraphPoint<GLfloat>] = []

    private var outlinePoints: [GraphPoint<GLfloat>] = []

    private var triangleIndices: [GLuint] = []

    func setPoints(_ points: [RangedGraphPoint<Double>], min: GraphPoint<Double>, max: GraphPoint<Double>) {
        self.points = points.flatMap { point -> [GraphPoint<GLfloat>] in
            return [
                GraphPoint(x: GLfloat(point.xRange.lowerBound),
                           y: GLfloat(point.yRange.upperBound)),
                GraphPoint(x: GLfloat(point.xRange.lowerBound),
                           y: GLfloat(point.yRange.lowerBound)),
                GraphPoint(x: GLfloat(point.xRange.upperBound),
                           y: GLfloat(point.yRange.upperBound)),
                GraphPoint(x: GLfloat(point.xRange.upperBound),
                           y: GLfloat(point.yRange.lowerBound))
            ]
        }

        if drawDots {
            let startIndices: [GLuint] = [0, 1, 2,
                                          1, 2, 3]

            let followIndices: [GLuint] = startIndices.map({ $0 + 4 })

            triangleIndices = startIndices + stride(from: 0, to: GLuint(Swift.max(self.points.count - 4, 0)), by: 4).flatMap { quad in followIndices.map { quad + $0 } }
        }
        else {
            let startIndices: [GLuint] = [0, 1, 2,
                                        1, 2, 3]

            let followIndices: [GLuint] = startIndices.map({ $0 + 2 }) + startIndices.map({ $0 + 4 })

            triangleIndices = startIndices + stride(from: 0, to: GLuint(Swift.max(self.points.count - 4, 0)), by: 4).flatMap { quad in followIndices.map { quad + $0 } }
        }

        if drawDots {
            let upperPoints = points.flatMap {
                point -> [GraphPoint<GLfloat>] in
                return [
                    GraphPoint(x: GLfloat(point.xRange.lowerBound),
                               y: GLfloat(point.yRange.upperBound)),
                    GraphPoint(x: GLfloat(point.xRange.upperBound),
                               y: GLfloat(point.yRange.upperBound)),
                    ] }

            let lowerPoints = points.reversed().flatMap {
                point -> [GraphPoint<GLfloat>] in
                return [
                    GraphPoint(x: GLfloat(point.xRange.upperBound),
                               y: GLfloat(point.yRange.lowerBound)),
                    GraphPoint(x: GLfloat(point.xRange.lowerBound),
                               y: GLfloat(point.yRange.lowerBound)),
                    ] }

            outlinePoints = upperPoints + lowerPoints
        }
        else {
            outlinePoints.removeAll()
        }

        let dataPerPixelX = GLfloat((max.x-min.x)/Double(bounds.size.width))
        let biasDataX = lineWidth * dataPerPixelX

        xScale = GLfloat(2.0/(Float(max.x-min.x)+biasDataX))

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
        let length = points.count
        let indexCount = triangleIndices.count

        guard length > 0, indexCount > 0 else {
            return
        }

        EAGLContext.setCurrent(context)

        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        if yScale == 0.0 {
            yScale = 0.1
        }

        shader.use()

        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))

        let xTranslation = GLfloat(-min.x-(max.x-min.x)/2.0)
        let yTranslation = GLfloat(-min.y-(max.y-min.y)/2.0)

        shader.setScale(xScale, yScale)
        shader.setTranslation(xTranslation, yTranslation)
        shader.setPointSize(lineWidth)

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(length * MemoryLayout<GraphPoint<GLfloat>>.stride), points, GLenum(GL_STATIC_DRAW))

        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), indexVbo)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), GLsizeiptr(indexCount * MemoryLayout<GLuint>.stride), triangleIndices, GLenum(GL_STATIC_DRAW))

        shader.setColor(lineColor.r, lineColor.g, lineColor.b, lineColor.a)

        shader.drawTriangles(count: indexCount)

        // TODO: Use second index buffer
        if drawDots, !outlinePoints.isEmpty {
            let outlineLength = outlinePoints.count

            glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(outlineLength * MemoryLayout<GraphPoint<GLfloat>>.size), outlinePoints, GLenum(GL_DYNAMIC_DRAW))

            shader.setColor(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
            shader.drawPositions(mode: GL_LINE_LOOP, start: 0, count: outlineLength)
        }
    }
}
