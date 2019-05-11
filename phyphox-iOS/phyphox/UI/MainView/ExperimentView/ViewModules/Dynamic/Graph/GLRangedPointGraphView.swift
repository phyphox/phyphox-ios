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

private let primitiveRestartFlag = GLuint.max

final class GLRangedPointGraphView: GLKView {
    private let shader: GLGraphShaderProgram

    private var vertexBuffer: GLuint = 0
    private var triangleIndexBuffer: GLuint = 0
    private var outlineIndexBuffer: GLuint = 0

    // Values used to transform the input values on the xy Plane into NDCs.
    private var xScale: GLfloat = 1.0
    private var yScale: GLfloat = 1.0

    private var xTranslation: GLfloat = 0
    private var yTranslation: GLfloat = 0

    private let drawDots: Bool
    private let lineWidth: GLfloat

    private let outlineMidIndex: Int

    private var vertexCount = 0

    /**
     In single point mode the ranged input points are expected to contain empty ranges, meaning they represent a single point rather than a rectangle. This only copies one vertex per point into the vertex buffer, and only draws dots or a connecting line on the vertices, depending on the `drawDots` value. No quads and no outline is rendered when this is `true`. When toggling this property all vertex data needs to be discarded (`setPoints`) before rendering.
     */
    var singlePointMode = false

    private var pointSize: CGSize = .zero

    private var triangulationIndexLength: Int {
        guard vertexCount > 0 else {
            return 0
        }

        if drawDots {
            return 6 * vertexCount/4
        }
        else {
            return 6 + (vertexCount - 4) * 3
        }
    }

    private var outlineIndexLength: Int {
        if drawDots {
            return 5 * vertexCount/4
        }
        else {
            return vertexCount
        }
    }

