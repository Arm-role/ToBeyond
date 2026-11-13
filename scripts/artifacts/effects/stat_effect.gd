class_name StatEffect
extends ArtifactEffect
## Data-only ATK change.
##   value = amount × source        (source: see ArtifactContext.source)
##   add:        stat += value
##   mul:        stat *= value      (amount × counter, or amount alone with source "one")
##   mul_linear: stat *= 1 + value
## hook "attack" fires once per copy in slot order; "land" fires once per type
## (value × copies) when the landing Gem matches card_dir / card_color.

@export_enum("attack", "land") var hook: String = "attack"
@export_enum("add", "mul", "mul_linear") var op: String = "add"
@export var amount: float = 1.0
@export var source: String = "one"
## Value of "counter" before the card has one.
@export var counter_fallback: float = 0.0
## Don't fire (and don't flash) when the source is 0.
@export var skip_if_zero: bool = false
@export var card_dir: String = ""  # "" = any/none
@export var card_color: String = ""  # "" = any/none


func attack(ctx: ArtifactContext, art: Dictionary) -> bool:
	if hook != "attack":
		return false
	return _apply(ctx, art, 1)


func land(ctx: ArtifactContext, count: int) -> bool:
	if hook != "land":
		return false
	if card_dir != "" and ctx.card.get("dir", "") != card_dir:
		return false
	if card_color != "" and ctx.card.get("color", "") != card_color:
		return false
	# Landing bonuses go to the walk totals, which the final attack starts from.
	ctx.atk = ctx.main.walk_base_damage
	var fired := _apply(ctx, {}, count)
	ctx.main.walk_base_damage = int(ctx.atk)
	return fired


func _apply(ctx: ArtifactContext, art: Dictionary, copies: int) -> bool:
	var src: float = ctx.source(source, art, counter_fallback)
	if skip_if_zero and src == 0.0:
		return false
	var value: float = amount * src * copies
	var x: float = ctx.atk
	match op:
		"add": x += value
		"mul": x *= value
		"mul_linear": x *= 1.0 + value
	ctx.atk = x
	return true
