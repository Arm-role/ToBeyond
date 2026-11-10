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

## Open task
- Splitting `scripts/main.gd`: plan, block status and checks in `docs/refactor-main-split.md` (branch `refactor-main-split`). "Next refactor block" means the first `todo` row there.

## Branches and previews
- Work on the session branch; don't push to `main` unless asked.
- Each pushed branch deploys to `https://arm-role.github.io/ToBeyond/preview/<branch>/` (`main` → site root).

## Keep sessions cheap
- One task per session; `/clear` or a new session after pushing.
- Model roles: the main session runs on Sonnet (project default in `.claude/settings.json`) and does the work; the `advisor` agent (Opus) is consulted at checkpoints; `runner` (Haiku) take repetitive or long-output work. Don't `/model` mid-session: it re-caches the whole context. Delegate to an agent instead.
- Don't read big files whole: `grep -n`, then `sed -n 'a,bp' | cut -c1-220`.
- Screenshots go to the `parity-checker` agent (`parity-check` skill); the main session reads text reports.

## Compact instructions
Keep: the current task, files changed and why, open differences from the last parity report, what is committed and pushed.
Drop: old tool output, screenshots, superseded plans.
