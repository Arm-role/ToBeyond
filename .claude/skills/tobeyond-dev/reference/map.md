# Map: feature → Godot code

Godot code is the source of truth. `tools/parity/check_refs.py` (run by `build.sh --check`) fails when a
`` `file.gd: name name` `` entry or a `scripts/…`/`data/…` path below no longer exists, so keep entries in that exact form.
Line numbers drift, so grep the name. Plan and per-phase docs: `docs/plan-domino-run.md`, `docs/domino/phase-N.md`.

| Feature | Godot |
|---|---|
| Fight state, stage scaling, boss pick | `domino_sim.gd: start_fight claim_win strike_each deal_hand place take` |
| One walk as an event list | `domino_sim.gd: run_walk _finalize _emit _push` |
| Pops, strikes, damage, shield | `domino_sim.gd: _do_pop _do_strike _hit _shield` |
| Rule engine (artifact + boss rules, caps, once) | `domino_sim.gd: _fire _match _check _apply` · ceilings `MAX_*` consts |
| Route (bounce, ring, flag moves) | `domino_sim.gd: default_route _route_next` |
| Artifacts / bosses as data | `data/domino/artifacts/*.tres` · `data/domino/bosses/*.tres` · `domino_rule.gd: trigger cond effect args once` · `domino_artifact.gd: archetype rarity rules` · `domino_boss.gd: rule args rules` |
| Catalog loading (web-export safe) | `domino_catalog.gd: all get_def bosses get_boss` |
| Reward pick 1 of 3 | `domino_reward.gd: offer pick` · `domino_view.gd: _reward _reward_offers _reward_pick` |
| Shop after a boss | `domino_shop.gd: stock price sell_value reroll_cost` · `domino_view.gd: _shop` |
| Artifact slot bar (tap to read, tap two to swap) | `domino_view.gd: _on_slot _slot_tip _apply_slots _refresh_slots` |
| Replaying a walk (fireball, pops, hits, shield, flags, gold) | `domino_view.gd: _on_go _play_walk _win _lose` |
| Characters, lasers, floating text, shake | `domino_view.gd: _react _windup _laser _strike_fx _float_text _shake _badge` |
| Shown values vs sim state | `domino_view.gd: _sync _refresh _new_turn` |
| Sound | `sfx_manager.gd: play step` |
| Version stamp (every screen needs one) | `domino_view.gd: _add_version_stamp` |
| Headless regression | `tools/parity/domino_regress.gd` · baseline `tools/parity/baseline/domino_regress.txt` |
