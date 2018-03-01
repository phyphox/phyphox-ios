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
    init(data: Data)
}

typealias DataCodable = DataEncodable & DataDecodable

extension Double: DataCodable {
    func encode() -> Data {
        var littleEndianBitPattern = bitPattern.littleEndian
        let size = MemoryLayout.size(ofValue: littleEndianBitPattern)

        return Data(bytes: &littleEndianBitPattern, count: size)
    }

    init(data: Data) {
        let littleEndianBitPattern = UInt64(littleEndian: data.withUnsafeBytes { (pointer: UnsafePointer<UInt64>) -> UInt64 in
            return pointer.pointee
        })

        self.init(bitPattern: littleEndianBitPattern)
    }
}

extension Sequence where Iterator.Element: DataCodable {
    func enumerateDataEncodedElements(using body: (_ data: Data) -> Void) {
        forEach { body($0.encode()) }
    }
}

extension DataBuffer {
    func writeState(to url: URL) throws {
        let atomicFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        FileManager.default.createFile(atPath: atomicFile.path, contents: nil, attributes: nil)
        let handle = try FileHandle(forWritingTo: atomicFile)

        enumerateDataEncodedElements { data in
            handle.write(data)
        }

        handle.closeFile()

        try FileManager.default.moveItem(at: atomicFile, to: url)
    }

    func readState(from url: URL) throws {
        guard let stream = InputStream(url: url) else {
            throw FileError.genericError
        }

        let bitPatternSize = MemoryLayout<UInt64>.size

        var values = [Double]()
        var data = Data(capacity: bitPatternSize)

        stream.open()

        while data.withUnsafeMutableBytes({ stream.read($0, maxLength: bitPatternSize) }) == bitPatternSize {
            let value = Double(data: data)
            values.append(value)
        }

        stream.close()

        replaceValues(values)
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

        let experimentURL = stateFolderURL.appendingPathComponent("Experiment.phyphox")

        guard let source = source else {
            throw FileError.genericError
        }

        try fileManager.copyItem(at: source, to: experimentURL)

        try buffers.0?.forEach { name, buffer in
            let bufferURL = stateFolderURL.appendingPathComponent(name).appendingPathExtension("buffer")
            try buffer.writeState(to: bufferURL)
        }

        return stateFolderURL
    }
}
