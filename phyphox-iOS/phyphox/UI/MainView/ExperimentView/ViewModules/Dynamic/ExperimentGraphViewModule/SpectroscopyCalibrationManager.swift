//
//  SpectroscopyCalibrationManager.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 08.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//


class SpectroscopyCalibrationManager {
    weak var delegate: SpectroscopyCalibrationDelegate?
    
    private var calibrationPoints: [(pixelPosition: Double, wavelength: Double)] = []
    private var calibrationState: CalibrationState = .uncalibrated
    private var calibrationParameters: (slope: Double, intercept: Double)?
    
    enum CalibrationState {
        case uncalibrated
        case start
        case firstPointSelected
        case secondPointSelected
        case calibrated
    }
    
    var isCalibrated: Bool {
        return calibrationState == .calibrated && calibrationParameters != nil
    }
    
    var needsSecondPoint: Bool {
        return calibrationState == .firstPointSelected
    }
    
    func getCalibrationState() -> CalibrationState {
        return calibrationState
    }
    
    func getCalibrationPoints() -> [(pixelPosition: Double, wavelength: Double)] {
        return calibrationPoints
    }
    
    func setCalibrationPoints(points: [(pixelPosition: Double, wavelength: Double)]){
        calibrationPoints = points
    }
    
    func startCalibration() {
        calibrationPoints.removeAll()
        calibrationState = .start
        calibrationParameters = nil
        delegate?.spectroscopyCalibrationDidStart(self)
        
    }
    
    func setUncalibrateMode(){
        calibrationState = .uncalibrated
        delegate?.spectroscopyUnCalibrated(self)
    }
    
    func addCalibrationReferencePoint(pixelIndex: Double, calibrationMarkerViewCount: Int) {
        //guard calibrationPoints.count < 2 else { return }
        let point = (pixelPosition: pixelIndex, wavelength: 0.0)
        CalibrationGraphUtility().manageCalibrationArray(&calibrationPoints, currentCount: calibrationMarkerViewCount, newItem: point)
       
    }
    
    func requestToAddCalibratedPoint(pixelIndex: Double) {
        //guard calibrationPoints.count < 2 else { return }
        
        if calibrationPoints.count == 1 {
            calibrationState = .firstPointSelected
            showWavelengthInputDialog(for: 0, pixelValue: pixelIndex)
        } else {
            calibrationState = .secondPointSelected
            showWavelengthInputDialog(for: 1, pixelValue: pixelIndex)
        }
    }
    
    private func showWavelengthInputDialog(for pointIndex: Int, pixelValue: Double){
        let title = pointIndex == 0 ?
        localize("spectroscopy_first_wavelength_title") :
        localize("spectroscopy_second_wavelength_title")
        let message = String(format: localize("spectroscopy_wavelength_message"), pixelValue)
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = localize("spectroscopy_wavelength_placeholder")
            textField.keyboardType = .decimalPad
            if pointIndex == 0 {
                textField.text = "420" // Default for violet/blue
            } else {
                textField.text = "680" // Default for red
            }
        }
        
        alert.addAction(UIAlertAction(title: localize("cancel"), style: .cancel) { _ in
            self.resetCalibration()
        })
        
        alert.addAction(UIAlertAction(title: localize("ok"), style: .default) { _ in
            if let wavelengthText = alert.textFields?.first?.text,
               let wavelength = Double(wavelengthText) {
                self.setWavelengthForPoint(pointIndex, wavelength: wavelength)
            } else {
                self.resetCalibration()
            }
        })
        
        delegate?.spectroscopyCalibration(self, shouldPresentDialog: alert)
    }
    
    private func setWavelengthForPoint(_ pointIndex: Int, wavelength: Double) {
        guard pointIndex < calibrationPoints.count else { return }
        
        calibrationPoints[pointIndex].wavelength = wavelength
        
        delegate?.spectroscopyCalibrationDidUpdatePoints(self, points: calibrationPoints, state: calibrationState)
        
        
        if calibrationPoints.count == 2 {
            performCalibration()
        }
        
    }
    
    private func performCalibration() {
        guard calibrationPoints.count == 2 else { return }
        
        let point1 = calibrationPoints[0]
        let point2 = calibrationPoints[1]
        
        // Linear calibration: wavelength = slope * pixel + intercept
        let deltaWavelength = point2.wavelength - point1.wavelength
        let deltaPixel = point2.pixelPosition - point1.pixelPosition
        
        guard abs(deltaPixel) > 0.001 else {
            // Points are too close, reset calibration
            resetCalibration()
            delegate?.spectroscopy(self, didFailWithError: "Calibration points are too close together")
            return
        }
        
        let slope = deltaWavelength / deltaPixel
        let intercept = point1.wavelength - slope * point1.pixelPosition
        
        calibrationParameters = (slope: slope, intercept: intercept)
        
        calibrationState = .calibrated
        
        delegate?.spectroscopyCalibrationDidComplete(self, slope: slope, intercept: intercept)
    }
    
    func resetCalibration() {
        calibrationPoints.removeAll()
        calibrationState = .start
        calibrationParameters = nil
        delegate?.spectroscopyCalibrationDidReset(self)
    }
    
    
    func transformPixelToWavelength(_ pixelIndex: Double) -> Double? {
        guard let params = calibrationParameters else { return nil }
        return params.slope * pixelIndex + params.intercept
    }
    
    func createWavelengthBuffer(from pixelBuffer: [DataBuffer?]) -> [Double] {
        guard let params = calibrationParameters else { return [] }
        
        var wavelengthArray: [Double] = []
        
        for (index, _) in pixelBuffer.enumerated() {
            let wavelength = params.slope * Double(index) + params.intercept
            wavelengthArray.append(wavelength)
        }
        
        return wavelengthArray
    }
    
    func getCalibrationInfo() -> String? {
        guard let params = calibrationParameters else { return nil }
        
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        
        let slopeStr = formatter.string(from: NSNumber(value: params.slope)) ?? "N/A"
        let interceptStr = formatter.string(from: NSNumber(value: params.intercept)) ?? "N/A"
        
        return "Calibrated: a- " + slopeStr + ",  b- " + interceptStr
    }
    
}

