//
//  FFTAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

/*
private int n, np2, logn; //input size, power-of-two filled size, log2 of input size (integer)
private double [] cos, sin; //Lookup table

protected fftAM(phyphoxExperiment experiment, Vector<String> inputs, Vector<dataBuffer> outputs) {
super(experiment, inputs, outputs);

n = experiment.getBuffer(inputs.get(0)).size; //Actual input size
logn = (int)(Math.log(n)/Math.log(2)); //log of input size
if (n != (1 << logn)) {
logn++;
np2 = (1 << logn); //power of two after zero filling
} else
np2 = n; //n is already power of two

//Create buffer of sine and cosine values
cos = new double[np2/2];
sin = new double[np2/2];
for (int i = 0; i < np2 / 2; i++) {
cos[i] = Math.cos(-2 * Math.PI * i / np2);
sin[i] = Math.sin(-2 * Math.PI * i / np2);
}
}

@Override
protected void update() {

//Create arrays for random access
double x[] = new double[np2];
double y[] = new double[np2];

//Iterator of first input -> Re(z)
Iterator ix = experiment.getBuffer(inputs.get(0)).getIterator();
int i = 0;
while (ix.hasNext())
x[i++] = (double)ix.next();
if (inputs.size() > 1) { //Is there imaginary input?
//Iterator of second input -> Im(z)
Iterator iy = experiment.getBuffer(inputs.get(1)).getIterator();
i = 0;
while (iy.hasNext())
y[i++] = (double)iy.next();
}// else {
//Fill y with zeros if there is no imaginary input
//Not explicitly needed as java initializes double arrays to zero anyway
//                for (i = 0; i < np2; i++)
//                    y[i] = 0.;
//            }


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

int j,k,n1,n2,a;
double c,s,t1,t2;

j = 0; /* bit-reverse */
n2 = np2/2;
for (i=1; i < np2 - 1; i++) {
n1 = n2;
while ( j >= n1 ) {
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

for (i=0; i < logn; i++)
{
n1 = n2;
n2 = n2 + n2;
a = 0;

for (j=0; j < n1; j++)
{
c = cos[a];
s = sin[a];
a += 1 << (logn - i - 1);

for (k=j; k < np2; k=k+n2)
{
t1 = c*x[k+n1] - s*y[k+n1];
t2 = s*x[k+n1] + c*y[k+n1];
x[k+n1] = x[k] - t1;
y[k+n1] = y[k] - t2;
x[k] = x[k] + t1;
y[k] = y[k] + t2;
}
}
}

//Append the real part of the result to output1 and the imaginary part to output2 (if used)
for (i = 0; i < n; i++) {
outputs.get(0).append(x[i]);
if (outputs.size() > 1 && outputs.get(1) != null)
outputs.get(1).append(y[i]);
}
}
*/

final class FFTAnylsis: ExperimentAnalysis {
    
}
