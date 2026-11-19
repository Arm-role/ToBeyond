# ToBeyond development workflow

Read `run/main_scene` in `project.godot` and follow the active scene's script. In the classic game, start with `main.gd` and follow its controllers and managers. In Domino Run, follow the view for UI and playback and the simulation for deterministic rules.

Use the Godot project as the source of truth. Read or search `To_Beyond_Draft.html` only when the user explicitly requests it. Preserve Thai wording, balance values, timing, and rounding outside the requested changes. Keep rules in the simulation, controllers, or data resources used by the active branch and keep rendering and animation in the view.

In Domino Run, add new behavior to the deterministic simulation and handle its events in the view. Put balance values in the associated data resources or simulation constants. Add a regression case when introducing an artifact, boss, or rule.

## Find and validate changes

1. Start with the [feature map](reference/map.md). Search for the relevant function and read the surrounding lines. Update the map when moving or renaming code it lists. Read the [game feel guide](reference/feel.md) for animation or timing changes and the [pitfalls](reference/pitfalls.md) when diagnosing a recurring issue.
2. Use Godot 4.7.2 and matching Web templates. If needed, run `bash tools/parity/setup_godot.sh`. Export `GODOT` with the executable path, then run `"$GODOT" --headless --path . --import` from the repo root on a fresh checkout or after switching branches.
3. Run `bash tools/parity/build.sh --check` for the branch's script and smoke checks. Run `bash tools/parity/build.sh --regress` after changing gameplay rules, scoring, artifacts, bosses, or Chaos. Use `--regress --update` only when you have verified that the baseline differences match the intended changes.
4. After game changes, play-test the affected interaction in a browser. Run `bash tools/parity/build.sh`, then serve `build/web` with `python3 -m http.server 3000 --bind 0.0.0.0 --directory build/web`. Check the affected interaction in a browser. For timing checks, use `node tools/parity/record.js` with the scenario and input sequence described in the game feel guide. Build logs are in `build/import.log` and `build/export.log`.
5. Use `python3 tools/parity/node_tree.py` to inspect the static Domino scene tree. For debug play-tests, `?arts=mirror,coal` pre-fills the artifact slots. Historical evals cover older builds.

## Version and preview

Work on the requested branch. For a requested push that includes changes beyond Markdown, bump the patch in `project.godot` once per push unless the user specifies another increment. Keep the version and commit stamp visible at the bottom right of every playable screen. GitHub Actions publishes `main` at the site root and other branches under `/ToBeyond/preview/<branch>/` on `arm-role.github.io`. Verify deployments against the intended commit and report the version, checks, and preview URL.
