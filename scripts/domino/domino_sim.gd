extends RefCounted
## Domino Run simulator (docs/domino/phase-3.md). Pure rules: no UI, no await.
## run_walk() returns the whole walk as a deterministic list of event
## Dictionaries; a view replays them. Artifacts are data (DominoArtifact with
## DominoRule entries) and react to events in slot order, depth-first.
## No class_name: const Sim = preload("res://scripts/domino/domino_sim.gd").

const N := 8
const HAND_SIZE := 3
const MAX_HAND := 5
const RED_DMG := 4
const BLUE_BLOCK := 3
const COIN_GEM := 1          # orange Gem: no attack or shield, pays this many coins each time it pops
const ATTACK := ["red"]
const DECK_COUNTS := {"red": 20, "orange": 10, "blue": 15}   # attack 20, coin 10, shield 15
const DISCARDS_PER_TURN := 1
const MAX_DISCARDS := 4   # shop upgrades raise the discards per turn up to this
const BASE_ENEMY_HP := 18
const BASE_STRIKE := 8.0
const WIN_HEAL := 1.0   # full heal when the next fight starts

# Loop ceilings. The first one hit emits `capped` and stops that branch.
const MAX_TILE_POPS := 3      # pops per tile per walk
const MAX_POPS := 24          # pops per walk
const MAX_DEPTH := 3          # reaction depth
const MAX_ART_FIRES := 8      # runs of one artifact per walk
const MAX_BOUNCES := 2
const MAX_STEPS := 24         # 3 x 8 steps per walk
const MAX_EVENTS := 400       # hitting this ends the walk at once

## Triggers an artifact may use. `hit` and `shield` are not among them (no damage feeding damage).
## Verbs that change the event they react to; they run before its built-in effect (the other verbs run after it).
const MODIFIERS := ["convert", "boost"]
const BOSS_EVERY := 3
const ELITE_HP := 1.4        # elite fight: enemy HP and strike multipliers
const ELITE_DMG := 1.2
const ELITE_CHANCE := 0.35   # chance that a non-boss stage (after stage 1) is an elite fight
const Catalog := preload("res://scripts/domino/domino_catalog.gd")
const TRIGGERS := ["ignite", "pass", "pop", "strike", "reach_end", "kill", "walk_end", "fight_start"]

var hp: float = 30.0
var max_hp: float = 30.0
var hand_size: int = HAND_SIZE   # shop upgrades raise it (max MAX_HAND)
var hp_ups: int = 0
var _fire_order: int = 0   # nth artifact rule fired in this walk (the view shows it on the card)
var hand_ups: int = 0
var discard_per_turn: int = DISCARDS_PER_TURN
var discard_ups: int = 0
var stage: int = 1
var enemy_hp: int = 0
var enemy_max: int = BASE_ENEMY_HP
var strike_dmg: float = BASE_STRIKE
var flags: Array[int] = [3]
## tile -> {color: String, life: int (walks to survive the next walk end), kept: bool, temp: bool}
var board: Dictionary = {}
var slots: Array = []            # owned DominoArtifact, left to right
var walk_no: int = 0
var rng := RandomNumberGenerator.new()
var events: Array = []           # events of the last run_walk()
var fight_events: Array = []     # events of the last start_fight()
var gold: int = 0
var boss: Resource = null        # DominoBoss of the current fight, null on a normal fight
var _used_bosses: Array = []
var _plan: Dictionary = {}       # stage -> {"kind", "boss"}: the enemy line-up, fixed once seen so it can be previewed
var kind: String = "fight"       # "fight" | "elite" | "boss": the current fight
var map_rng := RandomNumberGenerator.new()   # the stage plan only; never sim.rng, so fights and decks stay unchanged
var stats: Dictionary = {}       # add_stat values, one walk long
var run_deck: Dictionary = DECK_COUNTS.duplicate()   # Gems per colour in this run's deck; Chaos cards change it for good
var deck: Array = []             # limited draw pile of Gem colours (run_deck per fight)
var discard_pile: Array = []     # reshuffled into the deck when it runs out
var discards_left: int = DISCARDS_PER_TURN   # reset to discard_per_turn each hand
var _deck_ready: bool = false

