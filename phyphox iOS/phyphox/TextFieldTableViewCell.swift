//
//  TextFieldTableViewCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

private final class InsetTextField: UITextField {
    fileprivate override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 10.0, dy: 5.0)
    }
    
    fileprivate override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 10.0, dy: 5.0)
    }
    
    fileprivate override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: 10.0, dy: 5.0)
    }
}

final class TextFieldTableViewCell: UITableViewCell {
    let textField: UITextField = InsetTextField()
    var editingEndedCallback: (() -> Void)?
    var editingChangedCallback: (() -> Void)?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        textField.addTarget(self, action: #selector(didEndOnExit), for: UIControlEvents(rawValue: UIControlEvents.editingDidEndOnExit.rawValue | UIControlEvents.editingDidEnd.rawValue))
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        
        textField.borderStyle = .none
        contentView.addSubview(textField)
    }
    
    func editingChanged() {
        if editingChangedCallback != nil {
            editingChangedCallback!()
        }
    }
    
    func didEndOnExit() {
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
