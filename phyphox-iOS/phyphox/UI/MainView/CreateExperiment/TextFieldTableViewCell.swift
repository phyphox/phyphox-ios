//
//  TextFieldTableViewCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

private final class InsetTextField: UITextField {
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 10.0, dy: 5.0)
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 10.0, dy: 5.0)
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 10.0, dy: 5.0)
    }
}

final class TextFieldTableViewCell: UITableViewCell {
    let textField: UITextField = InsetTextField()
    var editingEndedCallback: (() -> Void)?
    var editingChangedCallback: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        textField.addTarget(self, action: #selector(didEndOnExit), for: UIControl.Event(rawValue: UIControl.Event.editingDidEndOnExit.rawValue | UIControl.Event.editingDidEnd.rawValue))
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        
        textField.borderStyle = .none
        contentView.addSubview(textField)
    }
    
    @objc func editingChanged() {
        if editingChangedCallback != nil {
            editingChangedCallback!()
        }
    }
    
    @objc func didEndOnExit() {
        if editingEndedCallback != nil {
            editingEndedCallback!()
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        textField.frame = contentView.bounds
    }
}
