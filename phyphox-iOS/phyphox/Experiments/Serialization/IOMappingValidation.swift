//
//  IOMappingValidation.swift
//  phyphox
//
//  Created by Sebastian Staacks on 10.08.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

//Validates as/component mappings against slot tables, mirroring Android's ioBlockParser and its exact messages
//(output-component-validation in phyphox-docs). Tables live with their consumers: ExperimentAnalysisModule.ioMapping
//per module and the input elements' component tables in InputElementHandler.swift.

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

    ///Validates one list against its slot table and returns each item's slot index, throwing with Android's exact wording
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
                //Explicit mapping: find its slot, folding case
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
                        //Repeating group: last group, or a new one if taken (Android steps input and output differently)
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

    ///Validates a module's inputs and outputs against the slot table it declares (ExperimentAnalysisModule.ioMapping)
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

    ///Validates an input element's outputs against its component table, normalizing component names to the slot filled
    static func validateComponents(element: String, slots: [AnalysisIOSlot], outputs: [SensorOutputDescriptor]) throws -> [SensorOutputDescriptor] {
        let mappingIndices = try validate(kind: "output", slots: slots, items: outputs.map {
            Item(usedAs: $0.component ?? "", text: $0.bufferName, isValue: false, isEmpty: false)
        })
        return zip(outputs, mappingIndices).map { output, index in
            SensorOutputDescriptor(component: slots[index].name, bufferName: output.bufferName)
        }
    }
}
