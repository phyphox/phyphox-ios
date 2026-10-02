//
//  GraphLayoutManager.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 04.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

// MARK: - Graph Layout Manager
class GraphLayoutManager {
    let graphArea = UIView()

    private let descriptor: GraphViewDescriptor
    private let label = UILabel()
    private let xLabel: UILabel
    private let yLabel: UILabel
    private let zLabel: UILabel?
    private let unfoldMoreImageView: UIImageView
    private let unfoldLessImageView: UIImageView
    let gridView: GraphGridView
    let zGridView: GraphGridView?

    // Marker label for display
    private var markerLabel: UILabel?
    private var markerLabelFrame: UIView?
    var buttonView: UIView?

    //Data picker: one button per pick output, shown with the marker label while a point is selected; set by the graph view
    var pickButtons: [(slot: Int, title: String)] = []
    var onPickButtonTapped: ((Int) -> Void)?
    
    private let sideMargins: CGFloat = 10.0
    private let zScaleHeight: CGFloat = 40

    //The colour scale's plot, kept for the fixed plot area, where it is dropped when the top margin has no room
    private weak var zScaleView: UIView?

    ///Inside a stack: the expand icon is never shown
    var isStatic = false {
        didSet {
            unfoldMoreImageView.isHidden = isStatic || !unfoldLessImageView.isHidden
        }
    }
    
    var graphFrame: CGRect {
        return gridView.insetRect.offsetBy(dx: gridView.frame.origin.x, dy: gridView.frame.origin.y)
    }
    
    var zScaleFrame: CGRect {
        return zGridView?.insetRect.offsetBy(dx: zGridView!.frame.origin.x, dy: zGridView!.frame.origin.y) ?? .zero
    }
    
    private var showColorScale: Bool {
        return descriptor.showColorScale && descriptor.style[0] == .map
    }

    //A graph without a label has no title row (file format 1.21)
    private var hasTitle: Bool {
        return descriptor.hasLabel
    }

    private func titleSize(_ size: CGSize) -> CGSize {
        return hasTitle ? label.sizeThatFits(size) : .zero
    }
    
