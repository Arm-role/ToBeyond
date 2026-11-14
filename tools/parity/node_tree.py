#!/usr/bin/env python3
"""Print the current node tree of scenes/domino.tscn (and the @onready vars that
point into it), so nobody has to read the .tscn or trust a stale doc.

    python3 tools/parity/node_tree.py            # tree, plain text
    python3 tools/parity/node_tree.py Shop       # only paths containing "Shop"
"""
import glob, re, sys, os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
tscn = open("scenes/domino.tscn", encoding="utf8").read()
nodes = []
for m in re.finditer(r'\[node name="([^"]+)"(?: type="([^"]+)")?(?: parent="([^"]+)")?(?: instance=[^\]]*)?\]', tscn):
    name, typ, parent = m.groups()
    path = "." if parent is None else (name if parent == "." else f"{parent}/{name}")
    nodes.append((path, name, typ or "instance"))
args = [a for a in sys.argv[1:] if not a.startswith("--")]

def tree_lines():
    out = []
    for path, name, typ in nodes:
        if path == ".":
            out.append(f"Main ({typ})")
            continue
        if args and not any(a.lower() in path.lower() for a in args):
            continue
        depth = path.count("/") + 1
        out.append(f"{'  ' * depth}{name} ({typ})  ${path}")
    return out

onready = []
for f in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
    for m in re.finditer(r'@onready var (\w+)(?:\s*:\s*([\w\[\]]+))?\s*=\s*\$("?)([\w/]+)\3', open(f, encoding="utf8").read()):
        onready.append((m.group(1), m.group(4), m.group(2) or "", os.path.basename(f)))

print("\n".join(tree_lines()))
