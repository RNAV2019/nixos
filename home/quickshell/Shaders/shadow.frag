#version 440
// A soft drop shadow for a rounded rectangle: the shape blurred by a Gaussian, solved
// analytically (an erf across x, a few Gaussian-weighted samples down y), so it costs the
// same at any size and tracks a shape that changes every frame. After Evan Wallace's
// "Fast Rounded Rectangle Shadows".
//
// The shape's own footprint is cut out, so a ground that fades during a handoff never shows
// its shadow through itself. Output is premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;  // the ShaderEffect item size, item px (maps qt_TexCoord0 to px)
    vec2 boxOrigin; // the shape's top-left inside the item, item px
    vec2 boxSize;   // the shape's size, item px
    float radius;   // the shape's corner radius, item px
    float sigma;    // the Gaussian's standard deviation, item px
    vec2 offset;    // the shadow's offset from the shape, item px
    float strength; // peak alpha of the shadow
    float aa;       // antialias width of the cut-out, item px
};

const float PI = 3.141592653589793;

float gaussian(float x, float s) {
    return exp(-(x * x) / (2.0 * s * s)) / (sqrt(2.0 * PI) * s);
}

vec2 erf2(vec2 x) {
    vec2 s = sign(x);
    vec2 a = abs(x);
    x = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
    x *= x;
    return s - s / (x * x);
}

float shadowX(float x, float y, float s, float r, vec2 halfSize) {
    float delta = min(halfSize.y - r - abs(y), 0.0);
    float curved = halfSize.x - r + sqrt(max(0.0, r * r - delta * delta));
    vec2 integral = 0.5 + 0.5 * erf2((x + vec2(-curved, curved)) * (sqrt(0.5) / s));
    return integral.y - integral.x;
}

float roundedBoxShadow(vec2 p, vec2 halfSize, float s, float r) {
    float low = p.y - halfSize.y;
    float high = p.y + halfSize.y;
    float start = clamp(-3.0 * s, low, high);
    float end = clamp(3.0 * s, low, high);
    float stepY = (end - start) / 12.0;
    float y = start + stepY * 0.5;
    float value = 0.0;
    for (int i = 0; i < 12; i++) {
        value += shadowX(p.x, p.y - y, s, r, halfSize) * gaussian(y, s) * stepY;
        y += stepY;
    }
    return value;
}

float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 halfSize = boxSize * 0.5;
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 p = qt_TexCoord0 * itemSize - boxOrigin - halfSize;
    float shadow = roundedBoxShadow(p - offset, halfSize, max(sigma, 0.5), r);
    float inside = smoothstep(aa, -aa, sdRoundBox(p, halfSize, r));
    float a = clamp(shadow, 0.0, 1.0) * (1.0 - inside) * strength * qt_Opacity;
    fragColor = vec4(0.0, 0.0, 0.0, a);
}
