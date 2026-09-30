//
//  CameraAnalyzerMathTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
import UIKit
import Metal
import CoreVideo
import AVFoundation
@testable import phyphox

// phyphox-test: camera-analyzer-math
// phyphox-test: camera-color-channels
//The camera analyzers on generated frames instead of camera frames: a bitmap is written into a CVPixelBuffer of the
//camera's own pixel format (420 YpCbCr 8-bit bi-planar, full range) and turned into the Y and CbCr Metal textures the way
//CameraService does, and every analyzer runs its real kernels and reduction on it. Expected values come from a per-pixel
//reference on the CPU. Frame sizes are deliberately no multiple of 16, so every reduction ends in a partial threadgroup.
//
//The camera path is 8-bit 4:2:0 YCbCr, so an RGB colour cannot be handed to the analyzers exactly: the reference is the
//shader's per-pixel formulas applied to the RGB the pipeline reconstructs from the encoded frame (chroma shared by 2x2
//pixels), and a separate assertion keeps that reconstruction within the 8-bit quantization of the intended colour. The
//1e-4 tolerances therefore test the analyzers' math and reduction, not the YCbCr round trip.
final class CameraAnalyzerMathTests: XCTestCase {

    static let W = 331
    static let H = 197
    static let full = CGRect(x: 0, y: 0, width: 1, height: 1)

    static let WR = 0.2126, WG = 0.7152, WB = 0.0722
    static let uniformTolerance = 1e-4
    static let texturedTolerance = 3e-4

    typealias RGB = (r: Double, g: Double, b: Double)

    //Exposure factor 2^aperture/2 * 100/ISO * (1/60)/shutter: 1 for the first, 2 for the second
    static func settings(iso: Int, shutter: CMTime, aperture: Float) -> CameraSettingsModel {
        let model = CameraSettingsModel()
        model.currentIso = iso
        model.currentShutterSpeed = shutter
        model.currentApertureValue = aperture
        return model
    }
    static let unitExposure = settings(iso: 100, shutter: CMTime(value: 1, timescale: 60), aperture: 1.0)
    static let doubledExposure = settings(iso: 200, shutter: CMTime(value: 1, timescale: 120), aperture: 2.0)

    // MARK: - Per-pixel reference (the shader's formulas)

