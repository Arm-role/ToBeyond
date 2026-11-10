extends ArtifactEffect
## เขียวนำโชค: landing on a green Gem has a `chance` to give `coins` coins.

@export var chance: float = 1.0 / 3.0
@export var coins: int = 1


func land(ctx: ArtifactContext, _count: int) -> bool:
	if ctx.card.get("color") != "green":
		return false
	if randf() < chance:
		ctx.main.coins += coins
		ctx.coin_won = true
		ctx.main.update_all_ui()
	return true
