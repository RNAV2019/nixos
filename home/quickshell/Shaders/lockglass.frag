#version 440
// The lock clock's digits as liquid glass, after Apple's Lock Screen clock. `glyphs` holds the
// digits' coverage, `soft` that coverage blurred, `backdrop` what is seen through them (the
// blurred desktop under the scrim).
//
// Each stroke is a flat slab of clear glass: its face is level, and only in a narrow band at the
// outline (`band` px) does the surface roll off to the edge. How far in from the outline a pixel
// is, the blurred coverage says: read back through the normal distribution it is a distance in
// px, so the band is as wide on a thick stroke as on a thin one or round a counter.
//
// Through the face the desktop is seen softly blurred and a little magnified (the whole clock is
// one weak lens), under a veil set by how bright the desktop round it is: a smoky lift over a
// dark desktop, a pale one over a bright one, so the body is always a little lighter than what
// lies behind and the time reads without hiding it. In the band the glass bends the light hard:
// it shows a wide slice of the desktop just outside the outline, squeezed into a few px and drawn
// out along the edge, so a bright colour near a digit streaks along its rim.
//
// The light comes from two opposite corners. A thin bright line runs just inside the outline,
// counters included, brightest where the edge faces the upper left or the lower right and faint,
// never gone, on the other diagonals; it is white leaning toward the colour the band shows. Just
// inside it a soft darker band gives the slab its thickness, and on the edges facing the light a
// little light is caught in the band, fading in from the line. Nothing has a colour of the
// glass's own: over a grey desktop the glass is grey.
//
// The outline is feathered over a pixel or two, so the glass sits in the backdrop instead of
// looking cut out of it. `solid` turns the whole digit to plain ink with a crisp outline, which
// is what leaves and enters the pill. Output is premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // the ShaderEffect item size, item px (maps qt_TexCoord0 to px)
    float bevel;     // the reach the coverage was blurred over, item px
    float band;      // how far in from the outline the surface rolls off, item px
    float feather;   // the radius the outline is softened over, item px
    float bend;      // how far outside the outline the edge band reaches for what it shows, item px
    float smear;     // how much more the edge band blurs along the edge than across it
    float lens;      // how much the face magnifies what is behind it (a share)
    float soften;    // the radius the backdrop is blurred over inside the glass, item px
    float reach;     // the radius the desktop's brightness round a pixel is taken over, item px
    float veil;      // the share of what is seen that the veil replaces
    vec3 tone;       // the body's tone over a black, a mid-grey and a white desktop
    float rim;       // the strength of the bright line inside the outline
    float rimFloor;  // its strength where the edge faces across the light, as a share
    float rimTint;   // how much of the colour the band shows the line takes
    float shade;     // how much darker the band just inside the line is
    float catchLight; // the light caught in the band on edges facing the light
    float solid;     // 0 glass, 1 plain ink
    vec2 light;      // where the light comes from on screen (y down); its opposite lights too
    vec4 ink;        // the digits' plain colour (premultiplied by Qt)
    vec4 pick;       // which channels of `glyphs` and `soft` hold the coverage of the layer drawn here
    vec4 window;     // the row it shows through, item px down: none above x, all from y to z, none below w
};

layout(binding = 1) uniform sampler2D glyphs;
layout(binding = 2) uniform sampler2D soft;
layout(binding = 3) uniform sampler2D backdrop;

// One read of the coverage. The texture is mipmapped at twice the item's size; read a level
// finer than the screen asks for, so each pixel is the plain 2x2 mean of the level below its
// own size. At rest that is the full texture boxed down to the screen exactly; in flight it
// stays as crisp as box filtering allows, where the level the screen asks for would blend in
// the next coarser one and blur.
float glyph(vec2 uv) {
    return dot(texture(glyphs, uv, -1.0), pick);
}

// One read of the blurred coverage: a half on a straight outline, rising toward a stroke's spine.
float softAt(vec2 uv) {
    return dot(texture(soft, uv), pick);
}

// How much of the row `window` shows at this pixel's height. A minute rolling over slides whole
// digits through it; only what is drawn is faded, never the coverage the glass is read from, so a
// digit at the row's edge is still whole glass, only fainter.
float windowAt() {
    float y = qt_TexCoord0.y * itemSize.y;
    return smoothstep(window.x, window.y, y) * (1.0 - smoothstep(window.z, window.w, y));
}

// The digits' coverage averaged over a disc of radius r (item px): the centre and a dozen taps
// on a golden-angle spiral. Over a straight outline that is a smooth ramp 2r wide, and well
// inside or outside the strokes it changes nothing.
float coverage(vec2 uv, float r) {
    float a = glyph(uv);
    if (r <= 0.0)
        return a;
    for (int i = 1; i <= 12; i++) {
        float turn = float(i) * 2.39996;
        a += glyph(uv + vec2(cos(turn), sin(turn)) * sqrt(float(i) / 12.0) * r / itemSize);
    }
    return a / 13.0;
}

// Light past a white is eased into it rather than cut off at it, so a bright desktop does not
// blow the glass out to a flat white.
vec3 shoulder(vec3 c) {
    const float knee = 0.8;
    vec3 over = max(c - knee, 0.0);
    return min(c, vec3(knee)) + (1.0 - knee) * (1.0 - exp(-over / (1.0 - knee)));
}

const vec3 rec709 = vec3(0.2126, 0.7152, 0.0722);


