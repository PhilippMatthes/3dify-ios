attribute vec4 vertexPosition;
attribute vec2 texCoord;

uniform mat4 modelViewProjectionMatrix;

varying vec2 vTexCoord;


void main() {
    vTexCoord = texCoord;
    gl_Position = modelViewProjectionMatrix * vertexPosition;
}
