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

// TODO: Sharegroup

final class GLRangedPointGraphView: GLKView {
    private let shader: ShaderProgram

    private let vbo: GLuint
    private let triangleIndexBuffer: GLuint
    private let outlineIndexBuffer: GLuint

    // Values used to transform the input values on the xy Plane into NDCs.
    private var xScale: GLfloat = 1.0
    private var yScale: GLfloat = 1.0

    private let drawDots: Bool
    private let lineWidth: GLfloat
//    private let lineColor: GLcolor

    let outlineMidIndex: Int

    @available(*, unavailable)
    override convenience init(frame: CGRect) {
        fatalError()
    }

    @available(*, unavailable)
    init() {
        fatalError()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    init(drawDots: Bool, lineWidth: GLfloat, lineColor: GLcolor, maximumPointCount: Int) {
        let context = EAGLContext(api: .openGLES3)!

        context.isMultiThreaded = true

        EAGLContext.setCurrent(context)

        shader = ShaderProgram()

        self.drawDots = drawDots
        self.lineWidth = lineWidth
//        self.lineColor = lineColor

        var vbo: GLuint = 0
        var triangleIndexBuffer: GLuint = 0
        var outlineIndexBuffer: GLuint = 0

        glGenBuffers(1, &vbo)
        glGenBuffers(1, &triangleIndexBuffer)
        glGenBuffers(1, &outlineIndexBuffer)

        self.vbo = vbo
        self.triangleIndexBuffer = triangleIndexBuffer
        self.outlineIndexBuffer = outlineIndexBuffer

        outlineMidIndex = 2 * maximumPointCount

        super.init(frame: .zero, context: context)

        prepareBuffers(maximumPointCount: maximumPointCount)

        self.drawableColorFormat = .RGBA8888

        // 2D drawing, no depth information needed
        self.drawableDepthFormat = .formatNone
        self.drawableStencilFormat = .formatNone

        self.drawableMultisample = .multisample4X
        self.isOpaque = false
        self.enableSetNeedsDisplay = false

        glClearColor(0.0, 0.0, 0.0, 0.0)

        shader.use()
        
        shader.setPointSize(lineWidth)
        shader.setColor(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
    }

    private func prepareBuffers(maximumPointCount: Int) {
        EAGLContext.setCurrent(context)

        let maximumVertexCount = maximumPointCount * 4

        // Allocate buffer for vertex position data

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<GraphPoint<GLfloat>>.stride * maximumVertexCount, nil, GLenum(GL_DYNAMIC_DRAW))

        // Allocate and fill coordinate-indipendet buffers for triangulation and outline indices

        let startIndices: [GLuint] = [0, 1, 2,
                                      1, 2, 3]
        let followIndices: [GLuint]

        if drawDots {
            followIndices = startIndices.map({ $0 + 4 })
        }
        else {
            followIndices = startIndices.map({ $0 + 2 }) + startIndices.map({ $0 + 4 })
        }

        let triangleIndices = startIndices + stride(from: 0, to: GLuint(Swift.max(maximumVertexCount - 4, 0)), by: 4).flatMap { quad in followIndices.map { quad + $0 } }

        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), triangleIndexBuffer)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), MemoryLayout<GLuint>.stride * triangleIndices.count, triangleIndices, GLenum(GL_STATIC_DRAW))

        let upperIndices = stride(from: 0, to: GLuint(maximumVertexCount), by: 2).reversed()
        let lowerIndices = stride(from: 1, to: GLuint(maximumVertexCount), by: 2)

        let outlineIndices = upperIndices + lowerIndices

        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), outlineIndexBuffer)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), MemoryLayout<GLuint>.stride * outlineIndices.count, outlineIndices, GLenum(GL_STATIC_DRAW))
    }

    private var vertexCount = 0
    private var drawQuads = true

    //private var points = [GraphPoint<GLfloat>]()

    func appendPoints<S: Sequence>(_ points: S, replace: Int, min: GraphPoint<Double>, max: GraphPoint<Double>, drawQuads: Bool) where S.Element == RangedGraphPoint<GLfloat> {
        if drawQuads {
            let addedVertices = points.flatMap { point -> [GraphPoint<GLfloat>] in
                return [
                    GraphPoint(x: point.xRange.lowerBound,
                               y: point.yRange.upperBound),
                    GraphPoint(x: point.xRange.lowerBound,
                               y: point.yRange.lowerBound),
                    GraphPoint(x: point.xRange.upperBound,
                               y: point.yRange.upperBound),
                    GraphPoint(x: point.xRange.upperBound,
                               y: point.yRange.lowerBound)
                ]
            }
            
            EAGLContext.setCurrent(context)

            glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
            glBufferSubData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<GraphPoint<GLfloat>>.stride * (vertexCount - replace * 4), MemoryLayout<GraphPoint<GLfloat>>.stride * addedVertices.count, addedVertices)

            vertexCount = vertexCount - replace * 4 + addedVertices.count

            scheduleRedraw(min: min, max: max)
        }
        else {
//            newPoints = points.map { GraphPoint(x: GLfloat($0.xRange.lowerBound), y: GLfloat($0.yRange.lowerBound)) }
//            
//            pointCount = newPoints.count
        }
    }

    func setPoints<S: Sequence>(_ points: S, min: GraphPoint<Double>, max: GraphPoint<Double>, drawQuads: Bool) where S.Element == RangedGraphPoint<GLfloat> {

//        self.drawQuads = drawQuads
//
//        let newPoints: [GraphPoint<GLfloat>]
//
//        if drawQuads {
//            newPoints = points.flatMap { point -> [GraphPoint<GLfloat>] in
//                return [
//                    GraphPoint(x: point.xRange.lowerBound,
//                               y: point.yRange.upperBound),
//                    GraphPoint(x: point.xRange.lowerBound,
//                               y: point.yRange.lowerBound),
//                    GraphPoint(x: point.xRange.upperBound,
//                               y: point.yRange.upperBound),
//                    GraphPoint(x: point.xRange.upperBound,
//                               y: point.yRange.lowerBound)
//                ]
//            }
//
//            self.points = newPoints
//
//            pointCount = newPoints.count
//        }
//        else {
//            triangleIndices.removeAll()
//            outlineIndices.removeAll()
//
//            newPoints = points.map { GraphPoint(x: GLfloat($0.xRange.lowerBound), y: GLfloat($0.yRange.lowerBound)) }
//            self.points = newPoints
//            pointCount = newPoints.count
//        }
//
//        shader.use()
//
//        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
//        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<GraphPoint<GLfloat>>.stride * newPoints.count, self.points, GLenum(GL_DYNAMIC_DRAW))
//
//        scheduleRedraw(min: min, max: max)
    }

    var xTranslation: GLfloat = 0
    var yTranslation: GLfloat = 0

    private func scheduleRedraw(min: GraphPoint<Double>, max: GraphPoint<Double>) {
        let dataPerPixelX = GLfloat((max.x - min.x) / Double(bounds.size.width))
        let biasDataX = lineWidth * dataPerPixelX

        xScale = GLfloat(2.0/(GLfloat(max.x - min.x) + biasDataX))

        let dataPerPixelY = GLfloat((max.y - min.y) / Double(bounds.size.height))
        let biasDataY = lineWidth * dataPerPixelY

        yScale = GLfloat(2.0/(GLfloat(max.y - min.y) + biasDataY))

        xTranslation = GLfloat(-min.x-(max.x-min.x)/2.0)
        yTranslation = GLfloat(-min.y-(max.y-min.y)/2.0)

        display()
    }

    override func draw(_ rect: CGRect) {
        render()
    }

    private var triangulationIndexLength: Int {
        guard vertexCount > 0 else {
            return 0
        }

        if drawDots {
            return 6 * vertexCount/4
        }
        else {
            return 6 + (vertexCount - 1) * 3
        }
    }

    private var outlineIndexLength: Int {
        return vertexCount
    }

    func render() {
        EAGLContext.setCurrent(context)

        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        if yScale == 0.0 {
            yScale = 0.1
        }

        shader.use()

        shader.setScale(xScale, yScale)
        shader.setTranslation(xTranslation, yTranslation)

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)

        if drawQuads, triangulationIndexLength > 0 {
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), triangleIndexBuffer)
            shader.drawElements(mode: GL_TRIANGLES, start: 0, count: triangulationIndexLength)

            if !drawDots, outlineIndexLength > 0 {
                glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), outlineIndexBuffer)
                shader.drawElements(mode: GL_LINE_LOOP, start: outlineMidIndex - outlineIndexLength/2 , count: outlineIndexLength)
            }
        }
        else {
            shader.drawPositions(mode: (drawDots ? GL_POINTS : GL_LINE_STRIP), start: 0, count: vertexCount)
        }
    }
}
