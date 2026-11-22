#!/usr/bin/env python3
"""Generate the ctxtree README hero animation.

Rebuild (from anywhere):

    python3 docs/assets/hero/make_hero.py

Writes docs/assets/hero.gif and docs/assets/hero-poster.png.
Needs python3 with Pillow, ffmpeg and ImageMagick (magick or convert) on PATH.

    python3 docs/assets/hero/make_hero.py --preview OUT_DIR 0,2.2,4.4,6,7.4,9
        also saves the frames at those times (seconds) as PNG for review.

Font: Lato (Regular, Bold, Black), SIL Open Font License 1.1, vendored in
fonts/ with its license (fonts/OFL.txt). Every shape is drawn here; the agent
badges are original generic badges, not product logos.

Storyboard (12 s at 20 fps, seamless loop: first and last frame are the same
"four badges on an empty card" state):
  0.0 to 3.0   Problem: "Your agents forget." Each agent grows its own sticky
               notes, some duplicated or contradicting, then they fade and get
               a red "?" (forgotten, out of sync).
  3.0 to 4.6   Turn: the notes fly into the center and become one memory/
               tree (INDEX.md, topics, log, active task, plus global rules and
               profile). The headline becomes "ctxtree" and the tagline.
  4.6 to 8.0   Solution: lines connect every agent to the tree, a "memory
               behind code" warning shows, pulses travel agent to tree and
               back, the warning flips to "synced with code".
  8.0 to 11.2  Hold on the final frame (also saved as the poster).
  11.2 to 12.0 Fade back to the opening state.
"""

import argparse
import math
import os
import random
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.dirname(HERE)
FONTS = os.path.join(HERE, "fonts")

W, H = 800, 400   # output size
IM = None         # ImageMagick binary, found at run time
S = 2             # supersampling factor; everything is drawn at 2x then reduced
FPS = 20
T = 12.0
POSTER_T = 9.5
RADIUS = 22       # card corner radius

# Palette (works as a light card on both GitHub themes)
PAPER = (250, 247, 239)
FRAME = (70, 74, 82)
INK = (31, 35, 40)
MUTED = (96, 104, 114)
WHITE = (255, 255, 255)
NOTE = (255, 234, 150)
NOTE_EDGE = (176, 140, 40)
RED = (207, 34, 46)
AMBER_BG = (255, 232, 176)
AMBER_INK = (150, 96, 0)
GREEN_BG = (212, 243, 222)
GREEN_INK = (26, 127, 55)

# name, initials, color, badge top-left (1x), side
AGENTS = [
    ("Claude Code", "CC", (196, 86, 44), (28, 148), "L"),
    ("OpenCode", "OC", (79, 82, 214), (600, 148), "R"),
    ("Codex", "CX", (14, 128, 110), (28, 288), "L"),
    ("Antigravity", "AG", (178, 50, 118), (600, 288), "R"),
]
BADGE_W, BADGE_H = 172, 52

# Each agent's private notes: (text, center x, center y, angle)
NOTES = [
    [("uses pnpm", 262, 138, -4), ("auth: JWT", 272, 210, 3)],
    [("uses npm?", 538, 138, 4), ("auth: ???", 528, 210, -3)],
    [("db: postgres", 262, 278, 3), ("todo: tests", 272, 350, -4)],
    [("db: mysql?", 538, 278, -3), ("todo: ???", 528, 350, 4)],
]

CARD = (296, 120, 504, 374)  # memory tree card box (1x)
CARD_C = ((CARD[0] + CARD[2]) / 2, (CARD[1] + CARD[3]) / 2)
FILES = ["INDEX.md", "auth.md", "db.md", "log.md", "active-task.md"]


def font(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f"Lato-{weight}.ttf"), int(size * S))


def s(v):
    return int(round(v * S))


# ---------------------------------------------------------------- easing ---

