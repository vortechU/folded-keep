class_name Fx
extends Node2D
## Juice layer drawn on the map, above units: dust puffs, ink droplets, rings, stars, popups.
## One node draws every particle (cheap on web). Uses scaled time, so hit-stop freezes it.
## Get it with `Fx.of(node)`. The fold controller adds it to the Board, above the folded map.
## Owner: Claude (see DESIGN.md).

enum Kind { PUFF, DROP, RING, STAR, TEXT, SCRIBBLE }

const MAX_PARTS := 500
const MAP := Rect2(0, 0, 360, 640)

var _parts: Array[Dictionary] = []
var _font: Font


static func of(node: Node) -> Fx:
	return node.get_tree().get_first_node_in_group("fx") as Fx


func _ready() -> void:
	add_to_group("fx")
	z_index = 5
	_font = ThemeDB.fallback_font
	Events.keep_hit.connect(_on_keep_hit)
	Events.unit_crushed.connect(_on_unit_crushed)


func _process(delta: float) -> void:
	if _parts.is_empty():
		return
	var i := _parts.size() - 1
	while i >= 0:
		var p := _parts[i]
		p.t += delta
		if p.t >= p.life:
			_parts.remove_at(i)
		else:
			p.v *= pow(p.drag, delta)
			p.pos += p.v * delta
			if p.kind == Kind.DROP:
				p.vz -= 260.0 * delta
				p.z = maxf(0.0, p.z + p.vz * delta)
		i -= 1
	queue_redraw()


# --- emitters -------------------------------------------------------------

## A little cloud of paper dust, optionally pushed in a direction.
func dust(pos: Vector2, dir := Vector2.ZERO, count := 5, spread := 4.0, color := Palette.PARCHMENT_SHADOW) -> void:
	for i in count:
		var v := dir * randf_range(40.0, 90.0) + Vector2.from_angle(randf() * TAU) * randf_range(8.0, 30.0)
		_add({"kind": Kind.PUFF, "pos": pos + Vector2.from_angle(randf() * TAU) * randf() * spread,
			"v": v, "drag": 0.02, "life": randf_range(0.35, 0.6), "r": randf_range(2.0, 4.5), "color": color})


## Dust blown outward in a ring (buildings landing, flips).
func dust_ring(pos: Vector2, radius: float, count := 10) -> void:
	for i in count:
		var d := Vector2.from_angle(TAU * i / count + randf() * 0.3)
		_add({"kind": Kind.PUFF, "pos": pos + d * radius * 0.6, "v": d * randf_range(40.0, 70.0),
			"drag": 0.01, "life": randf_range(0.3, 0.5), "r": randf_range(2.0, 3.5), "color": Palette.PARCHMENT_SHADOW})


## Ink droplets that fly up and fall back onto the paper.
func droplets(pos: Vector2, color: Color, count := 8, power := 1.0) -> void:
	for i in count:
		_add({"kind": Kind.DROP, "pos": pos, "v": Vector2.from_angle(randf() * TAU) * randf_range(20.0, 70.0) * power,
			"drag": 0.2, "life": randf_range(0.4, 0.7), "r": randf_range(0.8, 1.8), "color": color,
			"z": 2.0, "vz": randf_range(60.0, 120.0) * power})


func ring(pos: Vector2, radius: float, color := Palette.INK, life := 0.3) -> void:
	_add({"kind": Kind.RING, "pos": pos, "v": Vector2.ZERO, "drag": 1.0, "life": life, "r": radius, "color": color})


## A cartoon impact burst (slaps).
func star(pos: Vector2, color := Palette.GOLD) -> void:
	_add({"kind": Kind.STAR, "pos": pos, "v": Vector2.ZERO, "drag": 1.0, "life": 0.22, "r": 9.0, "color": color,
		"a": randf() * TAU})


## A quill's quick sketch loop around a spot (something being drawn onto the map).
func scribble(pos: Vector2, radius: float, color := Palette.SEPIA) -> void:
	var pts := PackedVector2Array()
	var a0 := randf() * TAU
	for i in 22:
		var a := a0 + i * TAU * 2.2 / 22.0
		var r := radius * randf_range(0.75, 1.15)
		pts.append(pos + Vector2(cos(a) * r, sin(a) * r * 0.8))
	_add({"kind": Kind.SCRIBBLE, "pos": pos, "v": Vector2.ZERO, "drag": 1.0, "life": 0.5, "r": radius,
		"color": color, "pts": pts})


## Floating popup text (rewards, combos).
func text(pos: Vector2, msg: String, color := Palette.GOLD, big := false) -> void:
	pos = pos.clamp(MAP.position + Vector2(24, 30), MAP.end - Vector2(24, 12))
	_add({"kind": Kind.TEXT, "pos": pos, "v": Vector2(0, -28.0 if not big else -14.0), "drag": 0.15,
		"life": 0.8 if not big else 1.1, "r": 0.0, "color": color, "msg": msg, "size": 16 if big else 8})


