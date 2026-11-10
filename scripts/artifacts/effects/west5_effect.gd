extends ArtifactEffect
## แนวตะวันตก: with 5+ West tiles in a row, landing on a West Gem adds its ATK to the multiplier.

@export var run_length: int = 5


func land(ctx: ArtifactContext, _count: int) -> bool:
	if ctx.card.get("dir", "") != "W" or ctx.gain <= 0 or ctx.dir_run("W") < run_length:
		return false
	ctx.main.walk_mult_bonus += ctx.gain
	return true
