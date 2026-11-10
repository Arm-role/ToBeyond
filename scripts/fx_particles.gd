class_name FxParticles
extends Node2D

## Tiny particle system drawn with _draw(): bursts, a trail that follows a
## moving point, or a falling stream. Used instead of CPUParticles2D, which drew
## black particles in the web (GL Compatibility) build. A few dozen particles
## per effect is all the game needs.

var tex: Texture2D
var gravity: float = 0.0
var damping: float = 0.0           # per second, fraction of velocity lost
var col_from: Color = Color.WHITE
var col_mid: Color = Color(0, 0, 0, 0)  # alpha 0 = no middle colour
var size_scale: float = 1.0
var shrink: bool = true            # scale 1 -> 0.1 over the life
var fade: bool = true
var fade_from: float = 0.0         # life fraction where fading starts (when there is no middle colour)
var speed_scale: float = 1.0
var emit_rate: float = 0.0         # particles/second, for trails (0 = burst only)
var emit_life: float = 0.4
var emit_speed: Vector2 = Vector2(10, 70)
var emit_dir: Vector2 = Vector2(-1, 0)
var emit_spread: float = 70.0      # degrees
var continuous: bool = false       # trail: stays alive until stop()
var head: Vector2 = Vector2.ZERO   # where a trail spawns (local coordinates)
var _p: Array = []
var _acc: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	z_as_relative = false
	z_index = 120  # above the modals (z_index 100)
	_rng.randomize()


func add_particle(pos: Vector2, vel: Vector2, life: float, size: float, spin: float = 0.0) -> void:
	_p.append({"pos": pos, "vel": vel, "life": life, "age": 0.0, "size": size, "rot": _rng.randf() * TAU, "spin": spin})


## `count` particles flying out in all directions at speeds between lo and hi.
func burst(count: int, lo: float, hi: float, life: float, size: float) -> void:
	for i in count:
		var a := _rng.randf() * TAU
		add_particle(Vector2.ZERO, Vector2(cos(a), sin(a)) * _rng.randf_range(lo, hi), life * _rng.randf_range(0.7, 1.15), size * _rng.randf_range(0.6, 1.2))


func stop() -> void:
	continuous = false
	emit_rate = 0.0


func _process(delta: float) -> void:
	var d := delta * speed_scale
	if emit_rate > 0.0:
		_acc += d * emit_rate
		while _acc >= 1.0:
			_acc -= 1.0
			var a := emit_dir.angle() + deg_to_rad(_rng.randf_range(-emit_spread, emit_spread))
			add_particle(head, Vector2(cos(a), sin(a)) * _rng.randf_range(emit_speed.x, emit_speed.y), emit_life, size_scale * _rng.randf_range(0.6, 1.0))
	var i := _p.size() - 1
	while i >= 0:
		var q: Dictionary = _p[i]
		q["age"] += d
		if q["age"] >= q["life"]:
			_p.remove_at(i)
		else:
			q["vel"] = q["vel"] * maxf(0.0, 1.0 - damping * d) + Vector2(0, gravity) * d
			q["pos"] += q["vel"] * d
			q["rot"] += q["spin"] * d
		i -= 1
	queue_redraw()
	if _p.is_empty() and not continuous and emit_rate <= 0.0:
		queue_free()


func _draw() -> void:
	if tex == null:
		return
	var half := tex.get_size() * 0.5
	for q in _p:
		var t: float = q["age"] / q["life"]
		var c := col_from
		if col_mid.a > 0.0:
			c = col_from.lerp(col_mid, t / 0.45) if t < 0.45 else col_mid
		if fade:
			var f0 := 0.45 if col_mid.a > 0.0 else fade_from
			c.a *= 1.0 - clampf((t - f0) / (1.0 - f0), 0.0, 1.0)
		var s: float = q["size"] * (lerpf(1.0, 0.1, t) if shrink else 1.0)
		draw_set_transform(q["pos"], q["rot"], Vector2(s, s))
		draw_texture(tex, -half, c)
