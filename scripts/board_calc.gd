class_name BoardCalc
extends RefCounted

## Group / direction counting and walk attack maths, moved from main.gd.
## State stays on main; this class reads it as _main.xxx.

var _main: Node


func _init(main: Node) -> void:
	_main = main


## Flat ATK per placed Gem (Stone groups were removed in P2). `groups` stays in
## the result, empty, so callers keep their shape; P4 replaces this with Gem types.
const GEM_ATK: int = 2

func calculate_groups() -> Dictionary:
	var grp_val: Dictionary = {}
	var total := 0
	for tile_idx in range(_main.N_TILES):
		if _main.placed_cards.has(tile_idx) and not _main.placed_cards[tile_idx].get("is_blank", false):
			grp_val[tile_idx] = GEM_ATK
			total += GEM_ATK
	return {"groups": [], "grp_val": grp_val, "base_dmg": total}


## Auto-place: cards sorted by colour then direction; each takes the first free
## tile that points the same way as the card, else the first free tile.
func greedy_placement(cards_to_place: Array) -> Dictionary:
	const COLORS := ["red", "green", "orange", "blue"]
	const DIRS := ["N", "E", "S", "W"]
	var free: Array[int] = []
	for i in range(_main.N_TILES):
		if not _main.placed_cards.has(i):
			free.append(i)
	var use: Array = cards_to_place.slice(0, mini(cards_to_place.size(), free.size()))
	use.sort_custom(func(a, b):
		var ca: int = COLORS.find(str(a["color"]))
		var cb: int = COLORS.find(str(b["color"]))
		if ca != cb:
			return ca < cb
		return DIRS.find(str(a["dir"])) < DIRS.find(str(b["dir"])))
	var slots: Array = []
	for card in use:
		var pick: int = free[0]
		for t in free:
			if _main.TILE_DIR[t] == card["dir"]:
				pick = t
				break
		free.erase(pick)
		slots.append(pick)
	return {"cards": use, "slots": slots}


func tile_direction_count(direction: String) -> int:
	var count := 0
	for tile_direction in _main.TILE_DIR:
		if tile_direction == direction:
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


## Totems hop to new tiles after every round.
func shuffle_totems() -> void:
	var count: int = _main.totem_tiles.size()
	if count == 0:
		return
	var free: Array[int] = []
	for i in range(_main.N_TILES):
		free.append(i)
	free.shuffle()
	_main.totem_tiles.clear()
	for i in range(count):
		_main.totem_tiles.append(free[i])


func totem_attack(tile_idx: int) -> int:
	return int(round(20.0 + 40.0 * pow(float(_main.N_TILES - 1 - tile_idx) / float(_main.N_TILES - 1), 2.0)))


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
	var landed: Dictionary = _main.artifact_sys.land(tile_idx, card, gain, helper_pass)
	var extra: int = landed["extra"]
	var fired: Array = landed["fired"]  # landing artifacts that took effect (for the flash + sparks)
	var coin_won: bool = landed["coin_won"]
	return {"gain": gain, "extra": extra, "fired": fired, "coin_won": coin_won}

