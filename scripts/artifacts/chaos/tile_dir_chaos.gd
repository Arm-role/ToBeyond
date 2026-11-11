class_name TileDirChaos
extends ChaosEffect
## Changes the direction of a board tile for the rest of the game.


func _init() -> void:
	needs_tile = true


func use_tile(main: Node, card: Dictionary, tile_idx: int) -> Dictionary:
	if main.TILE_DIR[tile_idx] == card["dir"]:
		return fail("ช่องนี้เป็นทิศ%sอยู่แล้ว" % ShopManager.DIR_TH.get(card["dir"], ""))
	main.TILE_DIR[tile_idx] = card["dir"]
	return done()
