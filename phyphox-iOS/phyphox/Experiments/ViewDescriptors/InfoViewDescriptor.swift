//
//  InfoViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

struct InfoViewDescriptor: ViewDescriptor, Equatable {
    let label: String
    let visibilityBuffer: DataBuffer?
    let color: UIColor
    let fontSize: CGFloat
    let align: InfoViewElementDescriptor.TextAlignment
    let bold: Bool
    let italic: Bool
    let translation: ExperimentTranslationCollection?

    init(label: String, visibilityBuffer: DataBuffer?, color: UIColor, fontSize: CGFloat, align: InfoViewElementDescriptor.TextAlignment, bold: Bool, italic: Bool, translation: ExperimentTranslationCollection?) {
        self.label = label
        self.visibilityBuffer = visibilityBuffer
        self.color = color
        self.fontSize = fontSize
        self.align = align
        self.bold = bold
        self.italic = italic
        self.translation = translation
    }

    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size:90%;color:#\(color.hexStringValue!)\" class=\"infoElement adjustableColor\" id=\"element\(id)\"><p>\(localizedLabel)</p></div>"
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        guard let visibilityLabel = visibilityBuffer?.name else {
            return ""
        }
        
        return """
                function (data) { 
                      if (data.hasOwnProperty(\"\(visibilityLabel)\")) {
                      var x = data[\"\(visibilityLabel)\"][\"data\"][data[\"\(visibilityLabel)\"][\"data\"].length-1];
                          var infoElement = document.getElementById(\"element\(id)\");
                          if (x <= 0.0) {
                              infoElement.style.display = \"none\";
                          } else {
                              infoElement.style.display = \"block\";
                          }
                      }
                 }
            """
    }
}
