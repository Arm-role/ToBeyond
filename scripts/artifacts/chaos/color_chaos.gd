class_name ColorChaos
extends ChaosEffect
## Turns up to 2 hand Gems into the card's colour for the rest of the game.


func use_hand(main: Node, card: Dictionary, picked: Array[Dictionary]) -> Dictionary:
	if picked.is_empty():
		return fail("เลือก Gem ในมือก่อน (สูงสุด 2 ใบ)")
	if picked.size() > 2:
		return fail("เปลี่ยนสีได้สูงสุด 2 ใบ")
	var col_th: String = ShopManager.COL_TH.get(card["col"], "")
	if picked.all(func(c): return c["color"] == card["col"]):
		return fail("Gem ที่เลือกเป็นสี%sอยู่แล้ว" % col_th)
	for gem in picked:
		if gem.get("is_blank", false):
			continue
		main.deck_mods.append({"from": gem["color"], "dir": gem["dir"], "to": card["col"], "to_dir": gem["dir"]})
		gem["color"] = card["col"]
	return done("🎨 เปลี่ยนเป็นสี%sถาวร" % col_th)
