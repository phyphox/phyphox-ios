//
//  GraphDataStatusView.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

//A dimmed note centered in the plot area of a graph that shows nothing, saying why: no data at all, no valid
//point, or none inside the current range. In the last case an arrow next to the text points from the plot centre
//towards the closest valid point. Mirrors Android's GraphView.drawDataStatus.
final class GraphDataStatusView: UIView {
    private(set) var status: GraphDataStatus = .noData
    private(set) var arrowAngle: CGFloat? = nil //Screen angle in radians, nil draws no arrow

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = true
        isUserInteractionEnabled = false
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityIdentifier = "graph.status"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ status: GraphDataStatus, arrowAngle: Double?) {
        self.status = status
        self.arrowAngle = status == .noDataInRange ? arrowAngle.map { CGFloat($0) } : nil
        isHidden = status == .ok
        accessibilityLabel = isHidden ? nil : text
        setNeedsDisplay()
    }

    var text: String {
        switch status {
        case .noValidData: return localize("graph_no_valid_data")
        case .noDataInRange: return localize("graph_no_data_in_range")
        default: return localize("graph_no_data")
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard status != .ok, let context = UIGraphicsGetCurrentContext() else { return }

        //The tic labels' size and colour, dimmed
        let textSize = SettingBundleHelper.getGraphSettingLabelSize() * 0.85
        let color = (UIColor(named: "textColor") ?? .label).withAlphaComponent(0.63)
        let font = UIFont.preferredFont(forTextStyle: .body).withSize(textSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textBounds = string.size()

        let arrowLength = arrowAngle != nil ? textSize * 1.2 : 0
        let gap = arrowAngle != nil ? textSize * 0.5 : 0
        let cx = bounds.midX
        let cy = bounds.midY

        //Text and arrow are centered together
        let textCenterX = cx - (gap + arrowLength) / 2
        string.draw(at: CGPoint(x: textCenterX - textBounds.width / 2, y: cy - textBounds.height / 2))

        if let angle = arrowAngle {
            let ax = textCenterX + textBounds.width / 2 + gap + arrowLength / 2
            let half = arrowLength / 2
            let head = arrowLength * 0.35
            context.saveGState()
            context.translateBy(x: ax, y: cy)
            context.rotate(by: angle)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(textSize * 0.1)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: -half, y: 0))
            context.addLine(to: CGPoint(x: half, y: 0))
            context.move(to: CGPoint(x: half - head, y: -head))
            context.addLine(to: CGPoint(x: half, y: 0))
            context.addLine(to: CGPoint(x: half - head, y: head))
            context.strokePath()
            context.restoreGState()
        }
    }
}
