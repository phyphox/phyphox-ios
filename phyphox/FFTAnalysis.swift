//
//  FFTAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class FFTAnylsis: ExperimentAnalysis {
    //input size, power-of-two filled size, log2 of input size (integer)
    private var n: Int
    private var np2: Int
    private var logn: Int
    
    //Lookup table
    private var cosArray: [Double]
    private var sinArray: [Double]
    
    override init(experiment: Experiment, inputs: [String], outputs: [DataBuffer]) {
        //FIXME:
        n = 0//experiment.getBuffer().. This: getBufferForKey(inputs.first!)!.size doesn't work because self isn't initialized yet.
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
        
        super.init(experiment: experiment, inputs: inputs, outputs: outputs)
    }
    
    override func update() {
        var x = [Double](count: np2, repeatedValue: 0.0);
        var y = [Double](count: np2, repeatedValue: 0.0);
        
        var ix = getBufferForKey(inputs.first!)!.generate()
        var i = 0
        
        while let next = ix.next() {
            x[i++] = next
            
            if inputs.count > 1 {
                var iy = getBufferForKey(inputs[1])!.generate()
                i = 0
                
                //TODO: wirklich i vom großen loop benutzen?
                while let yNext = iy.next() {
                    y[i++] = yNext
                }
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
        
        j = 0; /* bit-reverse */
        n2 = np2/2;
        
        for (i = 1; i < np2 - 1; i++) {
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
                t1 = y[i];
                y[i] = y[j];
                y[j] = t1;
            }
        }
        
        n2 = 1;
        
        for (i = 0; i < logn; i++) {
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
                    y[k+n1] = y[k] - t2;
                    x[k] = x[k] + t1;
                    y[k] = y[k] + t2;
                }
            }
        }
    }
}
