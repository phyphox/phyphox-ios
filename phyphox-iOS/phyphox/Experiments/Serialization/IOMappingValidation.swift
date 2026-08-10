//
//  IOMappingValidation.swift
//  phyphox
//
//  Created by Sebastian Staacks on 10.08.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

//Validation of the input/output mapping mechanism of the file format, mirroring Android's
//ioBlockParser (PhyphoxFile.java): each input and output of an analysis module - and each output
//of an input element - is checked against a slot table stating whether the mapping attribute
//(as/component) is required for that slot, how many tags may fill it, and whether a literal value
//or the empty type is permitted. A file breaking any of these is refused with the same messages
//Android uses, instead of silently assigning positionally (see input-output-component-validation,
//analysis-slot-constraints-unenforced and rules.yml, output-component-validation, in phyphox-docs).
//
//This file holds only the algorithm. The slot tables live where their names are consumed, so the
//vocabulary is not defined in two places: each analysis module declares its table by overriding
//ExperimentAnalysisModule.ioMapping in its own file (initially generated from the machine-readable
//specification, phyphox-docs/spec/analysis.yml), and the component tables of the input elements
//sit next to their handlers in InputElementHandler.swift.

struct AnalysisIOSlot {
    let name: String
    let asRequired: Bool
    let repeatOffset: Int //-1: not part of a repeating group
    let valueAllowed: Bool
    let emptyAllowed: Bool
    let minCount: Int
    let maxCount: Int //0: unlimited
}

struct AnalysisIOMapping {
    let inputs: [AnalysisIOSlot]
    let outputs: [AnalysisIOSlot]
}

enum IOMappingValidation {

    struct Item {
        let usedAs: String //empty if the mapping attribute is absent
        let text: String   //buffer name or literal, for error messages
        let isValue: Bool
        let isEmpty: Bool
    }

    ///Validates one list of inputs or outputs against its slot table and returns, per item, the
    ///index of the slot it maps to (repeating groups report the slot inside the table). Throws
    ///with Android's exact wording when the file breaks the mapping rules.
    @discardableResult static func validate(kind: String, slots: [AnalysisIOSlot], items: [Item]) throws -> [Int] {
        var filled = [Bool]()
        var counts = [Int](repeating: 0, count: slots.count)
        var mappingIndices = [Int]()
        let repeatPeriod = (slots.last?.repeatOffset ?? -1) + 1

        func ensureSize(_ index: Int) {
            while filled.count <= index {
                filled.append(false)
            }
        }

        for item in items {
            var targetIndex = -1
            var mappingIndex = -1

            if !item.usedAs.isEmpty {
                //An explicit mapping has been given: find it, folding case
                let folded = item.usedAs.lowercased()
                for (i, slot) in slots.enumerated() where slot.name.lowercased() == folded {
                    targetIndex = i
                    mappingIndex = i
                    break
                }
                guard mappingIndex >= 0 else {
                    throw ElementHandlerError.message("Could not find mapping for \(kind) \"\(item.usedAs)\".")
                }
                ensureSize(targetIndex)
                if filled[targetIndex] || slots[mappingIndex].repeatOffset >= 0 {
                    if slots[mappingIndex].repeatOffset >= 0 {
                        //Part of a repeating group: place it in the last group, opening a new one
                        //if that slot is taken (the input and output paths step differently on
                        //Android - both are mirrored here)
                        if kind == "input" {
                            while targetIndex - slots[mappingIndex].repeatOffset + repeatPeriod < filled.count {
                                targetIndex += repeatPeriod
                            }
                            ensureSize(targetIndex)
                            while filled[targetIndex] {
                                targetIndex += repeatPeriod
                                ensureSize(targetIndex)
                            }
                        } else if filled[targetIndex] {
                            targetIndex = slots.count + slots[mappingIndex].repeatOffset
                            ensureSize(targetIndex)
                            while filled[targetIndex] {
                                targetIndex += repeatPeriod
                                ensureSize(targetIndex)
                            }
                        }
                    } else {
                        throw ElementHandlerError.message("The \(kind) \"\(item.usedAs)\" has already been defined.")
                    }
                }
            } else {
                //No explicit mapping: fill the first free slot that does not require the attribute
                var firstRepeatable = -1
                for (i, slot) in slots.enumerated() where !slot.asRequired {
                    if slot.repeatOffset >= 0 && firstRepeatable < 0 {
                        firstRepeatable = i
                    }
                    ensureSize(i)
                    if !filled[i] {
                        targetIndex = i
                        mappingIndex = i
                        break
                    }
                }
                if targetIndex < 0 {
                    if firstRepeatable >= 0 {
                        targetIndex = slots.count
                        var repeatIndex = 0
                        ensureSize(targetIndex)
                        while filled[targetIndex] || slots[firstRepeatable + repeatIndex].asRequired {
                            targetIndex += 1
                            repeatIndex = (repeatIndex + 1) % repeatPeriod
                            ensureSize(targetIndex)
                        }
                        mappingIndex = firstRepeatable + repeatIndex
                    } else if kind == "input" {
                        throw ElementHandlerError.message("The non-mapped input from buffer \(item.text) could not be matched.")
                    } else {
                        throw ElementHandlerError.message("The non-mapped output could not be matched.")
                    }
                }
            }

            counts[mappingIndex] += 1
            ensureSize(targetIndex)
            filled[targetIndex] = true
            mappingIndices.append(mappingIndex)

            if item.isValue && !slots[mappingIndex].valueAllowed {
                throw ElementHandlerError.message("Value-type not allowed for \(kind) \"\(slots[mappingIndex].name)\".")
            }
            if item.isEmpty && !slots[mappingIndex].emptyAllowed {
                throw ElementHandlerError.message("Value-type not allowed for \(kind) \"\(slots[mappingIndex].name)\".")
            }
        }

        for (i, slot) in slots.enumerated() {
            if slot.maxCount > 0 && counts[i] > slot.maxCount {
                throw ElementHandlerError.message("A maximum of \(slot.maxCount) \(kind)s was expected for \(slot.name) but \(counts[i]) were found.")
            }
            if counts[i] < slot.minCount {
                throw ElementHandlerError.message("A minimum of \(slot.minCount) \(kind)s was expected for \(slot.name) but \(counts[i]) were found.")
            }
        }

        return mappingIndices
    }

