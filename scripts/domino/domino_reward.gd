extends RefCounted
## Reward offers after a won fight (docs/domino/phase-4.md). No class_name:
## const Reward = preload("res://scripts/domino/domino_reward.gd").

const Catalog := preload("res://scripts/domino/domino_catalog.gd")
const WEIGHT := {"common": 60, "uncommon": 30, "rare": 10}


static func _pick(pool: Array, rng: RandomNumberGenerator) -> Resource:
	var total := 0
	for d in pool:
		total += int(WEIGHT.get(d.rarity, 10))
	var roll := rng.randi_range(1, maxi(total, 1))
	for d in pool:
		roll -= int(WEIGHT.get(d.rarity, 10))
		if roll <= 0:
			return d
	return pool[pool.size() - 1]


## Three different artifacts not owned yet, weighted 60/30/10 by rarity. Once the
## player owns one, at least one offer shares an archetype with what they hold.
static func offer(sim, count: int = 3) -> Array:
	var pool: Array = []
	for d in Catalog.all():
		if not sim.slots.has(d):
			pool.append(d)
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var d := _pick(pool, sim.rng)
		pool.erase(d)
		out.append(d)
	if not sim.slots.is_empty() and not out.is_empty():
		var held: Array = []
		for a in sim.slots:
			held.append(a.archetype)
		var has_match := false
		for d in out:
			if d.archetype in held:
				has_match = true
		if not has_match:
			var match_pool: Array = []
			for d in pool:
				if d.archetype in held:
					match_pool.append(d)
			if not match_pool.is_empty():
				out[out.size() - 1] = _pick(match_pool, sim.rng)
	return out
