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
import MetalKit
import Combine



@available(iOS 13.0, *)
class CameraUIDataModel: ObservableObject {
   @Published  var cameraIsMaximized: Bool = false
}


@available(iOS 14.0, *)
final class ExperimentCameraUIView: UIView, CameraGUIDelegate {
  
    
    func updateResolution(resolution: CGSize) {
        setNeedsLayout()
    }
    
    
    var cameraSelectionDelegate: CameraSelectionDelegate?
    var cameraViewDelegete: CameraViewDelegate?

    let descriptor: CameraViewDescriptor
    
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height / 2
    
    var resizableState: ResizableViewModuleState = .normal
    
    let dataModel = CameraUIDataModel()
    
    private var cancellables = Set<AnyCancellable>()
    
    required init?(descriptor: CameraViewDescriptor) {
        self.descriptor = descriptor
        super.init(frame: .zero)
        
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
        
        let cameraViewModel = CameraViewModel(cameraUIDataModel: dataModel)
        
        cameraSelectionDelegate?.exposureSettingLevel = descriptor.exposureAdjustmentLevel
        
        let cameraViewHostingController = UIHostingController(rootView: PhyphoxCameraView(
            viewModel: cameraViewModel, 
            cameraSelectionDelegate: cameraSelectionDelegate,
            cameraViewDelegete:  cameraViewDelegete
        ))
        
        let cameraSettingHostingController = UIHostingController(rootView: CameraSettingView(
            cameraSettingModel: cameraViewDelegete?.cameraSettingsModel ?? CameraSettingsModel(),
            cameraSelectionDelegate: cameraSelectionDelegate
        ))
        

        cameraSettingHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        cameraViewHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        cameraViewHostingController.view.clipsToBounds = false
        
        cameraSettingHostingController.view.backgroundColor = UIColor(named: "mainBackground")
        cameraViewHostingController.view.backgroundColor = UIColor(named: "mainBackground")
        
        
        addSubview(cameraViewHostingController.view)
        addSubview(cameraSettingHostingController.view)
        
       
        
        if(dataModel.cameraIsMaximized){
            cameraSettingHostingController.view.isHidden = false
        } else {
            cameraSettingHostingController.view.isHidden = true
        }
       
        // UI Showing the 
        dataModel.objectWillChange.sink{
            [weak self] _ in
            if(self?.dataModel.cameraIsMaximized == true){
                cameraSettingHostingController.view.isHidden = true
                self?.resizableState = .normal
                
                
            } else {
                cameraSettingHostingController.view.isHidden = false
                self?.resizableState = .exclusive
               
                
                
            }
        }.store(in: &cancellables)
         
        var constraints = [NSLayoutConstraint]()
        
        constraints.append(cameraViewHostingController.view.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor))
        constraints.append(cameraViewHostingController.view.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor))
        constraints.append(cameraViewHostingController.view.bottomAnchor.constraint(equalTo: cameraSettingHostingController.view.topAnchor))
        constraints.append(cameraViewHostingController.view.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor))
        
        
        constraints.append(cameraSettingHostingController.view.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor))
        constraints.append(cameraSettingHostingController.view.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor))
        constraints.append(cameraSettingHostingController.view.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor))
        constraints.append(cameraSettingHostingController.view.topAnchor.constraint(equalTo: cameraViewHostingController.view.bottomAnchor))
        
        constraints.append(cameraSettingHostingController.view.widthAnchor.constraint(equalTo: cameraViewHostingController.view.widthAnchor, multiplier: 1))
        
        constraints.append(cameraViewHostingController.view.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.70))
        
        constraints.append(cameraViewHostingController.view.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1))
        
        constraints.append(cameraSettingHostingController.view.heightAnchor.constraint(equalTo: cameraViewHostingController.view.heightAnchor, multiplier: 0.30))
         
         
        NSLayoutConstraint.activate(constraints)
    }
 
}
