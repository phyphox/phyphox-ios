//
//  ExperimentGraphUtilities.swift
//  phyphox
//
//  Created by Jonas Gessner on 07.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

struct ExperimentGraphUtilities {
    static func getTicks(_ min: Double, max: Double, maxTicks: Int, log: Bool) -> [Double] {
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

        let stepFactor = pow(10.0, floor(log10(range))-1)
        var step = 1.0
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

        let first = ceil(min/step)*step

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
