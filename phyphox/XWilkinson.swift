//
//  XWilkinson.swift
//  phyphox
//
//  Created by Jonas Gessner on 25.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

//http://vis.stanford.edu/files/2010-TickLabels-InfoVis.pdf

import Foundation

final class Label: SequenceType, CustomStringConvertible {
    var min, max, step, score: Double!
    
    var description: String {
        get {
            let formatter = NSNumberFormatter()
            formatter.alwaysShowsDecimalSeparator = true
            formatter.numberStyle = .DecimalStyle
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 2
            
            
            func format(d: Double) -> String {
                return formatter.stringFromNumber(NSNumber(double: d))!
            }
            
            var s = "(Score: \(format(score))) "
            for x in min.stride(through: max, by: step) {
                s += "\t\(format(x))"
            }
            
            return s
        }
    }
    
    func generate() -> IndexingGenerator<[Double]> {
        return getList().generate()
    }
    
    func getList() -> [Double] {
        var list = [Double]()
        for x in min.stride(to: max, by: step) {
            list.append(x)
        }
        return list;
    }
    
    func getRelativeList() -> [Double] {
        var list = [Double]()
        let total = max-min
        
        for x in min.stride(to: max, by: step) {
            list.append(x/total)
        }
        return list;
    }
}

final class XWilkinson {
    private let Q: [Double] // Initial step sizes which we use as seed of generator
    private let base: Double // Number base used to calculate logarithms
    private let w: [Double] // scale-goodness weights for simplicity, coverage, density, legibility
    private let eps: Double // can be injected via c'tor depending on your application, default is 1e-10
    
    var loose = false // Loose flag
    var clipToBounds = false
    
    init(Q: [Double], base: Double, w: [Double], eps: Double) {
        self.w = w;
        self.Q = Q;
        self.base = base;
        self.eps = eps;
    }
    
    convenience init(Q: [Double], base: Double) {
        self.init(Q: Q, base: base, w: [0.25, 0.2, 0.5, 0.05], eps: 1e-10)
    }
    
    class func base10() -> XWilkinson {
        return XWilkinson(Q: [1, 5, 2, 2.5, 4, 3], base: 10);
    }
    
    class func base2() -> XWilkinson {
        return XWilkinson(Q: [1.0], base: 2);
    }
    
    class func base16() -> XWilkinson {
        return XWilkinson(Q: [1.0, 2, 4, 8], base: 16);
    }
    
    // calculation of scale-goodness
    private func w(s: Double, c: Double, d: Double, l: Double) -> Double {
        let a = w[0]*s + w[1]*c
        let b = w[2]*d + w[3]*l
        return a + b
    }
    
    private func logB(a: Double) -> Double {
        return log(a)/log(base);
    }
    
    
    /*
     * a mod b for float numbers (reminder of a/b)
     */
    private func flooredMod(a: Double, n: Double) -> Double {
        return a - n * floor(a / n)
    }
    
    private func v(min: Double, max: Double, step: Double) -> Double {
        return (flooredMod(min, n: step) < eps && min <= 0 && max >= 0) ? 1.0 : 0.0
    }
    
    private func simplicity(i: Int, j: Int, min: Double, max: Double, step: Double) -> Double {
        if (Q.count > 1) {
            return 1.0 - Double(i) / Double(Q.count - 1) - Double(j) + v(min, max: max, step: step)
        }
        else {
            return 1.0 - Double(j) + v(min, max: max, step: step)
        }
    }
    
    private func simplicity_max(i: Int, j: Int) -> Double {
        if (Q.count > 1) {
            return 1.0 - Double(i) / Double(Q.count - 1) - Double(j) + 1.0
        }
        else {
            return 1.0 - Double(j) + 1.0
        }
    }
    
    private func coverage(dmin: Double, dmax: Double, lmin: Double, lmax: Double) -> Double {
        let a = dmax - lmax;
        let b = dmin - lmin;
        let c = 0.1 * (dmax - dmin);
        return 1.0 - 0.5 * ((a*a + b*b) / (c*c));
    }
    
