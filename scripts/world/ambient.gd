class_name Ambient
extends Node2D
## Life on the map's ground, purely cosmetic: grazing sheep that scatter when a fold slams near
## them (or an enemy walks by), smoke curling from the hamlet's chimneys with the wind, ripples
## drifting down the river, the windmill's sails and the serpent of the mere.
## Sits in the map World under the buildings. main.gd sets `paper` and connects
## FoldController.slammed to on_slam. Owner: Claude.

const InkShader := preload("res://shaders/ink.gdshader")
const RIPPLES := 18
const FLOW := 9.0 ## ripple drift downstream, px/s
const SAIL_SPIN := 1.1 ## rad/s
const SAILS := preload("res://assets/sprites/terrain/windmill_sails.png")
const SERPENT := Vector2(19, 407)
const SERPENT_SKIN := Color("#6f8a64")
const FLOCKS := [Vector3(182, 238, 18), Vector3(96, 428, 16)] ## (x, y, pasture radius)
const SHEEP_PER_FLOCK := 5
const GRAZE_SPEED := 4.0
const PANIC_SPEED := 38.0
const PANIC_TIME := 1.3
const SCARE_SLAM := 70.0 ## a crease this close sends them running
const SCARE_ENEMY := 16.0
const WOOL := Color("#f6eedb")
const BAA_COOLDOWN := 12.0 ## s between baas at most
const BAA_CHANCE := 0.35 ## of a scare (off cooldown) making them baa
const BAA_VOLUME_DB := -12.0

var paper: Paper
var _sheep: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _smoke_cd := 0.0
var _scan := 0.0
var _time := 0.0
var _next_baa := 0.0
var _river_len := PackedFloat32Array() ## distance along the river at each point
var _ripples: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _ring_cd := 2.0


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = InkShader
	mat.set_shader_parameter("boil", 0.7)
	material = mat
	if paper:
		_river_len.append(0.0)
		for i in paper.river.size() - 1:
			_river_len.append(_river_len[i] + paper.river[i].distance_to(paper.river[i + 1]))
		for i in RIPPLES:
			_add_ripple(randf())
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
	if scared and _time >= _next_baa and randf() < BAA_CHANCE:
		_next_baa = _time + BAA_COOLDOWN
		Audio.play_sfx("baa", BAA_VOLUME_DB)


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
	_time += delta
	_update_smoke(delta)
	_update_water(delta)
	queue_redraw()


func _add_ripple(age: float) -> void:
	var life := randf_range(2.5, 4.0)
	_ripples.append({"s": randf() * _river_len[-1], "off": randf_range(-0.55, 0.55), "t": age * life, "life": life,
		"light": randf() < 0.7})


## Ripples drift downstream and fade; now and then something stirs the mere.
func _update_water(delta: float) -> void:
	if not paper:
		return
	for i in range(_ripples.size() - 1, -1, -1):
		var r: Dictionary = _ripples[i]
		r.t += delta
		r.s += FLOW * delta
		if r.t >= r.life or r.s >= _river_len[-1]:
			_ripples.remove_at(i)
			_add_ripple(0.0)
	_ring_cd -= delta
	if _ring_cd <= 0.0:
		_ring_cd = randf_range(2.5, 5.0)
		var a := randf_range(-1.2, 1.2)
		_rings.append({"pos": Decor.LAKE + Vector2(cos(a) * randf_range(20, 40), sin(a) * randf_range(4, 24)), "t": 0.0})
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].t += delta
		if _rings[i].t > 1.8:
			_rings.remove_at(i)


## Point and direction at distance s along the river.
func _river_at(s: float) -> Array:
	var r := paper.river
	var i := 0
	while i < r.size() - 2 and _river_len[i + 1] < s:
		i += 1
	var k := clampf((s - _river_len[i]) / maxf(_river_len[i + 1] - _river_len[i], 0.001), 0.0, 1.0)
	return [r[i].lerp(r[i + 1], k), (r[i + 1] - r[i]).normalized(), lerpf(paper.river_w[i], paper.river_w[i + 1], k)]


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
	if paper:
		_draw_water()
		_draw_serpent(SERPENT)
		_draw_sails(Decor.windmill_hub())
	for p in _smoke:
		var k: float = p.t / p.life
		var r: float = p.r * (1.0 + k * 2.2)
		var c: Vector2 = p.pos + Vector2(sin(p.t * 2.0 + p.seed) * 1.5, 0)
		var a := (1.0 - k) * minf(1.0, p.t * 4.0)
		draw_circle(c, r, Color(Palette.PARCHMENT, 0.5 * a))
		draw_arc(c, r, 0.0, TAU, 12, Color(Palette.SEPIA, 0.55 * a), 0.6)
	for s in _sheep:
		_draw_sheep(s)


