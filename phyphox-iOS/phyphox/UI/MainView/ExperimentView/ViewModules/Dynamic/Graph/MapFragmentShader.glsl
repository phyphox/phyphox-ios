uniform sampler2D colorMap;

void main(void) {
    gl_FragColor = vec4(texture2D(colorMap, vec2(gl_FragCoord.z, 0.0)).rgb, 1.0);
}
