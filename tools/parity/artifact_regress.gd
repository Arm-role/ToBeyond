extends SceneTree
## Headless numbers check for artifacts: puts artifact sets on fixed boards,
## runs every hook (pre-walk, route, landing, attack, chaos use, victory,
## shop) and prints one line per case. Run before and after a refactor and
## diff the output:
##   godot --headless --path . --script res://tools/parity/artifact_regress.gd > out.txt

const BOARDS := {
	# Default tile directions N N E E S S W W.
	"full": {"dirs": [], "cards": {0: ["red", "N"], 1: ["red", "N"], 2: ["blue", "E"], 3: ["blue", "E", true],
		4: ["green", "S"], 5: ["orange", "W"], 6: ["red", "S"], 7: ["blue", "W"]}},
	"sparse": {"dirs": [], "cards": {0: ["green", "E"], 2: ["orange", "N"], 3: ["red", "S"], 6: ["blue", "W"]},
		"mtile": [2], "xmult": [3], "xatk": [6]},
	"south": {"dirs": ["S", "S", "S", "S", "S", "N", "N", "N"],
		"cards": {0: ["red", "S"], 1: ["red", "S"], 2: ["green", "S"], 3: ["red", "S"], 4: ["red", "S"],
			5: ["orange", "N"], 6: ["orange", "N"], 7: ["green", "N"]}},
	"west": {"dirs": ["W", "W", "W", "W", "W", "E", "E", "E"],
		"cards": {0: ["blue", "W"], 1: ["blue", "W"], 2: ["blue", "W"], 4: ["green", "W"],
			5: ["green", "E"], 6: ["green", "E"], 7: ["green", "E", true]}},
}

const COMBOS := [
	["add5", "mult2", "atk15"],
	["add5", "add5", "atk15", "atk15"],
	["south5", "add5", "mult2", "north5", "stoneUp"],
	["reverse", "firstGem", "isoGem", "dirEHit", "eastG"],
	["helperOdd", "helperEven", "firstGem", "greenCoin", "dirSHit"],
	["chaosStack", "discardStack", "stone7W", "stone7E", "redS"],
	["totem", "totem", "reverse", "emptyAtk", "chaosAtk"],
	["equalG", "stone3", "tileAtk", "west5", "orangeN"],
	["artiPay", "fatePay", "walkCoin", "fullSell", "freediscard"],
	["emptyAtk", "emptyMult", "emptyGrow", "mult2", "atk15"],
]

var main: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _run() -> void:
	for i in 5:
		await process_frame
	var singles: Array = []
	for item in ShopManager.ARTIFACT_CATALOG:
		singles.append([item["type"]])
	for board in BOARDS:
		for set in singles + COMBOS:
			_case(board, set)
	print("REGRESS_DONE")
	quit()


func _catalog(type_key: String) -> Dictionary:
	for item in ShopManager.ARTIFACT_CATALOG:
		if item["type"] == type_key:
			return item.duplicate(true)
	return {}


func _setup(board_key: String, set: Array) -> void:
	seed(4242)
	main.start_new_game()
	seed(777)
	var b: Dictionary = BOARDS[board_key]
	main.TILE_DIR.assign(b["dirs"] if not b["dirs"].is_empty() else main.DEFAULT_TILE_DIR)
	main.placed_cards.clear()
	var id := 7000
	for idx in b["cards"]:
		var c: Array = b["cards"][idx]
		main.placed_cards[idx] = {"id": id, "color": c[0], "dir": c[1], "is_blank": false, "gold": c.size() > 2}
		id += 1
	main.chaos_mult_tiles.clear()
	main.chaos_xmult_tiles.clear()
	main.chaos_xatk_tiles.clear()
	for t in b.get("mtile", []): main.chaos_mult_tiles[t] = true
	for t in b.get("xmult", []): main.chaos_xmult_tiles[t] = true
	for t in b.get("xatk", []): main.chaos_xatk_tiles[t] = true
	main.chaos = [{"kind": "mtile"}, null, null]
	for i in main.artifacts.size():
		main.artifacts[i] = _catalog(set[i]) if i < set.size() else null
	main.sync_totems()
	main.coins = 23


func _case(board_key: String, set: Array) -> void:
	_setup(board_key, set)
	var out: Array[String] = []
	out.append("grp=%d" % int(main.calculate_groups()["base_dmg"]))
	# Walk: pre-walk hook, route, landing hooks, totems, final attack.
	main.begin_walk_damage()
	main.is_busy = true
	var route: Array[String] = []
	var fired: Array[String] = []
	for step in main.battle_mgr.build_walk_steps():
		var idx: int = step["tile"]
		route.append("%s%d%s" % ["h" if step["helper"] else "", idx, ("!" + step["fx"]) if step["fx"] != "" else ""])
		if main.placed_cards.has(idx):
			var times := 2 if main.placed_cards[idx].get("gold", false) else 1
			for k in times:
				var r: Dictionary = main.apply_tile_walk_effects(idx, step["helper"])
				fired.append("%d:%d+%d%s" % [idx, r["gain"], r["extra"], ",".join(r["fired"])])
		if main.totem_tiles.has(idx):
			main.walk_base_damage += main.totem_attack(idx)
	out.append("route=" + " ".join(route))
	out.append("land=" + " ".join(fired))
	out.append("walk=%d/%s" % [main.walk_base_damage, main.fmt_num(main.walk_mult_bonus)])
	var steps: Array = []
	var atk: Dictionary = main.compute_attack(steps)
	var st: Array[String] = []
	for s in steps:
		st.append("%d:%s/%s" % [s["slot"], main.fmt_num(s["atk"]), main.fmt_num(s["mult"])])
	out.append("atk=%d/%s/%d" % [atk["atk"], main.fmt_num(atk["mult"]), atk["dmg"]])
	out.append("steps=" + " ".join(st))
	main.is_busy = false
	# Chaos use.
	main.chaos[0] = {"kind": "mtile"}
	main._finish_chaos(0, "")
	# Victory reward.
	var before: int = main.coins
	main.walks_left = 2
	main.discards_left = 2
	main.on_victory()
	out.append("win=+%d" % (main.coins - before))
	# Shop: sell price, stone upgrade, next round discards.
	var sells: Array[String] = []
	for a in main.artifacts:
		if a != null:
			sells.append(str(main.shop_mgr.get_sell_price(a)))
	out.append("sell=" + ",".join(sells))
	main.coins = 50
	main.shop_mgr.shop_bought.clear()
	main.shop_mgr.buy_stone_upgrade(0, ShopManager.STONE_UPGRADE_PRICE)
	main.shop_mgr.on_shop_leave()
	out.append("disc=%d" % main.discards_left)
	var ms: Array[String] = []
	for a in main.artifacts:
		if a != null and a.has("m"):
			ms.append("%s=%s" % [a["type"], main.fmt_num(float(a["m"]))])
	out.append("m=" + ",".join(ms))
	var chaos_kinds: Array[String] = []
	for c in main.chaos:
		chaos_kinds.append(c["kind"] if c != null else "-")
	out.append("chaos=" + ",".join(chaos_kinds))
	print("CASE %s [%s] %s" % [board_key, ",".join(set), " | ".join(out)])
