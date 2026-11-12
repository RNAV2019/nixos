#version 440
// The lock clock's digits as frosted glass. `glyphs` holds the digits' coverage (their alpha),
// `soft` that coverage blurred over the bevel's depth, `backdrop` what lies behind them (the
// blurred desktop under the scrim), mipmapped.
//
// Inside a digit the backdrop shows through: softened (a higher mip), bent toward the digit's
// middle near its outline as a thick pane would bend it, lightened, and milked over with a
// little of the ink so the time reads on any wallpaper. The outline catches the light: a thin
// bright rim where it faces the light and a fainter one opposite, over a wider soft bevel. An
// ellipse of the accent tints the first digits as coloured glass and fades out across them.
// `solid` turns the whole digit to plain ink, which is what leaves and enters the pill.
// Output is premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // the ShaderEffect item size, item px (maps qt_TexCoord0 to px)
    float bevel;     // how far in from the outline the glass curves, item px
    float rim;       // the bright rim's width, item px
    float bend;      // how far the backdrop is displaced at the outline, item px
    float soften;    // the backdrop's mip level inside the glass
    float lighten;   // the backdrop's gain inside the glass
    float milk;      // the share of ink laid over the backdrop
    float shine;     // the rim's strength
    float solid;     // 0 glass, 1 plain ink
    vec2 light;      // where the light comes from, a unit vector on screen (y down)
    vec2 washCentre; // the accent ellipse's centre, item px
    vec2 washRadii;  // its half-axes, item px
    float washAngle; // its lean, radians clockwise on screen
    float washCore;  // the share of the radius that is solid before the falloff
    float washDepth; // how strongly it colours the glass
    vec4 ink;        // the digits' plain colour (premultiplied by Qt)
    vec4 tint;       // the accent (premultiplied by Qt)
};

layout(binding = 1) uniform sampler2D glyphs;
layout(binding = 2) uniform sampler2D soft;
layout(binding = 3) uniform sampler2D backdrop;

// The digits' coverage blurred over about the bevel's depth: half on a straight outline,
// rising to one deep inside, so it stands in for the distance to the outline and its slope
// for the way the outline faces.
float depth(vec2 uv) {
    return texture(soft, uv).a;
}

void main() {
    float a = texture(glyphs, qt_TexCoord0).a;
    if (a <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 px = 1.0 / itemSize;
    vec2 reach = px * bevel * 0.3;

    // 0 on the outline, 1 once the bevel has levelled off.
    float inside = clamp((depth(qt_TexCoord0) - 0.5) * 2.0, 0.0, 1.0);
    float edge = 1.0 - smoothstep(0.0, 1.0, inside);
    float line = 1.0 - smoothstep(0.0, clamp(rim / bevel, 0.02, 1.0), inside);
    // Points into the digit; the outline's own normal is its opposite.
    vec2 slope = vec2(depth(qt_TexCoord0 + vec2(reach.x, 0.0)) - depth(qt_TexCoord0 - vec2(reach.x, 0.0)),
                      depth(qt_TexCoord0 + vec2(0.0, reach.y)) - depth(qt_TexCoord0 - vec2(0.0, reach.y)));
    vec2 inward = length(slope) > 0.0005 ? normalize(slope) : vec2(0.0);

    // The backdrop, bent toward the middle of the stroke as the pane thickens to its edge.
    vec2 uv = qt_TexCoord0 + inward * bend * edge * edge * px;
    vec3 seen = textureLod(backdrop, uv, soften).rgb * lighten;

    vec2 p = qt_TexCoord0 * itemSize - washCentre;
    float c = cos(washAngle);
    float s = sin(washAngle);
    vec2 q = vec2(c * p.x + s * p.y, -s * p.x + c * p.y) / max(washRadii, vec2(1.0));
    float wash = (1.0 - smoothstep(washCore, 1.0, length(q))) * washDepth;

    // Coloured glass where the accent pools, milk glass everywhere.
    vec3 glass = mix(seen, tint.rgb, wash);
    glass = mix(glass, ink.rgb, milk);

    // The light on the outline: bright where it faces the light, fainter where it faces away
    // (the far wall of the pane, seen through it), and a soft sheen down from the lit side.
    float facing = dot(-inward, light);
    float lit = pow(max(facing, 0.0), 1.5);
    float back = pow(max(-facing, 0.0), 2.0);
    glass += ink.rgb * shine * (line * (0.3 + 0.7 * lit + 0.4 * back) + edge * (0.1 + 0.3 * lit));
    glass *= 1.0 - 0.12 * edge * back;

    vec3 colour = mix(min(glass, vec3(1.0)), ink.rgb, solid);
    fragColor = vec4(colour, 1.0) * (a * qt_Opacity);
}
