uniform sampler2D colorMap;

void main(void) {
    gl_FragColor = texture2D(colorMap, vec2(gl_FragCoord.z, 0.0));
}
