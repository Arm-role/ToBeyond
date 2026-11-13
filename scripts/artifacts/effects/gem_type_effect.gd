class_name GemTypeEffect
extends ArtifactEffect
## Data-only landing bonus for one Gem colour: every landing on a Gem of
## `card_color` adds `amount` (× copies) to that colour's own track.
## red -> ATK, blue -> shield, green -> heal, orange -> gold coins.

@export_enum("red", "blue", "green", "orange") var card_color: String = "red"
@export var amount: int = 3


func land(ctx: ArtifactContext, count: int) -> bool:
	if ctx.card.get("color", "") != card_color:
		return false
	var v: int = amount * count
	match card_color:
		"red": ctx.main.walk_base_damage += v
		"blue": ctx.main.walk_block += v
		"green": ctx.main.walk_heal += v
		"orange":
			ctx.main.coins += v
			ctx.main.update_all_ui()
	ctx.extra += v
	return true
