//
//  InfoViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class InfoViewDescriptor: ViewDescriptor {
    
    override func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size:90%;\" class=\"infoElement\" id=\"element\(id)\"><p>\(localizedLabel)</p></div>"
    }
}
