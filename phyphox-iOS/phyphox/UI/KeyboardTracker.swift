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
        NotificationCenter.default.addObserver(self.self, selector: #selector(keyboardFrameWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self.self, selector: #selector(keyboardFrameDidChange(_:)), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
    }

    @objc private static func keyboardFrameWillChange(_ notification: Notification) {
        keyboardFrame = (notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue;
        if (keyboardFrame.isEmpty) {
            keyboardFrame = (notification.userInfo![UIResponder.keyboardFrameBeginUserInfoKey]! as AnyObject).cgRectValue;
        }
    }

    @objc private static func keyboardFrameDidChange(_ notification: Notification) {
        keyboardFrame = (notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue;
    }
}
