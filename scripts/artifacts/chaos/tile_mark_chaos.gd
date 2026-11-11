class_name TileMarkChaos
extends ChaosEffect
## Marks a board tile. `state_var` names the Dictionary on main (tile index ->
## true) that board_calc / ui_renderer read: chaos_mult_tiles, chaos_xmult_tiles
## or chaos_xatk_tiles.

@export var state_var: StringName = &"chaos_mult_tiles"


func _init() -> void:
	needs_tile = true


func use_tile(main: Node, _card: Dictionary, tile_idx: int) -> Dictionary:
	var marks: Dictionary = main.get(state_var)
	if marks.has(tile_idx):
		return fail("ช่องนี้มี Chaos ชนิดนี้แล้ว")
	marks[tile_idx] = true
	return done()