def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def smooth(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def prog(t, a, b):
    """Eased progress of t through [a, b]."""
    return smooth((t - a) / (b - a))


def back_out(x):
    x = clamp(x)
    c = 1.70158
    return 1 + (c + 1) * (x - 1) ** 3 + c * (x - 1) ** 2


def lerp(a, b, x):
    return a + (b - a) * x


# ------------------------------------------------------------ rough lines ---

def wobble(points, seed, amp):
    """Offset a polyline along its normals by smooth, seeded noise."""
    rnd = random.Random(seed)
    waves = [(rnd.uniform(0.02, 0.05), rnd.uniform(0, 6.28), rnd.uniform(0.4, 1.0)) for _ in range(2)]
    out = []
    dist = 0.0
    for i, (x, y) in enumerate(points):
        if i:
            dist += math.hypot(x - points[i - 1][0], y - points[i - 1][1])
        j = min(i + 1, len(points) - 1)
        k = max(i - 1, 0)
        dx, dy = points[j][0] - points[k][0], points[j][1] - points[k][1]
        n = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / n, dx / n
        off = sum(a * math.sin(f * dist / S + p) for f, p, a in waves) * amp * S / 1.4
        out.append((x + nx * off, y + ny * off))
    return out


def rough_stroke(draw, points, color, width, seed, amp=1.0, passes=2):
    for p in range(passes):
        pts = wobble(points, seed * 31 + p, amp)
        draw.line(pts, fill=color, width=s(width), joint="curve")


def rrect_path(x0, y0, x1, y1, r, step=3):
    """Points around a rounded rectangle (supersampled coordinates in)."""
    pts = []

    def arc(cx, cy, a0, a1):
        n = max(4, int(abs(a1 - a0) * r / (step * S)))
        for i in range(n + 1):
            a = math.radians(lerp(a0, a1, i / n))
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))

    arc(x1 - r, y0 + r, -90, 0)
    arc(x1 - r, y1 - r, 0, 90)
    arc(x0 + r, y1 - r, 90, 180)
    arc(x0 + r, y0 + r, 180, 270)
    pts.append(pts[0])
    # densify straight edges so the wobble bends them
    dense = []
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        d = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(d / (step * S)))
        for k in range(n):
            dense.append((lerp(a[0], b[0], k / n), lerp(a[1], b[1], k / n)))
    dense.append(pts[-1])
    return dense


def rough_box(draw, box, r, fill, outline, width, seed, amp=0.9):
    x0, y0, x1, y1 = [s(v) for v in box]
    if fill is not None:
        draw.rounded_rectangle((x0, y0, x1, y1), radius=s(r), fill=fill)
    if outline is not None:
        rough_stroke(draw, rrect_path(x0, y0, x1, y1, s(r)), outline, width, seed, amp)


def bezier(p0, p1, p2, p3, n=60):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0]
        y = u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]
        pts.append((x, y))
    return pts


# --------------------------------------------------------------- sprites ---

def text_center(draw, xy, text, fnt, fill):
    draw.text(xy, text, font=fnt, fill=fill, anchor="mm")


