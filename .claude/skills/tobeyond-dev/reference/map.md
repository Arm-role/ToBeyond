# Map: feature → Godot code

Godot code is the source of truth. `tools/parity/check_refs.py` (run by `build.sh --check`) fails when a
`` `file.gd: name name` `` entry or a `scripts/…`/`data/…` path below no longer exists, so keep entries in that exact form.
Line numbers drift, so grep the name. The draft columns live in the appendix at the end; open them only when the user orders a draft comparison.

| Feature | Godot |
|---|---|
| Board tiles, tile art, directions | `ui_renderer.gd: render_tiles _apply_tile_state _render_tile_number _make_tile_frame` · `main.gd: render_tiles TILE_DIR` |
| Group strip under the board | `ui_renderer.gd: _render_gstrip_cell _gstrip_chip _group_color_for_tile _make_gstrip_badge` |
| Totem | `board_calc.gd: sync_totems totem_attack` · `ui_renderer.gd: _render_totem` · `battle_manager.gd: _hit_totem` |
| Deck, hand, sort, discard | `main.gd: build_deck draw_up_to_hand set_sort_mode render_hand` · `ui_renderer.gd: render_hand` · `chaos_controller.gd: on_discard_pressed` |
| Place / take back / new round | `main.gd: _on_hand_card_clicked _on_tile_clicked start_new_round` · `chaos_controller.gd: on_tile_clicked` |
| Stone formulas (groups) | `stone_calc.gd: DEFAULT_FORMULAS FLAGS calculate_groups _group_better validate_formulas` · `board_calc.gd: calculate_groups matching_group_count matching_card_count` |
| Auto place | `stone_calc.gd: solve_best_placement` · `main.gd: auto_place_selected` |
| Damage formula text | `main.gd: show_calc refresh_calc fmt_num` · `board_calc.gd: compute_attack` |
| Walk (token path, per-tile effects) | `battle_manager.gd: run_walk build_walk_steps _visit_tile _tile_pop _spawn_tile_popup` · `board_calc.gd: tile_direction_count tile_direction_run passive_chaos_tile_count apply_tile_walk_effects` · `main.gd: _on_walk_pressed _land_card begin_walk_damage prepare_walk_artifacts` |
| Attack sequence (artifacts one by one, fireball, beam) | `board_calc.gd: compute_attack` · `main.gd: artifact_slot flash_artifact` · `artifact_system.gd: attack` (per copy, slot order) · `battle_manager.gd: _on_walk_finished _burst _charge_ring _hero_cast` |
| Enemy counter attack, player HP | `battle_manager.gd: _enemy_counter_attack _hero_ouch` · `main.gd: player_hp player_max_hp` |
| Enemy spawn, boss, boss skill, scaling | `main.gd: is_boss spawn_current_enemy boss_skill` · `shop_manager.gd: on_shop_leave` (stage++, HP ×1.5, ATK × PHP_GROW) |
| Victory summary | `reward_flow.gd: on_victory render_summary add_row` · `main.gd: on_victory _on_reward_shop_pressed` |
| Shop: offers, tabs, reroll, buy | `shop_manager.gd: open_shop set_tab generate_game_offers reroll_shop render_shop_offers _render_game_offers _render_artifact_catalog _render_chaos_catalog _render_upgrade_catalog _add_shop_card _add_offer_row buy_game_offer buy_stat buy_stone_upgrade buy_artifact buy_chaos on_shop_leave` |
| Artifact slots, names, descriptions, sell | `shop_manager.gd: display_name display_desc art_cover get_sell_price confirm_sell_artifact sell_artifact` · `ui_renderer.gd: render_artifact_row _style_item_slot` · `main.gd: artifacts flash_artifact` |
| Popup (title, text, buttons) | `action_dialog.gd: setup show_dialog` · `main.gd: show_action_dialog` |
| Chaos cards | `chaos_controller.gd: on_slot_pressed apply_hand apply_to_tile finish` · `shop_manager.gd: CHAOS_CATALOG chaos_label chaos_name chaos_desc buy_chaos sell_chaos` · `main.gd: give_random_chaos apply_deck_mods reset_chaos chaos_msg` · `ui_renderer.gd: render_chaos_row` |
| Crystal (boss obstacle) | `chaos_controller.gd: hit_crystal` · `battle_manager.gd: _hit_crystal` · `ui_renderer.gd: _render_crystal` · `main.gd: hit_crystal` |
| Deck view, Stone view | `ui_renderer.gd: open_deck_modal setup_stone_modal_content make_mini_card _fit_view_scroll` |
| Discovery toast | `main.gd: show_discovery_toast` · `vfx_manager.gd: show_center_toast` |
| Speed ×1–×5 | `main.gd: _on_speed_toggle` · `battle_manager.gd: _spd _timer` |
| Game over, new game | `main.gd: on_game_over start_new_game` |
| Drag cards (slots swap/sell, hand→board, board↔board/hand, shop card→buy) | `slot_drag.gd: on_input begin finish` · `chaos_controller.gd: place_from_hand move_board_card return_board_card` |
| Toolbar (fullscreen, audio, sort buttons) | `toolbar_controls.gd: _setup_fullscreen_button _setup_audio_button _style_sort_button` |
| Effects, sound, hit stop (game feel, not in the draft) | `vfx_manager.gd: fire_laser_beam shake_node spawn_damage_number show_center_toast pop_tile_anim` · `battle_manager.gd: _hit_stop` · `sfx_manager.gd` (synthesised sounds, `main.sfx.play(name)`) |

