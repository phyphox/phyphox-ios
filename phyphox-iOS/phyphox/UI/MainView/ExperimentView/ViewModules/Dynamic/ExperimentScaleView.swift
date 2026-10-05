//
//  ExperimentScaleView.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

///The axis of a gauge (file format 1.21, phyphox-docs views/drawing.md, "View-Element: scale"): a straight or circular
///baseline from min to max, major tics, minor tics between them, the values at the tics and a label with a unit. The
///geometry comes from the attributes; min and max may be bound to data containers (the last value replaces the attribute
///while it is finite). With a unit reference the values take part in the unit conversion like a graph axis: the
///positions of min and max stay, the tics are chosen automatically in the displayed unit, and a tap on the label opens
///the unit dialog - also inside a stack, as long as the scale is not wrapped in a transform (ExperimentGroupView offers
///the tap to its untransformed scales). Every other touch is left to the page.
final class ExperimentScaleView: DrawingBoxView, DynamicViewModule, DescriptorBoundViewModule {
    let descriptor: ScaleViewDescriptor

    private let displayLink = DisplayLink(refreshRate: 0)
    private var wantsUpdate = true

    //The unit currently shown (session state, docs/file-format/units.md): the experiment's own unless the Unit system
    //setting or the unit dialog switched it; only meaningful while the descriptor's unit is convertible
    private(set) var displayUnitId: String?

