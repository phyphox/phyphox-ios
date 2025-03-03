//
//  Shaders.h.swift
//  phyphox
//
//  Created by Sebastian Staacks on 18.02.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

#include <metal_stdlib>
#import "ShaderTypes.h"

using namespace metal;

typedef struct {
    float2 position [[attribute(kVertexAttributePosition)]];
    float2 texCoord [[attribute(kVertexAttributeTexcoord)]];
} ImageVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ImageColorInOut;

// Convert from YCbCr to rgb.
float4 ycbcrToRGBTransform(float4 y, float4 CbCr);

//Linearize gamma RGB channels to linear RGB (individually)
float linearizeGamma(float x);

typedef struct {
    float2 position;
    float2 texCoord;
} CamVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoordCamera;
    float2 texCoordScene;
} CamColorInOut;

struct PartialBufferLength {
    uint length;
};


struct Mode_HSV {
    float mode; // 0.0 for Hue, 1.0 for Staturation, 2.0 for Value
};
