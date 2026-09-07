//
//  ExperimentAnalysisModule.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

///A module's inputs and outputs assigned to the slots of its ioMapping by the same algorithm that validated
///them (IOMappingValidation, mirroring Android's ioBlockParser), so each slot name is defined once
struct MappedAnalysisIO {
    fileprivate var inputsBySlot: [String: [ExperimentAnalysisDataInput]] = [:]
    fileprivate var outputsBySlot: [String: [ExperimentAnalysisDataOutput]] = [:]

    ///All inputs assigned to the slot, in fill order (several for a repeating group)
    func inputs(_ slot: AnalysisIOSlot) -> [ExperimentAnalysisDataInput] {
        return inputsBySlot[slot.name.lowercased()] ?? []
    }

    func input(_ slot: AnalysisIOSlot) -> ExperimentAnalysisDataInput? {
        return inputs(slot).first
    }

    ///The buffer data of the input assigned to the slot, nil if the slot is unfilled or holds a value
    func data(_ slot: AnalysisIOSlot) -> MutableDoubleArray? {
        guard case .buffer(buffer: _, data: let data, usedAs: _, keep: _)? = input(slot) else {
            return nil
        }
        return data
    }

    ///All outputs assigned to the slot, in fill order (several for a repeating group)
    func outputs(_ slot: AnalysisIOSlot) -> [ExperimentAnalysisDataOutput] {
        return outputsBySlot[slot.name.lowercased()] ?? []
    }

    func output(_ slot: AnalysisIOSlot) -> ExperimentAnalysisDataOutput? {
        return outputs(slot).first
    }

    ///The buffer of the output assigned to the slot, nil if the slot is unfilled
    func buffer(_ slot: AnalysisIOSlot) -> DataBuffer? {
        guard case .buffer(buffer: let buffer, data: _, usedAs: _, append: _)? = output(slot) else {
            return nil
        }
        return buffer
    }
}

/**
 Abstract class providing an Analysis module for Experiments
 */
class ExperimentAnalysisModule {
    ///The slot table inputs and outputs are validated against (see IOMappingValidation). Every module overrides it
    ///with the same slot constants its init consumes; a unit test walks the classMap to catch omissions.
    class var ioMapping: AnalysisIOMapping? { return nil }

    ///Assigns inputs and outputs to the slots of ioMapping; the file was already validated against it in the factory
    static func mapIO(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput]) throws -> MappedAnalysisIO {
        guard let mapping = ioMapping else {
            throw SerializationError.genericError(message: "Module declares no io mapping.")
        }
        var mapped = MappedAnalysisIO()
        let inputIndices = try IOMappingValidation.validate(kind: "input", slots: mapping.inputs, items: inputs.map { input in
            switch input {
            case .buffer(buffer: let buffer, data: _, usedAs: let usedAs, keep: _):
                return IOMappingValidation.Item(usedAs: usedAs, text: buffer.name, isValue: false, isEmpty: false)
            case .value(value: let value, usedAs: let usedAs):
                return IOMappingValidation.Item(usedAs: usedAs, text: String(value), isValue: true, isEmpty: false)
            }
        })
        for (input, index) in zip(inputs, inputIndices) {
            mapped.inputsBySlot[mapping.inputs[index].name.lowercased(), default: []].append(input)
        }
        let outputIndices = try IOMappingValidation.validate(kind: "output", slots: mapping.outputs, items: outputs.map { output in
            switch output {
            case .buffer(buffer: let buffer, data: _, usedAs: let usedAs, append: _):
                return IOMappingValidation.Item(usedAs: usedAs, text: buffer.name, isValue: false, isEmpty: false)
            }
        })
        for (output, index) in zip(outputs, outputIndices) {
            mapped.outputsBySlot[mapping.outputs[index].name.lowercased(), default: []].append(output)
        }
        return mapped
    }

    let inputs: [ExperimentAnalysisDataInput]
    let outputs: [ExperimentAnalysisDataOutput]

    ///A module whose outputs are all static executes once (Android: AnalysisModule.isStatic/executed). Accepted
    ///side effect: a skipped module no longer clears its keep=false inputs either.
    let isStatic: Bool
    private var executed = false
    
    var cycles: [(Int,Int)] = []
    
    var analysisTime: TimeInterval = 0.0
    var analysisLinearTime: TimeInterval = 0.0
    var analysisTimeOffset1970: TimeInterval = 0.0
    var analysisLinearTimeOffset1970: TimeInterval = 0.0

    let attributeContainer: AttributeContainer
    
    required init(inputs: [ExperimentAnalysisDataInput], outputs: [ExperimentAnalysisDataOutput], additionalAttributes: AttributeContainer) throws {
        self.inputs = inputs
        self.outputs = outputs
        self.attributeContainer = additionalAttributes
        self.isStatic = outputs.allSatisfy { $0.isStatic }
    }

    ///Re-arms a skipped static module when a buffer it uses was reset by clear-data (Android: Analysis.java notifyUpdate)
    func notifyBuffersReset(_ resetBuffers: Set<ObjectIdentifier>) {
        guard executed else { return }

        let touched = inputs.contains { input in
            guard let buffer = input.dataBuffer else { return false }
            return resetBuffers.contains(ObjectIdentifier(buffer))
        } || outputs.contains { resetBuffers.contains(ObjectIdentifier($0.dataBuffer)) }

        if touched {
            executed = false
        }
    }
    
    func setCycles(cycles: [(Int,Int)]) {
        self.cycles = cycles
    }
    
    /**
     Updates immediately.
     */
    func setNeedsUpdate(experimentTime: TimeInterval, linearTime: TimeInterval, experimentReference1970: TimeInterval, linearReference1970: TimeInterval) {
        if Thread.isMainThread {
            print("Analysis should run in the background!")
        }

        guard !(isStatic && executed) else {
            return
        }

        self.analysisTime = experimentTime
        self.analysisLinearTime = linearTime
        self.analysisTimeOffset1970 = experimentReference1970
        self.analysisLinearTimeOffset1970 = linearReference1970
        retainData()
        willUpdate()
        update()
        didUpdate()

        //Locks static outputs even if the module wrote nothing
        for output in outputs {
            output.markSet()
        }

        executed = true
    }
    
    func retainData() {
        for input in inputs {
            input.retainData()
        }
    }
    
    #if DEBUG
    func debug_noteInputs(inputs: AnyObject) {
        print("\(type(of: self)) inputs: \(inputs)")
    }
    
    func debug_noteOutputs(outputs: AnyObject) {
        print("\(type(of: self)) outputs: \(outputs)")
    }
    #endif
    
    func willUpdate() {
        
    }
    
    func didUpdate() {

    }
    
    func update() {
        
    }
    
    func clearOutputs() {
        for output in outputs {
            output.clear()
        }
    }
    
    func clearInputs() {
        for input in inputs {
            input.clear()
        }
    }
    
}

class AutoClearingExperimentAnalysisModule : ExperimentAnalysisModule {
    override func willUpdate() {
        clearInputs()
        clearOutputs()
    }
}

extension ExperimentAnalysisModule: Equatable {
    static func ==(lhs: ExperimentAnalysisModule, rhs: ExperimentAnalysisModule) -> Bool {
        return lhs.attributeContainer == rhs.attributeContainer &&
            lhs.inputs == rhs.inputs &&
            lhs.outputs == rhs.outputs
    }
}
