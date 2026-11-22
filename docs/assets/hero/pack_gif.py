#!/usr/bin/env python3
"""Pack palette PNG frames (all sharing one palette) into an optimized GIF.

Called by build.mjs:  python3 -I pack_gif.py FRAME_DIR OUT.gif FPS

ffmpeg's GIF encoder writes every frame in full when the palette has a
transparent entry (needed here for the rounded corners), and ImageMagick runs
out of its cache at 1280 x 640 x 480 frames. Pillow's GIF writer handles both:
it merges identical consecutive frames (adding their durations, so the holds
cost almost nothing) and stores only the changed rectangle of each frame.
"""

import glob
import os
import sys

from PIL import Image


def main():
    frame_dir, out, fps = sys.argv[1], sys.argv[2], float(sys.argv[3])
    paths = sorted(glob.glob(os.path.join(frame_dir, "p[0-9]*.png")))
    if not paths:
        sys.exit("no frames found")
    frames = [Image.open(p) for p in paths]
    for f in frames:
        f.load()
        if f.mode != "P":
            sys.exit(f"{f.filename}: expected a palette PNG, got {f.mode}")
    trans = frames[0].info.get("transparency")
    if isinstance(trans, bytes):  # tRNS chunk as alpha per palette entry
        trans = trans.index(0) if 0 in trans else None
    ms = int(round(1000 / fps))
    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=ms,
        loop=0,
        disposal=1,
        optimize=True,  # unchanged pixels inside each changed rectangle become transparent
        **({"transparency": trans} if trans is not None else {}),
    )


if __name__ == "__main__":
    main()
