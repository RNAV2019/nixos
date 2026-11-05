#!/usr/bin/env python3
"""video.py OUT_DIR — count blank frames in each OUT_DIR/*.mkv.

A frame is blank when the island silhouette is missing at y ~ 8-12: fewer than MIN_PX pixels of the
top strip's centre row are near the island colour (taken from the first frame of the same video,
where the island is at rest). A pill that vanishes for a frame between two surfaces shows up as a
blank frame. Prints "<scenario>: <blank> blank of <frames>" and the indices of the blank runs.
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


def analyse(path):
    rows = list(frames(path))
    if not rows:
        return 0, 0, []
    mid = rows[0][(X1 - X0) // 2]          # the resting island at the centre of the row
    blank = []
    for i, r in enumerate(rows):
        near = np.all(np.abs(r.astype(int) - mid.astype(int)) <= TOL, axis=1)
        if near.sum() < MIN_PX:
            blank.append(i)
    return len(blank), len(rows), blank


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
        n, total, blank = analyse(v)
        print(f"{v.stem}: {n} blank of {total} frames" + (f" ({', '.join(runs(blank))})" if blank else ""))


if __name__ == "__main__":
    main()
