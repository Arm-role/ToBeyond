extends Node
## Idle "alive" motion for a card-like Control: a slow rock around the card's
## bottom edge plus a gentle breathing bob. Add it as a child of the card.
##
## It only touches the parent's rotation / scale / pivot_offset (never its
## position), so layout, deal and lift tweens keep working. When something
## else changes rotation or scale (trigger punch, tile pop, container resort)
## the sway steps aside, waits until that motion has settled, then fades back in.

@export var rot_deg: float = 1.2       # rocking amplitude
@export var bob: float = 0.012         # scale breathing amplitude (≈ vertical bob)

var _t: float = 0.0
var _rot_speed: float = 1.0
var _bob_speed: float = 1.0
var _last_rot: float = 0.0
var _last_scale: Vector2 = Vector2.ONE
var _hold: float = 0.0
var _weight: float = 0.0


func _ready() -> void:
	_t = randf() * 100.0
	_rot_speed = TAU / randf_range(2.8, 3.8)
	_bob_speed = TAU / randf_range(2.2, 3.0)
	var p := get_parent() as Control
	if p != null:
		_last_rot = p.rotation
		_last_scale = p.scale


func _process(delta: float) -> void:
	var p := get_parent() as Control
	if p == null or not p.is_visible_in_tree():
		return
	_t += delta
	if not is_equal_approx(p.rotation, _last_rot) or not p.scale.is_equal_approx(_last_scale):
		# Someone else is animating the card: let it finish.
		_last_rot = p.rotation
		_last_scale = p.scale
		_hold = 0.12
		_weight = 0.0
		return
	if _hold > 0.0:
		_hold -= delta
		return
	_weight = minf(1.0, _weight + delta / 0.5)
	p.pivot_offset = Vector2(p.size.x * 0.5, p.size.y)
	p.rotation = deg_to_rad(rot_deg) * sin(_t * _rot_speed) * _weight
	var s := 1.0 + bob * (0.5 + 0.5 * sin(_t * _bob_speed)) * _weight
	p.scale = Vector2(s, s)
	_last_rot = p.rotation
	_last_scale = p.scale


## Remove the sway and put the card back to rest.
func stop() -> void:
	var p := get_parent() as Control
	if p != null and is_equal_approx(p.rotation, _last_rot) and p.scale.is_equal_approx(_last_scale):
		p.rotation = 0.0
		p.scale = Vector2.ONE
	queue_free()
