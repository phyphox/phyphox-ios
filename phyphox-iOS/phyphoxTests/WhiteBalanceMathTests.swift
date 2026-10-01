//
//  WhiteBalanceMathTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
import AVFoundation
@testable import phyphox

//The colour math behind the camera's white balance by white point (file format 1.21, phyphox-docs
//docs/file-format/input.md "White balance"): temperature and Duv to a chromaticity and back, the camera-gui's scale,
//and the gain sanitizing that keeps AVCaptureDevice from throwing. The sign conventions are the ones that matter: a
//positive tint lies above the locus (towards green), so a neutral surface comes out magenta. Same check values as
//Android's WhiteBalanceMathTest, so both apps agree on the white point a file asks for.
final class WhiteBalanceMathTests: XCTestCase {

    private func assertClose(_ expected: (Double, Double), _ actual: (Double, Double), _ tolerance: Double, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(expected.0, actual.0, accuracy: tolerance, "\(message) [0]", file: file, line: line)
        XCTAssertEqual(expected.1, actual.1, accuracy: tolerance, "\(message) [1]", file: file, line: line)
    }

    func testPlanckianLocusMatchesTabulatedPoints() {
        assertClose((0.3135, 0.3237), WhiteBalance.planckianXY(6500.0), 0.001, "6500 K")
        assertClose((0.4234, 0.3990), WhiteBalance.planckianXY(3200.0), 0.002, "3200 K")
        assertClose((0.4476, 0.4074), WhiteBalance.planckianXY(2856.0), 0.003, "illuminant A")
        assertClose((0.5267, 0.4133), WhiteBalance.planckianXY(2000.0), 0.003, "2000 K")
    }

    func testUvConversionRoundTrips() {
        let xy = (x: 0.3127, y: 0.3290)
        assertClose(xy, WhiteBalance.uvToXy(WhiteBalance.xyToUv(xy)), 1e-12, "xy -> uv -> xy")
        assertClose((0.1978, 0.3122), WhiteBalance.xyToUv(xy), 0.0005, "D65 in uv")
    }

    func testTintIsDuvTowardsGreen() {
        let onLocus = WhiteBalance.xyToUv(WhiteBalance.chromaticity(temperature: 5500.0, duv: 0.0))
        let green = WhiteBalance.xyToUv(WhiteBalance.chromaticity(temperature: 5500.0, duv: 0.01))
        let magenta = WhiteBalance.xyToUv(WhiteBalance.chromaticity(temperature: 5500.0, duv: -0.01))
        let d = ((green.u - onLocus.u) * (green.u - onLocus.u) + (green.v - onLocus.v) * (green.v - onLocus.v)).squareRoot()
        XCTAssertEqual(0.01, d, accuracy: 1e-6, "the offset is the Duv distance")
        XCTAssertGreaterThan(green.v, onLocus.v, "positive Duv lies above the locus")
        XCTAssertLessThan(magenta.v, onLocus.v, "negative Duv lies below the locus")
        //D65 sits about 0.0032 above the Planckian locus at 6504 K
        assertClose(WhiteBalance.D65, WhiteBalance.chromaticity(temperature: 6504.0, duv: 0.0032), 0.0006, "D65 from 6504 K and Duv 0.0032")
    }

    func testTemperaturesOutsideTheLocusApproximationAreClamped() {
        assertClose(WhiteBalance.planckianXY(1667.0), WhiteBalance.planckianXY(1000.0), 1e-12, "below")
        assertClose(WhiteBalance.planckianXY(25000.0), WhiteBalance.planckianXY(40000.0), 1e-12, "above")
    }

    //The inverse recovers the white point the device reports when it had to clamp the gains
    func testTemperatureAndTintInvertTheChromaticity() {
        for temperature in [2000.0, 2850.0, 3200.0, 4200.0, 5500.0, 6504.0, 8000.0, 15000.0, 24000.0] {
            for duv in [0.0, 0.01, -0.004, 0.02] {
                let xy = WhiteBalance.chromaticity(temperature: temperature, duv: duv)
                let back = WhiteBalance.temperatureAndTint(x: xy.x, y: xy.y)
                XCTAssertEqual(temperature, back.temperature, accuracy: temperature * 0.002, "\(temperature) K, Duv \(duv)")
                XCTAssertEqual(duv, back.duv, accuracy: 1e-5, "\(temperature) K, Duv \(duv)")
            }
        }
        let d65 = WhiteBalance.temperatureAndTint(x: WhiteBalance.D65.x, y: WhiteBalance.D65.y)
        XCTAssertEqual(6504.0, d65.temperature, accuracy: 20.0, "D65 is 6504 K")
        XCTAssertEqual(0.0032, d65.duv, accuracy: 0.0005, "D65 lies 0.0032 above the locus")
    }

