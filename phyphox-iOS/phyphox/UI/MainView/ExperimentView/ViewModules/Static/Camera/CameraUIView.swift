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
    @Published var cameraSize: CGSize = CGSize(width: 0, height: 0)
}

protocol ZoomSliderViewDelegate: AnyObject {
    func buttonTapped()
}


@available(iOS 14.0, *)
final class ExperimentCameraUIView: UIView, CameraGUIDelegate, ResizableViewModule, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
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
        let value = self.cameraSettingValues[indexPath.row]
        cell.configure(with: String(value))
        return cell
         
        /**
        let value = Array(self.isoValuesWithSelectedFlag.keys)[indexPath.row]
        cell.configure(with: String(value))
        return cell
         */
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    
        print("indexPath ", indexPath.row)
        
        if let cell = collectionView.cellForItem(at: indexPath) as? CameraSettingValueViewCell {
            cell.isSelected = true
            cell.contentView.tintColor = UIColor(named: "highlightColor")
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(settingValueTapped(_:)))
            currentindex = indexPath.row
            cell.contentView.addGestureRecognizer(tapGestureRecognizer)
            tapGestureRecognizer.cancelsTouchesInView = false
        }
    }
    
    var currentindex = 0
    
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! CameraSettingValueViewCell
                cell.isSelected = false

    }
    
    
    @objc private func settingValueTapped(_ sender: UITapGestureRecognizer){
        print("currentTitle ", currentindex )
        
       
        if(cameraSettingMode == .SHUTTER_SPEED) {
            cameraViewDelegete?.cameraSettingsModel.shutterSpeed(value: Double(self.cameraSettingValues[currentindex]))
        }
        if(cameraSettingMode == .ISO) {
            cameraViewDelegete?.cameraSettingsModel.iso(value: Int(self.cameraSettingValues[currentindex]))
        }
        
        if(cameraSettingMode == .ZOOM){
            buttonClickedDelegate?.buttonTapped()
            cameraViewDelegete?.cameraSettingsModel.setZoomScale(scale: CGFloat(self.cameraSettingValues[currentindex]))
        }
    }
    
    let loadZoomSessionQueue = DispatchQueue(label: "loadZoom", attributes: [], autoreleaseFrequency: .workItem)
   
    var cameraSelectionDelegate: CameraSelectionDelegate?
    var cameraViewDelegete: CameraViewDelegate?
    
    private let descriptor: CameraViewDescriptor
    
    private let dataModel = CameraUIDataModel()
    private let cameraViewModel : CameraViewModel
    
    private var cancellableForCameraSettingMode = Set<AnyCancellable>()
    
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
    private var isListVisible: Bool = false
    private var rotation: Double = 0.0
    private var isFlipped: Bool = false
    private var autoExposureOff: Bool = true
    private var zoomClicked: Bool = false
    private var cameraPositionText: UILabel?
    private var autoExposureText: UILabel?
    private var isoSettingText: UILabel?
    private var shutterSpeedText: UILabel?
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
        
        cameraPositionText = createLabel(withText: "Back")
        autoExposureText = createLabel(withText: "Off")
        isoSettingText = createLabel(withText: "Not set")
        shutterSpeedText = createLabel(withText: "Not set")
        apertureText = createLabel(withText: "Not set")
        
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.isUserInteractionEnabled = true

        
        $cameraSettingMode.sink(receiveValue: { newMode in
            print("mode ", newMode)
            
            for val in self.isoValuesWithSelectedFlag.sorted(by: <) {
                print(val)
            }
        }
        ).store(in: &cancellableForCameraSettingMode)
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
        
        metalView = cameraViewDelegete?.mView
    
        cameraSelectionDelegate?.exposureSettingLevel = descriptor.exposureAdjustmentLevel
        cameraSettingUIView = cameraSettingViews(adjustmentLabel: descriptor.exposureAdjustmentLevel)
        
        let w = getAdjustedPreviewFrameSize().width
        let h = getAdjustedPreviewFrameSize().height
      
        headerView?.frame = CGRect(x: 0.0, y: 0.0, width: frame.width, height: heightSpacing - 10.0)
        
        metalView?.frame = CGRect(x: (frame.width - w)/2, y: 0.0 + heightSpacing , width: w, height: h - heightSpacing)
        metalView?.contentMode = .scaleAspectFit
        metalView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(resizeTapped(_:))))
        
       
        addSubview(headerView ?? emptyView)
        addSubview(metalView ?? emptyView)
        addSubview(cameraSettingUIView ?? emptyView)
        addSubview(collectionView)
        
        
        if resizableState == .exclusive {
            cameraSettingUIView?.frame = CGRect(x: 0.0, y: h + 10.0, width: frame.width, height: 70.0)
            self.collectionView.frame = CGRect(x: 0, y: h + 10.0 + 80.0 , width: frame.width , height: 50.0)
            self.collectionView.contentInset = .init(top: 0, left: frame.width / 2, bottom: 0, right: frame.width / 2 )
            if(cameraViewDelegete != nil ){
                zoomSlider = ZoomSlider(cameraSettingModel: cameraViewDelegete!.cameraSettingsModel)
                buttonClickedDelegate = zoomSlider as? any ZoomSliderViewDelegate
                addSubview(zoomSlider ?? emptyView)
            }
            self.zoomSlider?.frame = CGRect(x: 0, y: h + 10.0 + 80.0 + 40.0 , width: frame.width , height: 50.0)
            self.zoomSlider?.isHidden = false
        } else{
            cameraSettingUIView?.frame = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
            self.collectionView.frame = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
            self.zoomSlider?.frame = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0)
            self.zoomSlider?.isHidden = true
        }
        
    }
    
    
    let settingValueHeight = 50.0
    
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
        hStack.addArrangedSubview(createLabel(withText: "Preview", font: .preferredFont(forTextStyle: .body)))
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
            case 2:
                settingStackView.addArrangedSubview(getCameraSettingView(for: .flipCamera))
                settingStackView.addArrangedSubview(getCameraSettingView(for: .autoExposure))
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
            case .aperture:
                vStack.addArrangedSubview(createButton(image: .systemImageName("camera.aperture"),
                                                       action: #selector(apertureButtonTapped(_:))))
                vStack.addArrangedSubview(createLabel(withText: "Not set"))
            case .zoom:
                vStack.addArrangedSubview(createButton(image: .assetImageName("ic_zoom"), 
                                                       action: #selector(zoomButtonTapped(_:))))
                vStack.addArrangedSubview(createLabel(withText: "Zoom"))
            }
            
            return vStack
        }
    
    // MARK: - SettingType Enum
    
    enum SettingType {
        case flipCamera, autoExposure, iso, shutterSpeed, aperture, zoom
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
        cameraSettingMode = .SWITCH_LENS
        isListVisible = false
        
        func rotateButton(_ button: UIButton) {
            let degree = CGFloat.pi / 2
            let clockwiseRotation = CGAffineTransform(rotationAngle: degree)
            
            button.transform = isFlipped ? .identity : clockwiseRotation
            isFlipped.toggle()
            
            if(isFlipped) {
                cameraPositionText?.text = "Front"
            } else {
                cameraPositionText?.text =  "Back"
            }
           
        }
        
        UIView.animate(withDuration: 0.3) {
            rotateButton(sender)
        }
        
        cameraViewDelegete?.cameraSettingsModel.switchCamera()
    }
    

    @objc private func autoExposureButtonTapped(_ sender: UIButton) {
        cameraSettingMode = .AUTO_EXPOSURE
        autoExposureOff.toggle()
        isListVisible = false
        zoomClicked = false
        
        autoExposureText?.text = autoExposureOff ? "Off" : "On"
        cameraViewDelegete?.cameraSettingsModel.autoExposure(auto: !autoExposureOff)
    }

    
    @objc private func isoSettingButtonTapped(_ sender: UIButton) {
        cameraSettingMode = .ISO
        cameraViewDelegete?.cameraSettingsModel.cameraSettingMode = .ISO
        cameraViewDelegete?.cameraSettingsModel.service?.configureSession()
        self.collectionView.reloadData()
        DispatchQueue.main.async {
            if (self.cameraSettingValues.count > 0){
                self.collectionView.selectItem(at: IndexPath(item: 2 , section: 0), animated: false, scrollPosition: .centeredHorizontally)
                self.collectionView(self.collectionView, didSelectItemAt: IndexPath(item: 2, section: 0))
            }
            
        }
        isListVisible.toggle()
        zoomClicked = false
    }
    
    
    @objc private func shutterSpeedButtonTapped(_ sender: UIButton) {
        cameraSettingMode = .SHUTTER_SPEED
        cameraViewDelegete?.cameraSettingsModel.cameraSettingMode = .SHUTTER_SPEED
        cameraViewDelegete?.cameraSettingsModel.service?.configure()
        self.collectionView.reloadData()
        isListVisible.toggle()
        zoomClicked = false
    }
    
    
    @objc private func apertureButtonTapped(_ sender: UIButton) {
        cameraSettingMode = .NONE
        isListVisible = false
        zoomClicked = false
    }
    
    @objc private func zoomButtonTapped(_ sender: UIButton) {
        cameraSettingMode = .ZOOM
        cameraViewDelegete?.cameraSettingsModel.cameraSettingMode = .ZOOM
        isListVisible.toggle()
        self.collectionView.reloadData()
        print("currentCAmerasetting values ", cameraSettingValues)
        zoomClicked = !zoomClicked
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
        //let layout = CenterAlignedCollectionViewFlowLayout()
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(CameraSettingValueViewCell.self, forCellWithReuseIdentifier: CameraSettingValueViewCell.identifier)
        return collectionView
    }()
    
    
    private var cameraSettingValues : [Float] {
        return cameraViewDelegete?.cameraSettingsModel.getLisOfCameraSettingsValue(cameraSettingMode: self.cameraSettingMode) ?? []
        
    }
    
 
    
    
    func findIsoNearestNumber(value: Double, numbers: [Double]) -> Double {
        var nearestNumber: Double?
        var minDifference = Double.infinity
        
        for number in numbers {
            let difference = abs(number - value)
            if difference < minDifference {
                minDifference = difference
                nearestNumber = number
            }
        }
        
        return nearestNumber ?? 30.0
    }
    
    private var isoValuesWithUserSelectedFlag : [Double:Double] = [ : ]
    
    private func updateExposureValue(){
        var currentValue: Double = 1.0
        
        if(cameraSettingMode == .SHUTTER_SPEED){
            currentValue = CMTimeGetSeconds(cameraViewDelegete?.cameraSettingsModel.currentShutterSpeed ?? CMTime(seconds: 30.0, preferredTimescale: 1000)) * 1000
            if shutters.contains(Int(currentValue)){
                // Do nothing
            } else {
                currentValue = findIsoNearestNumber(value: currentValue, numbers: shutters.map{Double($0)})
            }
            
        } else if(cameraSettingMode == .ISO){
            currentValue = Double(cameraViewDelegete?.cameraSettingsModel.currentIso ?? 100)
        } else if(cameraSettingMode == .EXPOSURE){
            currentValue = Double(cameraViewDelegete?.cameraSettingsModel.currentExposureValue ?? 0)
        }
        
        let cameraSettingsValues = cameraViewDelegete?.cameraSettingsModel.getLisOfCameraSettingsValue(cameraSettingMode: cameraSettingMode)
        
        for value in (cameraSettingsValues ?? []) {
            
            if (value == Float(currentValue)) {
                isoValuesWithUserSelectedFlag[Double(value)] = 1.0
            } else {
                isoValuesWithUserSelectedFlag[Double(value)] = 0.0
            }
        }
    }
    
    private var isoValuesWithSelectedFlag: [Double: Double] {
        var dictionary: [Double: Double] = [:]
        
        var currentValue: Double = 1.0
        
        if(cameraSettingMode == .SHUTTER_SPEED){
            currentValue = CMTimeGetSeconds(cameraViewDelegete?.cameraSettingsModel.currentShutterSpeed ?? CMTime(seconds: 30.0, preferredTimescale: 1000)) * 1000
            if shutters.contains(Int(currentValue)){
                // Do nothing
            } else {
                currentValue = findIsoNearestNumber(value: currentValue, numbers: shutters.map{Double($0)})
                
            }
            
        } else if(cameraSettingMode == .ISO){
            currentValue = Double(cameraViewDelegete?.cameraSettingsModel.currentIso ?? 100)
        } else if(cameraSettingMode == .EXPOSURE){
            currentValue = Double(cameraViewDelegete?.cameraSettingsModel.currentExposureValue ?? 0)
        }
        
        
        let cameraSettingsValues = cameraViewDelegete?.cameraSettingsModel.getLisOfCameraSettingsValue(cameraSettingMode: cameraSettingMode)
        
        for value in (cameraSettingsValues ?? []) {
            
            if (value == Float(currentValue)) {
                dictionary[Double(value)] = 1.0
            } else {
                dictionary[Double(value)] = 0.0
            }
            
        }
        exposureValuesWithSelectedFlag = dictionary
        return dictionary
    }
    
    private var sliderValue: Double = 0.5
    
    var zoomValuesWithItemSelectionFlag: [Double: Double] = [ 1.0 : 1.0]
    
    var exposureValuesWithSelectedFlag: [Double: Double] = [:]
    
    private func updateValue(key: Double) {
        for zoomvValues in zoomValuesWithItemSelectionFlag.keys{
            if (key == zoomvValues){
                zoomValuesWithItemSelectionFlag[zoomvValues] = 1.0
            } else{
                zoomValuesWithItemSelectionFlag[zoomvValues] = 0.0
            }
        }
        
    }
    
    private func updateValuesWithSelectedIndex(values: [Double]) {
        zoomValuesWithItemSelectionFlag = values.reduce(into: [:]) { result, value in
            if value == 1.0 {
                result[value] = 1.0
            } else {
                result[value] = 0
            }
        }
    }
    
    private func updateExposureValue(key: Double) {
        for zoomvValues in isoValuesWithSelectedFlag.keys{
            if (key == zoomvValues){
                isoValuesWithUserSelectedFlag[zoomvValues] = 1.0
            } else{
                isoValuesWithUserSelectedFlag[zoomvValues] = 0.0
            }
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
        
        switch image {
        case .systemImageName(let systemName):
            button.setImage(UIImage(systemName: systemName), for: .normal)
            rescaleImage(transform: CGAffineTransform(scaleX: 1.2, y: 1.2))
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
    
    
    private func createTextButton(label: String, color: UIColor, action: Selector) {
        let textButton = UIButton(type:.custom)
        
        textButton.titleLabel?.text = label
        textButton.titleLabel?.textColor = color
        textButton.addTarget(self, action: action, for: .touchUpInside)
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
        //self.backgroundColor = .clear
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
        print("slider current value ", CGFloat(sender.value))
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
