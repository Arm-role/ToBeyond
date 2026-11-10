extends ArtifactEffect
## โดดเดี่ยว: landing on a Gem with no Gem on either side adds its ATK to the multiplier.


func land(ctx: ArtifactContext, _count: int) -> bool:
	if ctx.has_gem(ctx.tile_idx - 1) or ctx.has_gem(ctx.tile_idx + 1):
		return false
	ctx.main.walk_mult_bonus += ctx.gain
	ctx.extra += ctx.gain
	return true
