#!/usr/bin/env python3
"""video.py OUT_DIR — count blank frames in each OUT_DIR/*.mkv.

A frame is blank when the island silhouette is missing at y ~ 8-12: fewer than MIN_PX pixels of the
top strip's centre row are near the island colour (taken from the first frame of the same video,
where the island is at rest). A pill that vanishes for a frame between two surfaces shows up as a
blank frame. Prints "<scenario>: <blank> blank of <frames>" and the indices of the blank runs.

It also reads the silhouette itself: the components (runs of island-coloured pixels on that row, runs
less than GAP px apart being one) and its extent. A frame with more than one component, or whose
width differs from the last frame's by more than JUMP px (the fastest spring moves ~40 px a frame at
120 Hz), shows two islands, or a shape that jumped: the still and the taker at different sizes.
Prints "  islands: <n> frames with 2+ components (runs), <m> width jumps (frames)". Runs longer than one
frame are what the handover must not have.
With --satellite it also tracks the phone satellite's disc (see satellite()).
Needs numpy and ffmpeg on PATH:  nix shell nixpkgs#ffmpeg --impure --expr
'with import <nixpkgs> {}; python3.withPackages (p: [p.numpy])' ...   (see README.md)
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

W, H = 1920, 1080
ROW = 12  # the pill starts at y = 8; a few rows down clears its corner rounding
X0, X1 = 460, 1460   # where the island can be at y = 8 (centred pill, widest panel narrower than this)
TOL = 28             # per-channel distance from the island colour
MIN_PX = 24          # fewer matching pixels than this = no silhouette
GAP = 12             # island-coloured runs closer than this are one component
JUMP = 50            # px of width change in one frame that no spring produces


def frames(path):
    """Yield the y = ROW row of each frame, X0..X1, as an (n, 3) uint8 array."""
    cmd = ["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"crop={X1 - X0}:1:{X0}:{ROW}",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size = (X1 - X0) * 3
    while True:
        buf = p.stdout.read(size)
        if len(buf) < size:
            break
        yield np.frombuffer(buf, dtype=np.uint8).reshape(-1, 3)
    p.wait()


def silhouette(r, mid):
    """(components, left, right) of the island-coloured pixels of one row."""
    near = np.all(np.abs(r.astype(int) - mid.astype(int)) <= TOL, axis=1)
    idx = np.flatnonzero(near)
    if len(idx) < MIN_PX:
        return 0, 0, 0
    return 1 + int(np.sum(np.diff(idx) > GAP)), int(idx[0]), int(idx[-1])


def analyse(path):
    rows = list(frames(path))
    if not rows:
        return 0, 0, [], [], []
    mid = rows[0][(X1 - X0) // 2]          # the resting island at the centre of the row
    blank = []
    for i, r in enumerate(rows):
        near = np.all(np.abs(r.astype(int) - mid.astype(int)) <= TOL, axis=1)
        if near.sum() < MIN_PX:
            blank.append(i)
    sil = [silhouette(r, mid) for r in rows]
    multi = [i for i, (c, _, _) in enumerate(sil) if c > 1]
    jumps = [i for i in range(1, len(sil)) if sil[i][0] and sil[i - 1][0]
             and abs((sil[i][2] - sil[i][1]) - (sil[i - 1][2] - sil[i - 1][1])) > JUMP]
    return len(blank), len(rows), blank, multi, jumps


def runs(idx):
    out, start = [], None
    for k, i in enumerate(idx):
        if start is None:
            start = i
        if k + 1 == len(idx) or idx[k + 1] != i + 1:
            out.append(f"{start}" if start == i else f"{start}-{i}")
            start = None
    return out


SAT_X0, SAT_X1, SAT_Y1 = 700, 1800, 80   # the band the bar's island and its satellite live in
SAT_ROW = 29                          # the disc's midline: the pill's top (8) plus half the bar (21)
DISC = 44                             # columns counted as the disc: its diameter and a pixel each side
AREA_FULL = 3.1416 * 21 * 21          # a docked disc's area, px
AREA_TOL = 0.02                       # jump of the disc's area, as a share of a full disc
POP_RATIO = 2.5                       # how much bigger than its neighbours' steps a step must be to be a pop
CENTRE_TOL = 1.5                      # jump of its right edge, px, that the spring cannot explain


def satellite(path):
    """Per frame, the right edge R of the island-coloured silhouette on the disc's midline and the
    area A of island-coloured pixels within DISC columns of it. The recorder's frames come at
    uneven times (a repeated frame, a dropped one), so the steps between frames are not the
    spring's; a pop is a step that is out of scale with both its neighbours: more than POP_RATIO
    times the larger of them, and by more than CENTRE_TOL px (R) or AREA_TOL of a full disc (A).
    A repeated frame is skipped. Returns (n_frames, tracked, [(frame, what, step)])."""
    cmd = ["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"crop={SAT_X1 - SAT_X0}:{SAT_Y1}:{SAT_X0}:0",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size = (SAT_X1 - SAT_X0) * SAT_Y1 * 3
    mid = None
    last = None
    track = []
    n = 0
    while True:
        buf = p.stdout.read(size)
        if len(buf) < size:
            break
        img = np.frombuffer(buf, dtype=np.uint8).reshape(SAT_Y1, SAT_X1 - SAT_X0, 3)
        if mid is None:
            mid = img[12, (960 - SAT_X0)].astype(int)    # the resting island, top centre
        near = np.all(np.abs(img.astype(int) - mid) <= TOL, axis=2)
        cols = np.flatnonzero(near[SAT_ROW])
        if len(cols):
            # The silhouette is the run of columns through the centre, runs less than 30 px apart
            # being one (the docked disc sits 8 px off the pill); dark wallpaper beyond is not it.
            cuts = np.flatnonzero(np.diff(cols) > 30)
            ends = np.append(cols[cuts], cols[-1])
            starts = np.insert(cols[cuts + 1], 0, cols[0])
            mid_col = 960 - SAT_X0
            hit = [k for k in range(len(ends)) if starts[k] <= mid_col <= ends[k]]
            if not hit:
                n += 1
                continue
            right = int(ends[hit[0]])
            area = int(near[:, max(0, right - DISC + 1):right + 1].sum())
            raw = img.tobytes()
            if raw != last:
                track.append((n, right, area))
            last = raw
        n += 1
    p.wait()
    flags = []
    for k in range(2, len(track) - 1):
        for what, col, tol in (("edge", 1, CENTRE_TOL), ("area", 2, AREA_TOL * AREA_FULL)):
            before = abs(track[k - 1][col] - track[k - 2][col])
            step = abs(track[k][col] - track[k - 1][col])
            after = abs(track[k + 1][col] - track[k][col])
            if step > tol and step > POP_RATIO * max(before, after):
                flags.append((track[k][0], what, track[k][col] - track[k - 1][col]))
    return n, len(track), flags


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    sat = "--satellite" in sys.argv
    d = Path(args[0])
    vids = sorted(d.glob("*.mkv"))
    if not vids:
        sys.exit(f"video.py: no .mkv in {d}")
    for v in vids:
        if sat:
            n, tracked, flags = satellite(v)
            print(f"{v.stem}: satellite {len(flags)} flags over {tracked} tracked of {n} frames"
                  + (": " + ", ".join(f"{f}:{w}{x:+.1f}" for f, w, x in flags[:40]) if flags else ""))
            continue
        n, total, blank, multi, jumps = analyse(v)
        print(f"{v.stem}: {n} blank of {total} frames" + (f" ({', '.join(runs(blank))})" if blank else ""))
        print(f"  islands: {len(multi)} frames with 2+ components" + (f" ({', '.join(runs(multi))})" if multi else "")
              + f", {len(jumps)} width jumps" + (f" ({', '.join(runs(jumps))})" if jumps else ""))


if __name__ == "__main__":
    main()
