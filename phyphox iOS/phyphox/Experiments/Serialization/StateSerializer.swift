//
//  SimpleStateSerializer.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 26.05.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation

protocol DataEncodable {
    func encode() -> Data
}

protocol DataDecodable {
    init?(data: Data)
}

typealias DataCodable = DataEncodable & DataDecodable

extension Double: DataCodable {
    func encode() -> Data {
        if CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) {
            var value = self
            return Data(buffer: UnsafeBufferPointer(start: &value, count: 1))
        }
        else {
            var littleEndianBitPattern = bitPattern.littleEndian
            return Data(buffer: UnsafeBufferPointer(start: &littleEndianBitPattern, count: 1))
        }
    }

    init?(data: Data) {
        if CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) {
            guard data.count == MemoryLayout<Double>.size else { return nil }

            let value: Double = data.withUnsafeBytes({ $0.pointee })

            self.init(value)
        }
        else {
            let littleEndianBitPattern = UInt64(littleEndian: data.withUnsafeBytes { (pointer: UnsafePointer<UInt64>) -> UInt64 in
                return pointer.pointee
            })

            self.init(bitPattern: littleEndianBitPattern)
        }
    }
}

extension Sequence where Iterator.Element: DataCodable {
    func enumerateDataEncodedElements(using body: (_ data: Data) -> Void) {
        forEach { body($0.encode()) }
    }
}

extension DataBuffer {
    func writeState(to url: URL) throws {
        if CFByteOrderGetCurrent() == Int(CFByteOrderLittleEndian.rawValue) {
            let values = toArray()

            let pointer = UnsafePointer(values)
            let buffer = UnsafeBufferPointer(start: pointer, count: values.count)

            let data = Data(buffer: buffer)

            try data.write(to: url, options: .atomic)
        }
        else {
            let atomicFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

            FileManager.default.createFile(atPath: atomicFile.path, contents: nil, attributes: nil)
            let handle = try FileHandle(forWritingTo: atomicFile)

            enumerateDataEncodedElements { data in
                handle.write(data)
            }

            handle.closeFile()

            try FileManager.default.moveItem(at: atomicFile, to: url)
        }
    }

    func readState(from url: URL) throws {
        print("aaa")
        
        let data = try Data(contentsOf: url)

        let bitPatternSize = MemoryLayout<UInt64>.size

        let count = data.count / bitPatternSize

        let values = data.withUnsafeBytes { (pointer: UnsafePointer<Double>) -> [Double] in
            let buffer = UnsafeBufferPointer(start: pointer, count: count)

            return Array(buffer)
        }

        replaceValues(values)

      /*  let handle = try FileHandle(forReadingFrom: url)

        let bitPatternSize = MemoryLayout<UInt64>.size

        var values = [Double]()

        while true {
            let data = handle.readData(ofLength: bitPatternSize)
            guard data.count == bitPatternSize else { break }

            guard let value = Double(data: data) else { throw FileError.genericError } // TODO: error
            values.append(value)
        }

        handle.closeFile()
*/
      /*  guard let stream = InputStream(url: url) else {
            throw FileError.genericError
        }

        let bitPatternSize = MemoryLayout<UInt64>.size

        var values = [Double]()
        var data = Data(count: bitPatternSize)

        stream.open()

        while data.withUnsafeMutableBytes({ stream.read($0, maxLength: bitPatternSize) }) == bitPatternSize {
            guard let value = Double(data: data) else { throw FileError.genericError } // TODO: error
            values.append(value)
        }

        stream.close()

        replaceValues(values)*/
    }
}

extension Experiment {
    func saveState(to url: URL, with title: String) throws -> URL {
        let stateFolderURL = url.appendingPathComponent(title).appendingPathExtension(experimentStateFileExtension)

        let fileManager = FileManager.default

        guard !fileManager.fileExists(atPath: stateFolderURL.path) else {
            throw FileError.genericError
        }

        try fileManager.createDirectory(at: stateFolderURL, withIntermediateDirectories: false, attributes: nil)

        let experimentURL = stateFolderURL.appendingPathComponent(experimentStateExperimentFileName).appendingPathExtension(experimentStateFileExtension)

        guard let source = source else {
            throw FileError.genericError
        }

        try fileManager.copyItem(at: source, to: experimentURL)

        try buffers.forEach { name, buffer in
            let bufferURL = stateFolderURL.appendingPathComponent(name).appendingPathExtension(bufferContentsFileExtension)
            try buffer.writeState(to: bufferURL)
        }

        return stateFolderURL
    }
}
