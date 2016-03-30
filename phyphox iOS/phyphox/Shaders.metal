//
//  Shaders.metal
//  HelloMetal
//
//  Created by Main Account on 10/2/14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
};

vertex float4 vertex_func(const device packed_float2* vertex_array [[ buffer(0) ]],unsigned int vid [[ vertex_id ]]) {
    return float4(vertex_array[vid], 0.0, 1.0);
}


fragment float4 fragment_func(Vertex vert [[stage_in]]) {
    return float4(0, 0, 0, 1);
}
