//
//  SpectroscopyCalibrationManager.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 08.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

class SpectroscopyCalibrationManager {
    weak var delegate: SpectroscopyCalibrationDelegate?
    
    private var calibrationPoints: [(pixelIntensity: Double, wavelength: Double)] = []
    private var calibrationState: CalibrationState = .uncalibrated
    private var calibratiionParameters: (slope: Double, intercept: Double)?
    
    enum CalibrationState {
        case uncalibrated
        case firstPointSelected
        case secondPointSelected
        case calibrated
    }
    
    var isCalibrated: Bool {
        return calibrationState == .calibrated && calibratiionParameters != nil
    }
    
    var needsSecondPoint: Bool {
        return calibrationState == .firstPointSelected
    }
    
    func startCalibration() {
        
    }
    
    func addCalibrationPoint() {
        
    }
    
    private func showWavelengthInputDialog(){}
    
    private func setWavelengthForPoint() {}
    
    func resetCalibration() {}
    
}

protocol SpectroscopyCalibrationDelegate: AnyObject {
    func spectroscopyCalibrationDidStart(_ manager: SpectroscopyCalibrationManager)
    func spectroscopyCalibrationDidUpdatePoints(_ manager: SpectroscopyCalibrationManager, points: [(pixelIntensity: Double, wavelength: Double)], state: SpectroscopyCalibrationManager.CalibrationState)
    func spectroscopyCalibrationDidComplete(_ manager: SpectroscopyCalibrationManager, slope: Double, intercept: Double)
    func spectroscopyCalibrationDidReset(_ manager: SpectroscopyCalibrationManager)
    func spectroscopyCalibration(_ manager: SpectroscopyCalibrationManager, shouldPresentDialog dialog: UIAlertController)
    func spectroscopy(_ manager: SpectroscopyCalibrationManager, didFailWithError error: String)
}
