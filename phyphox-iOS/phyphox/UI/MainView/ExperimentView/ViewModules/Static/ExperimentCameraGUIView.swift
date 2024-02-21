//
//  ExperimentCameraView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.09.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation
import SwiftUI

protocol CameraGUIDelegate {
    func updateFrame(captureSession: AVCaptureSession)
    func updateResolution(resolution: CGSize)
}

protocol CameraGUISelectionDelegate {
    var x1: Float { get set }
    var x2: Float { get set }
    var y1: Float { get set }
    var y2: Float { get set }
    var frontCamera: Bool { get set }
}



@available(iOS 13.0, *)
final class ExperimentCameraGUIView: UIView, CameraGUIDelegate {
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    var resolution: CGSize?
    
    var layoutDelegate: ModuleExclusiveLayoutDelegate? = nil
    var resizableState: ResizableViewModuleState =  .normal
    
    var showMoreButton: UIButton = UIButton()
    
    var showLessButton: UIButton = UIButton()
    
    let videoPreviewUIView = UIView()
    
    private let label = UILabel()
    
    required init() {
        
        super.init(frame: .zero)
        
        setUpCameraViews()
        
        addSubview(showMoreButton)
        addSubview(showLessButton)
        
        //horizontalCameraSettingsStackView()
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return size
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        print("layoutSubviews")
        var cameraWidth : CGFloat
        var cameraHeight : CGFloat
        var previewXPosition: CGFloat
        
        
        switch resizableState {
        case .normal:
            cameraWidth = (UIScreen.main.bounds.width - 20) / 2
            cameraHeight = UIScreen.main.bounds.height / 3
            previewXPosition = (UIScreen.main.bounds.width / 2) - ((videoPreviewLayer?.frame.width ?? 0)/2)
        case .exclusive:
            cameraWidth = UIScreen.main.bounds.width - 20
            cameraHeight = UIScreen.main.bounds.height / 2
            previewXPosition = 10
        case .hidden:
            cameraWidth = 0
            cameraHeight = 0
            previewXPosition = 10
        }
        
        if(videoPreviewLayer != nil){
            print("updateFrame: layoutSubviews")
            videoPreviewLayer?.frame = CGRect(x: previewXPosition, y: 40, width: cameraWidth, height: cameraHeight)
            videoPreviewLayer?.contents =
            videoPreviewLayer?.videoGravity = .resizeAspectFill
            videoPreviewUIView.layer.addSublayer(videoPreviewLayer!)
            addSubview(videoPreviewUIView)

        }
        
    }
    
    func updateFrame(captureSession: AVCaptureSession) {
        //videoPreviewLayer = ScannerOverlayPreviewLayer(session: captureSession)
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        layoutSubviews()
        
    }
    
    func updateResolution(resolution: CGSize) {
        self.resolution = resolution
        setNeedsLayout()
    }
    
    func setUpCameraViews() {
        
        let unfoldRect = CGRectMake(5, 5, 40, 40)
        
        if #available(iOS 13.0, *) {
            showMoreButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
        } else {
            showMoreButton.setImage(UIImage(named: "unfold_more"), for: .normal)
        }
        showMoreButton.frame = unfoldRect
        showMoreButton.contentMode = .scaleAspectFill
        showMoreButton.isHidden = false
        showMoreButton.addTarget(self, action: #selector(maximizeCamera), for: .touchUpInside)
        
        if #available(iOS 13.0, *) {
            showLessButton.setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
        } else {
            showLessButton.setImage(UIImage(named: "unfold_less"), for: .normal)
        }
        showLessButton.frame = unfoldRect
        showLessButton.isHidden = true
        showLessButton.addTarget(self, action: #selector(minimizeCamera), for: .touchUpInside)
        
        
    }
    
    @objc private func maximizeCamera() {
        print("maximizeCamera")
        
        showLessButton.isHidden = false
        showMoreButton.isHidden = true
        
        resizableState = .exclusive
        layoutSubviews()
   }
    
    @objc private func minimizeCamera() {
        print("minimizeCamera")
        
        showLessButton.isHidden = true
        showMoreButton.isHidden = false
        
        resizableState = .normal
        layoutSubviews()
   }
    
    private func horizontalCameraSettingsStackView(){
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create buttons
        for i in 1...5 {
            let button = UIButton()
            button.setTitle("Button \(i)", for: .normal)
            button.setTitleColor( UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), for: .normal)
            button.setImage(UIImage(named: "new_experiment_simple"), for: .normal)
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(button)
        }
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
                // Video preview view constraints
                videoPreviewUIView.topAnchor.constraint(equalTo: topAnchor),
                videoPreviewUIView.leadingAnchor.constraint(equalTo: leadingAnchor),
                videoPreviewUIView.trailingAnchor.constraint(equalTo: trailingAnchor),
                videoPreviewUIView.bottomAnchor.constraint(equalTo: bottomAnchor),
                
                // Button 1 constraints
                stackView.topAnchor.constraint(equalTo: videoPreviewUIView.bottomAnchor, constant: 20),
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
                
            ])
        
        
    }
  
    
    @objc func buttonTapped(_ sender: UIButton) {
            print("Button tapped: \(sender.titleLabel?.text ?? "")")
        }

    
}
