#version 440
// The lock clock's digits: a text drawn into a texture, redrawn in one ink from its coverage
// alone (glyphs this big are rasterised with the panel's subpixel order, which would fringe
// every edge in colour), under an accent wash: a soft ellipse of a second colour that tints
// the first digits and fades out across them. Output is premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize; // the ShaderEffect item size, item px (maps qt_TexCoord0 to px)
    vec2 centre;   // the ellipse's centre, item px
    vec2 radii;    // its half-axes, item px
    float angle;   // its lean, radians clockwise on screen
    float core;    // the share of the radius that is solid before the falloff
    vec4 ink;      // the digits' colour (premultiplied by Qt)
    vec4 tint;     // the wash colour (premultiplied by Qt)
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * itemSize - centre;
    float c = cos(angle);
    float s = sin(angle);
    vec2 q = vec2(c * p.x + s * p.y, -s * p.x + c * p.y) / max(radii, vec2(1.0));
    float wash = 1.0 - smoothstep(core, 1.0, length(q));
    vec4 glyph = texture(source, qt_TexCoord0);
    // The mean of the three coverages: the same edge, without its colour.
    float cover = max(glyph.a, (glyph.r + glyph.g + glyph.b) / 3.0);
    fragColor = mix(ink, tint, wash) * (cover * qt_Opacity);
}
