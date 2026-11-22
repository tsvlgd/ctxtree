#!/usr/bin/env node
// Rebuild the ctxtree README hero (one command, from anywhere):
//
//   npm --prefix docs/assets/hero install && node docs/assets/hero/build.mjs
//
// (the install is only needed once). Writes docs/assets/hero.gif and
// docs/assets/hero-poster.png. Needs google-chrome (or CHROME=/path/to/chrome),
// ffmpeg and python3 with Pillow on PATH.
//
//   node docs/assets/hero/build.mjs --preview DIR 2,7,12,16,21 [--preview-only]
//     also saves the frames at those times (seconds) as PNG, full size and 800 px wide;
//     with --preview-only it skips the GIF and the poster.
//
// How it works: scene.html draws every frame as a pure function of time
// (window.renderAt(t)); headless Chrome screenshots it at FPS frames per second;
// ffmpeg builds one 256 colour palette for the whole clip; pack_gif.py (Pillow)
// merges repeated frames (the holds) and stores only the changed rectangle of each frame.

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import puppeteer from "puppeteer-core";

const HERE = dirname(fileURLToPath(import.meta.url));
const ASSETS = dirname(HERE);
const W = 1280, H = 640;
const FPS = Number(process.env.FPS || 20);

function which(cmd) {
  try { return execFileSync("sh", ["-c", `command -v ${cmd}`]).toString().trim() || null; } catch { return null; }
}
const CHROME = process.env.CHROME || which("google-chrome") || which("chromium") || which("chromium-browser");
if (!CHROME) throw new Error("Chrome not found; set CHROME=/path/to/chrome");
if (!which("ffmpeg")) throw new Error("ffmpeg not found on PATH");
if (!which("python3")) throw new Error("python3 (with Pillow) not found on PATH");

const args = process.argv.slice(2);
const pi = args.indexOf("--preview");
const only = args.includes("--preview-only");
const preview = pi >= 0 ? { dir: args[pi + 1], times: args[pi + 2].split(",").map(Number) } : null;

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ["--force-color-profile=srgb", "--hide-scrollbars", "--allow-file-access-from-files"],
});
const keep = process.env.KEEP_FRAMES;  // set to a folder to keep the frames for inspection
const tmp = keep || mkdtempSync(join(tmpdir(), "ctxtree-hero-"));
mkdirSync(tmp, { recursive: true });
try {
  const page = await browser.newPage();
  await page.setViewport({ width: W, height: H, deviceScaleFactor: 1 });
  await page.goto(pathToFileURL(join(HERE, "scene.html")).href, { waitUntil: "load" });
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map((i) => (i.complete ? null : new Promise((r) => (i.onload = r)))));
  });
  const { duration, posterT } = await page.evaluate(() => ({ duration: window.DURATION, posterT: window.POSTER_T }));
  const shot = async (t, path) => {
    await page.evaluate((tt) => window.renderAt(tt), t);
    await page.screenshot({ path, omitBackground: true, optimizeForSpeed: true, clip: { x: 0, y: 0, width: W, height: H } });
  };

  const n = only ? 0 : Math.round(duration * FPS);
  for (let i = 0; i < n; i++) await shot(i / FPS, join(tmp, `f${String(i).padStart(4, "0")}.png`));
  const poster = join(ASSETS, "hero-poster.png");
  if (!only) await shot(posterT, poster);
  if (preview) {
    mkdirSync(preview.dir, { recursive: true });
    for (const t of preview.times) {
      const p = join(preview.dir, `t${t.toFixed(2).padStart(5, "0")}.png`);
      await shot(t, p);
      execFileSync("ffmpeg", ["-v", "error", "-y", "-i", p, "-vf", "scale=800:-1:flags=lanczos", p.replace(".png", "-800.png")]);
    }
  }

  if (!only) {
    // One 256 colour palette for the whole clip (GIF alpha is on or off, so the
    // antialiased rounded corners are thresholded), then palette PNG frames that
    // pack_gif.py merges into the GIF (repeated frames merged, changed rectangles only).
    const palette = join(tmp, "palette.png");
    const frames = join(tmp, "f%04d.png");
    execFileSync("ffmpeg", ["-v", "error", "-y", "-framerate", String(FPS), "-i", frames,
      "-vf", "palettegen=max_colors=256:reserve_transparent=1:stats_mode=full", palette], { stdio: "inherit" });
    execFileSync("ffmpeg", ["-v", "error", "-y", "-framerate", String(FPS), "-i", frames, "-i", palette,
      "-lavfi", "[0:v][1:v]paletteuse=dither=bayer:bayer_scale=4:alpha_threshold=128", join(tmp, "p%04d.png")],
      { stdio: "inherit" });
    const out = join(ASSETS, "hero.gif");
    execFileSync("python3", ["-I", join(HERE, "pack_gif.py"), tmp, out, String(FPS)], { stdio: "inherit" });
    console.log(`wrote ${out} (${(statSync(out).size / 1e6).toFixed(2)} MB, ${n} frames rendered, ${duration} s) and ${poster}`);
  }
} finally {
  await browser.close();
  if (!keep && existsSync(tmp)) rmSync(tmp, { recursive: true, force: true });
}
