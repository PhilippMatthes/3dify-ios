//
//  Bokeh.metal
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "../TextureMappingVertex.h"

typedef struct {
    float2 texelSize;
    float bokehRadius;
} BokehUniforms;

// From https://github.com/Unity-Technologies/PostProcessing/blob/v2/PostProcessing/Shaders/Builtins/DiskKernels.hlsl
static constant int diskKernelSampleCount = 16;
static constant float2 diskKernel[diskKernelSampleCount] = {
    float2(0, 0),
    float2(0.54545456, 0),
    float2(0.16855472, 0.5187581),
    float2(-0.44128203, 0.3206101),
    float2(-0.44128197, -0.3206102),
    float2(0.1685548, -0.5187581),
    float2(1, 0),
    float2(0.809017, 0.58778524),
    float2(0.30901697, 0.95105654),
    float2(-0.30901703, 0.9510565),
    float2(-0.80901706, 0.5877852),
    float2(-1, 0),
    float2(-0.80901694, -0.58778536),
    float2(-0.30901664, -0.9510566),
    float2(0.30901712, -0.9510565),
    float2(0.80901694, -0.5877853),
};

constexpr sampler texSampler(address::clamp_to_edge, filter::linear, coord::normalized);

half weigh(half coc, half radius)
{
    return clamp((coc - radius) / 2, (half)0.1, (half)1.0);
}

fragment half4 bokeh(TextureMappingVertex vert [[stage_in]],
                     constant BokehUniforms *uniforms [[buffer(0)]],
                     texture2d<float, access::sample> colorTex [[texture(0)]],
                     texture2d<float, access::sample> cocTex [[texture(1)]])
{
    half3 color = 0;
    half weight = 0;
    for (int k = 0; k < diskKernelSampleCount; k++) {
        float2 o = diskKernel[k] * uniforms->bokehRadius;
        half radius = length(o) * 0.1;
        o *= uniforms->texelSize.xy;
        half3 s = (half3)colorTex.sample(texSampler, vert.uv + o).rgb;
        half coc = (half)cocTex.sample(texSampler, vert.uv + o).r;
        half sw = weigh(abs(coc), radius);
        color += s * sw;
        weight += sw;
    }
    color *= 1.0 / weight;
    return half4(color, 1);
}
