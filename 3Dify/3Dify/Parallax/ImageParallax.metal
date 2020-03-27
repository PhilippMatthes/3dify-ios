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
                                texture2d<float, access::sample> depthTexture,
                                float minLayers,
                                float maxLayers,
                                float pivot,
                                float heightScale)
{
    constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);

    const float numLayers = mix(maxLayers, minLayers, abs(dot(float3(0.0, 0.0, 1.0), float3(offset, -1.0))));
    // calculate the size of each layer
    const float layerDepth = 1.0 / numLayers;
    
    // depth of current layer
    float currentLayerDepth = 0.0;
    // the amount to shift the texture coordinates per layer (from vector P)
    const float2 P = offset * heightScale;
    const float2 deltaTexCoords = P / numLayers;
    
    // get initial values
    float2 currentTexCoords = texCoords + pivot * offset;
    float currentDepthMapValue = 1.0 - depthTexture.sample(sampler2d, currentTexCoords).r;
      
    while(currentLayerDepth < currentDepthMapValue)
    {
        // shift texture coordinates along direction of P
        currentTexCoords -= deltaTexCoords;
        // get depthmap value at current texture coordinates
        currentDepthMapValue = 1.0 - depthTexture.sample(sampler2d, currentTexCoords).r;
        // get depth of next layer
        currentLayerDepth += layerDepth;
    }

    // get texture coordinates before collision (reverse operations)
    const float2 prevTexCoords = currentTexCoords + deltaTexCoords;

    // get depth after and before collision for linear interpolation
    const float afterDepth = currentDepthMapValue - currentLayerDepth;
    const float beforeDepth = 1.0 - depthTexture.sample(sampler2d, prevTexCoords).r - currentLayerDepth + layerDepth;
     
    // interpolation of texture coordinates
    const float weight = afterDepth / (afterDepth - beforeDepth);
    const float2 finalTexCoords = prevTexCoords * weight + currentTexCoords * (1.0 - weight);

    return finalTexCoords;
}

float2 parallaxOcclusionMapping(float2 offset,
                                float2 texCoords,
                                texture2d<float, access::sample> depthTexture)
{
    // number of depth layers
    const float minLayers = 32.0;
    const float maxLayers = 128.0;
    
    // the rotation base depth
    const float pivot = 1.0;
    
    // the scale of depth
    const float heightScale = 1.0;
    
    return parallaxOcclusionMapping(offset, texCoords, depthTexture, minLayers, maxLayers, pivot, heightScale);
}

fragment half4 myFragment(SimpleVertex in [[stage_in]],
                          texture2d<float, access::sample> diffuseTexture [[texture(0)]],
                          texture2d<float, access::sample> depthTexture [[texture(1)]],
                          constant Uniforms& uniforms [[buffer(2)]])
{
    constexpr sampler sampler2d(coord::normalized, filter::linear, address::repeat);
    
    float2 parallaxUv = parallaxOcclusionMapping(uniforms.offset, in.texCoords, depthTexture);
    
    float4 diffuseColor = diffuseTexture.sample(sampler2d, parallaxUv);
    // float depthColor = depthTexture.sample(sampler2d, parallaxUv).r;
    return half4(diffuseColor);
}
