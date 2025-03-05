//
//  CameraGUIShader.metal
//  phyphox
//
//  Created by Sebastian Staacks on 05.03.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

#import "../../../../../Helper/ShaderTypes.h"
#import "../../../../../Helper/Shaders.h"

using namespace metal;

vertex CamColorInOut cameraGUIvertexTransform(const device CamVertex* cameraVertices [[ buffer(0) ]],
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

fragment half4 cameraGUIfragmentShader(CamColorInOut in [[ stage_in ]],
                              texture2d<float, access::sample> cameraImageTextureY [[ texture(0) ]],
                              texture2d<float, access::sample> cameraImageTextureCbCr [[ texture(1) ]],
                              constant SelectionState& selectionState [[buffer(2)]],
                              constant ShaderColorModifier& colorModifier [[buffer(3)]])
{
    
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

    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float4 luma = cameraImageTextureY.sample(s, in.texCoordCamera);
    float4 rgb = ycbcrToRGBTransform(luma, cameraImageTextureCbCr.sample(s, in.texCoordCamera));
    
    if (!isnan(colorModifier.overexposureColor.r) && any(rgb > float4(0.99, 0.99, 0.99, 1.0))) {
        rgb = float4(colorModifier.overexposureColor, 1.0);
    } else if (!isnan(colorModifier.underexposureColor.r) && any(rgb < float4(0.01, 0.01, 0.01, 0.0))) {
        rgb = float4(colorModifier.underexposureColor, 1.0);
    } else if (colorModifier.grayscale) {
        rgb = float4(luma.r, luma.r, luma.r, 1.0);
    }
    
    if (in.position.x < selectionState.x1 || in.position.x > selectionState.x2 || in.position.y < selectionState.y1 || in.position.y > selectionState.y2) {
        return mix(half4(rgb), half4(0.0, 0.0, 0.0, 1.0), 0.5);
    } else {
        return half4(rgb);
    }
}
