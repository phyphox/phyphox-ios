/*
 Based on the ARKit example implementations by Apple
 (https://developer.apple.com/documentation/arkit/environmental_analysis/creating_a_fog_effect_using_scene_depth)
 */

#include <metal_stdlib>
#include <simd/simd.h>

// Include header shared between this Metal shader code and C code executing Metal API commands.
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
float4 ycbcrToRGBTransform(float4 y, float4 CbCr) {
    const float4x4 ycbcrToRGBTransform = float4x4(
                                                  float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                  float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                  float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                  float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
                                                  );
    
    float4 ycbcr = float4(y.r, CbCr.rg, 1.0);
    return ycbcrToRGBTransform * ycbcr;
}

typedef struct {
    float2 position;
    float2 texCoord;
} CamVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoordCamera;
    float2 texCoordScene;
} CamColorInOut;

struct SelectionState {
    float x1;
    float x2;
    float y1;
    float y2;
    bool editable;
};

struct PartialBufferLength {
    uint length;
};

vertex CamColorInOut vertexTransform(const device CamVertex* cameraVertices [[ buffer(0) ]],
                                     const device CamVertex* sceneVertices [[ buffer(1) ]],
                                     unsigned int vid [[ vertex_id ]]) {
    CamColorInOut out;
    
    const device CamVertex& cv = cameraVertices[vid];
    const device CamVertex& sv = sceneVertices[vid];
    
    out.position = float4(cv.position, 0.0, 1.0);
    out.texCoordCamera = cv.texCoord;
    out.texCoordScene = sv.texCoord;
    
    return out;
}

fragment half4 fragmentShader(CamColorInOut in [[ stage_in ]],
                              texture2d<float, access::sample> cameraImageTextureY [[ texture(0) ]],
                              texture2d<float, access::sample> cameraImageTextureCbCr [[ texture(1) ]],
                              constant SelectionState& selectionState [[buffer(2)]])
{
    
    // Create an object to sample textures.
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    // Sample this pixel's camera image color.
    float4 rgb = ycbcrToRGBTransform(
                                     cameraImageTextureY.sample(s, in.texCoordCamera),
                                     cameraImageTextureCbCr.sample(s, in.texCoordCamera)
                                     );
    if (selectionState.editable) {
        float dx1 = in.position.x - selectionState.x1;
        float dx2 = in.position.x - selectionState.x2;
        float dy1 = in.position.y - selectionState.y1;
        float dy2 = in.position.y - selectionState.y2;
        float d11 = dx1*dx1 + dy1*dy1;
        float d12 = dx1*dx1 + dy2*dy2;
        float d21 = dx2*dx2 + dy1*dy1;
        float d22 = dx2*dx2 + dy2*dy2;
        if ((d11 > 100 && d11 < 200) || (d12 > 100 && d12 < 200) || (d21 > 100 && d21 < 200) || (d22 > 100 && d22 < 200)) {
            return half4(1.0, 1.0, 1.0, 1.0);
        }
    }
    if (in.position.x < selectionState.x1 || in.position.x > selectionState.x2 || in.position.y < selectionState.y1 || in.position.y > selectionState.y2) {
        return mix(half4(rgb), half4(0.0, 0.0, 0.0, 1.0), 0.5);
    } else {
        return half4(rgb);
    }
}


