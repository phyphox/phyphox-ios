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

private let exportTypes = [("CSV", ExportFileFormat.CSV(separator: ",")), ("CSV (Tab separated)", ExportFileFormat.CSV(separator: "\t")), ("Excel", ExportFileFormat.Excel)]

private let checkboxSize = CGSize(width: 24.0, height: 24.0)

final class ExperimentExportSetSelectionView: UIView, BEMCheckBoxDelegate {
    let export: ExperimentExport
    
    let switches: [BEMCheckBox]
    let labels: [UILabel]
    
    let formatLabel = UILabel()
    
    let formatSwitches: [BEMCheckBox]
    let formatLabels: [UILabel]
    
    let exportAvailabilityCallback: Bool -> Void
    
    init(export: ExperimentExport, translation: ExperimentTranslationCollection?, exportAvailabilityCallback: Bool -> Void) {
        self.export = export
        self.exportAvailabilityCallback = exportAvailabilityCallback
        
        var s = [BEMCheckBox]()
        s.reserveCapacity(export.sets.count)
        
        var l = [UILabel]()
        l.reserveCapacity(export.sets.count)
        
        for set in export.sets {
            let sw = BEMCheckBox()
            sw.boxType = .Square
            sw.offAnimationType = .Bounce
            sw.onAnimationType = .Bounce
            sw.on = true
            sw.lineWidth = 1.0
            sw.onTintColor = kHighlightColor
            sw.onCheckColor = kHighlightColor
            sw.tag = 0
            
            s.append(sw)


            let la = UILabel()
            la.font = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption1)
            
            la.text = set.localizedName
            
            l.append(la)
        }
        
        switches = s
        labels = l
        
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
            sw.tag = 1
            
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
        
        switches.forEach { sw in
            sw.delegate = self
            addSubview(sw)
        }
        
        labels.forEach { la in
            addSubview(la)
        }
        
       formatSwitches.forEach { sw in
            sw.delegate = self
            addSubview(sw)
        }
        
        formatLabels.forEach { la in
            addSubview(la)
        }
        
        formatLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        formatLabel.text = "Select the file format:"
        
        addSubview(formatLabel)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func didTapCheckBox(checkBox: BEMCheckBox) {
        if checkBox.tag == 1 {
            checkBox.userInteractionEnabled = false
            
            formatSwitches.forEach { sw in
                if sw !== checkBox {
                    sw.setOn(false, animated: true)
                    sw.userInteractionEnabled = true
                }
            }
        }
        else if checkBox.tag == 0 {
            var anyOn = false
            
            for box in switches {
                if box.on {
                    anyOn = true
                    break
                }
            }
            
            exportAvailabilityCallback(anyOn)
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
    
    func activeSets() -> [ExperimentExportSet]? {
        var sets = [ExperimentExportSet]()
        
        for (i, sw) in switches.enumerate() {
            if sw.on {
                sets.append(export.sets[i])
            }
        }
        
        return sets.count > 0 ? sets : nil
    }
    
    //Auto Layout is evil. This works:
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        var w: CGFloat = 0.0
        var h: CGFloat = -2*ySpacing+1.0 //Checkbox draws out of bounds, give it some more space..
        
       let switchSize = checkboxSize
        
        for label in labels {
            let s = label.sizeThatFits(size)
            
            w = max(xSpacing+s.width+xSpacing+switchSize.width+xSpacing, w)
            h += 2*ySpacing+max(s.height, switchSize.height)
        }
        
        let labelSize = formatLabel.sizeThatFits(size)
        w = max(labelSize.width, w)
        
        h += 6*ySpacing+labelSize.height
        
        for label in formatLabels {
            let s = label.sizeThatFits(size)
            
            w = max(xSpacing+s.width+xSpacing+switchSize.width+xSpacing, w)
            h += 2*ySpacing+max(s.height, switchSize.height)
        }
        
        return CGSize(width: max(w, size.width), height: h+20.0) //Need some more space so it doesn't look weird on the alert
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var h: CGFloat = -2*ySpacing+1.0
        
        let switchSize = checkboxSize
        
        for (i, label) in labels.enumerate() {
            let s = label.sizeThatFits(self.bounds.size)
            let sw = switches[i]
            
            let heightDelta = (switchSize.height-s.height)/2.0
            
            label.frame = CGRectMake(xSpacing, h+2*ySpacing+heightDelta, s.width, s.height)
            
            sw.frame = CGRectMake(self.bounds.size.width-switchSize.width-xSpacing, label.center.y-switchSize.height/2.0, switchSize.width, switchSize.height)
            
            h += 2*ySpacing+max(s.height, switchSize.height)
        }
        
        let labelSize = formatLabel.sizeThatFits(bounds.size)
        
        formatLabel.frame = CGRectMake((bounds.size.width-labelSize.width)/2.0, h+4*ySpacing, labelSize.width, labelSize.height)
        
        h += 6*ySpacing+labelSize.height
        
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
