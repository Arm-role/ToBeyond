extends ArtifactEffect
## แนวใต้: with 5+ South tiles in a row, ATK × multiplier becomes the ATK and
## the multiplier resets to 1, before every other attack card (draft order).

@export var run_length: int = 5


func attack_early(ctx: ArtifactContext, _art: Dictionary) -> bool:
	if ctx.dir_run("S") < run_length:
		return false
	ctx.atk *= ctx.mult
	ctx.mult = 1.0
	return true
