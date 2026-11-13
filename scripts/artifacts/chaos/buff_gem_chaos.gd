class_name BuffGemChaos
extends ChaosEffect
## Gives one hand Gem a permanent buff that triggers after the walk (before the
## Artifacts): card["buffs"][buff_type] += amount. Stacks when used again.
## Buff types are resolved in BattleManager._trigger_gem_buffs ("mult" so far).

@export var buff_type: String = "mult"
@export var amount: int = 1


func use_hand(main: Node, _card: Dictionary, picked: Array[Dictionary]) -> Dictionary:
	if picked.size() != 1 or picked[0].get("is_blank", false):
		return fail("เลือก Gem ในมือ 1 ใบก่อน")
	var gem: Dictionary = picked[0]
	# Fresh dict: crystal cards are copied with duplicate() (shallow).
	var buffs: Dictionary = gem.get("buffs", {}).duplicate()
	buffs[buff_type] = int(buffs.get(buff_type, 0)) + amount
	gem["buffs"] = buffs
	# Remembered for rebuilds by id; only the 48 base-deck cards have stable ids.
	if int(gem["id"]) < main.COLOR_ORDER.size() * main.DIR_ORDER.size() * 3:
		main.buff_mods.append({"id": int(gem["id"]), "type": buff_type, "amount": amount})
	return done("🔺 Gem ใบนี้ได้ buff MULT +%d ถาวร" % amount)
