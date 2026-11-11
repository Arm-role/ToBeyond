class_name StoneCalc
extends RefCounted

# Same data as FROWS in To_Beyond_Draft.html; `pv` = preview cards [colour, dir or ""].
const COLOR_ORDER: Array = ["red", "green", "orange", "blue"]
const DIR_ORDER: Array = ["N", "E", "S", "W"]

const DEFAULT_FORMULAS: Array[Dictionary] = [
	{"key": "col", "name": "สีเรียงกัน", "desc": "สีเดียวกันวางติดกัน (ใบเดี่ยวนับด้วย)", "min": 1, "a": 1, "g": 1, "pv": [["red", ""], ["red", ""], ["red", ""]]},
	{"key": "dsame", "name": "ทิศเรียงกัน", "desc": "ทิศของการ์ดเหมือนกันวางติดกัน (ไม่สนช่อง · 2 ใบขึ้นไป)", "min": 2, "a": 2, "g": 1, "pv": [["red", "E"], ["blue", "E"], ["green", "E"]]},
	{"key": "alt", "name": "สลับสี", "desc": "สองสีวางสลับกัน (3 ใบขึ้นไป)", "min": 3, "a": 3, "g": 1, "pv": [["red", ""], ["blue", ""], ["red", ""]]},
	{"key": "dtile", "name": "ทิศตรงช่อง", "desc": "ทิศของการ์ดตรงกับช่องทุกใบ (สีไหนก็ได้)", "min": 1, "a": 2, "g": 2, "pv": [["red", "N"], ["blue", "N"], ["green", "E"]]},
	{"key": "cd", "name": "สีทิศ", "desc": "สีเดียวกัน และทิศตรงช่องทุกใบ (2 ใบขึ้นไป)", "min": 2, "a": 5, "g": 5, "pv": [["red", "N"], ["red", "N"], ["red", "E"]]},
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

## Port of the draft's autoPlace(): the selected cards (first n in hand order,
## sorted by colour then direction) go on the free tiles that maximise
## [sum of group ATK x cards, 1 + sum of group ATK per card].
## Up to 15000 permutations are searched exhaustively, otherwise rotations +
## 40 random layouts, then hill climbing (swap two cards / move one card) on
## the best 8 within a 900 ms budget, like the draft.
static func solve_best_placement(cards_to_place: Array, placed_cards: Dictionary, tile_dirs: Array, formulas: Array, max_tiles: int = 8) -> Dictionary:
	var free: Array[int] = []
	for i in range(max_tiles):
		if not placed_cards.has(i):
			free.append(i)
	var n := mini(cards_to_place.size(), free.size())
	if n < 1:
		return {"cards": [], "slots": []}
	var use: Array = cards_to_place.slice(0, n)
	use.sort_custom(func(a, b):
		var ca := _rank(COLOR_ORDER, str(a["color"]))
		var cb := _rank(COLOR_ORDER, str(b["color"]))
		if ca != cb:
			return ca < cb
		return _rank(DIR_ORDER, str(a["dir"])) < _rank(DIR_ORDER, str(b["dir"])))
	var ctx := {"use": use, "placed": placed_cards, "dirs": tile_dirs, "formulas": formulas, "max": max_tiles}
	var perms := 1
	for i in range(n):
		perms *= (free.size() - i)
	var best: Array = []
	var best_sc: Array = []
	if perms <= 15000:
		var st := {"best": [], "sc": [], "as": [], "used": {}}
		_rec(0, n, free, ctx, st)
		best = st["best"]
	else:
		var t0 := Time.get_ticks_msec()
		var cand: Array = []
		for off in range(free.size()):
			var as_: Array = []
			for j in range(n):
				as_.append(free[(off + j) % free.size()])
			cand.append([_score(as_, ctx), as_])
		for r in range(40):
			var f: Array = free.duplicate()
			f.shuffle()
			var as_: Array = f.slice(0, n)
			cand.append([_score(as_, ctx), as_])
		cand.sort_custom(func(x, y): return _cmp(x[0], y[0]) > 0)
		for ci in range(mini(8, cand.size())):
			var as_: Array = cand[ci][1].duplicate()
			var v: Array = cand[ci][0]
			var imp := true
			while imp and Time.get_ticks_msec() - t0 < 900:
				imp = false
				for a in range(n):
					for b in range(a + 1, n):
						var t: Array = as_.duplicate()
						var tmp = t[a]
						t[a] = t[b]
						t[b] = tmp
						var w := _score(t, ctx)
						if _cmp(w, v) > 0:
							as_ = t
							v = w
							imp = true
					for f2 in free:
						if as_.has(f2):
							continue
						var t2: Array = as_.duplicate()
						t2[a] = f2
						var w2 := _score(t2, ctx)
						if _cmp(w2, v) > 0:
							as_ = t2
							v = w2
							imp = true
			if best_sc.is_empty() or _cmp(v, best_sc) > 0:
				best_sc = v
				best = as_
	if best.is_empty():
		return {"cards": [], "slots": []}
	return {"cards": use, "slots": best}


static func _rank(order: Array, v: String) -> int:
	var i := order.find(v)
	return 99 if i < 0 else i


static func _score(slots: Array, ctx: Dictionary) -> Array:
	var temp: Dictionary = ctx["placed"].duplicate()
	var use: Array = ctx["use"]
	for j in range(slots.size()):
		temp[slots[j]] = use[j]
	var g := calculate_groups(temp, ctx["dirs"], ctx["formulas"], ctx["max"])
	var total := 0
	var per_card := 0
	for grp in g["groups"]:
		total += int(grp["res"]["a"]) * grp["idxs"].size()
		per_card += int(grp["res"]["a"])
	return [total, 1 + per_card]


static func _cmp(x: Array, y: Array) -> int:
	if x[0] != y[0]:
		return int(x[0]) - int(y[0])
	return int(x[1]) - int(y[1])


static func _rec(j: int, n: int, free: Array, ctx: Dictionary, st: Dictionary) -> void:
	if j == n:
		var sc := _score(st["as"], ctx)
		if st["sc"].is_empty() or _cmp(sc, st["sc"]) > 0:
			st["sc"] = sc
			st["best"] = st["as"].duplicate()
		return
	for f in free:
		if st["used"].has(f):
			continue
		st["used"][f] = true
		if st["as"].size() > j:
			st["as"][j] = f
		else:
			st["as"].append(f)
		_rec(j + 1, n, free, ctx, st)
		st["used"].erase(f)
