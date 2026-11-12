#version 440
// The lock clock's digits as frosted jelly. `glyphs` holds the digits' coverage, `soft` that
// coverage blurred over about half a stroke's width, `backdrop` what is seen through them (the
// blurred desktop under the scrim).
//
// The blurred coverage rises from the outline to a stroke's spine and falls again beyond it, so
// it is read as the height of each stroke: one round dome across the stroke's whole width,
// steepest at the outline and level only along the spine. Everything is read off that surface.
// The backdrop is seen through it as through a lens, bent a little toward the spine on the
// shoulders and not at all at the outline, so the rim shows what lies right behind it. What the
// rim shows is made a little more vivid and brighter, and a little of the ink is milked over the
// body so the time reads on any desktop; no colour of the glass's own is added, so the edge always
// takes the desktop's colours, and on a grey desktop it is grey. A light from the upper left leaves
// one broad soft highlight on the shoulder that faces it, falling away smoothly in every direction
// (across the spine too), the far slopes fall into a gentle shade, and the light that passes
// through pools in a soft crescent just inside the far edge, tinted by what is seen there. All of
// it is read off the surface's normal, which turns smoothly through the spine, so no line is drawn
// along a stroke and a round dot is one plain droplet. Under the digits a
// contact shadow, the blurred coverage dropped a little, sits them on the desktop. The outline is
// feathered over a pixel or two, so the glass sits in the backdrop instead of looking cut out of
// it. `solid` turns the whole digit to plain ink with a crisp outline and no shadow of its own,
// which is what leaves and enters the pill. Output is premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // the ShaderEffect item size, item px (maps qt_TexCoord0 to px)
    float bevel;     // the reach the coverage was blurred over, item px
    float rim;       // how far in from the outline the rim's colours reach, item px
    float feather;   // the radius the outline is softened over, item px
    float relief;    // how steeply the dome falls to the outline
    float bend;      // how far the backdrop is displaced where the surface turns edge-on, item px
    float soften;    // the radius the backdrop is blurred over inside the glass, item px
    float lighten;   // the backdrop's gain inside the glass
    float milk;      // the share of ink laid over the backdrop on the dome's top
    float vivid;     // how much more saturated the rim shows what it gathers
    float glow;      // how much brighter the rim shows what it gathers
    float shine;     // the strength of the light on the surface
    float shade;     // how much darker the slopes facing away from the light are
    float pool;      // the strength of the light pooled inside the far edge
    float contact;   // the contact shadow's opacity
    float drop;      // how far the contact shadow is dropped, item px
    float solid;     // 0 glass, 1 plain ink
    vec2 light;      // where the light comes from on screen (y down); it also leans toward the eye
    vec4 ink;        // the digits' plain colour (premultiplied by Qt)
    vec4 pick;       // which channels of `glyphs` and `soft` hold the coverage of the layer drawn here
    vec4 window;     // the row it shows through, item px down: none above x, all from y to z, none below w
    float lag;       // how far above its own pixel a contact shadow's caster stands, item px
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

