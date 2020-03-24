precision highp float;

uniform sampler2D image;
uniform sampler2D imageDepth;
uniform vec2 offset;

varying highp vec2 vTexCoord;


void main() {
    int layers = 128;
    float pivot = 1.0;

    float layerDepth = 1.0 / float( layers );
    float currentLayerDepth = 0.0;

    vec2 deltaUv = offset / float( layers );
    vec2 currentUv = vTexCoord + pivot * offset;
    float currentDepth = 1.0 - texture2D( imageDepth, currentUv ).r;

    for( int i = 0; i < layers; i++ ) {
        if( currentLayerDepth > currentDepth ) {
            break;
        }

        currentUv -= deltaUv;
        currentDepth = 1.0 - texture2D( imageDepth, currentUv ).r;
        currentLayerDepth += layerDepth;
    }

    vec2 prevUv = currentUv + deltaUv;
    float endDepth = currentDepth - currentLayerDepth;
    float startDepth =
        texture2D( imageDepth, prevUv ).r - currentLayerDepth + layerDepth;

    float w = endDepth / ( endDepth - startDepth );

    vec2 newTexCoord = mix( currentUv, prevUv, w );

    vec4 depthColor = texture2D(imageDepth, newTexCoord);
    vec4 imageColor = texture2D(image, newTexCoord);
    vec4 visualizationColor = vec4(newTexCoord, 0.0, 1.0);
    
    gl_FragColor = imageColor;
}
