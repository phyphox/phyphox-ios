//
//  WhiteBalanceControlView.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

//The camera-gui's white balance control at exposure adjustment level 3 (file format 1.21, phyphox-docs
//docs/file-format/input.md "White balance"): automatic, locked, or a colour temperature on a logarithmic scale with a
//Duv tint adjustment. No named presets. Rows under the preview in portrait, columns beside the main controls in
//fullscreen landscape (vertical), as on Android.
final class WhiteBalanceControlView: UIView {
    static let rowHeight: CGFloat = 30.0
    static let horizontalHeight: CGFloat = 3.0 * rowHeight //the toggle and the two slider rows
    static let verticalWidth: CGFloat = 200.0
    private static let labelWidth: CGFloat = 72.0
    //The tint slider runs over whole thousandths of Duv
    private static let tintSteps = Float(WhiteBalance.maxTint * 1000.0)

    private let settings: CameraSettingsModel

    let modeControl: UISegmentedControl
    let temperatureLabel: UILabel
    let temperatureSlider = UISlider()
    let tintLabel: UILabel
    let tintSlider = UISlider()

    var vertical = false {
        didSet {
            setNeedsLayout()
        }
    }

    init(settings: CameraSettingsModel) {
        self.settings = settings
        modeControl = UISegmentedControl(items: [localize("wb_auto"), localize("wb_locked"), localize("wb_temperature")])
        temperatureLabel = WhiteBalanceControlView.makeLabel()
        tintLabel = WhiteBalanceControlView.makeLabel()
        super.init(frame: .zero)

        modeControl.selectedSegmentTintColor = UIColor(named: "highlightColor")
        modeControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor(named: "textColor") ?? .white], for: .normal)
        modeControl.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor(named: "textColorInsideButton") ?? .black], for: .selected)
        modeControl.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)

        temperatureSlider.minimumValue = 0.0
        temperatureSlider.maximumValue = 1.0
        temperatureSlider.thumbTintColor = UIColor(named: "highlightColor")
        temperatureSlider.addTarget(self, action: #selector(temperatureChanged(_:)), for: .valueChanged)

        tintSlider.minimumValue = -WhiteBalanceControlView.tintSteps
        tintSlider.maximumValue = WhiteBalanceControlView.tintSteps
        tintSlider.thumbTintColor = UIColor(named: "highlightColor")
        tintSlider.addTarget(self, action: #selector(tintChanged(_:)), for: .valueChanged)

        modeControl.accessibilityIdentifier = "whiteBalanceMode"
        temperatureSlider.accessibilityIdentifier = "whiteBalanceTemperature"
        tintSlider.accessibilityIdentifier = "whiteBalanceTint"

        for view in [modeControl, temperatureLabel, temperatureSlider, tintLabel, tintSlider] {
            addSubview(view)
        }
        update()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func makeLabel() -> UILabel {
        let label = UILabel()
        label.textColor = UIColor(named: "textColor")
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }

    //Reflects the state; setting a slider's value or the selected segment programmatically fires no action
    func update() {
        let selected: Int
        switch settings.whiteBalanceMode {
        case .auto: selected = 0
        case .locked: selected = 1
        case .temperature: selected = 2
        }
        if modeControl.selectedSegmentIndex != selected {
            modeControl.selectedSegmentIndex = selected
        }
        let temperatureMode = settings.whiteBalanceMode == .temperature
        for view in [temperatureLabel, temperatureSlider, tintLabel, tintSlider] {
            view.isHidden = !temperatureMode
        }
        temperatureLabel.text = "\(settings.whiteBalanceTemperatureInEffect) K"
        temperatureSlider.value = WhiteBalance.position(ofTemperature: settings.whiteBalanceTemperatureInEffect, range: settings.whiteBalanceTemperatureRange)
        tintLabel.text = localize("wb_tint") + " " + WhiteBalance.formatTint(settings.whiteBalanceTintInEffect)
        tintSlider.value = min(max(-WhiteBalanceControlView.tintSteps, (settings.whiteBalanceTintInEffect * 1000.0).rounded()), WhiteBalanceControlView.tintSteps)
    }

    @objc private func modeChanged(_ sender: UISegmentedControl) {
        let mode: WhiteBalanceMode
        switch sender.selectedSegmentIndex {
        case 1: mode = .locked
        case 2: mode = .temperature
        default: mode = .auto
        }
        if mode != settings.whiteBalanceMode {
            settings.service?.setWhiteBalanceMode(mode)
        }
    }

    @objc private func temperatureChanged(_ sender: UISlider) {
        settings.service?.setWhiteBalanceTemperature(WhiteBalance.temperature(atPosition: sender.value, range: settings.whiteBalanceTemperatureRange))
    }

    @objc private func tintChanged(_ sender: UISlider) {
        settings.service?.setWhiteBalanceTint(sender.value.rounded() / 1000.0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let row = WhiteBalanceControlView.rowHeight
        if vertical {
            //The toggle on top, below it the two scales as columns with their label above a vertical slider
            modeControl.frame = CGRect(x: 0, y: 0, width: bounds.width, height: row - 2)
            let columnWidth = bounds.width / 2
            let top = row
            let length = max(bounds.height - top - 20, 0)
            for (column, pair) in [(temperatureLabel, temperatureSlider), (tintLabel, tintSlider)].enumerated() {
                let x = CGFloat(column) * columnWidth
                pair.0.frame = CGRect(x: x, y: top, width: columnWidth, height: 20)
                pair.1.transform = .identity
                pair.1.bounds = CGRect(x: 0, y: 0, width: length, height: row)
                pair.1.transform = CGAffineTransform(rotationAngle: -.pi / 2)
                pair.1.center = CGPoint(x: x + columnWidth / 2, y: top + 20 + length / 2)
            }
        } else {
            let toggleWidth = min(bounds.width, 280.0)
            modeControl.frame = CGRect(x: (bounds.width - toggleWidth) / 2, y: 1, width: toggleWidth, height: row - 2)
            for (index, pair) in [(temperatureLabel, temperatureSlider), (tintLabel, tintSlider)].enumerated() {
                let y = CGFloat(index + 1) * row
                pair.0.frame = CGRect(x: 0, y: y, width: WhiteBalanceControlView.labelWidth, height: row)
                pair.1.transform = .identity
                pair.1.frame = CGRect(x: WhiteBalanceControlView.labelWidth, y: y, width: bounds.width - WhiteBalanceControlView.labelWidth, height: row)
            }
        }
    }
}