    @available(*, unavailable)
    override init(frame: CGRect) {
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
        var context: EAGLContext! = EAGLContext(api: .openGLES3)

        if context == nil {
            context = EAGLContext(api: .openGLES2)
        }

        context.isMultiThreaded = true

        EAGLContext.setCurrent(context)

        shader = GLGraphShaderProgram()

        self.drawDots = drawDots
        self.lineWidth = lineWidth

        glGenBuffers(1, &vertexBuffer)
        glGenBuffers(1, &triangleIndexBuffer)
        glGenBuffers(1, &outlineIndexBuffer)

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

        if drawDots {
            glEnable(GLenum(GL_PRIMITIVE_RESTART_FIXED_INDEX))
        }

        shader.use()
        
        shader.setPointSize(lineWidth)
        shader.setColor(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
    }

    private func prepareBuffers(maximumPointCount: Int) {
        EAGLContext.setCurrent(context)

        let maximumVertexCount = maximumPointCount * 4

        // Allocate buffer for vertex position data
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<GraphPoint2D<GLfloat>>.stride * maximumVertexCount, nil, GLenum(GL_DYNAMIC_DRAW))

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

        let outlineIndices: [GLuint]

        if drawDots {
            let startIndices: [GLuint] = [0, 1, 3, 2]

            outlineIndices = stride(from: 0, to: GLuint(maximumVertexCount), by: 4).flatMap { factor in startIndices.map({ $0 + factor }) + [primitiveRestartFlag] }
        }
        else {
            let upperIndices = stride(from: 0, to: GLuint(maximumVertexCount), by: 2).reversed()
            let lowerIndices = stride(from: 1, to: GLuint(maximumVertexCount), by: 2)

            outlineIndices = upperIndices + lowerIndices
        }

        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), outlineIndexBuffer)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), MemoryLayout<GLuint>.stride * outlineIndices.count, outlineIndices, GLenum(GL_STATIC_DRAW))
    }

    private func createVertices<S: Sequence>(from points: S) -> [GraphPoint2D<GLfloat>] where S.Element == RangedGraphPoint<GLfloat> {
        let vertices: [GraphPoint2D<GLfloat>]

        if singlePointMode {
            vertices = points.map { point -> GraphPoint2D<GLfloat> in
                return GraphPoint2D(x: point.xRange.lowerBound, y: point.yRange.lowerBound)
            }
        }
        else {
            vertices = points.flatMap { point -> [GraphPoint2D<GLfloat>] in
                return [
                    GraphPoint2D(x: point.xRange.lowerBound,
                               y: point.yRange.upperBound),
                    GraphPoint2D(x: point.xRange.lowerBound,
                               y: point.yRange.lowerBound),
                    GraphPoint2D(x: point.xRange.upperBound,
                               y: point.yRange.upperBound),
                    GraphPoint2D(x: point.xRange.upperBound,
                               y: point.yRange.lowerBound)
                ]
            }
        }

        return vertices
    }

    func appendPoints<S: Sequence>(_ points: S, replace: Int, min: GraphPoint2D<Double>, max: GraphPoint2D<Double>) where S.Element == RangedGraphPoint<GLfloat> {
        let vertices = createVertices(from: points)

        EAGLContext.setCurrent(context)

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferSubData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<GraphPoint2D<GLfloat>>.stride * (vertexCount - replace * 4), MemoryLayout<GraphPoint2D<GLfloat>>.stride * vertices.count, vertices)

        vertexCount = vertexCount - replace * 4 + vertices.count

        updateTransform(min: min, max: max)
    }

    func setPoints<S: Sequence>(_ points: S, min: GraphPoint2D<Double>, max: GraphPoint2D<Double>) where S.Element == RangedGraphPoint<GLfloat> {
        let vertices = createVertices(from: points)

        EAGLContext.setCurrent(context)

        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferSubData(GLenum(GL_ARRAY_BUFFER), 0, MemoryLayout<GraphPoint2D<GLfloat>>.stride * vertices.count, vertices)

        vertexCount = vertices.count

        updateTransform(min: min, max: max)
    }

    private func updateTransform(min: GraphPoint2D<Double>, max: GraphPoint2D<Double>) {
        let dataPerPointX = GLfloat((max.x - min.x) / Double(pointSize.width))
        let biasDataX = lineWidth * dataPerPointX

        xScale = GLfloat(2.0/(GLfloat(max.x - min.x) + biasDataX))

        let dataPerPointY = GLfloat((max.y - min.y) / Double(pointSize.height))
        let biasDataY = lineWidth * dataPerPointY

        yScale = GLfloat(2.0/(GLfloat(max.y - min.y) + biasDataY))

        xTranslation = GLfloat(-min.x - (max.x - min.x)/2.0)
        yTranslation = GLfloat(-min.y - (max.y - min.y)/2.0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        pointSize = bounds.size
    }

    override func draw(_ rect: CGRect) {
        render()
    }

    private func render() {
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        guard vertexCount > 0 else { return }

        if yScale == 0.0 {
            yScale = 0.1
        }

        shader.use()

        shader.setScale(xScale, yScale)
        shader.setTranslation(xTranslation, yTranslation)

        if !singlePointMode {
            let triangulationIndexLength = self.triangulationIndexLength

            if triangulationIndexLength > 0 {
                glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), triangleIndexBuffer)
                shader.drawElements(mode: GL_TRIANGLES, start: 0, count: triangulationIndexLength)
            }

            let outlineIndexLength = self.outlineIndexLength

            if outlineIndexLength > 0 {
                glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), outlineIndexBuffer)

                if drawDots {
                    shader.drawElements(mode: GL_LINE_LOOP, start: 0, count: outlineIndexLength)
                }
                else {
                    shader.drawElements(mode: GL_LINE_LOOP, start: outlineMidIndex - outlineIndexLength/2 , count: outlineIndexLength)
                }
            }
        }
        else {
            shader.drawPositions(mode: (drawDots ? GL_POINTS : GL_LINE_STRIP), start: 0, count: vertexCount, strideFactor: 1)
        }
    }

    deinit {
        glDeleteBuffers(1, &vertexBuffer)
        glDeleteBuffers(1, &outlineIndexBuffer)
        glDeleteBuffers(1, &triangleIndexBuffer)
    }
}
