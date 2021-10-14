//
//  ExperimentDepthGUIView.swift
//  phyphox
//
//  Created by Sebastian Staacks on 13.10.21.
//  Copyright © 2021 RWTH Aachen. All rights reserved.
//

//Note that this is treated as a static view element as it does not need to react to any change of analysis data

import Foundation
import ARKit
import Metal
import MetalKit
import CocoaMQTT

@available(iOS 14.0, *)
protocol DepthGUIDelegate {
    func updateFrame(frame: ARFrame)
    func updateResolution(resolution: CGSize)
}

protocol DepthGUISelectionDelegate {
    var mode: ExperimentDepthInput.DepthExtractionMode { get set }
    var x1: Float { get set }
    var x2: Float { get set }
    var y1: Float { get set }
    var y2: Float { get set }
}

extension MTKView: RenderDestinationProvider {
}

@available(iOS 14.0, *)
final class ExperimentDepthGUIView: UIView, DescriptorBoundViewModule, ResizableViewModule, MTKViewDelegate, DepthGUIDelegate {
    
    var resolution: CGSize?
    var depthGUISelectionDelegate: DepthGUISelectionDelegate?
    
    func updateResolution(resolution: CGSize) {
        self.resolution = resolution
        setNeedsLayout()
    }
    
    func updateFrame(frame: ARFrame) {
        let selectionState: ExperimentDepthGUIRenderer.SelectionStruct
        if let del = depthGUISelectionDelegate {
            selectionState = ExperimentDepthGUIRenderer.SelectionStruct(x1: del.x1, x2: del.x2, y1: del.y1, y2: del.y2, editable: resizableState == .exclusive)
        } else {
            selectionState = ExperimentDepthGUIRenderer.SelectionStruct(x1: 0, x2: 0, y1: 0, y2: 0, editable: false)
        }
        renderer.updateFrame(frame: frame, selectionState: selectionState)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }
    
    func draw(in view: MTKView) {
        renderer.update()
    }
    
    var layoutDelegate: ModuleExclusiveLayoutDelegate? = nil
    var resizableState: ResizableViewModuleState =  .normal
    
    let unfoldMoreImageView: UIImageView
    let unfoldLessImageView: UIImageView
    
    let descriptor: DepthGUIViewDescriptor
    let spacing: CGFloat = 1.0
    private let sideMargins:CGFloat = 10.0
    private let buttonPadding: CGFloat = 20.0


    private let label = UILabel()
    private let arView = MTKView()
    let renderer: ExperimentDepthGUIRenderer
    private let aggregationBtn = UIButton()
    
    var panGestureRecognizer: UIPanGestureRecognizer? = nil
    
    required init?(descriptor: DepthGUIViewDescriptor) {
        self.descriptor = descriptor
        
        unfoldLessImageView = UIImageView(image: UIImage(named: "unfold_less"))
        unfoldMoreImageView = UIImageView(image: UIImage(named: "unfold_more"))
        
        arView.device = MTLCreateSystemDefaultDevice()
        arView.backgroundColor = UIColor.clear
        
        renderer = ExperimentDepthGUIRenderer(metalDevice: arView.device!, renderDestination: arView)
        
        aggregationBtn.backgroundColor = kLightBackgroundColor
        aggregationBtn.setTitle(localize("depthAggregationMode"), for: UIControl.State())
        aggregationBtn.isHidden = true
        
        super.init(frame: .zero)
        
        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = kTextColor

        addSubview(label)
        
        let unfoldRect = CGRect(x: 5, y: 5, width: 20, height: 20)
        unfoldMoreImageView.frame = unfoldRect
        unfoldLessImageView.frame = unfoldRect
        unfoldLessImageView.isHidden = true
        unfoldMoreImageView.isHidden = false
        
        addSubview(unfoldMoreImageView)
        addSubview(unfoldLessImageView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ExperimentDepthGUIView.tapped(_:)))
        arView.addGestureRecognizer(tapGesture)
        self.addGestureRecognizer(tapGesture)
        
        arView.delegate = self
        
