//
//  Compose.metal
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 16/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "../TextureMappingVertex.h"

constexpr sampler texSampler(address::clamp_to_zero, filter::linear, coord::normalized);

half3 lerp(half3 a, half3 b, half w)
{
    return a + w*(b-a);
}

fragment half4 compose(TextureMappingVertex vert [[stage_in]],
                       constant float2& texelSize [[buffer(0)]],
                       texture2d<float, access::sample> colorTex [[texture(0)]],
                       texture2d<float, access::sample> dofTex [[texture(1)]],
                       texture2d<float, access::sample> cocTex [[texture(2)]])
{
    half3 source = (half3)colorTex.sample(texSampler, vert.uv).rgb;
    half4 dof = (half4)dofTex.sample(texSampler, vert.uv);
    half coc = (half)cocTex.sample(texSampler, vert.uv).r;
    half dofStrength = smoothstep(half(0.1), half(1), abs(coc));
    half3 color = lerp(source, dof.rgb, dofStrength);
    return half4(color, 1);
}

