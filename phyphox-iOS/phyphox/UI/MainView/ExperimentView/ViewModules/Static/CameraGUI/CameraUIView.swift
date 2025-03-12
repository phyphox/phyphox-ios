//
//  CameraUIView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 16.02.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation
import MetalKit
import Combine


@available(iOS 13.0, *)
class CameraViewModel {
    var cameraUIDataModel: CameraUIDataModel
    
    init(cameraUIDataModel: CameraUIDataModel) {
        self.cameraUIDataModel = cameraUIDataModel
    }
}


@available(iOS 13.0, *)
class CameraUIDataModel {
    var cameraIsMaximized: Bool = false
    var cameraSize: CGSize = CGSize(width: 0, height: 0)
}

protocol ZoomSliderViewDelegate: AnyObject {
    func buttonTapped(for value: Float)
}

@available(iOS 14.0, *)
final class ExperimentCameraUIView: UIView, CameraGUIDelegate, ResizableViewModule, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, CameraSettingsModel.SettingsChangeObserver {
    
    var cameraModelOwner: CameraModelOwner? {
        didSet {
            self.cameraPreviewRenderer.cameraModelOwner = cameraModelOwner
            cameraSettingUIView = cameraSettingViews(adjustmentLevel: descriptor.exposureAdjustmentLevel)
            cameraSettingUIView?.isHidden = true
            cameraModelOwner?.cameraModel?.cameraSettingsModel.registerSettingsObserver(self)
            self.addSubview(cameraSettingUIView!)
            setupCameraSettingViews()
        }
    }
    var cameraTextureProvider: CameraMetalTextureProvider? {
        didSet {
            self.cameraPreviewRenderer.cameraTextureProvider = cameraTextureProvider
        }
    }
    
    private let descriptor: CameraViewDescriptor
    
    private let dataModel = CameraUIDataModel()
    private let cameraViewModel : CameraViewModel
    
    // Camera preview views
    private var cameraPreviewView: UIView
    private let emptyView : UIView
    private let previewResizingButton : UIButton
    private var headerView: UIView!
    private var zoomSlider: UISlider?
    
    //Metal
    private let metalView = MTKView()
    private var metalDevice: MTLDevice!
    private var cameraPreviewRenderer: CameraPreviewRenderer
    
    // View minimization and maximization
    private var isViewMaximized = false
    var layoutDelegate: ModuleExclusiveLayoutDelegate? = nil
    var resizableState: ResizableViewModuleState =  .normal
    
    // Resizing the Passepartout
    private var panGestureRecognizer: UIPanGestureRecognizer? = nil
    private var panningIndexX: Int = 0
    private var panningIndexY: Int = 0
    
    // Camera Setting Views and its flags
    private var cameraSettingUIView: UIStackView?
    var cameraSettingMode: CameraSettingMode = .NONE
    private var isListVisible: Bool = false {
        didSet {
            self.collectionView.isHidden = isListVisible ? false : true
            self.setNeedsLayout()
        }
    }
    private var rotation: Double = 0.0
    private var isFlipped: Bool = false
    
    var currentCameraSettingValuesIndex = 0
    
    private var isZoomSliderVisible: Bool = false
    var showZoomSlider: Bool = false {
        didSet{
            onZoomSliderVisibilityChanged?(showZoomSlider)
        }
    }
    
    var onZoomSliderVisibilityChanged: ((Bool) -> Void)?
    
    private var switchCameraButton: UIButton!
    private var autoExposureButton: UIButton!
    private var isoButton: UIButton!
    private var shutterSpeedButton: UIButton!
    private var apertureButton: UIButton!
    private var exposureButton: UIButton!
    private var zoomButton: UIButton!
    
    private var cameraPositionText: UILabel!
    private var autoExposureText: UILabel!
    private var isoSettingText: UILabel!
    private var shutterSpeedText: UILabel!
    private var exposureText: UILabel!
    private var apertureText: UILabel!
    private var zoomText: UILabel!
    