        aggregationBtn.addTarget(self, action: #selector(ExperimentDepthGUIView.aggregationBtnPressed), for: .touchUpInside)
        
        addSubview(arView)
        addSubview(aggregationBtn)
        
        renderer.drawRectResized(size: arView.bounds.size)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        switch resizableState {
        case .exclusive:
            return size
        case .hidden:
            return CGSize.init(width: 0, height: 0)
        default:
            let labelh = label.sizeThatFits(size).height
            
            return CGSize(width: size.width, height: Swift.min((size.width-2*sideMargins)/descriptor.aspectRatio + labelh + 2*spacing, size.height))
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let s = label.sizeThatFits(frame.size)
        label.frame = CGRect(x: (frame.size.width-s.width)/2.0, y: spacing, width: s.width, height: s.height)
        
        let orientation = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation ?? .portrait
        
        var buttonS = resizableState == .exclusive ? aggregationBtn.sizeThatFits(frame.size) : CGSize(width: 0, height: 0)
        if buttonS.width > 0 {
            buttonS.width += 2*buttonPadding
        }
        let buttonH = resizableState == .exclusive ? buttonS.height + 2*spacing : 0
        
        let h, w: CGFloat
        if let resolution = resolution {
            let actualAspect = (frame.width - 2*sideMargins) / (frame.height - 2*spacing - s.height - buttonH)
            let aspect: CGFloat
            if orientation == .landscapeRight || orientation == .landscapeLeft {
                aspect = resolution.width / resolution.height
            } else {
                aspect = resolution.height / resolution.width
            }
            if aspect > actualAspect {
                w = frame.width - 2*sideMargins
                h = w / aspect
            } else {
                h = frame.height - 2*spacing - s.height - buttonH
                w = h * aspect
            }
        } else {
            w = frame.width - 2*sideMargins
            h = frame.height - 2*spacing - s.height - buttonH
        }
        arView.frame = CGRect(x: (frame.width - w)/2, y: 2*spacing + s.height, width: w, height: h)
        if resizableState == .exclusive {
            aggregationBtn.frame = CGRect(x: (frame.width - buttonS.width)/2, y: 2*spacing + s.height + h + 2*spacing, width: buttonS.width, height: buttonS.height)
        }
    }
    
    func resizableStateChanged(_ newState: ResizableViewModuleState) {
        if newState == .exclusive {
            if let del = depthGUISelectionDelegate {
                aggregationBtn.setTitle(localize("depthAggregationMode") + ": " + localize("depthAggregationMode" + del.mode.rawValue.capitalized), for: UIControl.State())
            }
            aggregationBtn.isHidden = false
            unfoldMoreImageView.isHidden = true
            unfoldLessImageView.isHidden = false
            panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ExperimentDepthGUIView.panned(_:)))
            if let gr = panGestureRecognizer {
                arView.addGestureRecognizer(gr)
            }
        } else {
            unfoldMoreImageView.isHidden = false
            unfoldLessImageView.isHidden = true
            aggregationBtn.isHidden = true
            if let gr = panGestureRecognizer {
                arView.removeGestureRecognizer(gr)
            }
            panGestureRecognizer = nil
        }
    }
    
    @objc func tapped(_ sender: UITapGestureRecognizer) {
        if resizableState == .normal {
            layoutDelegate?.presentExclusiveLayout(self)
        } else {
            layoutDelegate?.restoreLayout()
        }
    }
    
    var panningIndexX: Int = 0
    var panningIndexY: Int = 0
    @objc func panned (_ sender: UIPanGestureRecognizer) {
        guard var del = depthGUISelectionDelegate else {
            return
        }
        let p = sender.location(in: arView)
        let pr = CGPoint(x: p.x / arView.frame.width, y: p.y / arView.frame.height)
        let ps = pr.applying(renderer.displayToCameraTransform)
        let x = Float(ps.x)
        let y = Float(ps.y)
        
        if sender.state == .began {
            let d11 = (x - del.x1)*(x - del.x1) + (y - del.y1)*(y - del.y1)
            let d12 = (x - del.x1)*(x - del.x1) + (y - del.y2)*(y - del.y2)
            let d21 = (x - del.x2)*(x - del.x2) + (y - del.y1)*(y - del.y1)
            let d22 = (x - del.x2)*(x - del.x2) + (y - del.y2)*(y - del.y2)
            let dist:Float = 0.01
            if d11 < dist && d11 < d12 && d11 < d21 && d11 < d22 {
                panningIndexX = 1
                panningIndexY = 1
            } else if d12 < dist && d12 < d21 && d12 < d22 {
                panningIndexX = 1
                panningIndexY = 2
            } else if d21 < dist && d21 < d22 {
                panningIndexX = 2
                panningIndexY = 1
            } else if d22 < dist {
                panningIndexX = 2
                panningIndexY = 2
            } else {
                panningIndexX = 0
                panningIndexY = 0
            }
        } else {
            if panningIndexX == 1 {
                del.x1 = x
            } else if panningIndexX == 2 {
                del.x2 = x
            }
            if panningIndexY == 1 {
                del.y1 = y
            } else if panningIndexY == 2 {
                del.y2 = y
            }
        }
    }
    
    @objc private func aggregationBtnPressed() {
        let al = UIAlertController(title: localize("depthAggregationMode"), message: localize("depthAggregationModePrompt"), preferredStyle: .actionSheet)
        
        for mode in ExperimentDepthInput.DepthExtractionMode.allCases {
            al.addAction(UIAlertAction(title: localize("depthAggregationMode" + mode.rawValue.capitalized), style: .default, handler: { _ in
                if var del = self.depthGUISelectionDelegate {
                    del.mode = mode
                    self.aggregationBtn.setTitle(localize("depthAggregationMode") + ": " + localize("depthAggregationMode" + del.mode.rawValue.capitalized), for: UIControl.State())
                }
            }))
        }
        
        if let popover = al.popoverPresentationController {
            popover.sourceView = aggregationBtn
            popover.sourceRect = aggregationBtn.bounds
            popover.permittedArrowDirections = .any
        }
                
        layoutDelegate?.presentDialog(al)
    }
}
