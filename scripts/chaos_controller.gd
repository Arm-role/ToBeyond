class_name ChaosController
extends RefCounted

## Chaos use, tile click and discard, moved from main.gd. State stays on main.

var _main: Node

func _init(main: Node) -> void:
	_main = main


func on_slot_pressed(slot_idx: int) -> void:
	if _main.is_busy or slot_idx < 0 or slot_idx >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	var kind: String = chaos_card["kind"]
	if kind in ["tdir", "mtile", "xmult", "xatk", "crystal"]:
		_main.selected_chaos_slot = -1 if _main.selected_chaos_slot == slot_idx else slot_idx
		_main.chaos_msg("แตะช่องที่ต้องการวาง" if _main.selected_chaos_slot >= 0 else "ยกเลิกแล้ว")
		_main.update_all_ui()
		return
	apply_hand(slot_idx)


func apply_hand(slot_idx: int) -> void:
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	var picked: Array[Dictionary] = []
	for card in _main.hand:
		if _main.selected_card_ids.has(card["id"]):
			picked.append(card)
	var kind: String = chaos_card["kind"]
	if kind != "destroy" and picked.any(func(c): return c.get("is_blank", false)):
		_main.chaos_msg("การ์ดเปล่าใช้ Chaos ไม่ได้")
		return
	if kind == "color":
		if picked.is_empty():
			_main.chaos_msg("เลือก Gem ในมือก่อน (สูงสุด 2 ใบ)")
			return
		if picked.size() > 2:
			_main.chaos_msg("เปลี่ยนสีได้สูงสุด 2 ใบ")
			return
		if picked.all(func(c): return c["color"] == chaos_card["col"]):
			_main.chaos_msg("Gem ที่เลือกเป็นสี%sอยู่แล้ว" % ShopManager.COL_TH.get(chaos_card["col"], ""))
			return
		for card in picked:
			if card.get("is_blank", false):
				continue
			_main.deck_mods.append({"from": card["color"], "dir": card["dir"], "to": chaos_card["col"], "to_dir": card["dir"]})
			card["color"] = chaos_card["col"]
		finish(slot_idx, "🎨 เปลี่ยนเป็นสี%sถาวร" % ShopManager.COL_TH.get(chaos_card["col"], ""))
	elif kind == "dirc":
		if picked.is_empty():
			_main.chaos_msg("เลือก Gem ในมือก่อน (1 ใบ)")
			return
		if picked.size() > 1:
			_main.chaos_msg("เปลี่ยนทิศได้ทีละ 1 ใบ")
			return
		if picked[0]["dir"] == chaos_card["dir"]:
			_main.chaos_msg("Gem ที่เลือกเป็นทิศ%sอยู่แล้ว" % ShopManager.DIR_TH.get(chaos_card["dir"], ""))
			return
		var card = picked[0]
		_main.deck_mods.append({"from": card["color"], "dir": card["dir"], "to": card["color"], "to_dir": chaos_card["dir"]})
		card["dir"] = chaos_card["dir"]
		finish(slot_idx, "🧭 เปลี่ยนเป็นทิศ%sถาวร" % ShopManager.DIR_TH.get(chaos_card["dir"], ""))
	elif kind == "goldify":
		if picked.size() != 1:
			_main.chaos_msg("เลือก Gem ในมือ 1 ใบก่อน")
			return
		if picked[0].get("gold", false):
			_main.chaos_msg("ใบนี้เป็นการ์ดทองอยู่แล้ว")
			return
		picked[0]["gold"] = true
		_main.gold_mods.append({"color": picked[0]["color"], "dir": picked[0]["dir"]})
		finish(slot_idx, "✨ เป็นการ์ดทองถาวร")
	elif kind == "destroy":
		if picked.size() != 2:
			_main.chaos_msg("เลือก Gem ในมือ 2 ใบก่อน")
			return
		for card in picked:
			if not card.get("is_blank", false):
				_main.deck_removals.append({"color": card["color"], "dir": card["dir"]})
			_main.hand.erase(card)
		finish(slot_idx, "💥 ทำลาย Gem 2 ใบถาวร")


