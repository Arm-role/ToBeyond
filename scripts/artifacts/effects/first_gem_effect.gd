extends ArtifactEffect
## ก้าวแรก: the first Gem the fireball reaches counts its ATK as n+(n-1)+…+1.
## Helper passes don't use it up; a gold Gem's second landing repeats it.


func land(ctx: ArtifactContext, _count: int) -> bool:
	var m := ctx.main
	if ctx.helper_pass or (m.first_gem_triggered and m.first_gem_tile != ctx.tile_idx):
		return false
	m.first_gem_triggered = true
	m.first_gem_tile = ctx.tile_idx
	ctx.extra = int(ctx.gain * (ctx.gain + 1) / 2) - ctx.gain
	m.walk_base_damage += ctx.extra
	return true
