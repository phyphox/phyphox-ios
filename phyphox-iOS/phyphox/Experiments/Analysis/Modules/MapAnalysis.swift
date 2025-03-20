//
//  MapAnalysis.swift
//  phyphox
//
//  Created by Sebastian Staacks on 03.04.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

final class MapAnalysis: AutoClearingExperimentAnalysisModule {
    enum ZMode {
        case count
        case sum
        case average
    }
    private var zMode = ZMode.average
    
    private var mapWidth: ExperimentAnalysisDataInput
    private var minX: ExperimentAnalysisDataInput
    private var maxX: ExperimentAnalysisDataInput
    private var mapHeight: ExperimentAnalysisDataInput
    private var minY: ExperimentAnalysisDataInput
    private var maxY: ExperimentAnalysisDataInput
    private var x: MutableDoubleArray
    private var y: MutableDoubleArray
    private var z: MutableDoubleArray? = nil
    
    private var outX: ExperimentAnalysisDataOutput? = nil
    private var outY: ExperimentAnalysisDataOutput? = nil
    private var outZ: ExperimentAnalysisDataOutput? = nil
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        
        let attributes = additionalAttributes.attributes(keyedBy: String.self)
        if let mode: String = try attributes.optionalValue(for: "zMode") {
            switch mode {
            case "count":
                zMode = .count
            case "average":
                zMode = .average
            case "sum":
                zMode = .sum
            default:
                throw SerializationError.genericError(message: "Error: Unknown value for zMode of map module.")
            }
        }
        
        var mapWidth: ExperimentAnalysisDataInput? = nil
        var minX: ExperimentAnalysisDataInput? = nil
        var maxX: ExperimentAnalysisDataInput? = nil
        var mapHeight: ExperimentAnalysisDataInput? = nil
        var minY: ExperimentAnalysisDataInput? = nil
        var maxY: ExperimentAnalysisDataInput? = nil
        var x: MutableDoubleArray? = nil
        var y: MutableDoubleArray? = nil
        
        for input in inputs {
            if input.asString == "mapWidth" {
                mapWidth = input
            }
            else if input.asString == "minX" {
                minX = input
            }
            else if input.asString == "maxX" {
                maxX = input
            }
            else if input.asString == "mapHeight" {
                mapHeight = input
            }
            else if input.asString == "minY" {
                minY = input
            }
            else if input.asString == "maxY" {
                maxY = input
            }
            else if input.asString == "x" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    x = data
                default:
                    throw SerializationError.genericError(message: "Error: Input x for map module has to be a buffer.")
                }
            }
            else if input.asString == "y" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    y = data
                default:
                    throw SerializationError.genericError(message: "Error: Input y for map module has to be a buffer.")
                }
            }
            else if input.asString == "z" {
                switch input {
                case .buffer(buffer: _, data: let data, usedAs: _, keep: _):
                    z = data
                default:
                    throw SerializationError.genericError(message: "Error: Input z for map module has to be a buffer.")
                }
            }
            else {
                throw SerializationError.genericError(message: "Error: Unknown input for map module: \(input.asString).")
            }
        }
        
        guard mapWidth != nil else {
            throw SerializationError.genericError(message: "Error: Input mapWidth required for map module.")
        }
        self.mapWidth = mapWidth!
        
        guard minX != nil else {
            throw SerializationError.genericError(message: "Error: Input minX required for map module.")
        }
        self.minX = minX!
        
        guard maxX != nil else {
            throw SerializationError.genericError(message: "Error: Input maxX required for map module.")
        }
        self.maxX = maxX!
        
        guard mapHeight != nil else {
            throw SerializationError.genericError(message: "Error: Input mapHeight required for map module.")
        }
        self.mapHeight = mapHeight!
        
        guard minY != nil else {
            throw SerializationError.genericError(message: "Error: Input minY required for map module.")
        }
        self.minY = minY!
        
        guard maxY != nil else {
            throw SerializationError.genericError(message: "Error: Input maxY required for map module.")
        }
        self.maxY = maxY!
        
        guard x != nil else {
            throw SerializationError.genericError(message: "Error: Input x required for map module.")
        }
        self.x = x!
        
        guard y != nil else {
            throw SerializationError.genericError(message: "Error: Input y required for map module.")
        }
        self.y = y!
        
        for output in outputs {
            if output.asString == "x" {
                outX = output
            } else if output.asString == "y" {
                outY = output
            } else if output.asString == "z" {
                outZ = output
            } else {
                throw SerializationError.genericError(message: "Error: Unknown output for reduce module: \(output.asString).")
            }
        }
        
        try super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        guard let mapWidth = self.mapWidth.getSingleValueAsInt() else {
            return
        }
        guard let minX = self.minX.getSingleValue() else {
            return
        }
        guard let maxX = self.maxX.getSingleValue() else {
            return
        }
        guard let mapHeight = self.mapHeight.getSingleValueAsInt() else {
            return
        }
        guard let minY = self.minY.getSingleValue() else {
            return
        }
        guard let maxY = self.maxY.getSingleValue() else {
            return
        }
        let x = self.x.data
        let y = self.y.data
        let z = self.z?.data
        
        var n = min(x.count, y.count)
        if let nz = z?.count {
            n = min(n, nz)
        }
        
        var zSumOut = [Double](repeating: 0, count: mapWidth*mapHeight)
        var nOut = [Int](repeating: 0, count: mapWidth*mapHeight)
        
        for i in 0..<n {
            let thisX = x[i]
            let thisY = y[i]
            let thisZ = z?[i] ?? 0.0
            if !(thisX.isFinite && thisY.isFinite && thisZ.isFinite) {
                continue
            }
            let xd = Double(mapWidth-1)*(thisX-minX)/(maxX-minX)
            let xi = Int(round(xd))
            let yd = Double(mapHeight-1)*(thisY-minY)/(maxY-minY)
            let yi = Int(round(yd))
            if (xi < 0 || xi >= mapWidth || yi < 0 || yi >= mapHeight) {
                continue
            }
            let index = xi + yi*mapWidth
            if zMode != .count {
                zSumOut[index] += thisZ
            }
            nOut[index] += 1
        }
        
        var resX = [Double]()
        var resY = [Double]()
        var resZ = [Double]()
        for yi in 0..<mapHeight {
            for xi in 0..<mapWidth {
                resX.append(minX + Double(xi)*(maxX-minX)/Double(mapWidth-1))
                resY.append(minY + Double(yi)*(maxY-minY)/Double(mapHeight-1))
                let index = yi*mapWidth+xi
                switch zMode {
                    case .count: resZ.append(Double(nOut[index]))
                    case .sum: resZ.append(Double(zSumOut[index]))
                    case .average: resZ.append(Double(zSumOut[index]) / Double(nOut[index]))
                }
            }
        }
                
        if let xOut = outX {
            switch xOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(resX)
            }
        }
        
        if let yOut = outY {
            switch yOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(resY)
            }
        }
        
        if let zOut = outZ {
            switch zOut {
            case .buffer(buffer: let buffer, data: _, usedAs: _, append: _):
                buffer.appendFromArray(resZ)
            }
        }
        
    }
}
