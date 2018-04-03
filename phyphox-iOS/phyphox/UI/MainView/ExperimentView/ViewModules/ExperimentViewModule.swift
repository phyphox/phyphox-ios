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
        buffer.addObserver(self, alwaysNotify: false)
    }

    func dataBufferUpdated(_ buffer: DataBuffer) {
        setNeedsUpdate()
    }
}

extension DynamicViewModule where Self: DisplayLinkListener {
    func attachDisplayLink(_ displayLink: DisplayLink) {
        displayLink.listener = self
    }
}

protocol DescriptorBoundViewModule {
    associatedtype Descriptor: ViewDescriptor

    var descriptor: Descriptor { get }

    init?(descriptor: Descriptor)
}

protocol DisplayLinkListener: class {
    func display(_ displayLink: DisplayLink)
}

final class DisplayLink {
    private lazy var displayLink: CADisplayLink = {
        return CADisplayLink(target: self, selector: #selector(displayRefresh))
    }()

    weak var listener: DisplayLinkListener?

    init(refreshRate: Int) {
        if #available(iOS 10.0, *) {
            displayLink.preferredFramesPerSecond = refreshRate
        }
        else {
            if refreshRate >= 1 {
                displayLink.frameInterval = 60 / refreshRate
            }
        }

        displayLink.isPaused = true
        displayLink.add(to: .main, forMode: .commonModes)
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
