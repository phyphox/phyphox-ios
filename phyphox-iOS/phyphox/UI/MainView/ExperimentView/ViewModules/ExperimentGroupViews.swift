//
//  ExperimentGroupViews.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import UIKit

///A module holding other modules: the view groups and the transform of file format 1.21 (phyphox-docs views/groups.md).
///The experiment screen wires its protocols (visibility, exclusive layout, zoom, buttons, export, analysis limits) per
///module, so every walk over the modules goes through the tree (UIView.moduleTree) rather than the rows alone.
protocol ContainerViewModule: AnyObject {
    var childModules: [UIView] { get }

    ///Maximizes a leaf below this container: the children on the path to it stay, the others are hidden
    func presentExclusive(_ leaf: UIView)
    ///Undoes presentExclusive; the visibility buffers are applied again by the caller
    func restoreExclusive()
}

extension UIView {
    ///This module and, for a container, every module below it, in document order
    var moduleTree: [UIView] {
        guard let container = self as? ContainerViewModule else { return [self] }
        return [self] + container.childModules.flatMap { $0.moduleTree }
    }

    ///A child hidden by its visibility buffer or by another module's maximized layout takes no space in a group
    fileprivate var takesSpace: Bool {
        return !isHidden
    }
}

///vertical, horizontal, grid and stack. A child keeps the size it reports at the width it is given and is centred in its
///cell, like a top-level module in its table row; the manual-frame style of the leaf modules is kept.
final class ExperimentGroupView: UIView, ContainerViewModule, VisibilityControllableViewModule {
    enum Kind {
        case vertical
        case horizontal(weights: [CGFloat])
        ///maxWidth in text line heights, the unit of the separator's height
        case grid(maxWidth: CGFloat, fillLastRow: Bool)
        case stack
    }

    let kind: Kind
    let childModules: [UIView]
    let visibilityBuffer: DataBuffer?
    private(set) var exclusiveLeaf: UIView? = nil

    private let fontScale = UIFont.preferredFont(forTextStyle: .footnote).pointSize

