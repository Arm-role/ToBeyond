extends SceneTree
## Headless regression for the Domino simulator (docs/domino/phase-3.md): fixed
## seeds and boards, artifacts off / each alone / all three / stress ceilings,
## one line per event. Deterministic; diff against tools/parity/baseline/.
##   godot --headless --path . --script res://tools/parity/domino_regress.gd

const Sim := preload("res://scripts/domino/domino_sim.gd")
const Catalog := preload("res://scripts/domino/domino_catalog.gd")
const RuleRes := preload("res://scripts/domino/domino_rule.gd")
const ArtRes := preload("res://scripts/domino/domino_artifact.gd")

# tile -> colour; flag tile; strike damage; hero hp
const BOARDS := {
	"full": {"gems": {0: "red", 1: "red", 2: "blue", 3: "blue", 4: "red", 5: "red", 6: "blue", 7: "blue"}, "flag": 3, "hp": 30.0},
	"sparse": {"gems": {0: "red", 3: "blue", 6: "red"}, "flag": 6, "hp": 30.0},
	"flag_red": {"gems": {1: "red", 4: "red", 7: "blue"}, "flag": 4, "hp": 30.0},
	"flag_end": {"gems": {2: "blue", 7: "blue", 5: "red"}, "flag": 7, "hp": 30.0},
	"lethal": {"gems": {0: "red"}, "flag": 1, "hp": 5.0},
	"killer": {"gems": {0: "red", 1: "red", 2: "red", 3: "red", 4: "red", 5: "red"}, "flag": 6, "hp": 30.0, "enemy": 14},
}
const SETS := [[], ["mirror"], ["coal"], ["riposte"], ["mirror", "riposte"], ["coal", "mirror", "riposte"]]


func _rule(trigger: String, cond: Dictionary, effect: String, args: Dictionary = {}, once: String = "") -> Resource:
	var r: Resource = RuleRes.new()
	r.trigger = StringName(trigger)
	r.cond = cond
	r.effect = StringName(effect)
	r.args = args
	r.once = StringName(once)
	return r


func _art(id: String, rules: Array) -> Resource:
	var a: Resource = ArtRes.new()
	a.id = id
	for r in rules:
		a.rules.append(r)
	return a


func _line(ev: Dictionary) -> String:
	var keys: Array = ev.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		var v = ev[k]
		if v is float:
			v = snappedf(v, 0.001)
		parts.append("%s=%s" % [k, str(v)])
	return " ".join(parts)


func _run(label: String, sim: RefCounted, walks: int = 1) -> void:
	for w in walks:
		var evs: Array = sim.run_walk()
		print("== %s walk %d: %d events, hp %s, enemy %d, kept %s" % [label, w + 1, evs.size(), str(snappedf(sim.hp, 0.001)), sim.enemy_hp, str(evs[-1].kept_tiles)])
		for ev in evs:
			print(_line(ev))
		# the kept Gems stay; refill the rest like a player would
		if w + 1 < walks:
			sim.place(0, "red")


func _setup(b: Dictionary, ids: Array, boss_id: String = "") -> RefCounted:
	var sim = Sim.new()
	sim.rng.seed = 7
	if boss_id != "":
		sim.start_fight(3, Catalog.get_boss(boss_id))
	else:
		sim.start_fight(1)
	sim.hp = b.hp
	sim.enemy_hp = b.get("enemy", 99)   # big by default so the walk is not cut short
	sim.flags.assign([b.flag, b.flag2] if b.has("flag2") else [b.flag])
	for t in b.gems:
		sim.place(t, b.gems[t])
	for id in ids:
		sim.slots.append(Catalog.get_def(id))
	return sim