kernel void computeSumLuminanceParallellll(texture2d<float, access::read> yTexture [[ texture(0) ]],
                                           device float *result [[ buffer(0) ]],
                                           device float *partialSums [[ buffer(1) ]],
                                           device float *count [[ buffer(2) ]],
                                           constant SelectionState& selectionState [[ buffer(3) ]],
                                           uint2 gid2D [[ thread_position_in_grid ]],
                                           uint2 tid [[ thread_position_in_threadgroup ]],
                                           uint2 groupSize [[ threads_per_threadgroup ]],
                                           uint2 groupId [[ threadgroup_position_in_grid ]]) {
    
    
    
    // Initialize the sum for this thread
    float luminanceSum = 0.0;
    
    float countPixel = 0.0;
    
    
    // Calculate texture dimensions
    uint width = selectionState.x2 - selectionState.x1;
    uint height = selectionState.y2 - selectionState.y1;
    
    // Convert the 2D gid to a 1D index
    //uint gid = gid2D.y * (groupSize.x * groupId.x) + gid2D.x;
    
    // Clear the buffer at this index
    //result[gid] = 0.0f;
    
    
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    
    if (globalID.x >= yTexture.get_width() || globalID.y >= yTexture.get_height()) {
        return;
    }
    
    *count = (width / groupSize.x ) * (height / groupSize.y);
    
    
    luminanceSum = yTexture.read(globalID).r * 255 ;
    threadgroup float localSums[256]; // Assuming maximum threadgroup size of 16x16 (256 threads)
    threadgroup float localPixelCount[256];
    localSums[tid.x + tid.y * groupSize.x] = luminanceSum;
    localPixelCount[tid.x + tid.y * groupSize.x] = 1;
    
    
    // Synchronize threads in the threadgroup
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Only one thread in the threadgroup should write the sum to the partial sums
    if (tid.x == 0 && tid.y == 0) {
        float totalGroupSum = 0.0;
        uint totalGroupPixels = 0;
        for (uint i = 0; i < groupSize.x * groupSize.y; i++) {
            totalGroupSum += localSums[i];
            totalGroupPixels += localPixelCount[i];
        }
        partialSums[groupId.x] = totalGroupPixels;
        
    }
    
    // First thread in the grid writes the final result
    if (gid2D.x == 0 && gid2D.y == 0) {
        float totalSum = 0.0;
        uint gridSize = (width / groupSize.x ) * (height / groupSize.y);
        for (uint i = 0; i < gridSize; i++) {
            totalSum += partialSums[i];
            
        }
        *result = totalSum;
    }
    
}



// this compute shader works for non selectable states.
kernel void computeSumLuminanceParallelNonSelectableStates(texture2d<float, access::read> yTexture [[ texture(0) ]],
                                                           device float *result [[ buffer(0) ]],
                                                           device float *partialSums [[ buffer(1) ]],
                                                           device float *count [[ buffer(2) ]],
                                                           constant SelectionState& selectionState [[ buffer(3) ]],
                                                           uint2 gid2D [[ thread_position_in_grid ]],
                                                           uint2 tid [[ thread_position_in_threadgroup ]],
                                                           uint2 groupSize [[ threads_per_threadgroup ]],
                                                           uint2 groupId [[ threadgroup_position_in_grid ]]) {
    
    
    uint width = yTexture.get_width();
    uint height = yTexture.get_height();
    
    float totalSum = 0.0;
    
    if(gid2D.x > width || gid2D.y > height){
        return;
    }
    
    float luminance = 0.0;
    
    luminance = yTexture.read(gid2D).r * 255;
    
    threadgroup float localSums[256]; // Assuming maximum threadgroup size of 16x16 (256 threads)
    localSums[tid.x + tid.y * groupSize.x] = luminance;
    
    // Synchronize threads in the threadgroup
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Only one thread in the threadgroup should write the sum to the partial sums
    if (tid.x == 0 && tid.y == 0) {
        float totalGroupSum = 0.0;
        for (uint i = 0; i < groupSize.x * groupSize.y; i++) {
            totalGroupSum += localSums[i];
        }
        partialSums[groupId.x] = totalGroupSum;
        
    }
    
    uint gridSize = (width / groupSize.x ) * (height / groupSize.y);
    for (uint i = 0; i < gridSize; i++) {
        totalSum += partialSums[i];
    }
    
    *result = totalSum;
    
}


