class_name StreakEffect
extends ArtifactEffect
## Streak counter, once per walk. Gems placed from the hand are noted
## (card_played); right before the walk (pre_walk) the copy's "m" grows by
## `amount` if only `dir` Gems were placed since the last walk, or resets to 0
## if any other Gem was placed. A walk with no placing leaves "m" alone.
## Read it with a StatEffect whose source is "counter".

@export var dir: String = "N"
@export var amount: int = 1


func card_played(ctx: ArtifactContext, art: Dictionary) -> bool:
	if ctx.card.get("dir", "") == dir:
		art["pn"] = true
	else:
		art["po"] = true
	return false


func pre_walk(_ctx: ArtifactContext, art: Dictionary) -> bool:
	var other: bool = art.get("po", false)
	var north: bool = art.get("pn", false)
	art.erase("po")
	art.erase("pn")
	if other:
		var had: bool = int(art.get("m", 0)) != 0
		art["m"] = 0
		return had
	if north:
		art["m"] = int(art.get("m", 0)) + amount
		return true
	return false