func _initialize() -> void:
	var h = Sim.new()
	h.rng.seed = 12345
	print("hands: ", h.deal_hand(), h.deal_hand(), h.flags)
	for name in BOARDS:
		for ids in SETS:
			var walks := 2 if "coal" in ids else 1
			_run("%s [%s]" % [name, ",".join(ids)], _setup(BOARDS[name], ids), walks)
	# fights: stage scaling and heal
	var f = Sim.new()
	f.rng.seed = 3
	for s in [1, 2, 3, 5]:
		f.hp = 10.0
		f.start_fight(s)
		print("fight %d: boss %s enemy %d strike %s hp %s" % [s, f.boss.id if f.boss != null else "-", f.enemy_hp, str(snappedf(f.strike_dmg, 0.001)), str(snappedf(f.hp, 0.001))])
	# stress: ceilings (pop, steps, depth, artifact fires, events)
	var loop_b: Dictionary = BOARDS.full
	var bounce_any := _art("bounce_any", [_rule("reach_end", {}, "bounce")])
	var dbl1 := _art("dbl1", [_rule("pop", {}, "repop", {"where": "same"})])
	var dbl2 := _art("dbl2", [_rule("pop", {}, "repop", {"where": "same"})])
	var sim = _setup(loop_b, ["mirror"])
	sim.slots = [Catalog.get_def("mirror"), dbl1, dbl2]
	_run("stress pop-cap", sim)
	sim = _setup(loop_b, [])
	sim.slots = [bounce_any]
	_run("stress bounce-steps", sim)
	var chain: Array = []
	for i in 5:
		var cond := {"cause": "pass"} if i == 0 else {"cause": "chain%d" % (i - 1)}
		chain.append(_art("chain%d" % i, [_rule("pop", cond, "repop", {"where": "next"})]))
	sim = _setup(BOARDS.full, [])
	sim.slots = chain
	_run("stress depth", sim)
	var spam := _art("spam", [_rule("pass", {}, "spawn_gem", {"color": "red", "temp": true})])
	sim = _setup(loop_b, [])
	sim.slots = [spam, bounce_any]
	_run("stress artifact-fires", sim)
	# per-fight and effect verbs on data built in memory
	var verbs := _art("verbs", [
		_rule("ignite", {}, "shield", {"amount": 2}),
		_rule("pop", {"color": "red", "every": 2}, "damage", {"amount": "base"}),
		_rule("strike", {"blocked_full": true}, "heal", {"amount": "excess"}),
		_rule("reach_end", {}, "move_flag", {"delta": -1}, "fight"),
		_rule("walk_end", {}, "add_stat", {"stat": "x", "amount": 1, "max": 3}),
	])
	sim = _setup(BOARDS.full, [])
	sim.slots = [verbs]
	_run("verbs", sim, 2)
	_phase4()
	_phase5()
	quit()


const SINGLES := ["echo", "ring", "thorns", "push", "furnace", "fuse", "stoke", "twin", "alchemy"]
const COMBOS := [
	["mirror", "riposte", "ring"],
	["echo", "twin", "mirror"],
	["coal", "furnace", "fuse"],
	["push", "ring"],
	["push", "mirror"],
	["stoke", "mirror", "echo"],
	["thorns", "riposte"],
	["ring", "mirror", "echo", "twin", "stoke"],
]


## Phase 4: each new artifact alone and the dangerous combos; ceiling lines show in the output.
func _phase4() -> void:
	var more := {"red_run": {"gems": {0: "red", 1: "red", 2: "red", 3: "blue", 4: "red", 5: "red", 6: "blue", 7: "red"}, "flag": 5, "hp": 40.0},
		"blue_run": {"gems": {0: "blue", 1: "blue", 2: "blue", 3: "blue", 4: "blue", 5: "red"}, "flag": 4, "hp": 40.0}}
	for name in ["full", "flag_red", "flag_end"]:
		for id in SINGLES:
			_run("p4 %s [%s]" % [name, id], _setup(BOARDS[name], [id]), 2 if id in ["furnace"] else 1)
	for name in more:
		for id in SINGLES:
			_run("p4 %s [%s]" % [name, id], _setup(more[name], [id]))
	for ids in COMBOS:
		for name in ["red_run", "blue_run"]:
			_run("p4 combo %s [%s]" % [name, ",".join(ids)], _setup(more[name], ids), 2 if "coal" in ids else 1)
	# coal + furnace: kept Gems pop doubled on the next walk
	var cf = _setup(more.red_run, ["coal", "furnace"])
	_run("p4 coal+furnace", cf, 3)


const BOSSES := ["twin_flag", "drifter", "obsidian", "smoke", "bulwark"]
const BOSS_SETS := [
	[],
	["mirror", "riposte", "ring"],
	["push", "ring"],
	["push", "mirror"],
	["thorns", "riposte"],
	["echo", "twin", "mirror"],
]


## Phase 5: coins, economy artifacts and every boss against the phase-4 combos.
func _phase5() -> void:
	var arena := {"gems": {0: "red", 1: "blue", 2: "red", 3: "blue", 4: "red", 5: "red", 6: "blue", 7: "red"}, "flag": 3, "flag2": 6, "hp": 40.0}
	for ids in BOSS_SETS:
		for bid in BOSSES:
			var b := arena.duplicate()
			if bid != "twin_flag":
				b.erase("flag2")
			_run("p5 %s [%s]" % [bid, ",".join(ids)], _setup(b, ids, bid))
	# economy: kill reactions pay out; piggy scales with the coins held
	var kill_b: Dictionary = BOARDS.killer
	for ids in [["bounty"], ["piggy"], ["bounty", "piggy"]]:
		var sim = _setup(kill_b, ids)
		sim.gold = 12
		_run("p5 gold [%s]" % ",".join(ids), sim)
		print("gold now %d, claim_win %d, gold %d" % [sim.gold, sim.claim_win(), sim.gold])
	# boss pick: stages 3, 6, 9 draw different bosses
	var bs = Sim.new()
	bs.rng.seed = 11
	for s in range(1, 10):
		bs.start_fight(s)
		print("stage %d boss %s enemy %d strike %s" % [s, bs.boss.id if bs.boss != null else "-", bs.enemy_max, str(snappedf(bs.strike_dmg, 0.001))])
