# ToBeyond

Godot 4.7.2 (GDScript) port of `To_Beyond_Draft.html`; the HTML draft is the source of truth.
For any game work load the `tobeyond-dev` skill (rules, draft↔Godot map, pitfalls, tools).

## Commands
- `tools/parity/setup_godot.sh`: install Godot + Web export templates (fresh container, ~1 min)
- `tools/parity/build.sh --check`: parse every script + headless smoke run (seconds)
- `tools/parity/build.sh`: Web export to `build/web`
- `node tools/parity/parity.js <scenario[,…]> [--fast] [--region=…] [--seq]`: compare with the draft (text report + `build/parity/*.png`)
- `python3 tools/parity/node_tree.py [filter]`: live node tree of `scenes/main.tscn`
- `python3 tools/parity/token_report.py`: token use of this session per request

## Branches and previews
- Work on the session branch; don't push to `main` unless asked.
- Each pushed branch deploys to `https://arm-role.github.io/ToBeyond/preview/<branch>/` (`main` → site root).

## Keep sessions cheap
- One task per session; `/clear` or a new session after pushing.
- Choose the model when the session starts: switching mid-session re-caches the whole context.
- Don't read big files whole (the draft is 155 KB with 15k-char lines): `grep -n`, then `sed -n 'a,bp' | cut -c1-220`.
- Screenshots go to the `parity-checker` agent (`parity-check` skill); the main session reads text reports.

## Compact instructions
Keep: the current task, files changed and why, open differences from the last parity report, what is committed and pushed.
Drop: old tool output, screenshots, superseded plans.
