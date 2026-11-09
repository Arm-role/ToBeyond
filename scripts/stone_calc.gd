class_name StoneCalc
extends RefCounted

# Same data as FROWS in To_Beyond_Draft.html; `pv` = preview cards [colour, dir or ""].
const DEFAULT_FORMULAS: Array[Dictionary] = [
	{"key": "col", "name": "สีเรียงกัน", "desc": "สีเดียวกันวางติดกัน (ใบเดี่ยวนับด้วย)", "min": 1, "a": 1, "g": 1, "pv": [["red", ""], ["red", ""], ["red", ""]]},
	{"key": "dsame", "name": "ทิศเรียงกัน", "desc": "ทิศของการ์ดเหมือนกันวางติดกัน (ไม่สนช่อง · 2 ใบขึ้นไป)", "min": 2, "a": 2, "g": 1, "pv": [["red", "E"], ["blue", "E"], ["green", "E"]]},
	{"key": "alt", "name": "สลับสี", "desc": "สองสีวางสลับกัน (3 ใบขึ้นไป)", "min": 3, "a": 3, "g": 1, "pv": [["red", ""], ["blue", ""], ["red", ""]]},
	{"key": "dtile", "name": "ทิศตรงช่อง", "desc": "ทิศของการ์ดตรงกับช่องทุกใบ (สีไหนก็ได้)", "min": 1, "a": 2, "g": 2, "pv": [["red", "N"], ["blue", "N"], ["green", "E"]]},
	{"key": "cd", "name": "สีทิศ", "desc": "สีเดียวกัน และทิศตรงช่องทุกใบ (2 ใบขึ้นไป)", "min": 2, "a": 3, "g": 3, "pv": [["red", "N"], ["red", "N"], ["red", "E"]]},
	{"key": "twin", "name": "ฝาแฝด", "desc": "การ์ดเหมือนกันทั้งสีและทิศ วางติดกัน (2 ใบขึ้นไป)", "min": 2, "a": 4, "g": 4, "pv": [["red", "S"], ["red", "S"], ["red", "S"]]}
]

## Calculate stone formula groupings and base damage
static func calculate_groups(placed_cards: Dictionary, tile_dirs: Array, formulas: Array, max_tiles: int = 8) -> Dictionary:
	var used: Array[int] = []
	var groups: Array = []
	var grp_val: Dictionary = {}

	while true:
		var cands: Array = []
		for s0 in range(max_tiles):
			if used.has(s0) or not placed_cards.has(s0) or placed_cards[s0].get("is_blank", false):
				continue
			for e0 in range(s0, max_tiles):
				if used.has(e0) or not placed_cards.has(e0) or placed_cards[e0].get("is_blank", false):
					break
				var idxs: Array[int] = []
				for q in range(s0, e0 + 1):
					idxs.append(q)
				var n = idxs.size()

				var first_col = placed_cards[s0]["color"]
				var first_dir = placed_cards[s0]["dir"]

				var same_col = true
				var same_dir = true
				var dtile = true

				for idx in idxs:
					var c = placed_cards[idx]
					if c["color"] != first_col: same_col = false
					if c["dir"] != first_dir: same_dir = false
					if c["dir"] != tile_dirs[idx]: dtile = false

				var alt_col = false
				if n >= 3:
					alt_col = (placed_cards[idxs[0]]["color"] != placed_cards[idxs[1]]["color"])
					for q in range(2, n):
						if placed_cards[idxs[q]]["color"] != placed_cards[idxs[q - 2]]["color"]:
							alt_col = false
							break

				var f = {
					"col": same_col,
					"dsame": same_dir,
					"alt": alt_col,
					"dtile": dtile,
					"cd": same_col and dtile,
					"twin": same_col and same_dir
				}

				var best_k = -1
				var best_v = 0
				for k in range(formulas.size()):
					var r = formulas[k]
					if f.get(r["key"], false) and n >= r["min"]:
						var v = r["a"] + r["g"] * (n - 1)
						if v > best_v or (v == best_v and k > best_k):
							best_v = v
							best_k = k

				if best_k >= 0:
					cands.append({
						"type": formulas[best_k]["key"],
						"name": formulas[best_k]["name"],
						"idxs": idxs,
						"col": first_col if same_col else null,
						"res": {"a": best_v, "k": best_k, "tot": best_v * n}
					})

		var best = null
		for g in cands:
			if best == null:
				best = g
				continue
			var b = best
			if g["res"]["tot"] > b["res"]["tot"] or (g["res"]["tot"] == b["res"]["tot"] and (g["res"]["a"] > b["res"]["a"] or (g["res"]["a"] == b["res"]["a"] and g["idxs"].size() > b["idxs"].size()))):
				best = g

		if best == null:
			break

		for i in best["idxs"]:
			used.append(i)
			grp_val[i] = best["res"]["a"]
		groups.append(best)

	var total_base_dmg = 0
	for i in range(max_tiles):
		if placed_cards.has(i) and not placed_cards[i].get("is_blank", false):
			total_base_dmg += grp_val.get(i, 1)

	return {
		"groups": groups,
		"grp_val": grp_val,
		"base_dmg": total_base_dmg
	}

