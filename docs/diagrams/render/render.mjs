// Rebuild every diagram (run from the repo root):
//
//   cd docs/diagrams/render && npm ci && node render.mjs
//
// Reads docs/diagrams/*.excalidraw (the source of truth) and writes <slug>.svg
// and <slug>.png beside each one. It uses the official exporter
// (@excalidraw/excalidraw exportToSvg) inside headless Chrome, so strokes are
// the real rough.js hand drawn style and text uses Excalifont (OFL). The SVG
// embeds the font as a base64 subset, so it renders on GitHub without network.
// The PNG is a 2x screenshot of that SVG on white.
//
// Needs: node 18 or later and Google Chrome or Chromium. Set CHROME_PATH to
// point at a browser binary when it is not at a standard location.
// Optional: node render.mjs architecture   renders only the named slugs.

import { build } from "esbuild";
import { createServer } from "node:http";
import { readFile, readdir, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, extname, basename } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const here = dirname(fileURLToPath(import.meta.url));
const diagramsDir = join(here, "..");
const buildDir = join(here, ".build");
const assetDir = join(here, "node_modules/@excalidraw/excalidraw/dist/prod");
const SCALE = 2;
const PADDING = 32;

function findChrome() {
  const candidates = [
    process.env.CHROME_PATH,
    "/usr/bin/google-chrome",
    "/usr/bin/google-chrome-stable",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
  ].filter(Boolean);
  const hit = candidates.find((p) => existsSync(p));
  if (!hit) throw new Error("no Chrome found; set CHROME_PATH");
  return hit;
}

// 1. Bundle the exporter for the browser (ESM with code splitting, so the
//    font subsetting worker chunk keeps working).
await mkdir(buildDir, { recursive: true });
await build({
  stdin: {
    contents:
      'import { exportToSvg } from "@excalidraw/excalidraw";\nwindow.exportToSvg = exportToSvg;\nwindow.exporterReady = true;\n',
    resolveDir: here,
    loader: "js",
  },
  bundle: true,
  format: "esm",
  splitting: true,
  outdir: buildDir,
  entryNames: "entry",
  minify: true,
  define: { "process.env.NODE_ENV": '"production"', "process.env.IS_PREACT": '"false"' },
  logLevel: "error",
});

// 2. Serve the bundle and Excalidraw's font assets on localhost.
const types = { ".js": "text/javascript", ".html": "text/html", ".woff2": "font/woff2", ".css": "text/css", ".svg": "image/svg+xml", ".wasm": "application/wasm" };
const page = `<!doctype html><meta charset="utf-8"><body style="margin:0;background:#fff">
<script>window.EXCALIDRAW_ASSET_PATH = location.origin + "/assets/";</script>
<script type="module" src="/entry.js"></script></body>`;
const server = createServer(async (req, res) => {
  const url = decodeURIComponent(req.url.split("?")[0]);
  let file;
  if (url === "/" || url === "/index.html") {
    res.writeHead(200, { "content-type": "text/html" });
    return res.end(page);
  }
  if (url.startsWith("/assets/")) file = join(assetDir, url.slice("/assets/".length));
  else file = join(buildDir, url.slice(1));
  try {
    const body = await readFile(file);
    res.writeHead(200, { "content-type": types[extname(file)] || "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end();
  }
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const origin = `http://127.0.0.1:${server.address().port}`;

// 3. Export each diagram.
const wanted = process.argv.slice(2);
const slugs = (await readdir(diagramsDir))
  .filter((f) => f.endsWith(".excalidraw"))
  .map((f) => basename(f, ".excalidraw"))
  .filter((s) => wanted.length === 0 || wanted.includes(s));

const browser = await puppeteer.launch({
  executablePath: findChrome(),
  headless: true,
  args: ["--no-sandbox", "--font-render-hinting=none"],
});
try {
  const tab = await browser.newPage();
  tab.on("pageerror", (e) => console.error("page error:", e.message));
  await tab.goto(origin + "/", { waitUntil: "networkidle0" });
  await tab.waitForFunction(() => window.exporterReady === true, { timeout: 60000 });

  for (const slug of slugs) {
    const scene = JSON.parse(await readFile(join(diagramsDir, slug + ".excalidraw"), "utf8"));
    const svg = await tab.evaluate(
      async (scene, padding) => {
        const el = await window.exportToSvg({
          elements: scene.elements.filter((e) => !e.isDeleted),
          appState: {
            ...scene.appState,
            exportBackground: true,
            viewBackgroundColor: "#ffffff",
            exportWithDarkMode: false,
            exportEmbedScene: false,
          },
          files: scene.files || {},
          exportPadding: padding,
        });
        return el.outerHTML;
      },
      scene,
      PADDING,
    );
    const svgText = '<?xml version="1.0" encoding="UTF-8"?>\n' + svg + "\n";
    await writeFile(join(diagramsDir, slug + ".svg"), svgText);

    // PNG: draw the finished SVG (fonts embedded) at 2x and screenshot it.
    const size = await tab.evaluate(async (svgText) => {
      document.body.innerHTML = "";
      const img = new Image();
      img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgText)));
      await img.decode();
      img.id = "shot";
      img.style.display = "block";
      document.body.appendChild(img);
      return { w: img.naturalWidth, h: img.naturalHeight };
    }, svgText);
    await tab.setViewport({ width: Math.ceil(size.w), height: Math.ceil(size.h), deviceScaleFactor: SCALE });
    const shot = await tab.$("#shot");
    await new Promise((r) => setTimeout(r, 300));
    await shot.screenshot({ path: join(diagramsDir, slug + ".png"), omitBackground: false });
    console.log(`${slug}: ${Math.round(size.w * SCALE)}x${Math.round(size.h * SCALE)} png, svg ${(svgText.length / 1024).toFixed(0)} KB`);
  }
} finally {
  await browser.close();
  server.close();
}
