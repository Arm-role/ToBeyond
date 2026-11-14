#!/usr/bin/env node
// Compare the Godot web build with To_Beyond_Draft.html in the same test state.
// Prints a short text table of what differs and saves build/parity/<scenario>.png
// (draft on top, Godot below).
//
//   node tools/parity/parity.js <scenario[,scenario...]> [options]
//     --region=top,board,bottom|screen|center|x,y,w,h  crop; one full-resolution image per region
//     --seq[=frames]   attack sequence: frames + calc text timeline (default 12)
//     --fast           Godot numbers from a headless run of the sources (no build, no Godot image)
//     --all            print every compared element, not just the ones that differ
//     --no-shot        numbers only
// Scenarios live in tools/parity/scenarios.js (Godot side: scripts/debug_scenarios.gd).
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), os = require('os'), path = require('path');
const { spawnSync } = require('child_process');
const { SCENARIOS, REGIONS, SEQ_CLICKS } = require('./scenarios.js');

const ROOT = path.resolve(__dirname, '../..');
const WEB = path.join(ROOT, 'build/web'), OUT = path.join(ROOT, 'build/parity');
const DRAFT = 'file://' + path.join(ROOT, 'To_Beyond_Draft.html');
const TOL = 4; // px
const argv = process.argv.slice(2);
const opt = k => { const a = argv.find(x => x === '--' + k || x.startsWith('--' + k + '=')); return a === undefined ? null : (a.includes('=') ? a.slice(a.indexOf('=') + 1) : true); };
const names = (argv.find(a => !a.startsWith('--')) || 'main').split(',');
const FAST = !!opt('fast'), ALL = !!opt('all'), SHOT = !opt('no-shot') && !FAST;
const SEQ = opt('seq') ? (opt('seq') === true ? 12 : +opt('seq')) : 0;
const regionArg = opt('region') || (SEQ ? 'top' : null);
// Regions: named (top, board, bottom, center; "screen" = top,board,bottom) or "x,y,w,h".
// Each region is saved at full resolution, so small details stay visible.
const CLIPS = (() => {
  if (!regionArg) return [null];
  const t = String(regionArg).split(',');
  if (t.length === 4 && t.every(x => /^\d+$/.test(x))) return [{ label: t.join('-'), clip: { x: +t[0], y: +t[1], width: +t[2], height: +t[3] } }];
  return t.flatMap(n => (n === 'screen' ? ['top', 'board', 'bottom'] : [n])).map(n => {
    const r = REGIONS[n];
    if (!r) { console.error(`unknown region "${n}". Have: ${Object.keys(REGIONS).join(', ')}, screen, or x,y,w,h`); process.exit(2); }
    return { label: n, clip: { x: r[0], y: r[1], width: r[2], height: r[3] } };
  });
})();
const CLIP = CLIPS[0] && CLIPS[0].clip; // used by --seq frames
const sleep = ms => new Promise(r => setTimeout(r, ms));

for (const n of names) if (!SCENARIOS[n]) { console.error(`unknown scenario "${n}". Have: ${Object.keys(SCENARIOS).join(', ')}`); process.exit(2); }
if (!FAST) {
  const pck = path.join(WEB, 'index.pck');
  if (!fs.existsSync(pck)) { console.error('no build/web — run tools/parity/build.sh (or use --fast)'); process.exit(2); }
  const built = fs.statSync(pck).mtimeMs;
  const stale = ['scripts', 'scenes'].flatMap(d => fs.readdirSync(path.join(ROOT, d)).map(f => path.join(ROOT, d, f))).filter(f => fs.statSync(f).mtimeMs > built);
  if (stale.length) console.log(`WARNING build is older than ${stale.length} source file(s) (${path.basename(stale[0])}…) — run tools/parity/build.sh`);
}

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' };
const serve = () => new Promise(res => {
  const s = http.createServer((q, r) => {
    const f = path.join(WEB, decodeURIComponent(q.url.split('?')[0]).replace(/\/$/, '/index.html'));
    fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); return r.end(); } r.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' }); r.end(d); });
  });
  s.listen(0, '127.0.0.1', () => res(s));
});