var _depth: int = 0
var _step: int = 0
var _tile: int = 0
var _dir: int = 1
var _lap: int = 0
var _block: int = 0
var _pops: int = 0
var _tile_pops: Dictionary = {}
var _fires: Dictionary = {}
var _once_walk: Dictionary = {}
var _once_fight: Dictionary = {}
var _stopped: bool = false
var _bounce_req: bool = false
var _bounces: int = 0
var _struck: int = 0
var _route: Array[int] = []      # tiles in walking order (set_route may rewrite it at ignite)
var _ridx: int = 0               # index of the fireball in _route
var _flag_moves: int = 0
var _red_pops: int = 0


# --- setup / hand --------------------------------------------------------------

## `forced_boss` (tests) overrides the pick; otherwise every BOSS_EVERY-th stage draws an unused boss.
## `fight_kind` "elite" makes the enemy tougher (a boss stage is always "boss").
func start_fight(s: int, forced_boss: Resource = null, fight_kind: String = "fight") -> void:
	stage = s
	kind = fight_kind
	boss = forced_boss
	if boss == null and s % BOSS_EVERY == 0:
		var pool: Array = []
		for b in Catalog.bosses():
			if not _used_bosses.has(b):
				pool.append(b)
		if pool.is_empty():
			_used_bosses.clear()
			pool = Catalog.bosses().duplicate()
		if not pool.is_empty():
			boss = pool[rng.randi_range(0, pool.size() - 1)]
			_used_bosses.append(boss)
	if boss != null:
		kind = "boss"
	var st := enemy_stats(s, kind, boss)
	enemy_max = st.hp
	strike_dmg = st.dmg
	enemy_hp = enemy_max
	if s > 1:
		hp = minf(max_hp, hp + max_hp * WIN_HEAL)
	board.clear()
	build_deck()
	_once_fight.clear()
	_reset_walk()
	_block = 0   # shield does not carry into a new fight
	events = []
	_fire(_emit("fight_start", {"stage": s}))
	fight_events = events
	events = []


## Fresh limited deck for a fight: 20 attack, 10 coin (orange), 15 shield, shuffled.
func build_deck() -> void:
	deck.clear()
	discard_pile.clear()
	for c in run_deck:
		for i in int(run_deck[c]):
			deck.append(c)
	_shuffle(deck)
	_deck_ready = true


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Top card of the deck; when it is empty the discard pile is shuffled back in. "" when nothing is left.
func _draw() -> String:
	if deck.is_empty() and not discard_pile.is_empty():
		deck = discard_pile.duplicate()
		discard_pile.clear()
		_shuffle(deck)
	return deck.pop_back() if not deck.is_empty() else ""


## Discards one hand Gem (limited per turn) and draws a replacement; returns it ("" = nothing left to draw).
## Returns "-" (nothing happened) when no discard is left.
func discard_card(color: String) -> String:
	if discards_left <= 0:
		return "-"
	discards_left -= 1
	var n := _draw()   # draw first so the discarded Gem cannot come straight back
	discard_pile.append(color)
	return n


## Draws the next hand from the deck. `leftover` = Gems of the last hand that were never placed (they go to the discard pile).
## Also rolls this turn's flag tile.
func deal_hand(leftover: Array = []) -> Array[String]:
	if not _deck_ready:
		build_deck()
	for c in leftover:
		if c != "":
			discard_pile.append(c)
	discards_left = discard_per_turn
	var h: Array[String] = []
	for i in hand_size:
		var c := _draw()
		if c != "":
			h.append(c)
	flags = [rng.randi_range(1, N - 1)]
	if _boss_is("twin_flag"):
		var second := rng.randi_range(1, N - 2)
		flags.append(second if second < flags[0] else second + 1)   # a different tile
	return h


## Shield carried right now (a status that lasts across turns).
func block() -> int:
	return _block


func _boss_is(rule: String) -> bool:
	return boss != null and String(boss.rule) == rule


func _boss_arg(key: String, default):
	return boss.args.get(key, default) if boss != null else default


## What one flag hits for (a twin-flag boss splits the strike).
func strike_each() -> float:
	return strike_dmg * (float(_boss_arg("mult", 1.0)) if _boss_is("twin_flag") else 1.0)


const WIN_COINS := 4
const HP_BONUS_TIERS := 3   # remaining HP is counted in thirds of max HP


## Coins for the HP left: floor(hp / (max_hp / 3)), so 0..3 (full HP = 3, at least 2/3 = 2, at least 1/3 = 1).
func hp_bonus() -> int:
	return clampi(int(floorf(maxf(hp, 0.0) / (max_hp / HP_BONUS_TIERS) + 0.0001)), 0, HP_BONUS_TIERS)