    // size definitions
    private let spacing: CGFloat = 1.0
    private let sideMargins:CGFloat = 10.0
    static let defaultHeight = 300.0
    static let controlHeight = 60.0
    static let controlExtraHeight = 30.0
    static let controlZoomHeight = 30.0
    
    
    required init?(descriptor: CameraViewDescriptor) {
        self.descriptor = descriptor
        
        cameraViewModel = CameraViewModel(cameraUIDataModel: dataModel)
        
        cameraPreviewView = UIView()
        previewResizingButton = UIButton()
        
        emptyView = UIView()
        emptyView.backgroundColor = .clear
        
        self.metalDevice = MTLCreateSystemDefaultDevice()
        metalView.device = metalDevice
        metalView.preferredFramesPerSecond = 60
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        cameraPreviewRenderer = CameraPreviewRenderer(metalDevice: metalDevice, renderDestination: metalView, descriptor: descriptor)
        cameraPreviewRenderer.loadMetal()
        metalView.delegate = cameraPreviewRenderer
                
        super.init(frame: .zero)
        
        switchCameraButton = createButton(image: .assetImageName("flip_camera"),
                                          action: #selector(flipButtonTapped(_:)))
        autoExposureButton = createButton(image: .assetImageName("ic_auto_exposure"),
                                          action: #selector(autoExposureButtonTapped(_:)))
        isoButton = createButton(image: .assetImageName("ic_camera_iso"),
                                 action: #selector(isoSettingButtonTapped(_:)))
        shutterSpeedButton = createButton(image: .assetImageName("ic_shutter_speed"),
                                          action: #selector(shutterSpeedButtonTapped(_:)))
        exposureButton = createButton(image: .assetImageName("ic_exposure"),
                                      action: #selector(exposureButtonTapped(_:)))
        apertureButton = createButton(image: .systemImageName("camera.aperture"),
                                      action: #selector(apertureButtonTapped(_:)))
        zoomButton = createButton(image: .assetImageName("ic_zoom"),
                                  action: #selector(zoomButtonTapped(_:)))
        
        
        cameraPositionText = createLabel(withText: localize("back"))
        autoExposureText = createLabel(withText: localize("off"))
        isoSettingText = createLabel(withText: localize("notSet"))
        shutterSpeedText = createLabel(withText:localize("notSet"))
        exposureText = createLabel(withText: localize("notSet"))
        apertureText = createDisabledLabel(withText: localize("notSet"))
        zoomText = createLabel(withText: "Zoom")
        
        headerView = previewViewHeader()
        
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.isUserInteractionEnabled = true
        
        self.metalView.contentMode = .scaleAspectFit
        self.metalView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(resizeTapped(_:))))
        
        addSubview(headerView)
        addSubview(self.metalView)
        addSubview(collectionView)
        
        collectionView.isHidden = true
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
            return CGSize(width: size.width, height: Swift.min(ExperimentCameraUIView.defaultHeight, size.height))
        }
    }
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let orientation = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation ?? .portrait
        let imageResolution = cameraModelOwner?.cameraModel?.cameraSettingsModel.resolution ?? CGSize(width: 1920, height: 1080)
        
        //Header
        let headSize = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        headerView.frame = CGRect(x: sideMargins, y: spacing, width: frame.width-2*sideMargins, height: headSize.height)
        
        //Controls
        let controlsVisible = resizableState == .exclusive //TODO controls can be allowed in non-exclusive state
        let controlSize = controlsVisible ? CGSize(width: frame.width-2*sideMargins, height: ExperimentCameraUIView.controlHeight) : .zero
        let controlExtraSize = collectionView.isHidden ? .zero : CGSize(width: frame.width-2*sideMargins, height: ExperimentCameraUIView.controlExtraHeight)
        let controlZoomSize = (zoomSlider?.isHidden ?? true) ? .zero : CGSize(width: frame.width-2*sideMargins, height: ExperimentCameraUIView.controlZoomHeight)
        cameraSettingUIView?.frame = CGRect(x: sideMargins, y: frame.height - controlExtraSize.height - controlZoomSize.height - controlSize.height - 2*spacing, width: frame.width - 2*sideMargins, height: controlSize.height)
        collectionView.frame = CGRect(x: sideMargins, y: frame.height - controlExtraSize.height - spacing - controlZoomSize.height, width: frame.width - 2*sideMargins, height: controlExtraSize.height)
        self.zoomSlider?.frame = CGRect(x: sideMargins, y: frame.height - controlZoomSize.height - spacing, width: frame.width - 2*sideMargins, height: controlZoomSize.height)
        
        //Metal view
        let h, w: CGFloat
        let metalAvailableHeight = frame.height - 5*spacing - headSize.height - controlSize.height - controlExtraSize.height - controlZoomSize.height
        let actualAspect = (frame.width - 2*sideMargins) / metalAvailableHeight
        let aspect = if orientation == .landscapeRight || orientation == .landscapeLeft {
            imageResolution.width / imageResolution.height
        } else {
            imageResolution.height / imageResolution.width
        }
        if aspect > actualAspect {
            w = frame.width - 2*sideMargins
            h = w / aspect
        } else {
            h = metalAvailableHeight
            w = h * aspect
        }
        self.metalView.frame = CGRect(x: (frame.width - w) / 2, y: headSize.height + 2*spacing + (metalAvailableHeight - h) / 2, width: w, height: h)
        
        //TODO This also does not seem to belong here...
        cameraModelOwner?.cameraModel?.exposureSettingLevel = descriptor.exposureAdjustmentLevel
        
        updateCameraSettingsCurrentValues()
    }
    
    private func setupCameraSettingViews() {
        if let cameraModel = cameraModelOwner?.cameraModel {
            zoomSlider = ZoomSlider(cameraSettingModel: cameraModel.cameraSettingsModel)
            buttonClickedDelegate = zoomSlider as? any ZoomSliderViewDelegate
            
            zoomSlider?.isHidden = true
            onZoomSliderVisibilityChanged = { value in
                self.zoomSlider?.isHidden = value ? false : true
                self.setNeedsLayout()
            }
            
            addSubview(zoomSlider!)
        }
    }
    
    private func updateCameraSettingsCurrentValues() {
        guard let cameraSettingsModel = cameraModelOwner?.cameraModel?.cameraSettingsModel else { return }
        
        if((cameraSettingsModel.service?.isConfigured) != nil){
            onIsoChange(newValue: cameraSettingsModel.currentIso)
            onApertureChange(newValue: cameraSettingsModel.currentApertureValue)
            
            let currentShutterSpeed = cameraSettingsModel.currentShutterSpeed
            onShutterSpeedChange(newValue: currentShutterSpeed)
            
            exposureText?.text = String(cameraSettingsModel.currentExposureValue)+"EV"
            
            if let aeState = cameraModelOwner?.cameraModel?.autoExposureEnabled {
                autoExposureText?.text = aeState ? localize("on") : localize("off")
            } else {
                autoExposureText?.text = "?"
            }
        }
    }
    
    func onShutterSpeedChange(newValue: CMTime) {
        let shutterInverse = round(Float(newValue.timescale)/Float(newValue.value))
        if shutterInverse.isFinite {
            DispatchQueue.main.async {
                self.shutterSpeedText?.text = "1/" + String(Int(shutterInverse))
            }
        } else {
            DispatchQueue.main.async {
                self.shutterSpeedText?.text = "?"
            }
        }
    }
    
    func onIsoChange(newValue: Int) {
        DispatchQueue.main.async {
            self.isoSettingText?.text = String(newValue)
        }
    }
    
    func onApertureChange(newValue: Float) {
        DispatchQueue.main.async {
            self.apertureText?.text = "f/"+String(newValue)
        }
    }

    func updateResolution(resolution: CGSize) {
        Task.detached { @MainActor in
            self.setNeedsLayout()
        }
    }
    
    func resizableStateChanged(_ newState: ResizableViewModuleState) {
        if newState == .exclusive {
            cameraSettingUIView?.isHidden = false
            panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
            if let gr = panGestureRecognizer {
                metalView.addGestureRecognizer(gr)
            }
            self.cameraModelOwner?.cameraModel?.isOverlayEditable = true
            
            
        } else {
            cameraSettingUIView?.isHidden = true
            if let gr = panGestureRecognizer {
                metalView.removeGestureRecognizer(gr)
            }
    
            panGestureRecognizer = nil
            self.cameraModelOwner?.cameraModel?.isOverlayEditable = false
            cameraSettingMode = .NONE
            manageVisiblity()
        }
    }
    
    // MARK: - Camera preview
    
    private func previewViewHeader() -> UIStackView{
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.distribution = .fillEqually
        hStack.alignment = .fill
        hStack.addArrangedSubview(cameraPreviewViewControlButton())
        hStack.addArrangedSubview(createLabel(withText: descriptor.localizedLabel, font: .preferredFont(forTextStyle: .body)))
        hStack.addArrangedSubview(emptyButtonView())
        
        return hStack
        
    }
    
    
    /// A button used for minimizing and maximizing the view of the camera preview
    private func cameraPreviewViewControlButton() -> UIButton {
        previewResizingButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
        previewResizingButton.contentHorizontalAlignment = .left
        previewResizingButton.layoutMargins = .init(top: 2.0, left: 5.0, bottom: 2.0, right: 5.0)
        previewResizingButton.addTarget(self, action: #selector(resizeTapped(_:)), for: .touchUpInside)
        previewResizingButton.isEnabled = true
        return previewResizingButton
        
    }
    
    private func emptyButtonView() -> UIButton {
        let button = UIButton()
        return button
    }
    
    // MARK: - Camera settings Views
   
    /// This view contains the collections of stacked camera settings views
    private func cameraSettingViews(adjustmentLevel: CameraSettingLevel) -> UIStackView {
        let settingStackView = createStackView(axis: .horizontal, distribution: .fillEqually)
        
        switch adjustmentLevel {
        case .BASIC:
            settingStackView.addArrangedSubview(getCameraSettingView(for: .flipCamera))
            settingStackView.addArrangedSubview(getCameraSettingView(for: .zoom))
        case .INTERMEDIATE:
            settingStackView.addArrangedSubview(getCameraSettingView(for: .flipCamera))
            settingStackView.addArrangedSubview(getCameraSettingView(for: .autoExposure))
            settingStackView.addArrangedSubview(getCameraSettingView(for: .exposure))
            settingStackView.addArrangedSubview(getCameraSettingView(for: .zoom))
        case .ADVANCE:
            settingStackView.addArrangedSubview(getCameraSettingView(for: .flipCamera))
            settingStackView.addArrangedSubview(getCameraSettingView(for: .autoExposure))
            settingStackView.addArrangedSubview(getCameraSettingView(for: .iso))
            settingStackView.addArrangedSubview(getCameraSettingView(for: .shutterSpeed))
            settingStackView.addArrangedSubview(getCameraSettingView(for: .aperture))
            settingStackView.addArrangedSubview(getCameraSettingView(for: .zoom))
            break
        default:
            break
        }
        
        return settingStackView
    }
    
    private func getCameraSettingView(for type: SettingType) -> UIStackView {
            let vStack = createStackView(axis: .vertical, distribution: .fillEqually)
            
            switch type {
            case .flipCamera:
                vStack.addArrangedSubview(switchCameraButton)
                vStack.addArrangedSubview(cameraPositionText)
            case .autoExposure:
                vStack.addArrangedSubview(autoExposureButton)
                vStack.addArrangedSubview(autoExposureText)
            case .iso:
                vStack.addArrangedSubview(isoButton)
                vStack.addArrangedSubview(isoSettingText)
            case .shutterSpeed:
                vStack.addArrangedSubview(shutterSpeedButton)
                vStack.addArrangedSubview(shutterSpeedText)
            case .exposure:
                vStack.addArrangedSubview(exposureButton)
                vStack.addArrangedSubview(exposureText)
            case .aperture:
                vStack.addArrangedSubview(apertureButton)
                vStack.addArrangedSubview(apertureText)
            case .zoom:
                vStack.addArrangedSubview(zoomButton)
                vStack.addArrangedSubview(zoomText)
            }
            
            return vStack
        }
    
    // MARK: - SettingType Enum
    
    enum SettingType {
        case flipCamera, autoExposure, iso, shutterSpeed, exposure, aperture, zoom
    }


    // MARK: - gesture recognizers
    
    @objc func resizeTapped(_ sender: UITapGestureRecognizer) {
        if resizableState == .normal {
            cameraPreviewViewControlButton().setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
            layoutDelegate?.presentExclusiveLayout(self)
    
        } else {
            cameraPreviewViewControlButton().setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
            layoutDelegate?.restoreLayout()
        }
    }
    

    @objc private func flipButtonTapped(_ sender: UIButton) {
        
        func rotateButton(_ button: UIButton) {
            let degree = CGFloat.pi / 2
            let clockwiseRotation = CGAffineTransform(rotationAngle: degree)
            
            button.transform = isFlipped ? .identity : clockwiseRotation
            isFlipped.toggle()
            
            cameraPositionText?.text = isFlipped ? localize("front") : localize("back")
            
        }
        
        UIView.animate(withDuration: 0.3) { rotateButton(sender) }
        
        handleButtonTapped(mode: .NONE, additionalActions: {
            
            self.cameraModelOwner?.cameraModel?.cameraSettingsModel.switchCamera()
 
        })
       
    }
    
    @objc private func autoExposureButtonTapped(_ sender: UIButton) {
        handleButtonTapped(mode: .NONE, additionalActions: {
            let autoExposureState = !(self.cameraModelOwner?.cameraModel?.autoExposureEnabled ?? false)
            self.autoExposureText?.text = autoExposureState ? localize("on") : localize("off")
            self.cameraModelOwner?.cameraModel?.cameraSettingsModel.autoExposure(auto: autoExposureState)
        })
    }

    
    @objc private func isoSettingButtonTapped(_ sender: UIButton) {
        handleButtonTapped(mode: .ISO, additionalActions: {
            self.collectionView.reloadData()
            self.selectDefaultItemInCollectionView()
            self.updateContentInset(startListFromMiddle: false)
        })
    }
    
    
    @objc private func shutterSpeedButtonTapped(_ sender: UIButton) {
        handleButtonTapped(mode: .SHUTTER_SPEED, additionalActions: {
            self.collectionView.reloadData()
            self.selectDefaultItemInCollectionView()
            self.updateContentInset(startListFromMiddle: false)
        })
    }
    
    @objc private func exposureButtonTapped(_ sender: UIButton){
        handleButtonTapped(mode: .EXPOSURE, additionalActions: {
            self.collectionView.reloadData()
            self.selectDefaultItemInCollectionView()
            self.updateContentInset(startListFromMiddle: false)
        })
    }
    
    @objc private func apertureButtonTapped(_ sender: UIButton) {
        handleButtonTapped(mode: .NONE, additionalActions: nil)
    }
    
    @objc private func zoomButtonTapped(_ sender: UIButton) {
        if(cameraModelOwner?.cameraModel?.cameraSettingsModel.service?.defaultVideoDevice?.position == .front){
            return
        }
        handleButtonTapped(mode: .ZOOM, additionalActions: {
            self.collectionView.reloadData()
            self.selectDefaultItemInCollectionView()
            self.updateContentInset(startListFromMiddle: true)
        })
    }
    
    private func updateContentInset(startListFromMiddle: Bool){
        if(startListFromMiddle){
            self.collectionView.contentInset = UIEdgeInsets(top: 0, left: self.frame.width / 2, bottom: 0, right: self.frame.width / 2)
        } else{
            self.collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
    }
    
    private func handleButtonTapped(mode: CameraSettingMode, additionalActions: (() -> Void)?){
        cameraSettingMode = mode
        manageVisiblity()
        additionalActions?()
    }
    
    private func selectDefaultItemInCollectionView(){
        var currentSelectionIndex: Int
        
        guard let cameraSettingsModel = self.cameraModelOwner?.cameraModel?.cameraSettingsModel else { return }
        
        if(cameraSettingMode == .ISO){
            currentSelectionIndex = cameraSettingValues.firstIndex(where: { $0 == Float(cameraSettingsModel.currentIso)}) ?? 0
        } 
        else if(cameraSettingMode == .SHUTTER_SPEED){
            let currentShutterSpeed = cameraSettingsModel.currentShutterSpeed
            guard let shutterSpeed = cameraSettingsModel.service?.findClosestPredefinedShutterSpeed(for: currentShutterSpeed) else { return }
            currentSelectionIndex = cameraSettingValues.firstIndex(where: { $0 == Float(shutterSpeed.timescale)}) ?? 0
        }
        else if(cameraSettingMode == .EXPOSURE){
            guard let currentExposureValue = self.cameraModelOwner?.cameraModel?.cameraSettingsModel.currentExposureValue else { return }
            currentSelectionIndex = cameraSettingValues.firstIndex(where: { $0 == Float(currentExposureValue)}) ?? 0
        }
        else if(cameraSettingMode == .ZOOM){
            currentSelectionIndex = cameraSettingValues.firstIndex(where: { $0 == Float(1)}) ?? 0
        }
        else {
            currentSelectionIndex = 0
        }
        
        DispatchQueue.main.async {
            if (self.cameraSettingValues.count > 0){
                self.collectionView.selectItem(at: IndexPath(item: currentSelectionIndex , section: 0), animated: false, scrollPosition: .centeredHorizontally)
                self.collectionView(self.collectionView, didSelectItemAt: IndexPath(item: currentSelectionIndex, section: 0))
            }
            
        }
        
    }
    
     
    @objc func panned(_ sender: UIPanGestureRecognizer) {
        
        guard var model = cameraModelOwner?.cameraModel else {
            return
        }
        
        let p = sender.location(in: metalView)
       
        
        let pr = CGPoint(x: p.x / metalView.frame.width, y: p.y / metalView.frame.height)
        let ps = pr.applying(cameraPreviewRenderer.displayToCameraTransform)
        let x = Float(ps.x)
        let y = Float(ps.y)
                
        if sender.state == .began {
            let x1Square = (x - model.x1) * (x - model.x1)
            let x2Square = (x - model.x2) * (x - model.x2)
            let y1Square = (y - model.y1) * (y - model.y1)
            let y2Square = (y - model.y2) * (y - model.y2)
            
            let d11 = x1Square + y1Square
            let d12 = x1Square + y2Square
            let d21 = x2Square + y1Square
            let d22 = x2Square + y2Square
            
            let _:Float = 0.1 // it was 0.01 for depth, after removing it from if else, it worked. Need to come again for this
            if d11 < d12 && d11 < d21 && d11 < d22 {
                panningIndexX = 1
                panningIndexY = 1
            } else if d12 < d21 && d12 < d22 {
                panningIndexX = 1
                panningIndexY = 2
            } else if  d21 < d22 {
                panningIndexX = 2
                panningIndexY = 1
            }  else {
                panningIndexX = 2
                panningIndexY = 2
            }
            
            if panningIndexX == 1 {
                model.x1 = x
            } else if panningIndexX == 2 {
                model.x2 = x
            }
            if panningIndexY == 1 {
                model.y1 = y
            } else if panningIndexY == 2 {
                model.y2 = y
            }
            
        } else {
            if panningIndexX == 1 {
                model.x1 = x
            } else if panningIndexX == 2 {
                model.x2 = x
            }
            if panningIndexY == 1 {
                model.y1 = y
            } else if panningIndexY == 2 {
                model.y2 = y
            }
        }
    }
    
    // MARK: - camera setting exposure value generator
 
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(CameraSettingValueViewCell.self, forCellWithReuseIdentifier: CameraSettingValueViewCell.identifier)
        return collectionView
    }()
    
    private var cameraSettingValues: [Float] {
        guard let cameraSettingsModel = cameraModelOwner?.cameraModel?.cameraSettingsModel else { return [] }
        
        switch cameraSettingMode {
        case .ISO:
            return cameraSettingsModel.isoValues
        case .SHUTTER_SPEED:
            return cameraSettingsModel.shutterSpeedValues
        case .EXPOSURE:
            return cameraSettingsModel.exposureValues
        case .ZOOM:
            return cameraSettingsModel.zoomOpticalLensValues
        default:
            return []
        }
    }
  
    // MARK: - Utility Functions for creating views
    
    private func createStackView(axis: NSLayoutConstraint.Axis, distribution: UIStackView.Distribution) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = axis
        stackView.distribution = distribution
        stackView.alignment = .fill
        stackView.backgroundColor = .clear
        
        return stackView
    }
    
    private func createButton(image: ButtonImage, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        
        func rescaleImage(edgeInsets: UIEdgeInsets? = nil, transform: CGAffineTransform? = nil) {
            if let insets = edgeInsets {
                button.imageEdgeInsets = insets
            }
            if let transform = transform {
                button.transform = transform
            }
        }
        
        func disabledImage(){
            button.isEnabled = false
            button.alpha = 0.5
        }
        
        switch image {
        case .systemImageName(let systemName):
            button.setImage(UIImage(systemName: systemName), for: .normal)
            rescaleImage(transform: CGAffineTransform(scaleX: 1.2, y: 1.2))
            if(systemName == "camera.aperture"){
                disabledImage()
            }
        case .assetImageName(let imageName):
            let image = UIImage(named: imageName)
            button.setImage(image, for: .normal)
           
            switch imageName{
            case "ic_auto_exposure":
                rescaleImage(edgeInsets: UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6))
            case "flip_camera", "ic_camera_iso":
                rescaleImage(edgeInsets: UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3))
            case "ic_zoom", "ic_shutter_speed":
                rescaleImage(transform: CGAffineTransform(scaleX: 1.2, y: 1.2))
            default:
                break
            }
        }
        
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: action, for: .touchUpInside)
        
        return button
    }
    