    func testScaleIsLogarithmicAndRoundsToTenKelvin() {
        let range = WhiteBalance.minTemperature...WhiteBalance.maxTemperature
        //1667 rounds to 1670, as on Android
        XCTAssertEqual(WhiteBalance.temperature(atPosition: 0.0, range: range), 1670)
        XCTAssertEqual(WhiteBalance.temperature(atPosition: 1.0, range: range), WhiteBalance.maxTemperature)
        XCTAssertEqual(WhiteBalance.temperature(atPosition: -1.0, range: range), 1670, "clamped below")
        XCTAssertEqual(WhiteBalance.temperature(atPosition: 2.0, range: range), WhiteBalance.maxTemperature, "clamped above")
        //The geometric middle of 1667 and 25000 is about 6455 K
        XCTAssertEqual(WhiteBalance.temperature(atPosition: 0.5, range: range), 6450, accuracy: 10)
        for temperature in [1670, 3200, 5500, 6500, 12000, 25000] {
            let position = WhiteBalance.position(ofTemperature: temperature, range: range)
            XCTAssertEqual(WhiteBalance.temperature(atPosition: position, range: range), temperature, "\(temperature) K round trip")
        }
        XCTAssertEqual(WhiteBalance.temperature(atPosition: WhiteBalance.position(ofTemperature: 3204, range: range), range: range), 3200, "rounded to 10 K")
        XCTAssertEqual(WhiteBalance.position(ofTemperature: 100000, range: range), 1.0, "clamped to the top")
        XCTAssertEqual(WhiteBalance.position(ofTemperature: 5500, range: 5500...5500), 0.0, "a degenerate range")
    }

    func testTintIsFormattedWithSignAndThreeDecimals() {
        XCTAssertEqual(WhiteBalance.formatTint(0.004), "+0.004")
        XCTAssertEqual(WhiteBalance.formatTint(-0.004), "-0.004")
        XCTAssertEqual(WhiteBalance.formatTint(0.0), "+0.000")
    }

    func testFileSettingsAreReadFromTheLockedEntries() {
        var locked: [String: Float?] = [:]
        locked.updateValue(nil, forKey: "white_balance")
        var settings = WhiteBalance.settings(fromLocked: locked)
        XCTAssertEqual(settings.mode, .locked, "the value-less entry is the lock")

        settings = WhiteBalance.settings(fromLocked: ["white_balance": 3200.0, "white_balance_tint": -0.004])
        XCTAssertEqual(settings.mode, .temperature)
        XCTAssertEqual(settings.temperature, 3200)
        XCTAssertEqual(settings.tint, -0.004, accuracy: 1e-9)

        settings = WhiteBalance.settings(fromLocked: ["white_balance": 5600.4])
        XCTAssertEqual(settings.temperature, 5600, "rounded to whole Kelvin")
        XCTAssertEqual(settings.tint, 0.0, "the tint defaults to 0")

        XCTAssertEqual(WhiteBalance.settings(fromLocked: ["white_balance": 0.0]).mode, .auto, "a non-positive temperature is ignored")
        XCTAssertEqual(WhiteBalance.settings(fromLocked: ["white_balance": -3200.0]).mode, .auto)
        XCTAssertEqual(WhiteBalance.settings(fromLocked: ["white_balance_tint": 0.004]).mode, .auto, "a tint without a temperature is ignored")
        XCTAssertEqual(WhiteBalance.settings(fromLocked: ["iso": 100.0]).mode, .auto)
        XCTAssertEqual(WhiteBalance.settings(fromLocked: [:]).mode, .auto)
    }

    func testGainsAreSanitizedBeforeTheyReachTheDevice() {
        let fine = AVCaptureDevice.WhiteBalanceGains(redGain: 1.5, greenGain: 1.0, blueGain: 2.5)
        var result = CameraService.sanitizedGains(fine, maxGain: 4.0)
        XCTAssertFalse(result.clamped)
        XCTAssertEqual(result.gains.redGain, 1.5)
        XCTAssertEqual(result.gains.greenGain, 1.0)
        XCTAssertEqual(result.gains.blueGain, 2.5)

        let outOfRange = AVCaptureDevice.WhiteBalanceGains(redGain: 0.5, greenGain: 1.0, blueGain: 6.0)
        result = CameraService.sanitizedGains(outOfRange, maxGain: 4.0)
        XCTAssertTrue(result.clamped)
        XCTAssertEqual(result.gains.redGain, 1.0, "below 1 is raised to 1")
        XCTAssertEqual(result.gains.blueGain, 4.0, "above the maximum is lowered to it")

        let nan = AVCaptureDevice.WhiteBalanceGains(redGain: .nan, greenGain: 1.0, blueGain: 1.0)
        result = CameraService.sanitizedGains(nan, maxGain: 4.0)
        XCTAssertTrue(result.clamped)
        XCTAssertEqual(result.gains.redGain, 1.0, "NaN never reaches the device")
    }
}
