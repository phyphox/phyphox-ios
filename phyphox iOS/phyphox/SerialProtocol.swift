//
//  serialProtocol.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 01.09.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//


//TODO This is only a part of the implementation of bluetooth protocols

import Foundation

protocol SerialProtocol {
    func read(newData: String) -> [[Double]]
    func write(data: [[Double]])
}

class SerialBufferedReader {
    var buffer: String = ""
    let newData: (buffer: String) -> (Int, [[Double]])
    
    init(newData: (buffer: String) -> (Int, [[Double]])) {
        self.newData = newData
    }
    
    func read(data: String) -> [[Double]] {
        buffer += data
        let result = newData(buffer: buffer)
        let index = buffer.startIndex.advancedBy(result.0)
        buffer = buffer.substringFromIndex(index)
        return result.1
    }
}

class SimpleSerialProtocol: SerialProtocol {
    let reader: SerialBufferedReader
    
    init(separator: Character) {
        
        reader = SerialBufferedReader(newData: {(buffer: String) -> (Int, [[Double]]) in
            var result: [[Double]] = [[]]
            
            var elements = buffer.characters.split(separator, allowEmptySlices: true).map(String.init)
            elements.removeLast() //The last element may be incomplete until a separator has been received.
            
            var processed = 0
            for element in elements {
                processed += element.characters.count + 1
                if let v = Double(element) {
                    result[0].append(v)
                }
            }
            return (processed, result)
        })
        
    }
    
    
    func read(newData: String) -> [[Double]] {
        return reader.read(newData)
    }
    
    func write(data: [[Double]]) {
        //TODO
    }
}

class CSVSerialProtocol: SerialProtocol {
    func read(newData: String) -> [[Double]] {
        //TODO
        return [[]]
    }
    
    func write(data: [[Double]]) {
        //TODO
    }
}

class JSONSerialProtocol: SerialProtocol {
    func read(newData: String) -> [[Double]] {
        //TODO
        return [[]]
    }
    
    func write(data: [[Double]]) {
        //TODO
    }
}