    enum ButtonImage {
        case systemImageName(String)
        case assetImageName(String)
    }

    private func createLabel(withText text: String , font: UIFont? = nil) -> UILabel {
        let label = UILabel()
        label.text = text
        label.backgroundColor = UIColor(named: "mainBackground")
        label.textColor = UIColor(named: "textColor")
        label.font = font ?? .preferredFont(forTextStyle: .caption1)
        label.textAlignment = .center
        
        return label
    }
    
    private func createDisabledLabel(withText text: String) -> UILabel {
        let label = createLabel(withText: text)
        label.isEnabled = false
        label.alpha = 0.5
        return label
    }
    
    
    private func createTextButton(label: String, color: UIColor, action: Selector) {
        let textButton = UIButton(type:.custom)
        
        textButton.titleLabel?.text = label
        textButton.titleLabel?.textColor = color
        textButton.addTarget(self, action: action, for: .touchUpInside)
    }
    
    
    private func manageVisiblity(){
        switch cameraSettingMode {
        case .NONE:
            isListVisible = false
            showZoomSlider = false
        case .ZOOM:
            showZoomSlider.toggle()
            isListVisible = showZoomSlider
        case .ISO, .SHUTTER_SPEED, .EXPOSURE:
            isListVisible.toggle()
            showZoomSlider = false
        case .WHITE_BALANCE:
            showZoomSlider = false
        }
        
        
    }
    
