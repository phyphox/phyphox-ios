//
//  Constants.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreGraphics

func CGRectGetMid(r: CGRect) -> CGPoint {
    return CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r))
}

extension RangeReplaceableCollectionType where Index : Comparable {
    mutating func removeAtIndices<S : SequenceType where S.Generator.Element == Index>(indices: S) {
        indices.sort().lazy.reverse().forEach{ removeAtIndex($0) }
    }
}
