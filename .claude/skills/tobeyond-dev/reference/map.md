# Draft ↔ Godot map

Draft sections start with a comment like `/* ===== Token / walk ===== */`; jump with
`grep -n "===== Token" To_Beyond_Draft.html`. Function names below are exact; line numbers drift, so grep.

| Feature | Draft (section: functions) | Godot (file: functions) |
|---|---|---|
| Board tiles, tile art, directions | Board: `tileSvg placedSvg dirSvg orn pos locked`; `TILE_DIR` | main: `render_tiles` → ui_renderer: `render_tiles _apply_tile_state _render_tile_number _make_tile_frame`; `TILE_DIR` |
| Group strip under the board | Calc display: `updateGroups gShadow clearGroupFx`; Board: `gstripClear` | ui_renderer: `_render_gstrip_cell _gstrip_chip _group_color_for_tile _make_gstrip_badge` |
| Totem | Board: `syncTotem totemAtk` | main: `sync_totems totem_attack`; ui_renderer: `_render_totem`; battle_manager: `_hit_totem` |
| Deck, hand, sort, discard | Deck / hand: `buildDeck drawUp setSort colorRank dirRank renderTray fitHand discardCard` | main: `build_deck draw_up_to_hand set_sort_mode _on_discard_pressed render_hand` → ui_renderer: `render_hand` |
| Place / take back / new round | Place / take back: `placeCard clearBoardCards newRound` | main: `_on_hand_card_clicked _on_tile_clicked start_new_round` |
| Stone formulas (groups) | Stone: `stoneVal stoneDesc tileDir lineRuns calcGroups`; `FROWS` | stone_calc: `DEFAULT_FORMULAS calculate_groups`; main: `calculate_groups matching_group_count` |
| Auto place | Auto place: `autoPlace` | stone_calc: `solve_best_placement`; main: `auto_place_selected` |
| Damage formula text | Calc display: `showCalc refreshCalc`; State: `fmt` | main: `show_calc refresh_calc fmt_num` |
| Walk (token path, per-tile effects) | Token / walk: `walk placeRun arrive dash startPass endPass westCardAtk greenEastOk dirCount dirRun northExp eastFactor passiveTileCount` | battle_manager: `run_walk _visit_tile _tile_pop _spawn_tile_popup`; main: `begin_walk_damage apply_tile_walk_effects tile_direction_count tile_direction_run passive_chaos_tile_count prepare_walk_artifacts` |
| Attack sequence (artifacts one by one, fireball, beam) | Token / walk: `attackSeq strike finish popScore` | main: `compute_attack(steps) _record_step artifact_slot flash_artifact`; battle_manager: `_on_walk_finished _burst _charge_ring _hero_cast` |
| Enemy counter attack, player HP | Token / walk: `enemyStrike updatePlayerHP`; State: `phpMax` | battle_manager: `_enemy_counter_attack _hero_ouch`; main: `player_hp player_max_hp` |
| Enemy spawn, boss, boss skill, scaling | Enemy: `isBoss bossSkill spawnEnemy`; `BOSS_PICS BOSS_BLANKS` | main: `is_boss spawn_current_enemy boss_skill`; shop_manager: `on_shop_leave` (stage++, HP ×1.5, ATK × PHP_GROW) |
| Victory summary | `showReward afterReward` (`rewardInfo`) | main: `on_victory render_reward_summary _add_reward_row _on_reward_shop_pressed` |
| Shop: offers, tabs, reroll, buy | Artifact / Shop: `genOffers rerollShop buyOffer openOfferPop artCardEl stoneCardEl chaosCardEl upgCardEl upgPrice`; `openShop leaveShop setShopTab renderShop renderUpgrades buyHand buyStat buyStone` | shop_manager: `open_shop set_tab generate_game_offers reroll_shop render_shop_offers _render_game_offers _render_artifact_catalog _render_chaos_catalog _render_upgrade_catalog _add_shop_card _add_offer_row buy_* on_shop_leave` |
| Artifact slots, names, descriptions, sell | `itemName itemDesc itemCover setItemFace setItemLabel renderItems flashItem openOwnedPop sellItem artSellVal hasFullSell`; `ITEMS` | shop_manager: `DRAFT_NAMES DRAFT_DESCS display_name display_desc art_cover get_sell_price confirm_sell_artifact sell_artifact`; ui_renderer: `render_artifact_row _style_item_slot`; main: `artifacts flash_artifact` |
| Popup (title, text, buttons) | `openPop closePop` | main: `_setup_action_dialog show_action_dialog` |
| Chaos cards | CHAOS: `chaosFromDef chaosLabel chaosName chaosDesc chaosCover useChaos placeChaos onChaosUsed giveRandChaos renderChaos chaosMsg setTileDir applyDeckMods resetChaos`; `CHAOS_SHOP` | shop_manager: `CHAOS_CATALOG chaos_label chaos_name chaos_desc buy_chaos sell_chaos`; main: `_on_chaos_slot_pressed _apply_hand_chaos _apply_chaos_to_tile _finish_chaos give_random_chaos apply_deck_mods reset_chaos chaos_msg`; ui_renderer: `render_chaos_row` |
| Crystal (boss obstacle) | CHAOS: `crystalSvg addCrystal hitCrystal giveCrystalChaos clearCrystals` | main: `hit_crystal`; battle_manager: `_hit_crystal`; ui_renderer: `_render_crystal` |
| Deck view, Stone view | `openDeckView openStoneView closeView` | ui_renderer: `open_deck_modal setup_stone_modal_content make_mini_card _fit_view_scroll` |
| Discovery toast | `discoverToast` | main: `show_discovery_toast` → vfx_manager: `show_center_toast` |
| Speed ×1–×5 | Speed: `apply cycleSpeed` (scales setTimeout, rAF, CSS) | main: `_on_speed_toggle`; battle_manager: `_spd _timer` |
| Game over, new game | `showGameOver newGame resetGame` | main: `on_game_over start_new_game` |
| Effects | `strike enemyStrike` + CSS keyframes | vfx_manager: `fire_laser_beam shake_node spawn_damage_number show_center_toast pop_tile_anim` |
| Sound, hit stop, fullscreen/mute buttons (not in the draft, added for game feel) | — | `scripts/sfx_manager.gd` (synthesised sounds, `main.sfx.play(name)`), battle_manager: `_hit_stop`, final-total pop + tier tint in `_on_walk_finished`; main: `_setup_fullscreen_button _setup_audio_button`, number pop in `show_calc` |

