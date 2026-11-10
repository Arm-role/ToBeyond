extends ArtifactEffect
## แนวตะวันออก: landing on an East Gem multiplies the multiplier by
## 1 + per_tile × East tiles (full_factor when the whole board is East).

@export var per_tile: float = 0.1
@export var full_factor: float = 2.0


func land(ctx: ArtifactContext, _count: int) -> bool:
	if ctx.card.get("dir", "") != "E":
		return false
	var n := ctx.dir_count("E")
	var f: float = full_factor if n >= ctx.main.N_TILES else 1.0 + per_tile * n
	ctx.main.walk_mult_bonus = (1.0 + ctx.main.walk_mult_bonus) * f - 1.0
	return true