## Enemy stats for stage `s`: {"hp", "dmg"} (stage scaling, then the boss or elite multipliers).
func enemy_stats(s: int, k: String, b: Resource) -> Dictionary:
	var hp_max := BASE_ENEMY_HP
	var dmg := BASE_STRIKE
	for i in range(1, s):
		hp_max = roundi(hp_max * 1.25)
		dmg *= 1.15
	if b != null:
		hp_max = roundi(hp_max * b.hp_mult)
		dmg *= b.dmg_mult
	elif k == "elite":
		hp_max = roundi(hp_max * ELITE_HP)
		dmg *= ELITE_DMG
	return {"hp": hp_max, "dmg": dmg}


## The enemy of stage `s`: {"kind": "fight" | "elite" | "boss", "boss": Resource or null}. Boss every
## BOSS_EVERY-th stage (no repeat until all were seen), elite by chance; stored so the view can preview it.
func plan(s: int) -> Dictionary:
	if not _plan.has(s):
		var k := "fight"
		var b: Resource = null
		if s % BOSS_EVERY == 0:
			k = "boss"
			var taken: Array = []
			for p in _plan.values():
				if p.boss != null:
					taken.append(p.boss)
			var pool: Array = []
			for c in Catalog.bosses():
				if not taken.has(c):
					pool.append(c)
			if pool.is_empty():
				pool = Catalog.bosses().duplicate()
			if not pool.is_empty():
				b = pool[map_rng.randi_range(0, pool.size() - 1)]
		elif s > 1 and map_rng.randf() < ELITE_CHANCE:
			k = "elite"
		_plan[s] = {"kind": k, "boss": b}
	return _plan[s]


## Coins for winning the fight: 4 + the HP bonus. Returns the amount.
func claim_win() -> int:
	var c := WIN_COINS + hp_bonus()
	gold += c
	return c


func place(tile: int, color: String) -> bool:
	if board.has(tile) or tile < 0 or tile >= N:
		return false
	board[tile] = {"color": color, "life": 0, "kept": false, "temp": false}
	return true


## Takes a Gem back off the board; "" if the tile is empty or the Gem is kept.
func take(tile: int) -> String:
	if not board.has(tile) or board[tile].kept:
		return ""
	var c: String = board[tile].color
	board.erase(tile)
	return c


# --- walk ----------------------------------------------------------------------

func _reset_walk() -> void:
	_depth = 0
	_step = 0
	_tile = 0
	_dir = 1
	_lap = 0
	_pops = 0
	_tile_pops = {}
	_fires = {}
	_fire_order = 0
	_once_walk = {}
	_stopped = false
	_bounce_req = false
	_bounces = 0
	_struck = 0
	stats = {}
	_route = default_route()
	_ridx = 0
	_flag_moves = 0
	_red_pops = 0


static func default_route() -> Array[int]:
	var r: Array[int] = []
	for t in N:
		r.append(t)
	return r


## Tile after `tile` walking in `dir` along the current route, or -1 past its end.
func _route_next(tile: int, dir: int) -> int:
	var i := _route.find(tile) + dir
	return _route[i] if i >= 0 and i < _route.size() else -1


func run_walk() -> Array:
	_reset_walk()
	events = []
	walk_no += 1
	_fire(_emit("ignite", {"walk": walk_no, "block": _block}))
	var idx := 0
	var dir := 1
	while not _stopped:
		if _step >= MAX_STEPS:
			_cap("steps")
			break
		_step += 1
		var tile: int = _route[idx]
		_tile = tile
		_dir = dir
		_ridx = idx
		_fire(_emit("pass", {"tile": tile}))
		if _stopped:
			break
		if board.has(tile):
			_do_pop(tile, "pass")
		if not _stopped and flags.has(tile):
			_do_strike(tile)
		if _stopped:
			break
		var at_end: bool = (dir == 1 and idx == _route.size() - 1) or (dir == -1 and idx == 0)
		if not at_end:
			idx += dir
			continue
		_bounce_req = false
		_fire(_emit("reach_end"))
		if _stopped:
			break
		if _bounce_req:
			if _bounces >= MAX_BOUNCES:
				_cap("steps")
				break
			_bounces += 1
			_lap = _bounces
			dir = -dir
			_dir = dir
			_emit("bounce")
			continue   # enter the same tile again, going the other way
		break
	var wend := _emit("walk_end", {"kept_tiles": []})
	_fire(wend)
	wend["kept_tiles"] = _finalize()
	return events


