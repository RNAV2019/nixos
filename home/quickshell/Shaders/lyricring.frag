#version 440
// A circle drawn round a word by hand (Lyrics/Styles/Ring.qml): an ellipse begun at `start` and
// taken `sweep` round, a little past where it began, widening as it goes so its end clears its
// beginning. `drawn` is how much of the stroke the pen has laid down, 0..1. Drawn here, where a
// change of `drawn` costs a uniform, not on the CPU, where each frame of the pen's travel would
// be a new outline to build. Output is premultiplied alpha.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // px
    vec2 radii;      // the ellipse's half-axes where the pen starts, px
    float stroke;    // the pen's width, px
    float drawn;     // 0..1
    float start;     // radians, clockwise from three o'clock (y runs down)
    float sweep;     // radians
    float grow;      // how much wider the ellipse is at the stroke's end, as a share
    float aa;        // antialias width, px (1 / devicePixelRatio)
    vec4 ink;        // premultiplied
};

const float TAU = 6.283185307179586;

// How far `p` is from the pen's line at the turn `along` (0..1 of the whole stroke), in px:
// the ellipse there is the starting one scaled by 1 + grow * along, and the distance is read
// off its implicit form and that form's slope, which is good to a hair this close to the line.
float away(vec2 p, float along) {
    vec2 ab = radii * (1.0 + grow * along);
    vec2 q = p / ab;
    float len = length(q);
    return abs(len - 1.0) * len / max(length(q / ab), 1e-6);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * itemSize;
    // Where round the ellipse this pixel is, as a turn from the pen's start.
    float turn = mod(atan(p.y / radii.y, p.x / radii.x) - start, TAU);
    float alpha = 0.0;
    // The stroke passes any angle once, and the stretch near the start a second time.
    for (int lap = 0; lap < 2; lap++) {
        float along = (turn + TAU * float(lap)) / sweep;
        if (along > drawn || along > 1.0)
            continue;
        float d = away(p, along);
        // The pen lifts cleanly: the last few px of the laid stroke taper.
        float tip = smoothstep(0.0, 0.012, drawn - along);
        alpha = max(alpha, (1.0 - smoothstep(stroke * 0.5 - aa, stroke * 0.5 + aa, d)) * tip);
    }
    fragColor = ink * alpha * qt_Opacity;
}
