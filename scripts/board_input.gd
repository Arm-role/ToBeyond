class_name BoardInput
extends RefCounted

## Tile click, discard and drag-drop card moves (moved out of ChaosController
## so the Chaos system can be removed without touching card input).
## State stays on main. The Chaos branches below go away with Chaos (plan-gem-types P3).

var _main: Node

func _init(main: Node) -> void:
	_main = main


func on_tile_clicked(tile_idx: int) -> void:
	if _main.is_busy: return
	if _main.selected_chaos_slot >= 0:
		_main.chaos_ctl.apply_to_tile(tile_idx)
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
