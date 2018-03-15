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
}

extension DynamicViewModule {
    func registerForUpdatesFromBuffer(_ buffer: DataBuffer) {
        buffer.addObserver(self, alwaysNotify: false)
    }

    func dataBufferUpdated(_ buffer: DataBuffer) {
        setNeedsUpdate()
    }
}

protocol DescriptorBoundViewModule {
    associatedtype Descriptor: ViewDescriptor

    var descriptor: Descriptor { get }

    init?(descriptor: Descriptor)
}

class DisplayLinkedView: UIView {
    private lazy var displayLink: CADisplayLink = {
        return CADisplayLink(target: self, selector: #selector(displayRefresh))
    }()

    var refreshRate: Int {
        get {
            if #available(iOS 10.0, *) {
                return displayLink.preferredFramesPerSecond
            }
            else {
                return 60 / displayLink.frameInterval
            }
        }
        set {
            if #available(iOS 10.0, *) {
                displayLink.preferredFramesPerSecond = newValue
            }
            else {
                displayLink.frameInterval = 60 / newValue
            }
        }
    }

    var linked = false {
        didSet {
            displayLink.isPaused = !linked
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        displayLink.isPaused = true
        displayLink.add(to: .main, forMode: .commonModes)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func displayRefresh() {
        display()
    }

    func display() {}
}
