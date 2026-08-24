//
//  CRC32InputStream.swift
//  phyphox
//
//  Created by Sebastian Staacks on 17.05.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation
import zlib

final class CRC32InputStream: InputStream {
    public var crcValue: UInt = 0
    let inputStream: InputStream
    
    init(_ inputStream: InputStream) {
        self.inputStream = inputStream
        super.init(data: Data())
    }
    
    override func open() {
        inputStream.open()
    }

    override func close() {
        inputStream.close()
    }

    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return inputStream.getBuffer(buffer, length: len)
    }
    
    override var hasBytesAvailable: Bool {
        get {
            return inputStream.hasBytesAvailable
        }
    }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        let count = inputStream.read(buffer, maxLength: len)
        //A failed read returns -1, which must be passed through as the error it is - handing
        //it to crc32 as an unsigned count trapped instead (a crash on any unreadable file)
        if count > 0 {
            crcValue = crc32(crcValue, buffer, uInt(count))
        }
        return count
    }
    
}
