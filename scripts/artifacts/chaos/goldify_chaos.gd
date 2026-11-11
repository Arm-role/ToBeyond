class_name GoldifyChaos
extends ChaosEffect
## Makes one hand Gem a permanent gold card.


func use_hand(main: Node, _card: Dictionary, picked: Array[Dictionary]) -> Dictionary:
	if picked.size() != 1:
		return fail("เลือก Gem ในมือ 1 ใบก่อน")
	if picked[0].get("gold", false):
		return fail("ใบนี้เป็นการ์ดทองอยู่แล้ว")
	picked[0]["gold"] = true
	main.gold_mods.append({"color": picked[0]["color"], "dir": picked[0]["dir"]})
	return done("✨ เป็นการ์ดทองถาวร")
