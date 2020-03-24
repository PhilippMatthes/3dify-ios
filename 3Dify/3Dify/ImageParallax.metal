//
//  Parallax.metal
//  3Dify
//
//  Created by It's free real estate on 24.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include <SceneKit/scn_metal>

struct MyNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewTransform;
    float4x4 normalTransform;
    float4x4 modelViewProjectionTransform;
};

typedef struct {
    float3 position [[ attribute(SCNVertexSemanticPosition) ]];
    float2 texCoords [[ attribute(SCNVertexSemanticTexcoord0) ]];
} MyVertexInput;

struct SimpleVertex
{
    float4 position [[position]];
    float2 texCoords;
};

vertex SimpleVertex myVertex(MyVertexInput in [[ stage_in ]],
                             constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                             constant MyNodeBuffer& scn_node [[buffer(1)]])
{
    SimpleVertex vert;
    vert.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    vert.texCoords = in.texCoords;

    return vert;
}

fragment half4 myFragment(SimpleVertex in [[stage_in]],
                          texture2d<float, access::sample> diffuseTexture [[texture(0)]])
{
    constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);
    float4 color = diffuseTexture.sample(sampler2d, in.texCoords);
    return half4(color);
}
