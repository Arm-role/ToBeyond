class_name CounterEffect
extends ArtifactEffect
## Data-only permanent counter: on `hook`, the copy's "m" grows by
## amount × source (skipped when that is 0). Read it back with a StatEffect
## whose source is "counter".

@export_enum("chaos_used", "pre_walk", "victory", "stone_upgrade", "round_start") var hook: String = "chaos_used"
@export var amount: float = 1.0
@export var source: String = "one"
## For source matching_groups / matching_cards.
@export var dir: String = ""  # "" = any/none
@export var color: String = ""  # "" = any/none
## Value of "m" before the card has one.
@export var start: float = 0.0
## 0 keeps "m" an integer; otherwise the result is rounded to this step (0.1 like the draft).
@export var snap: float = 0.0


func chaos_used(ctx: ArtifactContext, art: Dictionary) -> bool: return _grow(ctx, art, "chaos_used")
func pre_walk(ctx: ArtifactContext, art: Dictionary) -> bool: return _grow(ctx, art, "pre_walk")
func victory(ctx: ArtifactContext, art: Dictionary) -> bool: return _grow(ctx, art, "victory")
func stone_upgrade(ctx: ArtifactContext, art: Dictionary) -> bool: return _grow(ctx, art, "stone_upgrade")
func round_start(ctx: ArtifactContext, art: Dictionary) -> bool: return _grow(ctx, art, "round_start")


func _grow(ctx: ArtifactContext, art: Dictionary, when: String) -> bool:
	if when != hook:
		return false
	var n: float = ctx.source(source, art, 0.0, dir, color)
	if n == 0.0:
		return false
	if snap > 0.0:
		art["m"] = snappedf(float(art.get("m", start)) + amount * n, snap)
	else:
		art["m"] = int(art.get("m", start)) + int(amount * n)
	return true
