class_name Weather
extends Node2D
## Weather over the map, rolled for each wave (`roll`) and fading out when the wave ends:
##   rain  - ink-hatched rain streaks, splashes and wet spots soaking into the paper
##   storm - heavier rain, lightning bolts (scorch marks, a screen flash via `lightning`), and wind
##           gusts that shove Crow Riders sideways (`Weather.gust`, read by Unit._flyer_step)
##   fog   - fog banks, thick along the top edge where enemies come in, thin at the Keep
## Lives at the top of the map World so it folds with the map; wet spots and scorch marks are drawn
## on `ground` (a node just above the paper, set up in `_ready`). Owner: Claude.

signal lightning(pos: Vector2) ## a bolt struck: main flashes the whole screen

const FogShader := preload("res://shaders/fog.gdshader")
const BANNERS := {"rain": "RAIN SWEEPS IN", "storm": "A STORM ROLLS IN", "fog": "FOG CREEPS IN"}
const FADE := 2.5 ## seconds to fade weather in or out
const CHANCE := 0.6 ## of weather on a wave after the scripted ones
const DROPS_PER_SEC := {"rain": 320.0, "storm": 650.0}
const FALL := Vector2(70, 330) ## rain streak velocity, px/s (leaning with Wind.DIR)
const STREAK := 15.0
const RAIN := Color("#34405a")
const TINT := {"rain": Color(0.14, 0.17, 0.26, 0.14), "storm": Color(0.10, 0.11, 0.2, 0.24)}
const MAX_WET := 70
const LIGHTNING_EVERY := Vector2(5.0, 10.0)
const GUST_EVERY := Vector2(3.5, 6.5)
const GUST_TIME := 2.8
const GUST_SPEED := 34.0 ## px/s sideways at the peak of a gust (Crow Riders fly at 22)
const MAP := Rect2(Vector2.ZERO, Paper.SIZE)

## The storm's wind right now (px/s). Crow Riders drift with it.
static var gust := Vector2.ZERO

var kind := "clear"
var forced := "" ## debug: `?weather=storm` / `-- --weather=storm` picks the weather of every wave
var ground: Node2D
var _last := "clear"
var _amount := 0.0
var _target := 0.0
var _drops: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _wet: Array[Dictionary] = []
var _bolts: Array[Dictionary] = []
var _streaks: Array[Dictionary] = []
var _drop_acc := 0.0
var _lightning_cd := 3.0
var _gust_cd := 2.0
var _gust_t := -1.0
var _gust_dir := Vector2.RIGHT
var _fog: Node2D
var _fog_mat: ShaderMaterial


func _ready() -> void:
	gust = Vector2.ZERO
	ground = Node2D.new()
	ground.name = "WeatherGround"
	ground.draw.connect(_draw_ground)
	_fog = Node2D.new()
	_fog.name = "Fog"
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = FogShader
	_fog.material = _fog_mat
	_fog.draw.connect(func(): _fog.draw_rect(MAP, Color.WHITE))
	_fog.visible = false
	add_child(_fog)
	Events.phase_changed.connect(_on_phase_changed)


## Picks the weather for wave `i` (0-based) and fades it in. Returns the banner line ("" = clear).
## Wave 2 always rains so everyone sees weather early; storms only come with Crow Riders to shove.
func roll(i: int, has_flyers: bool) -> String:
	var pick := "clear"
	if forced != "":
		pick = forced
	elif i == 1:
		pick = "rain"
	elif i >= 3 and randf() < CHANCE:
		var pool := ["rain", "fog"]
		if has_flyers:
			pool += ["storm", "storm"]
		pool.erase(_last)
		pick = pool.pick_random()
	_last = pick
	if pick == "clear":
		clear()
		return ""
	kind = pick
	_target = 1.0
	_lightning_cd = randf_range(2.0, 4.0)
	_gust_cd = randf_range(1.5, 3.0)
	Audio.set_ambience("storm" if pick == "storm" else "rain" if pick == "rain" else "")
	return BANNERS[pick]


func _on_phase_changed(phase: String) -> void:
	if phase != "wave":
		clear()


func clear() -> void:
	_target = 0.0
	Audio.set_ambience("")


