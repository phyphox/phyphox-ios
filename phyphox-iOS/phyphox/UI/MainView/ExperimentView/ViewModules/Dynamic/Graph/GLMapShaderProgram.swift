//
//  GLMapShaderProgram.swift
//  phyphox
//
//  Created by Sebastian Staacks on 30.04.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

final class GLMapShaderProgram {
    private let programHandle: GLuint
    
    private let positionAttributeHandle: GLuint
    private let translationUniformHandle: GLint
    private let scaleUniformHandle: GLint
    
    init() {
        let vertexStr = try! String(contentsOfFile: Bundle.main.path(forResource: "MapVertexShader", ofType: "glsl")!)
        let fragmentStr = try! String(contentsOfFile: Bundle.main.path(forResource: "MapFragmentShader", ofType: "glsl")!)
        
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
        translationUniformHandle = GLint(glGetUniformLocation(programHandle, "translation"))
        
        glEnableVertexAttribArray(positionAttributeHandle)
    }
    
    func use() {
        glUseProgram(programHandle)
    }
    
    func setScale(_ x: GLfloat, _ y: GLfloat, _ z: GLfloat) {
        glUniform3f(scaleUniformHandle, x, y, z)
    }
    
    func setTranslation(_ x: GLfloat, _ y: GLfloat, _ z: GLfloat) {
        glUniform3f(translationUniformHandle, x, y, z)
    }
    
    private func bufferOffset<I: BinaryInteger>(_ i: I) -> UnsafeRawPointer? {
        return UnsafeRawPointer(bitPattern: Int(i))
    }
    
    func drawElements(mode: Int32, start: Int, count: Int) {
        guard count > 0 else { return }
        
        glVertexAttribPointer(positionAttributeHandle, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(MemoryLayout<GraphPoint3D<GLfloat>>.stride), nil)
        
        let pointer = bufferOffset(start * MemoryLayout<GLuint>.stride)
        glDrawElements(GLenum(mode), GLsizei(count), GLenum(GL_UNSIGNED_INT), pointer)
    }
    
    deinit {
        glDeleteProgram(programHandle)
    }
}