    init(kind: Kind, children: [UIView], visibilityBuffer: DataBuffer?) {
        self.kind = kind
        self.childModules = children
        self.visibilityBuffer = visibilityBuffer
        super.init(frame: .zero)
        //Document order is the z-order: later children are drawn over earlier ones
        for child in children {
            addSubview(child)
        }
        if case .stack = kind {
            //A stack is not interactive: no maximize, zoom or pick, no touches on a transformed child
            isUserInteractionEnabled = false
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isStack: Bool {
        if case .stack = kind { return true }
        return false
    }

    ///Columns of a grid at the given width: the smallest count keeping each column at or below maxWidth
    func gridColumns(width: CGFloat) -> Int {
        guard case .grid(let maxWidth, _) = kind else { return 1 }
        let columnWidth = maxWidth * fontScale
        guard columnWidth > 0, columnWidth.isFinite, width > columnWidth else { return 1 }
        return Int((width / columnWidth).rounded(.up))
    }

    ///Frames of the children (nil for a child that takes no space) at the given width, and the group's own size
    private func layout(in size: CGSize) -> (frames: [CGRect?], size: CGSize) {
        let width = size.width
        let unbounded = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        var frames = [CGRect?](repeating: nil, count: childModules.count)

        //A maximized leaf below this group: the path to it takes the whole box, everything else is hidden
        if let leaf = exclusiveLeaf {
            for (index, child) in childModules.enumerated() where child === leaf || child.moduleTree.contains(where: { $0 === leaf }) {
                frames[index] = CGRect(origin: .zero, size: size)
            }
            return (frames, size)
        }

        let visible = childModules.enumerated().filter { $0.element.takesSpace }
        guard !visible.isEmpty else { return (frames, CGSize(width: width, height: 0)) }

        //A child is centred in its cell; it may report a narrower size (info and image keep side margins)
        func place(_ child: UIView, in cell: CGRect) -> CGRect {
            let fitted = child.sizeThatFits(CGSize(width: cell.width, height: CGFloat.greatestFiniteMagnitude))
            let w = Swift.min(Swift.max(fitted.width, 0), cell.width)
            let h = fitted.height.isFinite ? Swift.max(fitted.height, 0) : 0
            return CGRect(x: cell.minX + (cell.width - w) / 2.0, y: cell.minY + (cell.height - h) / 2.0, width: w, height: h)
        }

        switch kind {
        case .vertical:
            var y: CGFloat = 0
            for (index, child) in visible {
                let fitted = child.sizeThatFits(unbounded)
                let w = Swift.min(Swift.max(fitted.width, 0), width)
                let h = fitted.height.isFinite ? Swift.max(fitted.height, 0) : 0
                frames[index] = CGRect(x: (width - w) / 2.0, y: y, width: w, height: h)
                y += h
            }
            return (frames, CGSize(width: width, height: y))

        case .horizontal(let weights):
            //The row splits by weight; a hidden child gives its share to its siblings
            var total: CGFloat = 0
            for (index, _) in visible {
                let weight = index < weights.count ? weights[index] : 1
                total += weight > 0 && weight.isFinite ? weight : 0
            }
            var columns: [(index: Int, x: CGFloat, width: CGFloat)] = []
            var x: CGFloat = 0
            for (index, _) in visible {
                let weight = index < weights.count ? weights[index] : 1
                let share = total > 0 ? (weight > 0 && weight.isFinite ? weight : 0) / total : 1.0 / CGFloat(visible.count)
                let columnWidth = width * share
                columns.append((index, x, columnWidth))
                x += columnWidth
            }
            //The row is as tall as its tallest child, the others are centred vertically
            var rowHeight: CGFloat = 0
            for column in columns {
                let fitted = childModules[column.index].sizeThatFits(CGSize(width: column.width, height: CGFloat.greatestFiniteMagnitude))
                if fitted.height.isFinite {
                    rowHeight = Swift.max(rowHeight, fitted.height)
                }
            }
            for column in columns {
                frames[column.index] = place(childModules[column.index], in: CGRect(x: column.x, y: 0, width: column.width, height: rowHeight))
            }
            return (frames, CGSize(width: width, height: rowHeight))

        case .grid(_, let fillLastRow):
            let columns = gridColumns(width: width)
            var y: CGFloat = 0
            var start = 0
            while start < visible.count {
                let row = Array(visible[start..<Swift.min(start + columns, visible.count)])
                //An incomplete last row keeps the column width unless fillLastRow stretches its children over the row
                let columnWidth = width / CGFloat(fillLastRow ? row.count : columns)
                var rowHeight: CGFloat = 0
                for (_, child) in row {
                    let fitted = child.sizeThatFits(CGSize(width: columnWidth, height: CGFloat.greatestFiniteMagnitude))
                    if fitted.height.isFinite {
                        rowHeight = Swift.max(rowHeight, fitted.height)
                    }
                }
                for (position, (index, child)) in row.enumerated() {
                    frames[index] = place(child, in: CGRect(x: CGFloat(position) * columnWidth, y: y, width: columnWidth, height: rowHeight))
                }
                y += rowHeight
                start += columns
            }
            return (frames, CGSize(width: width, height: y))

        case .stack:
            //Every child gets the full width; the tallest sets the height and the others are centred in it
            var height: CGFloat = 0
            for (_, child) in visible {
                let fitted = child.sizeThatFits(unbounded)
                if fitted.height.isFinite {
                    height = Swift.max(height, fitted.height)
                }
            }
            for (index, child) in visible {
                frames[index] = place(child, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            return (frames, CGSize(width: width, height: height))
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        if exclusiveLeaf != nil {
            return size
        }
        return layout(in: size).size
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let frames = layout(in: bounds.size).frames
        for (index, child) in childModules.enumerated() {
            if let frame = frames[index] {
                child.frame = frame
                //A nested group re-lays out even when its frame is unchanged (a child's visibility may have changed)
                if child is ContainerViewModule {
                    child.setNeedsLayout()
                }
            }
        }
    }

    // MARK: - Exclusive layout of a leaf below this group

    func presentExclusive(_ leaf: UIView) {
        exclusiveLeaf = leaf
        for child in childModules {
            if child === leaf {
                (child as? ResizableViewModule)?.switchResizableState(.exclusive)
                child.isHidden = false
            } else if let container = child as? ContainerViewModule, child.moduleTree.contains(where: { $0 === leaf }) {
                container.presentExclusive(leaf)
                child.isHidden = false
            } else {
                for module in child.moduleTree {
                    (module as? ResizableViewModule)?.switchResizableState(.hidden)
                }
                child.isHidden = true
            }
        }
        setNeedsLayout()
    }

    func restoreExclusive() {
        exclusiveLeaf = nil
        for child in childModules {
            (child as? ContainerViewModule)?.restoreExclusive()
            for module in child.moduleTree {
                (module as? ResizableViewModule)?.switchResizableState(.normal)
            }
            child.isHidden = false
        }
        setNeedsLayout()
    }
}

///transform: wraps one element of a stack and scales, rotates, moves or fades it under the control of its inputs. The
///wrapper itself stays untransformed (the stack lays out the untransformed size); the child's layer is transformed
///about the origin. Driven per frame like the graph: flagged on a buffer write, evaluated on the display link.
final class ExperimentTransformView: UIView, ContainerViewModule, DynamicViewModule, DisplayLinkListener, VisibilityControllableViewModule {
    let descriptor: TransformViewDescriptor
    let child: UIView
    private let displayLink = DisplayLink(refreshRate: 0)
    private var wantsUpdate = true
    private(set) var appliedState = TransformState()

    var childModules: [UIView] {
        return [child]
    }

    var visibilityBuffer: DataBuffer? {
        return descriptor.visibilityBuffer
    }

    var active = false {
        didSet {
            displayLink.active = active
            if active {
                setNeedsUpdate()
            }
        }
    }

    init(descriptor: TransformViewDescriptor, child: UIView) {
        self.descriptor = descriptor
        self.child = child
        super.init(frame: .zero)
        addSubview(child)
        child.layer.anchorPoint = CGPoint(x: descriptor.originX, y: descriptor.originY)
        for input in descriptor.inputs {
            if let buffer = input.buffer {
                registerForUpdatesFromBuffer(buffer)
            }
        }
        attachDisplayLink(displayLink)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setNeedsUpdate() {
        wantsUpdate = true
    }

    func display(_ displayLink: DisplayLink) {
        if wantsUpdate {
            wantsUpdate = false
            applyTransform()
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        //A wrapped element hidden by its own visibility takes no space in the stack
        return child.isHidden ? .zero : child.sizeThatFits(size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        //bounds and center rather than frame: a frame is undefined for a transformed view. With the anchor at the
        //origin, the untransformed child fills the wrapper exactly.
        child.bounds = CGRect(origin: .zero, size: bounds.size)
        child.center = CGPoint(x: bounds.width * descriptor.originX, y: bounds.height * descriptor.originY)
        if child is ContainerViewModule {
            child.setNeedsLayout()
        }
        applyTransform()
    }

    ///Scale, then rotation, then translation about the origin (CGAffineTransform concatenates right to left); the
    ///rotation is in radians and positive clockwise on screen, as in UIKit's y-down coordinates; lengths are fractions
    ///of the untransformed size
    func applyTransform() {
        let state = descriptor.currentState()
        appliedState = state
        let tx = CGFloat(state.translateX) * bounds.width
        let ty = CGFloat(state.translateY) * bounds.height
        child.transform = CGAffineTransform(translationX: tx, y: ty)
            .rotated(by: CGFloat(state.rotate))
            .scaledBy(x: CGFloat(state.scale * state.scaleX), y: CGFloat(state.scale * state.scaleY))
        child.alpha = CGFloat(state.opacity)
    }

    //A stack never maximizes, so nothing to do here
    func presentExclusive(_ leaf: UIView) {}

    func restoreExclusive() {}
}
