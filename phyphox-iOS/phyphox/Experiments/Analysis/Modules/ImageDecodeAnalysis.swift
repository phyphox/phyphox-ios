//
//  ImageDecodeAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 06.08.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import CoreGraphics
import Foundation
import ImageIO

//Decode an image file (any format supported by ImageIO, at least PNG, JPEG and BMP) from a
//buffer holding the bytes of the encoded file (one byte per value, 0..255) into its dimensions
//and per-pixel channel data (0..1, line-wise from the top), like the Android implementation
//does via BitmapFactory.
final class ImageDecodeAnalysis: AutoClearingExperimentAnalysisModule {
    private static let inInSlot = AnalysisIOSlot(name: "in", asRequired: false, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let widthOutSlot = AnalysisIOSlot(name: "width", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let heightOutSlot = AnalysisIOSlot(name: "height", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let rOutSlot = AnalysisIOSlot(name: "r", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let gOutSlot = AnalysisIOSlot(name: "g", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let bOutSlot = AnalysisIOSlot(name: "b", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let aOutSlot = AnalysisIOSlot(name: "a", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let lumaOutSlot = AnalysisIOSlot(name: "luma", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)
    private static let luminanceOutSlot = AnalysisIOSlot(name: "luminance", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 1)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.inInSlot], outputs: [Self.widthOutSlot, Self.heightOutSlot, Self.rOutSlot, Self.gOutSlot, Self.bOutSlot, Self.aOutSlot, Self.lumaOutSlot, Self.luminanceOutSlot])
    }
    private let input: MutableDoubleArray

    private let widthOutput: ExperimentAnalysisDataOutput?
    private let heightOutput: ExperimentAnalysisDataOutput?
    private let rOutput: ExperimentAnalysisDataOutput?
    private let gOutput: ExperimentAnalysisDataOutput?
    private let bOutput: ExperimentAnalysisDataOutput?
    private let aOutput: ExperimentAnalysisDataOutput?
    private let lumaOutput: ExperimentAnalysisDataOutput?
    private let luminanceOutput: ExperimentAnalysisDataOutput?

    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        guard inputs.count == 1 else {
            throw SerializationError.genericError(message: "Imagedecode analysis needs exactly one input.")
        }

        let io = try Self.mapIO(inputs: inputs, outputs: outputs)

        guard let data = io.data(Self.inInSlot) else {
            throw SerializationError.genericError(message: "Imagedecode analysis needs a buffer input.")
        }
        input = data

        widthOutput = io.output(Self.widthOutSlot)
        heightOutput = io.output(Self.heightOutSlot)
        rOutput = io.output(Self.rOutSlot)
        gOutput = io.output(Self.gOutSlot)
        bOutput = io.output(Self.bOutSlot)
        aOutput = io.output(Self.aOutSlot)
        lumaOutput = io.output(Self.lumaOutSlot)
        luminanceOutput = io.output(Self.luminanceOutSlot)

        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }

    //sRGB EOTF, same as the luminance output of the camera input
    private func linearize(_ x: Double) -> Double {
        if x < 0.04045 {
            return x / 12.92
        } else {
            return pow((x + 0.055) / 1.055, 2.4)
        }
    }

    override func update() {
        let inData = input.data
        guard !inData.isEmpty else { return }

        var encoded = Data(capacity: inData.count)
        for value in inData {
            let rounded = value.rounded()
            if rounded.isFinite && abs(rounded) <= 2147483647.0 {
                encoded.append(UInt8(truncatingIfNeeded: Int32(rounded)))
            } else {
                encoded.append(0)
            }
        }

        guard let source = CGImageSourceCreateWithData(encoded as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            print("imagedecode: Could not decode image data.")
            return
        }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            print("imagedecode: Could not decode image data.")
            return
        }

        //Drawing into an sRGB context converts wide-gamut images and unifies the pixel format,
        //like the BitmapFactory options on Android. The buffer holds the image line-wise from
        //the top as premultiplied RGBA.
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixelData.withUnsafeMutableBytes { (rawBuffer: UnsafeMutableRawBufferPointer) -> Bool in
            guard let context = CGContext(data: rawBuffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else {
            print("imagedecode: Could not decode image data.")
            return
        }

        if let widthOutput = widthOutput {
            switch widthOutput {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(Double(width))
            }
        }
        if let heightOutput = heightOutput {
            switch heightOutput {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.append(Double(height))
            }
        }

        guard rOutput != nil || gOutput != nil || bOutput != nil || aOutput != nil || lumaOutput != nil || luminanceOutput != nil else {
            return
        }

        let count = width * height
        var r = rOutput != nil ? [Double](repeating: 0.0, count: count) : []
        var g = gOutput != nil ? [Double](repeating: 0.0, count: count) : []
        var b = bOutput != nil ? [Double](repeating: 0.0, count: count) : []
        var a = aOutput != nil ? [Double](repeating: 0.0, count: count) : []
        var luma = lumaOutput != nil ? [Double](repeating: 0.0, count: count) : []
        var luminance = luminanceOutput != nil ? [Double](repeating: 0.0, count: count) : []

        for i in 0..<count {
            let av = Double(pixelData[4*i + 3]) / 255.0
            var rv = Double(pixelData[4*i]) / 255.0
            var gv = Double(pixelData[4*i + 1]) / 255.0
            var bv = Double(pixelData[4*i + 2]) / 255.0

            //The context stores premultiplied alpha, but the channel outputs are the plain
            //color values, like Android's getPixels delivers them
            if av > 0.0 && av < 1.0 {
                rv = min(rv / av, 1.0)
                gv = min(gv / av, 1.0)
                bv = min(bv / av, 1.0)
            }

            if rOutput != nil {
                r[i] = rv
            }
            if gOutput != nil {
                g[i] = gv
            }
            if bOutput != nil {
                b[i] = bv
            }
            if aOutput != nil {
                a[i] = av
            }
            if lumaOutput != nil {
                //Rec. 709 weights on gamma-encoded values, same as the luma output of the camera input
                luma[i] = 0.2126 * rv + 0.7152 * gv + 0.0722 * bv
            }
            if luminanceOutput != nil {
                luminance[i] = 0.2126 * linearize(rv) + 0.7152 * linearize(gv) + 0.0722 * linearize(bv)
            }
        }

        func write(_ values: [Double], to output: ExperimentAnalysisDataOutput?) {
            guard let output = output else { return }
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(values)
            }
        }

        write(r, to: rOutput)
        write(g, to: gOutput)
        write(b, to: bOutput)
        write(a, to: aOutput)
        write(luma, to: lumaOutput)
        write(luminance, to: luminanceOutput)
    }
}
