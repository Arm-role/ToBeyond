extends RefCounted
## Shop logic (docs/domino/phase-5.md). No class_name:
## const Shop = preload("res://scripts/domino/domino_shop.gd").

const Catalog := preload("res://scripts/domino/domino_catalog.gd")
const Reward := preload("res://scripts/domino/domino_reward.gd")
const PRICE := {"common": 4, "uncommon": 6, "rare": 8}
const STOCK := 4
const REROLL_BASE := 2   # first reroll costs 2, each next one 1 more


static func price(d: Resource) -> int:
	return int(PRICE.get(d.rarity, 6))


static func sell_value(d: Resource) -> int:
	return price(d) / 2


static func reroll_cost(rerolls: int) -> int:
	return REROLL_BASE + rerolls


## Four different artifacts the player does not own, weighted by rarity like rewards.
static func stock(sim, count: int = STOCK) -> Array:
	var pool: Array = []
	for d in Catalog.all():
		if not sim.slots.has(d):
			pool.append(d)
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var d: Resource = Reward.pick(pool, sim.rng)
		pool.erase(d)
		out.append(d)
	return out
