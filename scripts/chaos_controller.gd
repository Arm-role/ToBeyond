class_name ChaosController
extends RefCounted

## Chaos use, tile click and discard, moved from main.gd. State stays on main.

var _main: Node

func _init(main: Node) -> void:
	_main = main


func on_slot_pressed(slot_idx: int) -> void:
	if _main.shop_modal.visible:
		_main.shop_mgr.confirm_sell_chaos(slot_idx)
		return
	if _main.is_busy or slot_idx < 0 or slot_idx >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	var effect := _effect_of(chaos_card)
	if effect == null:
		return
	if effect.needs_tile:
		_main.selected_chaos_slot = -1 if _main.selected_chaos_slot == slot_idx else slot_idx
		_main.chaos_msg("แตะช่องที่ต้องการวาง" if _main.selected_chaos_slot >= 0 else "ยกเลิกแล้ว")
		_main.update_all_ui()
		return
	apply_hand(slot_idx)


func _effect_of(chaos_card: Dictionary) -> ChaosEffect:
	var definition := ArtifactSystem.chaos_def(chaos_card)
	return definition.effect if definition != null else null


func apply_hand(slot_idx: int) -> void:
	var chaos_card = _main.chaos[slot_idx]
	if chaos_card == null:
		return
	var effect := _effect_of(chaos_card)
	if effect == null:
		return
	var picked: Array[Dictionary] = []
	for card in _main.hand:
		if _main.selected_card_ids.has(card["id"]):
			picked.append(card)
	if not effect.allow_blank and picked.any(func(c): return c.get("is_blank", false)):
		_main.chaos_msg("การ์ดเปล่าใช้ Chaos ไม่ได้")
		return
	_finish_use(effect.use_hand(_main, chaos_card, picked), slot_idx)


func apply_to_tile(tile_idx: int) -> void:
	if _main.selected_chaos_slot < 0 or _main.selected_chaos_slot >= _main.chaos.size():
		return
	var chaos_card = _main.chaos[_main.selected_chaos_slot]
	if chaos_card == null:
		_main.selected_chaos_slot = -1
		return
	var effect := _effect_of(chaos_card)
	if effect == null or not effect.needs_tile:
		return
	var result := effect.use_tile(_main, chaos_card, tile_idx)
	_finish_use(result, _main.selected_chaos_slot)
	if result["ok"]:
		_main.sfx.play("place")
		VfxManager.tile_glow(_main.tiles_container.get_child(tile_idx) as Control, Color("#ffd966"))


func _finish_use(result: Dictionary, slot_idx: int) -> void:
	if result["ok"]:
		finish(slot_idx, result["msg"])
	else:
		_main.chaos_msg(result["msg"])


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


## Drag-and-drop helpers (SlotDrag). All return true when something changed.
func place_from_hand(card_id: int, tile_idx: int) -> bool:
	if _main.is_busy or _main.chaos_crystals.has(tile_idx):
		return false
	var found = null
	for card in _main.hand:
		if card["id"] == card_id:
			found = card
			break
	if found == null:
		return false
	_main.hand.erase(found)
	if _main.placed_cards.has(tile_idx):
		_main.hand.append(_main.placed_cards[tile_idx])
	_main.placed_cards[tile_idx] = found
	_main.artifact_sys.card_played(found)
	_main.selected_card_ids.clear()
	_main.update_all_ui()
	_main.refresh_calc()
	_main.pop_tile_anim(tile_idx)
	return true


func move_board_card(from_tile: int, to_tile: int) -> bool:
	if _main.is_busy or from_tile == to_tile or not _main.placed_cards.has(from_tile) or _main.chaos_crystals.has(to_tile):
		return false
	var held = _main.placed_cards[from_tile]
	if _main.placed_cards.has(to_tile):
		_main.placed_cards[from_tile] = _main.placed_cards[to_tile]
	else:
		_main.placed_cards.erase(from_tile)
	_main.placed_cards[to_tile] = held
	_main.update_all_ui()
	_main.refresh_calc()
	_main.pop_tile_anim(to_tile)
	return true


func return_board_card(tile_idx: int) -> bool:
	if _main.is_busy or not _main.placed_cards.has(tile_idx):
		return false
	if _main.hand.size() >= _main.hand_max:
		_main.msg_label.text = "มือเต็ม เอา Gem กลับไม่ได้"
		return false
	_main.hand.append(_main.placed_cards[tile_idx])
	_main.placed_cards.erase(tile_idx)
	_main.update_all_ui()
	_main.refresh_calc()
	return true
