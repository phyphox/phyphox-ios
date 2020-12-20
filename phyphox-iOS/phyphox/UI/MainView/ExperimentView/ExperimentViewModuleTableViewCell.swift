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
