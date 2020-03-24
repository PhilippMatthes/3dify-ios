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

struct Uniforms {
    float2 offset;
};

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

float2 parallaxOcclusionMapping(float2 offset,
                                float2 texCoords,
                                texture2d<float, access::sample> depthTexture) {
    constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);
    
    int layers = 128;
    float pivot = 1.0;

    float layerDepth = 1.0 / float( layers );
    float currentLayerDepth = 0.0;

    float2 deltaUv = offset / float( layers );
    float2 currentUv = texCoords + pivot * offset;
    float currentDepth = 1.0 - depthTexture.sample(sampler2d, currentUv).r;

    for( int i = 0; i < layers; i++ ) {
        if( currentLayerDepth > currentDepth ) {
            break;
        }

        currentUv -= deltaUv;
        currentDepth = 1.0 - depthTexture.sample(sampler2d, currentUv).r;
        currentLayerDepth += layerDepth;
    }

    float2 prevUv = currentUv + deltaUv;
    float endDepth = currentDepth - currentLayerDepth;
    float startDepth =
        depthTexture.sample(sampler2d, prevUv).r - currentLayerDepth + layerDepth;

    float w = endDepth / ( endDepth - startDepth );

    return mix( currentUv, prevUv, w );
}

fragment half4 myFragment(SimpleVertex in [[stage_in]],
                          texture2d<float, access::sample> diffuseTexture [[texture(0)]],
                          texture2d<float, access::sample> depthTexture [[texture(1)]],
                          constant Uniforms& uniforms [[buffer(2)]])
{
    constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);
    
    float2 parallaxUv = parallaxOcclusionMapping(uniforms.offset, in.texCoords, depthTexture);
    
    float4 diffuseColor = diffuseTexture.sample(sampler2d, parallaxUv);
    return half4(diffuseColor);
}