## Searches placement without blocking the gameplay frame. Exact enumeration is
## useful for a small hand, but grows as (free slots)!; an 8-card placement can
## otherwise invoke Stone calculation tens of thousands of times synchronously.
static func solve_best_placement(cards_to_place: Array, placed_cards: Dictionary, tile_dirs: Array, formulas: Array, max_tiles: int = 8) -> Dictionary:
	var free_slots: Array[int] = []
	for i in range(max_tiles):
		if not placed_cards.has(i):
			free_slots.append(i)

	var n = mini(cards_to_place.size(), free_slots.size())
	if n <= 0:
		return {"cards": [], "slots": []}

	# Three cards stays comfortably below a frame even when all eight board slots
	# are free. Larger selections use bounded candidates below.
	if n > 3:
		return _solve_sampled_placement(cards_to_place.slice(0, n), free_slots, placed_cards, tile_dirs, formulas, max_tiles)

	var state = {
		"best_score": -1,
		"best_cards": [],
		"best_slots": [],
		"temp_placed": placed_cards.duplicate(),
		"used_slots": [],
		"used_card_indices": [],
		"chosen_cards": [],
		"chosen_slots": []
	}
	_search_placements(cards_to_place, free_slots, n, tile_dirs, formulas, max_tiles, state)
	return {"cards": state["best_cards"], "slots": state["best_slots"]}


static func _solve_sampled_placement(cards: Array, free_slots: Array[int], placed_cards: Dictionary, tile_dirs: Array, formulas: Array, max_tiles: int) -> Dictionary:
	const CANDIDATE_LIMIT := 96
	var best_score := -1
	var best_cards: Array = []
	var best_slots: Array = []
	for trial in range(CANDIDATE_LIMIT):
		var candidate_cards = cards.duplicate()
		var candidate_slots = free_slots.duplicate()
		if trial > 0:
			candidate_cards.shuffle()
			candidate_slots.shuffle()
		var temp_placed = placed_cards.duplicate()
		for i in range(candidate_cards.size()):
			temp_placed[candidate_slots[i]] = candidate_cards[i]
		var score = int(calculate_groups(temp_placed, tile_dirs, formulas, max_tiles)["base_dmg"])
		if score > best_score:
			best_score = score
			best_cards = candidate_cards
			best_slots = candidate_slots.slice(0, candidate_cards.size())
	return {"cards": best_cards, "slots": best_slots}


static func _search_placements(cards_to_place: Array, free_slots: Array[int], target_count: int, tile_dirs: Array, formulas: Array, max_tiles: int, state: Dictionary) -> void:
	if state["chosen_cards"].size() == target_count:
		var score = int(calculate_groups(state["temp_placed"], tile_dirs, formulas, max_tiles)["base_dmg"])
		if score > state["best_score"]:
			state["best_score"] = score
			state["best_cards"] = state["chosen_cards"].duplicate()
			state["best_slots"] = state["chosen_slots"].duplicate()
		return

	for card_index in range(cards_to_place.size()):
		if state["used_card_indices"].has(card_index):
			continue
		state["used_card_indices"].append(card_index)
		var card = cards_to_place[card_index]
		state["chosen_cards"].append(card)
		for slot in free_slots:
			if state["used_slots"].has(slot):
				continue
			state["used_slots"].append(slot)
			state["chosen_slots"].append(slot)
			state["temp_placed"][slot] = card
			_search_placements(cards_to_place, free_slots, target_count, tile_dirs, formulas, max_tiles, state)
			state["temp_placed"].erase(slot)
			state["chosen_slots"].pop_back()
			state["used_slots"].pop_back()
		state["chosen_cards"].pop_back()
		state["used_card_indices"].pop_back()

