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
    }
    //Every thread of the threadgroup must reach this barrier. Placing a threadgroup_barrier in
    //divergent control flow (as it was, inside if(tid.x==0)) is undefined behaviour and hangs the
    //GPU on older hardware such as the A9 (iPhone 6s). Hoisted to uniform scope so the row sums are
    //written before the final sum reads them.
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (tid.x == 0 && tid.y == 0) {
        float totalGroupSum = 0.0;
        for (uint i = 0; i < (groupSize.x * groupSize.y); i+=groupSize.x) {
            totalGroupSum += localSums[i];
        }

        partialSums[groupId.x + groupId.y * groupsPerGrid.x ] = totalGroupSum;
    }

}

//Spectroscopy: one value per pixel along the dispersion axis of the camera image, obtained by
//averaging the linear luminance of the selected analysis area across the perpendicular axis.
//The camera texture is in sensor orientation, so computeSpectrumAlongX serves a device held in
//landscape orientation relative to the spectrum and computeSpectrumAlongY one held in portrait
//orientation. One thread computes one spectrum pixel; the dispatch is one-dimensional along the
//dispersion axis.
kernel void computeSpectrumAlongX(
     texture2d<float, access::read> yTexture [[texture(0)]],
     texture2d<float, access::read> cameraImageTextureCbCr [[ texture(1) ]],
     device float *outBuffer [[buffer(0)]],
     constant SelectionState& selectionState [[buffer(1)]],
     uint gid [[thread_position_in_grid]]
                            )
{
    uint x1 = uint(selectionState.x1);
    uint x2 = min(uint(selectionState.x2), yTexture.get_width());
    uint y1 = uint(selectionState.y1);
    uint y2 = min(uint(selectionState.y2), yTexture.get_height());

    uint x = x1 + gid;
    if (x >= x2) {
        return;
    }

    float sum = 0.0;

    for (uint y = y1; y < y2; y++) {
        uint2 pixelCoord = uint2(x, y);
        float4 rgb = ycbcrToRGBTransform(
                                         yTexture.read(pixelCoord),
                                         cameraImageTextureCbCr.read(pixelCoord/2)
                                         );
        sum += 0.2126 * linearizeGamma(rgb.r) + 0.7152 * linearizeGamma(rgb.g) + 0.0722 * linearizeGamma(rgb.b);
    }

    outBuffer[gid] = y2 > y1 ? sum / float(y2 - y1) : 0.0;

}

kernel void computeSpectrumAlongY(
     texture2d<float, access::read> yTexture [[texture(0)]],
     texture2d<float, access::read> cameraImageTextureCbCr [[ texture(1) ]],
     device float *outBuffer [[buffer(0)]],
     constant SelectionState& selectionState [[buffer(1)]],
     uint gid [[thread_position_in_grid]]
                            )
{
    uint x1 = uint(selectionState.x1);
    uint x2 = min(uint(selectionState.x2), yTexture.get_width());
    uint y1 = uint(selectionState.y1);
    uint y2 = min(uint(selectionState.y2), yTexture.get_height());

    uint y = y1 + gid;
    if (y >= y2) {
        return;
    }

    float sum = 0.0;

    for (uint x = x1; x < x2; x++) {
        uint2 pixelCoord = uint2(x, y);
        float4 rgb = ycbcrToRGBTransform(
                                         yTexture.read(pixelCoord),
                                         cameraImageTextureCbCr.read(pixelCoord/2)
                                         );
        sum += 0.2126 * linearizeGamma(rgb.r) + 0.7152 * linearizeGamma(rgb.g) + 0.0722 * linearizeGamma(rgb.b);
    }

    outBuffer[gid] = x2 > x1 ? sum / float(x2 - x1) : 0.0;

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
    }
    //Uniform barrier - see computeLuma; a divergent threadgroup_barrier hangs the A9 GPU.
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (tid.x == 0 && tid.y == 0) {
        float totalGroupSum = 0.0;
        for (uint i = 0; i < (groupSize.x * groupSize.y); i+=groupSize.x) {
            totalGroupSum += localSums[i];
        }

        partialSums[groupId.x + groupId.y * groupsPerGrid.x ] = totalGroupSum;
    }
}

