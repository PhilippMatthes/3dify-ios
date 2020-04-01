//
//  ProjectTexture.metal
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "TextureMappingVertex.h"

/// Projects provided vertices to corners of drawable texture.
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