## Everything a slam throws up: dust squeezed out from under the flap's edges and along the crease,
## plus a combo popup when several units get crushed at once.
func slam(m: Vector2, n: Vector2, outcomes: Array) -> void:
	# The crease itself.
	var t := n.orthogonal()
	var s := -800.0
	while s < 800.0:
		var p := m + t * s
		if MAP.has_point(p):
			dust(p + n * randf_range(-2.0, 2.0), -n * 0.4, 1, 2.0)
		s += 22.0
	# The flap's outer edges, where the air gets pushed out.
	var corners := [MAP.position, Vector2(MAP.end.x, 0), MAP.end, Vector2(0, MAP.end.y)]
	for c in 4:
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var steps := int(a.distance_to(b) / 16.0)
		for k in steps:
			var e := a.lerp(b, (k + 0.5) / steps)
			if FoldMath.side(e, m, n) <= 0.0:
				continue
			var q := FoldMath.mirror(e, m, n)
			if MAP.grow(-2.0).has_point(q):
				dust(q, -n, 2, 3.0)
	var crushed: Array[Vector2] = []
	for o in outcomes:
		if o.outcome == FoldController.Outcome.CRUSH:
			crushed.append(o.pos)
	if crushed.size() >= 2:
		var c := Vector2.ZERO
		for p in crushed:
			c += p
		text(c / crushed.size() + Vector2(0, -20), "x%d CRUSH!" % crushed.size(), Palette.RED_LIGHT, true)


# --- listeners ------------------------------------------------------------

func _on_keep_hit() -> void:
	var keep := Paper.KEEP_POS
	ring(keep, 30.0, Palette.RED, 0.35)
	droplets(keep + Vector2(0, -10), Palette.RED, 6)
	for b in get_tree().get_nodes_in_group("building"):
		if b.kind == "keep":
			b.jolt(Vector2(1.12, 0.88))


func _on_unit_crushed(u: Node) -> void:
	var reward: int = Waves.REWARDS.get(u.kind, 1)
	if u.team == Unit.Team.ENEMY and reward > 0:
		text(u.position + Vector2(0, -14), "+%d" % reward, Palette.GOLD, reward >= 10)


# --- internals ------------------------------------------------------------

func _add(p: Dictionary) -> void:
	if _parts.size() >= MAX_PARTS:
		_parts.pop_front()
	p.t = 0.0
	if not p.has("z"):
		p.z = 0.0
		p.vz = 0.0
	_parts.append(p)


func _draw() -> void:
	for p in _parts:
		var k: float = p.t / p.life
		var pos: Vector2 = p.pos
		var col: Color = p.color
		match p.kind:
			Kind.PUFF:
				var r: float = p.r * (0.6 + 0.8 * sqrt(k)) * (1.0 - k * k)
				draw_circle(pos, maxf(r, 0.5), Color(col, 0.75 * (1.0 - k)))
			Kind.DROP:
				var z: float = p.z
				draw_circle(pos, p.r, Color(0, 0, 0, 0.18))
				draw_circle(p.pos - Vector2(0, z), p.r, col)
			Kind.RING:
				var r: float = p.r * (0.3 + 0.7 * (1.0 - pow(1.0 - k, 3.0)))
				draw_arc(pos, r, 0.0, TAU, 24, Color(col, 1.0 - k), 2.0 * (1.0 - k) + 0.5)
			Kind.STAR:
				var r: float = p.r * (0.5 + k)
				for i in 6:
					var d := Vector2.from_angle(p.a + TAU * i / 6.0)
					draw_line(pos + d * r * 0.5, pos + d * r, Color(col, 1.0 - k), 1.5)
			Kind.SCRIBBLE:
				var pts: PackedVector2Array = p.pts
				var n := mini(pts.size(), int(pts.size() * k * 2.4) + 2)
				var a := clampf((1.0 - k) * 2.5, 0.0, 1.0)
				draw_polyline(pts.slice(0, n), Color(col, 0.8 * a), 1.0)
			Kind.TEXT:
				var fs: int = p.size
				var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - k * 8.0)
				var a := clampf((1.0 - k) * 3.0, 0.0, 1.0)
				draw_set_transform(pos, 0.0, Vector2.ONE * pop)
				var w := _font.get_string_size(p.msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var o := Vector2(-w * 0.5, fs * 0.35).round()
				for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
					draw_string(_font, o + d, p.msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.INK, a))
				draw_string(_font, o, p.msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
				draw_set_transform(Vector2.ZERO)
