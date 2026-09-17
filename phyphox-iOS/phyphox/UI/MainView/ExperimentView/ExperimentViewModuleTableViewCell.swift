//
//  ExperimentViewModuleTableViewCell.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

final class ExperimentViewModuleTableViewCell: UITableViewCell {
    var module: UIView? {
        willSet {
            if newValue !== module, module?.superview === contentView {
                module?.removeFromSuperview()
            }
        }
        
        didSet {
            if module !== oldValue, let module = module {
                contentView.addSubview(module)
                setNeedsLayout() //Adding subview to contentview, so layoutSubviews isn't automatically triggered on self
            }
        }
    }

    //A cell caches its accessibility children once it is configured, so anything a module shows later (a graph's
    //read-out, its pick buttons) stayed invisible to VoiceOver and UI automation. Naming the module as the only element
    //keeps the traversal live; a module hidden by another one's maximized layout is left out.
    override var accessibilityElements: [Any]? {
        get { return module.flatMap { $0.isHidden ? nil : [$0] } }
        set { }
    }

    var topInset: CGFloat = 0.0 {
        didSet {
            setNeedsLayout()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let module = module {
            let size = module.sizeThatFits(self.contentView.bounds.size)

            let effectiveHeight = contentView.bounds.size.height - topInset

            let origin = CGPoint(x: (contentView.bounds.size.width - size.width)/2.0, y: topInset + (effectiveHeight - size.height)/2.0)

            module.frame = CGRect(origin: origin, size: size)
        }
    }
}
