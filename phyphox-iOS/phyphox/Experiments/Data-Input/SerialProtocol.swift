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
    func read(_ newData: String) -> [[Double]]
    func write(_ data: [[Double]])
}

class SerialBufferedReader {
    var buffer: String = ""
    let newData: (_ buffer: String) -> (Int, [[Double]])
    
    init(newData: @escaping (_ buffer: String) -> (Int, [[Double]])) {
        self.newData = newData
    }
    
    func read(_ data: String) -> [[Double]] {
        buffer += data
        let result = newData(buffer)
        let index = buffer.index(buffer.startIndex, offsetBy: result.0)
        buffer = String(buffer[index...])
        return result.1
    }
}

class SimpleSerialProtocol: SerialProtocol {
    let reader: SerialBufferedReader
    
    init(separator: Character) {
        
        reader = SerialBufferedReader(newData: {(buffer: String) -> (Int, [[Double]]) in
            var result: [[Double]] = [[]]
            
            var elements = buffer.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
            elements.removeLast() //The last element may be incomplete until a separator has been received.
            
            var processed = 0
            for element in elements {
                processed += element.count + 1
                if let v = Double(element) {
                    result[0].append(v)
                }
            }
            return (processed, result)
        })
        
    }
    
    
    func read(_ newData: String) -> [[Double]] {
        return reader.read(newData)
    }
    
    func write(_ data: [[Double]]) {
        //TODO
    }
}

class CSVSerialProtocol: SerialProtocol {
    func read(_ newData: String) -> [[Double]] {
        //TODO
        return [[]]
    }
    
    func write(_ data: [[Double]]) {
        //TODO
    }
}

class JSONSerialProtocol: SerialProtocol {
    func read(_ newData: String) -> [[Double]] {
        //TODO
        return [[]]
    }
    
    func write(_ data: [[Double]]) {
        //TODO
    }
}