// How much of the row `window` shows at this pixel's height less `above` (item px). A minute
// rolling over slides whole digits through it; only what is drawn is faded, never the coverage the
// glass is read from, so a digit at the row's edge is still whole glass, only fainter.
float windowAt(float above) {
    float y = qt_TexCoord0.y * itemSize.y - above;
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

// The blurred coverage below which the dome has no height: under the outline's own half, so
// even a thin stroke, whose blurred coverage peaks lower, keeps a round top.
const float floor_ = 0.3;

// Light past a white is eased into it rather than cut off at it, so a bright desktop does not
// blow the glass out to a flat white.
vec3 shoulder(vec3 c) {
    const float knee = 0.8;
    vec3 over = max(c - knee, 0.0);
    return min(c, vec3(knee)) + (1.0 - knee) * (1.0 - exp(-over / (1.0 - knee)));
}

// The highlight: centred where the surface has turned this far (0 level, 1 edge-on) toward the
// light, and this wide in the same measure. Off-centre and broad, so it lies on the shoulder and
// still crosses the spine as a gentle fall-off rather than stopping at it.
const float sheenAt = 0.7;
const float sheenWidth = 0.3;
// The light takes on the desktop's hue only this much, and a dark desktop's hue less (the floor
// is added before its brightest channel is divided out), so it is lit glass, never a glow.
const float tintShare = 0.6;
const float tintFloor = 0.15;

void main() {
    vec2 px = 1.0 / itemSize;
    float glass = 1.0 - solid;
    float s = softAt(qt_TexCoord0);

    // The outline is feathered only as glass: as ink it hands over to the pill's own clock,
    // whose edge is crisp.
    float a = coverage(qt_TexCoord0, feather * glass);

    // The contact shadow, under the feathered outline and round it: where the blurred coverage
    // a little above is more than here, which is below a stroke and not beside it.
    float shadow = 0.0;
    if (a < 1.0 && glass > 0.0) {
        float above = softAt(qt_TexCoord0 - vec2(0.0, drop) * px);
        shadow = contact * glass * smoothstep(0.0, 0.3, above - s) * smoothstep(0.0, 0.5, above);
    }
    if (a <= 0.0) {
        fragColor = vec4(0.0, 0.0, 0.0, shadow * windowAt(lag) * qt_Opacity);
        return;
    }

    // The dome: the square root of the blurred coverage above floor_, so the surface falls ever
    // more steeply toward the outline and is round across the top. Its slope comes from the
    // blurred coverage's own, read over a step wide enough to smooth out the coarse levels the
    // blur is built from.
    float step_ = max(1.0, bevel * 0.2);
    vec2 grad = vec2(softAt(qt_TexCoord0 + vec2(step_, 0.0) * px) - softAt(qt_TexCoord0 - vec2(step_, 0.0) * px),
                     softAt(qt_TexCoord0 + vec2(0.0, step_) * px) - softAt(qt_TexCoord0 - vec2(0.0, step_) * px)) / (2.0 * step_);
    vec2 slope = grad / (2.0 * sqrt(max(s - floor_, 0.02))) * relief * bevel;
    vec3 normal = normalize(vec3(-slope, 1.0));
    // 0 where the surface faces the eye, 1 where it has turned edge-on, and which way it faces.
    float tilt = length(normal.xy);
    float t4 = tilt * tilt * tilt * tilt;
    vec2 facing = normal.xy / max(tilt, 1e-4);

    // How far inside the outline this point is, in px: the blurred coverage over its own slope
    // (negative outside). The rim's colours fade in from the outline over `rim` px measured so,
    // as wide on thick strokes as on thin ones, and with no step where they end.
    float depth = (s - 0.5) / max(length(grad), 1e-4);
    float edge = exp(-3.0 * max(depth, 0.0) / max(rim, 1.0));

    // Seen through the lens: bent toward the spine on the shoulders, most where the surface has
    // turned about half way, and back to none at the outline, so the rim shows the colour right
    // behind it (a rim that reached across the stroke mixed two colours meeting behind a dot into
    // a mauve). Softened over a disc: a dozen taps on a golden-angle spiral (the texture's mip
    // levels are not filtered between, and show as blocks).
    vec2 uv = qt_TexCoord0 - facing * bend * 0.2 * tilt * (1.0 - tilt * tilt * tilt) * px;
    vec3 seen = texture(backdrop, uv).rgb;
    for (int i = 1; i <= 12; i++) {
        float turn = float(i) * 2.39996;
        float out_ = sqrt(float(i) / 12.0) * soften;
        seen += texture(backdrop, uv + vec2(cos(turn), sin(turn)) * out_ * px).rgb;
    }
    seen /= 13.0;

    // Toward the rim, what is seen is lifted: more saturated about its own grey (so a grey stays
    // grey) and brighter. The light's colour is that hue at full brightness, only partly.
    const vec3 rec709 = vec3(0.2126, 0.7152, 0.0722);
    float luma = dot(seen, rec709);
    vec3 vivified = clamp(mix(vec3(luma), seen, 1.0 + vivid * edge), 0.0, 1.0);
    vivified *= lighten * (1.0 + glow * edge);
    vec3 hue = (vivified + tintFloor) / (max(max(vivified.r, vivified.g), vivified.b) + tintFloor);
    vec3 tint = mix(vec3(dot(hue, rec709)), hue, tintShare);

    // The milk thins toward the rim, where the jelly is thinnest and the desktop's colours show.
    vec3 body = mix(vivified, ink.rgb, milk * (1.0 - 0.3 * edge));

    // The light, all of it local, so the body keeps the tone of what is seen through it. One
    // broad highlight on the shoulder facing it; the slopes facing away a shade darker, and light
    // pooled in a crescent just inside the far edge. Where the surface turns edge-on it gathers a
    // little more of the desktop's light, tinted as the desktop is; over a bright desktop it
    // darkens there a little instead, as a glass on white paper is ringed in grey, so the digits
    // keep their shape where there is no light left to add. Only the normal itself is used near
    // the spine (`facing` turns over there), so nothing changes abruptly along a stroke.
    vec2 toward = normalize(light);
    vec2 off = normal.xy - toward * sheenAt;
    float sheen = exp(-dot(off, off) / (2.0 * sheenWidth * sheenWidth));
    float away = max(dot(facing, -toward), 0.0);
    float crescent = away * away * smoothstep(0.3, 1.0, tilt) * (0.4 + 0.6 * edge);
    body *= 1.0 - shade * smoothstep(0.0, 1.0, -dot(normal.xy, toward)) - 0.2 * t4 * luma * luma;
    vec3 shone = mix(ink.rgb, tint, 0.3) * (shine * 0.5 * sheen)
               + tint * (pool * crescent * (0.45 + 0.6 * luma) + glow * 0.1 * t4 * (0.2 + luma));
    body = shoulder(max(body, 0.0) + shone);

    vec3 colour = mix(body, ink.rgb, solid);
    float shown = windowAt(0.0);
    fragColor = vec4(colour * a * shown, a * shown + shadow * windowAt(lag) * (1.0 - a * shown)) * qt_Opacity;
}