// The normal distribution's quantile: the distance, in sigmas, at which its cumulative share is
// p (Abramowitz and Stegun 26.2.23, good to 5e-4 of a sigma).
float probit(float p) {
    float q = clamp(min(p, 1.0 - p), 1e-6, 0.5);
    float u = sqrt(-2.0 * log(q));
    float t = u - (2.515517 + u * (0.802853 + u * 0.010328)) / (1.0 + u * (1.432788 + u * (0.189269 + u * 0.001308)));
    return p < 0.5 ? -t : t;
}

void main() {
    vec2 px = 1.0 / itemSize;
    float glass = 1.0 - solid;
    float s = softAt(qt_TexCoord0);

    // The outline is feathered only as glass: as ink it hands over to the pill's own clock,
    // whose edge is crisp.
    float a = coverage(qt_TexCoord0, feather * glass);

    if (a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // How far inside the outline this point is, in px (negative outside). Across a straight
    // outline the blurred coverage climbs like a normal distribution's cumulative share, so read
    // backwards through the quantile it is a distance; the blur is a little wider in its tails
    // than one Gaussian, which the cubic term takes up (fitted off MultiEffect's blur at the
    // clock's size: within half a px over the edge band). It keeps growing toward a stroke's
    // spine. The slope of the coverage (read a step ahead in x and in y, wide enough to smooth
    // out the coarse levels the blur is built from) gives only the way the outline faces. `x`
    // runs from 0 at the outline to 1 where the face begins, `e` the other way.
    float t = probit(s);
    float depth = bevel * t * (0.2 + 0.041 * t * t);
    float step_ = max(1.0, bevel * 0.2);
    vec2 grad = vec2(softAt(qt_TexCoord0 + vec2(step_, 0.0) * px), softAt(qt_TexCoord0 + vec2(0.0, step_) * px)) - s;
    float slope = length(grad);
    float x = clamp(depth / max(band, 1.0), 0.0, 1.0);
    float e = 1.0 - x;
    float e2 = e * e;
    // Which way the outline faces (out of the glass), and how squarely toward the light or away.
    vec2 out_ = slope > 1e-6 ? -grad / slope : vec2(0.0);
    float facing = dot(out_, normalize(light));

    // What is seen: the face magnifies a little about the plate's middle; the band reaches out
    // past the outline, as far as `bend` at the outline itself and less going in, so it shows a
    // wide slice of what lies round the digit squeezed into its few px (the mapping only runs one
    // way, so nothing folds). Softened over a disc (the texture's mip levels are not filtered
    // between, and show as blocks), drawn out along the edge in the band.
    vec2 uv = 0.5 + (qt_TexCoord0 - 0.5) * (1.0 - lens) + out_ * bend * e2 * px;
    vec2 along = vec2(-out_.y, out_.x);
    float stretch = 1.0 + smear * e2;
    vec3 seen = texture(backdrop, uv).rgb;
    for (int i = 1; i <= 7; i++) {
        float turn = float(i) * 2.39996;
        vec2 d = vec2(cos(turn), sin(turn)) * sqrt(float(i) / 7.0) * soften;
        vec2 o = out_ == vec2(0.0) ? d : along * dot(d, along) * stretch + out_ * dot(d, out_);
        seen += texture(backdrop, uv + o * px).rgb;
    }
    seen /= 8.0;

    // The veil, set by how bright the desktop is round this pixel (eight reads on two rings, far
    // apart on the blurred desktop, so a bright shape near a digit moves it only a little). The
    // body's tone over a uniform desktop of that brightness is `tone` for black, mid-grey and
    // white, and in between it eases from one to the next, so a dark desktop with a little colour
    // in it is lifted hardly more than a black one. Neutral: it lifts or dims, it never tints.
    float area = 0.0;
    for (int i = 0; i < 8; i++) {
        float turn = float(i) * 0.7854;
        float far = (i % 2 == 0 ? 1.0 : 0.5) * reach;
        area += dot(texture(backdrop, qt_TexCoord0 + vec2(cos(turn), sin(turn)) * far * px).rgb, rec709);
    }
    area = clamp(area / 8.0, 0.0, 1.0);
    vec3 at = tone - vec3(0.0, 0.5, 1.0) * (1.0 - veil);
    float lift = area < 0.5 ? mix(at.x, at.y, smoothstep(0.0, 0.5, area)) : mix(at.y, at.z, smoothstep(0.5, 1.0, area));
    vec3 body = seen * (1.0 - veil) + lift;

    // The line's colour: white, leaning toward the hue the band shows (that hue at full
    // brightness; a dark one counts for less, the floor being added before its brightest channel
    // is divided out, so black gives white).
    const float hueFloor = 0.15;
    vec3 hue = (seen + hueFloor) / (max(max(seen.r, seen.g), seen.b) + hueFloor);
    vec3 lineColour = mix(vec3(1.0), hue, rimTint);

    // The slab's edge: a soft darker band just inside the line, deeper on the far side; light
    // caught in the band where the edge faces the light, fading in from it; and the line itself,
    // right inside the feathered outline, strongest facing either lit corner.
    float inner = max(depth - feather, 0.0);
    float off = (inner - 0.45 * band) / (0.4 * band);
    float shadeBand = exp(-off * off);
    body *= 1.0 - shade * shadeBand * (0.4 + 0.6 * max(-facing, 0.0));
    body += lineColour * catchLight * max(facing, 0.0) * exp(-inner / (0.4 * band));
    float lit = rimFloor + (1.0 - rimFloor) * facing * facing;
    float across = inner / max(0.08 * band, 0.75);
    float line = exp(-across * across);
    body = mix(body, lineColour, clamp(rim * lit * line, 0.0, 1.0));
    body = shoulder(max(body, 0.0));

    vec3 colour = mix(body, ink.rgb, solid);
    float shown = windowAt();
    fragColor = vec4(colour, 1.0) * a * shown * qt_Opacity;
}
