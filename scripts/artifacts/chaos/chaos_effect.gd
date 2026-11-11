class_name ChaosEffect
extends Resource
## Base class of what a Chaos card does (data/chaos/*.tres -> `effect`).
## Hand cards run use_hand(); cards with needs_tile = true are selected first
## and run use_tile() when a board tile is tapped. Both return
## {"ok": bool, "msg": String}. On ok = false nothing may have been changed and
## msg is shown as the error toast; on ok = true msg is the success toast
## ("" = none). `card` is the owned card dict (kind, col?, dir?).

## Tap the card, then a board tile.
@export var needs_tile: bool = false
## False = the controller refuses blank cards in the selection.
@export var allow_blank: bool = false


func use_hand(_main: Node, _card: Dictionary, _picked: Array[Dictionary]) -> Dictionary:
	return fail("")


func use_tile(_main: Node, _card: Dictionary, _tile_idx: int) -> Dictionary:
	return fail("")


static func fail(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}


static func done(msg: String = "") -> Dictionary:
	return {"ok": true, "msg": msg}