    private func coverage_max(dmin: Double, dmax: Double, span: Double) -> Double {
        let range = dmax - dmin;
        if (span > range) {
            let half = (span - range) / 2.0;
            let r = 0.1 * range;
            return 1.0 - half * half / (r * r);
        } else {
            return 1.0;
        }
    }
    
    
    /*
     *
     * @param k		number of labels
     * @param m		number of desired labels
     * @param dmin	data range minimum
     * @param dmax	data range maximum
     * @param lmin	label range minimum
     * @param lmax	label range maximum
     * @return		density
     *
     * k-1 number of intervals between labels
     * m-1 number of intervals between desired number of labels
     * r   label interval length/label range
     * rt  desired label interval length/actual range
     */
    private func density(k: Int, m: Int, dmin: Double, dmax: Double, lmin: Double, lmax: Double) -> Double {
        let r = Double(k - 1) / (lmax - lmin);
        let rt = Double(m - 1) / (max(lmax, dmax) - min(lmin, dmin));
        return 2.0 - max(r / rt, rt / r);   // return 1-Math.max(r/rt, rt/r); (paper is wrong)
    }
    
    private func density_max(k: Int, m: Int) -> Double {
        if (k >= m) {
            return 2.0 - Double((k - 1) / (m - 1))       // return 2-(k-1)/(m-1); (paper is wrong)
        } else {
            return 1.0
        }
    }
    
    private func legibility(min: Double, max: Double, step: Double) -> Double {
        return 1.0; // Maybe later more...
    }
    
    
    /**
     *
     * @param dmin data range min
     * @param dmax data range max
     * @param m    desired number of labels
     *
     * @return XWilkinson.Label
     */
    func search(dmin: Double, dmax: Double, m: Int) -> Label {
        let best = Label()
        
        var bestScore = -2.0;
        var sm: Double = 0.0, dm: Double = 0.0, cm: Double = 0.0, delta: Double = 0.0
        var j = 1;
        
        let formatter = NSNumberFormatter()
        formatter.alwaysShowsDecimalSeparator = true
        formatter.numberStyle = .DecimalStyle
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        formatter.minimumIntegerDigits = 2
        
        main_loop:
            while (j < Int.max) {
                for _i in 0..<Q.count {
                    let i = _i + 1;
                    let q = Q[_i];
                    
                    sm = simplicity_max(i, j: j);
                    
                    //print("i: \(i) q: \(q) sm: \(sm)")
                    
                    //print("w: \(w(sm, c: 1, d: 1, l: 1)) bestScore: \(bestScore)")
                    if (w(sm, c: 1, d: 1, l: 1) < bestScore) {
                        break main_loop;
                    }
                    
                    //here: equal
                    
                    var k = 2;
                    
                    while (k < Int.max) {
                        dm = density_max(k, m: m);
//                        print("k: \(k) m: \(m)")
//                        print("dm \(dm)")
//
//                        print("sm: \(formatter.stringFromNumber(NSNumber(double: sm))!) dm: \(formatter.stringFromNumber(NSNumber(double: dm))!)")
//                        print("w: \(formatter.stringFromNumber(NSNumber(double: w1))!) bestScore: \(formatter.stringFromNumber(NSNumber(double: bestScore))!)")
                        
                        if (w(sm, c: 1, d: dm, l: 1) < bestScore) {
                            //print("break: k: \(k) bestScore: \(formatter.stringFromNumber(NSNumber(double: bestScore))!) w: \(formatter.stringFromNumber(NSNumber(double: w1))!)")
                            break;
                        }
                        
                        delta = (dmax - dmin) / Double(k + 1) / (Double(j) * q);
                        var z = Int(ceil(logB(delta)))
                        
//                        print("z: \(z)")
                        while (z < Int.max) {
                            let step = Double(j) * q * pow(base, Double(z));
                            
                            cm = coverage_max(dmin, dmax: dmax, span: step * Double(k - 1));
                            
                            //print("cm: \(formatter.stringFromNumber(NSNumber(double: cm))!)")
                            if (w(sm, c: cm, d: dm, l: 1) < bestScore) {
                                //print("break: z: \(z) bestScore: \(formatter.stringFromNumber(NSNumber(double: bestScore))!)")
                                break;
                            }
                            
                            let min_start = Int(floor(dmax / step - Double(k - 1))) * j;
                            let max_start = Int(ceil(dmin / step)) * j;
                            
                            //print("min_start: \(min_start) max_start: \(max_start)")
                            
                            func format(d: Double) -> String {
                                return formatter.stringFromNumber(NSNumber(double: d))!
                            }
                            
                            if max_start >= min_start {
                                for start in min_start...max_start {
                                    let lmin = Double(start) * step / Double(j);
                                    let lmax = lmin + step * Double(k - 1);
                                    let c = coverage(dmin, dmax: dmax, lmin: lmin, lmax: lmax);
                                    let s = simplicity(i, j: j, min: lmin, max: lmax, step: step);
                                    let d = density(k, m: m, dmin: dmin, dmax: dmax, lmin: lmin, lmax: lmax);
                                    let l = legibility(lmin, max: lmax, step: step);
                                    let score = w(s, c: c, d: d, l: l);
                                    
//                                    print("i: \(i) j: \(j) lmin: \(format(lmin)) lmax: \(format(lmax)) step: \(step) s: \(format(s))")
//                                    print("score: \(format(score)) d: \(format(d)) c: \(format(c)) l: \(format(l))")
//                                    print("bestScore: \(format(bestScore)) loose: \(loose) dmin: \(format(dmin)) dmax: \(format(dmax))")
                                    // later legibility logic can be implemented hier
                                    
                                    if (score-DBL_EPSILON > bestScore && (!loose || (clipToBounds ? (lmin >= dmin && lmax <= dmax) : (lmin <= dmin && lmax >= dmax)))) {
//                                        print("update")
                                        best.min = lmin;
                                        best.max = lmax;
                                        best.step = step;
                                        best.score = score;
                                        bestScore = score;
                                    }
                                }
                            }
                            
                            z = z + 1;
                        }
                        k = k + 1;
                    }
                }
                j = j + 1;
        }
        
        return best
    }
    
    
    class func test() {
        var x = XWilkinson.base10();
        