// this compute shader works for selectable states.
kernel void computeSumLuminanceParallel(texture2d<float, access::read> yTexture [[ texture(0) ]],
                                        device float *partialSums [[ buffer(0) ]],
                                        constant SelectionState& selectionState [[ buffer(1) ]],
                                        device float *countt [[ buffer(2) ]],
                                        uint2 gid2D [[ thread_position_in_grid ]],
                                        uint2 tid [[ thread_position_in_threadgroup ]],
                                        uint2 groupSize [[ threads_per_threadgroup ]],
                                        uint2 groupId [[ threadgroup_position_in_grid ]]) {
    
    
    uint pixelCount = 0;
    float luminance = 1.0;
    
    uint width =  yTexture.get_width();
    uint height = yTexture.get_height();
    
    if(gid2D.x > width || gid2D.y > height){
        return;
    }
    
    uint selectionWidth = selectionState.x2 - selectionState.x1; //96
    uint selectionHeight = selectionState.y2 - selectionState.y1; //72
    
    *countt = selectionWidth;
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    
    threadgroup float localSums[256]; // Assuming maximum threadgroup size of 16x16 (256 threads)
   
    luminance = yTexture.read(globalID).r;
    
    
    if(globalID.x > selectionState.x2 || globalID.y > selectionState.y2){
        luminance = 0.0;
    }
    

    localSums[tid.x + tid.y * groupSize.x] = luminance;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (tid.x == 0 && tid.y == 0) {
        float totalGroupSum = 0.0;
        for (uint i = 0; i < (groupSize.x * groupSize.y); i++) {
            totalGroupSum += localSums[i];
        }
        
        uint threadGroupWidth = selectionWidth / groupSize.x ;
        partialSums[groupId.x + groupId.y * threadGroupWidth ] = totalGroupSum;
        threadgroup_barrier(mem_flags::mem_device);
    }
    
}



kernel void computeFinalSum(device float *partialSums [[ buffer(0) ]],
                            device float *result [[ buffer(1) ]],
                            constant PartialBufferLength& partialBufferLength [[ buffer(2) ]],
                            device float *count [[ buffer(3) ]],
                            uint gid [[ thread_position_in_grid ]],
                            uint tid [[ thread_position_in_threadgroup ]]
                            ) {
    
    uint numPartialSums = partialBufferLength.length;
    threadgroup float localSum[1024];
    
    *count = numPartialSums;
    
    if(gid < numPartialSums) {
        localSum[tid] = partialSums[gid];
        
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // Perform parallel reduction within the threadgroup
    uint testNumPartialSum = exp2(ceil(log2(float(numPartialSums))));
    
        for (uint stride = testNumPartialSum / 2; stride > 0; stride /= 2) {
            
            if (tid < stride && (tid + stride) < numPartialSums) {
                localSum[tid] += localSum[tid + stride];
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
        }
  
   
       if (gid == 0) {
           *result = localSum[0];
       }
}


kernel void computeHSV(texture2d<float, access::sample> cameraImageTextureY [[ texture(0) ]],
                       texture2d<float, access::sample> cameraImageTextureCbCr [[ texture(1) ]],
                       device float *result [[ buffer(0) ]],
                       uint2 gid2D [[ thread_position_in_grid ]],
                       uint2 tid [[ thread_position_in_threadgroup ]],
                       uint2 groupSize [[ threads_per_threadgroup ]],
                       uint2 groupId [[ threadgroup_position_in_grid ]]){
    

    uint2 position = uint2(0,0);
   
    // Create an object to sample textures.
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    // Sample this pixel's camera image color.
    float4 rgb = ycbcrToRGBTransform(
                                     cameraImageTextureY.sample(s, float2(gid2D)),
                                     cameraImageTextureCbCr.sample(s, float2(gid2D))
                                     );
    
    
    float minValue, maxValue;
    uint maxIndex;

    float red = rgb.r;
    float green = rgb.g;
    float blue = rgb.b;

    if(red == green && red == blue){
        maxIndex = 0;
        maxValue = red;
        minValue = red;
    } else if(red >= green && red >= blue){
        maxIndex = 1;
        maxValue = red;
        minValue = (green < blue) ? green : blue;
    }else if ((green >= red) && (green >= blue))
    {
        maxIndex = 2;
        maxValue = green;
        minValue = (red < blue) ? red : blue;
    }
    else
    {
        maxIndex = 3;
        maxValue = blue;
        minValue = (red < green) ? red : green;
    }
    
    // Now we can compute the value of h.
    float h;
    switch(maxIndex)
        {
            case 0:    h = 0.0;
                            break;
            case 1: h = 60.0 * ((green - blue) / (maxValue - minValue));
                            break;
            case 2: h = 60.0 * (2 + ((blue - red) / (maxValue - minValue)));
                            break;
            case 3: h = 60.0 * (4 + ((red - green) / (maxValue - minValue)));
                            break;
        }
    
    if (h < 0.0)
            h += 360.0;
    
    // Compute the saturation.
    float saturation;
    saturation = (maxIndex == 0) ? 0.0 : ((maxValue - minValue) / maxValue);
        
        // Compute the value.
    float value = maxValue;
    
    *result = h;
    
}
 

