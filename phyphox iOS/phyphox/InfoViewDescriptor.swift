//
//  InfoViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class InfoViewDescriptor: ViewDescriptor {
    
    override func generateViewHTMLWithID(id: Int) -> String {
        return "<div style=\\\"font-size:12;\\\" class=\\\"valueElement\\\" id=\\\"element\(id)\\\"><p>\(localizedLabel)</p></div>"
    }
}
