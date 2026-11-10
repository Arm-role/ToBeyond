class_name BoardCalc
extends RefCounted

## Group / direction counting and walk attack maths, moved from main.gd.
## State stays on main; this class reads it as _main.xxx.

var _main: Node


func _init(main: Node) -> void:
	_main = main


func calculate_groups() -> Dictionary:
	var result: Dictionary = StoneCalc.calculate_groups(_main.placed_cards, _main.TILE_DIR, _main.stone_formulas, _main.N_TILES)
	# Equalizer lifts every completed Stone group to the highest group value.
	# This mirrors the draft's updateGroups() rule and changes real walk damage,
	# not merely the number printed under a tile.
	if _main.artifact_sys.has_rule(&"equal_groups") and result["groups"].size() >= 2:
		var highest := 0
		for group in result["groups"]:
			highest = maxi(highest, int(group["res"]["a"]))
		for group in result["groups"]:
			group["res"]["a"] = highest
			for tile_idx in group["idxs"]:
				result["grp_val"][tile_idx] = highest
		var total := 0
		for tile_idx in range(_main.N_TILES):
			if _main.placed_cards.has(tile_idx) and not _main.placed_cards[tile_idx].get("is_blank", false):
				total += int(result["grp_val"].get(tile_idx, 1))
		result["base_dmg"] = total
	return result


func tile_direction_count(direction: String) -> int:
	var count := 0
	for tile_direction in _main.TILE_DIR:
		if tile_direction == direction:
			count += 1
	return count


func tile_direction_run(direction: String) -> int:
	var best := 0
	var run := 0
	for tile_direction in _main.TILE_DIR:
		run = run + 1 if tile_direction == direction else 0
		best = maxi(best, run)
	return best


func matching_group_count(direction: String, color: String) -> int:
	var count := 0
	for group in calculate_groups()["groups"]:
		var matches := 0
		for tile_idx in group["idxs"]:
			var card = _main.placed_cards.get(tile_idx)
			if card != null and _main.TILE_DIR[tile_idx] == direction and card.get("dir") == direction and (color.is_empty() or card.get("color") == color):
				matches += 1
		if matches >= 2:
			count += 1
	return count


func matching_card_count(direction: String, color: String) -> int:
	var count := 0
	for tile_idx in _main.placed_cards:
		var card = _main.placed_cards[tile_idx]
		if _main.TILE_DIR[tile_idx] == direction and card.get("dir") == direction and card.get("color") == color:
			count += 1
	return count


func sync_totems() -> void:
	var desired := mini(_main.N_TILES, _main.artifact_sys.rule_count(&"totem"))
	while _main.totem_tiles.size() > desired:
		_main.totem_tiles.pop_back()
	while _main.totem_tiles.size() < desired:
		for tile_idx in range(_main.N_TILES):
			if not _main.totem_tiles.has(tile_idx):
				_main.totem_tiles.append(tile_idx)
				break


func totem_attack(tile_idx: int) -> int:
	return int(round(20.0 + 40.0 * pow(float(_main.N_TILES - 1 - tile_idx) / float(_main.N_TILES - 1), 2.0)))


func passive_chaos_tile_count() -> int:
	return _main.chaos_mult_tiles.size() + _main.chaos_xmult_tiles.size() + _main.chaos_xatk_tiles.size()


## Final attack. `steps` (optional, passed by the caller) is filled like the
## draft's attackSeq(): steps[0] is the raw walk total, then one entry per
## artifact that fired: {"slot": artifact slot, "atk": float, "mult": float}.
func compute_attack(steps: Array = []) -> Dictionary:
	var calc = calculate_groups()
	var atk: float = 1 + (_main.walk_base_damage if _main.is_busy else calc["base_dmg"])
	var mult: float = 1.0 + (_main.walk_mult_bonus if _main.is_busy else 0.0)
	steps.append({"slot": -1, "atk": atk, "mult": mult})

	# Artifacts in slot order like the draft's attackSeq() (South-five first).
	var result: Dictionary = _main.artifact_sys.attack(calc, atk, mult, steps)
	atk = result["atk"]
	mult = result["mult"]
	return {"atk": int(round(atk)), "mult": mult, "dmg": int(round(atk * mult))}


func apply_tile_walk_effects(tile_idx: int, helper_pass: bool = false) -> Dictionary:
	var card = _main.placed_cards.get(tile_idx)
	if card == null or card.get("is_blank", false):
		return {"gain": 0, "extra": 0, "fired": []}

	var gain = int(calculate_groups()["grp_val"].get(tile_idx, 1))
	_main.walk_base_damage += gain
	if _main.chaos_mult_tiles.has(tile_idx):
		_main.walk_mult_bonus += 5.0
	if _main.chaos_xmult_tiles.has(tile_idx):
		_main.walk_mult_bonus = (1.0 + _main.walk_mult_bonus) * 1.2 - 1.0
	if _main.chaos_xatk_tiles.has(tile_idx):
		_main.walk_base_damage = int(round(_main.walk_base_damage * 1.2))
	var landed: Dictionary = _main.artifact_sys.land(tile_idx, card, gain, helper_pass)
	var extra: int = landed["extra"]
	var fired: Array = landed["fired"]  # landing artifacts that took effect (for the flash + sparks)
	var coin_won: bool = landed["coin_won"]
	return {"gain": gain, "extra": extra, "fired": fired, "coin_won": coin_won}

