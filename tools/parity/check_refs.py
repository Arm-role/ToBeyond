#!/usr/bin/env python3
"""Fail when the skill docs point at code that no longer exists.

Checks, in .claude/skills/tobeyond-dev/SKILL.md and reference/map.md (text before the
"Appendix" heading only):
  1. `file.gd: name name …`  every name must be a func/const/var/signal/enum defined in that file
                             (a trailing * is a prefix wildcard; "(args)" after a name is ignored)
  2. `scripts/…` `data/…` `tools/…` `scenes/…` paths must exist (globs allowed)
Usage: python3 tools/parity/check_refs.py     exit 0 = ok, 1 = stale references (listed)
"""
import glob
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOCS = [
    ".claude/skills/tobeyond-dev/SKILL.md",
    ".claude/skills/tobeyond-dev/reference/map.md",
]
DEF_RE = re.compile(
    r"^\s*(?:@export\s+|@onready\s+|static\s+)*"
    r"(?:func|const|var|signal|enum|class)\s+(\w+)", re.M)


def defs_of(stem):
    paths = glob.glob(os.path.join(ROOT, "scripts", "**", stem + ".gd"), recursive=True)
    if not paths:
        return None
    names = set()
    for p in paths:
        with open(p, encoding="utf-8") as f:
            names |= set(DEF_RE.findall(f.read()))
    return names


def main():
    bad = []
    cache = {}
    for doc in DOCS:
        path = os.path.join(ROOT, doc)
        if not os.path.exists(path):
            bad.append(f"{doc}: file missing")
            continue
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
        for i, line in enumerate(lines, 1):
            if line.startswith("## Appendix"):
                break
            for span in re.findall(r"`([^`]+)`", line):
                m = re.match(r"^(\w+)\.gd:\s*(.+)$", span)
                if m:
                    stem, rest = m.groups()
                    if stem not in cache:
                        cache[stem] = defs_of(stem)
                    names = cache[stem]
                    if names is None:
                        bad.append(f"{doc}:{i}: scripts/**/{stem}.gd does not exist")
                        continue
                    for tok in rest.split():
                        tok = re.sub(r"\(.*$", "", tok)
                        if not tok:
                            continue
                        if tok.endswith("*"):
                            ok = any(n.startswith(tok[:-1]) for n in names)
                        else:
                            ok = tok in names
                        if not ok:
                            bad.append(f"{doc}:{i}: {stem}.gd has no `{tok}`")
                elif re.match(r"^(scripts|data|tools|scenes)/", span) and " " not in span:
                    pat = re.sub(r"<[^>]*>", "*", span)
                    if not glob.glob(os.path.join(ROOT, pat)):
                        bad.append(f"{doc}:{i}: path `{span}` does not exist")
    if bad:
        print("\n".join(bad[:30]))
        print(f"check_refs FAILED ({len(bad)} stale reference(s)); fix the doc or the name")
        return 1
    print("check_refs OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
