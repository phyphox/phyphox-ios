//
//  ExperimentView.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentView: UIView {
    let collections: [ExperimentViewCollection]
    
    init(viewDescriptors: [ExperimentViewDescriptor]) {
        var c: [ExperimentViewCollection] = []
        
        for descriptor in viewDescriptors {
            let v = ExperimentViewCollection(viewDescriptor: descriptor)
            
            c.append(v)
        }
        
        assert(c.count > 0, "No view collectios")
        
        collections = c
        
        super.init(frame: CGRect.zero)
        
        backgroundColor = UIColor.whiteColor()
        
        for v in collections {
            addSubview(v)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
