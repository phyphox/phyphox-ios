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
    private override func editingRectForBounds(bounds: CGRect) -> CGRect {
        return CGRectInset(bounds, 10.0, 5.0)
    }
    
    private override func textRectForBounds(bounds: CGRect) -> CGRect {
        return CGRectInset(bounds, 10.0, 5.0)
    }
    
    private override func placeholderRectForBounds(bounds: CGRect) -> CGRect {
        return CGRectInset(bounds, 10.0, 5.0)
    }
}

final class TextFieldTableViewCell: UITableViewCell {
    let textField: UITextField = InsetTextField()
    var editingEndedCallback: (() -> Void)?
    var editingChangedCallback: (() -> Void)?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        textField.addTarget(self, action: #selector(didEndOnExit), forControlEvents: UIControlEvents(rawValue: UIControlEvents.EditingDidEndOnExit.rawValue | UIControlEvents.EditingDidEnd.rawValue))
        textField.addTarget(self, action: #selector(editingChanged), forControlEvents: .EditingChanged)
        
        textField.borderStyle = .None
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
