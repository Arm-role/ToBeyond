extends ArtifactEffect
## แนวเหนือ: multiplier ^ (1 + per_tile × North tiles), ^full_power when the whole board is North.

@export var per_tile: float = 0.12
@export var full_power: float = 2.0


func attack(ctx: ArtifactContext, _art: Dictionary) -> bool:
	var n := ctx.dir_count("N")
	if n <= 0:
		return false
	ctx.mult = pow(ctx.mult, full_power if n >= ctx.main.N_TILES else 1.0 + per_tile * n)
	return true
