#version 440
// Clips a source texture to a rounded rectangle with an antialiased edge.
// Output is premultiplied alpha.
//
// During a content morph (Ui/MorphLayer.qml) a second texture of the same box says, in its red
// channel, how much of the contents shows at each point: the elements still flying in from the
// panel before are held back, and the new ones arrive one after another.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 boxSize;   // clip rectangle size, item px
    vec2 boxOrigin; // its top-left inside the item, item px
    vec2 itemSize;  // the ShaderEffect item size, item px (maps qt_TexCoord0 to px)
    float radius;
    float aa;       // antialias width, item px (1 / devicePixelRatio)
    float useMask;  // 1 while a morph's mask is live, else 0
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D mask;

float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize - boxOrigin - boxSize * 0.5;
    float d = sdRoundBox(p, boxSize * 0.5, radius);
    float a = smoothstep(aa, -aa, d);
    vec4 c = texture(source, qt_TexCoord0);
    float shown = mix(1.0, texture(mask, qt_TexCoord0).r, useMask);
    fragColor = c * (a * shown * qt_Opacity);
}
