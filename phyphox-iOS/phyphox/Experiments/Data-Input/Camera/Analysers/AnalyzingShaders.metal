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
                        uint2 groupId [[ threadgroup_position_in_grid ]],
                        uint2 groupsPerGrid [[ threadgroups_per_grid ]]) {
    
    
    float luma;
    threadgroup float localSums[256]; // Assuming maximum threadgroup size of 16x16 (256 threads)
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    if(globalID.x > selectionState.x2 || globalID.y > selectionState.y2){
        luma = 0.0;
    } else {
        luma = yTexture.read(globalID).r;
    }
    
    uint index = (tid.x + tid.y * groupSize.x);
    localSums[index] = luma;
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
            
            partialSums[groupId.x + groupId.y * groupsPerGrid.x ] = totalGroupSum;
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
                             uint2 groupId [[ threadgroup_position_in_grid ]],
                             uint2 groupsPerGrid [[ threadgroups_per_grid ]]) {
    
    
    float luminance;
    threadgroup float localSums[256];
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    
    if (globalID.x > selectionState.x2 || globalID.y > selectionState.y2) {
        luminance = 0.0;
    } else {
        // Sample this pixel's camera image color.
        float4 rgb = ycbcrToRGBTransform(
                                         cameraImageTextureY.read(globalID),
                                         cameraImageTextureCbCr.read(globalID/2)
                                         );
        
        float red = rgb.r;
        float green = rgb.g;
        float blue = rgb.b;
            
        luminance = 0.2126 * linearizeGamma(red) + 0.7152 * linearizeGamma(green) + 0.0722 * linearizeGamma(blue);
    }
    
    uint index = (tid.x + tid.y * groupSize.x);
    localSums[index] = luminance;
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
            
            partialSums[groupId.x + groupId.y * groupsPerGrid.x ] = totalGroupSum;
            threadgroup_barrier(mem_flags::mem_device);
        }
    }
}

kernel void computeHue(texture2d<float, access::read> cameraImageTextureY [[ texture(0) ]],
                       texture2d<float, access::read> cameraImageTextureCbCr [[ texture(1) ]],
                       device float *partialSumsX [[ buffer(0) ]],
                       device float *partialSumsY [[ buffer(1) ]],
                       constant SelectionState& selectionState [[ buffer(2) ]],
                       constant PartialBufferLength& partialBufferLength [[ buffer(3) ]],
                       uint2 gid2D [[ thread_position_in_grid ]],
                       uint2 tid [[ thread_position_in_threadgroup ]],
                       uint2 groupSize [[ threads_per_threadgroup ]],
                       uint2 groupId [[ threadgroup_position_in_grid ]],
                       uint2 groupsPerGrid [[ threadgroups_per_grid ]]) {
    
    float x, y;
    threadgroup float localSumsX[256];
    threadgroup float localSumsY[256];
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
        
    if (globalID.x > selectionState.x2 || globalID.y > selectionState.y2) {
        x = 0.0;
        y = 0.0;
    } else {
        // Sample this pixel's camera image color.
        float4 rgb = ycbcrToRGBTransform(
                                         cameraImageTextureY.read(globalID),
                                         cameraImageTextureCbCr.read(globalID/2)
                                         );
        
        float rgbMax = max(max(rgb.r, rgb.g), rgb.b);
        float rgbMin = min(min(rgb.r, rgb.g), rgb.b);
        float d = rgbMax - rgbMin;
        float hue;
        
        if(rgbMax == rgbMin){
            hue = 0.0;
        } else if(rgbMax == rgb.r) {
            hue = (rgb.g - rgb.b + d * (rgb.g < rgb.b ? 6.0 : 0.0)) / (6.0 * d);
        } else if (rgbMax == rgb.g) {
            hue = (rgb.b - rgb.r + d * 2.0) / (6.0 * d);
        } else {
            hue = (rgb.r - rgb.g + d * 4.0) / (6.0 * d);
        }
        
        hue *= 2.0 * 3.141592;
        
        y = sin(hue);
        x = cos(hue);
    }
    
    uint index = (tid.x + tid.y * groupSize.x);
    localSumsY[index] = y;
    localSumsX[index] = x;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (tid.x == 0) {
        float totalRowSumY = 0.0;
        float totalRowSumX = 0.0;
        for (uint i = 0; i < groupSize.x; i++) {
            totalRowSumY += localSumsY[tid.y * groupSize.x + i];
            totalRowSumX += localSumsX[tid.y * groupSize.x + i];
        }
        
        localSumsX[tid.y * groupSize.x] = totalRowSumX;
        localSumsY[tid.y * groupSize.x] = totalRowSumY;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        if (tid.y == 0) {
            float totalGroupSumY = 0.0;
            float totalGroupSumX = 0.0;
            for (uint i = 0; i < (groupSize.x * groupSize.y); i+=groupSize.x) {
                totalGroupSumY += localSumsY[i];
                totalGroupSumX += localSumsX[i];
            }

            partialSumsY[groupId.x + groupId.y * groupsPerGrid.x] = totalGroupSumY;
            partialSumsX[groupId.x + groupId.y * groupsPerGrid.x] = totalGroupSumX;
            threadgroup_barrier(mem_flags::mem_device);
        }
    }
}



kernel void computeSaturationAndValue(texture2d<float, access::read> cameraImageTextureY [[ texture(0) ]],
                                      texture2d<float, access::read> cameraImageTextureCbCr [[ texture(1) ]],
                                      device float *partialSums [[ buffer(0) ]],
                                      constant SelectionState& selectionState [[ buffer(1) ]],
                                      constant PartialBufferLength& partialBufferLength [[ buffer(2) ]],
                                      device Mode_HSV* inputMode [[buffer(3)]],
                                      uint2 gid2D [[ thread_position_in_grid ]],
                                      uint2 tid [[ thread_position_in_threadgroup ]],
                                      uint2 groupSize [[ threads_per_threadgroup ]],
                                      uint2 groupId [[ threadgroup_position_in_grid ]],
                                      uint2 groupsPerGrid [[ threadgroups_per_grid ]]) {
    
    float result;
    threadgroup float localSums[256];
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    
    if (globalID.x > selectionState.x2 || globalID.y > selectionState.y2) {
        result = 0.0;
    } else {
        // Sample this pixel's camera image color.
        float4 rgb = ycbcrToRGBTransform(
                                         cameraImageTextureY.read(globalID),
                                         cameraImageTextureCbCr.read(globalID/2)
                                         );
        
        Mode_HSV mode = *inputMode;
        
        uint m = mode.mode;
        
        float rgbMax = max(max(rgb.r, rgb.g), rgb.b);
        float rgbMin = min(min(rgb.r, rgb.g), rgb.b);
        float d = rgbMax - rgbMin;
        
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
    }
    
    localSums[tid.x + tid.y * groupSize.x] = result;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Compute 1D index in the partialSums array for the current pixel
    uint index = (tid.x + tid.y * groupSize.x);
    
    // Write the HSV values into the partialSums buffer
    localSums[index] = result;
    
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
            
            partialSums[groupId.x + groupId.y * groupsPerGrid.x ] = totalGroupSum;
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