    //The bound containers' last values as read by update(); NaN while a container is empty
    private(set) var boundMin = Double.nan
    private(set) var boundMax = Double.nan

    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }

    required init?(descriptor: ScaleViewDescriptor, resourceFolder: URL?) {
        self.descriptor = descriptor
        super.init(aspectRatio: descriptor.attributes.aspectRatio)

        //The Unit system setting is applied on every load (units.md, "The unit-system setting")
        displayUnitId = descriptor.unit.id
        if let id = descriptor.unit.id, descriptor.isConvertible {
            displayUnitId = Units.forSetting(id, SettingBundleHelper.getUnitSystem())
        }

        for buffer in [descriptor.minBuffer, descriptor.maxBuffer] {
            if let buffer = buffer {
                registerForUpdatesFromBuffer(buffer)
            }
        }
        attachDisplayLink(displayLink)
        readBound()

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Units

    var isConvertible: Bool {
        return descriptor.isConvertible
    }

    ///Whether the scale shows a unit other than the experiment's
    var isConverted: Bool {
        guard isConvertible, let from = descriptor.unit.id, let to = displayUnitId else { return false }
        return to != from
    }

    ///What the unit dialog does: the values in another unit of the same quantity, the geometry stays
    func setDisplayUnit(_ id: String) {
        guard isConvertible, Units.sameQuantity(descriptor.unit.id, id) else { return }
        displayUnitId = id
        setNeedsDisplay()
    }

    ///The symbol in the label: the display unit's, or the experiment's
    var displayUnitSymbol: String {
        if isConverted, let id = displayUnitId {
            return Units.symbol(id)
        }
        return descriptor.unit.symbol
    }

    ///"label (unit)", or either part alone
    var labelText: String {
        let symbol = displayUnitSymbol
        guard descriptor.hasLabel else { return symbol }
        return symbol.isEmpty ? descriptor.localizedLabel : descriptor.localizedLabel + " (" + symbol + ")"
    }

    //A position in the display unit (scale and offset, so a temperature converts with its offset)
    private func toDisplay(_ v: Double) -> Double {
        guard isConverted, let from = descriptor.unit.id, let to = displayUnitId else { return v }
        return Units.convert(v, from: from, to: to)
    }

    private func fromDisplay(_ v: Double) -> Double {
        guard isConverted, let from = descriptor.unit.id, let to = displayUnitId else { return v }
        return Units.convert(v, from: to, to: from)
    }

    // MARK: - Range

    ///The range: the bound container's last value while it is finite, the attribute otherwise
    var effectiveMin: Double {
        return boundMin.isFinite ? boundMin : descriptor.attributes.min
    }

    var effectiveMax: Double {
        return boundMax.isFinite ? boundMax : descriptor.attributes.max
    }

    //Reads the bound containers; true if the range changed
    @discardableResult
    private func readBound() -> Bool {
        func same(_ a: Double, _ b: Double) -> Bool {
            return (a.isNaN && b.isNaN) || a == b
        }
        let m = descriptor.minBuffer?.last ?? .nan
        let M = descriptor.maxBuffer?.last ?? .nan
        let changed = !same(m, boundMin) || !same(M, boundMax)
        boundMin = m
        boundMax = M
        return changed
    }

    func setNeedsUpdate() {
        wantsUpdate = true
    }

    ///Re-ranges from the bound containers, as the display link does
    func update() {
        if readBound() {
            setNeedsDisplay()
        }
    }

    // MARK: - Tics

    ///A tic of the laid-out scale: its value in the experiment's unit, its position along the baseline as a fraction from
    ///min (0) to max (1), whether it is a major tic and the value text shown at it (nil for none)
    struct Tic: Equatable {
        let value: Double
        let fraction: Double
        let major: Bool
        let text: String?
    }

    ///The text size in points: the app's text size scaled by size
    var textSize: CGFloat {
        return UIFont.preferredFont(forTextStyle: .body).pointSize * CGFloat(descriptor.attributes.size)
    }

    ///How many decimals a step needs to be written exactly: 10 -> 0, 0.25 -> 2, 0.1 -> 1 (at most 10)
    static func decimalsFor(step: Double) -> Int {
        guard step > 0 else { return 0 }
        for d in 0..<10 {
            let scaled = step * pow(10, Double(d))
            if abs(scaled - scaled.rounded()) < 1e-6 * Swift.max(1, scaled) {
                return d
            }
        }
        return 10
    }

    ///The number of major tics the automatic step aims at: one per five text heights of baseline, at least two (the
    ///webinterface readme fixes this for the page as well)
    static func maxTicsFor(baseline: Double, textSize: Double) -> Int {
        guard textSize > 0 else { return 2 }
        return Swift.max(2, Int(floor(baseline / (5 * textSize))))
    }

    ///The length of the baseline in points for a box of the given width
    func baselineLength(width: Double) -> Double {
        let a = descriptor.attributes
        if a.shape == .circular {
            return abs(a.sweepAngle) * abs(a.radius) * width
        }
        let dx = (a.endX - a.startX) * width
        let dy = (a.endY - a.startY) * width / (a.aspectRatio > 0 ? a.aspectRatio : 1)
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func formatValue(_ shown: Double, decimals: Int) -> String {
        var shown = shown
        if abs(shown) < pow(10, -Double(decimals)) / 2 {
            shown = 0 //no "-0"
        }
        return String(format: "%.\(decimals)f", shown)
    }

    ///The tics for a box of the given width (drawing.md, "Tics"): in the experiment's unit major tics sit at
    ///min + k * ticStep up to max, or at the nice multiples a graph axis of this length would choose when ticStep is 0;
    ///while another unit is shown the nice multiples are chosen in that unit and placed at the matching positions.
    ///minorTics minor tics divide each step, also between min and the first major tic and after the last one. The values
    ///are formatted with as many decimals as the step needs or with precision (converted by the precision rule).
    func computeTics(width: Double, textSize: Double? = nil) -> [Tic] {
        let a = descriptor.attributes
        var result: [Tic] = []
        let lo = effectiveMin, hi = effectiveMax
        guard lo.isFinite, hi.isFinite, lo != hi else { return result }
        let dir: Double = hi > lo ? 1 : -1
        let converted = isConverted

        var majors: [(value: Double, shown: Double, k: Int)] = []
        let decimals: Int
        let step: Double //between major tics, in the experiment's unit, positive
        let every: Int
        if !converted && a.ticStep > 0 {
            let n = Int(floor(abs(hi - lo) / a.ticStep + 1e-9))
            for k in 0...n {
                let v = lo + dir * Double(k) * a.ticStep
                majors.append((v, v, k))
            }
            decimals = a.precision.map { Swift.max($0, 0) } ?? ExperimentScaleView.decimalsFor(step: a.ticStep)
            step = a.ticStep
            every = a.valueEvery
        } else {
            let dLo = Swift.min(toDisplay(lo), toDisplay(hi)), dHi = Swift.max(toDisplay(lo), toDisplay(hi))
            let maxTics = ExperimentScaleView.maxTicsFor(baseline: baselineLength(width: width), textSize: textSize ?? Double(self.textSize))
            let (dStep, stepPrecision) = ExperimentGraphUtilities.linearTicStep(range: dHi - dLo, maxTics: maxTics)
            let first = ceil(dLo / dStep - 1e-9) * dStep
            var k = 0
            while true {
                let d = first + Double(k) * dStep
                if d > dHi + dStep * 1e-9 {
                    break
                }
                majors.append((fromDisplay(d), d, k))
                k += 1
            }
            var factor = 1.0
            if converted, let from = descriptor.unit.id, let to = displayUnitId {
                factor = Units.scale(from: from, to: to)
            }
            if let precision = a.precision {
                decimals = converted ? Units.precision(precision, factor: factor) : Swift.max(precision, 0)
            } else {
                decimals = Swift.max(stepPrecision, 0)
            }
            step = dStep / factor
            //an explicit valueEvery rhythm describes the experiment's unit; a converted scale labels every tic
            every = converted ? (a.valueEvery > 0 ? 1 : 0) : a.valueEvery
        }

        let span = hi - lo
        for m in majors {
            let showValue = every > 0 && m.k % every == 0
            result.append(Tic(value: m.value, fraction: (m.value - lo) / span, major: true, text: showValue ? ExperimentScaleView.formatValue(m.shown, decimals: decimals) : nil))
        }

        if a.minorTics > 0, let base = majors.first?.value, step > 0 {
            let sub = dir * step / Double(a.minorTics + 1)
            let jA = (lo - base) / sub, jB = (hi - base) / sub
            let jFrom = Int(ceil(Swift.min(jA, jB) - 1e-9)), jTo = Int(floor(Swift.max(jA, jB) + 1e-9))
            if jFrom <= jTo {
                for j in jFrom...jTo where j % (a.minorTics + 1) != 0 {
                    let v = base + Double(j) * sub
                    let f = (v - lo) / span
                    if f < -1e-9 || f > 1 + 1e-9 {
                        continue
                    }
                    result.append(Tic(value: v, fraction: f, major: false, text: nil))
                }
            }
        }
        return result
    }

    // MARK: - Drawing

    private var lineColor: UIColor {
        return (descriptor.attributes.color ?? kFullWhiteColor).autoLightColor()
    }

    private var font: UIFont {
        return UIFont.systemFont(ofSize: textSize)
    }

    ///The point on the baseline at the fraction f from min to max, its outward/right-hand unit normal and the direction
    ///of travel there as a screen angle in radians (clockwise from the x axis)
    private func baselineAt(_ f: Double) -> (point: CGPoint, normal: CGPoint, travel: CGFloat) {
        let a = descriptor.attributes
        if a.shape == .circular {
            let theta = a.startAngle + f * a.sweepAngle
            let center = CGPoint(x: px(a.centerX), y: py(a.centerY))
            let normal = CGPoint(x: CGFloat(sin(theta)), y: CGFloat(-cos(theta)))
            let travel = CGFloat(theta) + (a.sweepAngle < 0 ? .pi : 0)
            return (DrawingBoxView.point(center: center, radius: len(a.radius), angle: theta), normal, travel)
        }
        let start = CGPoint(x: px(a.startX), y: py(a.startY)), end = CGPoint(x: px(a.endX), y: py(a.endY))
        let dx = end.x - start.x, dy = end.y - start.y
        let d = (dx * dx + dy * dy).squareRoot()
        let normal = d > 0 ? CGPoint(x: -dy / d, y: dx / d) : CGPoint(x: 0, y: 1)
        return (CGPoint(x: start.x + CGFloat(f) * dx, y: start.y + CGFloat(f) * dy), normal, atan2(dy, dx))
    }

    ///Text centred on the point, turned by the angle about its centre (positive clockwise on screen)
    private func drawCentredText(_ text: String, at point: CGPoint, angle: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let size = (text as NSString).size(withAttributes: attributes)
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        if angle != 0 {
            context.rotate(by: angle)
        }
        (text as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
        context.restoreGState()
    }

    ///Where the label is drawn in the current bounds, with a slop of half the text size around it; nil without a label
    func labelFrame() -> CGRect? {
        let text = labelText
        guard !text.isEmpty, bounds.width > 0 else { return nil }
        let a = descriptor.attributes
        let size = (text as NSString).size(withAttributes: [.font: font])
        let slop = textSize / 2
        return CGRect(x: px(a.labelPositionX) - size.width / 2 - slop, y: py(a.labelPositionY) - size.height / 2 - slop, width: size.width + 2 * slop, height: size.height + 2 * slop)
    }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let a = descriptor.attributes
        let color = lineColor
        let textAttributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let lineWidth = len(a.lineWidth)
        let lines = lineWidth > 0

        if lines {
            let baseline = UIBezierPath()
            if a.shape == .circular {
                let center = CGPoint(x: px(a.centerX), y: py(a.centerY))
                let radius = len(a.radius)
                if DrawingBoxView.isFullTurn(a.sweepAngle) {
                    baseline.append(UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius)))
                } else {
                    DrawingBoxView.addArc(to: baseline, center: center, radius: radius, startAngle: a.startAngle, sweepAngle: a.sweepAngle)
                }
            } else {
                baseline.move(to: CGPoint(x: px(a.startX), y: py(a.startY)))
                baseline.addLine(to: CGPoint(x: px(a.endX), y: py(a.endY)))
            }
            baseline.lineWidth = lineWidth
            baseline.lineCapStyle = .butt
            color.setStroke()
            baseline.stroke()
        }

        for tic in computeTics(width: Double(bounds.width)) {
            let (p, n, travel) = baselineAt(tic.fraction)
            let length = tic.major ? a.ticLength : a.minorTicLength
            if lines && length != 0 {
                let path = UIBezierPath()
                path.move(to: p)
                path.addLine(to: CGPoint(x: p.x + n.x * len(length), y: p.y + n.y * len(length)))
                path.lineWidth = lineWidth
                path.lineCapStyle = .butt
                color.setStroke()
                path.stroke()
            }
            if let text = tic.text {
                let angle: CGFloat
                switch a.valueOrientation {
                case .upright: angle = 0
                case .tangential: angle = travel
                case .radial: angle = atan2(n.y, n.x)
                }
                drawCentredText(text, at: CGPoint(x: p.x + n.x * len(a.valueDistance), y: p.y + n.y * len(a.valueDistance)), angle: angle, attributes: textAttributes)
            }
        }

        let label = labelText
        if !label.isEmpty {
            drawCentredText(label, at: CGPoint(x: px(a.labelPositionX), y: py(a.labelPositionY)), angle: 0, attributes: textAttributes)
        }
    }

    // MARK: - The tap on the label

    ///Whether the point (in this view's coordinates) is on the label of a convertible scale
    func hitsLabel(_ point: CGPoint) -> Bool {
        guard isConvertible, let frame = labelFrame() else { return false }
        return frame.contains(point)
    }

    ///Opens the unit dialog for the label, as a tap on it does
    func openUnitDialog() {
        guard let id = descriptor.unit.id, isConvertible else { return }
        UnitDialog.show(from: hostingViewController, sourceView: self, sourceRect: labelFrame(), experimentUnitId: id, currentUnitId: displayUnitId ?? id) { [weak self] chosen in
            self?.setDisplayUnit(chosen)
        }
    }

    @objc private func tapped(_ sender: UITapGestureRecognizer) {
        guard hitsLabel(sender.location(in: self)) else { return }
        openUnitDialog()
    }

    //Only the label of a convertible scale answers; everything else is left to the page. In a stack the group asks
    //hitsLabel itself, topmost scale first, so a label under a transformed needle is still reached.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, isUserInteractionEnabled, alpha > 0.01, hitsLabel(point) else { return nil }
        return self
    }
}

extension ExperimentScaleView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate {
            wantsUpdate = false
            update()
        }
    }
}

extension ExperimentScaleView: VisibilityControllableViewModule {
    var visibilityBuffer: DataBuffer? { descriptor.visibilityBuffer }
}
