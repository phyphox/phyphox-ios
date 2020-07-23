//
//  LoessAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 22.05.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

final class LoessAnalysis: ExperimentAnalysisModule {
    
    private var xIn: DataBuffer?
    private var yIn: DataBuffer?
    private var dIn: ExperimentAnalysisDataIO?
    private var xLocIn: DataBuffer?
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        
        for input in inputs {
            if input.asString == "x" {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    xIn = buffer
                case .value(value: _, usedAs: _):
                    break
                }
            } else if input.asString == "y" {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    yIn = buffer
                case .value(value: _, usedAs: _):
                    break
                }
            } else if input.asString == "xi" {
                switch input {
                case .buffer(buffer: let buffer, usedAs: _, clear: _):
                    xLocIn = buffer
                case .value(value: _, usedAs: _):
                    break
                }
            } else if input.asString == "d" {
                dIn = input
            } else {
                throw SerializationError.genericError(message: "Error: Invalid analysis input for loess module: \(String(describing: input.asString))")
            }
        }
        
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
            
        if (outputs.count < 1) {
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
        guard let x = xIn?.toArray() else {
            return
        }
        guard let y = yIn?.toArray() else {
            return
        }
        guard let xOut = xLocIn?.toArray() else {
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
            
            if outputs.count > 1 {
                let d = sw*swxxxx-swxx*swxx;
                let e = swx*swxx-sw*swxxx;
                let f = sw*swxx-swx*swx;

                let yi1 = (b * swy + d * swxy + e * swxxy) / det;
                result_yi1.append(yi1);
            
                let yi2 = (c * swy + e * swxy + f * swxxy) / det;
                result_yi2.append(yi2);
            }
            
        }
        
        beforeWrite()

        switch outputs[0] {
        case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
            if clear {
                buffer.replaceValues(result_yi0)
            }
            else {
                buffer.appendFromArray(result_yi0)
            }
        case .value(value: _, usedAs: _):
            break
        }
        
        if outputs.count > 1 {
            switch outputs[1] {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(result_yi1)
                }
                else {
                    buffer.appendFromArray(result_yi1)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
        
        if outputs.count > 2 {
            switch outputs[2] {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(result_yi2)
                }
                else {
                    buffer.appendFromArray(result_yi2)
                }
            case .value(value: _, usedAs: _):
                break
            }
        }
    }
}
