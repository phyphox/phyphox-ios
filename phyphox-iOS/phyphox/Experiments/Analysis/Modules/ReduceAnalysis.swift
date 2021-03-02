//
//  ReduceAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 03.04.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

final class ReduceAnalysis: ExperimentAnalysisModule {
    private var averageX = false
    private var averageY = false
    private var sumY = false
    
    private var factor: ExperimentAnalysisDataIO? = nil
    private var inX: DataBuffer? = nil
    private var inY: DataBuffer? = nil
    
    private var outX: ExperimentAnalysisDataIO? = nil
    private var outY: ExperimentAnalysisDataIO? = nil
    
    required init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)
        averageX = try attributes.optionalValue(for: "averageX") ?? false
        averageY = try attributes.optionalValue(for: "averageY") ?? false
        sumY = try attributes.optionalValue(for: "sumY") ?? false
        
        for input in inputs {
            if input.asString == "x" {
                switch input {
                    case .buffer(buffer: let buffer, usedAs: _, clear: _):
                        inX = buffer
                    default:
                        throw SerializationError.genericError(message: "Error: Input x for reduce module has to be a buffer.")
                }
            }
            else if input.asString == "y" {
                switch input {
                    case .buffer(buffer: let buffer, usedAs: _, clear: _):
                        inY = buffer
                    default:
                        throw SerializationError.genericError(message: "Error: Input y for reduce module has to be a buffer.")
                }
            }
            else if input.asString == "factor" {
                factor = input
            }
            else {
                throw SerializationError.genericError(message: "Error: Unknown input for reduce module: \(input.asString).")
            }
        }
        
        if (outputs.count < 1) {
            throw SerializationError.genericError(message: "Error: No output for reduce-module specified.")
        }
        
        for output in outputs {
            if output.asString == "x" {
                outX = output
            } else if output.asString == "y" {
                outY = output
            } else {
                throw SerializationError.genericError(message: "Error: Unknown output for reduce module: \(output.asString).")
            }
        }
        
        if factor == nil {
            throw SerializationError.genericError(message: "Error: Reduce module requires input \"factor\".")
        }
        
        if inX == nil {
            throw SerializationError.genericError(message: "Error: Reduce module requires input \"x\".")
        }
        
        if outX == nil {
            throw SerializationError.genericError(message: "Error: Reduce module requires output \"x\".")
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        guard let fac = factor?.getSingleValue() else {
            return
        }
        
        let x = inX!.toArray()
        let y = inY?.toArray()
        
        var resX = [Double]()
        var resY = [Double]()
        
        if fac > 1 {
            let ifac = Int(round(fac))
            var index = 0
            var i = 0
            while index < x.count {
                var newX = 0.0
                var newY = 0.0
                for j in 0..<ifac {
                    index = i*ifac+j
                    if index >= x.count {
                        break
                    }
                    if j == 0 {
                        newX = x[index]
                        newY = y != nil ? y![index] : 0.0
                    } else  {
                        if sumY || averageY {
                            newY += y != nil ? y![index] : 0.0
                        }
                        if averageX {
                            newX += x[index]
                        }
                    }
                }
                if averageX {
                    newX /= Double(ifac)
                }
                if averageY {
                    newY /= Double(ifac)
                }
                
                resX.append(newX)
                resY.append(newY)
                i += 1
                index = i*ifac
            }
        } else if fac > 0 {
            let ifac = Int(round(1.0/fac))
            for i in 0..<x.count {
                for _ in 0..<ifac {
                    resX.append(x[i])
                    resY.append(y != nil && y!.count > i ? y![i] : 0.0)
                }
            }
        }
        
        beforeWrite()
        
        switch outX! {
        case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
            if clear {
                buffer.replaceValues(resX)
            }
            else {
                buffer.appendFromArray(resX)
            }
        default:
            break
        }
        
        if let yOut = outY {
            switch yOut {
            case .buffer(buffer: let buffer, usedAs: _, clear: let clear):
                if clear {
                    buffer.replaceValues(resY)
                }
                else {
                    buffer.appendFromArray(resY)
                }
            default:
                break
            }
        }

    }
}
