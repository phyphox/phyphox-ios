//
//  FormulaParser.swift
//  phyphox
//
//  Created by Sebastian Staacks on 18.04.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

protocol FormulaFunction {
    func apply (_ x: Double?, _ y: Double?) -> Double
}

protocol FormulaFunction1: FormulaFunction {
    func apply (_ x: Double) -> Double
}

extension FormulaFunction1  {
    func apply (_ x: Double?, _ y: Double?) -> Double {
        if let x2 = x {
            return apply(x2)
        } else {
            return Double.nan
        }
    }
}

protocol FormulaFunction2: FormulaFunction {
    func apply (_ x: Double, _ y: Double) -> Double
}

extension FormulaFunction2  {
    func apply (_ x: Double?, _ y: Double?) -> Double {
        if let x2 = x, let y2 = y {
            return apply(x2, y2)
        } else {
            return Double.nan
        }
    }
}

final class FormulaParser {
    var base: Source? = nil
    
    enum FormulaError: Error {
        case parseError(_ message: String)
        case executionError(_ message: String)
    }
    
    class Source {
        let node: FormulaNode?
        let index: Int?
        let single: Bool?
        let value: Double?
        
        init(_ node: FormulaNode) {
            self.node = node
            self.index = nil
            self.single = nil
            self.value = nil
        }
        
        init(index: Int, single: Bool) {
            self.node = nil
            self.index = index-1
            self.single = single
            self.value = nil
        }
        
        init(_ value: Double) {
            self.node = nil
            self.index = nil
            self.single = nil
            self.value = value
        }
        
        func get(buffers: [[Double]], i: Int) throws -> Double {
            if let node = self.node {
                return try node.calculate(buffers: buffers, i: i)
            } else if let value = self.value {
                return value
            } else if let index = self.index, let single = self.single {
                if index >= buffers.count {
                    throw FormulaError.executionError("Index too large.")
                }
                let buffer = buffers[index]
                if buffer.count == 0 {
                    throw FormulaError.executionError("Empty input.")
                }
                if single {
                    return buffer.last ?? Double.nan
                } else {
                    if (i >= buffer.count) {
                        throw FormulaError.executionError("Input too short.")
                    }
                    return buffer[i]
                }
            } else {
                throw FormulaError.executionError("Node without content.")
            }
        }
    }
    
    class FormulaNode {
        let function: FormulaFunction
        let in1: Source?
        let in2: Source?
        
        init(function: FormulaFunction, in1: Source?, in2: Source?) {
            self.function = function
            self.in1 = in1
            self.in2 = in2
        }
        
        func calculate(buffers: [[Double]], i: Int) throws -> Double {
            return try function.apply(in1?.get(buffers: buffers, i: i), in2?.get(buffers: buffers, i: i))
        }
    }
    
    
    
    class AddFunction: FormulaFunction2 {
        func apply(_ x: Double, _ y: Double) -> Double {
            return x + y
        }
    }
    
    class MultiplyFunction: FormulaFunction2 {
        func apply(_ x: Double, _ y: Double) -> Double {
            return x * y
        }
    }
    
    class SubtractFunction: FormulaFunction2 {
        func apply(_ x: Double, _ y: Double) -> Double {
            return x - y
        }
    }
    
    class DivideFunction: FormulaFunction2 {
        func apply(_ x: Double, _ y: Double) -> Double {
            return x / y
        }
    }
    
    class ModuloFunction: FormulaFunction2 {
        func apply(_ x: Double, _ y: Double) -> Double {
            return x.truncatingRemainder(dividingBy: y)
        }
    }
    
    class PowerFunction: FormulaFunction2 {
        func apply(_ x: Double, _ y: Double) -> Double {
            return pow(x, y)
        }
    }
    
