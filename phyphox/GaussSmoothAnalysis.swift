//
//  GaussSmoothAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/*
int calcWidth; //range to which the gauss is calculated
double[] gauss; //Gauss-weight look-up-table

protected gaussSmoothAM(phyphoxExperiment experiment, Vector<String> inputs, Vector<dataBuffer> outputs) {
super(experiment, inputs, outputs);
setSigma(3); //default
}

//Change sigma
protected void setSigma(double sigma) {
this.calcWidth = (int)Math.round(sigma*3); //Adapt calculation range: 3x sigma should be plenty

gauss = new double[calcWidth*2+1];
for (int i = -calcWidth; i <= calcWidth; i++) {
gauss[i+calcWidth] = Math.exp(-(i/sigma*i/sigma)/2.)/(sigma*Math.sqrt(2.*Math.PI)); //Gauß!
}
}

@Override
protected void update() {
//Get array for random access
Double y[] = experiment.getBuffer(inputs.get(0)).getArray();

//Clear output
outputs.get(0).clear();

for (int i = 0; i < y.length; i++) { //For each data-point
double sum = 0;
for (int j = -calcWidth; j <= calcWidth; j++) { //For each step in the look-up-table
int k = i+j; //index in input that corresponds to the step in the look-up-table
if (k >= 0 && k < y.length)
sum += gauss[j+calcWidth]*y[k]; //Add weighted contribution
}
outputs.get(0).append(sum); //Append the result to the output buffer
}
}
*/

final class GaussSmoothAnalysis: ExperimentAnalysis {
    
}
