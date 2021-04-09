//
//  GLGraphShaderProgram.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

final class GLGraphShaderProgram {
    private let programHandle: GLuint

    private let positionAttributeHandle: GLuint
    private let translationUniformHandle: GLint
    private let scaleUniformHandle: GLint
    private let pointSizeUniformHandle: GLint
    private let colorUniformHandle: GLint

    init() {
        let vertexStr = try! String(contentsOfFile: Bundle.main.path(forResource: "VertexShader", ofType: "glsl")!)
        let fragmentStr = try! String(contentsOfFile: Bundle.main.path(forResource: "FragmentShader", ofType: "glsl")!)

        var vertexShader: GLuint = 0
        var fragmentShader: GLuint = 0
        
        let vertexShady = vertexStr.cString(using: String.Encoding.utf8)!
        let fragmentShady = fragmentStr.cString(using: String.Encoding.utf8)!
        vertexShady.withUnsafeBufferPointer{vertexPointer in
            var vertexBasePointer = vertexPointer.baseAddress
            vertexShader = glCreateShader(GLenum(GL_VERTEX_SHADER))
            glShaderSource(vertexShader, GLsizei(1), &vertexBasePointer, nil)
            glCompileShader(vertexShader)
            fragmentShady.withUnsafeBufferPointer{fragmentPointer in
                var fragmentBasePointer = fragmentPointer.baseAddress
                fragmentShader = glCreateShader(GLenum(GL_FRAGMENT_SHADER))
                glShaderSource(fragmentShader, GLsizei(1), &fragmentBasePointer, nil)
                glCompileShader(fragmentShader)
            }
        }

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
        colorUniformHandle = GLint(glGetUniformLocation(programHandle, "color"))

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

    func drawPositions(mode: Int32, start: Int, count: Int, strideFactor: Int) {
        guard count > 0 else { return }

        glVertexAttribPointer(positionAttributeHandle, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GraphPoint2D<GLfloat>>.stride * strideFactor), nil)

        glDrawArrays(GLenum(mode), GLint(start), GLsizei(count))
    }

    private func bufferOffset<I: BinaryInteger>(_ i: I) -> UnsafeRawPointer? {
        return UnsafeRawPointer(bitPattern: Int(i))
    }

    func drawElements(mode: Int32, start: Int, count: Int) {
        guard count > 0 else { return }

        glVertexAttribPointer(positionAttributeHandle, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GraphPoint2D<GLfloat>>.stride), nil)

        let pointer = bufferOffset(start * MemoryLayout<GLuint>.stride)
        glDrawElements(GLenum(mode), GLsizei(count), GLenum(GL_UNSIGNED_INT), pointer)
    }

    deinit {
        glDeleteProgram(programHandle)
    }
}
