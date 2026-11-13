extends Resource
## A boss definition, res://data/domino/bosses/<id>.tres. One rule per boss:
## `rule` names a built-in behaviour in DominoSim (twin_flag, obsidian, bulwark,
## drifter) or a view-only one (smoke); `args` tune it. `rules` are enemy rules
## run through the same engine, before the player's artifacts (source "enemy").

@export var id: String = ""
@export var name_th: String = ""
@export var icon: String = "👑"
@export_multiline var text_th: String = ""
@export var hp_mult: float = 1.5
@export var dmg_mult: float = 1.0
@export var rule: StringName = &""
@export var args: Dictionary = {}
@export var rules: Array[Resource] = []
@export var catalog_order: int = 0
