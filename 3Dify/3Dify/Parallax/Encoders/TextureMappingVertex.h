//
//  TextureMappingVertex.h
//  DoFRendering
//
//  Created by Bartłomiej Nowak on 14/11/2018.
//  Copyright © 2018 Bartłomiej Nowak. All rights reserved.
//

#ifndef TextureMappingVertex_h
#define TextureMappingVertex_h

typedef struct {
    float4 renderedCoordinate [[position]];
    float2 uv;
} TextureMappingVertex;

#endif /* TextureMappingVertex_h */