        // First examples taken from the paper pg 6, Fig 4
        x.loose = true;
        print(x.search(-98.0, dmax: 18.0, m: 3));
        
        x.loose = false;
        print(x.search(-98.0, dmax: 18.0, m: 3));
        
        print();
        
        x.loose = true;
        print(x.search(-1.0, dmax: 200.0, m: 3));
        x.loose = false;
        print(x.search(-1.0, dmax: 200.0, m: 3));
        
        print();
        
        x.loose = true;
        print(x.search(119.0, dmax: 178.0, m: 3));
        x.loose = false;
        print(x.search(119.0, dmax: 178.0, m: 3));
        
        print();
        
        x.loose = true;
        print(x.search(-31.0, dmax: 27.0, m: 4));
        x.loose = false;
        print(x.search(-31.0, dmax: 27.0, m: 3));
        
        print();
        
        x.loose = true;
        print(x.search(-55.45, dmax: -49.99, m: 2));
        x.loose = false;
        print(x.search(-55.45, dmax: -49.99, m: 3));
        
        print();
        x.loose = false;
        print(x.search(0, dmax: 100, m: 2));
        print(x.search(0, dmax: 100, m: 3));
        print(x.search(0, dmax: 100, m: 4));
        print(x.search(0, dmax: 100, m: 5));
        print(x.search(0, dmax: 100, m: 6));
        print(x.search(0, dmax: 100, m: 7));
        print(x.search(0, dmax: 100, m: 8));
        print(x.search(0, dmax: 100, m: 9));
        print(x.search(0, dmax: 100, m: 10));
        
        print("Some additional tests: Testing with base2");
        x = XWilkinson.base2();
        print(x.search(0, dmax: 32, m: 8));
       /*
        print("Quick experiment with minutes: Check the logic");
        x = XWilkinson.forMinutes();
        print(x.search(0, dmax: 240, m: 16));
        print(x.search(0, dmax: 240, m: 9));
        
        print("Quick experiment with minutes: Convert values to HH:mm");
        LocalTime start = LocalTime.now();
        LocalTime end = start.plusMinutes(245); // add 4 hrs 5 mins (245 mins) to the start
        
        int dmin = start.toSecondOfDay() / 60;
        int dmax = end.toSecondOfDay() / 60;
        if (dmin > dmax) {
            // if adding 4 hrs exceeds the midnight simply swap the values this is just an
            // example...
            int swap = dmin;
            dmin = dmax;
            dmax = swap;
        }
        print("dmin: " + dmin + " dmax: " + dmax);
        XWilkinson.Label labels = x.search(dmin, dmax, 15);
        print("labels");
        for (double time = labels.getMin(); time < labels.getMax(); time += labels.getStep()) {
            LocalTime lt = LocalTime.ofSecondOfDay(Double.valueOf(time).intValue() * 60);
            print(lt);
        }
     */
    }
}
