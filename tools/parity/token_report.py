#!/usr/bin/env python3
"""Token use of a Claude Code session, per user request.

    python3 tools/parity/token_report.py [transcript.jsonl]

Default: the newest transcript of this project in ~/.claude/projects/.
Most cost is the context re-read on every turn (cache read), so watch
"turns" and "avg ctx": fewer turns and a smaller context = cheaper.
"""
import glob, json, os, statistics, sys

def find_transcript():
    slug = os.getcwd().replace("/", "-")
    files = glob.glob(os.path.expanduser(f"~/.claude/projects/{slug}/*.jsonl"))
    if not files:
        sys.exit(f"no transcripts in ~/.claude/projects/{slug}/")
    return max(files, key=os.path.getmtime)

path = sys.argv[1] if len(sys.argv) > 1 else find_transcript()
rows = [json.loads(l) for l in open(path, encoding="utf8") if l.strip()]
tasks, cur, ctx_all, model_prev, switches = [], None, [], None, []
for r in rows:
    m = r.get("message") or {}
    if r.get("type") == "user" and isinstance(m.get("content"), str) and not m["content"].startswith("<"):
        cur = {"ask": m["content"].strip().replace("\n", " ")[:34], "turns": 0, "cr": 0, "cw": 0, "out": 0,
               "ctx": [], "builds": 0, "parity": 0, "images": 0, "agents": 0}
        tasks.append(cur)
        continue
    if r.get("type") != "assistant" or cur is None:
        continue
    u = m.get("usage") or {}
    model = m.get("model")
    if model and model != "<synthetic>":
        if model_prev and model != model_prev:
            switches.append(f"{model_prev} -> {model} during \"{cur['ask']}\"")
        model_prev = model
    if u:
        ctx = (u.get("input_tokens") or 0) + (u.get("cache_read_input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0)
        cur["turns"] += 1
        cur["cr"] += u.get("cache_read_input_tokens") or 0
        cur["cw"] += u.get("cache_creation_input_tokens") or 0
        cur["out"] += u.get("output_tokens") or 0
        cur["ctx"].append(ctx)
        ctx_all.append(ctx)
    for c in m.get("content") or []:
        if not isinstance(c, dict) or c.get("type") != "tool_use":
            continue
        inp = c.get("input") or {}
        cmd = inp.get("command", "") if c["name"] == "Bash" else ""
        cur["builds"] += ("build.sh" in cmd and "--check" not in cmd) or "export-release" in cmd
        cur["parity"] += "parity.js" in cmd
        cur["images"] += c["name"] == "Read" and str(inp.get("file_path", "")).lower().endswith((".png", ".jpg", ".jpeg", ".webp"))
        cur["agents"] += c["name"] in ("Agent", "Task")

tot = lambda k: sum(t[k] for t in tasks)
print(f"transcript: {path}")
print(f"turns {tot('turns')} | cache read {tot('cr')/1e6:.1f}M | cache write {tot('cw')/1e6:.2f}M | output {tot('out')/1e3:.0f}k")
if ctx_all:
    print(f"context per turn: min {min(ctx_all)/1e3:.0f}k  median {statistics.median(ctx_all)/1e3:.0f}k  max {max(ctx_all)/1e3:.0f}k")
print(f"\n{'request':36}{'turns':>6}{'avg ctx':>9}{'read':>8}{'write':>8}{'out':>7}{'build':>6}{'parity':>7}{'img':>5}{'agent':>6}")
for t in tasks:
    if not t["turns"]:
        continue
    avg = sum(t["ctx"]) / len(t["ctx"])
    print(f"{t['ask']:36}{t['turns']:>6}{avg/1e3:>8.0f}k{t['cr']/1e6:>7.1f}M{t['cw']/1e3:>7.0f}k{t['out']/1e3:>6.0f}k{t['builds']:>6}{t['parity']:>7}{t['images']:>5}{t['agents']:>6}")
for s in switches:
    print("model switch (re-caches the whole context):", s)
