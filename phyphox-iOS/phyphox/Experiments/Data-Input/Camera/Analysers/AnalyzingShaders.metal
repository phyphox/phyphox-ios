//
//  analyzingShaders.metal.swift
//  phyphox
//
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

#import "../../../../Helper/ShaderTypes.h"
#import "../../../../Helper/Shaders.h"

kernel void computeLuma(texture2d<float, access::read> yTexture [[ texture(0) ]],
                        device float *partialSums [[ buffer(0) ]],
                        constant SelectionState& selectionState [[ buffer(1) ]],
                        constant PartialBufferLength& partialBufferLength [[ buffer(2) ]],
                        uint2 gid2D [[ thread_position_in_grid ]],
                        uint2 tid [[ thread_position_in_threadgroup ]],
                        uint2 groupSize [[ threads_per_threadgroup ]],
                        uint2 groupId [[ threadgroup_position_in_grid ]]) {
    
    
    float luma;
    threadgroup float localSums[256]; // Assuming maximum threadgroup size of 16x16 (256 threads)
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    if(globalID.x > selectionState.x2 || globalID.y > selectionState.y2){
        luma = 0.0;
    } else {
        luma = yTexture.read(globalID).r;
    }
    
    localSums[tid.x + tid.y * groupSize.x] = luma;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (tid.x == 0) {
        float totalRowSum = 0.0;
        for (uint i = 0; i < groupSize.x; i++) {
            totalRowSum += localSums[tid.y * groupSize.x + i];
        }
        
        localSums[tid.y * groupSize.x] = totalRowSum;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        if (tid.y == 0) {
            float totalGroupSum = 0.0;
            for (uint i = 0; i < (groupSize.x * groupSize.y); i+=groupSize.x) {
                totalGroupSum += localSums[i];
            }
            
            uint selectionWidth = selectionState.x2 - selectionState.x1;
            uint threadGroupCountX = selectionWidth / groupSize.x ;
            partialSums[groupId.x + groupId.y * threadGroupCountX ] = totalGroupSum;
            threadgroup_barrier(mem_flags::mem_device);
        }
    }
    
}


kernel void computeLuminance(texture2d<float, access::read> cameraImageTextureY [[ texture(0) ]],
                             texture2d<float, access::read> cameraImageTextureCbCr [[ texture(1) ]],
                             device float *partialSums [[ buffer(0) ]],
                             constant SelectionState& selectionState [[ buffer(1) ]],
                             constant PartialBufferLength& partialBufferLength [[ buffer(2) ]],
                             uint2 gid2D [[ thread_position_in_grid ]],
                             uint2 tid [[ thread_position_in_threadgroup ]],
                             uint2 groupSize [[ threads_per_threadgroup ]],
                             uint2 groupId [[ threadgroup_position_in_grid ]]) {
    
    
    float luminance;
    threadgroup float localSums[256];
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    
    if (globalID.x > selectionState.x2 || globalID.y > selectionState.y2) {
        luminance = 0.0;
    } else {
        // Sample this pixel's camera image color.
        float4 rgb = ycbcrToRGBTransform(
                                         cameraImageTextureY.read(globalID),
                                         cameraImageTextureCbCr.read(globalID)
                                         );
        
        float red = rgb.r;
        float green = rgb.g;
        float blue = rgb.b;
            
        luminance = 0.2126 * linearizeGamma(red) + 0.7152 * linearizeGamma(green) + 0.0722 * linearizeGamma(blue);
    }
    
    localSums[tid.x + tid.y * groupSize.x] = luminance;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (tid.x == 0) {
        float totalRowSum = 0.0;
        for (uint i = 0; i < groupSize.x; i++) {
            totalRowSum += localSums[tid.y * groupSize.x + i];
        }
        
        localSums[tid.y * groupSize.x] = totalRowSum;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        if (tid.y == 0) {
            float totalGroupSum = 0.0;
            for (uint i = 0; i < (groupSize.x * groupSize.y); i+=groupSize.x) {
                totalGroupSum += localSums[i];
            }
            
            uint selectionWidth = selectionState.x2 - selectionState.x1;
            uint threadGroupCountX = selectionWidth / groupSize.x ;
            partialSums[groupId.x + groupId.y * threadGroupCountX ] = totalGroupSum;
            threadgroup_barrier(mem_flags::mem_device);
        }
    }
    
}




