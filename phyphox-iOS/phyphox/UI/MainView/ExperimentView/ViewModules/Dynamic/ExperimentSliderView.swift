//
//  ExperimentSliderView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 26.11.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//


import Foundation
import QuartzCore

private let spacing: CGFloat = 10.0


final class ExperimentSliderView: UIView, DynamicViewModule, DescriptorBoundViewModule, AnalysisLimitedViewModule {

    var descriptor: SliderViewDescriptor
    var analysisRunning: Bool = false
    
    private let displayLink = DisplayLink(refreshRate: 5)
    
    private var wantsUpdate = false
    
    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }
    
    var dynamicLabelHeight = 0.0
    private var textFieldWidth: CGFloat = 100.0
    
    private let uiSlider: UISlider
    private let rangeSlider = RangeSlider(frame: CGRectZero)
    private let label = UILabel()
    private let sliderValue = UILabel()
    
    private let minValueLabel = UILabel()
    private let maxValueLabel = UILabel()
    
    private var sliderBuffer : DataBuffer?
    
    private var rangeSliderLowerBuffer : DataBuffer?
    private var rangeSliderUpperBuffer : DataBuffer?
    
    required init(descriptor: SliderViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        
        uiSlider = UISlider()
        super.init(frame: .zero)
        
        
        guard Float(descriptor.minValue) < Float(descriptor.maxValue) else {
            fatalError("minValue must be less than maxValue")
        }
        
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = UIColor(named: "textColor")
        label.textAlignment = .center
        
        minValueLabel.numberOfLines = 0
        minValueLabel.text = numberFormatter(for: descriptor.minValue)
        minValueLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        minValueLabel.textColor = UIColor(named: "textColor")
        minValueLabel.textAlignment = .center
        minValueLabel.adjustsFontSizeToFitWidth = true
        
        maxValueLabel.numberOfLines = 0
        maxValueLabel.text = numberFormatter(for: descriptor.maxValue)
        maxValueLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        maxValueLabel.textColor = UIColor(named: "textColor")
        maxValueLabel.textAlignment = .center
        maxValueLabel.adjustsFontSizeToFitWidth = true
        
        sliderValue.numberOfLines = 0
        sliderValue.font = UIFont.preferredFont(forTextStyle: .body)
        sliderValue.textColor = UIColor(named: "textColor")
        sliderValue.backgroundColor =  UIColor.lightGray.withAlphaComponent(0.2)
        sliderValue.textAlignment = .center
        sliderValue.adjustsFontSizeToFitWidth = true
        
        if(descriptor.type == SliderType.Normal){
            
            sliderValue.text = numberFormatter(for: descriptor.defaultValue ?? 0.0)
            
            uiSlider.minimumValue = Float(descriptor.minValue)
            uiSlider.maximumValue = Float(descriptor.maxValue)
            uiSlider.value = Float(descriptor.defaultValue ?? 0.0)
            uiSlider.isUserInteractionEnabled = true
            
            
            uiSlider.minimumTrackTintColor = UIColor(named: "highlightColor")
            uiSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
            addSubview(uiSlider)
            
            if let buffer = descriptor.outputBuffers[.Empty] {
                sliderBuffer = buffer
                registerForUpdatesFromBuffer(sliderBuffer!)
            }
            
        }
        
        if(descriptor.type == SliderType.Range){
            
            sliderValue.text = String(descriptor.minValue) + " - " + String(descriptor.maxValue)
            
            
            rangeSlider.upperValue = descriptor.maxValue
            rangeSlider.maximumValue = descriptor.maxValue
            rangeSlider.minimumValue = descriptor.minValue
            rangeSlider.lowerValue = descriptor.minValue
            
            rangeSlider.stepSize = descriptor.stepSize
                       
            addSubview(rangeSlider)
            
            if let upperValueBuffer = descriptor.outputBuffers[.UpperValue]  {
                rangeSliderUpperBuffer = upperValueBuffer
                registerForUpdatesFromBuffer(rangeSliderUpperBuffer!)
                rangeSliderUpperBuffer?.replaceValues([descriptor.maxValue])
                rangeSliderUpperBuffer?.triggerUserInput()
            }
            
            if let lowerValueBuffer = descriptor.outputBuffers[.LowerValue] {
                rangeSliderLowerBuffer = lowerValueBuffer
                registerForUpdatesFromBuffer(rangeSliderLowerBuffer!)
                rangeSliderLowerBuffer?.replaceValues([descriptor.minValue])
                rangeSliderLowerBuffer?.triggerUserInput()
            }
            

            rangeSlider.addTarget(self, action: #selector(rangeSliderValueChanged), for: .valueChanged)
            
        }
        
        
        if(descriptor.showValue){
            addSubview(label)
            addSubview(sliderValue)
        }
        
        addSubview(minValueLabel)
        addSubview(maxValueLabel)
        
        attachDisplayLink(displayLink)
    }
    
    @objc func rangeSliderValueChanged(rangeSlider: RangeSlider) {
        
        sliderValue.text = numberFormatter(for: rangeSlider.lowerValue) + " - "  + numberFormatter(for: rangeSlider.upperValue)
        
        rangeSliderLowerBuffer?.replaceValues([rangeSlider.lowerValue])
        rangeSliderLowerBuffer?.triggerUserInput()
        rangeSliderUpperBuffer?.replaceValues([rangeSlider.upperValue])
        rangeSliderUpperBuffer?.triggerUserInput()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        
        if(descriptor.showValue){
            let s1 = label.sizeThatFits(size)
            var s2 = sliderValue.sizeThatFits(size)
            s2.width = textFieldWidth
           
            _ = s1.width + spacing/2.0
            _ = s2.width + spacing/2.0
            
            
            dynamicLabelHeight = Utility.measureHeightOfText(label.text ?? "-") * 2.5
            return CGSize(width: size.width, height: dynamicLabelHeight * 1.5)
        } else {
            dynamicLabelHeight = Utility.measureHeightOfText(minValueLabel.text ?? "-") * 1.5
            return CGSize(width: size.width, height: dynamicLabelHeight)
        }
        
        
    }
    
    override func layoutSubviews() {
        
        let h2 = minValueLabel.sizeThatFits(self.bounds.size).height
        let w = (bounds.width - spacing)/2.0
        
        var sliderContainerYValue = 0.0
        
        let paddingForSliderRow = 10.0
        
        if(descriptor.showValue){
            sliderContainerYValue = bounds.height / 2.0
            sliderContainerYValue = sliderContainerYValue + 10.0
            
            if(descriptor.type == SliderType.Range){
                textFieldWidth *= 1.25
            }
            
            sliderValue.frame = CGRect(origin: CGPoint(x: (bounds.width + spacing)/2.0, y: (bounds.height - h2)/2.0 - 12.0) , size: CGSize(width: textFieldWidth, height: h2))
            let measuredWidthOfLabel = Utility.measureWidthOfText(label.text ?? "-")
            let labelOffset = (((bounds.width ) / 2.0) - measuredWidthOfLabel) / 2.0
            label.frame = CGRect(origin: CGPoint(x: labelOffset , y: (bounds.height - dynamicLabelHeight)/2.0 - 12.0) , size: CGSize(width: w, height: dynamicLabelHeight))
        }
        
        if(descriptor.type == SliderType.Normal){
            uiSlider.frame = CGRect(origin: CGPoint(x: 50 + paddingForSliderRow, y: sliderContainerYValue), size: CGSize(width: bounds.width - 110 - paddingForSliderRow, height: h2))
            
        }
        if(descriptor.type == SliderType.Range){
            rangeSlider.frame = CGRect(origin: CGPoint(x: 52 + paddingForSliderRow, y: sliderContainerYValue), size: CGSize(width: bounds.width - 115 - paddingForSliderRow, height: h2))
        }
        
        minValueLabel.frame = CGRect(origin: CGPoint(x: paddingForSliderRow, y: sliderContainerYValue), size: CGSize(width: 50, height: h2))
        maxValueLabel.frame = CGRect(origin: CGPoint(x: bounds.width - 50 - paddingForSliderRow, y: sliderContainerYValue), size: CGSize(width: 50, height: h2))
       
    }
    
    @objc func sliderValueChanged(_ sender: UISlider){
      
        updateSlider(from: Double(sender.value))
        
    }
    
   
    func setNeedsUpdate() {
        wantsUpdate = true
    }
    
    func update(){
       
        if(SliderType.Normal == descriptor.type){
            if(sliderBuffer?.last == 0.0){
                uiSlider.value = Float(descriptor.defaultValue ?? 0.0)
                sliderValue.text = numberFormatter(for: descriptor.defaultValue ?? 0.0)
            } else {
                uiSlider.value = Float(sliderBuffer?.last ?? 0.0)
                sliderValue.text = numberFormatter(for: sliderBuffer?.last ?? 0.0)
            }
        }
        
        if(SliderType.Range == descriptor.type){
            
            let lowerValue = rangeSliderLowerBuffer?.last ?? descriptor.minValue
            let upperValue = rangeSliderUpperBuffer?.last ?? descriptor.maxValue
            
            rangeSlider.lowerValue = lowerValue
            rangeSlider.upperValue = upperValue
            
        
            sliderValue.text = numberFormatter(for: lowerValue) + " - "  + numberFormatter(for: upperValue)

        }
    }
    
    func updateSlider(from oldValue: Double) {
        
        let steppedValue = if descriptor.stepSize == 0 {
            oldValue
        } else {
            round(oldValue / descriptor.stepSize) * descriptor.stepSize
        }
        let newValue = min(max(steppedValue, descriptor.minValue), descriptor.maxValue)
        
        uiSlider.value = Float(newValue)
        sliderValue.text = numberFormatter(for: newValue)
        
        sliderBuffer?.replaceValues([newValue])
        sliderBuffer?.triggerUserInput()
        
    }
    
    func numberFormatter(for value: Double) -> String{
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = descriptor.precision
        formatter.maximumFractionDigits = descriptor.precision
        formatter.minimumIntegerDigits = 1
        formatter.numberStyle = .decimal
        
        let number = NSNumber(value: value)
        
        return formatter.string(from: number) ?? " "
        
    }
    
}

