//
//  AutocorrelationAnylsis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/*
private String smint = "";
private String smaxt = "";

protected autocorrelationAM(phyphoxExperiment experiment, Vector<String> inputs, Vector<dataBuffer> outputs) {
super(experiment, inputs, outputs);
}

//Optionally, a min and max of the used x-range can be set (same effect as a rangefilter but more efficient as it is done in one loop)
protected void setMinMax(String mint, String maxt) {
this.smint = mint;
this.smaxt = maxt;
}

@Override
protected void update() {
double mint, maxt;

//Update min and max as they might come from a dataBuffer
if (smint == null || smint.equals(""))
mint = Double.NEGATIVE_INFINITY; //not set by user, set to -inf so it has no effect
else
mint = getSingleValueFromUserString(smint);

if (smaxt == null || smaxt.equals(""))
maxt = Double.POSITIVE_INFINITY; //not set by user, set to +inf so it has no effect
else
maxt = getSingleValueFromUserString(smaxt);

//Get arrays for random access
Double y[] = experiment.getBuffer(inputs.get(0)).getArray();
Double x[] = new Double[y.length]; //Relative x (the displacement in the autocorrelation). This has to be filled from input2 or manually with 1,2,3...
if (inputs.size() > 1) {
//There is a second input, let's use it.
Double xraw[] = experiment.getBuffer(inputs.get(1)).getArray();
for (int i = 0; i < x.length; i++) {
if (i < xraw.length)
x[i] = xraw[i]-xraw[0]; //There is still input left. Use it and calculate the relative x
else
x[i] = xraw[xraw.length - 1]-xraw[0]; //No input left. This probably leads to wrong results, but let's use the last value
}
} else {
//There is no input2. Let's fill it with 0,1,2,3,4....
for (int i = 0; i < x.length; i++) {
x[i] = (double)i;
}
}

//Clear outputs
outputs.get(0).clear();
if (outputs.size() > 1 && outputs.get(1) != null)
outputs.get(1).clear();

//The actual calculation
for (int i = 0; i < y.length; i++) { //Displacement i for each value of input1
if (x[i] < mint || x[i] > maxt) //Skip this, if it should be filtered
continue;

double sum = 0.;
for (int j = 0; j < y.length-i; j++) { //For each value of input1 minus the current displacement
sum += y[j]*y[j+i]; //Product of normal and displaced data
}
sum /= (double)(y.length-i); //Normalize to the number of values at this displacement

//Append y output to output1 and x to output2 (if used)
outputs.get(0).append(sum);
if (outputs.size() > 1 && outputs.get(1) != null)
outputs.get(1).append(x[i]);
}
}
*/

final class AutocorrelationAnylsis: ExperimentAnalysis {
    
}
