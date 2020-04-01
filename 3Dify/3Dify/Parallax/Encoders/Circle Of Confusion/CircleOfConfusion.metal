//
//  CircleOfConfusion.metal
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "../TextureMappingVertex.h"

typedef struct {
    float focusDist, focusRange, bokehRadius;
} CoCUniforms;

constexpr sampler texSampler(address::clamp_to_zero, filter::linear, coord::normalized);

fragment half
circle_of_confusion_pass(TextureMappingVertex vert [[stage_in]],
                         constant CoCUniforms *uni [[buffer(0)]],
                         depth2d<float, access::sample> depthTex [[texture(0)]])
{
    half depth = depthTex.sample(texSampler, vert.uv);
    float coc = (depth - uni->focusDist) / uni->focusRange;
    return half(clamp(coc, -1.0, 1.0) * float(uni->bokehRadius));
}
