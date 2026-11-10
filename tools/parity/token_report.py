#!/usr/bin/env python3
"""Token use of a Claude Code session, per user request.

    python3 tools/parity/token_report.py [transcript.jsonl]

Default: the newest transcript of this project in ~/.claude/projects/.
Most cost is the context re-read on every turn (cache read), so watch
"turns" (API calls) and "avg ctx": fewer turns and a smaller context = cheaper.
"""
import glob, json, os, re, statistics, sys

def find_transcript():
    # Claude Code names the folder after the path with every non-alphanumeric
    # character turned into "-" (C:\Arm\Game\ToBeyond -> C--Arm-Game-ToBeyond).
    slug = re.sub(r"[^A-Za-z0-9]", "-", os.getcwd())
    base = os.path.expanduser("~/.claude/projects")
    files = []
    for d in glob.glob(os.path.join(base, "*")):
        if os.path.basename(d).lower() == slug.lower():
            files += glob.glob(os.path.join(d, "*.jsonl"))
    if not files:
        sys.exit(f"no transcripts in {base}/{slug}/")
    return max(files, key=os.path.getmtime)


def user_request(m):
    """Text the user typed, or None for tool results and injected context."""
    c = m.get("content")
    if isinstance(c, str):
        return None if c.startswith("<") else c
    if isinstance(c, list):
        if any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c):
            return None
        for b in c:
            if isinstance(b, dict) and b.get("type") == "text" and not b.get("text", "").lstrip().startswith("<"):
                return b["text"]
    return None

path = sys.argv[1] if len(sys.argv) > 1 else find_transcript()
rows = [json.loads(l) for l in open(path, encoding="utf8") if l.strip()]
tasks, cur, ctx_all, model_prev, switches, seen = [], None, [], None, [], set()
for r in rows:
    m = r.get("message") or {}
    ask = user_request(m) if r.get("type") == "user" and not r.get("isMeta") else None
    if ask:
        cur = {"ask": ask.strip().replace("\n", " ")[:34], "turns": 0, "cr": 0, "cw": 0, "out": 0,
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
    # One API response is written as several lines (thinking, text, tool use)
    # that repeat the same usage: count it once per message id.
    mid = m.get("id")
    if u and mid not in seen:
        seen.add(mid)
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
