#version 440
// What casts the lock clock's broad shadow while a minute rolls over: the digits' coverage, only
// as much of it as the row's window shows (the same window the glass is faded by, see
// lockglass.frag), so a digit sliding out of the row takes its shadow with it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // the item size, item px
    vec4 window;     // the row, item px down: none above x, all from y to z, none below w
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float y = qt_TexCoord0.y * itemSize.y;
    float shown = smoothstep(window.x, window.y, y) * (1.0 - smoothstep(window.z, window.w, y));
    fragColor = texture(source, qt_TexCoord0) * shown * qt_Opacity;
}
