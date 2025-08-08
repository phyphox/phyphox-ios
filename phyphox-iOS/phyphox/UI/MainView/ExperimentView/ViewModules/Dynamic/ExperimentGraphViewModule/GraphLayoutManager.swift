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
    
    private let sideMargins: CGFloat = 10.0
    private let zScaleHeight: CGFloat = 40
    
    var graphFrame: CGRect {
        return gridView.insetRect.offsetBy(dx: gridView.frame.origin.x, dy: gridView.frame.origin.y)
    }
    
    var zScaleFrame: CGRect {
        return zGridView?.insetRect.offsetBy(dx: zGridView!.frame.origin.x, dy: zGridView!.frame.origin.y) ?? .zero
    }
    
    private var showColorScale: Bool {
        return descriptor.showColorScale && descriptor.style[0] == .map
    }
    
    init(descriptor: GraphViewDescriptor, unfoldMoreImageView: UIImageView, unfoldLessImageView: UIImageView, gridView: GraphGridView, zGridView: GraphGridView?) {
        self.descriptor = descriptor
        
        self.unfoldMoreImageView = unfoldMoreImageView
        self.unfoldLessImageView = unfoldLessImageView
        
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
        
        let unfoldRect = CGRect(x: 5, y: 5, width: 20, height: 20)
        unfoldMoreImageView.frame = unfoldRect
        unfoldLessImageView.frame = unfoldRect
        unfoldLessImageView.isHidden = true
        unfoldMoreImageView.isHidden = false
    }
    
    func setupSubviews(renderer: GraphRenderer, markerSystem: GraphMarkerSystem) {
        
        graphArea.addSubview(label)
        graphArea.addSubview(renderer.plotView)
        graphArea.addSubview(renderer.gridView)
        graphArea.addSubview(xLabel)
        graphArea.addSubview(yLabel)
        
        if showColorScale, let zScale = renderer.zScaleView, let zGrid = renderer.zGridView, let zLabel = zLabel {
            graphArea.addSubview(zScale)
            graphArea.addSubview(zGrid)
            graphArea.addSubview(zLabel)
        }
        
        graphArea.addSubview(markerSystem.markerOverlayView)
        
        graphArea.addSubview(unfoldMoreImageView)
        graphArea.addSubview(unfoldLessImageView)
        
        let labelTapGesture = UITapGestureRecognizer(target: self, action: #selector(labelTapTest(_:)))
        label.addGestureRecognizer(labelTapGesture)
    }
    
    // MARK: - Event Handlers
    @objc  func labelTapTest(_ sender: UITapGestureRecognizer) {
        print("labelTapTest", sender.numberOfTapsRequired)
        
    }
    
    func handleResizableStateChange(_ state: ResizableViewModuleState) {
        unfoldMoreImageView.isHidden = (state == .exclusive)
        unfoldLessImageView.isHidden = (state != .exclusive)
        graphArea.isHidden = (state == .hidden)
        
        if state == .normal {
            let unfoldRect = CGRect(x: 5, y: 5, width: 20, height: 20)
            unfoldMoreImageView.frame = unfoldRect
            unfoldLessImageView.frame = unfoldRect
        }
    }
    
    func updateAxisLabels(systemTime: Bool, descriptor: GraphViewDescriptor) {
        if descriptor.timeOnX {
            xLabel.text = systemTime ? descriptor.localizedXLabelWithTimezone : descriptor.localizedXLabelWithUnit
        }
        if descriptor.timeOnY {
            yLabel.text = systemTime ? descriptor.localizedYLabelWithTimezone : descriptor.localizedYLabelWithUnit
        }
    }
    
    func updateMarkerLabel(_ text: String?) {
        if let text = text {
            if markerLabel == nil {
                markerLabel = UILabel()
                markerLabel?.textColor = UIColor(named: "textColor")
                markerLabel?.numberOfLines = 0
                markerLabel?.font = UIFont.preferredFont(forTextStyle: .caption1)
                
                markerLabelFrame = UIView()
                markerLabelFrame?.backgroundColor = UIColor(named: "lightBackgroundColor")
                markerLabelFrame?.layer.cornerRadius = 8.0
                markerLabelFrame?.layer.masksToBounds = true
                markerLabelFrame?.layer.borderWidth = 1.0
                markerLabelFrame?.layer.borderColor = UIColor(named: "separatorColor")?.cgColor
                markerLabelFrame?.addSubview(markerLabel!)
                markerLabelFrame?.isUserInteractionEnabled = false
                graphArea.addSubview(markerLabelFrame!)
            }
            
            markerLabel?.text = text
            let minSize = markerLabel!.sizeThatFits(graphArea.bounds.size)
            markerLabelFrame?.frame = CGRect(x: 0.0, y: 0.0, width: minSize.width + 20.0, height: minSize.height + 20.0)
            markerLabel?.frame = CGRect(x: 10.0, y: 10.0, width: minSize.width, height: minSize.height)
            
        } else if markerLabel != nil {
            markerLabel?.removeFromSuperview()
            markerLabelFrame?.removeFromSuperview()
            markerLabel = nil
            markerLabelFrame = nil
        }
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
            let s1 = label.sizeThatFits(size)
            let s2 = xLabel.sizeThatFits(size)
            let s3 = yLabel.sizeThatFits(size).applying(yLabel.transform)
            
            return CGSize(width: size.width,
                         height: Swift.min((size.width - s3.width - 2 * sideMargins) / descriptor.aspectRatio + s1.height + s2.height + 1.0, size.height))
        }
    }
    
    func layoutSubviews(bounds: CGRect, resizableState: ResizableViewModuleState, toolbar: UITabBar?) {
        
        guard resizableState != .hidden else { return }
        
        let spacing: CGFloat = 1.0
        var bottom: CGFloat = 0.0
        
        // Layout toolbar if in exclusive mode
        if resizableState == .exclusive, let toolbar = toolbar {
            let toolbarSize = toolbar.sizeThatFits(bounds.size)
            toolbar.frame = CGRect(x: 0, y: bounds.height - toolbarSize.height, width: bounds.width, height: toolbarSize.height)
            bottom += toolbarSize.height
        }
        
        graphArea.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - bottom)
        
        // Layout labels
        let s1 = label.sizeThatFits(bounds.size)
        label.frame = CGRect(x: (bounds.width - s1.width) / 2.0, y: spacing, width: s1.width, height: s1.height)
        
        let s2 = xLabel.sizeThatFits(bounds.size)
        let s3 = yLabel.sizeThatFits(bounds.size).applying(yLabel.transform)
        
        xLabel.frame = CGRect(x: (bounds.width + s3.width - s2.width) / 2.0,
                             y: bounds.height - s2.height - spacing - bottom,
                             width: s2.width, height: s2.height)
        
        bottom += s2.height + spacing
        
        if let zLabel = zLabel {
            let s4 = zLabel.sizeThatFits(bounds.size)
            zLabel.frame = CGRect(x: (bounds.width + s3.width - s4.width) / 2.0,
                                 y: s1.height + spacing + zScaleHeight,
                                 width: s4.width, height: s4.height)
        }
        
        let yCoord = s1.height + spacing + (showColorScale ? zScaleHeight + (zLabel?.frame.height ?? 0) + spacing : 0)
        let graphHeight = bounds.height - s1.height - spacing - bottom - (showColorScale ? zScaleHeight + spacing + (zLabel?.frame.height ?? 0) : 0)
        
        gridView.frame = CGRect(x: sideMargins + s3.width + spacing, y: yCoord, width: bounds.width - s3.width - spacing - 2*sideMargins, height:  graphHeight)
        
        if(showColorScale){
            zGridView?.frame = CGRect(x: sideMargins + s3.width + spacing, y: s1.height+spacing, width: bounds.width - s3.width - spacing - 2*sideMargins, height: zScaleHeight)
        }
        
        yLabel.frame = CGRect(x: sideMargins,
                             y: yCoord + (graphHeight - s3.height) / 2.0,
                             width: s3.width, height: s3.height)
    }
}
