//
//  Untitled.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 10.02.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

class SpectrumAnalysisConfigurationDialogView: UIView {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let imageView = UIImageView()
    private let firstDescLabel = UILabel()
    private let secondDescLabel = UILabel()
    private var firstToggleButtons: [UIButton] = []
    private var secondToggleButtons: [UIButton] = []
    
    private let dialogImage: UIImage?
    private let firstDescription: String
    private let firstOptions: [String]
    private let secondDescription: String
    private let secondOptions: [String]
    
    private let completion: (Int, Int) -> Void
    
    private var selectedFirstIndex: Int = 0
    private var selectedSecondIndex: Int = 0

    init(image: UIImage?, firstDescription: String, firstOptions: [String], secondDescription: String, secondOptions: [String], initialFirstIndex: Int = 0,
    initialSecondIndex: Int = 0, completion: @escaping (Int, Int) -> Void) {
        self.dialogImage = image
        self.firstDescription = firstDescription
        self.firstOptions = firstOptions
        self.secondDescription = secondDescription
        self.secondOptions = secondOptions
        self.selectedFirstIndex = initialFirstIndex
        self.selectedSecondIndex = initialSecondIndex
        self.completion = completion
        
        super.init(frame: .zero)
        setupViews()
        
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        
        self.addSubview(scrollView)
        scrollView.addSubview(contentView)

        if let img = UIImage(named: getHeaderImageName(orientationIndex: selectedFirstIndex, directionIndex: selectedSecondIndex)) {
            imageView.image = img
            imageView.contentMode = .scaleAspectFit
            contentView.addSubview(imageView)
        }
        
        configureLabel(firstDescLabel, text: firstDescription)
        configureLabel(secondDescLabel, text: secondDescription)
        
        for (idx, option) in firstOptions.enumerated() {
            let btn = createToggleButton(title: option, tag: idx, action: #selector(firstToggleTapped))
            firstToggleButtons.append(btn)
            contentView.addSubview(btn)
        }
        
        for (idx, option) in secondOptions.enumerated() {
            let btn = createToggleButton(title: option, tag: idx, action: #selector(secondToggleTapped))
            secondToggleButtons.append(btn)
            contentView.addSubview(btn)
        }
        
        selectToggle(firstToggleButtons, index: selectedFirstIndex)
        if firstOptions[selectedFirstIndex] == "Vertical" {
            updateSecondOptions(titles: ["Bottom to Top", "Top to Bottom"])
        }
        selectToggle(secondToggleButtons, index: selectedSecondIndex)

    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        scrollView.frame = self.bounds
        
        let contentWidth = bounds.width - 48
        let startX: CGFloat = 24
        var currentY: CGFloat = 16
        let elementSpacing: CGFloat = 20
        let buttonSpacing: CGFloat = 16
        
        let imageSize = 80.0
        if dialogImage != nil {
            imageView.frame = CGRect(x: (bounds.width - imageSize)/2, y: currentY, width: imageSize, height: imageSize)
            currentY = imageView.frame.maxY + elementSpacing
        }
        
        let firstSize = firstDescLabel.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
        firstDescLabel.frame = CGRect(x: startX, y: currentY, width: contentWidth, height: firstSize.height)
        currentY = firstDescLabel.frame.maxY + 12
        
        layoutButtonRow(firstToggleButtons, startY: currentY, startX: startX, spacing: buttonSpacing)
        currentY = (firstToggleButtons.first?.frame.maxY ?? currentY) + elementSpacing
        
        let secondSize = secondDescLabel.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
        secondDescLabel.frame = CGRect(x: startX, y: currentY, width: contentWidth, height: secondSize.height)
        currentY = secondDescLabel.frame.maxY + 12
        
        layoutButtonRow(secondToggleButtons, startY: currentY, startX: startX, spacing: buttonSpacing)
        
        let finalHeight = (secondToggleButtons.first?.frame.maxY ?? currentY) + 16
        
        contentView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: finalHeight)
        scrollView.contentSize = CGSize(width: bounds.width, height: finalHeight)
        
        
    }
    
    private func layoutButtonRow(_ buttons: [UIButton], startY: CGFloat, startX: CGFloat, spacing: CGFloat) {
            var xOffset = startX
            let btnWidth = (bounds.width - 48 - (spacing * CGFloat(buttons.count - 1))) / CGFloat(buttons.count)
            
            for button in buttons {
                button.frame = CGRect(x: xOffset, y: startY, width: btnWidth, height: 45)
                xOffset += btnWidth + spacing
            }
        }
    
    private func configureLabel(_ label: UILabel, text: String) {
            label.text = text
            label.font = .systemFont(ofSize: 16)
            label.numberOfLines = 0
        if(SettingBundleHelper.getAppMode() == Utility.DARK_MODE){
            label.textColor = UIColor.white
        } else{
            label.textColor = .black
        }
        contentView.addSubview(label)
        }
    
    private func createToggleButton(title: String, tag: Int, action: Selector) -> UIButton {
            let button = UIButton(type: .custom)
            button.setTitle(title, for: .normal)
            button.tag = tag
            button.layer.cornerRadius = 8
            button.titleLabel?.font = .systemFont(ofSize: 16)
            button.titleLabel?.backgroundColor = .clear
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.5
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
            button.addTarget(self, action: action, for: .touchUpInside)
            updateToggleAppearance(button)
            return button
        }

    private func selectToggle(_ buttons: [UIButton], index: Int) {
        for (i, button) in buttons.enumerated() {
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
            } else{
                button.setTitleColor(.black, for: .normal)
            }
            
            button.tintColor = .clear
            if(SettingBundleHelper.getAppMode() == Utility.DARK_MODE){
                button.backgroundColor = .darkGray
            } else{
                button.backgroundColor = .lightGray
            }
            
        }
    }
    
