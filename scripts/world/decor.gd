class_name Decor
extends Node2D
## Old-map decoration drawn once into the baked parchment (paper.gd): a river running into a lake
## with a sea serpent, hatched hills, forests, the title banner, a compass rose and a scale bar.
## Purely cosmetic; everything stays sepia and faint so red and blue ink stay readable.
## Bridges are drawn by paper.gd on top of the roads. Owner: Claude.

const WATER := Color("#9fb4b2")
const LAKE := Vector2(-6, 398)
const LAKE_R := Vector2(50, 32)
## A little hamlet by the left tower; ambient.gd puffs smoke from its chimneys.
const HOUSES := [Vector2(50, 322), Vector2(67, 312), Vector2(82, 327)]

var paper: Paper
var _rng := RandomNumberGenerator.new()
var _font: Font


func _draw() -> void:
	_rng.seed = 11
	_font = ThemeDB.fallback_font
	_draw_water()
	_draw_serpent(Vector2(16, 400))
	_draw_hills([Vector3(150, 130, 38), Vector3(186, 116, 46), Vector3(224, 132, 36), Vector3(168, 152, 28),
		Vector3(206, 154, 30)])
	_draw_hills([Vector3(30, 196, 30), Vector3(58, 190, 34)])
	for f in [Vector3(58, 478, 30), Vector3(312, 238, 26), Vector3(302, 548, 26), Vector3(28, 92, 16),
		Vector3(262, 470, 12)]:
		_draw_forest(Vector2(f.x, f.y), f.z)
	_draw_cartouche(Vector2(180, 52), "THE FOLDED KEEP")
	_draw_compass(Vector2(318, 470), 20.0)
	_draw_scale_bar(Vector2(22, 548))
	_draw_hamlet()


## Chimney tops of the hamlet's houses (where the smoke comes out).
static func chimneys() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for h: Vector2 in HOUSES:
		out.append(h + Vector2(2.5, -10.5))
	return out


func _draw_hamlet() -> void:
	var houses: Array = HOUSES.duplicate()
	houses.sort_custom(func(a, b): return a.y < b.y)
	for h: Vector2 in houses:
		draw_rect(Rect2(h + Vector2(-4, -1), Vector2(10, 6)), Color(Palette.INK, 0.15))
		# chimney, walls, roof, door
		draw_rect(Rect2(h + Vector2(1.5, -10.5), Vector2(2, 5)), Palette.SEPIA)
		draw_rect(Rect2(h + Vector2(-5, -4), Vector2(10, 7)), Palette.PARCHMENT_MID)
		draw_rect(Rect2(h + Vector2(-5, -4), Vector2(10, 7)), Palette.SEPIA, false, 0.7)
		var roof := PackedVector2Array([h + Vector2(-6.5, -4), h + Vector2(0, -9.5), h + Vector2(6.5, -4)])
		draw_colored_polygon(roof, Color(Palette.RED, 0.7))
		draw_polyline(roof + PackedVector2Array([roof[0]]), Palette.SEPIA, 0.7)
		draw_rect(Rect2(h + Vector2(-1, -0.5), Vector2(2, 3.5)), Palette.SEPIA)


# --- water ------------------------------------------------------------------------------

func _draw_water() -> void:
	var lake := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		var wob := 1.0 + sin(a * 3.0 + 1.0) * 0.08 + sin(a * 5.0) * 0.05
		lake.append(LAKE + Vector2(cos(a) * LAKE_R.x, sin(a) * LAKE_R.y) * wob)
	var r := paper.river
	# the river: quads between offset banks, widening downstream
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in r.size():
		var d := (r[mini(i + 1, r.size() - 1)] - r[maxi(i - 1, 0)]).normalized()
		var w := lerpf(2.8, 5.5, float(i) / r.size())
		left.append(r[i] + d.orthogonal() * w)
		right.append(r[i] - d.orthogonal() * w)
	for i in r.size() - 1:
		draw_colored_polygon(PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]), Color(WATER, 0.75))
	draw_colored_polygon(lake, Color(WATER, 0.75))
	draw_polyline(left, Color(Palette.SEPIA, 0.8), 0.9)
	draw_polyline(right, Color(Palette.SEPIA, 0.8), 0.9)
	draw_polyline(lake + PackedVector2Array([lake[0]]), Color(Palette.SEPIA, 0.8), 0.9)
	# ripples: shore lines inside the lake, current strokes along the river
	var ring := PackedVector2Array()
	for p in lake:
		ring.append(LAKE + (p - LAKE) * 0.78)
	for i in range(0, ring.size() - 1, 2):
		draw_line(ring[i], ring[i + 1], Color(Palette.SEPIA, 0.35), 0.6)
	for i in range(2, r.size() - 3, 5):
		draw_line(r[i], r[i + 2], Color(Palette.SEPIA, 0.3), 0.6)


