#version 440
// The lock clock's digits as bubbles of glass. `glyphs` holds the digits' coverage (their
// alpha), `soft` that coverage blurred over about half a stroke's width, `backdrop` what is
// seen through them (the blurred desktop under the scrim).
//
// The blurred coverage stands in for how far inside the outline a point is, and from it each
// stroke is given the height of an inflated tube: flat-topped along its spine, falling away
// steeply to the outline. Everything is read off that surface. The backdrop is seen through it
// as through a lens (bent toward the spine, more the steeper the surface), softened and
// lightened, with a little of the ink milked over it so the time reads on any wallpaper. A
// light from the upper left leaves a tight glint and a broader sheen on the slope facing it,
// the outline brightens where the surface turns away from the eye, and that turning edge takes
// the shifting colours of a soap film. The outline itself is feathered over a pixel or two, so
// the glass sits in the backdrop instead of looking cut out of it. `solid` turns the whole
// digit to plain ink with a crisp outline, which is what leaves and enters the pill. Output is
// premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // the ShaderEffect item size, item px (maps qt_TexCoord0 to px)
    float bevel;     // the reach the coverage was blurred over, item px
    float rim;       // the bright outline's width, item px
    float feather;   // the radius the outline is softened over, item px
    float relief;    // how steeply the surface falls to the outline
    float bend;      // how far the backdrop is displaced on the steepest slope, item px
    float soften;    // the radius the backdrop is blurred over inside the glass, item px
    float lighten;   // the backdrop's gain inside the glass
    float milk;      // the share of ink laid over the backdrop
    float shine;     // the strength of the light on the surface
    float film;      // the strength of the soap-film colours on the turning edge
    float solid;     // 0 glass, 1 plain ink
    vec2 light;      // where the light comes from on screen (y down); it also leans toward the eye
    vec4 ink;        // the digits' plain colour (premultiplied by Qt)
};

layout(binding = 1) uniform sampler2D glyphs;
layout(binding = 2) uniform sampler2D soft;
layout(binding = 3) uniform sampler2D backdrop;

// 0 on the outline, 1 along a stroke's spine. The blurred coverage is a half on a straight
// outline and, the blur being about half a stroke wide, a little over 0.8 at the spine.
float inside(vec2 uv) {
    return clamp((texture(soft, uv).a - 0.5) / 0.33, 0.0, 1.0);
}

// The surface: a quarter circle up from the outline, level along the spine.
float height(vec2 uv) {
    float out_ = 1.0 - inside(uv);
    return sqrt(max(0.0, 1.0 - out_ * out_));
}

// One read of the coverage. The texture is mipmapped at twice the item's size; read a level
// finer than the screen asks for, so each pixel is the plain 2x2 mean of the level below its
// own size. At rest that is the full texture boxed down to the screen exactly; in flight it
// stays as crisp as box filtering allows, where the level the screen asks for would blend in
// the next coarser one and blur.
float glyph(vec2 uv) {
    return texture(glyphs, uv, -1.0).a;
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

// A soap film's colours as it thins: rose, gold, green and round to rose again. A film runs
// through blue and cyan too, but on the dark glass those read as a stray blue tint (Ryan,
// 2026-11-12), so they are left out.
vec3 filmColour(float phase) {
    vec3 rose = vec3(0.98, 0.14, 0.66);
    vec3 gold = vec3(0.96, 0.64, 0.04);
    vec3 green = vec3(0.16, 0.88, 0.3);
    float p = fract(phase) * 3.0;
    if (p < 1.0)
        return mix(rose, gold, smoothstep(0.0, 1.0, p));
    if (p < 2.0)
        return mix(gold, green, smoothstep(1.0, 2.0, p));
    return mix(green, rose, smoothstep(2.0, 3.0, p));
}

void main() {
    // The outline is feathered only as glass: as ink it hands over to the pill's own clock,
    // whose edge is crisp.
    float a = coverage(qt_TexCoord0, feather * (1.0 - solid));
    if (a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 px = 1.0 / itemSize;
    vec2 reach = px * bevel * 0.22;

    // Uphill, toward the spine.
    vec2 rise = vec2(height(qt_TexCoord0 + vec2(reach.x, 0.0)) - height(qt_TexCoord0 - vec2(reach.x, 0.0)),
                     height(qt_TexCoord0 + vec2(0.0, reach.y)) - height(qt_TexCoord0 - vec2(0.0, reach.y)));
    vec3 normal = normalize(vec3(-rise * relief, 1.0));
    // 0 where the surface faces the eye, 1 where it has turned edge-on.
    float turned = 1.0 - normal.z;

    // How far inside the outline this point is, in px: the blurred coverage over its own
    // slope (negative outside). Measured so, the bright outline is as wide as `rim` says
    // wherever the strokes are thick or thin.
    float s0 = texture(soft, qt_TexCoord0).a;
    vec2 slope = vec2(texture(soft, qt_TexCoord0 + vec2(px.x, 0.0)).a - texture(soft, qt_TexCoord0 - vec2(px.x, 0.0)).a,
                      texture(soft, qt_TexCoord0 + vec2(0.0, px.y)).a - texture(soft, qt_TexCoord0 - vec2(0.0, px.y)).a) * 0.5;
    float depth = (s0 - 0.5) / max(length(slope), 1e-4);

    // Seen through the lens: bent toward the spine by the slope.
    // Softened over a small disc: a dozen taps on a golden-angle spiral (the texture's mip
    // levels are not filtered between, and show as blocks).
    vec2 uv = qt_TexCoord0 - normal.xy * bend * px;
    vec3 seen = texture(backdrop, uv).rgb;
    for (int i = 1; i <= 12; i++) {
        float turn = float(i) * 2.39996;
        float out_ = sqrt(float(i) / 12.0) * soften;
        seen += texture(backdrop, uv + vec2(cos(turn), sin(turn)) * out_ * px).rgb;
    }
    seen *= lighten / 13.0;

    // A little milk, so the time reads on any wallpaper.
    vec3 glass = mix(seen, ink.rgb, milk);

    // A soap film on the turning edge: its colour runs with how far the surface has turned,
    // and drifts across the digits.
    float phase = turned * 1.7 + dot(qt_TexCoord0 * itemSize, vec2(0.0021, 0.0034));
    glass = mix(glass, glass * 0.6 + filmColour(phase) * 0.55, film * smoothstep(0.0, 0.8, turned));

    // The light: a glint and a sheen on the slope that faces it, the far slope a shade darker,
    // and the outline bright where the surface turns away. The bright outline fades inward
    // from the outline over `rim`; the feather takes its outer half, so its brightest pixels
    // sit just inside the edge rather than on it.
    vec3 toLight = normalize(vec3(light, 0.75));
    vec3 halfway = normalize(toLight + vec3(0.0, 0.0, 1.0));
    float facing = max(dot(normal, halfway), 0.0);
    float glint = pow(facing, 70.0);
    float sheen = pow(facing, 9.0) * turned;
    float away = max(dot(normal.xy, -normalize(light)), 0.0);
    float line = 1.0 - smoothstep(0.0, max(rim, 1.0), depth);
    glass *= 1.0 - 0.22 * away * turned;
    glass += ink.rgb * shine * (0.9 * glint + 0.7 * sheen + line * (0.15 + 0.15 * turned) + 0.14 * turned);

    vec3 colour = mix(min(glass, vec3(1.0)), ink.rgb, solid);
    fragColor = vec4(colour, 1.0) * (a * qt_Opacity);
}
