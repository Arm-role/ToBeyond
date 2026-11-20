extends Resource
## A Domino artifact definition (template), res://data/domino/artifacts/<id>.tres.
## Never changed at runtime.

@export var id: String = ""
@export var name_th: String = ""
@export var icon: String = ""
@export_multiline var text_th: String = ""
@export var archetype: String = "blaze"   # blaze | guard | route | ember
@export var rarity: String = "common"     # common | uncommon | rare
@export var price: int = 6
@export var catalog_order: int = 0
@export var attack_trace_bonus: int = 0  # adds to the mark left by an attack Gem
@export var trace_cap: int = 0    # enables accumulation up to this power
@export var rules: Array[Resource] = []
