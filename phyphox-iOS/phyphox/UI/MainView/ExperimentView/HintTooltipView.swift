//
//  HintTooltipView.swift
//  phyphox
//
//  Created by Sebastian Staacks on 29.05.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation
import UIKit

/// A small coach-mark bubble with an upward pointer, shown below the navigation bar to point at a
/// top-bar button. It replaces the UIPopover-based hint for the experiment page: iOS 26 renders a
/// popover anchored to a bar button item as a glass bubble placed over the very button it is meant
/// to indicate, so the hint covered its target. This view is a plain subview we position ourselves,
/// so it can never cover the bar.
class HintTooltipView: UIView {
    private let bubble = UIView()
    private let label = UILabel()
    private let pointerLayer = CAShapeLayer()
    private let onDismiss: () -> Void
    private let pointsDown: Bool

    private let pointerHeight: CGFloat = 9
    private let pointerHalfWidth: CGFloat = 9
    private let hInset: CGFloat = 14
    private let vInset: CGFloat = 10
    private let cornerRadius: CGFloat = 12

    /// Horizontal position, in this view's coordinate space, the pointer tip should aim at.
    var pointerX: CGFloat = 0 { didSet { setNeedsLayout() } }

    /// `pointsDown` puts the pointer at the bottom (bubble above it) for hints that point at
    /// something below them, e.g. the support options at the end of the experiment list.
    init(text: String, pointsDown: Bool = false, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.pointsDown = pointsDown
        super.init(frame: .zero)
        backgroundColor = .clear

        bubble.backgroundColor = namedColors["blue"]
        bubble.layer.cornerRadius = cornerRadius
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOpacity = 0.25
        bubble.layer.shadowRadius = 6
        bubble.layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(bubble)

        pointerLayer.fillColor = namedColors["blue"]?.cgColor
        layer.addSublayer(pointerLayer)

        label.text = text
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.font = UIFont.preferredFont(forTextStyle: .callout)
        label.textColor = kTextColor
        bubble.addSubview(label)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Total size (pointer + bubble) needed to lay the text out within the given maximum width.
    func fittingSize(maxWidth: CGFloat) -> CGSize {
        let textSize = label.sizeThatFits(CGSize(width: maxWidth - 2 * hInset, height: 2000))
        let bubbleW = ceil(textSize.width) + 2 * hInset
        let bubbleH = ceil(textSize.height) + 2 * vInset
        return CGSize(width: bubbleW, height: bubbleH + pointerHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        bubble.frame = CGRect(x: 0, y: pointsDown ? 0 : pointerHeight, width: bounds.width, height: bounds.height - pointerHeight)
        label.frame = bubble.bounds.insetBy(dx: hInset, dy: vInset)

        //Keep the whole pointer base on the straight part of the edge, clear of the rounded corners.
        let tipInset = cornerRadius + pointerHalfWidth
        let tip = max(tipInset, min(pointerX, bounds.width - tipInset))
        let path = UIBezierPath()
        if pointsDown {
            let baseY = bounds.height - pointerHeight - 1
            path.move(to: CGPoint(x: tip, y: bounds.height))
            path.addLine(to: CGPoint(x: tip - pointerHalfWidth, y: baseY))
            path.addLine(to: CGPoint(x: tip + pointerHalfWidth, y: baseY))
        } else {
            path.move(to: CGPoint(x: tip, y: 0))
            path.addLine(to: CGPoint(x: tip - pointerHalfWidth, y: pointerHeight + 1))
            path.addLine(to: CGPoint(x: tip + pointerHalfWidth, y: pointerHeight + 1))
        }
        path.close()
        pointerLayer.frame = bounds
        pointerLayer.path = path.cgPath
    }

    @objc private func handleTap() { dismissTooltip() }

    func dismissTooltip() {
        removeFromSuperview()
        onDismiss()
    }
}
