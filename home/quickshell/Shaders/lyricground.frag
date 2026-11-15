#version 440
// The lyric stage's ground: black, with the playing cover's colours drifting through it as slow
// light. Drawn small and stretched (Lyrics/LyricScene.qml), so it costs next to nothing. The
// light is three soft lobes that wander on a warped field and never fill the frame: on an OLED
// panel most of this is unlit pixels.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;      // seconds, free-running
    float aspect;    // width over height
    float glow;      // how bright the light is, 0..1
    float stir;      // a kick: the field jumps ahead by this much
    vec4 tintA;
    vec4 tintB;
    vec4 tintC;
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.0, 9.0);
        a *= 0.5;
    }
    return v;
}

float lobe(vec2 p, vec2 at, float r) {
    float d = length(p - at) / r;
    return exp(-d * d);
}

void main() {
    vec2 p = vec2((qt_TexCoord0.x - 0.5) * aspect, qt_TexCoord0.y - 0.5);
    float t = time * 0.045 + stir * 0.35;
    // The field the lobes ride on.
    vec2 w = vec2(fbm(p * 1.3 + vec2(t, -t * 0.7)), fbm(p * 1.3 + vec2(-t * 0.8, t) + 5.2)) - 0.5;
    vec2 q = p + w * 0.55;
    vec2 a = vec2(cos(t * 1.9) * 0.62, sin(t * 1.3) * 0.34) * vec2(aspect * 0.55, 1.0);
    vec2 b = vec2(cos(t * 1.1 + 2.4) * 0.7, sin(t * 1.7 + 1.1) * 0.4) * vec2(aspect * 0.55, 1.0);
    vec2 c = vec2(cos(t * 0.7 + 4.2) * 0.5, sin(t * 2.1 + 3.0) * 0.36) * vec2(aspect * 0.55, 1.0);
    vec3 col = tintA.rgb * lobe(q, a, 0.36) + tintB.rgb * lobe(q, b, 0.32) + tintC.rgb * lobe(q, c, 0.27);
    // Streaks of the field itself, so the light has grain to it rather than three clean blobs.
    col *= 0.35 + 1.1 * fbm(q * 2.4 - t);
    // Deepened, so the light falls away to black well before the next lobe begins.
    col = pow(col * glow, vec3(1.5)) * 1.6;
    // Where lobes meet they add up; the ground is kept a ground, never a lamp.
    col = 0.5 * (1.0 - exp(-col * 2.2));
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
