//
//  ExperimentGraphView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 03.08.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//


protocol GraphGestureDelegate: AnyObject {
    func gestureHandler(_ handler: GraphGestureHandler, didTapAt point: CGPoint)
    func gestureHandler(_ handler: GraphGestureHandler, didPanWithTranslation translation: CGPoint, state: UIGestureRecognizer.State, sender: UIPanGestureRecognizer)
    func gestureHandler(_ handler: GraphGestureHandler, didPinchWithScale scale: CGFloat, state: UIGestureRecognizer.State, center: CGPoint, touches: (CGPoint, CGPoint))
    func gestureHandler(_ handler: GraphGestureHandler, didZPanWithTranslation translation: CGPoint, state: UIGestureRecognizer.State)
    func gestureHandler(_ handler: GraphGestureHandler, didZPinchWithScale scale: CGFloat, state: UIGestureRecognizer.State, center: CGPoint, touches: (CGPoint, CGPoint))
}

class GraphGestureHandler {
    weak var delegate: GraphGestureDelegate?
    
    private var panGestureRecognizer: UIPanGestureRecognizer? = nil
    private var pinchGestureRecognizer: UIPinchGestureRecognizer? = nil
    private var zPanGestureRecognizer: UIPanGestureRecognizer? = nil
    private var zPinchGestureRecognizer: UIPinchGestureRecognizer? = nil
    
    func setupGestures(on graphArea: UIView, plotView: UIView) {
        let plotTapGesture = UITapGestureRecognizer(target: self, action: #selector(plotTapped(_:)))
        plotView.addGestureRecognizer(plotTapGesture)
    }
    
    func handleResizableStateChange(_ state: ResizableViewModuleState, plotView: UIView, zScaleView: UIView?) {
        if state == .exclusive {
            enableInteractiveGestures(plotView: plotView, zScaleView: zScaleView)
        } else {
            disableInteractiveGestures(plotView: plotView, zScaleView: zScaleView)
        }
    }
    
    private func enableInteractiveGestures(plotView: UIView, zScaleView: UIView?) {
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        
        if let pan = panGestureRecognizer { plotView.addGestureRecognizer(pan) }
        if let pinch = pinchGestureRecognizer { plotView.addGestureRecognizer(pinch) }
        
        if let zScale = zScaleView {
            zPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(zPanned(_:)))
            zPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(zPinched(_:)))
            
            if let zPan = zPanGestureRecognizer { zScale.addGestureRecognizer(zPan) }
            if let zPinch = zPinchGestureRecognizer { zScale.addGestureRecognizer(zPinch) }
        }
    }
    
    private func disableInteractiveGestures(plotView: UIView, zScaleView: UIView?) {
        if let pan = panGestureRecognizer { plotView.removeGestureRecognizer(pan) }
        if let pinch = pinchGestureRecognizer { plotView.removeGestureRecognizer(pinch) }
        
        if let zScale = zScaleView {
            if let zPan = zPanGestureRecognizer { zScale.removeGestureRecognizer(zPan) }
            if let zPinch = zPinchGestureRecognizer { zScale.removeGestureRecognizer(zPinch) }
        }
        
        panGestureRecognizer = nil
        pinchGestureRecognizer = nil
        zPanGestureRecognizer = nil
        zPinchGestureRecognizer = nil
    }
    
    
    @objc private func plotTapped(_ sender: UITapGestureRecognizer) {
        delegate?.gestureHandler(self, didTapAt: sender.location(in: sender.view))
    }
    
    @objc private func panned(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: sender.view)
        delegate?.gestureHandler(self, didPanWithTranslation: translation, state: sender.state, sender: sender)
    }
    
    @objc private func pinched(_ sender: UIPinchGestureRecognizer) {
        guard sender.numberOfTouches == 2 else { return }
        
        let touches = (
            sender.location(ofTouch: 0, in: sender.view),
            sender.location(ofTouch: 1, in: sender.view)
        )
        delegate?.gestureHandler(
            self,
            didPinchWithScale: sender.scale,
            state: sender.state,
            center: sender.location(in: sender.view),
            touches: touches
        )
    }
    
    @objc private func zPanned(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: sender.view)
        delegate?.gestureHandler(self, didZPanWithTranslation: translation, state: sender.state)
    }
    
    @objc private func zPinched(_ sender: UIPinchGestureRecognizer) {
        guard sender.numberOfTouches == 2 else { return }
        
        let touches = (
            sender.location(ofTouch: 0, in: sender.view),
            sender.location(ofTouch: 1, in: sender.view)
        )
        delegate?.gestureHandler(
            self,
            didZPinchWithScale: sender.scale,
            state: sender.state,
            center: sender.location(in: sender.view),
            touches: touches
        )
    }
    
}


