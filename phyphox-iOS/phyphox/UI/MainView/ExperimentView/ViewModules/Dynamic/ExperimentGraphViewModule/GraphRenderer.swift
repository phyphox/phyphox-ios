//
//  GraphRenderer.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 04.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

// MARK: - Graph Renderer
class GraphRenderer {
    let plotView: GLGraphView
    let gridView: GraphGridView
    let zScaleView: GLGraphView?
    let zGridView: GraphGridView?
    
    private let descriptor: GraphViewDescriptor
    
    var systemTime: Bool = false {
        didSet {
            plotView.systemTime = systemTime
            plotView.timeOnX = descriptor.timeOnX
            plotView.timeOnY = descriptor.timeOnY
            plotView.linearTime = descriptor.linearTime
            plotView.hideTimeMarkers = descriptor.hideTimeMarkers
        }
    }
    
    var hasZData: Bool { return zScaleView != nil }
    
    init(descriptor: GraphViewDescriptor) {
        self.descriptor = descriptor
        
        self.plotView = GLGraphView()
        self.gridView = GraphGridView(descriptor: descriptor, isZScale: false)
        
        if descriptor.style[0] == .map {
            self.zScaleView = GLGraphView()
            self.zGridView = GraphGridView(descriptor: descriptor, isZScale: true)
            setupZScale()
        } else {
            self.zScaleView = nil
            self.zGridView = nil
        }
        
        setupRenderer()
    }
    
    private func setupRenderer() {
        // Setup GL graph configuration
        plotView.style = descriptor.style
        plotView.historyLength = descriptor.history
        plotView.mapWidth = descriptor.mapWidth
        plotView.colorMap = descriptor.colorMap
        //Only the plot itself honours this - the z scale is a gradient by nature
        plotView.interpolateMapColors = descriptor.interpolateMapColors
        plotView.timeOnX = descriptor.timeOnX
        plotView.timeOnY = descriptor.timeOnY
        plotView.systemTime = descriptor.systemTime
        plotView.linearTime = descriptor.linearTime
        plotView.hideTimeMarkers = descriptor.hideTimeMarkers
        
        // Configure grid views
        gridView.gridInset = CGPoint(x: 2.0, y: 2.0)
        gridView.gridOffset = CGPoint(x: 0.0, y: 0)
        gridView.isUserInteractionEnabled = false
        
        zGridView?.gridInset = CGPoint(x: 2.0, y: 2.0)
        zGridView?.gridOffset = CGPoint(x: 0.0, y: 0.0)
        zGridView?.isUserInteractionEnabled = false
        
        updateLineProperties()
    }
    
    private func setupZScale() {
        guard let zScale = zScaleView else { return }
        
        zScale.style = descriptor.style
        zScale.mapWidth = 2
        zScale.colorMap = descriptor.colorMap
        
        // Set dummy points for gradient display
        let x0y0z0 = GraphPoint3D<GLfloat>(x: 0.0, y: 0.0, z: 0.0)
        let x1y0z1 = GraphPoint3D<GLfloat>(x: 1.0, y: 0.0, z: 1.0)
        let x0y1z0 = GraphPoint3D<GLfloat>(x: 0.0, y: 1.0, z: 0.0)
        let x1y1z1 = GraphPoint3D<GLfloat>(x: 1.0, y: 1.0, z: 1.0)
        let min = GraphPoint3D<Double>(x: 0.0, y: 0.0, z: 0.0)
        let max = GraphPoint3D<Double>(x: 1.0, y: 1.0, z: 1.0)
        zScale.setPoints(points2D: [[]], points3D: [[x0y0z0, x1y0z1, x0y1z0, x1y1z1]], min: min, max: max, timeReferenceSets: [[]])
    }
    
    
    func refresh() {
        // Refresh rendering settings based on current configuration
        updateLineProperties()
    }
    
    private func updateLineProperties() {
        plotView.lineWidth = []
        plotView.lineColor = []
        
        for i in 0..<descriptor.yInputBuffers.count {
            let width = Float(descriptor.lineWidth[i] * (descriptor.style[i] == .dots ? 4.0 : SettingBundleHelper.getGraphSettingWidth()))
            plotView.lineWidth.append(width)
            
            var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
            descriptor.color[i].autoLightColor().getRed(&r, green: &g, blue: &b, alpha: &a)
            plotView.lineColor.append(GLcolor(r: Float(r), g: Float(g), b: Float(b), a: Float(a)))
        }
    }
    
    func updateFrames(graphFrame: CGRect, zScaleFrame: CGRect) {
        
        if plotView.frame != graphFrame {
            plotView.frame = graphFrame
            plotView.setNeedsLayout()
        }
        
        if let zScale = zScaleView, let zGrid = zGridView {
           
            if zScale.frame != zScaleFrame {
                zScale.frame = zScaleFrame
                zScale.setNeedsLayout()
            }
            
        }
    }
    
    func clearGraph() {
        plotView.setPoints(points2D: [], points3D: [], min: .zero, max: .zero, timeReferenceSets: [])
        gridView.grid = nil
        gridView.pauseMarkers = nil
        zGridView?.grid = nil
        zGridView?.pauseMarkers = nil
    }
    
    func updateData(_ result: GraphDataResult) {
        gridView.grid = result.grid
        zGridView?.grid = result.grid
        
        let points2D = result.dataSets.map { $0.points2D }
        let points3D = result.dataSets.map { $0.points3D }
        let timeReferenceSets = result.dataSets.map { $0.timeReferenceSets }
        
        plotView.setPoints(
            points2D: points2D,
            points3D: points3D,
            min: result.bounds.min,
            max: result.bounds.max,
            timeReferenceSets: timeReferenceSets
        )
    }
}
