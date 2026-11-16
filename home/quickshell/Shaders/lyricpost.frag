#version 440
// The lyric stage's lens: everything the styles draw passes through here once. It does two
// things (Lyrics/LyricScene.qml):
//   depth     depth of field: sharp in a band round `depthAt` (a height, 0..1), softer the
//             further above or below it, `depthBand` being half the band. Drift softens the
//             lines round the one in hand with it, and Punch puts a word out of focus as it
//             lands and as it leaves.
//   dither    half a step of noise, always: the ground's dark gradients are where eight bits
//             a channel show as bands.
// Output is opaque.
//
// What it costs is counted in reads of the picture: one a pixel in focus, and out of focus two
// where the picture is flat and eleven where it is not. The picture is kept with its smaller
// copies (mipmaps), and the out-of-focus read takes from those, so a wide blur costs no more
// than a narrow one.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 pixels;      // the stage in device pixels
    float time;       // seconds, free-running
    float depth;
    float depthAt;
    float depthBand;
};

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// The picture at `uv` as the lens sees it at that height: sharp inside the band, and outside
// it a disc of eight reads and the middle one, taken from the copy of the picture whose texels
// are about the disc's size.
vec3 seen(vec2 uv) {
    float radius = 0.0;
    if (depth > 0.0005) {
        float off = max(0.0, abs(uv.y - depthAt) - depthBand);
        // Soft by a fifth of the stage's height from the band, and no softer beyond.
        radius = depth * min(1.0, off / 0.2) * 0.011 * pixels.y;
    }
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

void main() {
    vec3 col = seen(qt_TexCoord0);
    col += (hash(qt_TexCoord0 * pixels * 1.37 + fract(time) * 13.0) - 0.5) / 255.0;
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
