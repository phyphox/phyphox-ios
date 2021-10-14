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