    ///Validates the inputs and outputs of an analysis module against the slot table the module
    ///itself declares (ExperimentAnalysisModule.ioMapping).
    static func validate(mapping: AnalysisIOMapping, inputs: [ExperimentAnalysisDataInputDescriptor], outputs: [ExperimentAnalysisDataOutputDescriptor]) throws {
        try validate(kind: "input", slots: mapping.inputs, items: inputs.map { descriptor in
            switch descriptor {
            case .buffer(name: let name, usedAs: let usedAs, keep: _):
                return Item(usedAs: usedAs, text: name, isValue: false, isEmpty: false)
            case .value(value: let value, usedAs: let usedAs):
                return Item(usedAs: usedAs, text: String(value), isValue: true, isEmpty: false)
            case .empty(usedAs: let usedAs):
                return Item(usedAs: usedAs, text: "", isValue: false, isEmpty: true)
            }
        })
        try validate(kind: "output", slots: mapping.outputs, items: outputs.map { descriptor in
            switch descriptor {
            case .buffer(name: let name, usedAs: let usedAs, append: _):
                return Item(usedAs: usedAs, text: name, isValue: false, isEmpty: false)
            }
        })
    }

    ///Validates the outputs of an input element (sensor, location, audio, depth, camera) against
    ///the components allowed for it and returns the outputs with their component names normalized
    ///to the canonical slot name, so an unnamed output carries the slot it filled.
    static func validateComponents(element: String, slots: [AnalysisIOSlot], outputs: [SensorOutputDescriptor]) throws -> [SensorOutputDescriptor] {
        let mappingIndices = try validate(kind: "output", slots: slots, items: outputs.map {
            Item(usedAs: $0.component ?? "", text: $0.bufferName, isValue: false, isEmpty: false)
        })
        return zip(outputs, mappingIndices).map { output, index in
            SensorOutputDescriptor(component: slots[index].name, bufferName: output.bufferName)
        }
    }
}
