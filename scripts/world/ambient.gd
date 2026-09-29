class_name Ambient
extends Node2D
## Life on the map's ground, purely cosmetic: grazing sheep that scatter when a fold slams near
## them (or an enemy walks by), and smoke curling from the hamlet's chimneys with the wind.
## Sits in the map World under the buildings. main.gd connects FoldController.slammed to on_slam.
## Owner: Claude.

const InkShader := preload("res://shaders/ink.gdshader")
const FLOCKS := [Vector3(182, 238, 18), Vector3(96, 428, 16)] ## (x, y, pasture radius)
const SHEEP_PER_FLOCK := 5
const GRAZE_SPEED := 4.0
const PANIC_SPEED := 38.0
const PANIC_TIME := 1.3
const SCARE_SLAM := 70.0 ## a crease this close sends them running
const SCARE_ENEMY := 16.0
const WOOL := Color("#f6eedb")

var _sheep: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _smoke_cd := 0.0
var _scan := 0.0


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = InkShader
	mat.set_shader_parameter("boil", 0.7)
	material = mat
	for f in FLOCKS:
		for i in SHEEP_PER_FLOCK:
			var home := Vector2(f.x, f.y)
			var p: Vector2 = home + Vector2.from_angle(randf() * TAU) * randf() * f.z
			_sheep.append({"pos": p, "home": home, "r": f.z, "target": p, "wait": randf_range(0.0, 4.0),
				"panic": 0.0, "flee": Vector2.ZERO, "face": 1.0 if randf() < 0.5 else -1.0, "t": randf() * 10.0, "hop": 0.0})


## A fold slammed along (m, n): sheep near the crease bolt away from it.
func on_slam(m: Vector2, n: Vector2, _outcomes: Array) -> void:
	var scared := false
	for s in _sheep:
		var d := FoldMath.side(s.pos, m, n)
		if absf(d) < SCARE_SLAM or FoldMath.side(s.pos, m, n) > 0.0:
			_scare(s, -n if d < 0.0 else n)
			scared = true
	if scared:
		Audio.play_sfx("baa")


func _scare(s: Dictionary, away: Vector2) -> void:
	s.panic = PANIC_TIME * randf_range(0.8, 1.2)
	s.flee = (away + Vector2.from_angle(randf() * TAU) * 0.6).normalized()
	s.hop = 1.0


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.3
		for e in get_tree().get_nodes_in_group("enemy"):
			if not e.is_alive() or e.is_flying():
				continue
			for s in _sheep:
				if s.panic <= 0.0 and s.pos.distance_to(e.position) < SCARE_ENEMY:
					_scare(s, (s.pos - e.position).normalized())
	for s in _sheep:
		s.t += delta
		s.hop = maxf(0.0, s.hop - delta * 3.0)
		var step := Vector2.ZERO
		if s.panic > 0.0:
			s.panic -= delta
			step = s.flee * PANIC_SPEED * delta
		elif s.wait > 0.0:
			s.wait -= delta
		else:
			var to: Vector2 = s.target - s.pos
			if to.length() < 1.0:
				# graze a while, then amble to a new spot in the pasture (wanderers drift home)
				s.wait = randf_range(1.5, 5.0)
				var back: Vector2 = s.home - s.pos
				var r: float = s.r
				s.target = s.pos + back * 0.5 + Vector2.from_angle(randf() * TAU) * randf() * r * 0.8 \
					if back.length() > r else s.home + Vector2.from_angle(randf() * TAU) * randf() * r
			else:
				step = to.normalized() * minf(GRAZE_SPEED * delta, to.length())
		if absf(step.x) > 0.01:
			s.face = signf(step.x)
		s.pos = (s.pos + step).clamp(Vector2(14, 34), Vector2(346, 626))
	_update_smoke(delta)
	queue_redraw()


func _update_smoke(delta: float) -> void:
	_smoke_cd -= delta
	if _smoke_cd <= 0.0:
		_smoke_cd = 0.55
		for c in Decor.chimneys():
			_smoke.append({"pos": c + Vector2(randf_range(-0.5, 0.5), 0), "t": 0.0, "life": randf_range(2.4, 3.2),
				"r": randf_range(1.2, 1.8), "seed": randf() * TAU})
	for i in range(_smoke.size() - 1, -1, -1):
		var p: Dictionary = _smoke[i]
		p.t += delta
		# rises, then leans over with the wind
		p.pos += (Vector2(0, -7.0) + Wind.DIR * Wind.SPEED * minf(p.t, 1.5)) * delta
		if p.t >= p.life:
			_smoke.remove_at(i)


func _draw() -> void:
	for p in _smoke:
		var k: float = p.t / p.life
		var r: float = p.r * (1.0 + k * 2.2)
		var c: Vector2 = p.pos + Vector2(sin(p.t * 2.0 + p.seed) * 1.5, 0)
		var a := (1.0 - k) * minf(1.0, p.t * 4.0)
		draw_circle(c, r, Color(Palette.PARCHMENT, 0.5 * a))
		draw_arc(c, r, 0.0, TAU, 12, Color(Palette.SEPIA, 0.55 * a), 0.6)
	for s in _sheep:
		_draw_sheep(s)


func _draw_sheep(s: Dictionary) -> void:
	var p: Vector2 = s.pos
	var f: float = s.face
	var moving: bool = s.panic > 0.0 or s.wait <= 0.0
	var bob := absf(sin(s.t * (22.0 if s.panic > 0.0 else 10.0))) * (1.0 if moving else 0.0)
	var lift: float = s.hop * 3.0 + bob * 0.6
	draw_set_transform(p + Vector2(0.5, 1.5), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 3.2, Color(Palette.INK, 0.15))
	draw_set_transform(p + Vector2(0, -lift), 0.0, Vector2(f, 1.0))
	# legs (scissoring while walking), woolly body, black face
	var sw := sin(s.t * 20.0) * 0.8 if moving else 0.0
	for x in [-1.8, 1.6]:
		draw_line(Vector2(x + sw, 0.5), Vector2(x - sw, 2.4), Palette.INK, 0.7)
	for c in [Vector2(-1.6, -1.6), Vector2(0.4, -2.2), Vector2(1.6, -1.2), Vector2(-0.4, -0.6)]:
		draw_circle(c, 2.0, Palette.SEPIA)
	for c in [Vector2(-1.6, -1.6), Vector2(0.4, -2.2), Vector2(1.6, -1.2), Vector2(-0.4, -0.6)]:
		draw_circle(c, 1.5, WOOL)
	# grazing sheep lower their heads
	var head := Vector2(3.4, -1.2 if moving else 0.4)
	draw_circle(head, 1.2, Palette.INK)
	draw_set_transform(Vector2.ZERO)
	if s.panic > 0.0 and s.hop > 0.3:
		draw_string(ThemeDB.fallback_font, p + Vector2(-1.5, -7 - lift), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.INK)
