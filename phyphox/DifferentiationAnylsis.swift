//
//  DifferentiationAnylsis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/*

protected differentiateAM(phyphoxExperiment experiment, Vector<String> inputs, Vector<dataBuffer> outputs) {
super(experiment, inputs, outputs);
}

@Override
protected void update() {
double v, last = Double.NaN;
boolean first = true;

//Clear output
outputs.get(0).clear();

//The actual calculation
Iterator it = experiment.getBuffer(inputs.get(0)).getIterator();
if (it == null) //non-buffer values are ignored
return;
//Calculate difference of neighbors
while (it.hasNext()) {
if (first) { //The first value is just stored
last = (double)it.next();
first = false;
continue;
}
v = (double)it.next();
outputs.get(0).append(v-last);
last = v;
}
}
*/

final class DifferentiationAnylsis: ExperimentAnalysis {
    
}