extension ExperimentSliderView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate && !analysisRunning {
            wantsUpdate = false
            update()
        }
    }
}

// Source for this code is: https://www.kodeco.com/2297-how-to-make-a-custom-control-tutorial-a-reusable-slider
class RangeSlider: UIControl{
 
    var minimumValue: Double = 0.0 {
        didSet {
            updateLayerFrames()
        }
    }

    var maximumValue: Double = 1.0 {
        didSet {
            updateLayerFrames()
        }
    }

    var lowerValue: Double = 0.2 {
        didSet {
            updateLayerFrames()
        }
    }

    var upperValue: Double = 0.8 {
        didSet {
            updateLayerFrames()
        }
    }
    
    var stepSize: Double = 0.0 {
        didSet {
            updateLayerFrames()
        }
    }
    
    let trackLayer = RangeSliderTrackLayer()
    let lowerThumbLayer = RangeSliderThumbLayer()
    let upperThumbLayer = RangeSliderThumbLayer()
        
    var thumbWidth: CGFloat {
        return CGFloat(bounds.height)
    }
    
    var trackTintColor: UIColor = UIColor(white: 0.25, alpha: 1.0) {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }

    var trackHighlightTintColor: UIColor = UIColor(red: 0.0, green: 0.45, blue: 0.94, alpha: 1.0) {
        didSet {
            trackLayer.setNeedsDisplay()
        }
    }

