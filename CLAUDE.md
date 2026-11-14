# ToBeyond

Godot 4.7.2 (GDScript) game. It started as a port of `To_Beyond_Draft.html`, but the draft is no longer a reference: read or search it only when the user orders it. The Godot code (`scripts/`, `scenes/`, `data/`) is the source of truth.
For any game work load the `tobeyond-dev` skill (rules, draft↔Godot map, pitfalls, tools).

## Commands
- `tools/parity/setup_godot.sh`: install Godot + Web export templates (fresh container, ~1 min)
- `tools/parity/build.sh --check`: parse every script, check skill docs, smoke-run the Domino scene (seconds)
- `tools/parity/build.sh --regress [--update]`: the check, then the Domino regression against `tools/parity/baseline/`
- `tools/parity/build.sh`: Web export to `build/web`
- `node tools/parity/record.js <name> --steps=…`: record the web build while clicking (contact sheet in `build/record/`)
- `python3 tools/parity/token_report.py`: token use of this session per request

## Enforced rules (`tools/hooks/guard.js`, a PreToolUse hook in `.claude/settings.json`)
Only the user can approve the "ask" rules: Claude Code stops and prompts them. Never look for a way around a rule; wait.
- Ask: `git push` to `main` (or any push while on `main`).
- Ask: reading or searching the old HTML draft. Do it only when the user orders it.
- Ask: editing `tools/hooks/` or `.claude/settings*.json`, including shell commands that touch them.
- Block: force push, skipping git hooks or signing, `Read` of a file over 40 KB without `offset`/`limit`.
- `node tools/hooks/test.js` checks all rules (run it after any change to the hook).

## Code layout
Domino Run (the old classic game and its draft-parity tools were removed in phase 6; git history has them).
- `scenes/domino.tscn` (main scene) → `scripts/domino/domino_view.gd`: draws and replays events; reads HP, shield and the row from event fields.
- `scripts/domino/domino_sim.gd`: all rules, no UI, no await. `run_walk()` returns a deterministic event list. Helpers: `domino_rule.gd`, `domino_artifact.gd`, `domino_boss.gd`, `domino_catalog.gd`, `domino_reward.gd`, `domino_shop.gd` (no `class_name`, loaded with `preload`).
- Artifacts and bosses are data: `data/domino/artifacts/*.tres`, `data/domino/bosses/*.tres`.
- Plan, status and per-phase docs: `docs/plan-domino-run.md`, `docs/domino/phase-N.md`; design rule `docs/design-principles.md`. Old plans: `docs/archive/`.
- Logic regression: `tools/parity/build.sh --regress` diffs `domino_regress.gd` against `tools/parity/baseline/domino_regress.txt` (thousands of lines: grep it, never read it whole). Run it after any change to the sim, artifacts or bosses. After an *intended* change run `--regress --update` and commit the baseline diff.
- Every playable screen shows the version stamp bottom-right (`_add_version_stamp`).

## Branches and previews
- Work on the session branch; don't push to `main` unless asked.
- Version: every push that changes more than `.md` files bumps `application/config/version` in `project.godot` (shown bottom-right with the commit): patch +1 per push (0.1.0 → 0.1.1), once per push, not per commit; minor/major only when the user says. Edit only that line. User rule (2026-11).
- Each pushed branch deploys to `https://arm-role.github.io/ToBeyond/preview/<branch>/` (`main` → site root).

## Keep sessions cheap
- One task per session; `/clear` or a new session after pushing.
- Model roles (Sonnet main, `advisor`, `runner`) and the big-file reading rule: `tobeyond-dev` skill. Don't `/model` mid-session: it re-caches the whole context; delegate to an agent instead.
- Look at screenshots only when pixels matter; prefer text reports (regress lines, `record.js` text timeline).

## Compact instructions
Keep: the current task, files changed and why, open problems from the last check, what is committed and pushed.
Drop: old tool output, screenshots, superseded plans.
