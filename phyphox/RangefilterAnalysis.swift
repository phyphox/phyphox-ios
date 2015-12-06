//
//  RangefilterAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
/*
private Vector<String> min; //Hold min and max as string as it might be a dataBuffer
private Vector<String> max;

//Constructor also takes arrays of min and max values
protected rangefilterAM(phyphoxExperiment experiment, Vector<String> inputs, Vector<dataBuffer> outputs, Vector<String> min, Vector<String> max) {
super(experiment, inputs, outputs);
this.min = min;
this.max = max;
}

@Override
protected void update() {
double[] min; //Double-valued min and max. Filled from String value / dataBuffer
double[] max;

min = new double[inputs.size()];
max = new double[inputs.size()];
for(int i = 0; i < inputs.size(); i++) {
if (this.min.get(i) == null)
min[i] = Double.NEGATIVE_INFINITY; //Not set by user, set to -inf so it has no influence
else {
min[i] = getSingleValueFromUserString(this.min.get(i)); //Get value from string: numeric or buffer
}
if (this.max.get(i) == null)
max[i] = Double.POSITIVE_INFINITY; //Not set by user, set to +inf so it has no influence
else {
max[i] = getSingleValueFromUserString(this.max.get(i)); //Get value from string: numeric or buffer
}

}

//Get iterators of all inputs (numeric string not allowed here as it makes no sense to filter static input)
Vector<Iterator> its = new Vector<>();
for (int i = 0; i < inputs.size(); i++) {
if (inputs.get(i) == null) {
its.add(null); //input does not exist
} else {
//Valid buffer. Get iterator
its.add(experiment.getBuffer(inputs.get(i)).getIterator());
}
}

//Clear all outputs
for (dataBuffer output : outputs) {
output.clear();
}

double []data = new double[inputs.size()]; //Will hold values of all inputs at same index
boolean hasNext = true; //Will be set to true if ANY of the iterators has a next item (not neccessarily all of them)
while (hasNext) {
//Check if any input has a value left
hasNext = false;
for (Iterator it : its) {
if (it.hasNext())
hasNext = true;
}

if (hasNext) {
boolean filter = false; //Will be set to true if any input falls outside its min/max
for (int i = 0; i < inputs.size(); i++) { //For each input...
if (its.get(i).hasNext()) { //This input has a value left. Get it!
data[i] = (double) its.get(i).next();
if (data[i] < min[i] || data[i] > max[i]) { //Is this value outside its min/max?
filter = true; //Yepp, filter this index
}
} else
data[i] = Double.NaN; //No value left in input. Set this value to NaN and do not filter it
}
if (!filter) { //Filter not triggered? Append the values of each input to the corresponding outputs.
for (int i = 0; i < inputs.size(); i++) {
outputs.get(i).append(data[i]);
}
}

}
}
}
*/
final class RangefilterAnalysis: ExperimentAnalysis {
    
}
