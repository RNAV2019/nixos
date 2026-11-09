#version 440
// Clips a source texture to a rounded rectangle with an antialiased edge.
// Output is premultiplied alpha.
//
// The texture can be drawn smaller or larger about a pivot (`scale`) and softened (`blur`, a
// radius in item px), which is how a surface's contents grow out of the pill with the card and
// one panel's contents dissolve into the next's. At scale 1 and blur 0 it is one tap, texel for
// texel.
//
// During a content morph (Ui/MorphLayer.qml) a second texture of the same box says, in its red
// channel, how much of the contents shows at each point: the elements still flying in from the
// panel before are held back until their ghosts land.
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
    vec2 pivot;     // the point the contents scale about, item px
    float scale;    // 1 at rest
    float blur;     // blur radius, item px; 0 at rest
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D mask;

float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Nothing outside the texture: scaled down, the contents end where their box does.
vec4 tap(vec2 uv) {
    vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
    return texture(source, uv) * (inside.x * inside.y);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec2 p = px - boxOrigin - boxSize * 0.5;
    float d = sdRoundBox(p, boxSize * 0.5, radius);
    float a = smoothstep(aa, -aa, d);

    vec2 uv = (pivot + (px - pivot) / max(scale, 0.01)) / itemSize;
    vec4 c;
    if (blur > 0.05) {
        // A disc of 16 taps on a golden-angle spiral, weighted toward the middle.
        vec2 r = vec2(blur) / itemSize;
        c = tap(uv) * 2.0;
        float total = 2.0;
        for (int i = 0; i < 16; i++) {
            float f = (float(i) + 0.5) / 16.0;
            float ang = float(i) * 2.39996323;
            float wgt = 1.5 - f;
            c += tap(uv + vec2(cos(ang), sin(ang)) * sqrt(f) * r) * wgt;
            total += wgt;
        }
        c /= total;
    } else {
        c = tap(uv);
    }
    // The mask is a picture of the same box, so it is read where the contents are.
    float shown = mix(1.0, texture(mask, uv).r, useMask);
    fragColor = c * (a * shown * qt_Opacity);
}
