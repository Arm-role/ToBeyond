class_name CrystalChaos
extends ChaosEffect
## Puts a Gem crystal on an empty tile.


func _init() -> void:
	needs_tile = true


func use_tile(main: Node, _card: Dictionary, tile_idx: int) -> Dictionary:
	if main.placed_cards.has(tile_idx) or main.chaos_crystals.has(tile_idx):
		return fail("วางผลึกได้เฉพาะช่องว่าง")
	main.chaos_crystals[tile_idx] = main.CRYSTAL_HP
	return done()
