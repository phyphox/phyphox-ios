//
//  ExperimentSliderView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 26.11.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

private let spacing: CGFloat = 10.0
private let textFieldWidth: CGFloat = 100.0

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
    
    private let uiSlider: UISlider
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
        sliderValue.text = numberFormatter(for: descriptor.defaultValue ?? 0.0)
        sliderValue.font = UIFont.preferredFont(forTextStyle: .body)
        sliderValue.textColor = UIColor(named: "textColor")
        sliderValue.backgroundColor =  UIColor.lightGray.withAlphaComponent(0.2)
        sliderValue.textAlignment = .center
        
        uiSlider.minimumValue = Float(descriptor.minValue ?? 0.0)
        uiSlider.maximumValue = Float(descriptor.maxValue ?? 0.0)
        uiSlider.value = Float(descriptor.defaultValue ?? 0.0)
        uiSlider.isUserInteractionEnabled = true
    
        uiSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        
        addSubview(label)
        addSubview(sliderValue)
        addSubview(minValueLabel)
        addSubview(uiSlider)
        addSubview(maxValueLabel)
        
        registerForUpdatesFromBuffer(descriptor.buffer)
        attachDisplayLink(displayLink)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        
        let s1 = label.sizeThatFits(size)
        var s2 = sliderValue.sizeThatFits(size)
        s2.width = textFieldWidth
       
        let left = s1.width + spacing/2.0
        let right = s2.width + spacing/2.0
        
        dynamicLabelHeight = Utility.measureHeightOfText(label.text ?? "-") * 2.5
        let width = min(2.0 * max(left, right), size.width)
        
        return CGSize(width: size.width, height: dynamicLabelHeight * 1.5)
        
    }
    
    override func layoutSubviews() {
        
        let h2 = sliderValue.sizeThatFits(self.bounds.size).height
        let w = (bounds.width - spacing)/2.0
        
        let measuredWidthOfLabel = Utility.measureWidthOfText(label.text ?? "-")
        let labelOffset = (((bounds.width ) / 2.0) - measuredWidthOfLabel) / 2.0
        label.frame = CGRect(origin: CGPoint(x: labelOffset , y: (bounds.height - dynamicLabelHeight)/2.0 - 20.0) , size: CGSize(width: w, height: dynamicLabelHeight))
        
        sliderValue.frame = CGRect(origin: CGPoint(x: (bounds.width + spacing)/2.0, y: (bounds.height - h2)/2.0 - 20.0) , size: CGSize(width: textFieldWidth, height: h2))
        
        minValueLabel.frame = CGRect(origin: CGPoint(x: 0, y: bounds.height / 2.0), size: CGSize(width: 40, height: h2))
        
        uiSlider.frame = CGRect(origin: CGPoint(x: 30, y: bounds.height / 2.0), size: CGSize(width: bounds.width - 70, height: h2))
        
        maxValueLabel.frame = CGRect(origin: CGPoint(x: bounds.width - 40, y: bounds.height / 2.0), size: CGSize(width: 40, height: h2))

    }
    
    @objc func sliderValueChanged(_ sender: UISlider){
      
        updateSlider(from: Float(sender.value))
        
    }
    
    func setNeedsUpdate() {
        wantsUpdate = true
    }
    
    func update(){
       
        if(descriptor.value == 0.0){
            uiSlider.value = Float(descriptor.defaultValue ?? 0.0)
            sliderValue.text = numberFormatter(for: descriptor.defaultValue ?? 0.0)
        } else {
            uiSlider.value = Float(descriptor.value)
            sliderValue.text = numberFormatter(for: descriptor.value)
        }
        
    }
    
    
    func isEven(value: Double) -> Bool{
        return Double(Int(value)).remainder(dividingBy: 2.0) == 0.0
    }
    
    func updateSlider(from oldValue: Float) {
        
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
        
        self.descriptor.buffer.replaceValues([Double(newValue)])
        self.descriptor.buffer.triggerUserInput()
        
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

