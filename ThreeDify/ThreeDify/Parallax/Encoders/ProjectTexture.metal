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

// Projects provided vertices to corners of drawable texture.
vertex TextureMappingVertex project_texture(unsigned int vertex_id [[ vertex_id ]])
{
    float4x4 renderedCoordinates = float4x4(float4(-1.0, -1.0, 0.0, 1.0),
                                            float4( 1.0, -1.0, 0.0, 1.0),
                                            float4(-1.0,  1.0, 0.0, 1.0),
                                            float4( 1.0,  1.0, 0.0, 1.0));
    float4x2 uvs = float4x2(float2(0.0, 1.0),
                           float2(1.0, 1.0),
                           float2(0.0, 0.0),
                           float2(1.0, 0.0));
    TextureMappingVertex outVertex;
    outVertex.renderedCoordinate = renderedCoordinates[vertex_id];
    outVertex.uv = uvs[vertex_id];
    return outVertex;
}
