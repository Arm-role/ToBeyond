extends RefCounted
## Chaos cards: tarot-like consumables sold in the shop and used at once on the run deck
## (sim.run_deck, Gem counts per colour). No class_name:
## const Chaos = preload("res://scripts/domino/domino_chaos.gd").

const MIN_DECK := 15   # destroying cannot leave fewer Gems than this
const STOCK := 3
const COLORS := ["red", "orange", "blue"]
const CARDS := [
	{"id": "to_red", "kind": "convert", "to": "red", "picks": 2, "price": 3, "icon": "🌀", "name": "Chaos เปลี่ยนเป็นแดง",
		"text": "เลือก Gem ในสำรับ 2 ใบ เปลี่ยนเป็น ⚔ แดง"},
	{"id": "to_blue", "kind": "convert", "to": "blue", "picks": 2, "price": 3, "icon": "🌀", "name": "Chaos เปลี่ยนเป็นน้ำเงิน",
		"text": "เลือก Gem ในสำรับ 2 ใบ เปลี่ยนเป็น 🛡 น้ำเงิน"},
	{"id": "to_orange", "kind": "convert", "to": "orange", "picks": 2, "price": 3, "icon": "🌀", "name": "Chaos เปลี่ยนเป็นส้ม",
		"text": "เลือก Gem ในสำรับ 2 ใบ เปลี่ยนเป็น 🪙 ส้ม"},
	{"id": "destroy", "kind": "destroy", "picks": 2, "price": 3, "icon": "💥", "name": "Chaos ทำลาย Gem",
		"text": "เลือก Gem ในสำรับ 2 ใบ ทิ้งออกจากสำรับถาวร (เหลือขั้นต่ำ %d ใบ)" % MIN_DECK},
	{"id": "clone", "kind": "clone", "picks": 1, "price": 4, "icon": "🧬", "name": "Chaos ทำสำเนา Gem",
		"text": "เลือก Gem ในสำรับ 1 ใบ เพิ่มสำเนาอีก 1 ใบ"},
]


## Up to `count` different Chaos cards for one shop visit (uses map_rng, never the fight rng).
static func stock(sim, count: int = STOCK) -> Array:
	var pool: Array = CARDS.duplicate()
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(sim.map_rng.randi_range(0, pool.size() - 1)))
	return out


static func deck_total(sim) -> int:
	var n := 0
	for c in sim.run_deck:
		n += int(sim.run_deck[c])
	return n


## `picks` = Gem colours chosen from the deck (one entry per Gem). True when the card can be used with them.
static func valid(sim, card: Dictionary, picks: Array) -> bool:
	if picks.is_empty() or picks.size() > int(card.picks):
		return false
	var used := {}
	for c in picks:
		if not (c in COLORS):
			return false
		used[c] = int(used.get(c, 0)) + 1
		if used[c] > int(sim.run_deck.get(c, 0)):
			return false
		if card.kind == "convert" and c == card.to:
			return false
	if card.kind == "destroy" and deck_total(sim) - picks.size() < MIN_DECK:
		return false
	return true


## Pays and applies the card. False (nothing changes) when it is not affordable or the picks are not valid.
static func buy(sim, card: Dictionary, picks: Array) -> bool:
	if sim.gold < int(card.price) or not valid(sim, card, picks):
		return false
	sim.gold -= int(card.price)
	for c in picks:
		match String(card.kind):
			"convert":
				sim.run_deck[c] = int(sim.run_deck[c]) - 1
				sim.run_deck[card.to] = int(sim.run_deck.get(card.to, 0)) + 1
			"destroy":
				sim.run_deck[c] = int(sim.run_deck[c]) - 1
			"clone":
				sim.run_deck[c] = int(sim.run_deck[c]) + 1
	return true
