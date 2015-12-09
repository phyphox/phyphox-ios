//
//  AutocorrelationAnylsis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class AutocorrelationAnylsis: ExperimentAnalysis {
    private var smint = "";
    private var smaxt = "";
    
    func setMinMax(mint: String, maxt: String) {
        smint = mint;
        smaxt = maxt;
    }
    
    override func update() {
        var mint: Double
        var maxt: Double
        
        if (smint.characters.count == 0) {
            mint = -Double.infinity; //not set by user, set to -inf so it has no effect
        }
        else {
            mint = getSingleValueFromUserString(smint)!;
        }
        
        if (smaxt.characters.count == 0) {
            maxt = Double.infinity; //not set by user, set to -inf so it has no effect
        }
        else {
            maxt = getSingleValueFromUserString(smaxt)!;
        }
        
        //Get arrays for random access
        var y = getBufferForKey(inputs.first!)!.toArray()
        var x = [Double](count: y.count, repeatedValue: 0.0) //Relative x (the displacement in the autocorrelation). This has to be filled from input2 or manually with 1,2,3...
        
        if inputs.count > 1 {
            var xraw = getBufferForKey(inputs[1])!.toArray()
            
            
            for (var i = 0; i < x.count; i++) {
                if (i < xraw.count) {
                    x[i] = xraw[i]-xraw[0]; //There is still input left. Use it and calculate the relative x
                }
                else {
                    x[i] = xraw[xraw.count - 1]-xraw[0]; //No input left. This probably leads to wrong results, but let's use the last value
                }
            }
        }
        else {
            //There is no input2. Let's fill it with 0,1,2,3,4....
            for (var i = 0; i < x.count; i++) {
                x[i] = Double(i);
            }
        }
        
        //Clear outputs
        outputs.first!.clear();
        if (outputs.count > 1) {
            outputs[1].clear();
        }
        
        //The actual calculation
        for (var i = 0; i < y.count; i++) { //Displacement i for each value of input1
            if (x[i] < mint || x[i] > maxt) { //Skip this, if it should be filtered
                continue;
            }
            
            var sum = 0.0
            
            for (var j = 0; j < y.count-i; j++) { //For each value of input1 minus the current displacement
                sum += y[j]*y[j+i]; //Product of normal and displaced data
            }
            sum /= Double(y.count-i); //Normalize to the number of values at this displacement
            
            //Append y output to output1 and x to output2 (if used)
            outputs.first!.append(sum);
            if (outputs.count > 1) {
                outputs[1].append(x[i]);
            }
        }
    }
}
