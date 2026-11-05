#version 440
// The media card's hills: three layers, each two slow sine waves under an envelope that rises
// from the start of the track and eases off into the thumb. A port of the Canvas that drew
// them (same frequencies, speeds, scales and envelope), so the card costs no software paint
// and no texture upload per frame. Output is premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;     // seconds of playing time, drives the waves
    vec2 itemSize;   // the ShaderEffect item size, item px (the whole track wide)
    float amplitude; // 0 flat .. 1 full hills
    float progress;  // played fraction of the track, 0..1
    vec4 ink0;       // back to front, straight alpha (alpha is the layer's opacity)
    vec4 ink1;
    vec4 ink2;
};

float ease(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / max(1.0, edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// Height of one layer at x, px.
float hill(float x, float w, float f1, float f2, float s1, float s2, float k) {
    float envelope = ease(0.0, w * 0.3, x) * (1.0 - 0.6 * ease(w - 36.0, w, x));
    float wave = (sin(x * f1 + phase * s1) + sin(x * f2 + phase * s2)) * 0.5;
    return itemSize.y * k * amplitude * envelope * (0.55 + 0.45 * wave);
}

// Source-over of a layer with straight colour c over a premultiplied destination.
vec4 over(vec4 dst, vec4 c, float cover) {
    float a = c.a * cover;
    return dst * (1.0 - a) + vec4(c.rgb * a, a);
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float w = progress * itemSize.x;
    // Pixel coverage of the played region's right edge (the thumb) and below each curve.
    float inside = clamp(w - p.x + 0.5, 0.0, 1.0);
    float below = p.y + 0.5 - itemSize.y;
    vec4 c = vec4(0.0);
    c = over(c, ink0, clamp(below + hill(p.x, w, 0.045, 0.11, 0.9, -1.3, 1.0), 0.0, 1.0) * inside);
    c = over(c, ink1, clamp(below + hill(p.x, w, 0.07, 0.031, -0.7, 1.1, 0.8), 0.0, 1.0) * inside);
    c = over(c, ink2, clamp(below + hill(p.x, w, 0.028, 0.083, 1.4, 0.6, 0.62), 0.0, 1.0) * inside);
    fragColor = c * qt_Opacity;
}