## Data

| Draft | Godot |
|---|---|
| `ITEMS` (owned artifacts) | `main.artifacts` |
| artifact catalog in `genOffers` / `itemName` / `itemDesc` | `ShopManager.ARTIFACT_CATALOG`, `ARTIFACT_RARITY`, `DRAFT_NAMES`, `DRAFT_DESCS` |
| `CHAOS_SHOP` | `ShopManager.CHAOS_CATALOG` |
| `FROWS` (Stone rows: key, name, desc, min, a, g, pv) | `StoneCalc.DEFAULT_FORMULAS` |
| `UPG_INFO` | shop_manager `_get_stat_offer_info` |
| `BOSS_PICS BOSS_BLANKS ENEMY_HP_START EATK_START PHP_GROW` | same names in main.gd (grep) |

## Draft CSS selectors (for parity `els`)

Top bar `#stat #coins #spd #rst` · preview `.preview #hero #calc .php .hpbar .hptxt .enemy #ename #eskill #epic #eatk #msg` · rows `#artrow .islot`, `#chaosrow` · board `#board .tile`, `#gstrip` · bottom `.toolcol .vbtn`, `#tray .tcard`, `#go #sortCol #sortDir #dis` · modals `#reward .rbox .rrow .shopgo`, `#shop .shophead #shopCoins #shopOwned #shopChaos .shoptabs #shopItems .sitem`, `#gameover .panel .ptitle #goinfo`, `#vwDeck #vwStone .panel .vscroll`, popup `#pop #popTitle #popDesc #popAct`, toast `#ctoast`.
