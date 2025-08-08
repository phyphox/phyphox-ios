//
//  Untitled.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 31.07.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//


struct WavelengthCalibrationCoefficients {
    let a: Double
    let b: Double
    
    func wavelengthFromPixel(_ pixel: Double) -> Double {
        return a * pixel + b
    }
    
    func pixelFromWavelength(_ wavelength: Double) -> Double {
        return (wavelength - b) / a
    }
}



class GraphCalibrationView : UIView {
    
    var calibrationPoints: [CGPoint] = [] {
        didSet { setNeedsDisplay() }
    }
    
    var wavelengthLabels: [(point: CGPoint, wavelength: String)] = [] {
           didSet { setNeedsDisplay() }
    }
    
    
    
}