    // For now, this is only a placeholder, later other images will replace it.
    func getHeaderImageName(orientationIndex: Int, directionIndex: Int) -> String {
            if orientationIndex == 0 {
                return directionIndex == 0 ? "arrow_gradient_right" : "arrow_gradient_left"
            } else {
                return directionIndex == 0 ? "arrow_gradient_bottom" : "arrow_gradient_top"
            }
        }
    
    private func updateDialogImage() {
        
        let imageName = getHeaderImageName(orientationIndex: selectedFirstIndex, directionIndex: selectedSecondIndex)
        if let newImg = UIImage(named: imageName) {
            self.imageView.image = newImg
        }
    }

    @objc private func firstToggleTapped(_ sender: UIButton) {
        selectedFirstIndex = sender.tag
        selectToggle(firstToggleButtons, index: selectedFirstIndex)
            if firstOptions[selectedFirstIndex] == "Verticle" {
                updateSecondOptions(titles: ["Bottom to Top", "Top to Bottom"])
            } else {
                updateSecondOptions(titles: secondOptions)
            }
        updateDialogImage()
    }
    
    private func updateSecondOptions(titles: [String]) {
        for (idx, button) in secondToggleButtons.enumerated() {
            if idx < titles.count {
                button.setTitle(titles[idx], for: .normal)
                button.isHidden = false
            } else {
                // Hide the button if there are fewer titles than buttons
                button.isHidden = true
            }
        }
        
        setNeedsLayout()
    }

    @objc private func secondToggleTapped(_ sender: UIButton) {
        selectedSecondIndex = sender.tag
        selectToggle(secondToggleButtons, index: selectedSecondIndex)
        updateDialogImage()
    }

    func okTapped() {
        parentViewController().dismiss(animated: true) {
            self.completion(self.selectedFirstIndex, self.selectedSecondIndex)
        }
    }

    @objc private func dismissIfAllowed() {
        parentViewController().dismiss(animated: true)
    }
}