protocol SpectroscopyCalibrationDelegate: AnyObject {
    func spectroscopyUnCalibrated(_ manager: SpectroscopyCalibrationManager)
    func spectroscopyCalibrationDidStart(_ manager: SpectroscopyCalibrationManager)
    func spectroscopyCalibrationDidUpdatePoints(_ manager: SpectroscopyCalibrationManager, points: [(pixelPosition: Double, wavelength: Double)], state: SpectroscopyCalibrationManager.CalibrationState)
    func spectroscopyCalibrationDidComplete(_ manager: SpectroscopyCalibrationManager, slope: Double, intercept: Double)
    func spectroscopyCalibrationDidReset(_ manager: SpectroscopyCalibrationManager)
    func spectroscopyCalibration(_ manager: SpectroscopyCalibrationManager, shouldPresentDialog dialog: UIAlertController)
    func spectroscopy(_ manager: SpectroscopyCalibrationManager, didFailWithError error: String)
}

extension ExperimentGraphView: SpectroscopyCalibrationDelegate {
    
    func spectroscopyUnCalibrated(_ manager: SpectroscopyCalibrationManager) {
        spectroscopyStatusLabel?.text = ""
        spectroscopyStatusLabel?.isHidden = true
        markerSystem.markerOverlayView.drawTheLine = true
        layoutSubviews()
        markerSystem.clearMarkers()
    }
    
    func spectroscopyCalibrationDidStart(_ manager: SpectroscopyCalibrationManager) {
        spectroscopyStatusLabel?.text = localize("spectroscopy_tap_first_point")
        spectroscopyStatusLabel?.isHidden = false
        layoutSubviews()
        markerSystem.markerOverlayView.drawTheLine = false
        markerSystem.clearMarkers()
        markerSystem.clearCalibrationMarkers()
    }
    
    func spectroscopyCalibrationDidUpdatePoints(_ manager: SpectroscopyCalibrationManager, points: [(pixelPosition: Double, wavelength: Double)], state: SpectroscopyCalibrationManager.CalibrationState) {
        switch state {
        case .firstPointSelected:
            spectroscopyStatusLabel?.text = localize("spectroscopy_tap_second_point")
            markerSystem.showCalibrationPointMarkers(for: points)
        case .secondPointSelected:
            spectroscopyStatusLabel?.text = localize("spectroscopy_calculating")
            markerSystem.showCalibrationPointMarkers(for: points)
            markerSystem.setCalibrationDone()
        default:
            break
        }
    
    }
    
    func spectroscopyCalibrationDidComplete(_ manager: SpectroscopyCalibrationManager, slope: Double, intercept: Double) {
        //TODO: calibration system here need to get the calibration info and show this into the status label.
        if let calibrationInfo = manager.getCalibrationInfo() { spectroscopyStatusLabel?.text = calibrationInfo }
        
        descriptor.calibrationSlope?.replaceValues([slope])
        descriptor.calibrationIntercept?.replaceValues([intercept])
        
        markerSystem.markerOverlayView.showMarkers = false
        markerSystem.refreshMarkers()
        layoutManager.removeMarkerLabelFrame()
        
        toolbarManager.isCalibrated = true
        
    }
     
    func spectroscopyCalibrationDidReset(_ manager: SpectroscopyCalibrationManager) {
        spectroscopyStatusLabel?.text = localize("spectroscopy_tap_first_point")
        markerSystem.clearMarkers()
        markerSystem.clearCalibrationMarkers()
        markerSystem.setCalibrationUnDone()
    }
    
    func spectroscopyCalibration(_ manager: SpectroscopyCalibrationManager, shouldPresentDialog dialog: UIAlertController) {
        layoutDelegate?.presentDialog(dialog)
    }
    
    func spectroscopy(_ manager: SpectroscopyCalibrationManager, didFailWithError error: String) {
        spectroscopyStatusLabel?.text = localize("spectroscopy_calibration_failed")
        
        let alert = UIAlertController(title: localize("error"), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localize("ok"), style: .default, handler: nil))
        layoutDelegate?.presentDialog(alert)
    }
    
    
    private func revertSpectroscopyCalibration() {
            // Revert axis labels back to original
            // This would require storing original values
            setNeedsLayout()
            dataManager.setNeedsUpdate()
        }
}


class CalibrationGraphUtility {
    
    func manageCalibrationArray<T>(_ array: inout [T], currentCount: Int, newItem: T) {
        switch currentCount {
        case 0:
            array = [newItem]
        case 1:
            array.append(newItem)
            if array.count > 2 {
                array.remove(at: 1)
            }
        case 2:
            array.append(newItem)
            if array.count > 3 {
                array.remove(at: 2)
            }
        default:
            if !array.isEmpty {
                array.removeLast()
            }
        }
    }
}
