#version 440
// The lyric stage's lens: everything the styles draw passes through here once. Each effect is
// one number, 0 for off, set per style and kicked by the words as they land
// (Lyrics/LyricScene.qml):
//   bloom       the bright parts' glow, added back
//   aberration  red and blue pulled apart from the middle outwards, a lens's fringe
//   punch       a radial smear towards the middle, the moment a hit lands
//   glitch      rows torn sideways for a frame or two
//   warp        a slow swim, as through heat or water
//   scan        fine horizontal lines, a tube's
//   grain       film grain
//   vignette    the corners fall off
//   flash       a lift of the whole frame
// and the four that make a style an old print run through a projector:
//   mono        colour drained to black and white
//   dust        specks and hairline scratches that come and go with the frames
//   flicker     the lamp's unsteadiness and the gate's weave, both small
//   spot        the lamp itself: a soft disc of light at `spotAt`, `spotSize` across
// `shake` moves the picture bodily. Output is opaque.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 pixels;      // the stage in device pixels
    vec2 shake;       // in texture coordinates
    float time;       // seconds, free-running
    float bloom;
    float aberration;
    float punch;
    float glitch;
    float warp;
    float scan;
    float grain;
    float vignette;
    float flash;
    float mono;
    float dust;
    float flicker;
    float spot;
    float spotSize;   // the disc's radius, in stage heights
    vec2 spotAt;      // its middle, in texture coordinates
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D glowSource;

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// The picture at `uv`, with its colours fringed along `dir`.
vec3 fringed(vec2 uv, vec2 dir) {
    if (aberration <= 0.0005)
        return texture(source, uv).rgb;
    vec2 o = dir * aberration;
    return vec3(texture(source, uv + o).r, texture(source, uv).g, texture(source, uv - o).b);
}

// Dust on the print: a few bright specks, in new places every twelfth of a second.
float specks(vec2 uv, float frame) {
    vec2 g = uv * vec2(pixels.x / pixels.y, 1.0) * 7.0;
    vec2 cell = floor(g);
    if (hash(cell + frame * 17.0) < 0.9)
        return 0.0;
    vec2 at = vec2(hash(cell + 3.1 + frame), hash(cell + 7.7 + frame)) - 0.5;
    float r = 0.008 + 0.022 * hash(cell + 1.3 + frame);
    return smoothstep(r, r * 0.35, length(fract(g) - 0.5 - at * 0.8));
}

void main() {
    vec2 uv = qt_TexCoord0 + shake;
    float frame = floor(time * 12.0);

    if (flicker > 0.0005)
        uv += flicker * 0.0014 * (vec2(hash(vec2(frame, 2.0)), hash(vec2(frame, 5.0))) - 0.5);

    if (warp > 0.0005)
        uv += warp * 0.006 * vec2(sin(uv.y * 17.0 + time * 1.9), cos(uv.x * 13.0 + time * 1.4));

    if (glitch > 0.0005) {
        float tear = floor(time * 24.0);
        float row = floor(uv.y * 28.0 + hash(vec2(tear, 3.0)) * 28.0);
        float torn = step(1.0 - glitch * 0.55, hash(vec2(row, tear)));
        uv.x += torn * (hash(vec2(tear, row)) - 0.5) * 0.16 * glitch;
    }

    vec2 centred = uv - 0.5;
    vec3 col;
    if (punch > 0.0005) {
        // Six samples drawn in towards the middle: a zoom caught mid-flight.
        col = vec3(0.0);
        for (int i = 0; i < 6; i++) {
            float s = 1.0 - punch * 0.075 * float(i) / 5.0;
            col += fringed(0.5 + centred * s, centred);
        }
        col /= 6.0;
    } else {
        col = fringed(uv, centred);
    }

    col += texture(glowSource, uv).rgb * bloom;

    if (scan > 0.0005)
        col *= 1.0 - scan * 0.5 * (0.5 + 0.5 * sin(uv.y * pixels.y * 3.14159 / 1.5));

    if (spot > 0.0005) {
        vec2 d = (uv - spotAt) * vec2(pixels.x / pixels.y, 1.0) / spotSize;
        col += spot * exp(-dot(d, d)) * (0.94 + 0.06 * hash(vec2(frame, 11.0)));
    }

    col += flash;
    if (mono > 0.0005)
        col = mix(col, vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), mono);
    if (flicker > 0.0005)
        col *= 1.0 + flicker * 0.09 * (hash(vec2(floor(time * 24.0), 1.0)) - 0.5);
    float corner = smoothstep(0.35, 0.95, length(centred * vec2(1.0, 1.15)));
    col *= 1.0 - vignette * corner;
    if (dust > 0.0005) {
        float scratchAt = hash(vec2(floor(time * 3.0), 9.0));
        float scratch = smoothstep(0.0011, 0.0, abs(uv.x - scratchAt)) * step(0.55, hash(vec2(floor(time * 3.0), 4.0)));
        col += dust * (0.4 * specks(uv, frame) + 0.1 * scratch * (0.5 + 0.5 * hash(vec2(frame, uv.y * 40.0))));
    }

    // Grain rides the light: black stays black, as film's does.
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col += (hash(qt_TexCoord0 * pixels + fract(time) * 71.0) - 0.5) * grain * (0.25 + 1.5 * luma);

    // Half a step of dither, always: the dark gradients are where eight bits show.
    col += (hash(qt_TexCoord0 * pixels * 1.37 + fract(time) * 13.0) - 0.5) / 255.0;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
