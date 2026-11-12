#version 440
// Takes the bar's island out of a capture of the desktop, so the lock's own pill can leave the
// spot without a ghost staying behind. `capture` is the stretch of the capture this item lies
// over, `wallpaper` the same stretch of the wallpaper.
//
// Inside the island's pill (and the phone satellite's disc and neck beside it) the wallpaper is
// put back: nothing else is ever under the bar. Around it the island's drop shadow is lifted
// off whatever it fell on, a window's top edge included, by dividing its darkening back out;
// the shadow is the one Shaders/shadow.frag draws, solved the same way. Everything else is the
// capture as it was. Output is premultiplied alpha, opaque.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // the ShaderEffect item size, item px (maps qt_TexCoord0 to px)
    vec2 boxOrigin;  // the island's top-left inside the item, item px
    vec2 boxSize;    // the island's size, item px
    float radius;    // its corner radius, item px
    float sigma;     // its shadow's standard deviation, item px
    vec2 offset;     // its shadow's offset, item px
    float strength;  // its shadow's peak alpha
    vec2 discCentre; // the satellite's disc, item px
    float discRadius; // its radius, item px; 0 when there is none
    float aa;        // antialias width, item px
    float amount;    // 0 leaves the capture alone, 1 patches it
};

layout(binding = 1) uniform sampler2D capture;
layout(binding = 2) uniform sampler2D wallpaper;

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

float sdCapsule(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

void main() {
    vec2 halfSize = boxSize * 0.5;
    float r = min(radius, min(halfSize.x, halfSize.y));
    vec2 at = qt_TexCoord0 * itemSize;
    vec2 p = at - boxOrigin - halfSize;

    // A pixel wider than the island, so the antialiased rim of the captured pill goes too.
    float island = smoothstep(aa, -aa, sdRoundBox(p, halfSize, r) - aa);
    float satellite = 0.0;
    if (discRadius > 0.0) {
        vec2 from = boxOrigin + vec2(boxSize.x - r, halfSize.y);
        satellite = smoothstep(aa, -aa, sdCapsule(at, from, discCentre, discRadius) - aa);
    }
    float hole = max(island, satellite);

    float shadow = clamp(roundedBoxShadow(p - offset, halfSize, max(sigma, 0.5), r), 0.0, 1.0) * strength;
    vec3 was = texture(capture, qt_TexCoord0).rgb;
    vec3 lifted = min(was / max(1.0 - shadow, 0.25), vec3(1.0));
    vec3 patched = mix(lifted, texture(wallpaper, qt_TexCoord0).rgb, hole);

    fragColor = vec4(mix(was, patched, amount), 1.0) * qt_Opacity;
}
