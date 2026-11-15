#version 440
// One direction of a blur on the lyric stage: a 13-tap Gaussian along `stride`, on a texture a
// fraction of the stage's size. Two of them make the bloom, whose first pass also keeps only
// what is bright (`floorLuma`), so dim ink does not glow; two more blur the soft plate, by as
// much as `stride` is long.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // One tap to the next, in texture coordinates. Not called `step`: that is a function of
    // the language's own, and a uniform of that name compiles, is never set, and blurs nothing.
    vec2 stride;
    float floorLuma;  // luma below this is dropped; 0 keeps everything
};

layout(binding = 1) uniform sampler2D source;

vec3 bright(vec2 uv) {
    vec3 c = texture(source, uv).rgb;
    if (floorLuma <= 0.0)
        return c;
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    return c * smoothstep(floorLuma, floorLuma + 0.35, l);
}

void main() {
    // Seven weights of a sigma-3 Gaussian, mirrored.
    const float w[7] = float[7](0.1370, 0.1289, 0.1072, 0.0789, 0.0514, 0.0297, 0.0152);
    vec3 sum = bright(qt_TexCoord0) * w[0];
    float total = w[0];
    for (int i = 1; i < 7; i++) {
        vec2 o = stride * float(i);
        sum += (bright(qt_TexCoord0 + o) + bright(qt_TexCoord0 - o)) * w[i];
        total += 2.0 * w[i];
    }
    fragColor = vec4(sum / total, 1.0) * qt_Opacity;
}