func apply_to_tile(tile_idx: int) -> void:
	if _main.selected_chaos_slot < 0 or _main.selected_chaos_slot >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[_main.selected_chaos_slot]
	if chaos_card == null:
		_main.selected_chaos_slot = -1
		return
	var kind: String = chaos_card["kind"]
	if kind == "tdir":
		if _main.TILE_DIR[tile_idx] == chaos_card["dir"]:
			_main.chaos_msg("ช่องนี้เป็นทิศ%sอยู่แล้ว" % ShopManager.DIR_TH.get(chaos_card["dir"], ""))
			return
		_main.TILE_DIR[tile_idx] = chaos_card["dir"]
	elif kind == "mtile":
		if _main.chaos_mult_tiles.has(tile_idx):
			_main.chaos_msg("ช่องนี้มี Chaos ชนิดนี้แล้ว")
			return
		_main.chaos_mult_tiles[tile_idx] = true
	elif kind == "xmult":
		if _main.chaos_xmult_tiles.has(tile_idx):
			_main.chaos_msg("ช่องนี้มี Chaos ชนิดนี้แล้ว")
			return
		_main.chaos_xmult_tiles[tile_idx] = true
	elif kind == "xatk":
		if _main.chaos_xatk_tiles.has(tile_idx):
			_main.chaos_msg("ช่องนี้มี Chaos ชนิดนี้แล้ว")
			return
		_main.chaos_xatk_tiles[tile_idx] = true
	elif kind == "crystal":
		if _main.placed_cards.has(tile_idx) or _main.chaos_crystals.has(tile_idx):
			_main.chaos_msg("วางผลึกได้เฉพาะช่องว่าง")
			return
		_main.chaos_crystals[tile_idx] = _main.CRYSTAL_HP
	else:
		return
	finish(_main.selected_chaos_slot, "")


func finish(slot_idx: int, message: String) -> void:
	_main.chaos[slot_idx] = null
	_main.selected_chaos_slot = -1
	_main.selected_card_ids.clear()
	_main.artifact_sys.chaos_used()
	if message != "":
		_main.chaos_msg(message)
	_main.update_all_ui()
	_main.refresh_calc()


func hit_crystal(tile_idx: int) -> Dictionary:
	if not _main.chaos_crystals.has(tile_idx):
		return {"used": 0, "broken": false}
	var current_hp: int = _main.chaos_crystals[tile_idx]
	var incoming: int = maxi(1, _main.walk_base_damage)
	var used: int = mini(incoming, current_hp)
	_main.walk_base_damage = maxi(0, _main.walk_base_damage - used)
	current_hp -= used
	if current_hp > 0:
		_main.chaos_crystals[tile_idx] = current_hp
		_main.update_all_ui()
		return {"used": used, "broken": false}
	_main.chaos_crystals.erase(tile_idx)
	for _i in range(_main.CRYSTAL_GEMS):
		var color: String = _main.COLOR_ORDER[randi_range(0, _main.COLOR_ORDER.size() - 1)]
		var direction: String = _main.DIR_ORDER[randi_range(0, _main.DIR_ORDER.size() - 1)]
		var deck_card := {"id": _main.card_uid_counter, "color": color, "dir": direction, "is_blank": false, "gold": false}
		_main.card_uid_counter += 1
		_main.deck.append(deck_card)
		var hand_card := deck_card.duplicate()
		hand_card["id"] = _main.card_uid_counter
		_main.card_uid_counter += 1
		_main.hand.append(hand_card)
	_main.msg_label.text = "💎 ผลึกแตก! ได้ Gem +%d" % _main.CRYSTAL_GEMS
	_main.update_all_ui()
	return {"used": used, "broken": true}


func on_tile_clicked(tile_idx: int) -> void:
	if _main.is_busy: return
	if _main.selected_chaos_slot >= 0:
		apply_to_tile(tile_idx)
		return
	if _main.chaos_crystals.has(tile_idx):
		_main.msg_label.text = "ช่องนี้มีผลึก Gem วาง Gem ไม่ได้"
		return

	# Rule: If tile already has card, return it to _main.hand!
	if _main.placed_cards.has(tile_idx):
		if _main.hand.size() >= _main.hand_max:
			_main.msg_label.text = "มือเต็ม เอา Gem กลับไม่ได้"
			return
		var card = _main.placed_cards[tile_idx]
		_main.placed_cards.erase(tile_idx)
		_main.hand.append(card)
		_main.update_all_ui()
		_main.refresh_calc()
		return

	# If exactly one card selected in _main.hand, place it here
	if _main.selected_card_ids.size() == 1:
		var target_id = _main.selected_card_ids[0]
		var found_card = null
		for card in _main.hand:
			if card["id"] == target_id:
				found_card = card
				break
		if found_card != null:
			_main.hand.erase(found_card)
			_main.placed_cards[tile_idx] = found_card
			_main.selected_card_ids.clear()
			_main.update_all_ui()
			_main.refresh_calc()
			_main.pop_tile_anim(tile_idx)


func on_discard_pressed() -> void:
	if _main.is_busy or _main.selected_card_ids.is_empty() or _main.discards_left <= 0:
		return
	if _main.placed_cards.size() > 0 and not _main.artifact_sys.has_rule(&"free_discard"):
		_main.msg_label.text = "⚠️ วาง Gem แล้วทิ้งไม่ได้ (ดึง Gem กลับก่อน)"
		return

	_main.discards_left -= 1
	var to_remove = []
	for card in _main.hand:
		if _main.selected_card_ids.has(card["id"]):
			to_remove.append(card)
	for card in to_remove:
		_main.hand.erase(card)
	_main.selected_card_ids.clear()
	_main.draw_up_to_hand(_main.hand_max)
	_main.update_all_ui()
	_main.refresh_calc()
