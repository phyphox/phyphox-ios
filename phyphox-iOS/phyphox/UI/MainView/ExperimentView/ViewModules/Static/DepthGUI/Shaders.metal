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



struct Mode {
    HSV_Mode enumValue;
};

struct Mode_HSV {
    float mode; // 0.0 for Hue, 1.0 for Staturation, 2.0 for Value
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


kernel void computeLuma(texture2d<float, access::read> yTexture [[ texture(0) ]],
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


kernel void computeLuminance(texture2d<float, access::sample> cameraImageTextureY [[ texture(0) ]],
                             texture2d<float, access::sample> cameraImageTextureCbCr [[ texture(1) ]],
                             device float *partialSums [[ buffer(0) ]],
                             constant SelectionState& selectionState [[ buffer(1) ]],
                             uint2 gid2D [[ thread_position_in_grid ]],
                             uint2 tid [[ thread_position_in_threadgroup ]],
                             uint2 groupSize [[ threads_per_threadgroup ]],
                             uint2 groupId [[ threadgroup_position_in_grid ]]) {
    
    
    uint pixelCount = 0;
    float luminance = 1.0;
    
    uint width =  cameraImageTextureY.get_width();
    uint height = cameraImageTextureY.get_height();
    
    if(gid2D.x > width || gid2D.y > height){
        return;
    }
    
    uint selectionWidth = selectionState.x2 - selectionState.x1; //96
    uint selectionHeight = selectionState.y2 - selectionState.y1; //72
    
    uint2 globalID = gid2D + uint2(selectionState.x1, selectionState.y1);
    
    // Create an object to sample textures.
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    // Sample this pixel's camera image color.
    float4 rgb = ycbcrToRGBTransform(
                                     cameraImageTextureY.sample(s, float2(gid2D)),
                                     cameraImageTextureCbCr.sample(s, float2(gid2D))
                                     );
    
    float red = rgb.r;
    float green = rgb.g;
    float blue = rgb.b;
    
    threadgroup float localSums[256];
    
    luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
    
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
                            uint gid [[ thread_position_in_grid ]],
                            uint tid [[ thread_position_in_threadgroup ]]
                            ) {
    
    uint numPartialSums = 35; // TODO: fix: numPartialSums is not receiving the value from CPU, hard coded need to be refactored
    threadgroup float localSum[1024];
    
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
    uint selectionHeight = selectionState.y2 - selectionState.y1; //72
    
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


enum HSV_Mode: uint {
    Hue = 0,
    Saturation = 1,
    Value = 2,
    };
    
