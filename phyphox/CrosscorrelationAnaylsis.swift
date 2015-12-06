//
//  CrosscorrelationAnaylsis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/*
protected crosscorrelationAM(phyphoxExperiment experiment, Vector<String> inputs, Vector<dataBuffer> outputs) {
super(experiment, inputs, outputs);
}

@Override
protected void update() {
Double a[], b[];
//Put the larger input in a and the smaller one in b
if (experiment.getBuffer(inputs.get(0)).getFilledSize() > experiment.getBuffer(inputs.get(1)).getFilledSize()) {
a = experiment.getBuffer(inputs.get(0)).getArray();
b = experiment.getBuffer(inputs.get(1)).getArray();
} else {
b = experiment.getBuffer(inputs.get(0)).getArray();
a = experiment.getBuffer(inputs.get(1)).getArray();
}

//Clear output
outputs.get(0).clear();

//The actual calculation
int compRange = a.length - b.length;
for (int i = 0; i < compRange; i++) {
double sum = 0.;
for (int j = 0; j < b.length; j++) {
sum += a[j+i]*b[j];
}
sum /= (double)(compRange); //Normalize bynumber of values
outputs.get(0).append(sum);
}
}
*/

final class CrosscorrelationAnaylsis: ExperimentAnalysis {
    
}