    //MARK: Collection views functions
    
    weak var buttonClickedDelegate: ZoomSliderViewDelegate?
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.cameraSettingValues.count
    }
    
    var index : IndexPath = IndexPath(row: 0, section: 0)
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraSettingValueViewCell.identifier, for: indexPath) as? CameraSettingValueViewCell else {
            fatalError("Failed to dequeue CameraSettingValueViewCell in CameraUIView")
        }
        
        index = indexPath
        var value : String
        
        if(cameraSettingMode == .SHUTTER_SPEED){
            value = "1/\(Int(self.cameraSettingValues[indexPath.row]))"
        } else if (cameraSettingMode == .EXPOSURE) {
            value = String(self.cameraSettingValues[indexPath.row]) + "EV"
        } else if(cameraSettingMode == .ZOOM){
            value = String(self.cameraSettingValues[indexPath.row])
        } else {
            value = String(Int(self.cameraSettingValues[indexPath.row]))
        }
        
        cell.configure(with: value)
        return cell

    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if let cell = collectionView.cellForItem(at: indexPath) as? CameraSettingValueViewCell {
            cell.isSelected = true
            cell.contentView.tintColor = UIColor(named: "highlightColor")
            
            let currentCameraSettingValue = self.cameraSettingValues[indexPath.row]
            
            guard let cameraSettingsModel = cameraModelOwner?.cameraModel?.cameraSettingsModel else { return }
            
            switch cameraSettingMode {
            case .NONE, .WHITE_BALANCE:
                break
            case .ZOOM:
                buttonClickedDelegate?.buttonTapped(for: currentCameraSettingValue)
                cameraSettingsModel.setZoomScale(scale: CGFloat(currentCameraSettingValue))
            case .ISO:
                cameraSettingsModel.iso(value: Int(currentCameraSettingValue))
                self.isoSettingText?.text = String(Int(currentCameraSettingValue))
            case .SHUTTER_SPEED:
                cameraSettingsModel.shutterSpeed(value: Double(currentCameraSettingValue))
                self.shutterSpeedText?.text = "1/" + String(Int(currentCameraSettingValue))
            case .EXPOSURE:
                cameraSettingsModel.exposure(value: currentCameraSettingValue)
                self.exposureText?.text = String(currentCameraSettingValue)+"EV"
           
            }
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as? CameraSettingValueViewCell
        cell?.isSelected = false

    }
    
}

