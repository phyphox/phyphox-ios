//
//  KeyboardTracker.swift
//  phyphox
//
//  Created by Jonas Gessner on 26.02.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import UIKit

final class KeyboardTracker {
    static var keyboardFrame = CGRect.zero

    static func startTracking() {
        NotificationCenter.default.addObserver(self.self, selector: #selector(keyboardFrameWillChange(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self.self, selector: #selector(keyboardFrameDidChange(_:)), name: .UIKeyboardDidChangeFrame, object: nil)
    }

    @objc private static func keyboardFrameWillChange(_ notification: Notification) {
        keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue;
        if (keyboardFrame.isEmpty) {
            keyboardFrame = (notification.userInfo![UIKeyboardFrameBeginUserInfoKey]! as AnyObject).cgRectValue;
        }
    }

    @objc private static func keyboardFrameDidChange(_ notification: Notification) {
        keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue;
    }
}
