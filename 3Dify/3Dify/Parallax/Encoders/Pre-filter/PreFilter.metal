//
//  PreFilter.metal
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "../TextureMappingVertex.h"

constexpr sampler texSampler(address::clamp_to_edge, filter::linear, coord::normalized);

typedef struct {
    half4 color [[color(0)]];
    half coc [[color(1)]];
} DownsampleOutput;

/// Takes the most extreme CoC value out of the four texels and puts it into the alpha channel
fragment DownsampleOutput downsample_coc(TextureMappingVertex vert [[stage_in]],
                                         constant float2& texelSize [[buffer(0)]],
                                         texture2d<float, access::sample> colorTex [[texture(0)]],
                                         texture2d<float, access::sample> cocTex [[texture(1)]])
{
    float4 o = texelSize.xyxy * float2(-0.5, 0.5).xxyy;
    half coc0 = cocTex.sample(texSampler, vert.uv + o.xy).r;
    half coc1 = cocTex.sample(texSampler, vert.uv + o.zy).r;
    half coc2 = cocTex.sample(texSampler, vert.uv + o.xw).r;
    half coc3 = cocTex.sample(texSampler, vert.uv + o.zw).r;
    half cocMin = min(min(min(coc0, coc1), coc2), coc3);
    half cocMax = max(max(max(coc0, coc1), coc2), coc3);
    half coc = cocMax >= -cocMin ? cocMax : cocMin;
    DownsampleOutput out;
    out.color = (half4)colorTex.sample(texSampler, vert.uv);
    out.coc = coc;
    return out;
}