// MARK: - camera setting values collection cell
@available(iOS 14.0, *)
class CameraSettingValueViewCell: UICollectionViewCell {
    
    static let identifier = "CameraSettingValueViewCell"
    
    override var isSelected: Bool {
        didSet {
            settingValueView.backgroundColor = isSelected ? UIColor(named: "highlightColor") : UIColor(named: "buttonBackground")
        }
    }
    
    private let settingValueView: UIButton = {
        let label = UIButton(type: .roundedRect)
        label.backgroundColor = UIColor(named: "buttonBackground")
        label.layer.cornerRadius = 15.0
        label.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        label.setTitleColor(UIColor(named: "textColorInsideButton"), for: .normal)
        label.isUserInteractionEnabled = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func configure(with text: String){
        self.settingValueView.setTitle(text, for: .normal)
        self.setupUI()
    }
    
    private func setupUI(){
        self.addSubview(self.settingValueView)
        self.settingValueView.frame = CGRect(x: 0, y: 10, width: 50, height: ExperimentCameraUIView.controlExtraHeight)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.settingValueView.setTitle(nil, for: .normal)
    }
}


extension UIView
{
    //Get Parent View Controller from any view
    func parentViewController() -> UIViewController {
        var responder: UIResponder? = self
        while !(responder is UIViewController) {
            responder = responder?.next
            if nil == responder {
                break
            }
        }
        return (responder as? UIViewController)!
    }
}



@available(iOS 14.0, *)
class ZoomSlider : UISlider , ZoomSliderViewDelegate{
    
