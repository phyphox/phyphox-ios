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
    
    required init(descriptor: SliderViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        
        uiSlider = UISlider()
        super.init(frame: .zero)
        
        
        guard Float(descriptor.minValue ?? 0.0) < Float(descriptor.maxValue ?? 1.0) else {
            fatalError("minValue must be less than maxValue")
        }
        
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = UIColor(named: "textColor")
        label.textAlignment = .center
        
        minValueLabel.numberOfLines = 0
        minValueLabel.text = numberFormatter(for: descriptor.minValue ?? 0.0)
        minValueLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        minValueLabel.textColor = UIColor(named: "textColor")
        minValueLabel.textAlignment = .center
        
        maxValueLabel.numberOfLines = 0
        maxValueLabel.text = numberFormatter(for: descriptor.maxValue ?? 0.0)
        maxValueLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        maxValueLabel.textColor = UIColor(named: "textColor")
        maxValueLabel.textAlignment = .center
        
        sliderValue.numberOfLines = 0
        sliderValue.font = UIFont.preferredFont(forTextStyle: .body)
        sliderValue.textColor = UIColor(named: "textColor")
        sliderValue.backgroundColor =  UIColor.lightGray.withAlphaComponent(0.2)
        sliderValue.textAlignment = .center
        
        if(descriptor.type == SliderType.Normal){
            
            sliderValue.text = numberFormatter(for: descriptor.defaultValue ?? 0.0)
            
            uiSlider.minimumValue = Float(descriptor.minValue ?? 0.0)
            uiSlider.maximumValue = Float(descriptor.maxValue ?? 0.0)
            uiSlider.value = Float(descriptor.defaultValue ?? 0.0)
            uiSlider.isUserInteractionEnabled = true
            uiSlider.minimumTrackTintColor = UIColor(named: "highlightColor")
            uiSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
            addSubview(uiSlider)
            
            if let buffer = descriptor.buffer {
                registerForUpdatesFromBuffer(buffer)
            }
        }
        
        if(descriptor.type == SliderType.Range){
            
            sliderValue.text = String(descriptor.minValue ?? 0.0) + " - " + String(descriptor.maxValue ?? 0.0)
            
            rangeSlider.minimumValue = descriptor.minValue ?? 0.0
            rangeSlider.lowerValue = descriptor.minValue ?? 0.0
            rangeSlider.upperValue = descriptor.maxValue ?? 1.0
            rangeSlider.maximumValue = descriptor.maxValue ?? 1.0
            
            self.descriptor.buffer?.replaceValues([descriptor.minValue ?? 0.0, descriptor.maxValue ?? 1.0])
            self.descriptor.buffer?.triggerUserInput()

            rangeSlider.addTarget(self, action: #selector(rangeSliderValueChanged), for: .valueChanged)
            
            addSubview(rangeSlider)
            
            if let buffer = descriptor.outputBuffers {
                for b_ in buffer{
                    registerForUpdatesFromBuffer(b_)
                }
                
            }
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
        
        descriptor.outputBuffers?[0].replaceValues([rangeSlider.lowerValue])
        self.descriptor.outputBuffers?[0].triggerUserInput()
        descriptor.outputBuffers?[1].replaceValues([rangeSlider.upperValue])
        self.descriptor.outputBuffers?[1].triggerUserInput()
        
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
            uiSlider.frame = CGRect(origin: CGPoint(x: 55, y: sliderContainerYValue), size: CGSize(width: bounds.width - 110, height: h2))
            
        }
        if(descriptor.type == SliderType.Range){
            rangeSlider.frame = CGRect(origin: CGPoint(x: 55, y: sliderContainerYValue), size: CGSize(width: bounds.width - 110, height: h2))
        }
        
        minValueLabel.frame = CGRect(origin: CGPoint(x: 0, y: sliderContainerYValue), size: CGSize(width: 60, height: h2))
        maxValueLabel.frame = CGRect(origin: CGPoint(x: bounds.width - 50, y: sliderContainerYValue), size: CGSize(width: 50, height: h2))
       
        
        
    }
    
    @objc func sliderValueChanged(_ sender: UISlider){
      
        updateSlider(from: Float(sender.value))
        
    }
    
    func setNeedsUpdate() {
        wantsUpdate = true
    }
    
    func update(){
       
        if(SliderType.Normal == descriptor.type){
            if(descriptor.value == 0.0){
                uiSlider.value = Float(descriptor.defaultValue ?? 0.0)
                sliderValue.text = numberFormatter(for: descriptor.defaultValue ?? 0.0)
            } else {
                uiSlider.value = Float(descriptor.value)
                sliderValue.text = numberFormatter(for: descriptor.value)
            }
        }
        
        if(SliderType.Range == descriptor.type){
            
            let lowerValue = descriptor.outputBuffers?[0].last ?? descriptor.minValue
            let upperValue = descriptor.outputBuffers?[1].last ?? descriptor.maxValue
        
            sliderValue.text = numberFormatter(for: lowerValue ?? 0.0) + " - "  + numberFormatter(for: upperValue ?? 0.0)

        }
    }
    
    
    func isEven(value: Double) -> Bool{
        return Double(Int(value)).remainder(dividingBy: 2.0) == 0.0
    }
    
    func updateSlider(from oldValue: Float) {
        
        if(descriptor.stepSize == 0){
            uiSlider.value = oldValue
            
            sliderValue.text = numberFormatter(for: Double(oldValue))
            self.descriptor.buffer?.replaceValues([Double(oldValue)])
            self.descriptor.buffer?.triggerUserInput()
            return
        }
        
         let stepSize = Float(descriptor.stepSize ?? 1.0)
         let defaultValue = descriptor.defaultValue ?? 0.0
         let minValue = Float(descriptor.minValue ?? 0.0)
         let flooredValue = floor((oldValue - minValue)/stepSize )
         
         let newValue: Float = (stepSize * flooredValue + minValue )
         
         guard let maxValue = descriptor.maxValue, let minValue = descriptor.minValue,
               newValue <= Float(maxValue), newValue >= Float(minValue) else {
             return
         }
        
        uiSlider.value = newValue
        sliderValue.text = numberFormatter(for: Double(newValue))
        
        self.descriptor.buffer?.replaceValues([Double(newValue)])
        self.descriptor.buffer?.triggerUserInput()
        
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
    
    let trackLayer = RangeSliderTrackLayer()
    let lowerThumbLayer = RangeSliderThumbLayer()
    let upperThumbLayer = RangeSliderThumbLayer()
    
    var previousLocation = CGPoint()
    
    var thumbWidth: CGFloat {
        return CGFloat(bounds.height)
    }
    
    var trackTintColor: UIColor = UIColor(white: 0.9, alpha: 1.0) {
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
        previousLocation = touch.location(in: self)

        // Hit test the thumb layers
        if lowerThumbLayer.frame.contains(previousLocation) {
            lowerThumbLayer.highlighted = true
        } else if upperThumbLayer.frame.contains(previousLocation) {
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
        let deltaLocation = Double(location.x - previousLocation.x)
        let deltaValue = (maximumValue - minimumValue) * deltaLocation / Double(bounds.width - thumbWidth)

        previousLocation = location

        // 2. Update the values
        if lowerThumbLayer.highlighted {
            lowerValue += deltaValue
            lowerValue = boundValue(value: lowerValue, toLowerValue: minimumValue, upperValue: upperValue)
        } else if upperThumbLayer.highlighted {
            upperValue += deltaValue
            upperValue = boundValue(value: upperValue, toLowerValue: lowerValue, upperValue: maximumValue)
        }
        

        sendActions(for: .valueChanged)

        return true
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        lowerThumbLayer.highlighted = false
        upperThumbLayer.highlighted = false
    }
    

    func updateLayerFrames() {
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        trackLayer.frame = bounds.insetBy(dx: 0.0, dy: bounds.height / 2.50)
        trackLayer.setNeedsDisplay()
        
        let lowerThumbCenter = CGFloat(positionForValue(value: lowerValue))
        
        lowerThumbLayer.frame = CGRect(x: lowerThumbCenter - thumbWidth / 2.0, y: -7.0,
                                       width: thumbWidth * 1.75, height: thumbWidth * 1.75)
        lowerThumbLayer.setNeedsDisplay()
        
        let upperThumbCenter = CGFloat(positionForValue(value: upperValue))
        upperThumbLayer.frame = CGRect(x: upperThumbCenter - thumbWidth / 2.0, y: -7.0,
            width: thumbWidth * 1.75, height: thumbWidth * 1.75)
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
        }
    }

}