def make_badge(name, initials, color, seed):
    pad = s(6)
    img = Image.new("RGBA", (s(BADGE_W) + 2 * pad, s(BADGE_H) + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    off = pad / S
    rough_box(d, (off, off, off + BADGE_W, off + BADGE_H), 16, color + (255,), INK, 2, seed)
    cx, cy = off + 28, off + BADGE_H / 2
    d.ellipse((s(cx - 16), s(cy - 16), s(cx + 16), s(cy + 16)), fill=WHITE)
    text_center(d, (s(cx), s(cy) + s(1)), initials, font("Black", 13), color)
    d.text((s(off + 52), s(cy) + s(1)), name, font=font("Bold", 18), fill=WHITE, anchor="lm")
    return img


def make_note(text, angle, seed):
    w, h = 112, 32
    pad = 6
    img = Image.new("RGBA", (s(w + 2 * pad), s(h + 2 * pad)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rough_box(d, (pad, pad, pad + w, pad + h), 4, NOTE + (255,), NOTE_EDGE, 1.4, seed, 0.6)
    text_center(d, (s(pad + w / 2), s(pad + h / 2) + s(1)), text, font("Bold", 15), INK)
    return img.rotate(angle, resample=Image.BICUBIC, expand=True)


def make_qmark():
    r = 13
    img = Image.new("RGBA", (s(2 * r + 4), s(2 * r + 4)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((s(2), s(2), s(2 + 2 * r), s(2 + 2 * r)), fill=RED, outline=WHITE, width=s(2))
    text_center(d, (s(r + 2), s(r + 3)), "?", font("Black", 18), WHITE)
    return img


def make_headline(title, sub, title_font, sub_size):
    img = Image.new("RGBA", (s(W), s(110)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    text_center(d, (s(W / 2), s(44)), title, title_font, INK)
    text_center(d, (s(W / 2), s(86)), sub, font("Regular", sub_size), MUTED)
    return img


def make_card_base():
    x0, y0, x1, y1 = CARD
    pad = 8
    img = Image.new("RGBA", (s(x1 - x0 + 2 * pad), s(y1 - y0 + 2 * pad)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w, h = x1 - x0, y1 - y0
    box = (pad, pad, pad + w, pad + h)
    # soft offset shadow, hand drawn feel
    d.rounded_rectangle((s(pad + 4), s(pad + 5), s(pad + w + 4), s(pad + h + 5)), radius=s(14), fill=(0, 0, 0, 28))
    rough_box(d, box, 14, WHITE + (255,), None, 2, 101)
    # header strip
    d.rounded_rectangle((s(pad), s(pad), s(pad + w), s(pad + 40)), radius=s(14), fill=INK)
    d.rectangle((s(pad), s(pad + 26), s(pad + w), s(pad + 40)), fill=INK)
    # folder glyph
    fx, fy = pad + 18, pad + 14
    d.rounded_rectangle((s(fx), s(fy), s(fx + 9), s(fy + 5)), radius=s(1.5), fill=NOTE)
    d.rounded_rectangle((s(fx), s(fy + 3), s(fx + 20), s(fy + 16)), radius=s(2.5), fill=NOTE)
    d.text((s(fx + 30), s(pad + 21)), "memory/", font=font("Bold", 19), fill=WHITE, anchor="lm")
    rough_box(d, box, 14, None, INK, 2, 101)
    return img, pad


def row_y(i):
    return CARD[1] + 58 + i * 25


def make_row(i, name):
    img = Image.new("RGBA", (s(200), s(24)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # tree connector: vertical part drawn per row, elbow into the file name
    last = i == len(FILES) - 1
    x = 10
    d.line((s(x), 0, s(x), s(12) if last else s(24)), fill=MUTED, width=s(1.6))
    d.line((s(x), s(12), s(x + 12), s(12)), fill=MUTED, width=s(1.6))
    weight = "Bold" if name == "INDEX.md" else "Regular"
    d.text((s(x + 18), s(12) + s(1)), name, font=font(weight, 16), fill=INK, anchor="lm")
    return img


def make_global_row():
    img = Image.new("RGBA", (s(200), s(24)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((s(10), s(12)), "+ GLOBAL.md  PROFILE.md", font=font("Bold", 13), fill=MUTED, anchor="lm")
    return img


def make_pill(kind):
    w, h = 180, 28
    img = Image.new("RGBA", (s(w + 4), s(h + 4)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bg, ink = (AMBER_BG, AMBER_INK) if kind == "stale" else (GREEN_BG, GREEN_INK)
    d.rounded_rectangle((s(2), s(2), s(2 + w), s(2 + h)), radius=s(h / 2), fill=bg, outline=ink, width=s(1.5))
    cx, cy = 2 + 18, 2 + h / 2
    d.ellipse((s(cx - 9), s(cy - 9), s(cx + 9), s(cy + 9)), fill=ink)
    if kind == "stale":
        text_center(d, (s(cx), s(cy) + s(1)), "!", font("Black", 14), WHITE)
        label = "memory behind code"
    else:
        d.line([(s(cx - 4.5), s(cy + 0.5)), (s(cx - 1), s(cy + 4)), (s(cx + 5), s(cy - 3.5))],
               fill=WHITE, width=s(2.2), joint="curve")
        label = "synced with code"
    d.text((s(cx + 16), s(cy) + s(1)), label, font=font("Bold", 14), fill=ink, anchor="lm")
    return img


# ------------------------------------------------------------- compositing ---

def paste(frame, sprite, center, scale=1.0, alpha=1.0):
    if alpha <= 0.003 or scale <= 0.01:
        return
    spr = sprite
    if abs(scale - 1.0) > 1e-3:
        spr = sprite.resize((max(1, int(sprite.width * scale)), max(1, int(sprite.height * scale))), Image.BICUBIC)
    if alpha < 0.997:
        a = spr.getchannel("A").point(lambda v: int(v * alpha))
        spr = spr.copy()
        spr.putalpha(a)
    x = int(round(s(center[0]) - spr.width / 2))
    y = int(round(s(center[1]) - spr.height / 2))
    layer = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    layer.paste(spr, (x, y))
    frame.alpha_composite(layer)


class Scene:
    def __init__(self):
        self.badges = [make_badge(n, i, c, 10 + k) for k, (n, i, c, _, _) in enumerate(AGENTS)]
        self.notes = [[make_note(t, a, 50 + 7 * k + j) for j, (t, _, _, a) in enumerate(ns)]
                      for k, ns in enumerate(NOTES)]
        self.qmark = make_qmark()
        self.head1 = make_headline("Your agents forget.",
                                   "Each one keeps private notes: duplicated, out of sync, gone next session.",
                                   font("Black", 36), 17)
        self.head2 = make_headline("ctxtree", "One memory for every coding agent.", font("Black", 46), 19)
        self.card, self.card_pad = make_card_base()
        self.rows = [make_row(i, n) for i, n in enumerate(FILES)]
        self.global_row = make_global_row()
        self.pills = {"stale": make_pill("stale"), "synced": make_pill("synced")}
        self.paths = []
        for k, (_, _, _, (bx, by), side) in enumerate(AGENTS):
            cy = by + BADGE_H / 2
            if side == "L":
                a, b = (bx + BADGE_W + 2, cy), (CARD[0] - 2, 186 if by < 200 else 300)
                c1, c2 = (a[0] + 44, a[1]), (b[0] - 44, b[1])
            else:
                a, b = (bx - 2, cy), (CARD[2] + 2, 186 if by < 200 else 300)
                c1, c2 = (a[0] - 44, a[1]), (b[0] + 44, b[1])
            pts = [(s(x), s(y)) for x, y in bezier(a, c1, c2, b)]
            self.paths.append(wobble(pts, 400 + k, 0.8))
        self.background = self.make_background()

    def make_background(self):
        img = Image.new("RGBA", (s(W), s(H)), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((0, 0, s(W) - 1, s(H) - 1), radius=s(RADIUS), fill=PAPER)
        rough_box(d, (7, 7, W - 7, H - 7), RADIUS - 6, None, FRAME, 1.6, 7, 0.7)
        return img


def draw_path(frame, pts, progress, color, width):
    if progress <= 0:
        return
    n = max(2, int(len(pts) * progress))
    d = ImageDraw.Draw(frame)
    d.line(pts[:n], fill=color, width=s(width), joint="curve")


def point_on(pts, x):
    i = clamp(x) * (len(pts) - 1)
    a = int(i)
    b = min(a + 1, len(pts) - 1)
    f = i - a
    return (lerp(pts[a][0], pts[b][0], f) / S, lerp(pts[a][1], pts[b][1], f) / S)


def render(scene, t, soft_corners=False):
    f = scene.background.copy()
    out = 1 - prog(t, 11.2, 11.9)  # loop fade back to the opening state

    # headlines
    h1 = prog(t, 0.2, 0.7) * (1 - prog(t, 2.9, 3.3))
    h2 = prog(t, 3.3, 3.9) * out
    paste(f, scene.head1, (W / 2, 55 - 6 * (1 - prog(t, 0.2, 0.7))), alpha=h1)
    paste(f, scene.head2, (W / 2, 55 + 6 * (1 - prog(t, 3.3, 3.9))), alpha=h2)

    # connector lines, drawn under the badges and the card
    line_p = prog(t, 4.6, 5.5)
    if line_p > 0 and out > 0:
        layer = Image.new("RGBA", f.size, (0, 0, 0, 0))
        for k, pts in enumerate(scene.paths):
            p = prog(t, 4.6 + 0.12 * k, 5.4 + 0.12 * k)
            draw_path(layer, pts, p, INK + (255,), 2.2)
        if out < 1:
            layer.putalpha(layer.getchannel("A").point(lambda v: int(v * out)))
        f.alpha_composite(layer)

    # memory tree card
    card_in = prog(t, 3.45, 4.0)
    if card_in > 0 and out > 0:
        sc = lerp(0.85, 1.0, back_out(clamp((t - 3.45) / 0.6)))
        alpha = card_in * out
        x0, y0, x1, y1 = CARD
        layer = scene.card.copy()
        for i, row in enumerate(scene.rows):
            r = prog(t, 3.9 + 0.12 * i, 4.2 + 0.12 * i)
            if r > 0:
                rr = row.copy()
                rr.putalpha(rr.getchannel("A").point(lambda v, r=r: int(v * r)))
                layer.alpha_composite(rr, (s(scene.card_pad + 8), s(row_y(i) - y0 + scene.card_pad - 12 - 6 * (1 - r))))
        g = prog(t, 4.5, 4.9)
        if g > 0:
            gr = scene.global_row.copy()
            gr.putalpha(gr.getchannel("A").point(lambda v: int(v * g)))
            gy = row_y(len(FILES)) + 8
            layer.alpha_composite(gr, (s(scene.card_pad + 8), s(gy - y0 + scene.card_pad - 12)))
            d = ImageDraw.Draw(layer)
            dy = s(gy - y0 + scene.card_pad - 16)
            for xx in range(s(scene.card_pad + 14), s(scene.card_pad + x1 - x0 - 14), s(8)):
                d.line((xx, dy, xx + s(4), dy), fill=MUTED + (int(160 * g),), width=s(1))
        paste(f, layer, CARD_C, sc, alpha)

        # sync status pill
        pill_y = y1 - 24
        stale = prog(t, 5.3, 5.6) * (1 - prog(t, 6.75, 6.9))
        synced = prog(t, 6.8, 7.0)
        if stale > 0:
            paste(f, scene.pills["stale"], (CARD_C[0], pill_y), sc, stale * alpha)
        if synced > 0:
            pop = 1 + 0.12 * math.sin(math.pi * clamp((t - 6.8) / 0.35))
            paste(f, scene.pills["synced"], (CARD_C[0], pill_y), sc * pop, synced * alpha)

    # notes: pop in, fade and get a "?", then fly into the center and become the tree
    for k, ns in enumerate(NOTES):
        for j, (_, nx, ny, _) in enumerate(ns):
            idx = 2 * k + j
            pop = clamp((t - (0.6 + 0.16 * idx)) / 0.35)
            if pop <= 0:
                continue
            fly = prog(t, 3.0 + 0.05 * idx, 3.75 + 0.05 * idx)
            if fly >= 1:
                continue
            forget = prog(t, 1.9 + 0.08 * k, 2.4 + 0.08 * k) * (1 - prog(fly, 0.0, 0.3))
            x, y = lerp(nx, CARD_C[0], fly), lerp(ny, CARD_C[1] - 10, fly)
            scale = back_out(pop) * lerp(1.0, 0.3, fly)
            alpha = min(1, pop * 2) * lerp(1.0, 0.45, forget) * (1 - prog(fly, 0.65, 1.0))
            paste(f, scene.notes[k][j], (x, y), scale, alpha)
            q = clamp((t - (1.95 + 0.07 * idx)) / 0.3) * (1 - prog(fly, 0.0, 0.25))
            if q > 0:
                paste(f, scene.qmark, (x + 58, y - 16), back_out(q), min(1, q * 2))

    # pulses: agents write to the tree, then the tree feeds every agent
    for k, pts in enumerate(scene.paths):
        color = AGENTS[k][2]
        for a, b, rev in ((5.7 + 0.1 * k, 6.6 + 0.1 * k, False), (7.0 + 0.05 * k, 7.8 + 0.05 * k, True)):
            if a <= t <= b:
                x = (t - a) / (b - a)
                x = smooth(x)
                pos = point_on(pts, 1 - x if rev else x)
                alpha = min(1, 6 * min(x, 1 - x) + 0.2)
                dot = Image.new("RGBA", (s(22), s(22)), (0, 0, 0, 0))
                dd = ImageDraw.Draw(dot)
                dd.ellipse((s(1), s(1), s(21), s(21)), fill=color + (70,))
                dd.ellipse((s(5), s(5), s(17), s(17)), fill=color, outline=WHITE, width=s(2))
                paste(f, dot, pos, 1.0, alpha)

    # agent badges (always present; they are the loop anchor)
    for k, (_, _, color, (bx, by), _) in enumerate(AGENTS):
        center = (bx + BADGE_W / 2, by + BADGE_H / 2)
        # glow ring when the tree's pulse reaches the agent
        arrive = 7.8 + 0.05 * k
        g = clamp(1 - abs(t - arrive) / 0.35)
        if g > 0:
            ring = Image.new("RGBA", (s(BADGE_W + 20), s(BADGE_H + 20)), (0, 0, 0, 0))
            ImageDraw.Draw(ring).rounded_rectangle((0, 0, ring.width - 1, ring.height - 1), radius=s(22),
                                                   fill=color + (int(90 * g),))
            paste(f, ring, center)
        paste(f, scene.badges[k], center)

    frame = f.resize((W, H), Image.LANCZOS)
    # hard alpha for GIF: inside the rounded card is opaque, outside fully transparent
    # (the PNG poster gets antialiased corners instead)
    if soft_corners:
        mask = Image.new("L", (W * 4, H * 4), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, W * 4 - 1, H * 4 - 1), radius=RADIUS * 4, fill=255)
        mask = mask.resize((W, H), Image.LANCZOS)
    else:
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), radius=RADIUS, fill=255)
    frame.putalpha(mask)
    return frame


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--preview", nargs=2, metavar=("DIR", "TIMES"),
                    help="also save frames at comma separated times (s) as PNG into DIR")
    ap.add_argument("--out", default=os.path.join(ASSETS, "hero.gif"))
    ap.add_argument("--poster", default=os.path.join(ASSETS, "hero-poster.png"))
    args = ap.parse_args()

    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg not found on PATH")
    global IM
    IM = shutil.which("magick") or shutil.which("convert")
    if not IM:
        sys.exit("ImageMagick (magick or convert) not found on PATH")

    scene = Scene()
    n = int(round(T * FPS))
    tmp = tempfile.mkdtemp(prefix="ctxtree-hero-")
    try:
        for i in range(n):
            render(scene, i / FPS).save(os.path.join(tmp, f"f{i:04d}.png"))
        render(scene, POSTER_T, soft_corners=True).save(args.poster, optimize=True)
        if args.preview:
            os.makedirs(args.preview[0], exist_ok=True)
            for ts in args.preview[1].split(","):
                render(scene, float(ts)).save(os.path.join(args.preview[0], f"t{float(ts):05.2f}.png"))
        vf = ("split[a][b];[a]palettegen=max_colors=128:reserve_transparent=1:stats_mode=full[p];"
              "[b][p]paletteuse=dither=bayer:bayer_scale=5:alpha_threshold=128")
        raw = os.path.join(tmp, "raw.gif")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(FPS), "-i", os.path.join(tmp, "f%04d.png"),
                        "-filter_complex", vf, "-loop", "0", raw], check=True)
        # ffmpeg writes every frame in full when the palette has transparency (the rounded
        # corners). ImageMagick merges repeated frames (summing their delays) and stores
        # only the changed rectangle of each frame, which cuts the size about tenfold.
        subprocess.run([IM, raw, "-layers", "RemoveDups", "-layers", "Optimize", "-loop", "0", args.out], check=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"wrote {args.out} ({os.path.getsize(args.out) / 1e6:.2f} MB, {n} frames) and {args.poster}")


if __name__ == "__main__":
    main()
