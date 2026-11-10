class_name ArtifactData
extends Resource
## One artifact definition (template). Lives in res://data/artifacts/<id>.tres
## and is never changed at runtime: what a player owns is a Dictionary made by
## make_instance(), which also carries the per-copy counter "m".

@export var id: String = ""
## Shop card fields (from the draft's ITEMS list).
@export var name: String = ""
@export var icon: String = ""
@export_multiline var desc: String = ""
@export var color: Color = Color.WHITE
@export var price: int = 6
@export var rarity: String = "common"  # common | uncommon | rare | "" (not in shop)
## Draft names/descriptions shown on cards and dialogs (empty = use name/desc).
@export var draft_name: String = ""
@export_multiline var draft_desc: String = ""
## False keeps it out of shop offers and the artifact list (unfinished in the draft).
@export var in_draft_pool: bool = true
## Starting value of the per-copy counter "m"; has_counter = false leaves "m" out.
@export var has_counter: bool = false
@export var start_m: float = 0.0
@export var counter_float: bool = false
## Cover art; without it the card shows emblem_dir's direction emblem.
@export var texture: Texture2D
@export var emblem_dir: String = ""  # "" = any/none
## Position in the catalog (shop pool order).
@export var catalog_order: int = 0
## Resolution order among landing effects of different types (smaller first).
@export var order: int = 0
## What the artifact does. Each effect answers the hooks it cares about.
@export var effects: Array[Resource] = []


func make_instance() -> Dictionary:
	var d := {"type": id, "name": name, "icon": icon, "desc": desc, "color": color, "price": price}
	if has_counter:
		d["m"] = start_m if counter_float else int(start_m)
	return d


func grants(rule: StringName) -> bool:
	for e in effects:
		if e is ArtifactEffect and (e as ArtifactEffect).grants(rule):
			return true
	return false
