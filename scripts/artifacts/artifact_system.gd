class_name ArtifactSystem
extends RefCounted
## Loads the artifact definitions from res://data and runs the
## artifact hooks for main.gd. See ArtifactEffect for the list of hooks.
## Adding an artifact = a new .tres in data/artifacts (plus an effect script
## only when no data-only effect fits). The game code never names artifacts.

const ARTIFACT_DIR := "res://data/artifacts/"

static var _defs: Dictionary = {}            # id -> ArtifactData
static var _list: Array[ArtifactData] = []   # by catalog_order


# --- Definitions (static) ------------------------------------------------------
static func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres") or f.ends_with(".res"):
			out.append(dir + f)
	return out


static func _ensure_loaded() -> void:
	if not _list.is_empty():
		return
	for path in _files(ARTIFACT_DIR):
		var d := load(path) as ArtifactData
		if d != null and d.id != "":
			_defs[d.id] = d
			_list.append(d)
	_list.sort_custom(func(a, b): return a.catalog_order < b.catalog_order)


static func all() -> Array[ArtifactData]:
	_ensure_loaded()
	return _list


static func get_def(id: String) -> ArtifactData:
	_ensure_loaded()
	return _defs.get(id)


# --- Hooks (per game) ------------------------------------------------------------
var main: Node


func _init(main_node: Node) -> void:
	main = main_node


func _ctx() -> ArtifactContext:
	return ArtifactContext.new(main)


func has_rule(rule: StringName) -> bool:
	return rule_count(rule) > 0


## Copies held that grant `rule`.
func rule_count(rule: StringName) -> int:
	var n := 0
	for art in main.artifacts:
		if art != null:
			var d := get_def(art.get("type", ""))
			if d != null and d.grants(rule):
				n += 1
	return n


## Type of the first held artifact granting `rule` ("" if none), for its flash.
func rule_type(rule: StringName) -> String:
	for art in main.artifacts:
		if art != null:
			var d := get_def(art.get("type", ""))
			if d != null and d.grants(rule):
				return d.id
	return ""


## Calls a per-copy hook on every held artifact in slot order.
## Returns [[slot, type], …] for the copies that took effect.
func _per_copy(hook: String, ctx: ArtifactContext, on_fire: Callable = Callable()) -> Array:
	var fired: Array = []
	for slot in range(main.artifacts.size()):
		var art = main.artifacts[slot]
		if art == null:
			continue
		var d := get_def(art.get("type", ""))
		if d == null:
			continue
		var any := false
		for e in d.effects:
			if e is ArtifactEffect and e.call(hook, ctx, art):
				any = true
		if any:
			fired.append([slot, d.id])
			if on_fire.is_valid():
				on_fire.call(slot)
	return fired


## Held types with their copy counts, ordered by ArtifactData.order.
func _held_types() -> Array:
	var counts := {}
	for art in main.artifacts:
		if art != null:
			var t: String = art.get("type", "")
			counts[t] = int(counts.get(t, 0)) + 1
	var types: Array = []
	for t in counts:
		var d := get_def(t)
		if d != null:
			types.append([d, counts[t]])
	types.sort_custom(func(a, b): return a[0].order < b[0].order)
	return types


static func _types(fired: Array, unique: bool = false) -> Array:
	var out: Array = []
	for f in fired:
		if not unique or not out.has(f[1]):
			out.append(f[1])
	return out


func round_start() -> void:
	var fired := _per_copy("round_start", _ctx())
	if not fired.is_empty():
		main.battle_mgr.fx_artifact_types(_types(fired))


## Right before the walk: counters fed by the board.
func pre_walk() -> void:
	var ctx := _ctx()
	var fired := _per_copy("pre_walk", ctx)
	if ctx.msg != "":
		main.msg_label.text = ctx.msg
	main.render_artifact_row()
	main.battle_mgr.fx_artifact_types(_types(fired))


## A Gem was placed from the hand onto the board (streak counters).
func card_played(card: Dictionary) -> void:
	var ctx := _ctx()
	ctx.card = card
	var fired := _per_copy("card_played", ctx)
	main.render_artifact_row()
	main.battle_mgr.fx_artifact_types(_types(fired))


## The walk lands on a Gem. Returns {"extra", "fired": [types], "coin_won"}.
func land(tile_idx: int, card: Dictionary, gain: int, helper_pass: bool) -> Dictionary:
	var ctx := _ctx()
	ctx.tile_idx = tile_idx
	ctx.card = card
	ctx.gain = gain
	ctx.helper_pass = helper_pass
	var fired: Array = []
	for entry in _held_types():
		var d: ArtifactData = entry[0]
		var any := false
		for e in d.effects:
			if e is ArtifactEffect and e.land(ctx, entry[1]):
				any = true
		if any:
			fired.append(d.id)
	return {"extra": ctx.extra, "fired": fired, "coin_won": ctx.coin_won}


## Final attack like the draft's attackSeq(): "early" cards first, then every
## card in slot order. Appends {"slot", "atk", "mult"} to `steps` per card fired.
func attack(calc: Dictionary, atk: float, mult: float, steps: Array) -> Dictionary:
	var ctx := _ctx()
	ctx.calc = calc
	ctx.atk = atk
	ctx.mult = mult
	var record := func(slot: int) -> void:
		steps.append({"slot": slot, "atk": ctx.atk, "mult": ctx.mult})
	_per_copy("attack_early", ctx, record)
	_per_copy("attack", ctx, record)
	return {"atk": ctx.atk, "mult": ctx.mult}


## Enemy died. Returns {"rows": {row: coins}, "total": coins, "fx": [types]};
## counters that grow on victory are updated too.
func victory() -> Dictionary:
	var ctx := _ctx()
	var rows := {}
	var total := 0
	var fx: Array = []
	for entry in _held_types():
		var d: ArtifactData = entry[0]
		for e in d.effects:
			if e is RewardEffect:
				var coins: int = e.reward(ctx, entry[1])
				if coins > 0:
					rows[e.row] = int(rows.get(e.row, 0)) + coins
					total += coins
					if not fx.has(d.id):
						fx.append(d.id)
	for t in _types(_per_copy("victory", ctx), true):
		if not fx.has(t):
			fx.append(t)
	return {"rows": rows, "total": total, "fx": fx}