    class MinusFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return -x
        }
    }
    
    class SqrtFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return sqrt(x)
        }
    }
    
    class SinFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return sin(x)
        }
    }
    
    class CosFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return cos(x)
        }
    }
    
    class TanFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return tan(x)
        }
    }
    
    class AsinFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return asin(x)
        }
    }
    
    class AcosFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return acos(x)
        }
    }
    
    class AtanFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return atan(x)
        }
    }
    
    class Atan2Function: FormulaFunction2 {
        func apply(_ x: Double, _ y: Double) -> Double {
            return atan2(x, y)
        }
    }
    
    class SinhFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return sinh(x)
        }
    }
    
    class CoshFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return cosh(x)
        }
    }
    
    class TanhFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return tanh(x)
        }
    }
    
    class ExpFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return exp(x)
        }
    }
    
    class LogFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return log(x)
        }
    }
    
    class AbsFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return abs(x)
        }
    }
    
    class SignFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            if x.isNaN {
                return Double.nan
            } else if x > 0 {
                return 1
            } else if x < 0 {
                return -1
            } else {
                return 0
            }
        }
    }
    
    class HeavisideFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            if x.isNaN {
                return Double.nan
            } else if x >= 0 {
                return 1
            } else {
                return 0
            }
        }
    }
    
    class RoundFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return round(x)
        }
    }
    
    class CeilFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return ceil(x)
        }
    }
    
    class FloorFunction: FormulaFunction1 {
        func apply(_ x: Double) -> Double {
            return floor(x)
        }
    }
    
    class MinFunction: FormulaFunction2 {
        func apply(_ x: Double, _ y: Double) -> Double {
            if x.isNaN || y.isNaN {
                return Double.nan
            }
            if x > y {
                return y
            } else {
                return x
            }
        }
    }
    
    class MaxFunction: FormulaFunction2 {
        func apply(_ x: Double, _ y: Double) -> Double {
            if x.isNaN || y.isNaN {
                return Double.nan
            }
            if x < y {
                return y
            } else {
                return x
            }
        }
    }
    
    private func parse(formula: String, start: String.Index, end: String.Index) throws -> Source? {
        var s = start
        var e = end
        
        if s == e {
            return nil
        }
        
        if formula[s] == "(" && formula[formula.index(before: e)] == ")" {
            var innerBracket = 1
            var j = formula.index(after: s)
            while j != formula.index(before: e) {
                switch formula[j] {
                case "(": innerBracket += 1
                case ")": innerBracket -= 1
                default: break
                }
                if innerBracket == 0 {
                    break
                }
                
                j = formula.index(after: j)
            }
            if innerBracket > 0 {
                s = formula.index(after: s)
                e = formula.index(before: e)
            }
        }
        
        if formula[s] == "[" && formula[formula.index(before: e)] == "]" {
            var indexOnly = true
            var j = formula.index(after: s)
            while j != formula.index(before: e) {
                if formula[j] == "]" {
                    indexOnly = false
                    break
                }
                
                j = formula.index(after: j)
            }
            
            if indexOnly {
                s = formula.index(after: s)
                e = formula.index(before: e)
                
                let sub = formula.index(before: e)
                
                let single = formula[sub] != "_"
                if !single {
                    e = sub
                }
                
                if let index = Int(formula[s..<e]) {
                    if index < 1 {
                        throw FormulaError.parseError("Indices start at 1.")
                    }
                    return Source(index: index, single: single)
                } else {
                    throw FormulaError.parseError("Could not parse index: " + formula[s..<e])
                }
            }
        }
        
        if formula[s] == "-" {
            s = formula.index(after: s)
            return Source(FormulaNode(function: MinusFunction(), in1: try parse(formula: formula, start: s, end: e), in2: nil))
        }
        
        var s1 = s
        var s2 = s
        var e1 = e
        var e2 = e
        var function:FormulaFunction? = nil
        
        var previousPriority = 100
        var brackets = 0
        var cmd = ""
        
        var i = s
        while i != e {
            switch formula[i] {
            case "(": brackets += 1
            case ")": brackets -= 1
            default: break
            }
            
            if brackets == 0 {
                switch formula[i] {
                case "+":
                    if previousPriority >= 1 && (i == s || formula[formula.index(before: i)] != "e") {
                        previousPriority = 1
                        function = AddFunction()
                        s1 = s
                        e2 = e
                        e1 = i
                        s2 = formula.index(after: i)
                    }
                case "-":
                    let prev = formula[formula.index(before: i)]
                    if previousPriority >= 1 && prev != "e" && prev != "+" && prev != "*" && prev != "-" && prev != "/" && prev != "%" && prev != "^" {
                        previousPriority = 1
                        function = SubtractFunction()
                        s1 = s
                        e2 = e
                        e1 = i
                        s2 = formula.index(after: i)
                    }
                case "*":
                    if previousPriority >= 2 {
                        previousPriority = 2
                        function = MultiplyFunction()
                        s1 = s
                        e2 = e
                        e1 = i
                        s2 = formula.index(after: i)
                    }
                case "/":
                    if previousPriority >= 2 {
                        previousPriority = 2
                        function = DivideFunction()
                        s1 = s
                        e2 = e
                        e1 = i
                        s2 = formula.index(after: i)
                    }
                case "%":
                    if previousPriority >= 2 {
                        previousPriority = 2
                        function = ModuloFunction()
                        s1 = s
                        e2 = e
                        e1 = i
                        s2 = formula.index(after: i)
                    }
                case "^":
                    if previousPriority >= 3 {
                        previousPriority = 3
                        function = PowerFunction()
                        s1 = s
                        e2 = e
                        e1 = i
                        s2 = formula.index(after: i)
                    }
                default: break
                }
            }
            let numberContinuation: Bool
            if (i == s) {
                numberContinuation = false
            } else {
                let prev = formula[formula.index(before: i)]
                if cmd == "" && prev >= "0" && prev <= "9" {
                    numberContinuation = true
                } else {
                    numberContinuation = false
                }
            }
            if (!numberContinuation) && ((formula[i] >= "a" && formula[i] <= "z") || (cmd != "" && formula[i] >= "0" && formula[i] <= "9")) {
                if brackets == 0 {
                    cmd += String(formula[i])
                } else {
                    cmd = ""
                }
            } else {
                if cmd != "" {
                    
                    if formula[i] != "(" {
                        throw FormulaError.parseError("Function " + cmd  + " needs a parameter.")
                    }
                    
                    if previousPriority >= 4 {
                        s1 = formula.index(after: i)
                        e1 = formula.index(before: e)
                        s2 = e1
                        e2 = e1
                        
                        var innerBracket = 0
                        var j = formula.index(after: i)
                        while j != end {
                            if (formula[j] == ",") {
                                if innerBracket == 0 {
                                    e1 = j
                                    s2 = formula.index(after: j)
                                    e2 = formula.index(before: end)
                                }
                            } else if formula[j] == "(" {
                                innerBracket += 1
                            } else if formula [j] == ")" {
                                innerBracket -= 1
                            }
                            
                            j = formula.index(after: j)
                        }
                        
                        previousPriority = 4
                        
                        switch(cmd) {
                            case "sqrt": function = SqrtFunction()
                            case "sin": function = SinFunction()
                            case "cos": function = CosFunction()
                            case "tan": function = TanFunction()
                            case "asin": function = AsinFunction()
                            case "acos": function = AcosFunction()
                            case "atan": function = AtanFunction()
                            case "atan2": function = Atan2Function()
                            case "sinh": function = SinhFunction()
                            case "cosh": function = CoshFunction()
                            case "tanh": function = TanhFunction()
                            case "exp": function = ExpFunction()
                            case "log": function = LogFunction()
                            case "abs": function = AbsFunction()
                            case "sign": function = SignFunction()
                            case "heaviside": function = HeavisideFunction()
                            case "round": function = RoundFunction()
                            case "ceil": function = CeilFunction()
                            case "floor": function = FloorFunction()
                            case "min": function = MinFunction()
                            case "max": function = MaxFunction()
                            default: break;
                        }
                    }
                    
                    cmd = ""
                }
            }
            
            i = formula.index(after: i)
        }
        
        if brackets != 0 {
            throw FormulaError.parseError("Brackets do not match!")
        }
        
        if let fun = function {
            return Source(FormulaNode(function: fun, in1: try parse(formula: formula, start: s1, end: e1), in2: try parse(formula: formula, start: s2, end: e2)))
        } else {
            if let v = Double(formula[s..<e]) {
                return Source(v)
            } else  {
                throw FormulaError.parseError("No recognized operator and no parsable value: " + formula[s..<e])
            }
        }
    }
    
    init(formula: String) throws {
        let strippedFormula = formula.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\t", with: "").replacingOccurrences(of: "\n", with: "").lowercased()
        base = try parse(formula: strippedFormula, start: strippedFormula.startIndex, end: strippedFormula.endIndex)
    }
    
    public func execute(buffers: [[Double]]) -> [Double] {
        guard let parsed = base else {
            return []
        }
        var n = 0
        for buffer in buffers {
            n = max(buffer.count, n)
        }
        
        var result: [Double] = []
        for i in 0..<n {
            do {
                result.append(try parsed.get(buffers: buffers, i: i))
            } catch {
                break
            }
        }
        
        return result
    }
}
