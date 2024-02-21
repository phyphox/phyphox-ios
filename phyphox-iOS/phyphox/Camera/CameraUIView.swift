//
//  CameraUIView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 16.02.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation
import SwiftUI

@available(iOS 14.0, *)
final class ExperimentCameraUIView: UIView {
    
    private let cameraModel = CameraModel()
    private var isMinimized = true
    
    private var overlayWidth: CGFloat = 50
    private var overlayHeight: CGFloat = 50
    private var scale: CGFloat = 1.0
    private var currentPosition: CGSize = .zero
    private var newPosition: CGSize = .zero
    private var height: CGFloat = 200.0
    private var width: CGFloat = 200.0
    private var startPosition: CGFloat = 0.0
    private var speed = 50.0
    private var viewState = CGPoint.zero
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        addSubview(minimizeCameraButton)
    }
    
    
    private var minimizeCameraButton: UIButton  {
        let minimizedButton = UIButton(type: .system)
        minimizedButton.addTarget(self, action: #selector(minimizeButtonTapped), for: .touchUpInside)
        
        let imageName = isMinimized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        let image = UIImage(systemName: imageName)?.withRenderingMode(.alwaysOriginal)
        
        minimizedButton.setImage(image, for: .normal)
        minimizedButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        minimizedButton.tintColor = UIColor(named: "textColor")
        minimizedButton.backgroundColor = .black
        minimizedButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        return minimizedButton
    }
    
    @objc private func minimizeButtonTapped(){
        isMinimized.toggle()
    }
    
}


@available(iOS 14.0, *)
final class CameraSettingUIView: UIView {
    private var cameraSettingModel = CameraSettingsModel()
    
    private var cameraSettingMode: CameraSettingMode = .NONE
    
    private var isEditing = false
    private var isZooming = false
    
    private var rotation: Double = 0.0
    private var isFlipped: Bool = false
    private var autoExposureOff : Bool = true
    
    private var zoomClicked: Bool = false
    
    private var isListVisible: Bool = false
    
    
    private var flipCameraBUtton: UIButton  {
        let flipCameraButton = UIButton(type: .system)
        flipCameraButton.addTarget(self, action: #selector(flipCameraButtonTapped), for: .touchUpInside)

        
        let image = UIImage(named: "flip_camera")?.withRenderingMode(.alwaysOriginal)

        flipCameraButton.setImage(image, for: .normal)
        flipCameraButton.imageView?.contentMode = .scaleAspectFit
        flipCameraButton.backgroundColor = UIColor.gray.withAlphaComponent(0.0)
        
        return flipCameraButton
    }
    
    
    @objc private func flipCameraButtonTapped() {
            cameraSettingMode = .SWITCH_LENS
            isListVisible = false
            if isFlipped {
                withAnimation(Animation.linear(duration: 0.3)) {
                    self.rotation = -90.0
                }
                isFlipped = false
            } else {
                withAnimation(Animation.linear(duration: 0.3)) {
                    self.rotation = 90.0
                }
                isFlipped = true
            }

            // Call your camera setting model method here
            cameraSettingModel.switchCamera()
        }
}
