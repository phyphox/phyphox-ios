//
//  GroupViewDescriptors.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

///A view element that contains other view elements (file format 1.21, phyphox-docs views/groups.md). The label has no
///effect on a group and visibility hides the whole group. Groups emit no markup of their own: the remote interface
///builds the container from the nested view layout (WebServerUtilities).
protocol GroupViewDescriptor: ViewDescriptor {
    var children: [ViewDescriptor] { get }
}

extension GroupViewDescriptor {
    ///The leaf elements below this group in document order
    var leaves: [ViewDescriptor] {
        return children.flatMap { $0.leafDescriptors }
    }
}

extension ViewDescriptor {
    ///This element, or for a group its leaves, in document order - the walkers over a view's elements use this
    var leafDescriptors: [ViewDescriptor] {
        return (self as? GroupViewDescriptor)?.leaves ?? [self]
    }
}

struct VerticalViewDescriptor: GroupViewDescriptor {
    let label = ""
    let translation: ExperimentTranslationCollection? = nil
    let visibilityBuffer: DataBuffer?
    let children: [ViewDescriptor]

    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
}

struct HorizontalViewDescriptor: GroupViewDescriptor {
    let label = ""
    let translation: ExperimentTranslationCollection? = nil
    let visibilityBuffer: DataBuffer?
    let children: [ViewDescriptor]
    ///One per child: its share of the row's width
    let weights: [CGFloat]

    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
}

struct GridViewDescriptor: GroupViewDescriptor {
    let label = ""
    let translation: ExperimentTranslationCollection? = nil
    let visibilityBuffer: DataBuffer?
    let children: [ViewDescriptor]
    ///Largest column width in text line heights (the unit of the separator's height)
    let maxWidth: CGFloat
    let fillLastRow: Bool

    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
}

struct StackViewDescriptor: GroupViewDescriptor {
    let label = ""
    let translation: ExperimentTranslationCollection? = nil
    let visibilityBuffer: DataBuffer?
    let children: [ViewDescriptor]

    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
}

///One input of a transform: the last value of a data container (or a constant) mapped linearly onto a property
struct TransformInput: Equatable {
    let property: TransformProperty
    let buffer: DataBuffer?
    let value: Double?
    let min: Double
    let max: Double
    let mapMin: Double
    let mapMax: Double
    let clamp: Bool

    ///The mapped value, or nil where the property keeps its neutral value: an empty container, a non-finite value
    ///or min == max (transform/input in phyphox-docs)
    func mappedValue() -> Double? {
        let raw: Double?
        if let buffer = buffer {
            raw = buffer.last
        } else {
            raw = value
        }
        guard let v = raw, v.isFinite, max != min else { return nil }
        var result = mapMin + (v - min) * (mapMax - mapMin) / (max - min)
        if clamp {
            result = Swift.min(Swift.max(result, Swift.min(mapMin, mapMax)), Swift.max(mapMin, mapMax))
        }
        return result.isFinite ? result : nil
    }
}

///The properties of a transform at one moment, neutral where no input drives them
struct TransformState: Equatable {
    var scale: Double = 1
    var scaleX: Double = 1
    var scaleY: Double = 1
    var translateX: Double = 0
    var translateY: Double = 0
    var rotate: Double = 0
    var opacity: Double = 1
}

struct TransformViewDescriptor: GroupViewDescriptor {
    let label = ""
    let translation: ExperimentTranslationCollection? = nil
    let visibilityBuffer: DataBuffer?
    let originX: CGFloat
    let originY: CGFloat
    let inputs: [TransformInput]
    let child: ViewDescriptor

    var children: [ViewDescriptor] {
        return [child]
    }

    ///Evaluates every input now; a later input for the same property wins
    func currentState() -> TransformState {
        var state = TransformState()
        for input in inputs {
            guard let value = input.mappedValue() else { continue }
            switch input.property {
            case .scale: state.scale = value
            case .scaleX: state.scaleX = value
            case .scaleY: state.scaleY = value
            case .translateX: state.translateX = value
            case .translateY: state.translateY = value
            case .rotate: state.rotate = value
            case .opacity: state.opacity = Swift.min(Swift.max(value, 0), 1)
            }
        }
        return state
    }

    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }
}
