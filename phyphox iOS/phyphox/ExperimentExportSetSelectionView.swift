//
//  ExperimentExportSetSelectionView.swift
//  phyphox
//
//  Created by Jonas Gessner on 29.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

private let ySpacing: CGFloat = 3.0
private let xSpacing: CGFloat = 10.0

private let checkboxSize = CGSize(width: 24.0, height: 24.0)

final class ExperimentExportSetSelectionView: UIView, BEMCheckBoxDelegate {
    let export: ExperimentExport
    
    let formatSwitches: [BEMCheckBox]
    let formatLabels: [UILabel]
    
    let exportAvailabilityCallback: Bool -> Void
    
    init(export: ExperimentExport, translation: ExperimentTranslationCollection?, exportAvailabilityCallback: Bool -> Void) {
        self.export = export
        self.exportAvailabilityCallback = exportAvailabilityCallback
        
        var fs = [BEMCheckBox]()
        fs.reserveCapacity(exportTypes.count)
        
        var fl = [UILabel]()
        fl.reserveCapacity(exportTypes.count)
        
        var on = true
        
        for (string, _) in exportTypes {
            let sw = BEMCheckBox()
            sw.boxType = .Circle
            sw.offAnimationType = .Bounce
            sw.onAnimationType = .Bounce
            sw.on = on
            sw.lineWidth = 1.0
            sw.onTintColor = kHighlightColor
            sw.onCheckColor = kHighlightColor
            
            on = false
            
            fs.append(sw)
            
            
            let la = UILabel()
            la.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)
            
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
    
    func didTapCheckBox(checkBox: BEMCheckBox) {
        checkBox.userInteractionEnabled = false
            
        formatSwitches.forEach { sw in
            if sw !== checkBox {
                sw.setOn(false, animated: true)
                sw.userInteractionEnabled = true
            }
        }
    }
    
    func selectedFormat() -> ExportFileFormat {
        for (i, sw) in formatSwitches.enumerate() {
            if sw.on {
                return exportTypes[i].1
            }
        }
        
        assert(false, "No file format selected")
    }
    
    //Auto Layout is evil. This works:
    
    override func sizeThatFits(size: CGSize) -> CGSize {
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
        
        for (i, label) in formatLabels.enumerate() {
            let s = label.sizeThatFits(bounds.size)
            let sw = formatSwitches[i]
            
            let heightDelta = (switchSize.height-s.height)/2.0
            
            label.frame = CGRectMake(xSpacing, h+2*ySpacing+heightDelta, s.width, s.height)
            
            sw.frame = CGRectMake(self.bounds.size.width-switchSize.width-xSpacing, label.center.y-switchSize.height/2.0, switchSize.width, switchSize.height)
            
            h += 2*ySpacing+max(s.height, switchSize.height)
        }
    }
}
