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


def main():
    d = Path(sys.argv[1])
    vids = sorted(d.glob("*.mkv"))
    if not vids:
        sys.exit(f"video.py: no .mkv in {d}")
    for v in vids:
        n, total, blank, multi, jumps = analyse(v)
        print(f"{v.stem}: {n} blank of {total} frames" + (f" ({', '.join(runs(blank))})" if blank else ""))
        print(f"  islands: {len(multi)} frames with 2+ components" + (f" ({', '.join(runs(multi))})" if multi else "")
              + f", {len(jumps)} width jumps" + (f" ({', '.join(runs(jumps))})" if jumps else ""))


if __name__ == "__main__":
    main()