func _draw_water() -> void:
	for r in _ripples:
		var at := _river_at(r.s)
		var p: Vector2 = at[0]
		var d: Vector2 = at[1]
		var w: float = at[2]
		if w < 2.5 or paper.bridges.any(func(b): return b.pos.distance_to(p) < b.w + 7.0):
			continue
		var n := d.orthogonal()
		var c: Vector2 = p + n * r.off * w
		var a: float = sin(PI * r.t / r.life) * (0.95 if r.light else 0.45)
		var col := Color(Palette.PARCHMENT, a) if r.light else Color(Palette.SEPIA, a)
		var len := clampf(w * 0.6, 1.5, 3.5)
		var pts := PackedVector2Array()
		for k in 5:
			var u := k / 4.0 * 2.0 - 1.0
			pts.append(c + d * u * len + n * sin(u * PI) * 0.6)
		draw_polyline(pts, col, 0.8)
	for ring in _rings:
		var k: float = ring.t / 1.8
		draw_set_transform(ring.pos, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 1.0 + k * 7.0, 0.0, TAU, 16, Color(Palette.SEPIA, 0.45 * (1.0 - k)), 0.6)
		if k > 0.25:
			draw_arc(Vector2.ZERO, 1.0 + (k - 0.25) * 7.0, 0.0, TAU, 16, Color(Palette.PARCHMENT, 0.5 * (1.0 - k)), 0.5)
		draw_set_transform(Vector2.ZERO)


## The mill's four lattice sails, turning.
func _draw_sails(hub: Vector2) -> void:
	draw_set_transform(hub, _time * SAIL_SPIN)
	draw_texture_rect(SAILS, Rect2(-14, -14, 28, 28), false)
	draw_set_transform(Vector2.ZERO)


## The serpent of the mere: two coils and a craning neck breaking the water, bobbing.
func _draw_serpent(o: Vector2) -> void:
	var bob := sin(_time * 1.3) * 0.7
	var ink := Color(Palette.INK, 0.85)
	var ring := Color(Palette.PARCHMENT, 0.7)
	# coils behind, each rising and sinking a little out of step
	for i in 2:
		var c := o + Vector2(-13.0 + i * 7.0, 0)
		var rise := 2.6 + sin(_time * 1.3 - 1.2 - i * 0.9) * 0.6
		draw_arc(c + Vector2(0, 3.0 - rise), 3.0, PI + 0.25, TAU - 0.25, 10, ink, 3.2)
		draw_arc(c + Vector2(0, 3.0 - rise), 3.0, PI + 0.25, TAU - 0.25, 10, SERPENT_SKIN, 1.8)
		for sx in [-1.0, 1.0]:
			draw_line(c + Vector2(sx * 3.5, 0.6), c + Vector2(sx * 5.5, 0.6), ring, 0.6)
	# neck: a thick inked curve rising to the head, fins along its back
	var head := o + Vector2(9, -12 + bob)
	var neck := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		neck.append(o.lerp(o + Vector2(2, -10 + bob), t).lerp((o + Vector2(2, -10 + bob)).lerp(head, t), t))
	draw_polyline(neck, ink, 3.6)
	for k in [3, 5]:
		var p := neck[k]
		var d := (neck[k + 1] - neck[k - 1]).normalized()
		var back := -d.orthogonal() if d.orthogonal().x > 0.0 else d.orthogonal()
		draw_colored_polygon(PackedVector2Array([p + d * 1.2, p - d * 1.2, p + back * 3.0 - d * 0.5]), ink)
	draw_polyline(neck, SERPENT_SKIN, 2.2)
	draw_line(o + Vector2(-2.5, 0.6), o + Vector2(-4.5, 0.6), ring, 0.6)
	draw_line(o + Vector2(3.5, 0.6), o + Vector2(5.5, 0.6), ring, 0.6)
	# head, snout to the right, and a flickering red tongue
	var skull := PackedVector2Array([head + Vector2(-2.0, -1.8), head + Vector2(2.5, -1.9), head + Vector2(6.0, -0.5),
		head + Vector2(6.0, 0.7), head + Vector2(2.0, 1.6), head + Vector2(-1.5, 1.6)])
	draw_colored_polygon(skull, SERPENT_SKIN)
	draw_polyline(skull + PackedVector2Array([skull[0]]), ink, 0.8)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-1.5, -1.6), head + Vector2(-3.5, -3.8), head + Vector2(0.5, -1.8)]), ink)
	draw_circle(head + Vector2(1.6, -0.5), 0.7, Palette.PARCHMENT)
	draw_circle(head + Vector2(1.8, -0.5), 0.35, Palette.INK)
	if fmod(_time, 3.1) < 0.35:
		var tip := head + Vector2(8.5, 0.6)
		draw_line(head + Vector2(6.0, 0.2), tip, Color(Palette.RED, 0.9), 0.5)
		draw_line(tip, tip + Vector2(1.0, -0.7), Color(Palette.RED, 0.9), 0.4)
		draw_line(tip, tip + Vector2(1.0, 0.7), Color(Palette.RED, 0.9), 0.4)


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
