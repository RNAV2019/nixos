#version 440
// The lyric stage's lens: everything the styles draw passes through here once. Each effect is
// one number, 0 for off, set per style (Lyrics/LyricScene.qml):
//   bloom     the bright parts' glow, added back
//   punch     a radial smear towards the middle, the moment a hit lands or a style cuts in
//   depth     depth of field for a column of lines: sharp in a band round `depthAt` (a height,
//             0..1), softer the further above or below it, `depthBand` being half the band
//   grain     film grain
//   vignette  the corners fall off
//   flash     a lift of the whole frame, at a cut
// and the four that make a style an old print run through a projector:
//   mono      colour drained to black and white
//   dust      specks and hairline scratches that come and go with the frames
//   flicker   the lamp's unsteadiness and the gate's weave, both small
//   spot      the lamp itself: a soft disc of light at `spotAt`, `spotSize` across
//   veil      black lifted to grey, as a print's never quite is
//   softness  the whole picture a little out of true, as a projector's lens leaves it (given
//             as which smaller copy of the picture to read: 1 is the half-size one)
// `softSource` is the soft plate: whatever a style has put out of focus, already blurred
// (Lyrics/LyricScene.qml), and added to the picture as light while `softOn` is 1.
// Output is opaque.
//
// What it costs is counted in reads of the picture: one a pixel at rest, six while a punch is
// on, and out of focus two where the picture is flat and eleven where it is not. The picture is kept with its smaller copies (mipmaps), and
// the out-of-focus read takes from those, so a wide blur costs no more than a narrow one.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 pixels;      // the stage in device pixels
    float time;       // seconds, free-running
    float bloom;
    float punch;
    float depth;
    float depthAt;
    float depthBand;
    float grain;
    float vignette;
    float flash;
    float mono;
    float dust;
    float flicker;
    float spot;
    float spotSize;   // the disc's radius, in stage heights
    vec2 spotAt;      // its middle, in texture coordinates
    float veil;
    float softness;
    float softOn;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D glowSource;
layout(binding = 3) uniform sampler2D softSource;

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// The picture at `uv` as the lens sees it at that height: sharp inside the band, and outside
// it a disc of eight reads and the middle one, taken from the copy of the picture whose texels
// are about the disc's size.
vec3 seen(vec2 uv) {
    if (depth <= 0.0005)
        return softness > 0.01 ? textureLod(source, uv, softness).rgb : texture(source, uv).rgb;
    float off = max(0.0, abs(uv.y - depthAt) - depthBand);
    // Soft by a fifth of the stage's height from the band, and no softer beyond.
    float radius = depth * min(1.0, off / 0.2) * 0.011 * pixels.y;
    if (radius < 0.75)
        return texture(source, uv).rgb;
    float lod = max(0.0, log2(radius) - 1.0);
    // Most of what is out of focus is black, or the ground's slow light: where the picture is
    // the same up close as from far off there is nothing a blur would change, and two reads
    // have found that out.
    vec3 here = texture(source, uv).rgb;
    vec3 wide = abs(here - textureLod(source, uv, lod + 1.5).rgb);
    if (max(wide.r, max(wide.g, wide.b)) < 0.012)
        return here;
    vec2 reach = radius / pixels;
    vec3 sum = textureLod(source, uv, lod).rgb;
    for (int i = 0; i < 8; i++) {
        float a = 0.785398 * float(i) + 0.39;
        sum += textureLod(source, uv + vec2(cos(a), sin(a)) * reach, lod).rgb;
    }
    return sum / 9.0;
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
    vec2 uv = qt_TexCoord0;
    float frame = floor(time * 12.0);

    if (flicker > 0.0005)
        uv += flicker * 0.0014 * (vec2(hash(vec2(frame, 2.0)), hash(vec2(frame, 5.0))) - 0.5);

    vec2 centred = uv - 0.5;
    vec3 col;
    if (punch > 0.004) {
        // Six reads drawn in towards the middle: a zoom caught mid-flight.
        col = vec3(0.0);
        for (int i = 0; i < 6; i++)
            col += texture(source, 0.5 + centred * (1.0 - punch * 0.075 * float(i) / 5.0)).rgb;
        col /= 6.0;
    } else {
        col = seen(uv);
    }

    if (softOn > 0.5)
        col += texture(softSource, uv).rgb;

    col += texture(glowSource, uv).rgb * bloom;

    if (spot > 0.0005) {
        vec2 d = (uv - spotAt) * vec2(pixels.x / pixels.y, 1.0) / spotSize;
        // A disc more than a glow: level across its middle, falling away at its edge, as a
        // lamp thrown out of focus on a wall is.
        col += spot * exp(-pow(dot(d, d), 1.7)) * (0.94 + 0.06 * hash(vec2(frame, 11.0)));
    }

    col += flash;
    if (mono > 0.0005)
        col = mix(col, vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), mono);
    if (veil > 0.0005)
        col += veil * (1.0 - col);
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