kernel void computeFinalSum(device float *partialSums [[ buffer(0) ]],
                            device float *result [[ buffer(1) ]],
                            constant PartialBufferLength& partialBufferLength [[ buffer(2) ]],
                            uint gid [[ thread_position_in_grid ]],
                            uint tid [[ thread_position_in_threadgroup ]],
                            uint groupSize [[ threads_per_threadgroup ]]
                            ) {
    
    threadgroup float localSums[256];
    
    float sum = 0.0;
    for (uint i = tid; i < partialBufferLength.length; i += groupSize)
        sum += partialSums[i];
    localSums[tid] = sum;
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Perform parallel reduction
    for (uint threads = groupSize / 2; threads > 0; threads /= 2) {
        if (tid < threads && (tid + threads) < groupSize) {
            localSums[tid] += localSums[tid + threads];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    if (gid == 0) {
        *result = localSums[0];
        threadgroup_barrier(mem_flags::mem_device);
    }
}


kernel void computeHue(texture2d<float, access::sample> cameraImageTextureY [[ texture(0) ]],
                       texture2d<float, access::sample> cameraImageTextureCbCr [[ texture(1) ]],
                       device float *partialSums [[ buffer(0) ]],
                       constant SelectionState& selectionState [[ buffer(1) ]],
                       constant PartialBufferLength& partialBufferLength [[ buffer(2) ]],
                       uint2 gid2D [[ thread_position_in_grid ]],
                       uint2 tid [[ thread_position_in_threadgroup ]],
                       uint2 groupSize [[ threads_per_threadgroup ]],
                       uint2 groupId [[ threadgroup_position_in_grid ]]){
    
    uint width = cameraImageTextureY.get_width();
    uint height = cameraImageTextureCbCr.get_height();
    
    uint numPartialSums = partialBufferLength.length; // TODO: fix: numPartialSums is not receiving the value from CPU
    
    if(gid2D.x > width || gid2D.y > height){
        return;
    }
    
    uint selectionWidth = selectionState.x2 - selectionState.x1; //96
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    
    
    threadgroup float localSums[512]; // 256 * 2, to place both x and y result into same buffer
    
    // Create an object to sample textures.
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    // Sample this pixel's camera image color.
    float4 rgb = ycbcrToRGBTransform(
                                     cameraImageTextureY.sample(s, float2(gid2D)),
                                     cameraImageTextureCbCr.sample(s, float2(gid2D))
                                     );
    
    
    
    float rgbMax = max(max(rgb.r, rgb.g), rgb.b);
    float rgbMin = min(min(rgb.r, rgb.g), rgb.b);
    float d = rgbMax - rgbMin;
    
    float result;
    float x,y;
    
    if(rgbMax == rgbMin){
        result = 0.0;
    } else if(rgbMax == rgb.r) {
        result = (rgb.g - rgb.b + d * (rgb.g < rgb.b ? 6.0 : 0.0)) / (6.0 * d);
    } else if (rgbMax == rgb.g) {
        result = (rgb.b - rgb.r + d * 2.0) / (6.0 * d);
    } else {
        result = (rgb.r - rgb.g + d * 4.0) / (6.0 * d);
    }
    
    result = result * 2 * 3.141592 ;
    
    uint index = (tid.x + tid.y * groupSize.x);
    
    if(globalID.x > selectionState.x2 || globalID.y > selectionState.y2){
        result = 0;
    }
    
    y = sin(result);
    x = cos(result);
    
    localSums[index] = y;
    localSums[index+256] = x;
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (tid.x == 0 && tid.y == 0) {
        float totalGroupForX = 0.0;
        float totalGroupForY = 0.0;
        
        for (uint i = 0; i < 256; i++) {
            totalGroupForY += localSums[i];
            totalGroupForX += localSums[i+256];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        uint threadGroupWidth = selectionWidth / groupSize.x ;
        
        partialSums[(groupId.x + groupId.y * threadGroupWidth) ] = totalGroupForY;
        partialSums[(groupId.x + groupId.y * threadGroupWidth) + 35] = totalGroupForX; // TODO: Hard coded need to be refactored
        threadgroup_barrier(mem_flags::mem_device);
    }
}



kernel void computeSaturationAndValue(texture2d<float, access::sample> cameraImageTextureY [[ texture(0) ]],
                                      texture2d<float, access::sample> cameraImageTextureCbCr [[ texture(1) ]],
                                      device float *partialSums [[ buffer(0) ]],
                                      constant SelectionState& selectionState [[ buffer(1) ]],
                                      device Mode_HSV* inputMode [[buffer(2)]],
                                      uint2 gid2D [[ thread_position_in_grid ]],
                                      uint2 tid [[ thread_position_in_threadgroup ]],
                                      uint2 groupSize [[ threads_per_threadgroup ]],
                                      uint2 groupId [[ threadgroup_position_in_grid ]]){
    
    
    uint width =  cameraImageTextureY.get_width();
    uint height = cameraImageTextureY.get_height();
    
    if(gid2D.x > width || gid2D.y > height){
        return;
    }
    
    uint selectionWidth = selectionState.x2 - selectionState.x1; //96
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    
    threadgroup float localSums[256];
    
    // Create an object to sample textures.
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    // Sample this pixel's camera image color.
    float4 rgb = ycbcrToRGBTransform(
                                     cameraImageTextureY.sample(s, float2(gid2D)),
                                     cameraImageTextureCbCr.sample(s, float2(gid2D))
                                     );
    
    Mode_HSV mode = *inputMode;
    
    uint m = mode.mode;
    
    float rgbMax = max(max(rgb.r, rgb.g), rgb.b);
    float rgbMin = min(min(rgb.r, rgb.g), rgb.b);
    float d = rgbMax - rgbMin;
    
    float result;
    
    switch (m){
            
        case 1:
            
            if (rgbMax == 0.0) {
                result = 0.0;
            } else {
                result = d / rgbMax;
            }
            
            break;
        case 2:
            
            result = max(rgb.r, max(rgb.b, rgb.g));
            
            break;
    }
    
    // Compute 1D index in the partialSums array for the current pixel
    uint index = (tid.x + tid.y * groupSize.x);
    
    if(globalID.x > selectionState.x2 || globalID.y > selectionState.y2){
        result = 0;
    }
    
    // Write the HSV values into the partialSums buffer
    localSums[index] = result;
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (tid.x == 0 && tid.y == 0) {
        float totalGroup = 0.0;
        
        for (uint i = 0; i < 256; i++) {
            totalGroup += localSums[i];
            
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        uint threadGroupWidth = selectionWidth / groupSize.x ;
        
        partialSums[(groupId.x + groupId.y * threadGroupWidth) ] = totalGroup;
        threadgroup_barrier(mem_flags::mem_device);
    }
    
}
