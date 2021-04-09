//
//  ExperimentGraphUtilities.swift
//  phyphox
//
//  Created by Jonas Gessner on 07.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

protocol GraphViewModule {
    func clearData()
}

struct GraphPoint2D<T: Numeric> {
    let x: T
    let y: T
}

struct GraphPoint3D<T: Numeric> {
    let x: T
    let y: T
    let z: T
}

extension GraphPoint2D {
    static var zero: GraphPoint2D {
        return GraphPoint2D(x: 0, y: 0)
    }
}

extension GraphPoint3D {
    static var zero: GraphPoint3D {
        return GraphPoint3D(x: 0, y: 0, z: 0)
    }
}

struct GLcolor {
    let r, g, b, a: Float
}

struct GraphGrid {
    let xGridLines: [GraphGridLine]
    let yGridLines: [GraphGridLine]
    let zGridLines: [GraphGridLine]
    let systemTimeOffsetX: Double
    let systemTimeOffsetY: Double
}

struct GraphGridLine {
    let absoluteValue: Double
    let relativeValue: CGFloat
}

struct PauseRanges {
    let xPauseRanges: [PauseRange]
    let yPauseRanges: [PauseRange]
}

struct PauseRange {
    let relativeBegin: CGFloat
    let relativeEnd: CGFloat
}

struct TimeReferenceSet {
    let index: Int
    let count: Int
    let referenceIndex: Int
    let experimentTime: Double
    let systemTime: Date
    let totalPauseGap: Double
    let isPaused: Bool
}

struct ExperimentGraphUtilities {
    static func getTimeStepFromRange(range: Double, maxTics: Int) -> Double {
        let baseUnit: Double
        if range < 60 {
            baseUnit = 1.0
        } else if range < 60*60 {
            baseUnit = 60.0
        } else if range < 24*60*60 {
            baseUnit = 60.0*60.0
        } else {
            baseUnit = 24*60*60
        }
        
        let steps = range / baseUnit
        let step: Double
        
        let maxTicsDouble = Double(maxTics)
        if steps * 12 <= maxTicsDouble {
            step = baseUnit / 12.0
        } else if steps  * 6 <= maxTicsDouble {
            step = baseUnit / 6.0
        } else if steps * 4 <= maxTicsDouble {
            step = baseUnit / 4.0
        } else if steps * 2 <= maxTicsDouble {
            step = baseUnit / 2.0
        } else if steps <= maxTicsDouble {
            step = baseUnit
        } else if steps <= maxTicsDouble * 2.0 {
            step = baseUnit * 2.0
        } else if steps <= maxTicsDouble * 5.0 {
            step = baseUnit * 5.0
        } else if steps <= maxTicsDouble * 10.0 {
            step = baseUnit * 10.0
        } else if steps <= maxTicsDouble * 20.0 {
            step = baseUnit * 20.0
        } else if steps <= maxTicsDouble * 50.0 {
            step = baseUnit * 50.0
        } else if steps <= maxTicsDouble * 100.0 {
            step = baseUnit * 100.0
        } else if steps <= maxTicsDouble * 200.0 {
            step = baseUnit * 200.0
        } else if steps <= maxTicsDouble * 500.0 {
            step = baseUnit * 500.0
        } else {
            step = baseUnit * 1000.0
        }
        if step < 1.0 {
            return 1.0
        }
        return step
    }
    
    static func getTicks(_ min: Double, max: Double, maxTicks: Int, log: Bool, isTime: Bool, systemTimeOffset: Double) -> [Double] {
        guard max > min && min.isFinite && max.isFinite else {
            return []
        }

        var tickLocations = [Double]()
        tickLocations.reserveCapacity(maxTicks)

        if log {
            let expMax = exp(max)
            let expMin = exp(min)
            let logMax = log10(expMax)
            let logMin = log10(expMin)

            let digitRangeDouble = ceil(logMax)-floor(logMin)
            
            guard digitRangeDouble > Double(Int.min) && digitRangeDouble < Double(Int.max) else { return [] }
            
            let digitRange = Int(ceil(logMax)-floor(logMin))
            if digitRange < 1 {
                return []
            }

            var first: Double = pow(10, floor(logMin))

            var magStep = 1
            while digitRange > maxTicks * magStep {
                magStep += 1
            }
            let magFactor: Double = pow(10.0, Double(magStep))

            for _ in 0..<digitRange {
                if first > expMax || tickLocations.count >= maxTicks {
                    break
                }
                if first > expMin {
                    tickLocations.append(Double(first))
                }

                if digitRange < 4 {
                    if 2*first > expMax || tickLocations.count >= maxTicks {
                        break
                    }
                    if 2*first > expMin {
                        tickLocations.append(Double(2*first))
                    }
                }

                if digitRange < 3 {
                    if 5*first > expMax || tickLocations.count >= maxTicks {
                        break
                    }
                    if 5*first > expMin {
                        tickLocations.append(Double(5*first))
                    }
                }

                first *= magFactor
            }
            return tickLocations
        }

        let range = max-min

        var step = 1.0
        if isTime && systemTimeOffset > 0 {
            step = getTimeStepFromRange(range: range, maxTics: maxTicks)
        } else {
        
            let stepFactor = pow(10.0, floor(log10(range))-1)
            let steps = Int(range/stepFactor)

            if steps <= maxTicks {
                step = 1*stepFactor
            }
            else if steps <= maxTicks * 2 {
                step = 2*stepFactor
            }
            else if steps <= maxTicks * 5 {
                step = 5*stepFactor
            }
            else if steps <= maxTicks * 10 {
                step = 10*stepFactor
            }
            else if steps <= maxTicks * 20 {
                step = 20*stepFactor
            }
            else if steps <= maxTicks * 50 {
                step = 50*stepFactor
            }
            else if steps <= maxTicks * 100 {
                step = 100*stepFactor
            }
            else if steps <= maxTicks * 250 {
                step = 250*stepFactor
            }
            else if steps <= maxTicks * 500 {
                step = 500*stepFactor
            }
            else if steps <= maxTicks * 1000 {
                step = 1000*stepFactor
            }
            else if steps <= maxTicks * 2000 {
                step = 2000*stepFactor
            }
        }

        let first: Double
        if systemTimeOffset > 0 {
            let alignedOffset = systemTimeOffset + Double(TimeZone.current.secondsFromGMT())
            first = ceil((alignedOffset + min)/step)*step - alignedOffset
        } else {
            first = ceil(min/step)*step
        }
        
        var i = 0

        while true {
            let s = first+Double(i)*step

            if s > max || tickLocations.count >= maxTicks {
                break
            }

            tickLocations.append(s)
            i += 1
        }

        return tickLocations
    }
}
