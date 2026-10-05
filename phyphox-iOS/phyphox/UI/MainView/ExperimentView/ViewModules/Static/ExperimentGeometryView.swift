//
//  ExperimentGeometryView.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

///A single static shape (file format 1.21, phyphox-docs views/drawing.md, "View-Element: geometry"): a rectangle,
///circle, line or ring segment on a transparent background, for gauge faces, needles and range bands. An area shape is
///filled with color and outlined with lineColor, each only when given; a line takes lineColor or falls back to color.
///Colours go through the light-theme adjustment like every colour attribute.
final class ExperimentGeometryView: DrawingBoxView, DescriptorBoundViewModule {
    let descriptor: GeometryViewDescriptor

    required init?(descriptor: GeometryViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        super.init(aspectRatio: descriptor.attributes.aspectRatio)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    ///The path of the shape in the current bounds
    func shapePath() -> UIBezierPath {
        let a = descriptor.attributes
        let path = UIBezierPath()
        switch a.shape {
        case .rectangle:
            let rect = CGRect(x: px(a.left), y: py(a.top), width: px(a.right) - px(a.left), height: py(a.bottom) - py(a.top)).standardized
            //A radius beyond half the shorter side is a stadium, as on Android
            let radius = Swift.max(Swift.min(len(a.cornerRadius), Swift.min(rect.width, rect.height) / 2), 0)
            path.append(UIBezierPath(roundedRect: rect, cornerRadius: radius))
        case .circle:
            let radius = Swift.max(len(a.radius), 0)
            let center = CGPoint(x: px(a.centerX), y: py(a.centerY))
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)))
        case .line:
            path.move(to: CGPoint(x: px(a.startX), y: py(a.startY)))
            path.addLine(to: CGPoint(x: px(a.endX), y: py(a.endY)))
        case .arc:
            let center = CGPoint(x: px(a.centerX), y: py(a.centerY))
            let outer = Swift.max(len(a.radius), 0)
            let inner = Swift.max(Swift.min(len(a.innerRadius), outer), 0)
            if DrawingBoxView.isFullTurn(a.sweepAngle) {
                //A ring (or a disc): two circles, the hole cut out by the fill rule
                path.append(UIBezierPath(ovalIn: CGRect(x: center.x - outer, y: center.y - outer, width: 2 * outer, height: 2 * outer)))
                if inner > 0 {
                    path.append(UIBezierPath(ovalIn: CGRect(x: center.x - inner, y: center.y - inner, width: 2 * inner, height: 2 * inner)))
                }
                path.usesEvenOddFillRule = true
            } else {
                //Outer arc, radial edge, inner arc back (a pie slice when innerRadius is 0), closed
                DrawingBoxView.addArc(to: path, center: center, radius: outer, startAngle: a.startAngle, sweepAngle: a.sweepAngle)
                if inner > 0 {
                    DrawingBoxView.addArc(to: path, center: center, radius: inner, startAngle: a.startAngle + a.sweepAngle, sweepAngle: -a.sweepAngle)
                } else {
                    path.addLine(to: center)
                }
                path.close()
            }
        }
        return path
    }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let a = descriptor.attributes
        let path = shapePath()
        path.lineWidth = Swift.max(len(a.lineWidth), 0)
        path.lineCapStyle = .butt //a line ends exactly at its points

        if a.shape != .line, let color = a.color {
            color.autoLightColor().setFill()
            path.fill()
        }
        let strokeColor = a.lineColor ?? (a.shape == .line ? a.color : nil)
        if let strokeColor = strokeColor, a.lineWidth > 0 {
            strokeColor.autoLightColor().setStroke()
            path.stroke()
        }
    }

    //Nothing to touch: the page scrolls
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

extension ExperimentGeometryView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
