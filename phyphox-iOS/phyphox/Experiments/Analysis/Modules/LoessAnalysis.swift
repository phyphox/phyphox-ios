//
//  LoessAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 22.05.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

final class LoessAnalysis: AutoClearingExperimentAnalysisModule {
    private static let xInSlot = AnalysisIOSlot(name: "x", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let yInSlot = AnalysisIOSlot(name: "y", asRequired: true, repeatOffset: -1, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let dInSlot = AnalysisIOSlot(name: "d", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let xiInSlot = AnalysisIOSlot(name: "xi", asRequired: true, repeatOffset: -1, valueAllowed: true, emptyAllowed: false, minCount: 1, maxCount: 1)
    private static let yi0OutSlot = AnalysisIOSlot(name: "yi0", asRequired: false, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 1, maxCount: 0)
    private static let yi1OutSlot = AnalysisIOSlot(name: "yi1", asRequired: true, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 0)
    private static let yi2OutSlot = AnalysisIOSlot(name: "yi2", asRequired: true, repeatOffset: 0, valueAllowed: false, emptyAllowed: false, minCount: 0, maxCount: 0)

    override class var ioMapping: AnalysisIOMapping? {
        return AnalysisIOMapping(inputs: [Self.xInSlot, Self.yInSlot, Self.dInSlot, Self.xiInSlot], outputs: [Self.yi0OutSlot, Self.yi1OutSlot, Self.yi2OutSlot])
    }
    
    private var xIn: MutableDoubleArray?
    private var yIn: MutableDoubleArray?
    private var dIn: ExperimentAnalysisDataInput?
    private var xLocIn: MutableDoubleArray?

    private var yi0Output: ExperimentAnalysisDataOutput?
    private var yi1Output: ExperimentAnalysisDataOutput?
    private var yi2Output: ExperimentAnalysisDataOutput?
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let io = try Self.mapIO(inputs: inputs, outputs: outputs)
        xIn = io.data(Self.xInSlot)
        yIn = io.data(Self.yInSlot)
        xLocIn = io.data(Self.xiInSlot)
        dIn = io.input(Self.dInSlot)

        if (xIn == nil) {
            throw SerializationError.genericError(message: "Error: No input for x provided to loess module.")
        }

        if (yIn == nil) {
            throw SerializationError.genericError(message: "Error: No input for y provided to loess module.")
        }

        if (xLocIn == nil) {
            throw SerializationError.genericError(message: "Error: No input for xi provided to loess module.")
        }

        if (dIn == nil) {
            throw SerializationError.genericError(message: "Error: No input for d provided to loess module.")
        }

        //Outputs map by name; an unnamed output fills yi0 - formerly they were read in
        //document order, ignoring the as attribute
        //(analysis-outputs-assigned-by-position in phyphox-docs)
        yi0Output = io.output(Self.yi0OutSlot)
        yi1Output = io.output(Self.yi1OutSlot)
        yi2Output = io.output(Self.yi2OutSlot)

        if (yi0Output == nil) {
            throw SerializationError.genericError(message: "Error: No output for loess module specified.")
        }

        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    func weight(dx: Double, d: Double) -> Double {
        if (dx > d) {
            return 0.0;
        }
        let v = dx / d;
        let v13 = 1.0 - v*v*v;
        return v13*v13*v13;
    }
    
    override func update() {
        guard let x = xIn?.data else {
            return
        }
        guard let y = yIn?.data else {
            return
        }
        guard let xOut = xLocIn?.data else {
            return
        }
        
        guard let d = dIn?.getSingleValue() else {
            return
        }
        
        let incount = min(x.count, y.count)

        var result_yi0: [Double] = []
        var result_yi1: [Double] = []
        var result_yi2: [Double] = []
        
        var minj = 0
        for xi in xOut {
            
            var sw = 0.0;
            var swx = 0.0;
            var swxx = 0.0;
            var swxxx = 0.0;
            var swxxxx = 0.0;
            var swy = 0.0;
            var swxy = 0.0;
            var swxxy = 0.0;

            var j = minj
            while (j < incount) {
                let xj = x[j];
                let yj = y[j];
                if (xj.isNaN || yj.isNaN) {
                    j += 1
                    continue;
                }
                let dx = xj-xi;
                if (abs(dx) > d) {
                    if (dx < 0) {
                        j += 1
                        minj = j;
                        continue;
                    } else {
                        j += 1
                        break;
                    }
                }

                let w = weight(dx: abs(dx), d: d);

                sw += w;
                let wx = w*dx;
                swx += wx;
                let wxx = wx*dx;
                swxx += wxx;
                let wxxx = wxx*dx;
                swxxx += wxxx;
                swxxxx += wxxx*dx;
                swy += w*yj;
                swxy += wx*yj;
                swxxy += wxx*yj;
                
                j += 1
            }

            let a = swxx*swxxxx-swxxx*swxxx;
            let b = swxx*swxxx-swx*swxxxx;
            let c = swx*swxxx-swxx*swxx;

            let det = sw*swxx*swxxxx+2*swx*swxx*swxxx-swxx*swxx*swxx-swx*swx*swxxxx-sw*swxxx*swxxx;

            let yi = (a*swy + b*swxy + c*swxxy)/det;

            result_yi0.append(yi)
            
            if yi1Output != nil || yi2Output != nil {
                let d = sw*swxxxx-swxx*swxx;
                let e = swx*swxx-sw*swxxx;
                let f = sw*swxx-swx*swx;

                let yi1 = (b * swy + d * swxy + e * swxxy) / det;
                result_yi1.append(yi1);

                let yi2 = (c * swy + e * swxy + f * swxxy) / det;
                result_yi2.append(yi2);
            }
            
        }
        
        if case .buffer(buffer: let buffer, data: _, usedAs: _, append: _)? = yi0Output {
            buffer.appendFromArray(result_yi0)
        }

        if case .buffer(buffer: let buffer, data: _, usedAs: _, append: _)? = yi1Output {
            buffer.appendFromArray(result_yi1)
        }

        if case .buffer(buffer: let buffer, data: _, usedAs: _, append: _)? = yi2Output {
            buffer.appendFromArray(result_yi2)
        }
    }
}
