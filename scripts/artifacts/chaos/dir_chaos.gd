class_name DirChaos
extends ChaosEffect
## Turns one hand Gem to the card's direction for the rest of the game.


func use_hand(main: Node, card: Dictionary, picked: Array[Dictionary]) -> Dictionary:
	if picked.is_empty():
		return fail("เลือก Gem ในมือก่อน (1 ใบ)")
	if picked.size() > 1:
		return fail("เปลี่ยนทิศได้ทีละ 1 ใบ")
	var dir_th: String = ShopManager.DIR_TH.get(card["dir"], "")
	if picked[0]["dir"] == card["dir"]:
		return fail("Gem ที่เลือกเป็นทิศ%sอยู่แล้ว" % dir_th)
	var gem: Dictionary = picked[0]
	main.deck_mods.append({"from": gem["color"], "dir": gem["dir"], "to": gem["color"], "to_dir": card["dir"]})
	gem["dir"] = card["dir"]
	return done("🧭 เปลี่ยนเป็นทิศ%sถาวร" % dir_th)
