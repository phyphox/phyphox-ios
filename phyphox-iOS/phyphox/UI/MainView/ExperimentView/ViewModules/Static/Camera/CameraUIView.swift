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
        
        let cameraViewHostingController = UIHostingController(rootView: PhyphoxCameraView(
            viewModel: cameraViewModel, 
            cameraSelectionDelegate: cameraSelectionDelegate,
            cameraViewDelegete:  cameraViewDelegete
        ))
        
        let hostingController = UIHostingController(rootView: CameraSettingView(
            cameraSettingModel: cameraViewDelegete?.cameraSettingsModel ?? CameraSettingsModel(),
            cameraSelectionDelegate: cameraSelectionDelegate
        ))

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        cameraViewHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        hostingController.view.backgroundColor = UIColor(named: "mainBackground")
        cameraViewHostingController.view.backgroundColor = UIColor(named: "mainBackground")
        
        addSubview(cameraViewHostingController.view)
        addSubview(hostingController.view)
        
        if(dataModel.cameraIsMaximized){
            hostingController.view.isHidden = false
        } else {
            hostingController.view.isHidden = true
        }
       
        // UI Showing the 
        dataModel.objectWillChange.sink{
            [weak self] _ in
            if(self?.dataModel.cameraIsMaximized == true){
                hostingController.view.isHidden = true
                self?.resizableState = .normal
                
                
            } else {
                hostingController.view.isHidden = false
                self?.resizableState = .exclusive
               
                
                
            }
        }.store(in: &cancellables)
         
        var constraints = [NSLayoutConstraint]()
        
        constraints.append(cameraViewHostingController.view.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor))
        constraints.append(cameraViewHostingController.view.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor))
        constraints.append(cameraViewHostingController.view.bottomAnchor.constraint(equalTo: hostingController.view.topAnchor))
        constraints.append(cameraViewHostingController.view.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor))
        
        
        constraints.append(hostingController.view.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor))
        constraints.append(hostingController.view.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor))
        constraints.append(hostingController.view.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor))
        constraints.append(hostingController.view.topAnchor.constraint(equalTo: cameraViewHostingController.view.bottomAnchor))
        
        constraints.append(hostingController.view.widthAnchor.constraint(equalTo: cameraViewHostingController.view.widthAnchor, multiplier: 1))
        
        constraints.append(cameraViewHostingController.view.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.75))
        
        constraints.append(cameraViewHostingController.view.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1))
        
        constraints.append(hostingController.view.heightAnchor.constraint(equalTo: cameraViewHostingController.view.heightAnchor, multiplier: 0.30))
         
         
        NSLayoutConstraint.activate(constraints)
       
    }
    
}