## After the walk: Gems are cleared, except kept ones (life > 0) which stay for one more walk.
func _finalize() -> Array:
	if enemy_hp <= 0 or hp <= 0.0:
		board.clear()
		return []
	var keep: Dictionary = {}
	for t in board:
		var g: Dictionary = board[t]
		if g.life > 0 and not g.temp:
			g.kept = true
			g.life = 0
			keep[t] = g
		elif not g.temp:
			discard_pile.append(g.color)   # played Gem goes to the discard pile (spawned temp Gems are not deck cards)
	board = keep
	var tiles: Array = keep.keys()
	tiles.sort()
	return tiles


# --- events --------------------------------------------------------------------

func _push(ev: Dictionary) -> void:
	ev["i"] = events.size()
	events.append(ev)


## Appends an event (walker state fills step/tile/dir/lap/depth unless given).
## Returns {} when the walk is stopped or the event ceiling is reached.
func _emit(k: String, payload: Dictionary = {}, src: String = "base") -> Dictionary:
	if _stopped and k != "kill" and k != "capped" and k != "walk_end" and k != "gold":
		return {}
	if events.size() >= MAX_EVENTS and k != "capped" and k != "walk_end" and k != "kill" and k != "gold":
		if not _stopped:
			_stopped = true
			var c := {"k": "capped", "what": "events", "step": _step, "tile": _tile, "dir": _dir, "lap": _lap, "depth": _depth, "src": src}
			_push(c)
		return {}
	var ev: Dictionary = payload.duplicate()
	ev["k"] = k
	ev["src"] = src
	ev["step"] = _step
	ev["dir"] = _dir
	ev["lap"] = _lap
	ev["depth"] = _depth
	if not ev.has("tile"):
		ev["tile"] = _tile
	_push(ev)
	return ev


func _cap(what: String) -> void:
	_emit("capped", {"what": what})


func _hit(target: String, amount: float, src: String, via: String) -> void:
	if _stopped:
		return
	var amt: float
	var after: float
	if target == "enemy":
		var a := roundi(amount)
		enemy_hp -= a
		amt = float(a)
		after = float(enemy_hp)
	else:
		hp -= amount
		amt = amount
		after = hp
	_emit("hit", {"target": target, "amount": amt, "hp_after": after, "via": via}, src)
	if after <= 0.0:
		_stopped = true
		_fire(_emit("kill", {"target": target}, src))


func _shield(amount: int, src: String) -> void:
	_block += amount
	_emit("shield", {"amount": amount, "total": _block}, src)


func _do_pop(tile: int, cause: String) -> void:
	var tp: int = _tile_pops.get(tile, 0)
	if tp >= MAX_TILE_POPS or _pops >= MAX_POPS:
		_cap("pop")
		return
	_tile_pops[tile] = tp + 1
	_pops += 1
	var g: Dictionary = board[tile]
	var red: bool = g.color in ATTACK
	var coin: bool = g.color == "orange"   # coin Gem: pays coins, no attack or shield
	var base: int = 0 if coin else ((RED_DMG + roundi(stats.get("red_bonus", 0.0))) if red else BLUE_BLOCK)
	if red:
		_red_pops += 1
		if _boss_is("bulwark") and _red_pops <= int(_boss_arg("pops", 2)):
			base = 0   # the boss's armour eats the first red pops of the walk
	var src := "base" if cause == "pass" else cause
	var ev := _emit("pop", {"tile": tile, "color": g.color, "nth": _pops, "tile_pops": tp + 1,
		"cause": cause, "kept": g.kept, "temp": g.temp, "base": base}, src)
	if ev.is_empty():
		return
	_fire(ev, true)   # modifiers (convert) first, then the Gem's own effect, then the reactions
	var boost := roundi(float(ev.get("boost", 0.0)))   # "boost" rules add to this Gem's power, whatever its colour
	if coin:
		gold += COIN_GEM + boost
		_emit("gold", {"amount": COIN_GEM + boost, "total": gold}, "base")
		base = 0
	elif base == 0 and red:
		ev["nullified"] = true
	elif red or ev.get("convert", "") == "damage":
		base += boost
		_hit("enemy", float(base), "base", "pop")
	else:
		_shield(base + boost, "base")
	_fire(ev)


