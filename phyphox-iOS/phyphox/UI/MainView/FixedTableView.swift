//
//  FixedTableView.swift
//  phyphox
//
//  Created by Sebastian Staacks on 13.03.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

//This is a slight modification of UITableView for fixed size usage. It always reports its content size as intrinsic content size
final class FixedTableView: UITableView {
    
    override func reloadData() {
        super.reloadData()
        self.invalidateIntrinsicContentSize()
        self.layoutIfNeeded()
    }
    
    override var intrinsicContentSize: CGSize {
        self.layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }
}
