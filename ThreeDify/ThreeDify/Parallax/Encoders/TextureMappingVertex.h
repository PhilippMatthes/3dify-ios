#ifndef TextureMappingVertex_h
#define TextureMappingVertex_h

typedef struct {
    float4 renderedCoordinate [[position]];
    float2 uv;
} TextureMappingVertex;

#endif /* TextureMappingVertex_h */
