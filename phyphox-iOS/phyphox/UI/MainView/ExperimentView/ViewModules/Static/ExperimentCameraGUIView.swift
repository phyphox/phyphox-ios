//
//  ExperimentCameraView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.09.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation

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


final class ExperimentCameraGUIView: UIView, CameraGUIDelegate {
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    func updateFrame(captureSession: AVCaptureSession) {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        layoutSubviews()
    }
    
    var resolution: CGSize?
    var depthGUISelectionDelegate: CameraGUISelectionDelegate?
    
    func updateResolution(resolution: CGSize) {
        self.resolution = resolution
        setNeedsLayout()
    }
    
    
    var layoutDelegate: ModuleExclusiveLayoutDelegate? = nil
    var resizableState: ResizableViewModuleState =  .normal
    
    let unfoldMoreImageView: UIImageView
    let unfoldLessImageView: UIImageView
    
    let descriptor: CameraViewDescriptor
    let spacing: CGFloat = 1.0
    private let sideMargins:CGFloat = 10.0
    private let buttonPadding: CGFloat = 20.0
    
    
    var screenRect: CGRect! = nil // For view dimensions
    private let label = UILabel()
    
    
    private let aggregationBtn = UIButton()
    private let cameraBtn = UIButton()
    
    var panGestureRecognizer: UIPanGestureRecognizer? = nil
    
    required init?(descriptor: CameraViewDescriptor) {
        self.descriptor = descriptor
        
        unfoldLessImageView = UIImageView(image: UIImage(named: "unfold_less"))
        unfoldMoreImageView = UIImageView(image: UIImage(named: "unfold_more"))
        
        
        aggregationBtn.backgroundColor = UIColor(named: "lightBackgroundColor")
        aggregationBtn.setTitle(localize("depthAggregationMode"), for: UIControl.State())
        aggregationBtn.isHidden = true
        
        cameraBtn.backgroundColor = UIColor(named: "lightBackgroundColor")
        cameraBtn.setTitle(localize("sensorCamera"), for: UIControl.State())
        cameraBtn.isHidden = true
        
        super.init(frame: .zero)
        
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = UIColor(named: "textColor")
        
        addSubview(label)
        

        
        let unfoldRect = CGRect(x: 5, y: 5, width: 20, height: 20)
        unfoldMoreImageView.frame = unfoldRect
        unfoldLessImageView.frame = unfoldRect
        unfoldLessImageView.isHidden = true
        unfoldMoreImageView.isHidden = false
        
        addSubview(unfoldMoreImageView)
        addSubview(unfoldLessImageView)
        
        addSubview(aggregationBtn)
        addSubview(cameraBtn)
        
        
    }
   
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        switch resizableState {
        case .exclusive:
            return size
        case .hidden:
            return CGSize.init(width: 0, height: 0)
        default:
            let labelh = label.sizeThatFits(size).height
            
            return CGSize(width: size.width, height: Swift.min((size.width-2*sideMargins)/descriptor.aspectRatio + labelh + 2*spacing, size.height))
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        videoPreviewLayer?.frame = bounds
        videoPreviewLayer?.videoGravity = .resizeAspectFill
        
        if(videoPreviewLayer != nil){
            layer.addSublayer(videoPreviewLayer!)
        }
            
        
        
    }
    
    func resizableStateChanged(_ newState: ResizableViewModuleState) {
        
    }
    
    @objc func tapped(_ sender: UITapGestureRecognizer) {
        if resizableState == .normal {
            layoutDelegate?.presentExclusiveLayout(self)
        } else {
            layoutDelegate?.restoreLayout()
        }
    }
    
    var panningIndexX: Int = 0
    var panningIndexY: Int = 0
    @objc func panned (_ sender: UIPanGestureRecognizer) {
        guard var del = depthGUISelectionDelegate else {
            return
        }
    }
    
    @objc private func aggregationBtnPressed() {
    }
        
        
    @objc private func cameraBtnPressed() {
    }
    
}
