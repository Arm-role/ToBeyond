extends ArtifactEffect
## โดดเดี่ยว: landing on a Gem with no Gem on either side adds its power to the walk's ATK again.


func land(ctx: ArtifactContext, _count: int) -> bool:
	if ctx.has_gem(ctx.tile_idx - 1) or ctx.has_gem(ctx.tile_idx + 1):
		return false
	ctx.main.walk_base_damage += ctx.gain
	ctx.extra += ctx.gain
	return true
