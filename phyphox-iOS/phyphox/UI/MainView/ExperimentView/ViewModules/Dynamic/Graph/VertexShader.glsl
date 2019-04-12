attribute vec2 position;
uniform vec2 scale;
uniform vec2 translation;
uniform lowp float pointSize;

void main(void) {
    gl_Position = vec4(scale * (position + translation), 0.0, 1.0);
    gl_PointSize = pointSize;
}
