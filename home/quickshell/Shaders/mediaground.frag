#version 440
// The ground of the control centre's media card, made of the playing track's cover so the card
// carries on from the picture instead of fading into a grey (Control/MediaCard.qml, Ui/MediaGround.qml).
//
// `art` is the cover, small (its own downscale is most of the blur) and already cropped by
// Ui/MediaGround.qml the way this mode lays it out, picked by `mode`:
//   0, the edge: cropped as Ui/CoverBleed.qml crops it into the bleed, and past the bleed its
//      right edge carried on across the card, so each height keeps the colour the art has there.
//   1, the whole: cropped to cover the whole card.
// Either is blurred by `blur` px, dimmed by `dim` (a paused track), then let down where the words
// are: from `capFrom` to `capTo` px across, the colour is darkened (scaled in linear light, hue
// and saturation kept) only as far as it takes for each ink on the card, laid at its alpha over
// this very colour as the scene graph blends it, to keep its WCAG contrast ratio. A dark cover
// keeps its colour untouched. Checked per pixel and per colour, not by luminance alone: an ink at
// part alpha over a saturated red is a pink, darker than the same ink over a grey of the red's
// luminance. Output is premultiplied alpha, opaque.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // the card, px
    vec2 bleedSize;  // the cover's bleed at the card's left, px
    float mode;      // 0 the edge carried on, 1 the whole cover
    float edgeInset; // how far inside the cover's right edge the edge is read, of its width
    float blur;      // blur radius, px
    float dim;       // black laid over it, 0..1
    vec4 ink0;       // an ink on the card: sRGB in rgb, the alpha it is laid at in a
    vec4 ink1;
    vec4 ink2;
    vec4 ink3;
    vec4 ratios;     // the contrast each of ink0..3 must keep; 0 skips it
    float capFrom;   // where the letting down starts, px across
    float capTo;     // where it is whole, px across
};

layout(binding = 1) uniform sampler2D art;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 toLinear(vec3 c) {
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 toSrgb(vec3 c) {
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

float contrast(float a, float b) {
    return (max(a, b) + 0.05) / (min(a, b) + 0.05);
}

// Whether an ink keeps its ratio over a ground (sRGB): blended in sRGB, as it is drawn.
bool holds(vec4 ink, float ratio, vec3 ground) {
    if (ratio <= 0.0)
        return true;
    vec3 seen = mix(ground, ink.rgb, ink.a);
    return contrast(dot(toLinear(seen), LUMA), dot(toLinear(ground), LUMA)) >= ratio;
}

bool allHold(vec3 lin) {
    vec3 g = toSrgb(lin);
    return holds(ink0, ratios.x, g) && holds(ink1, ratios.y, g) && holds(ink2, ratios.z, g) && holds(ink3, ratios.w, g);
}

// Where in the cover a point of the card reads, before the blur.
vec2 coverUv(vec2 p) {
    if (mode < 0.5)
        return vec2(min(p.x, bleedSize.x * (1.0 - edgeInset)), p.y) / bleedSize;
    return p / itemSize;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;

    // A disc of taps on a golden-angle spiral, Gaussian-weighted. Each tap reads a cover already
    // brought down to a few dozen texels, so the disc only has to smooth between them.
    const int TAPS = 40;
    vec3 sum = vec3(0.0);
    float weight = 0.0;
    for (int i = 0; i < TAPS; i++) {
        float r = sqrt((float(i) + 0.5) / float(TAPS));
        float a = float(i) * 2.39996323;
        vec2 o = vec2(cos(a), sin(a)) * r * blur;
        float w = exp(-2.0 * r * r);
        vec2 uv = clamp(coverUv(p + o), vec2(0.0), vec2(1.0));
        sum += toLinear(texture(art, uv).rgb) * w;
        weight += w;
    }
    vec3 lin = sum / weight;
    // CoverBleed lays its dim over the picture in sRGB; the same, read in linear.
    lin *= pow(1.0 - dim, 2.2);

    // The brightest scale of this colour every ink holds on, found by halving.
    if (!allHold(lin)) {
        float lo = 0.0, hi = 1.0;
        for (int i = 0; i < 12; i++) {
            float mid = 0.5 * (lo + hi);
            if (allHold(lin * mid))
                lo = mid;
            else
                hi = mid;
        }
        lin = mix(lin, lin * lo, smoothstep(capFrom, capTo, p.x));
    }

    fragColor = vec4(toSrgb(lin), 1.0) * qt_Opacity;
}
