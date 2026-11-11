class_name DestroyChaos
extends ChaosEffect
## Removes two hand Gems from the deck for good (blank cards may be picked).


func _init() -> void:
	allow_blank = true


func use_hand(main: Node, _card: Dictionary, picked: Array[Dictionary]) -> Dictionary:
	if picked.size() != 2:
		return fail("เลือก Gem ในมือ 2 ใบก่อน")
	for gem in picked:
		if not gem.get("is_blank", false):
			main.deck_removals.append({"color": gem["color"], "dir": gem["dir"]})
		main.hand.erase(gem)
	return done("💥 ทำลาย Gem 2 ใบถาวร")