func _draw_serpent(p: Vector2) -> void:
	draw_set_transform(p, 0.0, Vector2.ONE * 1.6)
	p = Vector2.ZERO
	var ink := Color(Palette.INK, 0.8)
	# three humps breaking the water, then the head
	for i in 3:
		var c := p + Vector2(i * 7.0 - 12.0, 0)
		draw_arc(c, 3.2, PI, TAU, 8, ink, 1.1)
		draw_line(c + Vector2(-4.5, 1.2), c + Vector2(-2.5, 1.2), Color(Palette.SEPIA, 0.5), 0.6)
		draw_line(c + Vector2(2.5, 1.2), c + Vector2(4.5, 1.2), Color(Palette.SEPIA, 0.5), 0.6)
	var h := p + Vector2(12, -5)
	draw_line(p + Vector2(8, 0), h, ink, 1.1)
	draw_colored_polygon(PackedVector2Array([h + Vector2(-2, -2), h + Vector2(5, 0), h + Vector2(-1, 2)]), ink)
	draw_line(h + Vector2(5, 0), h + Vector2(8, -1), Color(Palette.RED, 0.8), 0.5)
	draw_circle(h + Vector2(0.5, -0.6), 0.5, Palette.PARCHMENT)
	draw_set_transform(Vector2.ZERO)


# --- land -------------------------------------------------------------------------------

## A range of hachured hills, back to front: each Vector3 is (x, base y, width).
func _draw_hills(hills: Array) -> void:
	hills.sort_custom(func(a, b): return a.y < b.y)
	for hv in hills:
		var base := Vector2(hv.x, hv.y)
		var w: float = hv.z
		var h := w * 0.5
		var outline := PackedVector2Array()
		for k in 17:
			var t := k / 16.0
			# half rounded mound, half peak
			var peak := 1.0 - absf(2.0 * t - 1.0)
			var s := lerpf(pow(sin(PI * t), 1.2), peak * peak * (3.0 - 2.0 * peak), 0.4)
			outline.append(base + Vector2((t - 0.5) * w, -h * s * (1.0 + 0.06 * sin(t * 19.0))))
		# fill so hills in front hide the ones behind
		draw_colored_polygon(outline, Color(Palette.PARCHMENT, 0.92))
		draw_polyline(outline, Color(Palette.SEPIA, 0.85), 0.9)
		# shading hachures down the shadowed (right) flank
		for k in range(9, 16):
			var top := outline[k]
			var len := (base.y - top.y) * 0.55
			draw_line(top + Vector2(-0.6, 1.0), top + Vector2(-len * 0.35, len), Color(Palette.SEPIA, 0.55), 0.55)
		# ground strokes at the foot
		draw_line(base + Vector2(-w * 0.55, 0.5), base + Vector2(-w * 0.35, 0.5), Color(Palette.SEPIA, 0.5), 0.6)
		draw_line(base + Vector2(w * 0.3, 0.5), base + Vector2(w * 0.6, 0.5), Color(Palette.SEPIA, 0.5), 0.6)


## A clump of trees scattered around `c`, kept off the roads and the river.
func _draw_forest(c: Vector2, radius: float) -> void:
	var trees: Array[Vector2] = []
	for i in int(radius * radius * 0.12):
		var p := c + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * radius
		if paper.near_road(p, 12.0) or paper.near_river(p, 8.0) or not Rect2(12, 30, 336, 598).has_point(p):
			continue
		if trees.any(func(q): return q.distance_to(p) < 6.5):
			continue
		trees.append(p)
	trees.sort_custom(func(a, b): return a.y < b.y)
	for p in trees:
		draw_set_transform(p + Vector2(1.5, 2.5), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 3.2, Color(Palette.INK, 0.12))
		draw_set_transform(Vector2.ZERO)
		if _rng.randf() < 0.45:
			# conifer
			var tri := PackedVector2Array([p + Vector2(0, -8), p + Vector2(3.6, 1), p + Vector2(-3.6, 1)])
			draw_colored_polygon(tri, Palette.PARCHMENT_MID)
			draw_polyline(tri + PackedVector2Array([tri[0]]), Color(Palette.SEPIA, 0.9), 0.7)
			draw_line(p + Vector2(0.5, -5), p + Vector2(2.2, 0), Color(Palette.SEPIA, 0.6), 0.5)
			draw_line(p + Vector2(0, 1), p + Vector2(0, 3), Palette.SEPIA, 0.8)
		else:
			# broadleaf lollipop with a shaded side
			draw_line(p + Vector2(0, -1), p + Vector2(0, 3), Palette.SEPIA, 0.9)
			draw_circle(p + Vector2(0, -4), 3.6, Color(Palette.SEPIA, 0.9))
			draw_circle(p + Vector2(-0.3, -4.2), 2.9, Palette.PARCHMENT_MID)
			draw_line(p + Vector2(1.2, -6), p + Vector2(2.2, -3), Color(Palette.SEPIA, 0.6), 0.5)
			draw_line(p + Vector2(0.4, -4.5), p + Vector2(1.4, -1.5), Color(Palette.SEPIA, 0.6), 0.5)


