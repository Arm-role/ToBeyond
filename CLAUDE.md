# ToBeyond

Godot 4.7.2 (GDScript) game. It started as a port of `To_Beyond_Draft.html`, but the draft is no longer a reference: read or search it only when the user orders it. The Godot code (`scripts/`, `scenes/`, `data/`) is the source of truth.
For any game work load the `tobeyond-dev` skill (rules, draft↔Godot map, pitfalls, tools).

## Commands
- `tools/parity/setup_godot.sh`: install Godot + Web export templates (fresh container, ~1 min)
- `tools/parity/build.sh --check`: parse every script + headless smoke run (seconds)
- `tools/parity/build.sh`: Web export to `build/web`
- `node tools/parity/parity.js <scenario[,…]> [--fast] [--region=…] [--seq]`: compare with the draft (text report + `build/parity/*.png`)
- `python3 tools/parity/node_tree.py [filter]`: live node tree of `scenes/main.tscn`
- `python3 tools/parity/token_report.py`: token use of this session per request

## Enforced rules (`tools/hooks/guard.js`, a PreToolUse hook in `.claude/settings.json`)
Only the user can approve the "ask" rules: Claude Code stops and prompts them. Never look for a way around a rule; wait.
- Ask: `git push` to `main` (or any push while on `main`).
- Ask: reading or searching the old HTML draft. Do it only when the user orders it.
- Ask: editing `tools/hooks/` or `.claude/settings*.json`, including shell commands that touch them.
- Block: force push, skipping git hooks or signing, `Read` of a file over 40 KB without `offset`/`limit`.
- `node tools/hooks/test.js` checks all rules (run it after any change to the hook).

## Code layout (after the main.gd split, done)
- `scripts/main.gd`: node refs, state, `_ready`, new game / round / hand flow; one-line wrappers to the classes below. Plan and history: `docs/refactor-main-split.md`.
- Split classes (each holds `_main`): `BoardCalc`, `ToolbarControls`, `ActionDialog`, `SlotDrag`, `BoardInput`, `RewardFlow`, plus the managers (`BattleManager`, `ShopManager`, `UiRenderer`, `ArtifactSystem`).
- Greybox: `?mode=greybox` opens the Domino Run prototype (`scenes/greybox.tscn`). Plan, status and per-phase docs: `docs/plan-domino-run.md` + `docs/domino/phase-N.md` (read these first for any Domino work); the main game is untouched.
- Artifacts are data: `data/artifacts/*.tres`. Stone and Chaos were removed (`docs/plan-gem-types.md`).
- Logic regression: `tools/parity/build.sh --regress` diffs `artifact_regress.gd` against `tools/parity/baseline/`. Run it after any change to artifacts, walk or damage code. After an *intended* number change run `--regress --update` and commit the baseline diff.

## Branches and previews
- Work on the session branch; don't push to `main` unless asked.
- Version: every push that changes more than `.md` files bumps `application/config/version` in `project.godot` (shown bottom-right with the commit): patch +1 per push (0.1.0 → 0.1.1), once per push, not per commit; minor/major only when the user says. Edit only that line. User rule (2026-11).
- Each pushed branch deploys to `https://arm-role.github.io/ToBeyond/preview/<branch>/` (`main` → site root).

## Keep sessions cheap
- One task per session; `/clear` or a new session after pushing.
- Model roles (Sonnet main, `advisor`, `runner`) and the big-file reading rule: `tobeyond-dev` skill. Don't `/model` mid-session: it re-caches the whole context; delegate to an agent instead.
- Screenshots go to the `parity-checker` agent (`parity-check` skill); the main session reads text reports.

## Compact instructions
Keep: the current task, files changed and why, open differences from the last parity report, what is committed and pushed.
Drop: old tool output, screenshots, superseded plans.
