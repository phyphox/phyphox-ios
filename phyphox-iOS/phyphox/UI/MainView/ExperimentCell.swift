//
//  ExperimentCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit

class ExperimentCell: UICollectionViewCell {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var iconView: UIView?
    
    private let separator = UIView()
    
    private var optionsButton: PTButton?
    
    var showsOptionsButton = false {
        didSet {
            if showsOptionsButton {
                if optionsButton == nil {
                    optionsButton = PTButton()
                    optionsButton!.setImage(generateDots(15.0), for: UIControlState())
                    optionsButton!.accessibilityLabel = NSLocalizedString("actions", comment: "")
                    optionsButton!.addTarget(self, action: #selector(optionsButtonPressed(_:)), for: .touchUpInside)
                    
                    optionsButton!.setTintColor(kHighlightColor, for: UIControlState())
                    optionsButton!.setTintColor(kHighlightColor.interpolating(to: UIColor.black, byFraction: 0.5), for: .highlighted)
                    contentView.addSubview(optionsButton!)
                }
            }
            else {
                if optionsButton != nil {
                    optionsButton!.removeFromSuperview()
                    optionsButton = nil
                }
            }
        }
    }
    
    var optionsButtonCallback: ((_ button: UIButton) -> ())?
    
    var showSeparator = true {
        didSet {
            separator.isHidden = !showSeparator
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1, animations: {
                self.contentView.backgroundColor = self.isHighlighted ? kLightBackgroundColor : kBackgroundColor
            }) 
        }
    }
    
    weak var experiment: Experiment? {
        didSet {
            if experiment?.metadataEqual(to: oldValue) != true || (experiment == nil && oldValue == nil) {
                var available = true

                iconView?.removeFromSuperview()

                if let experiment = experiment {
                    titleLabel.text = experiment.localizedTitle
                    subtitleLabel.text = experiment.localizedDescription

                    for sensor in experiment.sensorInputs {
                        do {
                            try sensor.verifySensorAvailibility()
                        }
                        catch SensorError.sensorUnavailable(_) {
                            available = false
                            break
                        }
                        catch {}
                    }

                    let iconView = experiment.icon.generateResizableRepresentativeView()
                    self.iconView = iconView

                    contentView.addSubview(iconView)
                }

                if (available) {
                    titleLabel.textColor = kTextColor
                    subtitleLabel.textColor = kText2Color
                } else {
                    titleLabel.textColor = kTextColorDeactivated
                    subtitleLabel.textColor = kTextColorDeactivated
                }
                
                setNeedsLayout()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline)
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.caption1)
        
        separator.backgroundColor = UIColor.white
        separator.alpha = 0.1
        
        contentView.backgroundColor = kBackgroundColor
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        
        contentView.addSubview(separator)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func optionsButtonPressed(_ button: UIButton) {
        if optionsButtonCallback != nil {
            optionsButtonCallback!(button)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let s1 = CGSize(width: bounds.size.height-4.0, height: bounds.size.height-4.0)
        
        iconView?.frame = CGRect(x: 8.0, y: 2.0, width: s1.width, height: s1.height)
        
        let x = (iconView != nil ? iconView!.frame.maxX : 0.0)
        
        var maxLabelSize = CGSize(width: contentView.bounds.size.width-x-16.0, height: contentView.bounds.height)
        
        if let op = optionsButton {
            let size = CGSize(width: contentView.bounds.height, height: contentView.bounds.height)
            
            op.frame = CGRect(origin: CGPoint(x: self.contentView.bounds.width-size.width, y: (contentView.bounds.height-size.height)/2.0), size: size)
            
            maxLabelSize.width -= size.width+5.0
        }
        
        var s2 = titleLabel.sizeThatFits(maxLabelSize)
        s2.width = min(maxLabelSize.width, s2.width)
        
        titleLabel.frame = CGRect(x: x+8.0, y: 5.0, width: s2.width, height: s2.height)
        
        var s3 = subtitleLabel.sizeThatFits(maxLabelSize)
        s3.width = min(maxLabelSize.width, s3.width)
        
        subtitleLabel.frame = CGRect(x: x+8.0, y: contentView.bounds.size.height-s3.height-5.0, width: s3.width, height: s3.height)
        
        
        
        let separatorHeight = 1.0/UIScreen.main.scale
        
        separator.frame = CGRect(x: x+8.0, y: contentView.bounds.size.height-separatorHeight, width: contentView.bounds.size.width-x-16.0, height: separatorHeight)
        

    }
}
