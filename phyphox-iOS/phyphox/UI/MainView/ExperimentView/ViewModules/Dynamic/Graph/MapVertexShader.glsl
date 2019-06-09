attribute vec3 position;
uniform vec3 scale;
uniform vec3 translation;

void main(void) {
    gl_Position = vec4(scale * (position + translation), 1.0);
}
