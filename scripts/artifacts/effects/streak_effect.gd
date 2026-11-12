class_name StreakEffect
extends ArtifactEffect
## Streak counter: each Gem placed from the hand with `dir` adds `amount` to
## the copy's "m"; any other Gem resets it to 0. Read it with a StatEffect
## whose source is "counter".

@export var dir: String = "N"
@export var amount: int = 1


func card_played(ctx: ArtifactContext, art: Dictionary) -> bool:
	if ctx.card.get("dir", "") == dir:
		art["m"] = int(art.get("m", 0)) + amount
		return true
	art["m"] = 0
	return false
