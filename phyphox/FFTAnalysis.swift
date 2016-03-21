//
//  FFTAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Surge

public func fft(real input: [Double], imag i: [Double]) -> [Double] {
    var real = [Double](input)
    var imaginary = [Double](i)
    var splitComplex = DSPDoubleSplitComplex(realp: &real, imagp: &imaginary)
    
    let length = vDSP_Length(floor(log2(Float(input.count))))
    let radix = FFTRadix(kFFTRadix2)
    let weights = vDSP_create_fftsetupD(length, radix)
    vDSP_fft_zipD(weights, &splitComplex, 1, length, FFTDirection(FFT_FORWARD))
    
    var magnitudes = [Double](count: input.count, repeatedValue: 0.0)
    vDSP_zvmagsD(&splitComplex, 1, &magnitudes, 1, vDSP_Length(input.count))
    
    var normalizedMagnitudes = [Double](count: input.count, repeatedValue: 0.0)
    vDSP_vsmulD(sqrt(magnitudes), 1, [2.0 / Double(input.count)], &normalizedMagnitudes, 1, vDSP_Length(input.count))
    
    vDSP_destroy_fftsetupD(weights)
    
    return normalizedMagnitudes
}

final class FFTAnalysis: ExperimentAnalysisModule {
    //input size, power-of-two filled size, log2 of input size (integer)
    private var n: Int
    private var np2: Int
    private var logn: Int
    
    //Lookup table
    private var cosArray: [Double]
    private var sinArray: [Double]
    
    override init(inputs: [ExperimentAnalysisDataIO], outputs: [ExperimentAnalysisDataIO], additionalAttributes: [String : AnyObject]?) {
        n = inputs.first!.buffer!.size
        
        logn = Int(log(Double(n))/log(2.0))
        
        if (n != (1 << logn)) {
            logn++;
            np2 = (1 << logn); //power of two after zero filling
        }
        else {
            np2 = n; //n is already power of two
        }
        
        cosArray = [Double](count: np2/2, repeatedValue: 0.0)
        sinArray = [Double](count: np2/2, repeatedValue: 0.0)
        
        for (var i = 0; i < np2 / 2; i++) {
            cosArray[i] = cos(-2.0 * M_PI * Double(i)/Double(np2));
            sinArray[i] = sin(-2.0 * M_PI * Double(i)/Double(np2));
        }
        
        super.init(inputs: inputs, outputs: outputs, additionalAttributes: additionalAttributes)
    }
    
    override func update() {
        var x = [Double](count: np2, repeatedValue: 0.0);
        var y = [Double](count: np2, repeatedValue: 0.0);
        
        for (i, value) in inputs.first!.buffer!.enumerate() {
            x[i] = value
        }
        
        if inputs.count > 1 {
            for (i, value) in inputs[1].buffer!.enumerate() {
                y[i] = value
            }
        }
        
        /***************************************************************
         * fft.c
         * Douglas L. Jones
         * University of Illinois at Urbana-Champaign
         * January 19, 1992
         * http://cnx.rice.edu/content/m12016/latest/
         *
         *   fft: in-place radix-2 DIT DFT of a complex input
         *
         *   input:
         * n: length of FFT: must be a power of two
         * m: n = 2**m
         *   input/output
         * x: double array of length n with real part of data
         * y: double array of length n with imag part of data
         *
         *   Permission to copy and use this program is granted
         *   as long as this header is included.
         ****************************************************************/
        
        var j: Int
        var k: Int
        var n1: Int
        var n2: Int
        var a: Int
        
        var c: Double
        var s: Double
        var t1: Double
        var t2: Double
        
        var xMax: Double? = nil
        var xMin: Double? = nil
        
        var yMax: Double? = nil
        var yMin: Double? = nil
        
        j = 0; /* bit-reverse */
        n2 = np2/2;
        
        for (var i = 1; i < np2 - 1; i++) {
            n1 = n2;
            
            while j >= n1 {
                j = j - n1;
                n1 = n1/2;
            }
            
            j = j + n1;
            
            if (i < j) {
                t1 = x[i];
                x[i] = x[j];
                x[j] = t1;
                
                let maxXAssigned = max(x[i], x[j])
                let minXAssigned = min(x[i], x[j])
                
                if xMax == nil || maxXAssigned > xMax {
                    xMax = maxXAssigned
                }
                
                if xMin == nil || minXAssigned < xMin {
                    xMin = minXAssigned
                }
                
                t1 = y[i];
                y[i] = y[j];
                y[j] = t1;
                
                let maxYAssigned = max(y[i], y[j])
                let minYAssigned = min(y[i], y[j])
                
                if yMax == nil || maxYAssigned > yMax {
                    yMax = maxYAssigned
                }
                
                if yMin == nil || minYAssigned < yMin {
                    yMin = minYAssigned
                }
            }
        }
        
        n2 = 1;
        
        for (var i = 0; i < logn; i++) {
            n1 = n2;
            n2 = n2 + n2;
            a = 0;
            
            for (j = 0; j < n1; j++) {
                c = cosArray[a];
                s = sinArray[a];
                a += 1 << (logn - i - 1);
                
                for (k = j; k < np2; k = k+n2) {
                    t1 = c*x[k+n1] - s*y[k+n1];
                    t2 = s*x[k+n1] + c*y[k+n1];
                    
                    x[k+n1] = x[k] - t1;
                    x[k] = x[k] + t1;
                    
                    let maxXAssigned = max(x[k+n1], x[k])
                    let minXAssigned = min(x[k+n1], x[k])
                    
                    if xMax == nil || maxXAssigned > xMax {
                        xMax = maxXAssigned
                    }
                    
                    if xMin == nil || minXAssigned < xMin {
                        xMin = minXAssigned
                    }
                    
                    y[k+n1] = y[k] - t2;
                    y[k] = y[k] + t2;
                    
                    let maxYAssigned = max(y[k+n1], y[k])
                    let minYAssigned = min(y[k+n1], y[k])
                    
                    if yMax == nil || maxYAssigned > yMax {
                        yMax = maxYAssigned
                    }
                    
                    if yMin == nil || minYAssigned < yMin {
                        yMin = minYAssigned
                    }
                }
            }
        }
        
        //Append the real part of the result to output1 and the imaginary part to output2 (if used)
        if let xOut = outputs.first?.buffer {
            xOut.appendFromArray(x)
        }
        
        if let yOut = outputs.first?.buffer {
            yOut.appendFromArray(y)
        }
    }
}
