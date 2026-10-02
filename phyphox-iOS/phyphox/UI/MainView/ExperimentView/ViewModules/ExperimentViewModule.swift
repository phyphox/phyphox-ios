//
//  ExperimentViewModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

/**
 Modules whose content is dynamic (dependent on input buffers) may conform to this protocol to be aware of whether the module is active (visible on screen) or not and to be able to receive requests to update.
 */
protocol DynamicViewModule: DataBufferObserver {
    var active: Bool { get set }

    func setNeedsUpdate()

    func registerForUpdatesFromBuffer(_ buffer: DataBuffer)

    func attachDisplayLink(_ displayLink: DisplayLink)
}

extension DynamicViewModule {
    func registerForUpdatesFromBuffer(_ buffer: DataBuffer) {
        buffer.addObserver(self)
    }

    func dataBufferUpdated(_ buffer: DataBuffer) {
        setNeedsUpdate()
    }
    
    func userInputTriggered(_ buffer: DataBuffer) {
    }
}

extension DynamicViewModule where Self: DisplayLinkListener {
    func attachDisplayLink(_ displayLink: DisplayLink) {
        displayLink.listener = self
    }
}

protocol ResizingViewModule {
    var onResize: (() -> Void)? { get set }
}

enum ResizableViewModuleState {
    case normal
    case exclusive
    case hidden
}

protocol ResizableViewModule : AnyObject {
    var layoutDelegate: ModuleExclusiveLayoutDelegate? { get set }
    var resizableState: ResizableViewModuleState { get set }
    
    func switchResizableState(_ newState: ResizableViewModuleState)
    func resizableStateChanged(_ newState: ResizableViewModuleState)

    //A way back (a tab change, the "‹" bar button) asks the maximized module to leave; completion runs once it is gone.
    //A zoomed graph asks "Keep this view?" first and never calls it on Cancel.
    func leaveExclusive(completion: @escaping () -> Void)
}

extension ResizableViewModule {
    func leaveExclusive(completion: @escaping () -> Void) {
        layoutDelegate?.restoreLayout()
        completion()
    }

    func switchResizableState(_ newState: ResizableViewModuleState) {
        switch newState {
        case .exclusive:
            (self as? DynamicViewModule)?.active = true
        case .hidden:
            (self as? DynamicViewModule)?.active = false
        default:
            (self as? DynamicViewModule)?.active = true
        }
        self.resizableState = newState
        resizableStateChanged(newState)
    }
    
    func resizableStateChanged(_ newState: ResizableViewModuleState) {
    }
}

//targetX/targetY name the buffer for sameVariable; unitX/unitY carry the sending graph's logical units for sameUnit,
//where a reference matches every axis of the same quantity and text matches by equal text (units.md, "Linked zoom")
protocol ApplyZoomDelegate {
    func applyZoom(modeX: ApplyZoomAction, applyToX: ApplyZoomTarget, targetX: String?, unitX: Unit?, modeY: ApplyZoomAction, applyToY: ApplyZoomTarget, targetY: String?, unitY: Unit?, zoomMin: GraphPoint2D<Double>, zoomMax: GraphPoint2D<Double>, systemTime: Bool)
}

protocol ZoomableViewModule : AnyObject, ApplyZoomDelegate {
    var zoomDelegate: ApplyZoomDelegate? { get set }
}

protocol DescriptorBoundViewModule {
    associatedtype Descriptor: ViewDescriptor

    var descriptor: Descriptor { get }

    init?(descriptor: Descriptor, resourceFolder: URL?)
}

protocol DisplayLinkListener: AnyObject {
    func display(_ displayLink: DisplayLink)
}

final class DisplayLink {
    private lazy var displayLink: CADisplayLink = {
        return CADisplayLink(target: self, selector: #selector(displayRefresh))
    }()

    weak var listener: DisplayLinkListener?

    init(refreshRate: Int) {
        displayLink.preferredFramesPerSecond = refreshRate

        displayLink.isPaused = true
        displayLink.add(to: .main, forMode: RunLoop.Mode.common)
    }

    var active = false {
        didSet {
            displayLink.isPaused = !active
        }
    }

    @objc private func displayRefresh() {
        listener?.display(self)
    }
}

protocol ExportingViewModule : AnyObject {
    var exportDelegate: ExportDelegate? { get set }
}

protocol AnalysisLimitedViewModule : AnyObject {
    var analysisRunning: Bool { get set }
}

// Modules which has databuffer that defines the visibility of the view element.
protocol VisibilityControllableViewModule: AnyObject {
    var visibilityBuffer: DataBuffer? { get }
}
