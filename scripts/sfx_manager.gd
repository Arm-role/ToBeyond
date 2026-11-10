extends Node
## Sound effects synthesised in code (no audio files). Each sound is built the
## first time it is played and cached. A mute switch is saved in user://.
##   main.sfx.play("hit")      main.sfx.step(i)  (pentatonic steps for combos)
## Names: place step chime whoosh hit hurt win lose coin

const RATE := 22050
const PENTA := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
const SETTINGS := "user://settings.cfg"

var muted: bool = false
var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -7.0
		add_child(p)
		_pool.append(p)
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		muted = bool(cf.get_value("audio", "muted", false))
	AudioServer.set_bus_mute(0, muted)


func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(0, muted)
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("audio", "muted", muted)
	cf.save(SETTINGS)


## Pitch ratio of the i-th note of a rising pentatonic run (stops climbing at the top).
static func penta(i: int) -> float:
	return pow(2.0, float(PENTA[clampi(i, 0, PENTA.size() - 1)]) / 12.0)


func step(i: int) -> void:
	play("step", penta(i))


func play(sound: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if muted:
		return
	var s: AudioStreamWAV = _stream(sound)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _pool[_next]
		_next = (_next + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = -7.0 + vol_db
	p.play()


func _stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var f: PackedFloat32Array
	match sound:
		"place": f = _gen_place()
		"step": f = _gen_step()
		"chime": f = _gen_chime()
		"whoosh": f = _gen_whoosh()
		"hit": f = _gen_hit()
		"hurt": f = _gen_hurt()
		"win": f = _gen_win()
		"lose": f = _gen_lose()
		"coin": f = _gen_coin()
		_:
			return null
	var b := PackedByteArray()
	b.resize(f.size() * 2)
	for i in f.size():
		b.encode_s16(i * 2, int(clampf(f[i], -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = b
	_cache[sound] = s
	return s


func _buf(seconds: float) -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(int(seconds * RATE))
	return f


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _gen_place() -> PackedFloat32Array:
	var f := _buf(0.12)
	for i in f.size():
		var t := float(i) / RATE
		f[i] = sin(TAU * 130.0 * t) * exp(-t * 38.0) * 0.9 + _noise() * exp(-t * 110.0) * 0.35
	return f


func _gen_step() -> PackedFloat32Array:
	var f := _buf(0.2)
	for i in f.size():
		var t := float(i) / RATE
		f[i] = (sin(TAU * 440.0 * t) * exp(-t * 14.0) * 0.5 + sin(TAU * 880.0 * t) * exp(-t * 24.0) * 0.16) * minf(1.0, t / 0.003)
	return f


func _gen_chime() -> PackedFloat32Array:
	var f := _buf(0.5)
	for i in f.size():
		var t := float(i) / RATE
		var env := exp(-t * 6.5) * minf(1.0, t / 0.004)
		f[i] = (sin(TAU * 660.0 * t) + 0.55 * sin(TAU * 990.0 * t) + 0.28 * sin(TAU * 1320.0 * t) + 0.12 * sin(TAU * 1980.0 * t)) * env * 0.32
	return f


func _gen_whoosh() -> PackedFloat32Array:
	var dur := 0.45
	var f := _buf(dur)
	var lp := 0.0
	for i in f.size():
		var t := float(i) / RATE
		lp += (_noise() - lp) * lerpf(0.03, 0.35, t / dur)
		f[i] = lp * pow(sin(PI * t / dur), 1.5) * 2.0
	return f


func _gen_hit() -> PackedFloat32Array:
	var f := _buf(0.38)
	var phase := 0.0
	for i in f.size():
		var t := float(i) / RATE
		phase += TAU * (45.0 + 170.0 * exp(-t * 22.0)) / RATE
		f[i] = sin(phase) * exp(-t * 8.0) * 0.95 + _noise() * exp(-t * 45.0) * 0.45
	return f


func _gen_hurt() -> PackedFloat32Array:
	var f := _buf(0.35)
	var phase := 0.0
	for i in f.size():
		var t := float(i) / RATE
		phase += TAU * (70.0 + 60.0 * exp(-t * 14.0)) / RATE
		f[i] = (signf(sin(phase)) * 0.3 + _noise() * exp(-t * 20.0) * 0.3) * exp(-t * 7.0)
	return f


func _tone(f: PackedFloat32Array, start: float, freq: float, decay: float, level: float, tri: bool = false) -> void:
	var i0 := int(start * RATE)
	for i in range(i0, f.size()):
		var t := float(i - i0) / RATE
		var env := exp(-t * decay) * minf(1.0, t / 0.006)
		if t > 0.02 and env < 0.002:
			break
		var w := asin(sin(TAU * freq * t)) * 2.0 / PI if tri else sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.0 * t)
		f[i] += w * env * level


func _gen_win() -> PackedFloat32Array:
	var f := _buf(1.4)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for k in notes.size():
		_tone(f, k * 0.12, notes[k], 4.5 if k < 3 else 2.6, 0.26)
	return f


func _gen_lose() -> PackedFloat32Array:
	var f := _buf(1.6)
	var notes := [392.0, 329.63, 261.63, 196.0]
	for k in notes.size():
		_tone(f, k * 0.22, notes[k], 3.0, 0.4, true)
	return f


func _gen_coin() -> PackedFloat32Array:
	var f := _buf(0.3)
	_tone(f, 0.0, 988.0, 16.0, 0.3)
	_tone(f, 0.07, 1319.0, 12.0, 0.3)
	return f
