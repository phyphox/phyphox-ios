//
//  SpectrumAnalysisConfigurationDialogView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 10.02.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

//Accessory view for the spectrum analysis settings dialog: an image illustrating the currently
//selected option above a description and a row of toggle buttons. A change of the selection is
//reported (and applied) immediately, like on Android; the dialog's OK button only dismisses.
class SpectrumAnalysisConfigurationDialogView: UIView {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let imageView = UIImageView()
    private let descLabel = UILabel()
    private var toggleButtons: [UIButton] = []

    private let imageForIndex: (Int) -> UIImage?
    private let selectionChanged: (Int) -> Void

    private var selectedIndex: Int

    init(description: String, options: [String], initialIndex: Int,
         imageForIndex: @escaping (Int) -> UIImage?, selectionChanged: @escaping (Int) -> Void) {
        self.imageForIndex = imageForIndex
        self.selectionChanged = selectionChanged
        self.selectedIndex = initialIndex

        super.init(frame: .zero)
        setupViews(description: description, options: options)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(description: String, options: [String]) {

        self.addSubview(scrollView)
        scrollView.addSubview(contentView)

        imageView.image = imageForIndex(selectedIndex)
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)

        descLabel.text = description
        descLabel.font = .systemFont(ofSize: 16)
        descLabel.numberOfLines = 0
        descLabel.textColor = UIColor(named: "textColor")
        contentView.addSubview(descLabel)

        for (idx, option) in options.enumerated() {
            let btn = createToggleButton(title: option, tag: idx)
            toggleButtons.append(btn)
            contentView.addSubview(btn)
        }

        selectToggle(index: selectedIndex)
    }

    override var intrinsicContentSize: CGSize {
        //The alert controller sizes its accessory to this height. Its actual width is not known
        //at this point, so the typical alert content width is assumed for the label wrapping.
        let assumedWidth: CGFloat = 270
        let descHeight = descLabel.sizeThatFits(CGSize(width: assumedWidth - 48, height: .greatestFiniteMagnitude)).height
        return CGSize(width: UIView.noIntrinsicMetric, height: 16 + 100 + 20 + descHeight + 12 + 45 + 16)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.frame = self.bounds

        let contentWidth = bounds.width - 48
        let startX: CGFloat = 24
        var currentY: CGFloat = 16
        let elementSpacing: CGFloat = 20
        let buttonSpacing: CGFloat = 16

        let imageHeight = 100.0
        let imageWidth = imageHeight * (imageView.image.map { $0.size.width / $0.size.height } ?? 1.0)
        imageView.frame = CGRect(x: (bounds.width - imageWidth)/2, y: currentY, width: imageWidth, height: imageHeight)
        currentY = imageView.frame.maxY + elementSpacing

        let descSize = descLabel.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
        descLabel.frame = CGRect(x: startX, y: currentY, width: contentWidth, height: descSize.height)
        currentY = descLabel.frame.maxY + 12

        var xOffset = startX
        let btnWidth = (bounds.width - 48 - (buttonSpacing * CGFloat(toggleButtons.count - 1))) / CGFloat(toggleButtons.count)
        for button in toggleButtons {
            button.frame = CGRect(x: xOffset, y: currentY, width: btnWidth, height: 45)
            xOffset += btnWidth + buttonSpacing
        }

        let finalHeight = (toggleButtons.first?.frame.maxY ?? currentY) + 16

        contentView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: finalHeight)
        scrollView.contentSize = CGSize(width: bounds.width, height: finalHeight)

    }

    private func createToggleButton(title: String, tag: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.tag = tag
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.titleLabel?.backgroundColor = .clear
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.5
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        button.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        updateToggleAppearance(button)
        return button
    }

    private func selectToggle(index: Int) {
        for (i, button) in toggleButtons.enumerated() {
            button.isSelected = (i == index)
            updateToggleAppearance(button)
        }
    }

    private func updateToggleAppearance(_ button: UIButton) {
        if button.isSelected {
            button.backgroundColor = UIColor(named: "highlightColor")
            button.setTitleColor(.white, for: .normal)
            button.setTitleColor(.white, for: .selected)
            button.tintColor = .clear
        } else {
            if(SettingBundleHelper.getAppMode() == Utility.DARK_MODE){
                button.setTitleColor(.white, for: .normal)
                button.backgroundColor = .darkGray
            } else{
                button.setTitleColor(.black, for: .normal)
                button.backgroundColor = .lightGray
            }
            button.tintColor = .clear
        }
    }

    @objc private func toggleTapped(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        selectedIndex = sender.tag
        selectToggle(index: selectedIndex)
        imageView.image = imageForIndex(selectedIndex)
        setNeedsLayout()
        selectionChanged(selectedIndex)
    }
}
