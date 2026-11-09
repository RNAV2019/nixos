#!/usr/bin/env python3
"""sheet.py DIR [NAME...] — a contact sheet per transition capture (transitions.sh).

For DIR/NAME.mkv it finds the frame the transition starts on (the first that differs from the
resting first frame in the island's region), takes the frames at OFFSETS after it (120 fps, so
2 frames = 16.7 ms), crops them to the area anything moved in, and tiles them 4 across with the
time on each: DIR/NAME.png. Needs numpy, pillow and ffmpeg on PATH.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

W, H = 1920, 1080
RX0, RX1, RY1 = 260, 1660, 900          # the island's region: panels open below the bar, centred
TIMES = [0, 17, 33, 50, 67, 83, 108, 133, 167, 217, 283, 500]  # ms after the onset
FPS = 120
QUIET = 24  # raw frames (200 ms) of stillness before the transition


def read(path):
    cmd = ["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"fps=120,crop={RX1 - RX0}:{RY1}:{RX0}:0",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size = (RX1 - RX0) * RY1 * 3
    out = []
    while True:
        buf = p.stdout.read(size)
        if len(buf) < size:
            break
        out.append(np.frombuffer(buf, dtype=np.uint8).reshape(RY1, RX1 - RX0, 3))
    p.wait()
    return out


def changed(a, b):
    d = np.abs(a.astype(np.int16) - b.astype(np.int16)).max(axis=2)
    return np.count_nonzero(d > 24) > 40


def onset(frames, quiet=QUIET):
    """The first change after `quiet` unchanged frames (A at rest); else the first change."""
    still = 0
    first = None
    for i in range(1, len(frames)):
        if changed(frames[i], frames[i - 1]):
            if first is None:
                first = i
            if still >= quiet:
                return i
            still = 0
        else:
            still += 1
    return first


def sheet(path):
    frames = read(path)
    if len(frames) < 4:
        return f"{path.stem}: no frames"
    # Find the onset on the raw frames (the recorder's timer repeats frames at 120 Hz, so stillness
    # is counted in time), then drop exact duplicates so offsets are real frames.
    s_raw = None
    mark, stop = path.with_suffix(".mark"), path.with_suffix(".stop")
    if mark.exists() and stop.exists():
        # B was raised (stop - mark) ms before the capture ended: the first change from then on is
        # the transition, whatever A was doing earlier.
        lead = (int(stop.read_text()) - int(mark.read_text())) * FPS / 1000
        start = max(1, int(len(frames) - 1 - lead))
        s_raw = next((i for i in range(start, len(frames)) if changed(frames[i], frames[i - 1])), None)
    if s_raw is None:
        s_raw = onset(frames)
    uniq = [frames[0]]
    idx = [0]
    for i, f in enumerate(frames[1:], 1):
        if not np.array_equal(f, uniq[-1]):
            uniq.append(f)
            idx.append(i)
    s = None if s_raw is None else next((k for k, i in enumerate(idx) if i >= s_raw), None)
    if s is None:
        return f"{path.stem}: nothing moved"
    # The last distinct frame at or before each time (the one on screen then); 0 ms is the frame
    # before the change.
    def at(ms):
        # Rounded, so the steps stay even: 17 ms is 2 frames and 33 ms is 4, not 3.
        raw = s_raw + round(ms * FPS / 1000)
        k = max(j for j, i in enumerate(idx) if i <= raw)
        return k if ms > 0 else max(0, s - 1)
    picks = [at(t) for t in TIMES]
    chosen = [uniq[i] for i in picks]
    # Crop to where anything differs from the last frame or the first, padded.
    diff = np.zeros(chosen[0].shape[:2], bool)
    for f in chosen + [uniq[0], uniq[-1]]:
        diff |= np.abs(f.astype(np.int16) - uniq[-1].astype(np.int16)).max(axis=2) > 12
        diff |= np.abs(f.astype(np.int16) - uniq[0].astype(np.int16)).max(axis=2) > 12
    ys, xs = np.nonzero(diff)
    if len(xs) == 0:
        return f"{path.stem}: nothing moved"
    pad = 24
    x0, x1 = max(0, xs.min() - pad), min(diff.shape[1], xs.max() + pad)
    y0, y1 = 0, min(diff.shape[0], ys.max() + pad)
    tiles = [Image.fromarray(f[y0:y1, x0:x1]) for f in chosen]
    tw, th = tiles[0].size
    scale = min(1.0, 700 / tw)
    tw2, th2 = int(tw * scale), int(th * scale)
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (cols * tw2 + (cols - 1) * 6, rows * (th2 + 22) ), (30, 30, 30))
    d = ImageDraw.Draw(out)
    for k, (t, i, ms) in enumerate(zip(tiles, picks, TIMES)):
        cx, cy = (k % cols) * (tw2 + 6), (k // cols) * (th2 + 22)
        out.paste(t.resize((tw2, th2), Image.LANCZOS), (cx, cy + 20))
        d.text((cx + 4, cy + 4), f"{path.stem}  +{ms} ms", fill=(235, 235, 235))
    out.save(path.with_suffix(".png"))
    return f"{path.stem}: onset frame {s}, {len(uniq)} distinct frames, crop {x1 - x0}x{y1 - y0}"


def main():
    d = Path(sys.argv[1])
    names = sys.argv[2:] or sorted(p.stem for p in d.glob("*.mkv"))
    for n in names:
        print(sheet(d / f"{n}.mkv"), flush=True)


if __name__ == "__main__":
    main()
