#version 440
// How the lyric stage comes and goes (Lyrics/LyricStage.qml), after the way a folding phone
// hands one screen over to the other, without the tilt: the picture stays where it is, goes out
// of focus from the top down, and its light goes with it, the top first. `fold` is how far it
// has gone, 0 sharp and whole, 1 gone. Run backwards it is a picture arriving.
//
// The blur is read off the picture's smaller copies (mipmaps), so the source must have them.
// Output is premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 pixels;   // the picture in device pixels
    float fold;    // 0..1
};

layout(binding = 1) uniform sampler2D source;

// The picture at `uv`, out of focus by `radius` pixels: a disc of eight reads and the middle
// one, from the copy whose texels are about the disc's size.
vec3 soft(vec2 uv, float radius) {
    if (radius < 0.75)
        return texture(source, uv).rgb;
    float lod = max(0.0, log2(radius) - 1.0);
    vec2 reach = radius / pixels;
    vec3 sum = textureLod(source, uv, lod).rgb;
    for (int i = 0; i < 8; i++) {
        float a = 0.785398 * float(i) + 0.39;
        sum += textureLod(source, uv + vec2(cos(a), sin(a)) * reach, lod).rgb;
    }
    return sum / 9.0;
}

void main() {
    vec2 uv = qt_TexCoord0;
    if (fold <= 0.0005) {
        fragColor = vec4(texture(source, uv).rgb, 1.0) * qt_Opacity;
        return;
    }

    // How high up the picture this is: 0 at its foot, 1 at its top.
    float row = 1.0 - uv.y;

    // Out of focus from the top down: the foot stays readable longest, and the whole of it is
    // soft by the end.
    float radius = 0.045 * pixels.x * (0.25 + 0.75 * row) * sin(1.5708 * fold);
    vec3 col = soft(uv, radius);

    // The light goes the same way.
    col *= clamp(1.0 - fold * (0.25 + 0.75 * row), 0.0, 1.0);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
