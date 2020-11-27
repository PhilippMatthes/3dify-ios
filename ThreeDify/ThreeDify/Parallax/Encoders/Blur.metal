//
// 3Dify App
//
// Project website: https://github.com/3dify-app
//
// Authors:
// - Philipp Matthes 2020, Contact: mail@philippmatth.es
//
// Copyright notice: All rights reserved by the authors given above. Do not
// remove or change this copyright notice without confirmation of the authors.
//

#include <metal_stdlib>
using namespace metal;
#include "TextureMappingVertex.h"


constant float offset[] = { 0.0, 1.0, 2.0, 3.0, 4.0 };
constant half weight[] = { 0.2270270270, 0.1945945946, 0.1216216216, 0.0540540541, 0.0162162162 };
constant float bufferSize = 512.0;

constexpr sampler s = sampler(coord::normalized, r_address::clamp_to_edge, t_address::repeat, filter::linear);

struct BlurPassOutput {
    half4 blurred [[color(0)]];
};

typedef struct {
    bool isVertical;
    float blurIntensity;
    float focalPoint;
} BlurUniforms;


half4 blur_fragment(bool isVertical,
                     float2 uv,
                     float intensity,
                     float focalPoint,
                     texture2d<half, access::sample> diffuse,
                     texture2d<half, access::sample> depth)
{
    half4 color = diffuse.sample(s, uv) * weight[0];
    float depthIntensity = abs(depth.sample(s, uv).r - focalPoint) * intensity;
    
    for (int i=1; i<5; i++) {
        if (isVertical) {
            color += diffuse.sample( s, ( uv + float2(0.0, depthIntensity * offset[i])/bufferSize ) ) * weight[i];
            color += diffuse.sample( s, ( uv - float2(0.0, depthIntensity * offset[i])/bufferSize ) ) * weight[i];
        } else {
            color += diffuse.sample(s, ( uv + float2(depthIntensity * offset[i], 0.0)/bufferSize ) ) * weight[i];
            color += diffuse.sample(s, ( uv - float2(depthIntensity * offset[i], 0.0)/bufferSize ) ) * weight[i];
        }
    }
    
    return color;
};


fragment BlurPassOutput blur(
    TextureMappingVertex vert [[stage_in]],
    texture2d<half> diffuseTexture [[texture(0)]],
    texture2d<half> depthTexture [[texture(1)]],
    constant BlurUniforms *uniforms [[buffer(0)]]
) {
    
    BlurPassOutput output;
    if (uniforms->blurIntensity == 0) {
        output.blurred = diffuseTexture.sample(s, vert.uv);
    } else {
        output.blurred = blur_fragment(uniforms->isVertical,
                                       vert.uv,
                                       uniforms->blurIntensity,
                                       uniforms->focalPoint,
                                       diffuseTexture,
                                       depthTexture);
    }
    return output;
}
