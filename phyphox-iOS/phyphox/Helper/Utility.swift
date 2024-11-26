//
//  Utility.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 17.01.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

class Utility{
    
    public static var DARK_MODE: String  = "1"
    public static var LIGHT_MODE: String  = "2"
    public static var SYSTEM_MODE: String  = "3"

    
    private static func createConfiguredTextView(for text: String) -> UITextView {
            let textView = UITextView()
            textView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.font = UIFont.preferredFont(forTextStyle: .body)
            textView.text = text
            textView.isScrollEnabled = false
            textView.sizeToFit()
            return textView
    }
    
    static func measureHeightOfText(_ text: String) -> CGFloat {
        let textView = createConfiguredTextView(for: text)
        return textView.frame.size.height
    }
        
    static func measureWidthOfText(_ text: String) -> CGFloat {
        let textView = createConfiguredTextView(for: text)
        return textView.frame.size.width
    }
  
    
    
}

