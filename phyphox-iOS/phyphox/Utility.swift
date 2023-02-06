//
//  Utility.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 17.01.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

class Utility{
    
    static  func measureHeightofUILabelOnString(line: String) -> CGFloat {
        let textView = UITextView()
        let maxwidth = UIScreen.main.bounds.width
        textView.frame = CGRect(x:0,y: 0,width: maxwidth,height: CGFloat(MAXFLOAT))
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.text = line
        textView.isScrollEnabled = false
        textView.sizeToFit()
        return textView.frame.size.height
    }
    
}

