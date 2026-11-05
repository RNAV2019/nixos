#version 440
// Clips a source texture to a rounded rectangle with an antialiased edge.
// Output is premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 boxSize;   // clip rectangle size, item px
    vec2 boxOrigin; // its top-left inside the source, item px
    float radius;
    float aa;       // antialias width, item px (1 / devicePixelRatio)
};

layout(binding = 1) uniform sampler2D source;

float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * boxSize - boxOrigin - boxSize * 0.5;
    float d = sdRoundBox(p, boxSize * 0.5, radius);
    float a = smoothstep(aa, -aa, d);
    vec4 c = texture(source, qt_TexCoord0);
    fragColor = c * (a * qt_Opacity);
}
