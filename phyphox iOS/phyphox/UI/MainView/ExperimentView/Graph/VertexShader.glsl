attribute vec2 position;

uniform vec2 scale;
uniform vec2 translation;
uniform float pointSize;
uniform vec4 inColor;

varying lowp vec4 outColor;

void main(void) {
    outColor = inColor;
    gl_Position = vec4((scale * (position + translation)), 0.0, 1.0);
    gl_PointSize = pointSize;
}