    static func linearize(_ v: Double) -> Double { v < 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    static func luma(_ c: RGB) -> Double { WR * c.r + WG * c.g + WB * c.b }
    static func luminance(_ c: RGB) -> Double { WR * linearize(c.r) + WG * linearize(c.g) + WB * linearize(c.b) }
    static func saturation(_ c: RGB) -> Double {
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b)
        return mx == 0.0 ? 0.0 : (mx - mn) / mx
    }
    static func value(_ c: RGB) -> Double { max(c.r, c.g, c.b) }
    //Hue in radians, the shader's branches
    static func hue(_ c: RGB) -> Double {
        let mx = max(c.r, c.g, c.b), mn = min(c.r, c.g, c.b), d = mx - mn
        if d < 1e-5 { return 0.0 }
        if mx == c.r { return 2.0 * Double.pi * (c.g - c.b + d * (c.g < c.b ? 6.0 : 0.0)) / (6.0 * d) }
        if mx == c.g { return 2.0 * Double.pi * (c.b - c.r + d * 2.0) / (6.0 * d) }
        return 2.0 * Double.pi * (c.r - c.g + d * 4.0) / (6.0 * d)
    }
    static func hueDistanceDegrees(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360.0)
        return min(d, 360.0 - d)
    }

    // MARK: - Frames

    //A synthetic frame: the intended 8-bit RGB pixels, their encoding into the camera's Y and CbCr planes, and the RGB the
    //analyzers see after ycbcrToRGBTransform
    struct Frame {
        let width: Int
        let height: Int
        var intended: [(UInt8, UInt8, UInt8)]
        var yPlane: [UInt8]
        var cbcrPlane: [UInt8]  //interleaved Cb, Cr per 2x2 block, (width+1)/2 x (height+1)/2

        var chromaWidth: Int { (width + 1) / 2 }
        var chromaHeight: Int { (height + 1) / 2 }

        init(width: Int, height: Int, color: (Int, Int) -> (UInt8, UInt8, UInt8)) {
            self.width = width
            self.height = height
            intended = []
            intended.reserveCapacity(width * height)
            for y in 0..<height {
                for x in 0..<width {
                    intended.append(color(x, y))
                }
            }
            //BT.601 full range, the inverse of the shader's ycbcrToRGBTransform; chroma is the mean of each 2x2 block
            func ycbcr(_ c: (UInt8, UInt8, UInt8)) -> (y: Double, cb: Double, cr: Double) {
                let r = Double(c.0), g = Double(c.1), b = Double(c.2)
                let y = 0.299 * r + 0.587 * g + 0.114 * b
                return (y, (b - y) / 1.772 + 128.0, (r - y) / 1.402 + 128.0)
            }
            func byte(_ v: Double) -> UInt8 { UInt8(min(max(v.rounded(), 0.0), 255.0)) }
            yPlane = intended.map { byte(ycbcr($0).y) }
            let cw = (width + 1) / 2, ch = (height + 1) / 2
            cbcrPlane = [UInt8](repeating: 128, count: cw * ch * 2)
            for by in 0..<ch {
                for bx in 0..<cw {
                    var cb = 0.0, cr = 0.0, n = 0.0
                    for y in (2 * by)..<min(2 * by + 2, height) {
                        for x in (2 * bx)..<min(2 * bx + 2, width) {
                            let c = ycbcr(intended[y * width + x])
                            cb += c.cb
                            cr += c.cr
                            n += 1
                        }
                    }
                    cbcrPlane[(by * cw + bx) * 2] = byte(cb / n)
                    cbcrPlane[(by * cw + bx) * 2 + 1] = byte(cr / n)
                }
            }
        }

        //What the shader reconstructs for this pixel (ycbcrToRGBTransform, unclamped like the shader): the chroma zero
        //is 128 of 255, so a grey reconstructs exactly grey
        func rgb(_ x: Int, _ y: Int) -> RGB {
            let yy = Double(yPlane[y * width + x]) / 255.0
            let cb = Double(cbcrPlane[((y / 2) * chromaWidth + x / 2) * 2]) / 255.0 - 128.0 / 255.0
            let cr = Double(cbcrPlane[((y / 2) * chromaWidth + x / 2) * 2 + 1]) / 255.0 - 128.0 / 255.0
            return (yy + 1.4020 * cr, yy - 0.3441 * cb - 0.7141 * cr, yy + 1.7720 * cb)
        }

        func yValue(_ x: Int, _ y: Int) -> Double { Double(yPlane[y * width + x]) / 255.0 }

        //The pixel columns/rows a normalized region selects: the analyzers round the region outwards to whole pixels
        //(floor of the lower edge, ceiling of the upper one) and process the half-open ranges, so the reference does too
        func columns(_ roi: CGRect) -> Range<Int> {
            Int(floor(roi.minX * CGFloat(width)))..<Int(ceil(roi.maxX * CGFloat(width)))
        }
        func rows(_ roi: CGRect) -> Range<Int> {
            Int(floor(roi.minY * CGFloat(height)))..<Int(ceil(roi.maxY * CGFloat(height)))
        }

        func mean(_ roi: CGRect, _ f: (RGB) -> Double) -> Double {
            var sum = 0.0, n = 0.0
            for y in rows(roi) {
                for x in columns(roi) {
                    sum += f(rgb(x, y))
                    n += 1
                }
            }
            return sum / n
        }

        func meanY(_ roi: CGRect) -> Double {
            var sum = 0.0, n = 0.0
            for y in rows(roi) {
                for x in columns(roi) {
                    sum += yValue(x, y)
                    n += 1
                }
            }
            return sum / n
        }

        func minMax(_ roi: CGRect) -> (min: Double, max: Double) {
            var mn = Double.infinity, mx = -Double.infinity
            for y in rows(roi) {
                for x in columns(roi) {
                    let c = rgb(x, y)
                    mn = min(mn, c.r, c.g, c.b)
                    mx = max(mx, c.r, c.g, c.b)
                }
            }
            return (mn, mx)
        }

        //Mean hue in degrees as the direction of the mean unit vector, and that vector's length
        func meanHue(_ roi: CGRect) -> (degrees: Double, length: Double) {
            var sx = 0.0, sy = 0.0, n = 0.0
            for y in rows(roi) {
                for x in columns(roi) {
                    let h = CameraAnalyzerMathTests.hue(rgb(x, y))
                    sx += cos(h)
                    sy += sin(h)
                    n += 1
                }
            }
            var degrees = atan2(sy, sx) * 180.0 / Double.pi
            if degrees < 0 { degrees += 360.0 }
            return (degrees, (sx * sx + sy * sy).squareRoot() / n)
        }
    }

    static func uniform(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Frame { Frame(width: W, height: H) { _, _ in (r, g, b) } }

    //Ramps and a pseudo-random channel, so that every value occurs and no tile is uniform
    static func textured() -> Frame {
        Frame(width: W, height: H) { x, y in (UInt8(x * 255 / (W - 1)), UInt8(y * 255 / (H - 1)), UInt8((x * 7 + y * 13) % 256)) }
    }

    static func hsvToRgb(_ h: Double, _ s: Double, _ v: Double) -> (UInt8, UInt8, UInt8) {
        let c = UIColor(hue: CGFloat(h / 360.0), saturation: CGFloat(s), brightness: CGFloat(v), alpha: 1.0)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt8((r * 255).rounded()), UInt8((g * 255).rounded()), UInt8((b * 255).rounded()))
    }

    // MARK: - The camera's texture path

    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var textureCache: CVMetalTextureCache!
    var pixelBuffer: CVPixelBuffer?
    var cvTextureY: CVMetalTexture?
    var cvTextureCbCr: CVMetalTexture?
    var textureY: MTLTexture!
    var textureCbCr: MTLTexture!
    var frame: Frame!

    override func setUpWithError() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("no Metal device on this host")
        }
        self.device = device
        commandQueue = device.makeCommandQueue()
        AnalyzingModule.initialize(metalDevice: device)
        XCTAssertNotNil(AnalyzingModule.gpuFunctionLibrary, "the app's Metal library did not load")
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        textureCache = try XCTUnwrap(cache)
    }

    //Hands a frame to the analyzers the way CameraService.captureOutput does: a 420f pixel buffer, one texture per plane
    private func present(_ frame: Frame) throws {
        self.frame = frame
        var buffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, frame.width, frame.height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attributes as CFDictionary, &buffer)
        XCTAssertEqual(status, kCVReturnSuccess, "CVPixelBufferCreate failed")
        let pixelBuffer = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        for plane in 0..<2 {
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane)).assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
            let rows = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
            let rowBytes = plane == 0 ? frame.width : frame.chromaWidth * 2
            let source = plane == 0 ? frame.yPlane : frame.cbcrPlane
            XCTAssertEqual(rows, plane == 0 ? frame.height : frame.chromaHeight)
            for row in 0..<rows {
                source.withUnsafeBufferPointer { pointer in
                    (base + row * stride).update(from: pointer.baseAddress! + row * rowBytes, count: rowBytes)
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        self.pixelBuffer = pixelBuffer

        func texture(plane: Int, format: MTLPixelFormat) throws -> (CVMetalTexture, MTLTexture) {
            var cvTexture: CVMetalTexture?
            let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, plane)
            let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
            let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, format, width, height, plane, &cvTexture)
            XCTAssertEqual(status, kCVReturnSuccess, "no Metal texture for plane \(plane)")
            let cv = try XCTUnwrap(cvTexture)
            return (cv, try XCTUnwrap(CVMetalTextureGetTexture(cv)))
        }
        (cvTextureY, textureY) = try texture(plane: 0, format: .r8Unorm)
        (cvTextureCbCr, textureCbCr) = try texture(plane: 1, format: .rg8Unorm)
        XCTAssertEqual(textureY.width, frame.width)
        XCTAssertEqual(textureCbCr.width, frame.chromaWidth)
    }

    //One frame through one analyzer, exactly the steps AnalyzingRenderer takes per frame
    private func run(_ module: AnalyzingModule, roi: CGRect, settings: CameraSettingsModel) throws {
        module.loadMetal()
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        module.update(selectionArea: roi, metalCommandBuffer: commandBuffer, cameraImageTextureY: textureY, cameraImageTextureCbCr: textureCbCr)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertNil(commandBuffer.error, "GPU error: \(String(describing: commandBuffer.error))")
        module.prepareWriteToBuffers(cameraSettings: settings)
        module.writeToBuffers()
    }

    private func buffer(_ name: String) throws -> DataBuffer {
        try DataBuffer(name: name, size: 0, baseContents: [], static: false)
    }

    private func channel(linear: Bool, _ channel: LuminanceAnalyzer.Channel, roi: CGRect = full, settings: CameraSettingsModel = unitExposure) throws -> Double {
        let out = try buffer("out")
        try run(LuminanceAnalyzer(result: out, linear: linear, channel: channel), roi: roi, settings: settings)
        XCTAssertEqual(out.toArray().count, 1)
        return try XCTUnwrap(out.toArray().last)
    }

    private func hsv(_ mode: HSVAnalyzer.HSV_Mode, roi: CGRect = full) throws -> Double {
        let out = try buffer("out")
        try run(HSVAnalyzer(result: out, mode: mode), roi: roi, settings: Self.unitExposure)
        return try XCTUnwrap(out.toArray().last)
    }

    private func exposure(roi: CGRect = full) throws -> ExposureAnalyzer {
        let analyzer = ExposureAnalyzer()
        try run(analyzer, roi: roi, settings: Self.unitExposure)
        return analyzer
    }

    private func spectra(_ orientation: SpectrumOrientation, roi: CGRect = full, settings: CameraSettingsModel = unitExposure) throws -> [String: [Double]] {
        let names = ["luminance", "pixelPosition", "linearRed", "linearGreen", "linearBlue"]
        var buffers: [String: DataBuffer] = [:]
        for name in names { buffers[name] = try buffer(name) }
        let module = SpectroscopyAnalyzer(result: buffers["luminance"], xAxis: buffers["pixelPosition"], linearRed: buffers["linearRed"], linearGreen: buffers["linearGreen"], linearBlue: buffers["linearBlue"])
        module.setAnalysisOrientation(orientation: orientation)
        try run(module, roi: roi, settings: settings)
        return buffers.mapValues { $0.toArray() }
    }

    //The YCbCr round trip stays within the 8-bit quantization of the intended colour
    private func assertReconstruction(_ frame: Frame, x: Int, y: Int, tolerance: Double = 2.0 / 255.0) {
        let c = frame.rgb(x, y)
        let i = frame.intended[y * frame.width + x]
        XCTAssertEqual(c.r, Double(i.0) / 255.0, accuracy: tolerance, "reconstructed red")
        XCTAssertEqual(c.g, Double(i.1) / 255.0, accuracy: tolerance, "reconstructed green")
        XCTAssertEqual(c.b, Double(i.2) / 255.0, accuracy: tolerance, "reconstructed blue")
    }

    // MARK: - Tests

    func testEveryScalarChannelOnAUniformFrame() throws {
        let frame = Self.uniform(200, 100, 50)
        try present(frame)
        assertReconstruction(frame, x: 0, y: 0)
        let c = frame.rgb(0, 0)
        let t = Self.uniformTolerance

        XCTAssertEqual(try channel(linear: false, .red), c.r, accuracy: t, "red")
        XCTAssertEqual(try channel(linear: false, .green), c.g, accuracy: t, "green")
        XCTAssertEqual(try channel(linear: false, .blue), c.b, accuracy: t, "blue")
        XCTAssertEqual(try channel(linear: false, .luma), Self.luma(c), accuracy: t, "luma")
        XCTAssertEqual(try channel(linear: true, .red), Self.linearize(c.r), accuracy: t, "linearRed")
        XCTAssertEqual(try channel(linear: true, .green), Self.linearize(c.g), accuracy: t, "linearGreen")
        XCTAssertEqual(try channel(linear: true, .blue), Self.linearize(c.b), accuracy: t, "linearBlue")
        XCTAssertEqual(try channel(linear: true, .luma), Self.luminance(c), accuracy: t, "luminance")
        let hue = try hsv(.Hue)
        XCTAssertEqual(hue, Self.hue(c) * 180.0 / Double.pi, accuracy: 0.1, "hue")
        XCTAssertEqual(hue, 20.0, accuracy: 1.0, "hue of (200, 100, 50) is 20 degrees up to the chroma quantization")
        XCTAssertEqual(try hsv(.Saturation), Self.saturation(c), accuracy: t, "saturation")
        XCTAssertEqual(try hsv(.Value), Self.value(c), accuracy: t, "value")

        //The auto-exposure statistics share the pipeline. Min and max are taken over the reconstructed channels; the
        //luma statistic is the mean of the camera's Y plane (BT.601 as encoded), not the BT.709 luma output
        let stats = try exposure()
        XCTAssertEqual(stats.minRGB, c.b, accuracy: t, "exposure minRGB")
        XCTAssertEqual(stats.maxRGB, c.r, accuracy: t, "exposure maxRGB")
        XCTAssertEqual(stats.meanLuma, frame.yValue(0, 0), accuracy: t, "exposure meanLuma")
    }

    func testHueBranchesAndGrey() throws {
        //Pure colours do not survive the chroma quantization exactly, so the branch results are compared with the
        //reference hue of the reconstructed colour and only loosely with the ideal angle
        for (name, frame, ideal) in [("green", Self.uniform(0, 255, 0), 120.0), ("blue", Self.uniform(0, 0, 255), 240.0)] {
            try present(frame)
            let reference = Self.hue(frame.rgb(0, 0)) * 180.0 / Double.pi
            XCTAssertEqual(reference, ideal, accuracy: 1.0, "\(name) up to the chroma quantization")
            XCTAssertEqual(try hsv(.Hue), reference, accuracy: 0.1, name)
        }
        let magenta = Self.uniform(255, 0, 128)
        try present(magenta)
        let reference = Self.hue(magenta.rgb(0, 0)) * 180.0 / Double.pi
        XCTAssertEqual(reference, 329.88, accuracy: 1.0, "the wrap-around branch of red, up to the chroma quantization")
        XCTAssertEqual(try hsv(.Hue), reference, accuracy: 0.1, "magenta-ish, the wrap-around branch of red")
        try present(Self.uniform(100, 100, 100))
        XCTAssertEqual(Self.hueDistanceDegrees(0.0, try hsv(.Hue)), 0.0, accuracy: 0.1, "grey has hue 0")
        XCTAssertEqual(try hsv(.Saturation), 0.0, accuracy: Self.uniformTolerance, "grey has no saturation")
        XCTAssertEqual(try hsv(.Value), 100.0 / 255.0, accuracy: Self.uniformTolerance, "value of grey")
    }

    func testHueIsAveragedOnTheColourWheel() throws {
        //Half the frame just below 360 degrees, half just above 0: the mean lies at 0, an arithmetic mean of the angles
        //would report 180 (cyan). The boundary sits on an even column so no chroma block straddles it.
        let frame = Frame(width: Self.W, height: Self.H) { x, _ in x < 166 ? (255, 0, 43) : (255, 43, 0) }
        try present(frame)
        let reference = frame.meanHue(Self.full)
        XCTAssertLessThan(Self.hueDistanceDegrees(0.0, reference.degrees), 1.0, "the reference itself sits at the wrap-around")
        let hue = try hsv(.Hue)
        XCTAssertLessThan(Self.hueDistanceDegrees(reference.degrees, hue), 0.1, "hue \(hue) vs reference \(reference.degrees)")
        XCTAssertGreaterThan(Self.hueDistanceDegrees(180.0, hue), 170.0, "hue \(hue) is the arithmetic mean of the angles")
    }

    func testExposureFactorScalesOnlyTheLinearOutputs() throws {
        let frame = Self.uniform(200, 100, 50)
        try present(frame)
        let c = frame.rgb(0, 0)
        let t = Self.uniformTolerance
        XCTAssertEqual(try channel(linear: true, .luma, settings: Self.doubledExposure), 2 * Self.luminance(c), accuracy: 2 * t, "luminance")
        XCTAssertEqual(try channel(linear: true, .red, settings: Self.doubledExposure), 2 * Self.linearize(c.r), accuracy: 2 * t, "linearRed")
        XCTAssertEqual(try channel(linear: false, .luma, settings: Self.doubledExposure), Self.luma(c), accuracy: t, "luma")
        XCTAssertEqual(try channel(linear: false, .red, settings: Self.doubledExposure), c.r, accuracy: t, "red")
    }

    func testRegionOfInterestSelectsTheRightPixels() throws {
        //Quadrant boundaries on even coordinates so every chroma block lies within one quadrant
        let frame = Frame(width: Self.W, height: Self.H) { x, y in
            y < 98 ? (x < 166 ? (255, 0, 0) : (0, 255, 0)) : (x < 166 ? (0, 0, 255) : (255, 255, 255))
        }
        try present(frame)
        let t = Self.uniformTolerance
        //On iOS the selection is a rectangle in the texture: x1..x2 along the columns from the left, y1..y2 along the
        //rows from the top (the front camera mirrors it before the analyzers see it). Each region lies strictly inside
        //its quadrant and must return exactly that quadrant's colour as the pipeline reconstructs it.
        let cases: [(CGRect, (Int, Int), String)] = [
            (CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3), (0, 0), "top left, red"),
            (CGRect(x: 0.6, y: 0.1, width: 0.3, height: 0.3), (330, 0), "top right, green"),
            (CGRect(x: 0.1, y: 0.6, width: 0.3, height: 0.3), (0, 196), "bottom left, blue"),
            (CGRect(x: 0.6, y: 0.6, width: 0.3, height: 0.3), (330, 196), "bottom right, white")
        ]
        for (roi, pixel, name) in cases {
            assertReconstruction(frame, x: pixel.0, y: pixel.1)
            let expected = frame.rgb(pixel.0, pixel.1)
            XCTAssertEqual(try channel(linear: false, .red, roi: roi), expected.r, accuracy: t, "red in \(name)")
            XCTAssertEqual(try channel(linear: false, .green, roi: roi), expected.g, accuracy: t, "green in \(name)")
            XCTAssertEqual(try channel(linear: false, .blue, roi: roi), expected.b, accuracy: t, "blue in \(name)")
        }
        //A region across a boundary averages both sides: the reference selects the same whole pixels, so this is exact
        let topHalf = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.3)
        XCTAssertEqual(try channel(linear: false, .red, roi: topHalf), frame.mean(topHalf) { $0.r }, accuracy: t)
        XCTAssertEqual(try channel(linear: false, .green, roi: topHalf), frame.mean(topHalf) { $0.g }, accuracy: t)
        XCTAssertEqual(frame.columns(topHalf), 33..<298, "133 red columns, 132 green ones")
        XCTAssertEqual(try channel(linear: false, .blue, roi: topHalf), frame.mean(topHalf) { $0.b }, accuracy: t)
        XCTAssertLessThan(try channel(linear: false, .blue, roi: topHalf), 0.01, "nothing but red and green up there")

        let stats = try exposure()
        let minMax = frame.minMax(Self.full)
        XCTAssertEqual(stats.minRGB, minMax.min, accuracy: t, "exposure minRGB")
        XCTAssertEqual(stats.maxRGB, minMax.max, accuracy: t, "exposure maxRGB")
        XCTAssertEqual(minMax.min, 0.0, accuracy: 0.01, "black channels up to the chroma quantization")
        XCTAssertEqual(minMax.max, 1.0, accuracy: 0.01, "white channels up to the chroma quantization")

        //An empty selection has no pixels: NaN, not a stale or infinite value. (The region is rounded outwards to whole
        //pixels, so it is only empty when a zero-width edge lies exactly on a pixel boundary.)
        let empty = CGRect(x: 0, y: 0.5, width: 0, height: 0.2)
        XCTAssertTrue(try channel(linear: false, .red, roi: empty).isNaN, "empty selection")
        XCTAssertTrue(try hsv(.Hue, roi: empty).isNaN, "empty selection, hue")
        XCTAssertTrue(try exposure(roi: empty).meanLuma.isNaN, "empty selection, exposure")
    }

    func testReductionChainOnATexturedFrame() throws {
        let frame = Self.textured()
        try present(frame)
        let t = Self.texturedTolerance
        let full = Self.full
        XCTAssertEqual(try channel(linear: false, .red), frame.mean(full) { $0.r }, accuracy: t, "red")
        XCTAssertEqual(try channel(linear: false, .green), frame.mean(full) { $0.g }, accuracy: t, "green")
        XCTAssertEqual(try channel(linear: false, .blue), frame.mean(full) { $0.b }, accuracy: t, "blue")
        XCTAssertEqual(try channel(linear: false, .luma), frame.mean(full) { Self.luma($0) }, accuracy: t, "luma")
        XCTAssertEqual(try channel(linear: true, .luma), frame.mean(full) { Self.luminance($0) }, accuracy: t, "luminance")
        XCTAssertEqual(try channel(linear: true, .red), frame.mean(full) { Self.linearize($0.r) }, accuracy: t, "linearRed")
        XCTAssertEqual(try channel(linear: true, .green), frame.mean(full) { Self.linearize($0.g) }, accuracy: t, "linearGreen")
        XCTAssertEqual(try channel(linear: true, .blue), frame.mean(full) { Self.linearize($0.b) }, accuracy: t, "linearBlue")
        XCTAssertEqual(try hsv(.Saturation), frame.mean(full) { Self.saturation($0) }, accuracy: t, "saturation")
        XCTAssertEqual(try hsv(.Value), frame.mean(full) { Self.value($0) }, accuracy: t, "value")
        //A region that does not start at the frame edge and ends in partial threadgroups
        let region = CGRect(x: 0.13, y: 0.21, width: 0.61, height: 0.47)
        XCTAssertEqual(try channel(linear: false, .luma, roi: region), frame.mean(region) { Self.luma($0) }, accuracy: t, "luma in a region")
        XCTAssertEqual(try channel(linear: true, .green, roi: region), frame.mean(region) { Self.linearize($0.g) }, accuracy: t, "linearGreen in a region")
        XCTAssertEqual(try hsv(.Saturation, roi: region), frame.mean(region) { Self.saturation($0) }, accuracy: t, "saturation in a region")
        let stats = try exposure(roi: region)
        XCTAssertEqual(stats.meanLuma, frame.meanY(region), accuracy: t, "exposure meanLuma in a region")
    }

    func testHueReductionOnSweepsAndRamps() throws {
        //The mean hue is the direction of the mean unit vector, so a frame only makes a meaningful test when that vector
        //is not short: the textured frame above covers the colour wheel almost uniformly and its angle would be
        //ill-conditioned. These frames keep the partial tiles and the ramps but leave a mean vector of length 0.6 or more.
        let W = Self.W, H = Self.H
        let cases: [(String, Frame)] = [
            ("half circle sweep", Frame(width: W, height: H) { x, _ in Self.hsvToRgb(180.0 * Double(x) / Double(W - 1), 1.0, 1.0) }),
            ("half circle sweep at low saturation and value", Frame(width: W, height: H) { x, _ in Self.hsvToRgb(180.0 * Double(x) / Double(W - 1), 0.1, 0.5) }),
            ("red and green ramps", Frame(width: W, height: H) { x, y in (UInt8(x * 255 / (W - 1)), UInt8(y * 255 / (H - 1)), 0) })
        ]
        for (name, frame) in cases {
            try present(frame)
            let reference = frame.meanHue(Self.full)
            XCTAssertGreaterThanOrEqual(reference.length, 0.5, "\(name): the mean vector is too short for a meaningful check")
            let hue = try hsv(.Hue)
            XCTAssertLessThan(Self.hueDistanceDegrees(reference.degrees, hue), 0.1, "\(name): hue \(hue) vs reference \(reference.degrees)")
        }
    }

    func testSpectraFollowTheSpectrumAxis() throws {
        //A red ramp along the texture width over constant green: the landscape orientation (spectrum along x) resolves it
        //into one value per column, the portrait one averages every row to the same flat spectrum
        let W = Self.W, H = Self.H
        let frame = Frame(width: W, height: H) { x, _ in (UInt8(x * 255 / (W - 1)), 100, 0) }
        try present(frame)
        let factor = 2.0
        let settings = Self.doubledExposure

        let ramp = try spectra(.landscape, settings: settings)
        XCTAssertEqual(ramp["pixelPosition"]?.count, W, "one value per column")
        for name in ["luminance", "linearRed", "linearGreen", "linearBlue"] {
            XCTAssertEqual(ramp[name]?.count, W, "\(name) as long as pixelPosition")
        }
        let tolerance = factor * Self.uniformTolerance
        let r = { (name: String, i: Int) -> Double in ramp[name]?[i] ?? .nan }
        for i in 0..<W {
            XCTAssertEqual(r("pixelPosition", i), Double(i), accuracy: 1e-9, "pixel position")
            //Every row of a column is the same colour, so the column mean is that pixel's value
            let c = frame.rgb(i, 0)
            XCTAssertEqual(r("linearRed", i), factor * Self.linearize(c.r), accuracy: tolerance, "linearRed at column \(i)")
            XCTAssertEqual(r("linearGreen", i), factor * Self.linearize(c.g), accuracy: tolerance, "linearGreen at column \(i)")
            XCTAssertEqual(r("linearBlue", i), factor * Self.linearize(c.b), accuracy: tolerance, "linearBlue at column \(i)")
            XCTAssertLessThan(abs(r("linearBlue", i)), 3e-3, "no blue up to the chroma quantization")
            XCTAssertEqual(r("luminance", i), factor * Self.luminance(c), accuracy: tolerance, "luminance at column \(i)")
        }
        XCTAssertGreaterThan(r("linearRed", W - 1), r("linearRed", 0) + 1.0, "the red spectrum rises along the ramp")

        let flat = try spectra(.portrait, settings: settings)
        XCTAssertEqual(flat["pixelPosition"]?.count, H, "one value per row")
        let rowMean = factor * frame.mean(Self.full) { Self.linearize($0.r) }
        for j in 0..<H {
            XCTAssertEqual(flat["linearRed"]?[j] ?? .nan, rowMean, accuracy: factor * Self.texturedTolerance, "linearRed at row \(j)")
        }

        //A region: the spectrum covers exactly its columns, pixelPosition counts from the region's first column
        let region = CGRect(x: 0.2, y: 0.45, width: 0.6, height: 0.1)
        let part = try spectra(.landscape, roi: region, settings: settings)
        let columns = frame.columns(region)
        XCTAssertEqual(part["pixelPosition"]?.count, columns.count)
        XCTAssertEqual(part["pixelPosition"]?.first ?? .nan, Double(columns.lowerBound), accuracy: 1e-9)
        XCTAssertEqual(part["luminance"]?.count, columns.count)
    }

    //The value-level contract of the colour channels (test-matrix row camera-color-channels), through the renderer's own
    //wiring of buffers to analyzers: the BT.709 identities per frame, the exposure factor on the linear outputs only, and
    //under spectroscopy exactly as many spectrum values as pixelPosition while red/green/blue stay scalars
    func testColourChannelIdentitiesThroughTheRendererWiring() throws {
        let frame = Self.textured()
        try present(frame)
        let names = ["t", "luma", "luminance", "hue", "saturation", "value", "red", "green", "blue", "linearRed", "linearGreen", "linearBlue", "pixelPosition"]

        func measure(feature: CameraFeature, settings: CameraSettingsModel) throws -> [String: [Double]] {
            var buffers: [String: DataBuffer] = [:]
            for name in names { buffers[name] = try buffer(name) }
            let cameraBuffers = ExperimentCameraBuffers(luminanceBuffer: buffers["luminance"], lumaBuffer: buffers["luma"], hueBuffer: buffers["hue"], saturationBuffer: buffers["saturation"], valueBuffer: buffers["value"], tBuffer: buffers["t"], pixelPosition: buffers["pixelPosition"], redBuffer: buffers["red"], greenBuffer: buffers["green"], blueBuffer: buffers["blue"], linearRedBuffer: buffers["linearRed"], linearGreenBuffer: buffers["linearGreen"], linearBlueBuffer: buffers["linearBlue"])
            let renderer = AnalyzingRenderer(inFlightSemaphore: DispatchSemaphore(value: 1))
            renderer.initializeCameraBuffer(cameraBuffers: cameraBuffers, feature: feature)
            let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
            for module in renderer.analysingModules {
                module.update(selectionArea: Self.full, metalCommandBuffer: commandBuffer, cameraImageTextureY: textureY, cameraImageTextureCbCr: textureCbCr)
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            for module in renderer.analysingModules {
                module.prepareWriteToBuffers(cameraSettings: settings)
                module.writeToBuffers()
            }
            return buffers.mapValues { $0.toArray() }
        }

        //Photometric: every output one value per frame, the identities exact up to float rounding
        let photometric = try measure(feature: .PHOTOMETRIC, settings: Self.unitExposure)
        for name in names where name != "t" && name != "pixelPosition" {
            XCTAssertEqual(photometric[name]?.count, 1, "\(name) is one value per frame")
        }
        XCTAssertEqual(photometric["pixelPosition"]?.count, 0, "no spectrum axis under photometry")
        let v = { (name: String) in photometric[name]?.first ?? .nan }
        XCTAssertEqual(v("luma"), Self.WR * v("red") + Self.WG * v("green") + Self.WB * v("blue"), accuracy: 1e-5, "luma identity")
        XCTAssertEqual(v("luminance"), Self.WR * v("linearRed") + Self.WG * v("linearGreen") + Self.WB * v("linearBlue"), accuracy: 1e-5, "luminance identity")
        XCTAssertEqual(v("red"), frame.mean(Self.full) { $0.r }, accuracy: Self.texturedTolerance)
        XCTAssertEqual(v("linearBlue"), frame.mean(Self.full) { Self.linearize($0.b) }, accuracy: Self.texturedTolerance)

        let doubled = try measure(feature: .PHOTOMETRIC, settings: Self.doubledExposure)
        let d = { (name: String) in doubled[name]?.first ?? .nan }
        for name in ["luminance", "linearRed", "linearGreen", "linearBlue"] {
            XCTAssertEqual(d(name), 2 * v(name), accuracy: 1e-5, "\(name) scales with the exposure factor")
        }
        for name in ["luma", "red", "green", "blue", "hue", "saturation", "value"] {
            XCTAssertEqual(d(name), v(name), accuracy: 1e-9, "\(name) ignores the exposure factor")
        }

        //Spectroscopy: the linear triple and luminance are spectra as long as pixelPosition, the rest stays scalar
        let spectroscopy = try measure(feature: .SPECTROSCOPY, settings: Self.unitExposure)
        XCTAssertEqual(spectroscopy["pixelPosition"]?.count, Self.W)
        for name in ["luminance", "linearRed", "linearGreen", "linearBlue"] {
            XCTAssertEqual(spectroscopy[name]?.count, Self.W, "\(name) is a spectrum as long as pixelPosition")
        }
        for name in ["luma", "red", "green", "blue", "hue", "saturation", "value"] {
            XCTAssertEqual(spectroscopy[name]?.count, 1, "\(name) stays one value per frame under spectroscopy")
            XCTAssertEqual(spectroscopy[name]?.first ?? .nan, v(name), accuracy: 1e-9, "\(name) does not depend on the feature")
        }
        for i in stride(from: 0, to: Self.W, by: 37) {
            let s = { (name: String) in spectroscopy[name]?[i] ?? .nan }
            XCTAssertEqual(s("luminance"), Self.WR * s("linearRed") + Self.WG * s("linearGreen") + Self.WB * s("linearBlue"), accuracy: 1e-5, "luminance identity at pixel \(i)")
        }
    }
}