kernel void computeMinMaxRGB(texture2d<float, access::read> cameraImageTextureY [[ texture(0) ]],
                        texture2d<float, access::read> cameraImageTextureCbCr [[ texture(1) ]],
                        device float *partialMins [[ buffer(0) ]],
                        device float *partialMaxs [[ buffer(1) ]],
                        constant SelectionState& selectionState [[ buffer(2) ]],
                        constant PartialBufferLength& partialBufferLength [[ buffer(3) ]],
                        uint2 gid2D [[ thread_position_in_grid ]],
                        uint2 tid [[ thread_position_in_threadgroup ]],
                        uint2 groupSize [[ threads_per_threadgroup ]],
                        uint2 groupId [[ threadgroup_position_in_grid ]],
                        uint2 groupsPerGrid [[ threadgroups_per_grid ]]) {
    
    
    float min;
    float max;
    threadgroup float localMins[256]; // Assuming maximum threadgroup size of 16x16 (256 threads)
    threadgroup float localMaxs[256];
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    if(globalID.x > selectionState.x2 || globalID.y > selectionState.y2){
        min = INFINITY;
        max = -INFINITY;
    } else {
        float4 rgb = ycbcrToRGBTransform(
                                         cameraImageTextureY.read(globalID),
                                         cameraImageTextureCbCr.read(globalID/2)
                                         );
        min = min3(rgb.r, rgb.g, rgb.b);
        max = max3(rgb.r, rgb.g, rgb.b);
    }
    
    uint index = (tid.x + tid.y * groupSize.x);
    localMins[index] = min;
    localMaxs[index] = max;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (tid.x == 0) {
        min = INFINITY;
        max = -INFINITY;
        for (uint i = 0; i < groupSize.x; i++) {
            index = tid.y * groupSize.x + i;
            if (localMins[index] < min)
                min = localMins[index];
            if (localMaxs[index] > max)
                max = localMaxs[index];
        }

        localMins[tid.y * groupSize.x] = min;
        localMaxs[tid.y * groupSize.x] = max;
    }
    //Uniform barrier - see computeLuma; a divergent threadgroup_barrier hangs the A9 GPU.
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (tid.x == 0 && tid.y == 0) {
        min = INFINITY;
        max = -INFINITY;
        for (uint i = 0; i < (groupSize.x * groupSize.y); i+=groupSize.x) {
            if (localMins[i] < min)
                min = localMins[i];
            if (localMaxs[i] > max)
                max = localMaxs[i];
        }

        index = groupId.x + groupId.y * groupsPerGrid.x;
        partialMins[index] = min;
        partialMaxs[index] = max;
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
    }
    //Uniform barrier - see computeLuma; a divergent threadgroup_barrier hangs the A9 GPU.
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (tid.x == 0 && tid.y == 0) {
        float totalGroupSumY = 0.0;
        float totalGroupSumX = 0.0;
        for (uint i = 0; i < (groupSize.x * groupSize.y); i+=groupSize.x) {
            totalGroupSumY += localSumsY[i];
            totalGroupSumX += localSumsX[i];
        }

        partialSumsY[groupId.x + groupId.y * groupsPerGrid.x] = totalGroupSumY;
        partialSumsX[groupId.x + groupId.y * groupsPerGrid.x] = totalGroupSumX;
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
    }
    //Uniform barrier - see computeLuma; a divergent threadgroup_barrier hangs the A9 GPU.
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (tid.x == 0 && tid.y == 0) {
        float totalGroupSum = 0.0;
        for (uint i = 0; i < (groupSize.x * groupSize.y); i+=groupSize.x) {
            totalGroupSum += localSums[i];
        }

        partialSums[groupId.x + groupId.y * groupsPerGrid.x ] = totalGroupSum;
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
        //No barrier here: it was inside single-thread control flow (divergent, a GPU hang on the
        //A9) and served no purpose - the write to device memory is visible once the kernel completes.
        *result = localSums[0];
    }
}

kernel void computeFinalMinMax(device float *partialMins [[ buffer(0) ]],
                               device float *partialMaxs [[ buffer(1) ]],
                               device MinMax *result [[ buffer(2) ]],
                            constant PartialBufferLength& partialBufferLength [[ buffer(3) ]],
                            uint gid [[ thread_position_in_grid ]],
                            uint tid [[ thread_position_in_threadgroup ]],
                            uint groupSize [[ threads_per_threadgroup ]]
                            ) {
    
    threadgroup float localMins[256];
    threadgroup float localMaxs[256];
    
    float min = INFINITY;
    float max = -INFINITY;
    for (uint i = tid; i < partialBufferLength.length; i += groupSize) {
        if (partialMins[i] < min)
            min = partialMins[i];
        if (partialMaxs[i] > max)
            max = partialMaxs[i];
    }
    localMins[tid] = min;
    localMaxs[tid] = max;
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Perform parallel reduction
    for (uint threads = groupSize / 2; threads > 0; threads /= 2) {
        if (tid < threads && (tid + threads) < groupSize) {
            if (localMins[tid + threads] < localMins[tid])
                localMins[tid] = localMins[tid + threads];
            if (localMaxs[tid + threads] > localMaxs[tid])
                localMaxs[tid] = localMaxs[tid + threads];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    if (gid == 0) {
        //No barrier here - see computeFinalSum; it was divergent and pointless.
        result->min = localMins[0];
        result->max = localMaxs[0];
    }
}