const isList = spec => Array.isArray(spec) || String(spec).endsWith('/*');
const godotPaths = els => [...new Set(Object.values(els).flatMap(([, g]) => (Array.isArray(g) ? g : [g])))];
function godotShape(els, raw) {
  const out = {};
  for (const [name, [, g]] of Object.entries(els)) out[name] = Array.isArray(g) ? g.map(p => raw[p]) : (raw[g] === undefined ? null : raw[g]);
  return out;
}
async function draftInfo(page, els) {
  const lists = Object.fromEntries(Object.entries(els).map(([n, [, g]]) => [n, isList(g)]));
  return page.evaluate(([els, lists]) => {
    const hex = c => { const m = c.match(/[\d.]+/g); return m ? '#' + m.slice(0, 3).map(v => Math.round(+v).toString(16).padStart(2, '0')).join('') : c; };
    const info = e => {
      const b = e.getBoundingClientRect(), cs = getComputedStyle(e), text = (e.innerText || '').trim();
      const d = { x: Math.round(b.x), y: Math.round(b.y), w: Math.round(b.width), h: Math.round(b.height), vis: b.width > 0 && b.height > 0 && cs.visibility !== 'hidden' && +cs.opacity > 0, text: text.slice(0, 60), fs: parseFloat(cs.fontSize), color: hex(cs.color), ff: cs.fontFamily, leaf: e.children.length === 0 };
      if (text) { const r = document.createRange(); r.selectNodeContents(e); const t = r.getBoundingClientRect(); if (t.width > 0) d.tb = [t.x, t.y, t.width, t.height].map(Math.round); }
      return d;
    };
    const out = {};
    for (const [name, [sel]] of Object.entries(els)) { const all = [...document.querySelectorAll(sel)]; out[name] = lists[name] ? all.map(info) : (all[0] ? info(all[0]) : null); }
    return out;
  }, [els, lists]);
}
async function godotWebInfo(page, els) {
  const raw = await page.evaluate(paths => { window.tbRectsOut = null; window.tbRects(JSON.stringify(paths)); return window.tbRectsOut; }, godotPaths(els));
  return godotShape(els, JSON.parse(raw));
}
function godotHeadlessInfo(name, els) {
  const tmp = path.join(os.tmpdir(), `tb_rects_${process.pid}.json`);
  fs.writeFileSync(tmp, JSON.stringify(godotPaths(els)));
  const r = spawnSync(process.env.GODOT || 'godot', ['--headless', '--path', ROOT, '--', '--mode=classic', `--dbg=${name}`, `--rects=${tmp}`], { encoding: 'utf8', timeout: 60000 });
  const out = (r.stdout || '') + (r.stderr || '');
  const errs = out.split('\n').filter(l => /SCRIPT ERROR|Parse Error|^ERROR/.test(l));
  const line = out.split('\n').find(l => l.startsWith('TB_RECTS '));
  if (!line) { console.log(`godot headless run failed for ${name}:\n` + out.split('\n').slice(-15).join('\n')); return { info: null, errs }; }
  return { info: godotShape(els, JSON.parse(line.slice(9))), errs };
}

