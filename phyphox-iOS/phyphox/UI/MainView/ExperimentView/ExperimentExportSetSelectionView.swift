//
//  ExperimentExportSetSelectionView.swift
//  phyphox
//
//  Created by Jonas Gessner on 29.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit
import BEMCheckBox

private let ySpacing: CGFloat = 3.0
private let xSpacing: CGFloat = 10.0

private let checkboxSize = CGSize(width: 24.0, height: 24.0)

final class ExperimentExportSetSelectionView: UIView, BEMCheckBoxDelegate {
    
    let formatSwitches: [BEMCheckBox]
    let formatLabels: [UILabel]
    
    init() {
        
        var fs = [BEMCheckBox]()
        fs.reserveCapacity(exportTypes.count)
        
        var fl = [UILabel]()
        fl.reserveCapacity(exportTypes.count)
        
        var on = true
        
        for (string, _) in exportTypes {
            let sw = BEMCheckBox()
            sw.boxType = .circle
            sw.offAnimationType = .bounce
            sw.onAnimationType = .bounce
            sw.on = on
            sw.isUserInteractionEnabled = !on
            sw.lineWidth = 1.0
            sw.onTintColor = kHighlightColor
            sw.onCheckColor = kHighlightColor
            
            on = false
            
            fs.append(sw)
            
            
            let la = UILabel()
            la.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1)
            
            la.text = string
            
            fl.append(la)
        }
        
        formatSwitches = fs
        formatLabels = fl
        
        super.init(frame: .zero)
        
       formatSwitches.forEach { sw in
            sw.delegate = self
            addSubview(sw)
        }
        
        formatLabels.forEach { la in
            addSubview(la)
        }
        
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func didTap(_ checkBox: BEMCheckBox) {
        checkBox.isUserInteractionEnabled = false
            
        formatSwitches.forEach { sw in
            if sw !== checkBox {
                sw.setOn(false, animated: true)
                sw.isUserInteractionEnabled = true
            }
        }
    }
    
    func selectedFormat() -> ExportFileFormat {
        for (i, sw) in formatSwitches.enumerated() {
            if sw.on {
                return exportTypes[i].1
            }
        }
        
        fatalError("No file format selected")
    }
    
    //Auto Layout is evil. This works:
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var w: CGFloat = 0.0
        var h: CGFloat = 0.0
        
       let switchSize = checkboxSize
        
        for label in formatLabels {
            let s = label.sizeThatFits(size)
            
            w = max(xSpacing+s.width+xSpacing+switchSize.width+xSpacing, w)
            h += 2*ySpacing+max(s.height, switchSize.height)
        }
        
        return CGSize(width: max(w, size.width), height: h+20.0) //Need some more space so it doesn't look weird on the alert
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var h: CGFloat = 0.0
        
        let switchSize = checkboxSize
        
        for (i, label) in formatLabels.enumerated() {
            let s = label.sizeThatFits(bounds.size)
            let sw = formatSwitches[i]
            
            let heightDelta = (switchSize.height-s.height)/2.0
            
            label.frame = CGRect(x: xSpacing, y: h+2*ySpacing+heightDelta, width: s.width, height: s.height)
            
            sw.frame = CGRect(x: self.bounds.size.width-switchSize.width-xSpacing, y: label.center.y-switchSize.height/2.0, width: switchSize.width, height: switchSize.height)
            
            h += 2*ySpacing+max(s.height, switchSize.height)
        }
    }
}
