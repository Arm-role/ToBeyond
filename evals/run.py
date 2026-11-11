#!/usr/bin/env python3
"""Eval tasks for the ToBeyond agent setup (skill, agents, hooks).

A task replays a real past change: the agent starts from the parent commit and gets the prompt;
`checks` (shell commands run in the work tree) say whether it succeeded. This script never runs an
agent: it prepares trees and judges the result, so it costs no tokens.

  evals/run.py list
  evals/run.py validate [id]        checks must FAIL at the base commit and PASS at the source commit
                                    (proves the task is fair; run after adding or editing a task)
  evals/run.py setup <id>           work tree build/evals/<id> at the base commit, with the CURRENT
                                    .claude/, CLAUDE.md and tools/ laid over it (so the current skill is what is tested)
  evals/run.py check <id> [dir]     run the checks in dir (default build/evals/<id>)
  evals/run.py record <id> <dir> <turns> <tokens> [note]
                                    after a run: check, then append one row to evals/results.tsv
"""
import datetime
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TASKS = os.path.join(ROOT, "evals", "tasks")
WORK = os.path.join(ROOT, "build", "evals")
RESULTS = os.path.join(ROOT, "evals", "results.tsv")


def sh(cmd, cwd, quiet=True):
    r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=quiet, text=True)
    return r.returncode, ((r.stdout or "") + (r.stderr or "")).strip()


def load(tid):
    with open(os.path.join(TASKS, tid + ".json"), encoding="utf-8") as f:
        return json.load(f)


def ids():
    return sorted(f[:-5] for f in os.listdir(TASKS) if f.endswith(".json"))


def worktree(tid, rev, name):
    d = os.path.join(WORK, name)
    if os.path.exists(d):
        sh(f"git worktree remove --force '{d}'", ROOT)
        shutil.rmtree(d, ignore_errors=True)
    os.makedirs(WORK, exist_ok=True)
    rc, out = sh(f"git worktree add --detach '{d}' {rev}", ROOT)
    if rc:
        sys.exit(f"git worktree failed: {out}")
    rc, out = sh("godot --headless --path . --import", d)  # class_name cache; a fresh tree has none
    return d


def run_checks(task, d):
    results = []
    for c in task["checks"]:
        rc, out = sh("TB_SKIP_REFS=1 " + c if c.startswith("tools/parity/build.sh") else c, d)
        results.append((c, rc == 0, out))
    return results


def verdict(results):
    return all(ok for _, ok, _ in results)


def cmd_validate(only):
    bad = 0
    for tid in [only] if only else ids():
        t = load(tid)
        base = run_checks(t, worktree(tid, t["base"], tid + "-base"))
        src = run_checks(t, worktree(tid, t["source"], tid + "-source"))
        base_fail, src_pass = not verdict(base), verdict(src)
        print(f"{tid}: fails at base={base_fail}  passes at source={src_pass}")
        if not src_pass:
            for c, ok, out in src:
                if not ok:
                    print(f"   source FAIL: {c}\n   {out[:300]}")
        bad += (not base_fail) + (not src_pass)
        for n in (tid + "-base", tid + "-source"):
            sh(f"git worktree remove --force '{os.path.join(WORK, n)}'", ROOT)
    print("validate OK" if not bad else f"validate FAILED ({bad} problem(s))")
    return 1 if bad else 0


def cmd_setup(tid):
    t = load(tid)
    d = worktree(tid, t["base"], tid)
    for p in (".claude", "CLAUDE.md", "tools"):
        sh(f"git -C '{ROOT}' archive HEAD {p} | tar -x -C '{d}'", ROOT)
    print("note: the current map.md describes the current code, so run `build.sh --check` with TB_SKIP_REFS=1 here")
    print(f"work tree: {d}\nbase: {t['base']}  (source change: {t['source']})\n\nPROMPT:\n{t['prompt']}")
    return 0


def cmd_check(tid, d=None):
    t = load(tid)
    d = d or os.path.join(WORK, tid)
    res = run_checks(t, d)
    for c, ok, out in res:
        print(("PASS " if ok else "FAIL ") + c + ("" if ok else "\n     " + out[:300]))
    print("RESULT:", "PASS" if verdict(res) else "FAIL")
    return 0 if verdict(res) else 1


def cmd_record(tid, d, turns, tokens, note=""):
    t = load(tid)
    res = run_checks(t, d)
    head = sh("git rev-parse --short HEAD", ROOT)[1]
    new = not os.path.exists(RESULTS)
    with open(RESULTS, "a", encoding="utf-8") as f:
        if new:
            f.write("date\tsetup_commit\ttask\tresult\tturns\ttokens\tnote\n")
        f.write(f"{datetime.date.today()}\t{head}\t{tid}\t{'PASS' if verdict(res) else 'FAIL'}\t{turns}\t{tokens}\t{note}\n")
    print(open(RESULTS, encoding="utf-8").read().splitlines()[-1])
    return 0


def main(a):
    if not a or a[0] == "list":
        for tid in ids():
            t = load(tid)
            print(f"{tid:16} {t['kind']:9} {t['source']}  {t['prompt'][:70]}")
        return 0
    c = a[0]
    if c == "validate":
        return cmd_validate(a[1] if len(a) > 1 else None)
    if c == "setup" and len(a) > 1:
        return cmd_setup(a[1])
    if c == "check" and len(a) > 1:
        return cmd_check(a[1], a[2] if len(a) > 2 else None)
    if c == "record" and len(a) > 4:
        return cmd_record(*a[1:7])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