    var thumbTintColor: UIColor = UIColor(named: "white")! {
        didSet {
            lowerThumbLayer.setNeedsDisplay()
            upperThumbLayer.setNeedsDisplay()
        }
    }

    var curvaceousness: CGFloat = 1.0 {
        didSet {
            trackLayer.setNeedsDisplay()
            lowerThumbLayer.setNeedsDisplay()
            upperThumbLayer.setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        trackLayer.rangeSlider = self
        trackLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(trackLayer)

        lowerThumbLayer.rangeSlider = self
        lowerThumbLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(lowerThumbLayer)

        upperThumbLayer.rangeSlider = self
        upperThumbLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(upperThumbLayer)
        
        lowerThumbLayer.rangeSlider = self
        upperThumbLayer.rangeSlider = self
        
        updateLayerFrames()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let initialLocation = touch.location(in: self)

        // Hit test the thumb layers
        if lowerThumbLayer.frame.insetBy(dx: -thumbWidth/2.0, dy: -thumbWidth/2.0).contains(initialLocation) {
            lowerThumbLayer.highlighted = true
        } else if upperThumbLayer.frame.insetBy(dx: -thumbWidth/2.0, dy: -thumbWidth/2.0).contains(initialLocation) {
            upperThumbLayer.highlighted = true
        }

        return lowerThumbLayer.highlighted || upperThumbLayer.highlighted
    }
    
    func boundValue(value: Double, toLowerValue lowerValue: Double, upperValue: Double) -> Double {
        return min(max(value, lowerValue), upperValue)
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let location = touch.location(in: self)

        // 1. Determine by how much the user has dragged
        let relativeLocation = Double(location.x - bounds.minX - 0.5*thumbWidth) / Double(bounds.width - thumbWidth)

        var newValue = minimumValue + (maximumValue - minimumValue) * relativeLocation
                
        if stepSize > 0 {
            newValue = round(newValue / stepSize) * stepSize
        }
                         
        // 2. Update the values
        if lowerThumbLayer.highlighted {
            let boundLowerValue = boundValue(value: newValue, toLowerValue: minimumValue, upperValue: upperValue)
            if (boundLowerValue != lowerValue) {
                lowerValue = boundLowerValue
                sendActions(for: .valueChanged)
            }
        } else if upperThumbLayer.highlighted {
            let boundUpperValue = boundValue(value: newValue, toLowerValue: lowerValue, upperValue: maximumValue)
            if (boundUpperValue != upperValue) {
                upperValue = boundUpperValue
                sendActions(for: .valueChanged)
            }
        }

        return true
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        lowerThumbLayer.highlighted = false
        upperThumbLayer.highlighted = false
    }
    
    //Enlarge touchable area beyond the rather small bounds
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.insetBy(dx: -thumbWidth, dy: -thumbWidth).contains(point)
    }
    
