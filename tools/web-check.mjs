// Plays the web build in a real browser with nobody at the mouse.
//
//   node tools/web-check.mjs            3 sessions
//   node tools/web-check.mjs 10         as many as you like
//
// It serves build/site on a local port, opens it in headless Chrome with the
// bot playing (?autoplay), and reads the page's console. It passes when the
// requested number of sessions finish and the page reports no errors.
// Needs Chrome or Chromium: set CHROME_BIN if it is not in a usual place.
// No packages to install: it uses only what ships with Node 22 or newer.

import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, extname, join, normalize, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const RUNS = parseInt(process.argv[2] || "3", 10);
const TIMEOUT_MS = (60 + RUNS * 110) * 1000;
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "build", "site");
const TYPES = {
  ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream",
  ".png": "image/png", ".ttf": "font/ttf", ".txt": "text/plain", ".json": "application/json",
};

if (!existsSync(join(ROOT, "index.html"))) {
  console.error("No web build found. Run tools/export.sh web and tools/build-site.sh first.");
  process.exit(2);
}

function findChrome() {
  const candidates = [
    process.env.CHROME_BIN,
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
    "/usr/bin/google-chrome", "/usr/bin/chromium-browser", "/usr/bin/chromium",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ];
  return candidates.find((p) => p && existsSync(p));
}

const server = createServer((req, res) => {
  let path = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (path.endsWith("/")) path += "index.html";
  const file = normalize(join(ROOT, path));
  if (!file.startsWith(ROOT) || !existsSync(file) || !statSync(file).isFile()) {
    res.writeHead(404).end("not found");
    return;
  }
  res.writeHead(200, { "Content-Type": TYPES[extname(file)] || "application/octet-stream" });
  res.end(readFileSync(file));
});

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const chrome = findChrome();
  if (!chrome) {
    console.error("Chrome was not found. Set CHROME_BIN to its path.");
    process.exit(2);
  }
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const port = server.address().port;
  const profile = mkdtempSync(join(tmpdir(), "tryout-web-check-"));
  const url = `http://127.0.0.1:${port}/index.html?autoplay&mute&soak-log&skill=0.8`;
  const browser = spawn(chrome, [
    "--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`,
    "--no-first-run", "--no-default-browser-check", "--window-size=1280,720",
    "--enable-unsafe-swiftshader", "--autoplay-policy=no-user-gesture-required", "about:blank",
  ], { stdio: ["ignore", "ignore", "pipe"] });

  // Chrome prints the address of its control socket on stderr.
  const wsBase = await new Promise((ok, fail) => {
    let text = "";
    const timer = setTimeout(() => fail(new Error("Chrome did not start")), 20000);
    browser.stderr.on("data", (chunk) => {
      text += chunk.toString();
      const m = text.match(/DevTools listening on (ws:\/\/[^\s]+)/);
      if (m) { clearTimeout(timer); ok(m[1]); }
    });
  });
  const debugPort = new URL(wsBase).port;
  const targets = await (await fetch(`http://127.0.0.1:${debugPort}/json/list`)).json();
  const page = targets.find((t) => t.type === "page");
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((ok) => ws.addEventListener("open", ok, { once: true }));

  let id = 0;
  const send = (method, params = {}) => ws.send(JSON.stringify({ id: ++id, method, params }));
  const runs = [];
  const problems = [];
  let engineLine = "";
  ws.addEventListener("message", (event) => {
    const msg = JSON.parse(event.data);
    if (msg.method === "Runtime.consoleAPICalled") {
      const text = msg.params.args.map((a) => a.value ?? a.description ?? "").join(" ");
      if (text.startsWith("soak run=")) { runs.push(text); console.log(text); }
      else if (text.includes("OpenGL")) engineLine = text;
      if (msg.params.type === "error" || /SCRIPT ERROR|Parse Error/.test(text)) problems.push(text);
    } else if (msg.method === "Runtime.exceptionThrown") {
      problems.push(msg.params.exceptionDetails.text + " " + (msg.params.exceptionDetails.exception?.description || ""));
    }
  });
  send("Runtime.enable");
  send("Page.enable");
  send("Page.navigate", { url });

  const started = Date.now();
  while (runs.length < RUNS && Date.now() - started < TIMEOUT_MS) await sleep(500);
  const seconds = Math.round((Date.now() - started) / 1000);

  ws.close();
  browser.kill();
  server.close();
  await sleep(800);
  try { rmSync(profile, { recursive: true, force: true }); } catch { /* the browser may still hold it for a moment */ }

  console.log(engineLine);
  console.log(`${runs.length} of ${RUNS} sessions finished in ${seconds} s in headless Chrome`);
  if (problems.length) {
    console.log("Page errors:");
    for (const p of problems.slice(0, 10)) console.log("  " + p);
  }
  const ok = runs.length >= RUNS && problems.length === 0;
  console.log(ok ? "PASSED" : "FAILED");
  process.exit(ok ? 0 : 1);
}

main().catch((err) => { console.error(err); process.exit(1); });
