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
class CameraViewModel: ObservableObject {
    @Published var cameraUIDataModel: CameraUIDataModel
    
    init(cameraUIDataModel: CameraUIDataModel) {
        self.cameraUIDataModel = cameraUIDataModel
    }
}


@available(iOS 13.0, *)
class CameraUIDataModel: ObservableObject {
    @Published  var cameraIsMaximized: Bool = false
    @Published var cameraSize: CGSize = CGSize(width: 0, height: 0)
}

protocol ZoomSliderViewDelegate: AnyObject {
    func buttonTapped()
}

@available(iOS 14.0, *)
final class ExperimentCameraUIView: UIView, CameraGUIDelegate, ResizableViewModule, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
   
    var cameraSelectionDelegate: CameraSelectionDelegate?
    var cameraViewDelegete: CameraViewDelegate?
    
    private let descriptor: CameraViewDescriptor
    
    private let dataModel = CameraUIDataModel()
    private let cameraViewModel : CameraViewModel
    
    private var cancellableForCameraSettingMode = Set<AnyCancellable>()
    private var cancellableForCameraSettingValues = Set<AnyCancellable>()
    private var cancellableForCameraZoom = Set<AnyCancellable>()
    
    // Camera preview views
    private var cameraPreviewView: UIView
    private let emptyView : UIView
    private let previewResizingButton : UIButton
    private var headerView: UIView?
    private var metalView: MTKView?
    private var zoomSlider: UISlider?
    
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
    @Published var cameraSettingMode: CameraSettingMode = .NONE
    @Published private var isListVisible: Bool = false
    private var rotation: Double = 0.0
    private var isFlipped: Bool = false
    private var autoExposureOff: Bool = true
    
    var currentCameraSettingValuesIndex = 0
    
    @Published private var isZoomSliderVisible: Bool = false
    var showZoomSlider: Bool = false {
        didSet{
            onZoomSliderVisibilityChanged?(showZoomSlider)
        }
    }
    
    var onZoomSliderVisibilityChanged: ((Bool) -> Void)?
    
    
    private var cameraPositionText: UILabel?
    private var autoExposureText: UILabel?
    private var isoSettingText: UILabel?
    private var shutterSpeedText: UILabel?
    private var exposureText: UILabel?
    private var apertureText: UILabel?
    
    // size definations
    private let heightSpacing = 40.0
    private let actualScreenWidth = UIScreen.main.bounds.width
    private let actualScreenHeight = UIScreen.main.bounds.height
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height / 2
    
    
    required init?(descriptor: CameraViewDescriptor) {
        self.descriptor = descriptor
        
        cameraViewModel = CameraViewModel(cameraUIDataModel: dataModel)
        
        cameraPreviewView = UIView()
        previewResizingButton = UIButton()
        
        emptyView = UIView()
        emptyView.backgroundColor = .clear
        
        super.init(frame: .zero)
    
        headerView = previewViewHeader()
        
        cameraPositionText = createLabel(withText: localize("back"))
        autoExposureText = createLabel(withText: localize("off"))
        isoSettingText = createLabel(withText: localize("notSet"))
        shutterSpeedText = createLabel(withText:localize("notSet"))
        exposureText = createLabel(withText: localize("notSet"))
        apertureText = createDisabledLabel(withText: localize("notSet"))
        
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.isUserInteractionEnabled = true

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
            return CGSize(width: size.width - 10, height: Swift.min((size.width)/descriptor.aspectRatio, size.height) + heightSpacing)
        }
    }
    
    
    override func layoutSubviews() {
        
        super.layoutSubviews()
        
        guard let metalView = cameraViewDelegete?.mView else { return }
        self.metalView = metalView
        
        cameraSelectionDelegate?.exposureSettingLevel = descriptor.exposureAdjustmentLevel
        cameraSettingUIView = cameraSettingViews(adjustmentLabel: descriptor.exposureAdjustmentLevel)
        
        let adjustedSize = getAdjustedPreviewFrameSize()
        
        setupHeaderView(frameWidth: frame.width)
        setupMetalView(width: adjustedSize.width, height: adjustedSize.height)
        setupCameraSettingViews(width: adjustedSize.width, height: adjustedSize.height)
            
       
        if resizableState == .exclusive {
            configureExclusiveState(height:adjustedSize.height)
            } else {
                resetNonExclusiveState()
        }
    }
    
    private func setupHeaderView(frameWidth: CGFloat) {
        headerView?.frame = CGRect(x: 0.0, y: 0.0, width: frameWidth, height: heightSpacing - 10.0)
        addSubview(headerView ?? emptyView)
    }

    private func setupMetalView(width: CGFloat, height: CGFloat) {
        self.metalView?.frame = CGRect(x: (frame.width - width) / 2, y: heightSpacing, width: width, height: height - heightSpacing)
        self.metalView?.contentMode = .scaleAspectFit
        self.metalView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(resizeTapped(_:))))
        addSubview(self.metalView ?? emptyView)
    }
    
    
    private func setupCameraSettingViews(width: CGFloat, height: CGFloat) {
        addSubview(cameraSettingUIView ?? emptyView)
        addSubview(collectionView)
    }
    
    private func configureExclusiveState(height: CGFloat){
        cameraSettingUIView?.frame = CGRect(x: 0.0, y: height + 10.0, width: frame.width, height: 70.0)
        collectionView.frame = CGRect(x: 0, y: height + 10.0 + 80.0, width: frame.width, height: 50.0)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: frame.width / 2, bottom: 0, right: frame.width / 2)
        collectionView.isHidden = true
        
        if(cameraViewDelegete != nil ){
            zoomSlider = ZoomSlider(cameraSettingModel: cameraViewDelegete!.cameraSettingsModel)
            buttonClickedDelegate = zoomSlider as? any ZoomSliderViewDelegate
            addSubview(zoomSlider ?? emptyView)
        }
        
        self.zoomSlider?.frame = CGRect(x: 0, y: height + 10.0 + 80.0 + 40.0 , width: frame.width , height: 50.0)
        self.zoomSlider?.isHidden = true
        
        $isListVisible.sink(receiveValue: { value in
            
            self.collectionView.isHidden = value ? false : true
            
        }).store(in: &cancellableForCameraSettingValues)
        
        
        onZoomSliderVisibilityChanged = { value in
           
            self.zoomSlider?.isHidden = value ? false : true

        }
        
        guard let cameraSettingsModel = cameraViewDelegete?.cameraSettingsModel else { return }
        
        cameraSettingsModel.onApertureCurrentValueChanged = { value in
           
            DispatchQueue.main.async {
                self.apertureText?.text = "f"+String(value)
            }
        }
        
        
        updateCameraSettingsCurrentValues()
        
    }
    
    private func updateCameraSettingsCurrentValues() {
        guard let cameraSettingsModel = cameraViewDelegete?.cameraSettingsModel else { return }
        
        if((cameraSettingsModel.service?.isConfigured) != nil){
            isoSettingText?.text = String(cameraSettingsModel.currentIso)
            shutterSpeedText?.text = "1/" + (cameraSettingsModel.currentShutterSpeed?.timescale.description ?? "30")
            exposureText?.text = String(cameraSettingsModel.currentExposureValue)
            apertureText?.text = "f"+String(cameraSettingsModel.currentApertureValue)
        }
    }
    
    private func resetNonExclusiveState() {
        cameraSettingUIView?.frame = .zero
        collectionView.frame = .zero
        zoomSlider?.frame = .zero
        zoomSlider?.isHidden = true
    }

    func updateResolution(resolution: CGSize) {
        setNeedsLayout()
    }
    
    private func getAdjustedPreviewFrameSize() -> CGSize{
        let frameWidth = UIScreen.main.bounds.width
        let frameHeight = UIScreen.main.bounds.height
        
        let frameH = resizableState == .exclusive ? frameHeight * 0.65 : frame.height
        
        guard let imageResolution = cameraViewDelegete?.cameraSettingsModel.resolution else {
            return CGSize(width: frame.width, height: frameH)
        }
        
        let actualAspect = frame.width / frameH
        let isLandscape = frameWidth > frameHeight
        let aspect = isLandscape ? (imageResolution.width / imageResolution.height) : (imageResolution.height / imageResolution.width)
           
        let h, w: CGFloat
        
        if aspect > actualAspect {
            w = frame.width
            h = w / aspect
        } else {
            h = frameH
            w = h * aspect
        }
        
        return CGSize(width: w, height: h)
    }
    
    
    func resizableStateChanged(_ newState: ResizableViewModuleState) {
        if newState == .exclusive {
            cameraSettingUIView?.isHidden = false
            panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
            if let gr = panGestureRecognizer {
                metalView?.addGestureRecognizer(gr)
            }
            self.cameraViewDelegete?.isOverlayEditable = true
            
            
        } else {
            cameraSettingUIView?.isHidden = true
            if let gr = panGestureRecognizer {
                metalView?.removeGestureRecognizer(gr)
            }
    
            panGestureRecognizer = nil
            self.cameraViewDelegete?.isOverlayEditable = false
        }
    }
    
    // MARK: - Camera preview
    
    private func previewViewHeader() -> UIStackView{
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.distribution = .fillEqually
        hStack.alignment = .fill
        hStack.addArrangedSubview(cameraPreviewViewControlButton())
        hStack.addArrangedSubview(createLabel(withText: localize("preview"), font: .preferredFont(forTextStyle: .body)))
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
    private func cameraSettingViews(adjustmentLabel: Int) -> UIStackView {
        let settingStackView = createStackView(axis: .horizontal, distribution: .fillEqually)
        
        if resizableState == .exclusive {
            switch adjustmentLabel {
            case 0:
                break
            case 1:
                settingStackView.addArrangedSubview(getCameraSettingView(for: .flipCamera))
                settingStackView.addArrangedSubview(getCameraSettingView(for: .zoom))
            case 2:
                settingStackView.addArrangedSubview(getCameraSettingView(for: .flipCamera))
                settingStackView.addArrangedSubview(getCameraSettingView(for: .autoExposure))
                settingStackView.addArrangedSubview(getCameraSettingView(for: .exposure))
                settingStackView.addArrangedSubview(getCameraSettingView(for: .zoom))
            case 3:
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
            
            
        }
        
        return settingStackView
    }
    
    private func getCameraSettingView(for type: SettingType) -> UIStackView {
            let vStack = createStackView(axis: .vertical, distribution: .fillEqually)
            
            switch type {
            case .flipCamera:
                vStack.addArrangedSubview(createButton(image: .assetImageName("flip_camera"),
                                                       action: #selector(flipButtonTapped(_:))))
                vStack.addArrangedSubview(cameraPositionText ?? UILabel())
            case .autoExposure:
                vStack.addArrangedSubview(createButton(image: .assetImageName("ic_auto_exposure"),
                                                       action: #selector(autoExposureButtonTapped(_:))))
                vStack.addArrangedSubview(autoExposureText ?? UILabel())
            case .iso:
                vStack.addArrangedSubview(createButton(image: .assetImageName("ic_camera_iso"),
                                                       action: #selector(isoSettingButtonTapped(_:))))
                vStack.addArrangedSubview(isoSettingText ?? UILabel())
            case .shutterSpeed:
                vStack.addArrangedSubview(createButton(image: .assetImageName("ic_shutter_speed"),
                                                       action: #selector(shutterSpeedButtonTapped(_:))))
                vStack.addArrangedSubview(shutterSpeedText ?? UILabel())
            case .exposure:
                vStack.addArrangedSubview(createButton(image: .assetImageName("ic_exposure"),
                                                       action: #selector(exposureButtonTapped(_:))))
                vStack.addArrangedSubview(exposureText ?? UILabel())
            case .aperture:
                vStack.addArrangedSubview(createButton(image: .systemImageName("camera.aperture"),
                                                       action: #selector(apertureButtonTapped(_:))))
                vStack.addArrangedSubview(apertureText ?? UILabel())
            case .zoom:
                vStack.addArrangedSubview(createButton(image: .assetImageName("ic_zoom"), 
                                                       action: #selector(zoomButtonTapped(_:))))
                vStack.addArrangedSubview(createLabel(withText: "Zoom"))
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
        
        handleButtonTapped(mode: .SWITCH_LENS, additionalActions: {
            
            self.cameraViewDelegete?.cameraSettingsModel.switchCamera()
 
        })
       
    }
    
    @objc private func autoExposureButtonTapped(_ sender: UIButton) {
        handleButtonTapped(mode: .AUTO_EXPOSURE, additionalActions: {
            self.autoExposureText?.text = self.autoExposureOff ? localize("off") : localize("on")
            self.cameraViewDelegete?.cameraSettingsModel.autoExposure(auto: !self.autoExposureOff)
        })
        
    }

    
    @objc private func isoSettingButtonTapped(_ sender: UIButton) {
        handleButtonTapped(mode: .ISO, additionalActions: {
            self.collectionView.reloadData()
            self.selectDefaultItemInCollectionView()
        })
        
    }
    
    
    @objc private func shutterSpeedButtonTapped(_ sender: UIButton) {
        handleButtonTapped(mode: .SHUTTER_SPEED, additionalActions: {
            self.collectionView.reloadData()
            self.selectDefaultItemInCollectionView()
        })
      
    }
    
    @objc private func exposureButtonTapped(_ sender: UIButton){
        handleButtonTapped(mode: .EXPOSURE, additionalActions: {
            self.collectionView.reloadData()
           
        })
       
    }
    
    @objc private func apertureButtonTapped(_ sender: UIButton) {
        handleButtonTapped(mode: .NONE, additionalActions: nil)
    }
    
    @objc private func zoomButtonTapped(_ sender: UIButton) {
        if(cameraViewDelegete?.cameraSettingsModel.service?.defaultVideoDevice?.position == .front){
            return
        }
        handleButtonTapped(mode: .ZOOM, additionalActions: {
            self.collectionView.reloadData()
        })
        
    }
    
    private func handleButtonTapped(mode: CameraSettingMode, additionalActions: (() -> Void)?){
        cameraSettingMode = mode
        manageVisiblity()
        additionalActions?()
    }
    
    private func selectDefaultItemInCollectionView(){
        var currentSelectionIndex: Int
        
        if(cameraSettingMode == .ISO){
            guard let currentIso = self.cameraViewDelegete?.cameraSettingsModel.currentIso else { return }
            
            currentSelectionIndex = cameraSettingValues.firstIndex(where: { $0 == Float(currentIso)}) ?? 0
        } else if(cameraSettingMode == .SHUTTER_SPEED){
            guard let currentShutterSpeed = self.cameraViewDelegete?.cameraSettingsModel.currentShutterSpeed else { return }
            currentSelectionIndex = cameraSettingValues.firstIndex(where: { $0 == Float(currentShutterSpeed.timescale.description)}) ?? 0
        } else if(cameraSettingMode == .EXPOSURE){
            guard let currentExposureValue = self.cameraViewDelegete?.cameraSettingsModel.currentExposureValue else { return }
            currentSelectionIndex = cameraSettingValues.firstIndex(where: { $0 == Float(currentExposureValue)}) ?? 0
        } else {
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
        
        guard var del = cameraSelectionDelegate else {
            print("camera selection delegate is not accessable")
            return
        }
        
        guard let viewDelegate = cameraViewDelegete else {
            print("camera view delegate is not accessable")
            return
        }
        
        let p = sender.location(in: metalView)
       
        
        let pr = CGPoint(x: p.x / viewDelegate.mView.frame.width, y: p.y / viewDelegate.mView.frame.height)
        let ps = pr.applying(viewDelegate.metalRenderer.displayToCameraTransform)
        let x = Float(ps.x)
        let y = Float(ps.y)
        
        
        if sender.state == .began {
            let x1Square = (x - del.x1) * (x - del.x1)
            let x2Square = (x - del.x2) * (x - del.x2)
            let y1Square = (y - del.y1) * (y -  del.y1)
            let y2Square = (y - del.y2) * (y - del.y2)
            
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
                del.x1 = x
            } else if panningIndexX == 2 {
                del.x2 = x
            }
            if panningIndexY == 1 {
                del.y1 = y
            } else if panningIndexY == 2 {
                del.y2 = y
            }
            
        } else {
            if panningIndexX == 1 {
                del.x1 = x
            } else if panningIndexX == 2 {
                del.x2 = x
            }
            if panningIndexY == 1 {
                del.y1 = y
            } else if panningIndexY == 2 {
                del.y2 = y
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
        guard let cameraSettingsModel = cameraViewDelegete?.cameraSettingsModel else { return [] }
        
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
        case .NONE, .SWITCH_LENS:
            isListVisible = false
            showZoomSlider = false
        case .ZOOM:
            showZoomSlider.toggle()
            isListVisible = showZoomSlider
        case .AUTO_EXPOSURE:
            autoExposureOff.toggle()
            isListVisible = false
            showZoomSlider = false
        case .ISO, .SHUTTER_SPEED, .EXPOSURE:
            isListVisible.toggle()
            showZoomSlider = false
        case .WHITE_BAlANCE:
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
            
            guard let cameraSettingsModel = cameraViewDelegete?.cameraSettingsModel else { return }
            
            switch cameraSettingMode {
            case .NONE, .WHITE_BAlANCE, .AUTO_EXPOSURE, .SWITCH_LENS:
                break
            case .ZOOM:
                buttonClickedDelegate?.buttonTapped()
                cameraSettingsModel.setZoomScale(scale: CGFloat(currentCameraSettingValue))
            case .ISO:
                cameraSettingsModel.iso(value: Int(currentCameraSettingValue))
                self.isoSettingText?.text = String(Int(currentCameraSettingValue))
            case .SHUTTER_SPEED:
                cameraSettingsModel.shutterSpeed(value: Double(currentCameraSettingValue))
                self.shutterSpeedText?.text = "1/" + String(Int(currentCameraSettingValue))
            case .EXPOSURE:
                cameraSettingsModel.exposure(value: currentCameraSettingValue)
                self.exposureText?.text = String(Int(currentCameraSettingValue))
           
            }
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! CameraSettingValueViewCell
                cell.isSelected = false

    }
    
}

// MARK: - camera setting values collection cell
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
        self.settingValueView.frame = CGRect(x: 0, y: 0, width: 50, height: 25)
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
        
    
    func buttonTapped() {
        self.value = 1.0
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
