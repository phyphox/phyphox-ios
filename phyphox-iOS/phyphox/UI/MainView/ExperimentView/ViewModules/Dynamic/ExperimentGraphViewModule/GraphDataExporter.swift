//
//  GraphDataExporter.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 05.09.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//


class GraphDataExporter {
    private let descriptor: GraphViewDescriptor
    
    init(descriptor: GraphViewDescriptor) {
        self.descriptor = descriptor
    }
    
    func createExport() -> ExperimentExport {
        let name = descriptor.label
        var data: [(name: String, buffer: DataBuffer)] = []
        
        for i in 0..<descriptor.yInputBuffers.count {
            if let buffer = descriptor.xInputBuffers[i] {
                let xName = descriptor.localizedXLabel + (i > 0 ? " \(i+1)" : "") +
                (descriptor.localizedXUnit != "" ? "(" + descriptor.localizedXUnit + ")" : "")
                data.append((name: xName, buffer: buffer))
            }
            
            let yName = descriptor.localizedYLabel + (i > 0 ? " \(i+1)" : "") +
            (descriptor.localizedYUnit != "" ? "(" + descriptor.localizedYUnit + ")" : "")
            data.append((name: yName, buffer: descriptor.yInputBuffers[i]))
            
            if let buffer = descriptor.zInputBuffers[i] {
                let zName = descriptor.localizedZLabel + (i > 0 ? " \(i+1)" : "") +
                (descriptor.localizedZUnit != "" ? "(" + descriptor.localizedZUnit + ")" : "")
                data.append((name: zName, buffer: buffer))
            }
        }
        
        return ExperimentExport(sets: [ExperimentExportSet(name: name, data: data)])
    }
}

extension ExperimentGraphView {
    
    func exportGraphData() {
        let name = self.descriptor.label
        var data: [(name: String, buffer: DataBuffer)] = []
        for i in 0..<self.descriptor.yInputBuffers.count {
            if let buffer = self.descriptor.xInputBuffers[i] {
                data.append((name: self.descriptor.localizedXLabel + (i > 0 ? " \(i+1)" : "") + (self.descriptor.localizedXUnit != "" ? "(" + self.descriptor.localizedXUnit + ")" : ""), buffer: buffer))
            }
            
            //TODO: Export calibrated wavelength data if available
            
            
            data.append((name: self.descriptor.localizedYLabel + (i > 0 ? " \(i+1)" : "") + (self.descriptor.localizedYUnit != "" ? "(" + self.descriptor.localizedYUnit + ")" : ""), buffer: self.descriptor.yInputBuffers[i]))
            if let buffer = self.descriptor.zInputBuffers[i] {
                data.append((name: self.descriptor.localizedZLabel + (i > 0 ? " \(i+1)" : "") + (self.descriptor.localizedZUnit != "" ? "(" + self.descriptor.localizedZUnit + ")" : ""), buffer: buffer))
            }
        }
        let export = ExperimentExport(sets: [ExperimentExportSet(name: name, data: data)])
        menuController?.menuAlertController?.dismiss(animated: true, completion: {() -> Void in
            self.exportDelegate?.showExport(export, singleSet: true)
            })
    }
}