    let cameraModel: CameraSettingsModel
    
    init(cameraSettingModel: CameraSettingsModel) {
        self.cameraModel = cameraSettingModel
        super.init(frame: CGRect.zero)
        
        setupSlider()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSlider() {
        self.minimumValue = minimumZoomValue
        self.maximumValue = maximumZoomValue
        self.value = 1
        self.minimumValueImage = UIImage(systemName: "minus.magnifyingglass")
        self.maximumValueImage = UIImage(systemName: "plus.magnifyingglass")
        self.thumbTintColor = UIColor(named: "highlightColor")
        self.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
    }
    
    
    
    @objc func sliderValueChanged(_ sender :UISlider) {
        self.cameraModel.setZoomScale(scale: CGFloat(sender.value))
    }
    
    lazy private var minimumZoomValue : Float =  {
        return Float(self.cameraModel.service?.getMinimumZoomValue(defaultCamera: true) ?? 1.0)
        
    }()
   
    
    lazy private var maximumZoomValue: Float =  {
        return Float(self.cameraModel.service?.getMaxZoom() ?? 2)
    }()
        
    
    func buttonTapped(for value: Float) {
        self.value = value
    }
    
}

public struct AlertError {
    public var title: String = ""
    public var message: String = ""
    public var primaryButtonTitle = "Accept"
    public var secondaryButtonTitle: String?
    public var primaryAction: (() -> ())?
    public var secondaryAction: (() -> ())?
    
    public init(title: String = "", message: String = "", primaryButtonTitle: String = "Accept", secondaryButtonTitle: String? = nil, primaryAction: (() -> ())? = nil, secondaryAction: (() -> ())? = nil) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryAction = secondaryAction
    }
}