const norm = t => String(t || '').replace(/\[[^\]]*\]/g, '').replace(/\s+/g, '').toLowerCase();
const cdist = (a, b) => { const p = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)); try { const x = p(a), y = p(b); return Math.max(...x.map((v, i) => Math.abs(v - y[i]))); } catch { return 0; } };
const EMOJI = /^[\p{Extended_Pictographic}\uFE0F\u200D\s]+$/u;
function diffRow(d, g) {
  const out = [];
  if (!d || !g) return [!d ? 'missing in draft' : 'missing in Godot'];
  if (!d.vis && !g.vis) return out;
  if (d.vis !== g.vis) return [`visible html=${d.vis} godot=${g.vis}`];
  // Labels: compare where the text is drawn (Godot label boxes are often full width):
  // centre within TOL, width within max(6px, 8%). Line heights differ by design, so no height.
  if (/Label/.test(g.type) && d.tb && g.tb) {
    const [dx, dy, dw, dh] = d.tb, [gx, gy, gw, gh] = g.tb, emoji = EMOJI.test(d.text);
    const cx = Math.round(gx + gw / 2 - dx - dw / 2), cy = Math.round(gy + gh / 2 - dy - dh / 2), w = gw - dw;
    const bad = [];
    if (Math.abs(cx) > TOL) bad.push(`dx=${cx > 0 ? '+' : ''}${cx}`);
    if (Math.abs(cy) > TOL) bad.push(`dy=${cy > 0 ? '+' : ''}${cy}`);
    if (!emoji && Math.abs(w) > Math.max(6, 0.08 * dw)) bad.push(`dw=${w > 0 ? '+' : ''}${w}`);
    if (bad.length) out.push('text centre ' + bad.join(' '));
  } else {
    const a = [d.x, d.y, d.w, d.h], b = [g.x, g.y, g.w, g.h];
    const dl = ['x', 'y', 'w', 'h'].map((k, i) => [k, b[i] - a[i]]).filter(([, v]) => Math.abs(v) > TOL);
    if (dl.length) out.push(dl.map(([k, v]) => `d${k}=${v > 0 ? '+' : ''}${v}`).join(' '));
  }
  if (d.leaf && g.leaf && d.text && g.text && !EMOJI.test(d.text)) {
    if (Math.abs(g.fs - d.fs) > 1) out.push(`font ${d.fs}/${g.fs}px`);
    if (cdist(d.color, g.color) > 40) out.push(`colour ${d.color}/${g.color}`);
  }
  // Serif vs sans-serif (the draft uses Georgia / Noto Serif Thai for names and titles).
  const fam = String(d.ff || '').split(',')[0].replace(/"/g, '').trim();
  if (g.leaf && g.font && d.text && g.text && (/georgia|times|serif/i.test(fam) && !/sans/i.test(fam)) !== (/serif/i.test(g.font) && !/sans/i.test(g.font))) out.push(`font family "${fam}" / "${g.font}"`);
  const textNode = /Label|Button/.test(g.type) && !(g.icon && !g.text);
  if (textNode && (d.text || g.text) && norm(d.text) !== norm(g.text)) out.push(`text "${(d.text || '').replace(/\n/g, '⏎').slice(0, 34)}" / "${(g.text || '').replace(/\n/g, '⏎').slice(0, 34)}"`);
  return out;
}
function report(name, els, D, G) {
  const lines = []; let compared = 0, differ = 0;
  const box = (r, g) => (!r ? '-' : r.tb && g && /Label/.test(g.type) ? `${r.tb[0]},${r.tb[1]} ${r.tb[2]}x${r.tb[3]}` : `${r.x},${r.y} ${r.w}x${r.h}`);
  for (const n of Object.keys(els)) {
    const d = D[n], g = G[n];
    if (Array.isArray(d) || Array.isArray(g)) {
      const dn = (d || []).length, gn = (g || []).filter(Boolean).length;
      if (dn !== gn) { lines.push(`  ${n}: count html=${dn} godot=${gn}`); differ++; }
      for (let i = 0; i < Math.min(dn, gn); i++) {
        compared++; const r = diffRow(d[i], g[i]);
        if (r.length) differ++;
        if (r.length || ALL) lines.push(`  ${n}[${i}]  html ${box(d[i], g[i])}  ${r.join(' | ') || 'ok'}`);
      }
    } else {
      compared++; const r = diffRow(d, g);
      if (r.length) differ++;
      if (r.length || ALL) lines.push(`  ${n}  html ${box(d, g)}  ${r.join(' | ') || 'ok'}`);
    }
  }
  console.log(`== ${name}: ${compared} compared, ${differ} differ (tolerance ${TOL}px; Godot minus draft) ==`);
  console.log(lines.join('\n') || '  all match');
}
async function stack(browser, rows, file, w = 1280) {
  // rows: [[{label, buf}], ...] — each row's images side by side.
  const html = '<body style="margin:0;background:#000">' + rows.map(row => '<div style="display:flex">' + row.map(c => `<div style="position:relative;line-height:0;flex:1"><img style="width:100%" src="data:image/png;base64,${c.buf.toString('base64')}"><b style="position:absolute;left:4px;top:4px;background:#000b;color:#fff;font:bold 14px sans-serif;line-height:18px;padding:0 5px">${c.label}</b></div>`).join('') + '</div>').join('') + '</body>';
  const p = await browser.newPage({ viewport: { width: rows[0].length > 1 ? Math.min(1280, w * rows[0].length) : w, height: 200 } });
  await p.setContent(html); await p.evaluate(() => Promise.all([...document.images].map(i => i.decode())));
  await p.screenshot({ path: file, fullPage: true }); await p.close();
}
// --seq: pass 1 logs every change of the damage formula (polled every 40 ms),
// pass 2 (unless --no-shot) replays the attack and takes frames.
const CALC = 'Preview/CalcLabel', LOG_SECONDS = 7;
async function attack(page) { for (const [x, y, wait] of SEQ_CLICKS) { await page.mouse.click(x, y); if (wait) await sleep(wait); } }
async function calcLog(page, readCalc) {
  await attack(page);
  const log = [], t0 = Date.now();
  while (Date.now() - t0 < LOG_SECONDS * 1000) {
    const v = norm(await readCalc());
    if (!log.length || log[log.length - 1][1] !== v) log.push([((Date.now() - t0) / 1000).toFixed(2), v]);
    await sleep(40);
  }
  return log.map(([t, v]) => `${t} ${v}`).join(' · ');
}
async function frames(page) {
  await attack(page);
  const out = [], t0 = Date.now();
  for (let i = 0; i < SEQ; i++) { out.push({ t: (Date.now() - t0) / 1000, buf: await page.screenshot(CLIP ? { clip: CLIP } : {}) }); await sleep(300); }
  return out;
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const server = FAST ? null : await serve();
  const gErrs = [];
  const draft = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  draft.on('pageerror', e => gErrs.push('draft: ' + e.message));
  let godot = null;
  for (const [i, name] of names.entries()) {
    const sc = SCENARIOS[name];
    await draft.goto(DRAFT); await sleep(800);
    await draft.evaluate(sc.draft); await sleep(sc.wait || 700);
    const D = await draftInfo(draft, sc.els);
    let G;
    if (FAST) {
      const r = godotHeadlessInfo(name, sc.els); gErrs.push(...r.errs); G = r.info;
      if (!G) continue;
    } else {
      if (!godot) {
        godot = await browser.newPage({ viewport: { width: 1280, height: 720 } });
        godot.on('console', m => { if ((/error|warning/i.test(m.type()) || /SCRIPT ERROR|^ERROR/.test(m.text())) && !/GL Driver Message|GPU stall/.test(m.text())) gErrs.push('godot: ' + m.text().slice(0, 300)); });
        godot.on('pageerror', e => gErrs.push('godot: ' + e.message));
        await godot.goto(`http://127.0.0.1:${server.address().port}/index.html?mode=classic&dbg=${name}`);
      } else {
        await godot.evaluate(n => { window.tbReady = ''; window.tbRun(n); }, name);
      }
      await godot.waitForFunction(n => window.tbReady === n, name, { timeout: 120000 });
      G = await godotWebInfo(godot, sc.els);
    }
    report(name, sc.els, D, G);
    if (SHOT && !SEQ) {
      for (const R of CLIPS) {
        const so = R ? { clip: R.clip } : {};
        const file = path.join(OUT, `${name}${R ? '_' + R.label : ''}.png`);
        await stack(browser, [[{ label: 'HTML draft', buf: await draft.screenshot(so) }], [{ label: 'Godot', buf: await godot.screenshot(so) }]], file, R ? R.clip.width : 1280);
        console.log(`image: ${path.relative(ROOT, file)}`);
      }
    }
    if (SEQ && !FAST) {
      const draftReset = async () => { await draft.goto(DRAFT); await sleep(800); await draft.evaluate(sc.draft); await sleep(sc.wait || 700); };
      const godotReset = async () => { await godot.evaluate(n => { window.tbReady = ''; window.tbRun(n); }, name); await godot.waitForFunction(n => window.tbReady === n, name, { timeout: 60000 }); };
      const readD = () => draft.evaluate(() => (document.querySelector('#calc') || {}).innerText || '');
      const readG = () => godot.evaluate(p => { window.tbRects(JSON.stringify([p])); return (JSON.parse(window.tbRectsOut)[p] || {}).text || ''; }, CALC);
      await draftReset(); const ld = await calcLog(draft, readD);
      await godotReset(); const lg = await calcLog(godot, readG);
      console.log(`  formula changes, seconds after the attack click:\n   html : ${ld}\n   godot: ${lg}`);
      if (SHOT) {
        await draftReset(); const df = await frames(draft);
        await godotReset(); const gf = await frames(godot);
        const file = path.join(OUT, `${name}_seq.png`);
        await stack(browser, df.map((f, k) => [{ label: `html ${f.t.toFixed(1)}s`, buf: f.buf }, { label: `godot ${gf[k].t.toFixed(1)}s`, buf: gf[k].buf }]), file, CLIP ? CLIP.width : 1280);
        console.log(`image: ${path.relative(ROOT, file)} (frames are ~0.3 s apart on the draft, slower on Godot: compare by the time labels)`);
      }
    }
  }
  const uniq = [...new Set(gErrs)];
  console.log(uniq.length ? `errors (${uniq.length}):\n  ` + uniq.slice(0, 10).join('\n  ') : 'errors: none');
  await browser.close(); if (server) server.close();
  process.exit(uniq.some(e => /SCRIPT ERROR|Parse Error/.test(e)) ? 1 : 0);
})().catch(e => { console.error(e.message); process.exit(1); });
