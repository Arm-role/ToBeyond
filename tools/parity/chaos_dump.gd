extends SceneTree
## Prints every Chaos card's label, title, description and look (one line per
## card). Run before and after a Chaos refactor and diff the output:
##   godot --headless --path . --script res://tools/parity/chaos_dump.gd > out.txt

func _initialize() -> void:
	GameAssets.load_all(8)
	var shop := ShopManager.new(null)
	for def in ShopManager.CHAOS_CATALOG:
		var card := {"kind": def["kind"]}
		if def.has("col"):
			card["col"] = def["col"]
		if def.has("dir"):
			card["dir"] = def["dir"]
		var look: Dictionary = shop._chaos_card_look(card)
		var slot_bg := Color("#7b4fc9")
		slot_bg = {"goldify": Color("#e8bf4c"), "tdir": Color("#23978e"), "destroy": Color("#b73e3d")}.get(card["kind"], slot_bg)
		if card["kind"] == "color":
			slot_bg = GameAssets.COLORS.get(card.get("col", ""), slot_bg)
		var cover_text: String = {"xmult": "×1.2", "xatk": "×1.2"}.get(card["kind"], def.get("icon", ""))
		var slot_text: String = ShopManager.chaos_label(card) if look["cover"] != null else "×1.2\n" + ShopManager.chaos_label(card)
		print("%s|%s|%s|%s|bg=%s|text=%s|cover=%s|slot_bg=%s|cover_text=%s|slot_text=%s|price=%s|icon=%s|order=%s" % [
			card, ShopManager.chaos_label(card), ShopManager.chaos_name(card), ShopManager.chaos_desc(card),
			look["bg"], look["text"], look["cover"].resource_path if look["cover"] != null else "-", slot_bg,
			cover_text, slot_text, def["price"], def["icon"], def.get("color", "")])
	quit()
