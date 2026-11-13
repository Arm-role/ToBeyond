class_name ChaosData
extends Resource
## One Chaos card sold in the shop (res://data/chaos/*.tres). What the card
## does is the `effect` resource (ChaosEffect subclasses in scripts/artifacts/chaos/).

@export_enum("color", "dirc", "tdir", "mtile", "xmult", "xatk", "goldify", "destroy", "crystal", "buffmult") var kind: String = "color"
@export var col: String = ""  # "" = any/none
@export var dir: String = ""  # "" = any/none
## Stable key of the card (file name without the number prefix), e.g. "color_red", "xmult".
@export var id: String = ""
@export var name: String = ""
@export var icon: String = ""
@export var price: int = 5
@export var color: Color = Color.WHITE
@export var catalog_order: int = 0
## What the card does (see ChaosEffect).
@export var effect: ChaosEffect
## Texts and look (Thai text from the draft, written out in full).
@export var label: String = ""          # short text on slots and cards
@export var title: String = ""          # card name in the shop and dialogs
@export_multiline var desc: String = ""
@export var card_bg: Color = Color("#a66cf2")   # shop card background
@export var slot_bg: Color = Color("#7b4fc9")   # HUD slot background
@export var text_color: Color = Color.WHITE
## "chaos:<key>" = GameAssets.CHAOS_TEX, "emblem:<N|E|S|W>" = direction emblem, "" = no cover (cover_text is shown).
@export var cover_key: String = ""
@export var cover_text: String = ""
@export var slot_prefix: String = ""    # put before `label` on slots when there is no cover


func make_offer() -> Dictionary:
	var d := {"id": id, "kind": kind, "name": name, "icon": icon, "price": price, "color": color}
	if col != "":
		d["col"] = col
	if dir != "":
		d["dir"] = dir
	return d


## The owned card: what the player holds in a Chaos slot.
func make_card() -> Dictionary:
	var d := {"id": id, "kind": kind}
	if col != "":
		d["col"] = col
	if dir != "":
		d["dir"] = dir
	return d


func cover() -> Texture2D:
	var parts := cover_key.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "emblem":
		return GameAssets.EMBLEMS.get(parts[1])
	return GameAssets.CHAOS_TEX.get(parts[1])