    init(descriptor: GraphViewDescriptor, gridView: GraphGridView, zGridView: GraphGridView?) {
        self.descriptor = descriptor
        
        let config = UIImage.SymbolConfiguration(pointSize: 25, weight: .regular, scale: .default)
        //The collapse icon of a maximized graph is drawn one and a half times the size of the expand icon (its hit area is
        //the whole margin around the plot, see ExperimentGraphView.handleTapp); the title row grows to hold it
        let exclusiveConfig = UIImage.SymbolConfiguration(pointSize: 38, weight: .regular, scale: .default)
        self.unfoldLessImageView = UIImageView(image: UIImage(systemName: "arrow.down.right.and.arrow.up.left", withConfiguration: exclusiveConfig))
        self.unfoldMoreImageView = UIImageView(image: UIImage(systemName: "arrow.up.left.and.arrow.down.right", withConfiguration: config))
        self.unfoldLessImageView.contentMode = .scaleAspectFit
        
        // Initialize labels
        self.xLabel = Self.makeLabel(descriptor.systemTime ? descriptor.localizedXLabelWithTimezone : descriptor.localizedXLabelWithUnit)
        self.yLabel = Self.makeLabel(descriptor.systemTime ? descriptor.localizedYLabelWithTimezone : descriptor.localizedYLabelWithUnit)
        self.yLabel.transform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi/2.0))
        
        if descriptor.style[0] == .map {
            self.zLabel = Self.makeLabel(descriptor.localizedZLabelWithUnit)
        } else {
            self.zLabel = nil
        }
        self.gridView = gridView
        self.zGridView = zGridView
        
        setupLabels()
    
    }
    
    
    private static func makeLabel(_ text: String?) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.preferredFont(forTextStyle: .body).withSize(SettingBundleHelper.getGraphSettingLabelSize() * 0.8)
        label.textColor = UIColor(named: "textColor")
        return label
    }
    
    private func setupLabels() {
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body).withSize(SettingBundleHelper.getGraphSettingLabelSize())
        label.textColor = UIColor(named: "textColor")
        
        unfoldMoreImageView.frame = GraphLayoutManager.unfoldRect
        unfoldLessImageView.frame = GraphLayoutManager.exclusiveUnfoldRect
        unfoldLessImageView.isHidden = true
        unfoldMoreImageView.isHidden = false
    }

    private static let unfoldRect = CGRect(x: 5, y: 5, width: 20, height: 20)
    private static let exclusiveUnfoldRect = CGRect(x: 5, y: 3, width: 30, height: 30)

    //The title row of a maximized graph is at least as tall as its collapse icon, so the icon never overlaps the plot
    private func titleRowHeight(_ titleHeight: CGFloat, resizableState: ResizableViewModuleState) -> CGFloat {
        return resizableState == .exclusive ? Swift.max(titleHeight, GraphLayoutManager.exclusiveUnfoldRect.maxY + 3) : titleHeight
    }

    //The title is centred; next to the large collapse icon of a maximized graph it starts right of the icon instead
    private func titleFrame(_ size: CGSize, contentWidth: CGFloat, y: CGFloat, resizableState: ResizableViewModuleState) -> CGRect {
        var x = (contentWidth - size.width) / 2.0
        var width = size.width
        if resizableState == .exclusive {
            let minX = unfoldLessImageView.frame.maxX + 5
            if x < minX {
                x = minX
                width = Swift.max(Swift.min(width, contentWidth - minX - 5), 0)
            }
        }
        return CGRect(x: x, y: y, width: width, height: size.height)
    }
    
    func setupSubviews(renderer: GraphRenderer, markerSystem: GraphMarkerSystem) {
        
        graphArea.addSubview(label)
        graphArea.addSubview(renderer.plotView)
        graphArea.addSubview(renderer.gridView)
        graphArea.addSubview(renderer.statusView)
        graphArea.addSubview(xLabel)
        graphArea.addSubview(yLabel)
        
        if showColorScale, let zScale = renderer.zScaleView, let zGrid = renderer.zGridView, let zLabel = zLabel {
            graphArea.addSubview(zScale)
            graphArea.addSubview(zGrid)
            graphArea.addSubview(zLabel)
            zScaleView = zScale
        }
        
        graphArea.addSubview(markerSystem.markerOverlayView)
        
        graphArea.addSubview(unfoldMoreImageView)
        graphArea.addSubview(unfoldLessImageView)
        
    }
    
    
    func handleResizableStateChange(_ state: ResizableViewModuleState) {
        unfoldMoreImageView.isHidden = (state == .exclusive) || isStatic
        unfoldLessImageView.isHidden = (state != .exclusive)
        graphArea.isHidden = (state == .hidden)
        
        if state == .normal {
            unfoldMoreImageView.frame = GraphLayoutManager.unfoldRect
            removeMarkerLabelFrame()
        } else if state == .exclusive {
            unfoldLessImageView.frame = GraphLayoutManager.exclusiveUnfoldRect
        }
    }
    
    //The axis titles: a time axis showing a clock names the time zone, every other axis the unit currently shown
    func updateAxisLabels(systemTime: Bool, units: GraphDisplayUnits) {
        xLabel.text = descriptor.timeOnX && systemTime ? descriptor.localizedXLabelWithTimezone : descriptor.localizedXLabel(withUnit: units.symbols[0])
        yLabel.text = descriptor.timeOnY && systemTime ? descriptor.localizedYLabelWithTimezone : descriptor.localizedYLabel(withUnit: units.symbols[1])
        zLabel?.text = descriptor.localizedZLabel(withUnit: units.symbols[2])
    }

    //The axis titles as drawn (for the tests)
    var xAxisTitle: String? { return xLabel.text }
    var yAxisTitle: String? { return yLabel.text }
    var zAxisTitle: String? { return zLabel?.text }

    func axisLabelView(_ axis: Int) -> UIView? {
        switch axis {
        case 0: return xLabel
        case 1: return yLabel
        default: return zLabel
        }
    }

    //The axis (0 x, 1 y, 2 z) whose title the point (in graphArea coordinates) hits, with some slop around the text
    func axisLabel(at point: CGPoint) -> Int? {
        let slop: CGFloat = 12.0
        for axis in 0..<3 {
            guard let label = axisLabelView(axis), !label.isHidden, label.superview === graphArea else { continue }
            if label.frame.insetBy(dx: -slop, dy: -slop).contains(point) {
                return axis
            }
        }
        return nil
    }
    
    func createMarkerLabelFrame(){
        markerLabelFrame = UIView()
        markerLabelFrame?.backgroundColor = UIColor(named: "lightBackgroundColor")
        markerLabelFrame?.layer.cornerRadius = 8.0
        markerLabelFrame?.layer.masksToBounds = true
        markerLabelFrame?.layer.borderWidth = 1.0
        markerLabelFrame?.layer.borderColor = UIColor(named: "separatorColor")?.cgColor
        markerLabelFrame?.isUserInteractionEnabled = false
        markerLabelFrame?.accessibilityIdentifier = "graph.readout"
    }
    
    func createMarkerLabel(){
        markerLabel = UILabel()
        markerLabel?.textColor = UIColor(named: "textColor")
        markerLabel?.numberOfLines = 0
        markerLabel?.font = UIFont.preferredFont(forTextStyle: .caption1)
    }
    
    func updateMarkerLabel(_ text: String?, graphToolBarState : GraphToolbarManager.GraphMode, showPickButtons: Bool = false) {

        guard let text = text else {
            if markerLabel != nil {
                removeMarkerLabelFrame()
            }
            return
        }

        if markerLabel == nil {
            createMarkerLabel()
            createMarkerLabelFrame()
            markerLabelFrame?.addSubview(markerLabel!)
            graphArea.addSubview(markerLabelFrame!)
        }

        if showPickButtons && !pickButtons.isEmpty {
            if buttonView == nil {
                buttonView = createPickButtons()
                markerLabelFrame?.addSubview(buttonView!)
            }
            markerLabelFrame?.isUserInteractionEnabled = true
        } else {
            buttonView?.removeFromSuperview()
            buttonView = nil
            markerLabelFrame?.isUserInteractionEnabled = false
        }

        markerLabel?.text = text
        //New content after a touch, for assistive technology
        UIAccessibility.post(notification: .layoutChanged, argument: markerLabel)

        let padding = 10.0
        let verticalSpacing = 10.0
        let availableWidth = graphArea.bounds.width * 0.8 // Use 80% of available width
        let contentWidth = availableWidth - (2 * padding)

        let markerLabelSize = markerLabel!.sizeThatFits(graphArea.frame.size)

        let buttonViewSize: CGSize
        if let buttonView = buttonView {
            buttonView.setNeedsLayout()
            buttonView.layoutIfNeeded()
            //Fitting size on both axes, so the box hugs its content
            buttonViewSize = buttonView.systemLayoutSizeFitting(
                CGSize(width: contentWidth, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .fittingSizeLevel,
                verticalFittingPriority: .fittingSizeLevel
            )
        } else {
            buttonViewSize = .zero
        }

        // Calculate the width needed (use the widest element that exists)
        var maxContentWidth = markerLabelSize.width
        if buttonViewSize.width > 0 {
            maxContentWidth = max(maxContentWidth, buttonViewSize.width)
        }

        let frameWidth = min(maxContentWidth + (2 * padding), availableWidth)

        // Calculate total height - only include elements that exist
        var totalHeight = padding + markerLabelSize.height + padding

        if buttonViewSize.height > 0 {
            totalHeight += verticalSpacing + buttonViewSize.height
        }

        // Set markerLabelFrame
        markerLabelFrame?.frame = CGRect(x: 0.0, y: 0.0, width: frameWidth, height: totalHeight)

        var yOffset = padding
        markerLabel?.frame = CGRect(x: padding, y: yOffset, width: frameWidth - (2 * padding), height: markerLabelSize.height)

        if let buttons = buttonView, buttonViewSize.height > 0 {
            yOffset += markerLabelSize.height + verticalSpacing
            buttons.frame = CGRect(x: padding, y: yOffset, width: frameWidth - (2 * padding), height: buttonViewSize.height)
        }
    }

    func removeMarkerLabelFrame(){
        markerLabel?.removeFromSuperview()
        markerLabelFrame?.removeFromSuperview()
        buttonView?.removeFromSuperview()
        markerLabel = nil
        markerLabelFrame = nil
        buttonView = nil
    }
    
    func positionMarkerLabel(averageX: CGFloat, minY: CGFloat, viewBounds: CGSize) {
            guard let markerLabelFrame = markerLabelFrame else { return }
            
            let w = markerLabelFrame.frame.width
            let h = markerLabelFrame.frame.height
            
            let frame = graphFrame
            let x = Swift.min(Swift.max(frame.minX + averageX * frame.width - 0.5 * w, 0), viewBounds.width - w)
            let y = Swift.min(Swift.max(frame.minY + minY * frame.height - h - 15.0, 0), viewBounds.height - h)
            
            markerLabelFrame.frame = CGRect(x: x, y: y, width: w, height: h)
    }
    
    private func createPickButtons() -> UIStackView {

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 4.0

        for (slot, title) in pickButtons {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(UIColor(named: "highlightColor"), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15.0)
            button.tag = slot
            button.addTarget(self, action: #selector(pickButtonTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 90.0).isActive = true
            stackView.addArrangedSubview(button)
        }

        return stackView
    }

    @objc private func pickButtonTapped(_ sender: UIButton) {
        onPickButtonTapped?(sender.tag)
    }


    func refresh() {
        label.font = UIFont.preferredFont(forTextStyle: .body).withSize(SettingBundleHelper.getGraphSettingLabelSize())
        xLabel.font = UIFont.preferredFont(forTextStyle: .body).withSize(SettingBundleHelper.getGraphSettingLabelSize() * 0.8)
        yLabel.font = UIFont.preferredFont(forTextStyle: .body).withSize(SettingBundleHelper.getGraphSettingLabelSize() * 0.8)
    }
    
    func sizeThatFits(_ size: CGSize, resizableState: ResizableViewModuleState) -> CGSize {
        switch resizableState {
        case .exclusive:
            return size
        case .hidden:
            return CGSize(width: 0, height: 0)
        default:
            let s1 = titleSize(size)
            let s2 = xLabel.sizeThatFits(size)
            let s3 = yLabel.sizeThatFits(size).applying(yLabel.transform)
            
            return CGSize(width: size.width,
                         height: Swift.min((size.width - s3.width - 2 * sideMargins) / descriptor.aspectRatio + s1.height + s2.height + 1.0, size.height))
        }
    }
    
    func layoutSubviews(bounds: CGRect, resizableState: ResizableViewModuleState, toolbar: GraphToolbar?) {

        guard resizableState != .hidden else { return }

        let spacing: CGFloat = 1.0
        var bottom: CGFloat = 0.0
        var contentWidth = bounds.width

        // Layout toolbar if in exclusive mode
        if resizableState == .exclusive, let toolbar = toolbar {
            //Landscape: vertical toolbar strip at the right edge so the graph keeps the full height, like on Android
            let isLandscape = bounds.width > bounds.height
            toolbar.vertical = isLandscape
            let toolbarSize = toolbar.sizeThatFits(bounds.size)
            if isLandscape {
                toolbar.frame = CGRect(x: bounds.width - toolbarSize.width, y: 0, width: toolbarSize.width, height: bounds.height)
                contentWidth -= toolbarSize.width
            } else {
                toolbar.frame = CGRect(x: 0, y: bounds.height - toolbarSize.height, width: bounds.width, height: toolbarSize.height)
                bottom += toolbarSize.height
            }
        }

        graphArea.frame = CGRect(x: 0, y: 0, width: contentWidth, height: bounds.height - bottom)

        if let plotArea = descriptor.plotArea {
            layoutFixedPlotArea(plotArea, areaSize: graphArea.frame.size, resizableState: resizableState)
            return
        }
        gridView.fixedInsetRect = nil
        gridView.labelExclusion = .zero
        zScaleView?.isHidden = false
        zGridView?.isHidden = false
        zLabel?.isHidden = false
        label.isHidden = !hasTitle
        xLabel.isHidden = false
        yLabel.isHidden = false

        // Layout labels
        let s1 = titleSize(bounds.size)
        let titleRow = titleRowHeight(s1.height, resizableState: resizableState)
        label.frame = titleFrame(s1, contentWidth: contentWidth, y: spacing + (titleRow - s1.height) / 2.0, resizableState: resizableState)

        let s2 = xLabel.sizeThatFits(bounds.size)
        let s3 = yLabel.sizeThatFits(bounds.size).applying(yLabel.transform)

        xLabel.frame = CGRect(x: (contentWidth + s3.width - s2.width) / 2.0,
                             y: bounds.height - s2.height - spacing - bottom,
                             width: s2.width, height: s2.height)

        bottom += s2.height + spacing

        if let zLabel = zLabel {
            let s4 = zLabel.sizeThatFits(bounds.size)
            zLabel.frame = CGRect(x: (contentWidth + s3.width - s4.width) / 2.0,
                                 y: titleRow + spacing + zScaleHeight,
                                 width: s4.width, height: s4.height)
        }

        let yCoord = titleRow + spacing + (showColorScale ? zScaleHeight + (zLabel?.frame.height ?? 0) + spacing : 0)
        let graphHeight = bounds.height - titleRow - spacing - bottom - (showColorScale ? zScaleHeight + spacing + (zLabel?.frame.height ?? 0) : 0)

        gridView.frame = CGRect(x: sideMargins + s3.width + spacing, y: yCoord, width: contentWidth - s3.width - spacing - 2*sideMargins, height:  graphHeight)

        if(showColorScale){
            zGridView?.frame = CGRect(x: sideMargins + s3.width + spacing, y: titleRow+spacing, width: contentWidth - s3.width - spacing - 2*sideMargins, height: zScaleHeight)
        }

        yLabel.frame = CGRect(x: sideMargins,
                             y: yCoord + (graphHeight - s3.height) / 2.0,
                             width: s3.width, height: s3.height)
    }

    ///plotLeft & co. (file format 1.21, graph.md "Fixing the plot area"): the plot rectangle is pinned to fractions of
    ///the element's box and no longer moves with the tic labels. The labels, tics and the graph's own label are drawn in
    ///the margins that remain and dropped where they do not fit.
    private func layoutFixedPlotArea(_ plotArea: GraphViewDescriptor.PlotArea, areaSize: CGSize, resizableState: ResizableViewModuleState) {
        let spacing: CGFloat = 1.0
        let w = areaSize.width
        let h = areaSize.height
        let plot = CGRect(x: plotArea.left * w, y: plotArea.top * h,
                          width: Swift.max((plotArea.right - plotArea.left) * w, 0), height: Swift.max((plotArea.bottom - plotArea.top) * h, 0))

        gridView.frame = CGRect(origin: .zero, size: areaSize)
        gridView.fixedInsetRect = plot

        //The graph's label sits in the top margin, the colour scale below it, both only where they fit
        let s1 = titleSize(areaSize)
        var top: CGFloat = 0
        label.isHidden = !hasTitle || s1.height > plot.minY
        if !label.isHidden {
            label.frame = titleFrame(s1, contentWidth: w, y: spacing, resizableState: resizableState)
            top = s1.height + spacing
        }
        if showColorScale, let zGrid = zGridView, let zLabel = zLabel {
            let s4 = zLabel.sizeThatFits(areaSize)
            let fits = top + zScaleHeight + s4.height + spacing <= plot.minY
            zGrid.isHidden = !fits
            zScaleView?.isHidden = !fits
            zLabel.isHidden = !fits
            if fits {
                zGrid.frame = CGRect(x: plot.minX, y: top, width: plot.width, height: zScaleHeight)
                zLabel.frame = CGRect(x: plot.midX - s4.width / 2.0, y: top + zScaleHeight, width: s4.width, height: s4.height)
            }
        }

        //The axis labels at the outer edges; the tic labels between them and the plot, dropped where the space is gone
        let s2 = xLabel.sizeThatFits(areaSize)
        let s3 = yLabel.sizeThatFits(areaSize).applying(yLabel.transform)
        var exclusion = UIEdgeInsets.zero
        xLabel.isHidden = s2.height + spacing > h - plot.maxY
        if !xLabel.isHidden {
            xLabel.frame = CGRect(x: plot.midX - s2.width / 2.0, y: h - s2.height - spacing, width: s2.width, height: s2.height)
            exclusion.bottom = s2.height + spacing
        }
        yLabel.isHidden = s3.width + spacing > plot.minX
        if !yLabel.isHidden {
            yLabel.frame = CGRect(x: spacing, y: plot.midY - s3.height / 2.0, width: s3.width, height: s3.height)
            exclusion.left = s3.width + spacing
        }
        gridView.labelExclusion = exclusion
    }
}
