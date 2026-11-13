class_name RewardFlow
extends RefCounted

## Victory payout and reward summary rows, moved from main.gd. State stays on main.

var _main: Node

func _init(main: Node) -> void:
	_main = main


func on_victory() -> void:
	_main.is_busy = false
	_main.msg_label.text = "ชนะ!"

	# Matching draft reward: base + walks + interest + reward artifacts.
	var base_reward = 4
	var interest = mini(10, int(_main.coins / 5))
	var walk_reward = _main.walks_left
	var rewards: Dictionary = _main.artifact_sys.victory()
	var arti_pay: int = rewards["rows"].get("arti", 0)
	var fate_pay: int = rewards["rows"].get("fate", 0)
	var walk_coin_bonus: int = rewards["rows"].get("walk", 0)
	var reward_fx: Array = rewards["fx"]
	if _main.is_boss() and _main.artifacts.has(null):
		var drops: Array[Dictionary] = ShopManager.get_unowned_artifact_offers(_main.artifacts, 1)
		if not drops.is_empty():
			_main.artifacts[_main.artifacts.find(null)] = drops[0]
			_main.sync_totems()
			_main.msg_label.text = "🎁 บอสทิ้ง Artifact: %s" % ShopManager.display_name(drops[0])
	var total_gain = base_reward + walk_reward + interest + int(rewards["total"])
	_main.coins += total_gain
	if not reward_fx.is_empty():
		# The artifact row is hidden behind the reward panel, so show it paying out first.
		_main.render_artifact_row()
		await _main.battle_mgr.fx_artifact_types(reward_fx)
		await _main.get_tree().create_timer(0.45 / _main.speed_multiplier).timeout
	_main.sfx.play("coin")

	VfxManager.coin_rain(_main.effects_layer, clampi(total_gain * 3, 12, 40), _main.size.x * 0.6)
	render_summary(base_reward, _main.walks_left, walk_reward, _main.coins - total_gain, interest, total_gain, arti_pay, fate_pay, walk_coin_bonus)
	_main.update_all_ui()
	_main.reward_modal.visible = true
	# Same as the shop: slide up from the bottom, stop at the preview/gameplay divider.
	var top: float = _main.get_node("Preview").offset_bottom
	_main.reward_modal.offset_top = _main.size.y
	var slide: Tween = _main.reward_modal.create_tween()
	slide.tween_property(_main.reward_modal, "offset_top", top, 0.35 / _main.speed_multiplier) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func render_summary(base_reward: int, walks_remaining: int, walk_reward: int, held_coins: int, interest: int, total_gain: int, arti_pay: int = 0, fate_pay: int = 0, walk_coin_bonus: int = 0) -> void:
	for child in _main.reward_info.get_children():
		child.queue_free()
	add_row("ชนะศัตรู", "🪙 +%d" % base_reward)
	add_row("เลือดที่เหลือ (รับได้อีก %d ครั้ง) × 1" % walks_remaining, "🪙 +%d" % walk_reward)
	add_row("ดอกเบี้ย (มี %d ÷ 5 · สูงสุด 10)" % held_coins, "🪙 +%d" % interest)
	if arti_pay > 0:
		add_row("รายได้ Artifact", "🪙 +%d" % arti_pay)
	if fate_pay > 0:
		add_row("รายได้ Gem", "🪙 +%d" % fate_pay)
	if walk_coin_bonus > 0:
		add_row("เดินประหยัด", "🪙 +%d" % walk_coin_bonus)
	add_row("รวม", "🪙 +%d" % total_gain, true)


func add_row(left_text: String, right_text: String, is_total: bool = false) -> void:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0, 0, 0, 0)
	if not is_total:
		row_style.border_width_bottom = 1
		row_style.border_color = Color(0.827451, 0.65098, 0.290196, 0.3)
	row_style.content_margin_left = 6.0
	row_style.content_margin_top = 12.0
	row_style.content_margin_right = 6.0
	row_style.content_margin_bottom = 12.0
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	row.add_child(hbox)
	var left := Label.new()
	left.text = left_text
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_font_size_override("font_size", 36 if is_total else 27)
	if is_total:
		left.theme_type_variation = &"BoldLabel"
	left.add_theme_color_override("font_color", Color("#f0cf86") if is_total else Color("#f3ead7"))
	hbox.add_child(left)
	var right := Label.new()
	right.text = right_text
	right.add_theme_font_size_override("font_size", 36 if is_total else 27)
	if is_total:
		right.theme_type_variation = &"BoldLabel"
	right.add_theme_color_override("font_color", Color("#f0cf86") if is_total else Color("#f3ead7"))
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(right)
	_main.reward_info.add_child(row)
