//
//  CameraExperimentSpectrumManager.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 10.02.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

protocol SpectrumOrientationUpdateable: AnyObject {
    func updateSpectrumState(spectrum: SpectrumOrientation)
}

protocol SpectrumDispersionOrientationSelectionDelegate: AnyObject {
    func spectrumDidSelectNewOrientation(_ orientation: SpectrumOrientation)
}

enum SpectrumOrientation: Int, CaseIterable {
    case horizontalRedRight = 0
    case verticalRedUp = 1
    case horizontalBlueRight = 2
    case verticalBlueUp = 3
    case invalid = 4
    

    private static let rotationCycle: [SpectrumOrientation] = [
        .horizontalRedRight, .verticalRedUp, .horizontalBlueRight, .verticalBlueUp
    ]

    func rotateClockwise() -> SpectrumOrientation {
        guard let currentIndex = SpectrumOrientation.rotationCycle.firstIndex(of: self) else { return self }
        let prevIndex = (currentIndex - 1 + SpectrumOrientation.rotationCycle.count) % SpectrumOrientation.rotationCycle.count
        return SpectrumOrientation.rotationCycle[prevIndex]
    }

    func rotateCounterClockwise() -> SpectrumOrientation {
        guard let currentIndex = SpectrumOrientation.rotationCycle.firstIndex(of: self) else { return self }
        let nextIndex = (currentIndex + 1) % SpectrumOrientation.rotationCycle.count
        return SpectrumOrientation.rotationCycle[nextIndex]
    }
}

enum DeviceOrientation {
    case portrait, portraitUpsideDown, landscapeLeft, landscapeRight
}


class SpectrumDispersionManager {
    var currentDeviceOrientation: DeviceOrientation = .portrait
    var currentDispersionOrientation: SpectrumOrientation = .horizontalRedRight
    
    private var userSelectedDispersionMap: [DeviceOrientation: SpectrumOrientation] = [
        .portrait: .horizontalRedRight
    ]

    func onUserDispersionSelected(_ chosen: SpectrumOrientation) {
        userSelectedDispersionMap[currentDeviceOrientation] = chosen
        currentDispersionOrientation = chosen
    }

    func onDeviceRotated(_ newOrientation: DeviceOrientation) {
        if newOrientation == currentDeviceOrientation { return }
        
        let previous = currentDeviceOrientation
        currentDeviceOrientation = newOrientation
        let base = currentDispersionOrientation

        switch (previous, newOrientation) {
        case (.portrait, .landscapeLeft):
            currentDispersionOrientation = base.rotateClockwise()
        case (.landscapeLeft, .portrait):
            currentDispersionOrientation = base.rotateCounterClockwise()
        case (.portrait, .landscapeRight):
            currentDispersionOrientation = base.rotateCounterClockwise()
        case (.landscapeRight, .portrait):
            currentDispersionOrientation = base.rotateClockwise()
        case (.landscapeLeft, .landscapeRight), (.landscapeRight, .landscapeLeft):
            currentDispersionOrientation = base.rotateClockwise().rotateClockwise()
        default:
            currentDispersionOrientation = getHardcodedDefaultFor(newOrientation)
        }
        
        userSelectedDispersionMap[newOrientation] = currentDispersionOrientation
    }

    private func getHardcodedDefaultFor(_ orientation: DeviceOrientation) -> SpectrumOrientation {
        switch orientation {
        case .portrait: return .horizontalRedRight
        case .landscapeLeft: return .verticalBlueUp
        case .landscapeRight: return .verticalRedUp
        case .portraitUpsideDown: return .horizontalBlueRight
        }
    }
}

@available(iOS 14.0, *)
extension ExperimentCameraUIView: SpectrumOrientationUpdateable {
    func updateSpectrumState(spectrum: SpectrumOrientation) {
        switch spectrum {
        case .verticalBlueUp:      (isHorizontal, isRedToBlue) = (false, false)
        case .verticalRedUp:       (isHorizontal, isRedToBlue) = (false, true)
        case .horizontalBlueRight: (isHorizontal, isRedToBlue) = (true, true)
        case .horizontalRedRight:  (isHorizontal, isRedToBlue) = (true, false)
        default: break
        }

        let imageName = getGradientImageName(spectrum: spectrum)
        if let image = UIImage(named: imageName)?.withRenderingMode(.alwaysOriginal) {
            self.dialogButton.setImage(image, for: .normal)
        }
    }
    
    func getGradientImageName(spectrum: SpectrumOrientation) -> String {
            switch spectrum {
            case .horizontalRedRight:
                return "arrow_gradient_right"
            case .verticalRedUp:
                return "arrow_gradient_bottom"
            case .horizontalBlueRight:
                return "arrow_gradient_left"
            case .verticalBlueUp:
                return "arrow_gradient_top"
            case .invalid:
                return "arrow_gradient_right"
            }
        }
}

extension ExperimentPageViewController: SpectrumDispersionOrientationSelectionDelegate {
    func spectrumDidSelectNewOrientation(_ orientation: SpectrumOrientation) {
        self.orientationManager.onUserDispersionSelected(orientation)
    }
}