func _do_strike(tile: int) -> void:
	var color: String = board[tile].color if board.has(tile) else ""
	var sd := strike_each()
	var ev := _emit("strike", {"tile": tile, "dmg": sd, "block": _block, "redirect": "",
		"tile_color": color, "excess": maxf(0.0, _block - sd), "dealt": 0.0})
	if ev.is_empty():
		return
	_fire(ev)   # modifying reactions (reflect, ...) run before the strike resolves
	if _stopped:
		return
	ev["block"] = _block
	ev["excess"] = maxf(0.0, _block - float(ev.dmg))
	if ev.redirect == "enemy":
		ev["dealt"] = float(ev.dmg) * float(ev.get("mult", 1.0)) * (float(_boss_arg("mult", 0.5)) if _boss_is("obsidian") else 1.0)
		_hit("enemy", ev.dealt, "base", "reflect")
	else:
		var d: float = maxf(0.0, float(ev.dmg) - _block)
		ev["dealt"] = d
		if d > 0.0:
			_hit("hero", d, "base", "strike")
	if _stopped:
		return
	# Shield is a status: what the strike did not absorb carries over (also into the next turn).
	_block = maxi(0, _block - ceili(float(ev.dmg)))
	_emit("shield_break", {"left": _block})
	_struck += 1


# --- rule engine ---------------------------------------------------------------

## Runs every matching artifact rule for `ev`: slots left to right, rules in written order.
func _fire(ev: Dictionary, modifiers: bool = false) -> void:
	if ev.is_empty() or not (ev.k in TRIGGERS):
		return
	var owners: Array = []
	if boss != null and not boss.rules.is_empty():
		owners.append(boss)   # enemy rules run before the player's artifacts
	owners.append_array(slots)
	for def in owners:
		for ri in def.rules.size():
			if _stopped and ev.k != "kill":
				return
			var r: Resource = def.rules[ri]
			if String(r.trigger) != ev.k or (String(r.effect) in MODIFIERS) != modifiers or not _match(r, ev):
				continue
			var okey := "%s:%d" % [def.id, ri]
			var osrc: String = "enemy" if def == boss else def.id
			var once := String(r.once)
			if once == "walk" and _once_walk.has(okey):
				continue
			if once == "fight" and _once_fight.has(okey):
				continue
			if _depth >= MAX_DEPTH:
				_cap("depth")
				return
			var n: int = _fires.get(osrc, 0)
			if n >= MAX_ART_FIRES:
				_cap("artifact")
				continue
			_fires[osrc] = n + 1
			if once == "walk":
				_once_walk[okey] = true
			elif once == "fight":
				_once_fight[okey] = true
			_fire_order += 1
			_emit("fire", {"art": osrc, "order": _fire_order, "cause_i": ev.get("i", -1), "trigger": String(ev.k), "tile": ev.get("tile", -1)}, osrc)
			_depth += 1
			_apply(r, ev, osrc)
			_depth -= 1


func _match(r: Resource, ev: Dictionary) -> bool:
	var c: Dictionary = r.cond
	if String(r.effect) == "repop" and not c.has("cause"):
		if ev.get("cause", "") != "pass":
			return false
	for key in c:
		if not _check(String(key), c[key], ev):
			return false
	return true


func _color_at(tile: int) -> String:
	return board[tile].color if board.has(tile) else ""


## Artifact conditions on "red" match attack Gems only.
func _is_color(c: String, want) -> bool:
	return c in ATTACK if want == "red" else c == want


func _check(key: String, want, ev: Dictionary) -> bool:
	var tile: int = ev.tile
	match key:
		"color":
			return _is_color(ev.get("color", _color_at(tile)), want)
		"tile":
			if want is String:
				match want:
					"flag": return flags.has(tile)
					"first": return tile == _route[0]
					"last": return tile == _route[_route.size() - 1]
				return false
			return tile == int(want)
		"dir":
			return ev.dir == (1 if want == "fwd" else -1)
		"nth":
			return ev.get("nth", -1) == int(want)
		"every":
			return int(want) > 0 and ev.get("nth", 0) % int(want) == 0
		"cause":
			return ev.get("cause", "") == want
		"target":
			return ev.get("target", "") == want
		"kept", "temp":
			return ev.k == "walk_end" or ev.get(key, false) == want   # walk_end: per-Gem filter in keep_gems
		"neighbor":
			return _is_color(_color_at(tile - 1), want) or _is_color(_color_at(tile + 1), want)
		"before_flag":
			var ahead := false
			var ci := _route.find(tile)
			for f in flags:
				var fi := _route.find(f)
				if (fi > ci) if ev.dir == 1 else (fi >= 0 and fi < ci):
					ahead = true
			return ahead == want
		"flag_struck":
			return (_struck > 0) == want
		"tile_color":
			return _is_color(ev.get("tile_color", ""), want)
		"blocked_full":
			return (float(ev.get("block", 0)) >= float(ev.get("dmg", 0)) and ev.get("redirect", "") == "") == want
	return false