# --- cartography ------------------------------------------------------------------------

## A ribbon banner with the map's title.
func _draw_cartouche(c: Vector2, title: String) -> void:
	var size := 11
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var half := Vector2(tw * 0.5 + 16.0, 9.0)
	# tails behind the ribbon, folded under
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(sx * half.x, 4)
		var tail := PackedVector2Array([e + Vector2(-sx * 6, -6), e + Vector2(sx * 14, -6), e + Vector2(sx * 8, 1),
			e + Vector2(sx * 14, 8), e + Vector2(-sx * 6, 8)])
		draw_colored_polygon(tail, Palette.PARCHMENT_MID)
		draw_polyline(tail + PackedVector2Array([tail[0]]), Palette.SEPIA, 0.9)
		draw_colored_polygon(PackedVector2Array([c + Vector2(sx * half.x, half.y), c + Vector2(sx * (half.x - 6), half.y),
			c + Vector2(sx * half.x, half.y + 3)]), Palette.SEPIA)
	var body := Rect2(c - half, half * 2.0)
	draw_rect(body, Color("#efe2bf"))
	draw_rect(body, Palette.SEPIA, false, 1.0)
	draw_line(body.position + Vector2(3, 3), Vector2(body.end.x - 3, body.position.y + 3), Color(Palette.SEPIA, 0.4), 0.6)
	draw_line(Vector2(body.position.x + 3, body.end.y - 3), body.end - Vector2(3, 3), Color(Palette.SEPIA, 0.4), 0.6)
	draw_string(_font, c + Vector2(-tw * 0.5, size * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Palette.INK)
	for sx in [-1.0, 1.0]:
		draw_circle(c + Vector2(sx * (tw * 0.5 + 8.0), 0), 1.4, Palette.RED)


## An eight-point compass rose with a fleur of North.
func _draw_compass(c: Vector2, r: float) -> void:
	draw_arc(c, r * 0.72, 0.0, TAU, 32, Color(Palette.SEPIA, 0.8), 0.8)
	draw_arc(c, r * 0.64, 0.0, TAU, 32, Color(Palette.SEPIA, 0.5), 0.5)
	for i in 8:
		var a := i * PI * 0.25 - PI * 0.5
		var long := i % 2 == 0
		var tip := c + Vector2.from_angle(a) * r * (1.0 if long else 0.6)
		var side := Vector2.from_angle(a + PI * 0.5) * r * (0.16 if long else 0.1)
		# each point is split into a dark and a light half
		draw_colored_polygon(PackedVector2Array([c, tip, c + side]), Palette.SEPIA if long else Color(Palette.SEPIA, 0.7))
		draw_colored_polygon(PackedVector2Array([c, tip, c - side]), Palette.PARCHMENT)
		draw_polyline(PackedVector2Array([c + side, tip, c - side]), Palette.SEPIA, 0.6)
	draw_circle(c, 1.6, Palette.RED)
	var n := c + Vector2(0, -r - 6)
	var w := _font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(_font, n + Vector2(-w * 0.5, 3), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Palette.INK)


func _draw_scale_bar(p: Vector2) -> void:
	for i in 4:
		var r := Rect2(p + Vector2(i * 11.0, 0), Vector2(11, 3))
		draw_rect(r, Palette.SEPIA if i % 2 == 0 else Palette.PARCHMENT)
		draw_rect(r, Palette.SEPIA, false, 0.6)
	draw_string(_font, p + Vector2(0, 11), "LEAGUES", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(Palette.INK, 0.8))
