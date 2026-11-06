#version 440
// The phone satellite: the pill's right cap and a disc, joined by a smooth union, drawn as one
// filled shape with a 1 px outline. The neck between them is the union's own fillet; `neck` (the
// smooth-min k, px) thins as the disc travels away and the stubs a broken neck leaves are the
// same fillet, so there is no separate stub geometry. Output is premultiplied alpha.
//
// Every position is in the parent's coordinates (the window's), so the QML properties and the
// uniforms are the same numbers; `origin` is where the item sits there and `itemSize` how big it is.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;     // the ShaderEffect item size, px
    vec2 origin;       // its top-left in the parent, px
    vec2 pillEdge;     // x of the shape's right edge, y of its centre
    float pillHalfH;   // half the shape's height
    float capRadius;   // corner radius of its right end
    float neck;        // smooth-min k, px; 0 keeps the two apart
    float outlineWidth;
    vec3 disc;         // cx, cy, r
    float aa;          // antialias width, px (1 / devicePixelRatio)
    vec4 fill;         // premultiplied
    vec4 outline;      // premultiplied
};

float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Polynomial smooth minimum: min(a, b) pulled down by up to k / 4 where the two are within k.
float smin(float a, float b, float k) {
    if (k <= 0.0)
        return min(a, b);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize + origin;
    // The shape reaches far to the left of its cap; the item cuts it off there, where it lies on
    // the pill's own outline.
    float halfW = capRadius * 2.0;
    float dPill = sdRoundBox(p - vec2(pillEdge.x - halfW, pillEdge.y), vec2(halfW, pillHalfH), capRadius);
    float dDisc = length(p - disc.xy) - disc.z;
    float d = smin(dPill, dDisc, neck);

    float outer = smoothstep(0.5 * aa, -0.5 * aa, d);
    // The pill under the cap paints its own fill, and its contents (a label's last letters, a
    // cancel glyph) reach into the cap. Only the strip along its outline is covered, so the
    // outline does not show through the neck; d <= dPill, so no outline band lies deeper.
    float cover = smoothstep(-(outlineWidth + 2.0 * aa), -(outlineWidth + aa), dPill);
    outer *= cover;
    float inner = cover * smoothstep(0.5 * aa, -0.5 * aa, d + outlineWidth);
    float band = outer - inner;
    vec4 c = fill * outer;
    c = c * (1.0 - outline.a * band) + outline * band;
    fragColor = c * qt_Opacity;
}
