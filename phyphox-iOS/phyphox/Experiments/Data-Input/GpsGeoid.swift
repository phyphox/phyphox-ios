//
//  GpsGeoid.swift
//  phyphox
//
//  Created by Sebastian Staacks on 19.11.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

class GpsGeoid {
    static let shared = GpsGeoid()
    
    var offset = 0.0
    var scale = 1.0
    var dwidth = 0, dheight = 0, maxval = 0
    var lonres = 0.0, latres = 0.0
    
    //Cache
    var _ix = 0, _iy = 0
    var v00 = 0.0, v01 = 0.0, v10 = 0.0, v11 = 0.0
    var data: Data? = nil
    
    init() {
        
    }
    
    func load() {
        let inputStream = InputStream(fileAtPath: Bundle.main.path(forResource: "egm84_30", ofType: "pgm")!)!
        inputStream.open()
        defer {
            inputStream.close()
        }
        
        //Read header
        let bufferSize = 1000
        var dataBuffer = Data(capacity: bufferSize)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        while inputStream.read(buffer, maxLength: 1) > 0 {
            if buffer[0] != 0x0a {
                dataBuffer.append(buffer, count: 1)
            } else {
                guard let line = String(data: dataBuffer, encoding: .utf8) else {
                    print("Unexpected end in header of geoid data file.")
                    return
                }
                if line == "P5" {
                    dataBuffer.removeAll()
                    continue
                }
                if line[line.startIndex] == "#" {
                    if line[line.index(line.startIndex, offsetBy: 2) ..< line.index(line.startIndex, offsetBy: 8)] == "Offset" {
                        self.offset = Double(line[line.index(line.startIndex, offsetBy: 9) ..< line.endIndex]) ?? 0.0
                    } else if line[line.index(line.startIndex, offsetBy: 2) ..< line.index(line.startIndex, offsetBy: 7)] == "Scale" {
                        self.scale = Double(line[line.index(line.startIndex, offsetBy: 8) ..< line.endIndex]) ?? 0.0
                    }
                } else {
                    let parts = line.split(separator: " ")
                    if parts.count > 1 {
                        self.dwidth = Int(String(parts[0])) ?? 0
                        self.dheight = Int(String(parts[1])) ?? 0
                    } else {
                        self.maxval = Int(line) ?? 0
                        break
                    }
                }
                dataBuffer.removeAll()
            }
        }
        
        //Read data
        data = Data()
        var read = inputStream.read(buffer, maxLength: bufferSize)
        while read > 0 {
            data?.append(buffer, count: read)
            read = inputStream.read(buffer, maxLength: bufferSize)
        }
        
        lonres = Double(dwidth) / 360.0
        latres = Double(dheight-1) / 180.0
        
        _ix = dwidth
        _iy = dheight
    }
    
    private func rawval(ix: Int, iy: Int) -> Int {
        guard let data = data else {
            return 0
        }
        
        var nix = ix

        if nix < 0 {
            nix += dwidth
        } else if nix >= dwidth {
            nix -= dwidth
        }
        
        let index = 2*(nix + dwidth*iy)
        let upperByte = data[index]
        let lowerByte = data[index + 1]
        return Int(upperByte) << 8 + Int(lowerByte)
    }
    
    func height(latitude: Double, longitude: Double) -> Double {
        if data == nil {
            load()
        }
        
        var fx = longitude * lonres
        var fy = -latitude * latres
        var ix = Int(floor(fx))
        var iy = min((dheight-1)/2-1, Int(floor(fy)))
        
        fx -= Double(ix)
        fy -= Double(iy)
        iy += (dheight-1)/2
        ix += ix < 0 ? dwidth : (ix >= dwidth ? -dwidth : 0)
        
        if (!(ix == _ix && iy == _iy)) {
            v00 = Double(rawval(ix: ix  , iy: iy  ))
            v01 = Double(rawval(ix: ix+1, iy: iy  ))
            v10 = Double(rawval(ix: ix  , iy: iy+1))
            v11 = Double(rawval(ix: ix+1, iy: iy+1))
            _ix = ix
            _iy = iy
        }
        
        let a = (1-fx) * v00 + fx * v01
        let b = (1-fx) * v10 + fx * v11
        let c = (1-fy) * a + fy * b
        return offset + scale * c
    }
    
    
}