func _amt(v, ev: Dictionary) -> float:
	if v is String:
		return float(ev.get(v, 0))
	return float(v)


func _apply(r: Resource, ev: Dictionary, src: String) -> void:
	var a: Dictionary = r.args
	match String(r.effect):
		"damage":
			_hit("enemy", _amt(a.get("amount", 0), ev), src, src)
		"shield":
			_shield(roundi(_amt(a.get("amount", 0), ev)), src)
		"heal":
			hp = minf(max_hp, hp + _amt(a.get("amount", 0), ev))
			_emit("heal", {"amount": _amt(a.get("amount", 0), ev), "hp_after": hp}, src)
		"repop":
			var t: int = ev.tile if a.get("where", "same") == "same" else _route_next(ev.tile, ev.dir)
			if t >= 0 and t < N and board.has(t):
				_do_pop(t, src)
		"bounce":
			_bounce_req = true
		"reflect_strike":
			ev["redirect"] = "enemy"
			ev["mult"] = float(a.get("mult", 1.0))
		"keep_gems":
			var keep_t := -1   # "leftmost": only the Gem on the lowest tile stays
			for t in board:
				var g: Dictionary = board[t]
				if r.cond.has("kept") and g.kept != r.cond.kept:
					continue
				if r.cond.has("temp") and g.temp != r.cond.temp:
					continue
				if a.get("leftmost", false):
					if keep_t < 0 or t < keep_t:
						keep_t = t
					continue
				g.life = int(a.get("walks", 1))
			if keep_t >= 0:
				board[keep_t].life = int(a.get("walks", 1))
		"spawn_gem":
			for t in N:
				if not board.has(t):
					board[t] = {"color": a.get("color", "red"), "life": 0, "kept": false, "temp": bool(a.get("temp", true))}
					_emit("spawn", {"tile": t, "color": a.get("color", "red")}, src)
					break
		"move_flag":
			# delta counts along the walking direction; the flag stays on the route, never past its end
			var fi := _route.find(flags[0])
			if src != "enemy" and _boss_is("drifter"):
				fi = -1   # this boss's flag cannot be pushed
			if fi >= 0 and (src == "enemy" or _flag_moves < int(a.get("max", 999))):
				var ni := clampi(fi + int(a.get("delta", 0)) * ev.dir, 0, _route.size() - 1)
				if ni != fi:
					if src != "enemy":
						_flag_moves += 1
					var from: int = flags[0]
					flags[0] = _route[ni]
					_emit("flag_move", {"from": from, "to": flags[0]}, src)
		"set_route":
			# start: "after_flag" begins on the tile after the flag and wraps, so the flag is struck last
			if a.get("start", "") == "after_flag":
				var f: int = flags[0]
				var route: Array[int] = []
				for t in range(f + 1, N):
					route.append(t)
				for t in range(0, f + 1):
					route.append(t)
				_route = route
		"gold":
			var amt := roundi(_amt(a.get("amount", 1), ev))
			if a.has("per"):
				amt = mini(int(a.get("max", 999)), gold / maxi(int(a.get("per", 1)), 1)) * amt
			if amt > 0:
				gold += amt
				_emit("gold", {"amount": amt, "total": gold}, src)
		"convert":
			ev["convert"] = String(a.get("to", "damage"))
		"boost":
			ev["boost"] = float(ev.get("boost", 0.0)) + _amt(a.get("amount", 0), ev)
		"add_stat":
			var s: String = a.get("stat", "")
			stats[s] = minf(float(a.get("max", 999999)), float(stats.get(s, 0.0)) + float(a.get("amount", 0)))
		_:
			pass   # set_route, convert, gold: phases 4-5
