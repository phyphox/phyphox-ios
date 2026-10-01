//
//  WhiteBalance.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

enum WhiteBalanceMode {
    case auto
    case locked //the automatic result is held, from the first start when set by the file
    case temperature //a colour temperature with a Duv tint
}

//White balance by white point (file format 1.21, phyphox-docs docs/file-format/input.md "White balance"): a correlated
//colour temperature and a Duv tint become a CIE xy chromaticity, which AVCaptureDevice turns into its own gains. The
//locus and the tint convention are the same as in Android's WhiteBalance.kt, so a file balances both apps for the same
//white point. Accuracy is not promised by the docs; this is the implementation guidance from spec/input.yml.
enum WhiteBalance {
    //Validity of the Planckian locus approximation below
    static let minTemperature = 1667
    static let maxTemperature = 25000
    static let defaultTemperature = 5500
    //Duv
    static let maxTint: Float = 0.02

    static let D65 = (x: 0.3127, y: 0.3290)

    //Planckian locus in CIE xy (Kim et al. 2002), 1667..25000 K
    static func planckianXY(_ temperature: Double) -> (x: Double, y: Double) {
        let t = min(max(Double(minTemperature), temperature), Double(maxTemperature))
        let t2 = t * t
        let t3 = t2 * t
        let x: Double
        if t <= 4000.0 {
            x = -0.2661239e9 / t3 - 0.2343589e6 / t2 + 0.8776956e3 / t + 0.179910
        } else {
            x = -3.0258469e9 / t3 + 2.1070379e6 / t2 + 0.2226347e3 / t + 0.240390
        }
        let x2 = x * x
        let x3 = x2 * x
        let y: Double
        if t <= 2222.0 {
            y = -1.1063814 * x3 - 1.34811020 * x2 + 2.18555832 * x - 0.20219683
        } else if t <= 4000.0 {
            y = -0.9549476 * x3 - 1.37418593 * x2 + 2.09137015 * x - 0.16748867
        } else {
            y = 3.0817580 * x3 - 5.87338670 * x2 + 3.75112997 * x - 0.37001483
        }
        return (x, y)
    }

    //CIE 1960 uv, the diagram in which Duv is measured
    static func xyToUv(_ xy: (x: Double, y: Double)) -> (u: Double, v: Double) {
        let d = -2.0 * xy.x + 12.0 * xy.y + 3.0
        return (4.0 * xy.x / d, 6.0 * xy.y / d)
    }

    static func uvToXy(_ uv: (u: Double, v: Double)) -> (x: Double, y: Double) {
        let d = 2.0 * uv.u - 8.0 * uv.v + 4.0
        return (3.0 * uv.u / d, 2.0 * uv.v / d)
    }

    //Unit normal of the locus at a temperature in uv, pointing above the locus (towards green, larger v)
    private static func locusNormal(at temperature: Double) -> (u: Double, v: Double) {
        let step = temperature * 0.01
        let ahead = xyToUv(planckianXY(temperature + step))
        let behind = xyToUv(planckianXY(temperature - step))
        let du = ahead.u - behind.u
        let dv = ahead.v - behind.v
        let length = (du * du + dv * dv).squareRoot()
        var nu = dv / length
        var nv = -du / length
        if nv < 0.0 {
            nu = -nu
            nv = -nv
        }
        return (nu, nv)
    }

    //White point of a temperature and a Duv offset: the locus point moved along the locus normal in uv, positive
    //above the locus (towards green), negative towards magenta
    static func chromaticity(temperature: Double, duv: Double) -> (x: Double, y: Double) {
        let uv = xyToUv(planckianXY(temperature))
        if duv == 0.0 {
            return uvToXy(uv)
        }
        let normal = locusNormal(at: temperature)
        return uvToXy((uv.u + duv * normal.u, uv.v + duv * normal.v))
    }

    //The inverse: the locus temperature closest in uv and the signed distance to it, used to report the white point
    //the device actually reached when it had to clamp the gains. A golden-section search over log T, as the distance
    //to the locus has a single minimum in the range for any point near it.
    static func temperatureAndTint(x: Double, y: Double) -> (temperature: Double, duv: Double) {
        let uv = xyToUv((x, y))
        func distance(_ logT: Double) -> Double {
            let locus = xyToUv(planckianXY(exp(logT)))
            let du = uv.u - locus.u
            let dv = uv.v - locus.v
            return du * du + dv * dv
        }
        var a = log(Double(minTemperature))
        var b = log(Double(maxTemperature))
        let phi = (5.0.squareRoot() - 1.0) / 2.0
        var c = b - phi * (b - a)
        var d = a + phi * (b - a)
        var fc = distance(c)
        var fd = distance(d)
        for _ in 0..<80 {
            if fc < fd {
                b = d
                d = c
                fd = fc
                c = b - phi * (b - a)
                fc = distance(c)
            } else {
                a = c
                c = d
                fc = fd
                d = a + phi * (b - a)
                fd = distance(d)
            }
        }
        let temperature = exp((a + b) / 2.0)
        let locus = xyToUv(planckianXY(temperature))
        let normal = locusNormal(at: temperature)
        let duv = (uv.u - locus.u) * normal.u + (uv.v - locus.v) * normal.v
        return (temperature, duv)
    }

    //The white balance asked for by the camera input's locked attribute: white_balance without a value is the lock,
    //with a value the temperature in Kelvin, white_balance_tint the Duv (only with a temperature). An unreadable or
    //non-positive temperature is ignored with a log line, so the white balance stays automatic.
    static func settings(fromLocked locked: [String: Float?]) -> (mode: WhiteBalanceMode, temperature: Int, tint: Float) {
        var mode = WhiteBalanceMode.auto
        var temperature = defaultTemperature
        var tint: Float = 0.0
        if let entry = locked["white_balance"] {
            if let value = entry {
                if value.isFinite && value > 0.0 {
                    mode = .temperature
                    temperature = Int(value.rounded())
                    if let tintEntry = locked["white_balance_tint"], let tintValue = tintEntry, tintValue.isFinite {
                        tint = tintValue
                    }
                } else {
                    print("Ignoring locked white balance temperature \(value): not a positive number of Kelvin.")
                }
            } else {
                mode = .locked
            }
        } else if locked["white_balance_tint"] != nil {
            print("Ignoring locked white_balance_tint without a white_balance temperature.")
        }
        return (mode, temperature, tint)
    }

    //The camera-gui's temperature scale is logarithmic: the usual illuminants between 2500 K and 8000 K take up a
    //useful part of it. Positions run 0...1 over the range, temperatures are rounded to 10 K.
    static func temperature(atPosition position: Float, range: ClosedRange<Int>) -> Int {
        let minT = Double(range.lowerBound)
        let maxT = Double(range.upperBound)
        let t = minT * pow(maxT / minT, Double(min(max(0.0, position), 1.0)))
        return min(max(range.lowerBound, Int((t / 10.0).rounded()) * 10), range.upperBound)
    }

    static func position(ofTemperature temperature: Int, range: ClosedRange<Int>) -> Float {
        let minT = Double(range.lowerBound)
        let maxT = Double(range.upperBound)
        if maxT <= minT {
            return 0.0
        }
        let t = Double(min(max(range.lowerBound, temperature), range.upperBound))
        return Float(min(max(0.0, log(t / minT) / log(maxT / minT)), 1.0))
    }

    //"+0.004", as on Android
    static func formatTint(_ duv: Float) -> String {
        return String(format: "%+.3f", locale: Locale(identifier: "en_US"), duv)
    }
}
