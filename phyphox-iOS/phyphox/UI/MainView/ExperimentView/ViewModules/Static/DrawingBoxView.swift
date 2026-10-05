//
//  DrawingBoxView.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

///The box of a drawing element (geometry, scale; file format 1.21, phyphox-docs views/drawing.md, "Drawing
///coordinates"): the full width and width / aspectRatio tall, the way the stack sizes its children. Positions are
///fractions of the box per axis, lengths fractions of the width, angles radians clockwise from twelve o'clock. Drawing
///outside the box is clipped by the view's bounds; the view redraws when its size changes.
class DrawingBoxView: UIView {
    let aspectRatio: CGFloat

    init(aspectRatio: Double) {
        self.aspectRatio = aspectRatio > 0 && aspectRatio.isFinite ? CGFloat(aspectRatio) : 1
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width.isFinite ? Swift.max(size.width, 0) : 0
        return CGSize(width: width, height: width / aspectRatio)
    }

    ///A horizontal position as a fraction of the width, in points
    func px(_ xFraction: Double) -> CGFloat {
        return CGFloat(xFraction) * bounds.width
    }

    ///A vertical position as a fraction of the height, in points
    func py(_ yFraction: Double) -> CGFloat {
        return CGFloat(yFraction) * bounds.height
    }

    ///A length as a fraction of the width, in points
    func len(_ fraction: Double) -> CGFloat {
        return CGFloat(fraction) * bounds.width
    }

    ///UIBezierPath counts radians clockwise from three o'clock in UIKit's flipped coordinates; the file counts clockwise
    ///from twelve
    static func arcAngle(_ angle: Double) -> CGFloat {
        return CGFloat(angle) - .pi / 2
    }

    ///A full turn or more is a closed circle
    static func isFullTurn(_ sweepAngle: Double) -> Bool {
        return abs(sweepAngle) >= 2 * .pi - 1e-6
    }

    ///The point at the file's angle on a circle: x = cx + r sin θ, y = cy - r cos θ
    static func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        return CGPoint(x: center.x + radius * CGFloat(sin(angle)), y: center.y - radius * CGFloat(cos(angle)))
    }

    ///Appends the arc from startAngle over sweepAngle (clockwise for a positive sweep) to the path
    static func addArc(to path: UIBezierPath, center: CGPoint, radius: CGFloat, startAngle: Double, sweepAngle: Double) {
        path.addArc(withCenter: center, radius: radius, startAngle: arcAngle(startAngle), endAngle: arcAngle(startAngle + sweepAngle), clockwise: sweepAngle >= 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    //The colours follow the theme: a change of the system appearance redraws (autoLightColor reads it)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setNeedsDisplay()
        }
    }
}