    //Never use input on the slider for a gesture
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    func updateLayerFrames() {
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        trackLayer.frame = bounds.insetBy(dx: 0.5, dy: bounds.height / 2.50)
        trackLayer.setNeedsDisplay()
        
        let thumbSize = thumbWidth * 1.45
        let thumbVerticalPlacement = (thumbWidth - thumbSize) / 2.0
        
        let lowerThumbCenter = CGFloat(positionForValue(value: lowerValue))
        let lowerThumbHorizontalPlacement = lowerThumbCenter - thumbWidth / 1.5
        
        lowerThumbLayer.frame = CGRect(x: lowerThumbHorizontalPlacement, y: thumbVerticalPlacement,
                                       width: thumbSize, height: thumbSize)
        lowerThumbLayer.setNeedsDisplay()
        
        let upperThumbCenter = CGFloat(positionForValue(value: upperValue))
        let upperThumbHorizontalPlacement = upperThumbCenter - thumbWidth / 1.4
        
        upperThumbLayer.frame = CGRect(x: upperThumbHorizontalPlacement, y: thumbVerticalPlacement,
                                       width: thumbSize, height: thumbSize)
        upperThumbLayer.setNeedsDisplay()
        
        CATransaction.commit()
    }

    func positionForValue(value: Double) -> Double {
        return Double(bounds.width - thumbWidth) * (value - minimumValue) /
            (maximumValue - minimumValue) + Double(thumbWidth / 2.0)
    }
    
    override var frame: CGRect {
        didSet {
            updateLayerFrames()
        }
    }
}

class RangeSliderThumbLayer: CALayer {
    var highlighted: Bool = false {
        didSet {
            setNeedsDisplay()
        }
    }
    weak var rangeSlider: RangeSlider?
    
    override func draw(in ctx: CGContext) {
        if let slider = rangeSlider {
            let thumbFrame = bounds.insetBy(dx: 2.0, dy: 2.0)
            let cornerRadius = thumbFrame.height * slider.curvaceousness / 2.0
            let thumbPath = UIBezierPath(roundedRect: thumbFrame, cornerRadius: cornerRadius)

            // Fill - with a subtle shadow
            let shadowColor = UIColor.gray
            ctx.setShadow(offset: CGSize(width: 0.0, height: 1.0), blur: 1.0, color: shadowColor.cgColor)
            ctx.setFillColor(slider.thumbTintColor.cgColor )
            ctx.addPath(thumbPath.cgPath)
            ctx.fillPath()

        }
    }
}

class RangeSliderTrackLayer: CALayer {
    weak var rangeSlider: RangeSlider?
    
    override func draw(in ctx: CGContext) {
        if let slider = rangeSlider {
            // Clip
            let cornerRadius = bounds.height * slider.curvaceousness / 2.0
            let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
            ctx.addPath(path.cgPath)
            
            // Fill the track
            ctx.setFillColor(slider.trackTintColor.cgColor)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
            
            
            // Fill the highlighted range
            ctx.setFillColor(UIColor(named: "highlightColor")?.cgColor ?? slider.trackHighlightTintColor.cgColor)
            let lowerValuePosition = CGFloat(slider.positionForValue(value: slider.lowerValue))
            let upperValuePosition = CGFloat(slider.positionForValue(value: slider.upperValue))
            let rect = CGRect(x: lowerValuePosition, y: 0.0, width: upperValuePosition - lowerValuePosition, height: bounds.height)
            ctx.fill(rect)
            
            
            // Since native iOS slider doenot have marker in the slider indicating its discreteness, drawing of it is disabled.
            /**
            if(slider.stepSize != 0.0){
                let numberOfSteps : Int = (Int((slider.maximumValue - slider.minimumValue)) / Int(slider.stepSize))

                for step in 1..<numberOfSteps {
                    let minMaxDifference = (slider.maximumValue - slider.minimumValue)
                    let increaseBy = floor((Double(step) * minMaxDifference  / Double(numberOfSteps)))
                    let stepValue = slider.minimumValue + increaseBy
                    
                    ctx.setFillColor(UIColor(named: "white")?.cgColor ?? slider.trackHighlightTintColor.cgColor)
                    let positiion = CGFloat(slider.positionForValue(value: stepValue))
                    let rect = CGRect(x: positiion, y: 0.0, width: 2, height: bounds.height)
                    ctx.fill(rect)
                }
             }
                 */
           
        }
    }

}