func _process(delta: float) -> void:
	_amount = move_toward(_amount, _target, delta / FADE)
	if _amount <= 0.0 and _target <= 0.0:
		kind = "clear"
	var raining := kind == "rain" or kind == "storm"
	if raining:
		_drop_acc += DROPS_PER_SEC[kind] * _amount * delta
		while _drop_acc >= 1.0:
			_drop_acc -= 1.0
			_add_drop()
	if kind == "storm":
		_storm(delta)
	else:
		gust = Vector2.ZERO
		_gust_t = -1.0
	_step(delta)
	_fog.visible = kind == "fog"
	if _fog.visible:
		_fog_mat.set_shader_parameter("amount", _amount)
	queue_redraw()
	ground.queue_redraw()


func _add_drop() -> void:
	var life := randf_range(0.12, 0.3)
	var land := Vector2(randf_range(-10, MAP.size.x + 10), randf_range(-10, MAP.size.y + 10))
	_drops.append({"land": land, "t": 0.0, "life": life})


## Lightning now and then, and gusts of wind that sweep across the map (and the Crow Riders).
func _storm(delta: float) -> void:
	_lightning_cd -= delta
	if _lightning_cd <= 0.0 and _amount > 0.6:
		_lightning_cd = randf_range(LIGHTNING_EVERY.x, LIGHTNING_EVERY.y)
		_strike(Vector2(randf_range(30, MAP.size.x - 30), randf_range(60, MAP.size.y - 140)))
	if _gust_t < 0.0:
		_gust_cd -= delta
		if _gust_cd <= 0.0 and _amount > 0.6:
			_gust_t = 0.0
			_gust_dir = Vector2(1.0 if randf() < 0.5 else -1.0, randf_range(-0.2, 0.2)).normalized()
			Audio.play_sfx("wind_gust")
	if _gust_t >= 0.0:
		_gust_t += delta
		var env := sin(PI * clampf(_gust_t / GUST_TIME, 0.0, 1.0))
		gust = _gust_dir * GUST_SPEED * env * _amount
		# streaks of wind racing across the page with it
		if randf() < env * delta * 26.0:
			var y := randf_range(20, MAP.size.y - 20)
			var x := -40.0 if _gust_dir.x > 0.0 else MAP.size.x + 40.0
			_streaks.append({"pos": Vector2(x, y), "len": randf_range(30, 70), "t": 0.0, "wave": randf() * TAU})
		if _gust_t >= GUST_TIME:
			_gust_t = -1.0
			gust = Vector2.ZERO
			_gust_cd = randf_range(GUST_EVERY.x, GUST_EVERY.y)


func _strike(p: Vector2) -> void:
	# a jagged bolt from off the top of the page down to `p`, with a fork or two
	var pts := PackedVector2Array()
	var from := p + Vector2(randf_range(-60, 60), -p.y - 30.0)
	var n := 9
	for i in n + 1:
		var u := float(i) / n
		var jag := Vector2(randf_range(-14, 14), 0) if i > 0 and i < n else Vector2.ZERO
		pts.append(from.lerp(p, u) + jag)
	var forks: Array[PackedVector2Array] = []
	for f in randi_range(1, 2):
		var at := randi_range(3, n - 2)
		var fork := PackedVector2Array([pts[at]])
		var dir := Vector2(randf_range(-1, 1) * 0.8, 1.0).normalized()
		for k in 3:
			fork.append(fork[k] + dir.rotated(randf_range(-0.5, 0.5)) * randf_range(12, 20))
		forks.append(fork)
	_bolts.append({"pts": pts, "forks": forks, "t": 0.0})
	_wet.append({"pos": p, "r": 9.0, "t": 0.0, "life": 12.0, "scorch": true})
	var fx := Fx.of(self)
	if fx:
		fx.dust_ring(p, 10.0, 8)
		fx.ring(p, 18.0, Palette.GOLD, 0.35)
	lightning.emit(p)
	get_tree().create_timer(randf_range(0.15, 0.5), false).timeout.connect(func(): Audio.play_sfx("thunder"))


