extends ArtifactEffect
## ส้มแจก Chaos: before the walk, one random Chaos card per North Stone group of orange Gems.


func pre_walk(ctx: ArtifactContext, _art: Dictionary) -> bool:
	var n := ctx.matching_groups("N", "orange")
	for _i in range(n):
		ctx.main.give_random_chaos()
	if n <= 0:
		return false
	ctx.msg = "✨ Gem ส้มทิศเหนือสร้าง Chaos"
	return true
