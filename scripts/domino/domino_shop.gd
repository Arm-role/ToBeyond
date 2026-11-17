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


## Permanent upgrades (once per kind per purchase count, price rises each time).
const HP_UP := 5          # +5 max HP, heals the same amount
const HP_UP_BASE := 4
const HP_UP_STEP := 2
const HAND_UP_BASE := 8   # +1 hand tile, up to Sim.MAX_HAND
const HAND_UP_STEP := 4
const DISCARD_UP_BASE := 6   # +1 discard per turn, up to Sim.MAX_DISCARDS
const DISCARD_UP_STEP := 3


static func hp_up_cost(sim) -> int:
	return HP_UP_BASE + HP_UP_STEP * sim.hp_ups


static func hand_up_cost(sim) -> int:
	return HAND_UP_BASE + HAND_UP_STEP * sim.hand_ups


static func buy_hp(sim) -> bool:
	var c := hp_up_cost(sim)
	if sim.gold < c:
		return false
	sim.gold -= c
	sim.hp_ups += 1
	sim.max_hp += HP_UP
	sim.hp += HP_UP
	return true


static func buy_hand(sim) -> bool:
	var c := hand_up_cost(sim)
	if sim.gold < c or sim.hand_size >= sim.MAX_HAND:
		return false
	sim.gold -= c
	sim.hand_ups += 1
	sim.hand_size += 1
	return true


static func discard_up_cost(sim) -> int:
	return DISCARD_UP_BASE + DISCARD_UP_STEP * sim.discard_ups


static func buy_discard(sim) -> bool:
	var c := discard_up_cost(sim)
	if sim.gold < c or sim.discard_per_turn >= sim.MAX_DISCARDS:
		return false
	sim.gold -= c
	sim.discard_ups += 1
	sim.discard_per_turn += 1
	sim.discards_left += 1   # usable at once this hand
	return true
