#version 440
// The phone satellite: the pill's right cap and a disc, joined while the neck holds, drawn as one
// filled shape (an outline is drawn if one is given) over the disc's drop shadow, the shell's
// Gaussian (Shaders/shadow.frag); the pill under the cap casts its own. The neck is a rolling-ball fillet (circular blend): a ball of
// radius `neck` that touches both bodies, so the join is a concave, waisted bridge that thins as the
// disc draws away and pinches off at the gap where the ball no longer reaches both, as a metaball's
// does. After the break, `stub` draws the two broken ends as rounded tips, and `bulge` swells the
// cap while a disc is drawn in. Output is premultiplied alpha.
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
    float neck;        // the fillet ball's radius, px; 0 keeps the two apart
    float outlineWidth;
    vec3 disc;         // cx, cy, r
    float aa;          // antialias width, px (1 / devicePixelRatio)
    vec2 stub;         // the broken ends: how far each reaches past its body, and its radius, px
    float bulge;       // how far the cap swells, px
    vec4 fill;         // premultiplied
    vec4 outline;      // premultiplied
    float shadowSigma;    // the drop shadow's standard deviation, px
    float shadowOffsetY;  // how far down it falls, px
    float shadowStrength; // its peak alpha; 0 for none
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

// A disc is a rounded box whose corner radius is half its side.
float discShadow(vec2 p, float r, float s) {
    vec2 halfSize = vec2(r);
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

float sdSegment(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

// Polynomial smooth minimum: min(a, b) pulled down by up to k / 4 where the two are within k.
float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

// Circular smooth minimum (after Inigo Quilez): the fillet is a circle of radius k rolling
// between the two shapes, tangent to both, so the join is concave and meets each smoothly.
float sminRound(float a, float b, float k) {
    k *= 1.0 / (1.0 - sqrt(0.5));
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - k * 0.5 * (1.0 + h - sqrt(1.0 - h * (h - 2.0)));
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize + origin;
    // The shape reaches far to the left of its cap; the item cuts it off there, where it lies on
    // the pill's own outline.
    float halfW = capRadius * 2.0;
    float dPill = sdRoundBox(p - vec2(pillEdge.x - halfW, pillEdge.y), vec2(halfW, pillHalfH), capRadius);
    // The cap swells by pushing its end out; the pill's straight edges stay where they are.
    float dCap = sdRoundBox(p - vec2(pillEdge.x + bulge - halfW, pillEdge.y), vec2(halfW, pillHalfH), capRadius);
    float dDisc = length(p - disc.xy) - disc.z;
    float d = neck > 0.0 ? sminRound(dCap, dDisc, neck) : min(dCap, dDisc);

    if (stub.y > 0.0) {
        float reach = max(stub.x - stub.y, 0.0);
        float dA = sdSegment(p, vec2(pillEdge.x - 2.0 * stub.y, disc.y), vec2(pillEdge.x + reach, disc.y), stub.y);
        float dB = sdSegment(p, vec2(disc.x - disc.z + 2.0 * stub.y, disc.y), vec2(disc.x - disc.z - reach, disc.y), stub.y);
        d = smin(smin(d, dA, 2.0), dB, 2.0);
    }

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
    // The disc's shadow lies under the shape, off its own footprint and the pill's.
    float shade = 0.0;
    if (shadowStrength > 0.0 && disc.z > 0.0) {
        float s = clamp(discShadow(p - disc.xy - vec2(0.0, shadowOffsetY), disc.z, max(shadowSigma, 0.5)), 0.0, 1.0);
        float pillOff = smoothstep(-0.5 * aa, 0.5 * aa, dPill);
        shade = s * shadowStrength * pillOff * (1.0 - outer);
    }
    c = c + vec4(0.0, 0.0, 0.0, shade) * (1.0 - c.a);
    fragColor = c * qt_Opacity;
}
