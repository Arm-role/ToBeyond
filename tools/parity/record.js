#!/usr/bin/env node
// Record the Godot web build while a scripted input sequence runs, then write a
// contact sheet of the frames after the last click, so animation timing / game
// feel can be judged without the draft.
//
//   node tools/parity/record.js <scenario> --steps="386,600;458,600;530,600;w150;477,678"
//        [--region=x,y,w,h] [--fps=25] [--after=1500] [--cols=4] [--name=out]
//
// <scenario>  only names the output (the Domino scene has no ?dbg= states; add `?arts=a,b` to the URL in this file to test artifacts)
// --steps     ";"-separated: "x,y" = click (CSS px of the 1280×720 page),
//             "wN" = wait N ms. A 200 ms wait follows every click.
// --region    crop of the sheet (default: whole page). Handy: board+hand
//             = 90,350,1100,330
// --after     ms to record after the last step (default 1500)
// Needs build/web (tools/parity/build.sh). Output: build/record/<name>.png
// and a text timeline: cell i = i/fps s after the last click (video clock is
// ±100 ms). Swiftshader renders ~15 fps, so use --fps=25 at most.
const http = require('http'), fs = require('fs'), path = require('path');
const { spawnSync } = require('child_process');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '../..');
const WEB = path.join(ROOT, 'build/web');
const argv = process.argv.slice(2);
const opt = (k, d) => { const a = argv.find(x => x.startsWith('--' + k + '=')); return a ? a.slice(k.length + 3) : d; };
const scenario = argv.find(a => !a.startsWith('--')) || 'main';
const steps = opt('steps', '').split(';').filter(Boolean);
const fps = +opt('fps', 25), after = +opt('after', 1500), cols = +opt('cols', 4);
const region = opt('region', '');
const name = opt('name', scenario);
const OUT = path.join(ROOT, 'build/record');
const sleep = ms => new Promise(r => setTimeout(r, ms));
if (!fs.existsSync(path.join(WEB, 'index.html'))) { console.error('build/web missing: run tools/parity/build.sh'); process.exit(2); }
fs.mkdirSync(OUT, { recursive: true });
const TMP = fs.mkdtempSync(path.join(require('os').tmpdir(), 'tbrec-'));

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' };
const server = http.createServer((q, r) => {
  const f = path.join(WEB, decodeURIComponent(q.url.split('?')[0]).replace(/\/$/, '/index.html'));
  fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); return r.end(); } r.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' }); r.end(d); });
});

server.listen(0, '127.0.0.1', async () => {
  const errs = [];
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 720 }, recordVideo: { dir: path.join(TMP, 'vid'), size: { width: 1280, height: 720 } } });
  const t0 = Date.now();
  const page = await ctx.newPage();
  page.on('console', m => { if (/SCRIPT ERROR|^ERROR/.test(m.text())) errs.push(m.text().slice(0, 300)); });
  page.on('pageerror', e => errs.push(e.message));
  await page.goto(`http://127.0.0.1:${server.address().port}/index.html`);
  await page.waitForFunction(n => window.tbReady === n, scenario, { timeout: 120000 });
  await sleep(800);
  const log = [];
  let last = Date.now();
  for (const s of steps) {
    if (/^w\d+$/.test(s)) { await sleep(+s.slice(1)); log.push(['wait', s]); continue; }
    const [x, y] = s.split(',').map(Number);
    last = Date.now();
    await page.mouse.click(x, y);
    log.push(['click', s, last - t0]);
    await sleep(200);
  }
  await sleep(after);
  await ctx.close();
  await browser.close();
  server.close();

  const vid = fs.readdirSync(path.join(TMP, 'vid')).map(f => path.join(TMP, 'vid', f))[0];
  const start = Math.max((last - t0) / 1000 - 0.15, 0);
  // crop=w:h:x:y from region x,y,w,h
  const [rx, ry, rw, rh] = region ? region.split(',').map(Number) : [0, 0, 0, 0];
  const vf = [`fps=${fps}`, region ? `crop=${rw}:${rh}:${rx}:${ry}` : null].filter(Boolean).join(',');
  const frames = path.join(TMP, 'f_%03d.png');
  let r = spawnSync('ffmpeg', ['-loglevel', 'error', '-ss', String(start), '-i', vid, '-t', String((after + 600) / 1000 + 0.3), '-vf', vf, frames]);
  if (r.status !== 0) { console.error(String(r.stderr)); process.exit(1); }
  const n = fs.readdirSync(TMP).filter(f => f.startsWith('f_')).length;
  const out = path.join(OUT, name + '.png');
  r = spawnSync('ffmpeg', ['-loglevel', 'error', '-y', '-framerate', '1', '-i', frames, '-vf', `scale=iw*${region ? 0.5 : 0.4}:-1,tile=${cols}x${Math.ceil(n / cols)}`, '-frames:v', '1', out]);
  if (r.status !== 0) { console.error(String(r.stderr)); process.exit(1); }
  console.log(`scenario ${scenario}: ${n} frames @ ${fps} fps -> ${path.relative(ROOT, out)}`);
  console.log('steps:', log.map(l => l.slice(0, 2).join(' ')).join(' | '));
  console.log(`sheet cells read left→right, top→bottom; cell i ≈ ${(1000 / fps).toFixed(0)}·i ms after (last click − 150 ms)`);
  console.log(errs.length ? 'Godot errors:\n  ' + errs.join('\n  ') : 'Godot errors: none');
  fs.rmSync(TMP, { recursive: true, force: true });
  process.exit(0);
});