## Data

| Draft | Godot |
|---|---|
| `ITEMS` (owned artifacts) | `main.artifacts` |
| artifact catalog in `genOffers` / `itemName` / `itemDesc`, `RARITY`, attack/landing code per type | `data/artifacts/<id>.tres` (`ArtifactData`: shop fields, rarity, draft name/desc, cover, effects). `ShopManager.ARTIFACT_CATALOG` / `ARTIFACT_RARITY` are views built from it |
| artifact effects and trigger points | `scripts/artifacts/`: `ArtifactSystem` (hooks: round_start, chaos_used, pre_walk, land, attack_early, attack, victory, reward, stone_upgrade, rules), `ArtifactEffect` (hook table), data-only `StatEffect CounterEffect RewardEffect RuleEffect`, custom ones in `effects/*_effect.gd`. Game code asks `artifact_sys.has_rule(&"…")`, never an artifact id. Check numbers: `godot --headless --path . --script res://tools/parity/artifact_regress.gd` and diff with a run before the change |
| `CHAOS_SHOP` | `data/chaos/*.tres` (`ChaosData`) → `ShopManager.CHAOS_CATALOG` |
| `FROWS` (Stone rows: key, name, desc, min, a, g, tier, bonus, req, pv) | `StoneCalc.DEFAULT_FORMULAS` |
| `UPG_INFO` | shop_manager `_get_stat_offer_info` |
| `BOSS_PICS BOSS_BLANKS ENEMY_HP_START EATK_START PHP_GROW` | same names in main.gd (grep) |

## Draft CSS selectors (for parity `els`)

Top bar `#stat #coins #spd #rst` · preview `.preview #hero #calc .php .hpbar .hptxt .enemy #ename #eskill #epic #eatk #msg` · rows `#artrow .islot`, `#chaosrow` · board `#board .tile`, `#gstrip` · bottom `.toolcol .vbtn`, `#tray .tcard`, `#go #sortCol #sortDir #dis` · modals `#reward .rbox .rrow .shopgo`, `#shop .shophead #shopCoins #shopOwned #shopChaos .shoptabs #shopItems .sitem`, `#gameover .panel .ptitle #goinfo`, `#vwDeck #vwStone .panel .vscroll`, popup `#pop #popTitle #popDesc #popAct`, toast `#ctoast`.

## Appendix: draft functions (only when the user orders a draft comparison)

Draft sections start with a comment like `/* ===== Token / walk ===== */`; jump with `grep -n "===== Token" To_Beyond_Draft.html`. Reading the draft asks the user first (hook).

| Feature | Draft (section: functions) |
|---|---|
