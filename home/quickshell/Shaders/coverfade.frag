#version 440
// Ui/CoverBleed.qml's fade when it stands on a ground of its own picture (Ui/MediaGround.qml):
// rather than the surface's colour laid over its far end, the picture itself goes, on the same
// curve, so what is under it shows through. Stops at 0, 0.42, 0.74 and 1 of the width, as the
// gradient's: clear, 8% gone, 72% gone, gone.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

layout(binding = 1) uniform sampler2D source;

float gone(float x) {
    if (x < 0.42)
        return mix(0.0, 0.08, x / 0.42);
    if (x < 0.74)
        return mix(0.08, 0.72, (x - 0.42) / 0.32);
    return mix(0.72, 1.0, clamp((x - 0.74) / 0.26, 0.0, 1.0));
}

void main() {
    fragColor = texture(source, qt_TexCoord0) * (1.0 - gone(qt_TexCoord0.x)) * qt_Opacity;
}
