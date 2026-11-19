extends SceneTree
## Pass/fail matrix: every Chaos card x every Gem colour in the run deck. Prints only failures, then CHAOS_MATRIX_OK.
## Invariants: a card changes only what it names (a convert keeps the Gem's level, a coin Gem has none), a pick that changes
## nothing is refused, deck sizes move as the card says, and artifact colour conditions see Chaos Gems as their Lv1 kind.
##   godot --headless --path . --script res://tools/parity/chaos_matrix.gd
const Sim := preload("res://scripts/domino/domino_sim.gd")
const Chaos := preload("res://scripts/domino/domino_chaos.gd")

var fails := 0


func _fail(msg: String) -> void:
	fails += 1
	print("FAIL ", msg)


func _lv(c: String) -> int:
	return 2 if c.ends_with("2") else 1


func _initialize() -> void:
	for card in Chaos.CARDS:
		if card.kind == "global":
			continue
		for c in Chaos.COLORS:
			var sim = Sim.new()
			for k in Chaos.COLORS:
				sim.run_deck[k] = 5
			sim.gold = 99
			var tag := "%s on %s" % [card.id, c]
			var ok: bool = Chaos.valid(sim, card, [c])
			if ok != Chaos.can_pick(card, c) and not (not ok and card.kind == "destroy"):
				_fail("%s: valid() %s but can_pick() %s" % [tag, ok, Chaos.can_pick(card, c)])
			var before: Dictionary = sim.run_deck.duplicate()
			var bought: bool = Chaos.buy(sim, card, [c])
			if bought != ok:
				_fail("%s: buy() %s but valid() %s" % [tag, bought, ok])
			if not bought:
				if sim.run_deck != before or sim.gold != 99:
					_fail("%s: refused but state changed" % tag)
				continue
			var d := {}
			for k in sim.run_deck:
				if int(sim.run_deck[k]) < 0:
					_fail("%s: negative count %s" % [tag, k])
				if not (k in Chaos.COLORS):
					_fail("%s: unknown colour %s" % [tag, k])
				var dv := int(sim.run_deck[k]) - int(before.get(k, 0))
				if dv != 0:
					d[k] = dv
			var total := Chaos.deck_total(sim) - 35
			var want_total: int = {"convert": 0, "upgrade": 0, "destroy": -1, "clone": 1}[card.kind]
			if total != want_total:
				_fail("%s: deck size %+d, want %+d" % [tag, total, want_total])
			if sim.gold != 99 - int(card.price):
				_fail("%s: price not paid" % tag)
			if card.kind == "convert" or card.kind == "upgrade":
				var dest := ""
				for k in d:
					if d[k] > 0:
						dest = k
				if dest == "" or dest == c:
					_fail("%s: changed nothing (%s)" % [tag, str(d)])
				elif dest != "orange" and _lv(dest) != _lv(c) and card.kind == "convert":
					_fail("%s: level lost %s -> %s" % [tag, c, dest])
				elif card.kind == "upgrade" and _lv(dest) != 2:
					_fail("%s: upgrade did not reach Lv2 (%s)" % [tag, dest])
	# artifact colour conditions: Chaos Gems read as their Lv1 kind
	var sim2 = Sim.new()
	for c in Chaos.COLORS:
		var attack: bool = c in Sim.ATTACK
		if sim2._is_color(c, "red") != attack:
			_fail("_is_color(%s, red) != %s" % [c, attack])
		var kind: String = "red" if attack else c.trim_suffix("2")
		if sim2._is_color(c, "blue") != (kind == "blue") or sim2._is_color(c, "orange") != (kind == "orange"):
			_fail("_is_color(%s) wrong for blue/orange" % c)
	print("CHAOS_MATRIX_OK" if fails == 0 else "CHAOS_MATRIX_FAILED %d" % fails)
	quit(0 if fails == 0 else 1)
