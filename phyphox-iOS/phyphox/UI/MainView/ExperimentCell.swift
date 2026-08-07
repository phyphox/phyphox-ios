//
//  ExperimentCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit
import BEMCheckBox

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
                    optionsButton!.setImage(generateDots(15.0), for: UIControl.State())
                    optionsButton!.accessibilityLabel = localize("actions")
                    optionsButton!.addTarget(self, action: #selector(optionsButtonPressed(_:)), for: .touchUpInside)
                    contentView.addSubview(optionsButton!)
                }
                guard let optionsButton = optionsButton else {
                    return
                }
            
                let color = kTextColor.autoLightColor()
                optionsButton.setTintColor(color, for: UIControl.State())
                optionsButton.setTintColor(color.interpolating(to: UIColor.black, byFraction: 0.5), for: .highlighted)
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

    //Multi-select deletion: while the experiment list is in selection mode, deletable
    //experiments show a checkbox instead of the options button. The checkbox only displays the
    //state, toggling happens by tapping the cell.
    private var selectionCheckbox: BEMCheckBox?

    var showsSelectionCheckbox = false {
        didSet {
            if showsSelectionCheckbox {
                if selectionCheckbox == nil {
                    let checkbox = BEMCheckBox()
                    checkbox.boxType = .square
                    checkbox.offAnimationType = .bounce
                    checkbox.onAnimationType = .bounce
                    checkbox.lineWidth = 1.0
                    checkbox.onTintColor = kHighlightColor
                    checkbox.onCheckColor = kHighlightColor
                    checkbox.isUserInteractionEnabled = false
                    selectionCheckbox = checkbox
                    contentView.addSubview(checkbox)
                }
            } else {
                selectionCheckbox?.removeFromSuperview()
                selectionCheckbox = nil
            }
            //The checkbox shifts the whole content, so the layout must be recomputed even when
            //the reused cell shows the same experiment as before (whose setter skips the layout
            //invalidation when the metadata is unchanged)
            setNeedsLayout()
        }
    }

    var selectionChecked = false {
        didSet {
            selectionCheckbox?.on = selectionChecked
        }
    }

    var showSeparator = true {
        didSet {
            separator.isHidden = !showSeparator
        }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1, animations: {
                self.contentView.backgroundColor = self.isHighlighted ? UIColor(named: "lightBackgroundColor") : UIColor(named: "mainBackground")
            })
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        //In selection mode the checkbox is inserted at the leading edge, pushing icon and labels
        //to the right - the indentation makes the deletable experiments easy to spot, like on
        //Android
        var leadingInset: CGFloat = 0.0
        if let checkbox = selectionCheckbox {
            let boxSize: CGFloat = 24.0
            let slot: CGFloat = 40.0
            checkbox.frame = CGRect(x: (slot-boxSize)/2.0, y: (contentView.bounds.height-boxSize)/2.0, width: boxSize, height: boxSize)
            leadingInset = slot
        }

        let s1 = CGSize(width: bounds.size.height-4.0, height: bounds.size.height-4.0)

        iconView?.frame = CGRect(x: 8.0 + leadingInset, y: 2.0, width: s1.width, height: s1.height)

        let x = (iconView != nil ? iconView!.frame.maxX : leadingInset)
        
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.caption1)
        
        separator.backgroundColor = UIColor.white
        separator.alpha = 0.1
        
        contentView.backgroundColor =  UIColor(named: "mainBackground")
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        
        contentView.addSubview(separator)
    }
    
    weak var experiment: Experiment? {
        didSet {
            if experiment?.metadataEqual(to: oldValue) != true || (experiment == nil && oldValue == nil) {
                var available = true

                iconView?.removeFromSuperview()

                if let experiment = experiment {
                    titleLabel.text = experiment.displayTitle
                    if experiment.isLink {
                        subtitleLabel.text = "Link: \(experiment.localizedLinks.first?.url.absoluteString ?? "Invalid")"
                    } else if experiment.stateTitle != nil {
                        subtitleLabel.text = experiment.localizedTitle
                    } else {
                        subtitleLabel.text = experiment.localizedDescription
                    }
                    
                    if experiment.appleBan || experiment.invalid {
                        available = false
                    }

                    for sensor in experiment.sensorInputs {
                        do {
                            if !sensor.ignoreUnavailable {
                                try sensor.verifySensorAvailibility()
                            }
                        }
                        catch SensorError.sensorUnavailable(_) {
                            available = false
                            break
                        }
                        catch {}
                    }
                    
                    if experiment.cameraInput != nil {
                        do {
                            try ExperimentCameraInput.verifySensorAvaibility()
                        }
                        catch CameraInputError.sensorUnavailable {
                            available = false
                        }
                        catch {}
                    }
                    
                    if experiment.depthInput != nil {
                        do {
                            try ExperimentDepthInput.verifySensorAvailibility(cameraOrientation: nil)
                        }
                        catch DepthInputError.sensorUnavailable {
                            available = false
                        }
                        catch {}
                    }

                    let iconView = experiment.icon.generateResizableRepresentativeView(color: experiment.color, fontColor: experiment.color.overlayTextColor())
                    self.iconView = iconView

                    contentView.addSubview(iconView)
                }

                if (available) {
                    titleLabel.textColor = UIColor(named: "textColor")
                    subtitleLabel.textColor = UIColor(named: "textSecondaryColor")
                } else {
                    titleLabel.textColor = UIColor(named: "textColorDeactivated")
                    subtitleLabel.textColor = UIColor(named: "textColorDeactivated")
                }
                
                setNeedsLayout()
            }
        }
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
    
    
}
