//
//  GraphGridView.swift
//  phyphox
//
//  Created by Jonas Gessner on 24.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

protocol GraphGridDelegate: class {
    func updatePlotArea()
}

final class GraphGridView: UIView {
    private let borderView = UIView()
    weak var delegate: GraphGridDelegate?
    var descriptor: GraphViewDescriptor? = nil
    
    var isZScale: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        borderView.layer.borderColor = UIColor(white: 1.0, alpha: 1.0).cgColor
        borderView.layer.borderWidth = 2.0/UIScreen.main.scale
        
        addSubview(borderView)
    }
    
    var gridInset: CGPoint = .zero {
        didSet {
            setNeedsLayout()
        }
    }
    
    var gridOffset: CGPoint = .zero {
        didSet {
            setNeedsLayout()
        }
    }
    
    var gridLabelSpace: CGPoint = .zero {
        didSet {
            self.delegate?.updatePlotArea()
        }
    }
    
    var insetRect: CGRect {
        return bounds.insetBy(dx: gridInset.x + gridLabelSpace.x/2.0, dy: gridInset.y + gridLabelSpace.y/2.0).offsetBy(dx: gridOffset.x+gridLabelSpace.x/2.0, dy: gridOffset.y - gridLabelSpace.y/2.0)
    }
    
    convenience init(descriptor: GraphViewDescriptor?, isZScale: Bool) {
        self.init(frame: .zero)
        self.descriptor = descriptor
        self.isZScale = isZScale
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init(descriptor: nil, isZScale: false)
    }
    
    var grid: GraphGrid? {
        didSet {
            updateLineViews()
            setNeedsLayout()
        }
    }
    
    private var lineViews: [GraphGridLineView] = []
    private var labels: [UILabel] = []

    var pauseMarkers: PauseRanges? {
        didSet {
            updatePauseMarkerViews()
            setNeedsLayout()
        }
    }
    
    private var pauseMarkerViews: [GraphPauseMarkerView] = []
    
    private func updateLineViews() {
        var neededViews = 0
        
        if let grid = grid {
            if isZScale {
                neededViews += grid.zGridLines.count
            } else {
                neededViews += grid.xGridLines.count
                neededViews += grid.yGridLines.count
            }
        }
        
        let delta = lineViews.count-neededViews
        
        func makeLabel() -> UILabel {
            let label = UILabel()
            let defaultFont = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
            label.font = defaultFont.withSize(defaultFont.pointSize * 0.8)
            
            addSubview(label)
            
            return label
        }
        
        if delta > 0 {
            var index = 0
            
            lineViews = lineViews.filter({ (view) -> Bool in
                if index < neededViews {
                    index += 1
                    return true
                }
                else {
                    view.removeFromSuperview()
                    return false
                }
            })
            
            index = 0
            
            labels = labels.filter({ (view) -> Bool in
                if index < neededViews {
                    index += 1
                    return true
                }
                else {
                    view.removeFromSuperview()
                    return false
                }
            })
        }
        else if delta < 0 {
            for _ in delta..<0 {
                let view = GraphGridLineView()
                
                addSubview(view)
                
                lineViews.append(view)
                
                labels.append(makeLabel())
            }
        }
    }
    
    private func updatePauseMarkerViews() {
        var neededViews = 0
        
        if let pauseMarkers = pauseMarkers {
            neededViews += pauseMarkers.xPauseRanges.count
            neededViews += pauseMarkers.yPauseRanges.count
        }
        
        let delta = pauseMarkerViews.count-neededViews
        
        
        if delta > 0 {
            var index = 0
            
            pauseMarkerViews = pauseMarkerViews.filter({ (view) -> Bool in
                if index < neededViews {
                    index += 1
                    return true
                }
                else {
                    view.removeFromSuperview()
                    return false
                }
            })
            
            index = 0
        }
        else if delta < 0 {
            for _ in delta..<0 {
                let view = GraphPauseMarkerView()
                addSubview(view)
                pauseMarkerViews.append(view)
            }
        }
    }
    
    override func layoutSubviews() {
        let spacing = 1.0/UIScreen.main.scale
        super.layoutSubviews()
        
        let formatterX = NumberFormatter()
        formatterX.usesSignificantDigits = true
        formatterX.minimumSignificantDigits = Int((isZScale ? descriptor?.zPrecision : descriptor?.xPrecision) ?? 3)
        
        let formatterY = NumberFormatter()
        formatterY.usesSignificantDigits = true
        formatterY.minimumSignificantDigits = Int(descriptor?.yPrecision ?? 3)
        
        func format(_ n: Double, formatter: NumberFormatter, isTime: Bool, systemTimeOffset: Double) -> String {
            if isTime && systemTimeOffset > 0 {
                let alignedOffset = systemTimeOffset + Double(TimeZone.current.secondsFromGMT())
                let t = Date(timeIntervalSince1970: systemTimeOffset + n)
                let dateFormatter = DateFormatter()
                let day = 24*60*60
                if Int(round(n + alignedOffset)) % day == 0 {
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .none
                } else {
                    dateFormatter.dateStyle = .none
                    dateFormatter.timeStyle = .medium
                }
                return dateFormatter.string(from: t)
            } else {
                let expThreshold = max(formatter.minimumSignificantDigits, 3)
                if (n == 0 || (abs(n) < pow(10.0, Double(expThreshold)) && abs(n) > pow(10.0, Double(-expThreshold)))) {
                    formatter.numberStyle = .decimal
                    return formatter.string(from: NSNumber(value: n as Double))!
                } else {
                    formatter.numberStyle = .scientific
                    return formatter.string(from: NSNumber(value: n as Double))!
                }
            }
        }
        
        var xSpace = CGFloat(0.0)
        var ySpace = CGFloat(0.0)
        var index = 0
        
        if let grid = grid {
            let horizontalGridLines = isZScale ? grid.zGridLines : grid.xGridLines
            for line in horizontalGridLines {
                let label = labels[index]
                label.textColor = kTextColor

                label.text = format(line.absoluteValue, formatter: formatterX, isTime: descriptor?.timeOnX ?? false, systemTimeOffset: grid.systemTimeOffsetX)
                label.sizeToFit()

                ySpace = max(ySpace, label.frame.size.height)

                index += 1
            }

            if !isZScale {
                for line in grid.yGridLines {
                    let label = labels[index]
                    label.textColor = kTextColor

                    label.text = format(line.absoluteValue, formatter: formatterY, isTime: descriptor?.timeOnY ?? false, systemTimeOffset: grid.systemTimeOffsetY)
                    label.sizeToFit()

                    xSpace = max(xSpace, label.frame.size.width)

                    index += 1
                }
            }
        }

        gridLabelSpace = CGPoint(x: xSpace, y: ySpace)
        
        borderView.frame = insetRect
        
        if let grid = grid {
            index = 0

            let smallestUnit = 1.0/UIScreen.main.scale

            let horizontalGridLines = isZScale ? grid.zGridLines : grid.xGridLines
            
            for line in horizontalGridLines {
                let view = lineViews[index]

                view.horizontal = false

                let origin = insetRect.size.width*line.relativeValue

                if !origin.isFinite {
                    view.isHidden = true
                    continue
                }

                view.frame = CGRect(x: origin+insetRect.origin.x, y: insetRect.origin.y, width: smallestUnit, height: insetRect.size.height)

                let label = labels[index]
                label.frame = CGRect(x: origin+insetRect.origin.x-label.frame.size.width/2.0, y: insetRect.maxY+spacing, width: label.frame.size.width, height: label.frame.size.height)

                index += 1
            }

            if !isZScale {
                for line in grid.yGridLines {
                    let view = lineViews[index]

                    view.horizontal = true

                    let origin = insetRect.size.height-insetRect.size.height*line.relativeValue

                    if !origin.isFinite {
                        view.isHidden = true
                        continue
                    }

                    view.frame = CGRect(x: insetRect.origin.x, y: origin+insetRect.origin.y, width: insetRect.size.width, height: smallestUnit)

                    let label = labels[index]
                    label.frame = CGRect(x: insetRect.origin.x-spacing-label.frame.size.width, y: origin+insetRect.origin.y-label.frame.size.height/2.0, width: label.frame.size.width, height: label.frame.size.height)

                    index += 1
                }
            }
        }
        
        index = 0
        if let pauseMarkers = pauseMarkers {
            for pauseRange in pauseMarkers.xPauseRanges {
                let view = pauseMarkerViews[index]

                view.frame = CGRect(x: pauseRange.relativeBegin * insetRect.size.width+insetRect.origin.x, y: insetRect.origin.y, width: (pauseRange.relativeEnd - pauseRange.relativeBegin)*insetRect.size.width, height: insetRect.size.height)

                index += 1
            }
            for pauseRange in pauseMarkers.yPauseRanges {
                let view = pauseMarkerViews[index]

                view.frame = CGRect(x: insetRect.origin.x, y: pauseRange.relativeBegin * insetRect.size.height + insetRect.origin.y, width: insetRect.size.width, height: (pauseRange.relativeEnd - pauseRange.relativeBegin)*insetRect.size.height)

                index += 1
            }
        }
        
        bringSubviewToFront(borderView)
    }
}
