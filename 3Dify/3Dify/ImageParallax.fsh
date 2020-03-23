

void main() {
    int layers = 128;
    float pivot = 1.0;
    
    const float layerDepth = 1.0 / float( layers );
    float currentLayerDepth = 0.0;

    vec2 deltaUv = u_offset / float( layers );
    vec2 currentUv = v_tex_coord + pivot * u_offset;
    float currentDepth = 1.0 - texture2D( u_image_depth, currentUv ).r;

    for( int i = 0; i < layers; i++ ) {
        if( currentLayerDepth > currentDepth ) {
            break;
        }

        currentUv -= deltaUv;
        currentDepth = 1.0 - texture2D( u_image_depth, currentUv ).r;
        currentLayerDepth += layerDepth;
    }

    vec2 prevUv = currentUv + deltaUv;
    float endDepth = currentDepth - currentLayerDepth;
    float startDepth =
        texture2D( u_image_depth, prevUv ).r - currentLayerDepth + layerDepth;

    float w = endDepth / ( endDepth - startDepth );

    vec2 newTexCoord = mix( currentUv, prevUv, w );
    
    vec4 depthColor = texture2D(u_image_depth, newTexCoord);
    vec4 imageColor = texture2D(u_image, newTexCoord);
    vec4 visualizationColor = vec4(newTexCoord, 0.0, 1.0);
    
    gl_FragColor = mix(depthColor, imageColor, 1.0);
}