func _step(delta: float) -> void:
	for i in range(_drops.size() - 1, -1, -1):
		var d: Dictionary = _drops[i]
		d.t += delta
		if d.t >= d.life:
			_drops.remove_at(i)
			if MAP.has_point(d.land):
				_splashes.append({"pos": d.land, "t": 0.0})
				if randf() < 0.05 and _wet.size() < MAX_WET:
					_wet.append({"pos": d.land, "r": randf_range(2.5, 6.0), "t": 0.0,
						"life": randf_range(4.0, 8.0), "scorch": false})
	for i in range(_splashes.size() - 1, -1, -1):
		_splashes[i].t += delta
		if _splashes[i].t >= 0.3:
			_splashes.remove_at(i)
	for i in range(_wet.size() - 1, -1, -1):
		_wet[i].t += delta
		if _wet[i].t >= _wet[i].life:
			_wet.remove_at(i)
	for i in range(_bolts.size() - 1, -1, -1):
		_bolts[i].t += delta
		if _bolts[i].t >= 0.45:
			_bolts.remove_at(i)
	for i in range(_streaks.size() - 1, -1, -1):
		var s: Dictionary = _streaks[i]
		s.t += delta
		s.pos += _gust_dir * 300.0 * delta
		if s.t >= 1.6:
			_streaks.remove_at(i)


## Wet spots and scorch marks soak into the paper, under everything standing on it.
func _draw_ground() -> void:
	for w in _wet:
		var t: float = w.t / w.life
		var a := clampf(w.t / 0.3, 0.0, 1.0) * (1.0 - t * t)
		if w.scorch:
			ground.draw_circle(w.pos, w.r * 1.6, Color(Palette.INK, 0.12 * a))
			ground.draw_circle(w.pos, w.r, Color(Palette.INK, 0.3 * a))
			for k in 7:
				var dir := Vector2.from_angle(k * TAU / 7.0 + w.r)
				ground.draw_line(w.pos + dir * w.r * 0.6, w.pos + dir * w.r * 1.9, Color(Palette.INK, 0.28 * a), 1.0)
		else:
			ground.draw_circle(w.pos, w.r, Color(RAIN, 0.13 * a))
			ground.draw_circle(w.pos + Vector2(w.r * 0.3, -w.r * 0.2), w.r * 0.55, Color(RAIN, 0.08 * a))


func _draw() -> void:
	if kind == "clear":
		return
	if TINT.has(kind):
		var tint: Color = TINT[kind]
		draw_rect(MAP, Color(tint, tint.a * _amount))
	var fall := FALL + gust * 5.0
	var dir := fall.normalized()
	for d in _drops:
		# the streak falls onto its landing point
		var left: float = d.life - d.t
		var head: Vector2 = d.land - fall * left * 0.12
		var a := clampf(d.t / 0.06, 0.0, 1.0) * 0.6
		draw_line(head - dir * STREAK, head, Color(RAIN, a), 1.1)
	for s in _splashes:
		var u: float = s.t / 0.3
		draw_set_transform(s.pos, 0.0, Vector2(1.0, 0.6))
		draw_arc(Vector2.ZERO, 1.0 + u * 4.0, 0.0, TAU, 8, Color(RAIN, 0.6 * (1.0 - u)), 0.9)
	draw_set_transform(Vector2.ZERO)
	for s in _streaks:
		var a := sin(PI * clampf(s.t / 1.6, 0.0, 1.0)) * 0.35
		var pts := PackedVector2Array()
		for k in 8:
			var x: float = -_gust_dir.x * s.len * k / 7.0
			pts.append(s.pos + Vector2(x, sin(s.wave + k * 0.8 + s.t * 6.0) * 2.0))
		draw_polyline(pts, Color(Palette.PARCHMENT, a), 1.2)
	for b in _bolts:
		var u: float = b.t / 0.45
		var flick := 1.0 if u < 0.15 or (u > 0.28 and u < 0.4) else 0.35
		var a := (1.0 - u) * flick
		var lines: Array[PackedVector2Array] = [b.pts]
		lines.append_array(b.forks)
		for line in lines:
			draw_polyline(line, Color(Palette.INK, 0.7 * a), 4.0)
			draw_polyline(line, Color(1.0, 0.97, 0.8, a), 1.8)
