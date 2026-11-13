extends SceneTree
## Uses every Chaos card (hand and tile cards, valid and invalid picks) and
## prints the resulting game state per case. Run before and after a Chaos
## refactor and diff the output:
##   godot --headless --path . --script res://tools/parity/chaos_use.gd > out.txt

var main: Node


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _state(tag: String) -> void:
	var hand: Array[String] = []
	for c in main.hand:
		hand.append("%s%s%s%s%s" % [c["color"].substr(0, 2), c["dir"], "b" if c.get("is_blank", false) else "", "g" if c.get("gold", false) else "", "*" if main.selected_card_ids.has(c["id"]) else ""])
	var chaos_kinds: Array[String] = []
	for c in main.chaos:
		chaos_kinds.append(str(c.get("kind", "?")) + str(c.get("col", "")) + str(c.get("dir", "")) if c != null else "-")
	print("%s | msg=%s | toast=%s | chaos=%s | hand=%s | mods=%s gold=%s rem=%s | dirs=%s | m=%s x=%s a=%s cry=%s | placed=%s | sel=%d" % [
		tag, main.msg_label.text, (main._chaos_toast.get_child(0) as Label).text if main._chaos_toast != null else "", chaos_kinds, hand, main.deck_mods.size(), main.gold_mods.size(), main.deck_removals.size(),
		"".join(main.TILE_DIR), main.chaos_mult_tiles.keys(), main.chaos_xmult_tiles.keys(), main.chaos_xatk_tiles.keys(),
		main.chaos_crystals, main.placed_cards.keys(), main.selected_chaos_slot])


func _fresh(card: Dictionary) -> void:
	seed(99)
	main.start_new_game()
	main.is_busy = false
	main.msg_label.text = ""
	main.chaos = [card, null, null]
	main.selected_chaos_slot = -1
	main.selected_card_ids.clear()


func _pick(idx: Array) -> void:
	main.selected_card_ids.clear()
	for i in idx:
		main.selected_card_ids.append(main.hand[i]["id"])


func _run() -> void:
	for i in 5:
		await process_frame
	for def in ShopManager.CHAOS_CATALOG:
		var card := {"kind": def["kind"]}
		if def.has("col"): card["col"] = def["col"]
		if def.has("dir"): card["dir"] = def["dir"]
		var tag: String = def["kind"] + str(def.get("col", "")) + str(def.get("dir", ""))
		for picks in [[], [0], [0, 1], [0, 1, 2]]:
			_fresh(card.duplicate())
			_pick(picks)
			main._on_chaos_slot_pressed(0)
			_state("%s hand%s" % [tag, picks])
		# blank card in the selection
		_fresh(card.duplicate())
		main.hand[1]["is_blank"] = true
		_pick([0, 1])
		main._on_chaos_slot_pressed(0)
		_state(tag + " blank")
		# already gold / already same
		_fresh(card.duplicate())
		main.hand[0]["gold"] = true
		main.hand[0]["buffs"] = {"mult": 1}  # buffmult: already buffed -> refused (no stacking)
		main.hand[0]["color"] = card.get("col", main.hand[0]["color"])
		main.hand[0]["dir"] = card.get("dir", main.hand[0]["dir"])
		_pick([0])
		main._on_chaos_slot_pressed(0)
		_state(tag + " same")
		# tile cards: select, tap tiles (empty, same again, placed, crystal)
		_fresh(card.duplicate())
		main.placed_cards[3] = main.hand.pop_front()
		main._on_chaos_slot_pressed(0)
		_state(tag + " sel")
		for t in [0, 0, 3, 1]:
			main._on_tile_clicked(t)
			_state("%s tile%d" % [tag, t])
		main._on_chaos_slot_pressed(0)
		_state(tag + " resel")
		main._on_chaos_slot_pressed(0)
		_state(tag + " desel")
	print("CHAOS_USE_DONE")
	quit()
