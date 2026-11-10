class_name ChaosData
extends Resource
## One Chaos card sold in the shop (res://data/chaos/*.tres). What the card
## does is keyed by `kind` in main.gd (_apply_hand_chaos / _apply_chaos_to_tile).

@export_enum("color", "dirc", "tdir", "mtile", "xmult", "xatk", "goldify", "destroy", "crystal") var kind: String = "color"
@export var col: String = ""  # "" = any/none
@export var dir: String = ""  # "" = any/none
@export var name: String = ""
@export var icon: String = ""
@export var price: int = 5
@export var color: Color = Color.WHITE
@export var catalog_order: int = 0


func make_offer() -> Dictionary:
	var d := {"kind": kind, "name": name, "icon": icon, "price": price, "color": color}
	if col != "":
		d["col"] = col
	if dir != "":
		d["dir"] = dir
	return d
