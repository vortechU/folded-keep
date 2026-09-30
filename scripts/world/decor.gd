class_name Decor
extends Node2D
## Old-map decoration drawn once into the baked parchment (paper.gd): watercolor washes, the
## mountains the enemy comes from, a river rising at a spring and running into a lake, the Keep's
## moat, strip fields, hatched hills, forests, a hamlet with a windmill, ruins, milestones, a
## signpost, place names, a compass rose and a scale bar.
## Purely cosmetic; everything stays sepia and faint so red and blue ink stay readable.
## Bridges and roads are drawn by paper.gd on top. Animated bits (windmill sails, river ripples,
## the lake serpent) live in ambient.gd. Owner: Claude.

const WATER := Color("#9fb4b2")
const WATER_DEEP := Color("#7f9a9a")
const MEADOW := Color("#8e9f5c")
const OCHRE := Color("#c79a45")
const UMBER := Color("#7b5236")
const LAKE := Vector2(-6, 400)
const LAKE_R := Vector2(54, 36)
const MOAT := Vector2(180, 588)
const MOAT_R := Vector2(62, 30)
const MOAT_W := 4.5
## A little hamlet by the left tower; ambient.gd puffs smoke from its chimneys.
const HOUSES := [Vector2(50, 322), Vector2(67, 312), Vector2(82, 327)]
## Illustrated cottages (tools/draw_hamlet.py), one per house, and where each chimney tops out.
const COTTAGES := [preload("res://assets/sprites/terrain/cottage_a.png"),
	preload("res://assets/sprites/terrain/cottage_b.png"), preload("res://assets/sprites/terrain/cottage_c.png")]
const CHIMNEY_TOPS := [Vector2(-1.7, -14.6), Vector2(-1.4, -14.6), Vector2(-2.0, -14.6)]
const COTTAGE_RECT := Rect2(-9, -18, 20, 21)
const WINDMILL := Vector2(101, 303) ## foot of the mill; its sails turn in ambient.gd
const WINDMILL_TEX := preload("res://assets/sprites/terrain/windmill.png")
const WINDMILL_RECT := Rect2(-11, -24, 26, 28)
const RUINS := Vector2(158, 198)
const SIGNPOST := Vector2(162, 524)
const FONT_PATH := "res://scripts/ui/fonts/im_fell_english.ttf"

var paper: Paper
var _rng := RandomNumberGenerator.new()
var _font: Font


func _draw() -> void:
	_rng.seed = 11
	_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
	_draw_washes()
	_draw_fields(Vector2(184, 420), -0.12, 2, 2, Vector2(21, 27))
	_draw_fields(Vector2(86, 592), 0.1, 2, 1, Vector2(16, 30))
	_draw_fields(Vector2(274, 600), -0.08, 1, 2, Vector2(30, 14))
	_draw_river()
	_draw_lake()
	_draw_moat()
	_draw_mountains()
	_draw_spring(paper.river[0])
	_draw_hills([Vector3(152, 148, 30), Vector3(188, 142, 38), Vector3(222, 150, 28), Vector3(170, 166, 24),
		Vector3(206, 168, 26)])
	_draw_hills([Vector3(30, 196, 30), Vector3(58, 190, 34)])
	for f in [Vector3(64, 486, 30), Vector3(312, 238, 26), Vector3(302, 548, 26), Vector3(34, 140, 14),
		Vector3(262, 470, 12)]:
		_draw_forest(Vector2(f.x, f.y), f.z)
	_draw_ruins(RUINS)
	_draw_hamlet()
	_draw_windmill(WINDMILL)
	_draw_milestones()
	_draw_signpost(SIGNPOST)
	_draw_compass(Vector2(318, 470), 20.0)
	_draw_scale_bar(Vector2(22, 548))
	_draw_names()


## Chimney tops of the hamlet's houses (where the smoke comes out).
static func chimneys() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in HOUSES.size():
		out.append(HOUSES[i] + CHIMNEY_TOPS[i])
	return out


## Where the windmill's sails are pinned.
static func windmill_hub() -> Vector2:
	return WINDMILL + Vector2(0, -17.6)


# --- washes -----------------------------------------------------------------------------

## Hand-tinting, like an old map colored in watercolor: a dusky band over the enemy's mountains
## and soft green over the meadows and woods. Kept faint under everything else.
func _draw_washes() -> void:
	var band := PackedVector2Array([Vector2(0, 0), Vector2(360, 0)])
	for k in 25:
		var x := 360.0 - k * 15.0
		band.append(Vector2(x, _frontier_y(x)))
	draw_colored_polygon(band, Color(UMBER, 0.1))
	# the frontier: a faded red dash-dot border, as on a political map
	var x := 12.0
	var step := 0
	while x < 348.0:
		var p := Vector2(x, _frontier_y(x))
		if step % 3 == 2:
			draw_circle(p + Vector2(1.0, 0), 0.6, Color(Palette.RED, 0.4))
		else:
			draw_line(p, Vector2(x + 2.4, _frontier_y(x + 2.4)), Color(Palette.RED, 0.35), 0.9)
		x += 3.2
		step += 1
	for m in [Vector4(182, 240, 50, 34), Vector4(96, 432, 40, 30), Vector4(64, 486, 42, 38),
		Vector4(312, 236, 34, 32), Vector4(302, 548, 36, 30), Vector4(34, 140, 22, 20), Vector4(262, 470, 20, 17),
		Vector4(186, 300, 44, 22), Vector4(40, 205, 34, 22)]:
		_wash(Vector2(m.x, m.y), Vector2(m.z, m.w), MEADOW, 0.11)


func _frontier_y(x: float) -> float:
	return 114.0 + sin(x * 0.05) * 5.0 + sin(x * 0.13 + 1.0) * 3.0


## A soft wobbly blot of tint with a slightly darker rim where the pigment pooled.
func _wash(c: Vector2, r: Vector2, col: Color, alpha: float) -> void:
	var ph := _rng.randf() * TAU
	for layer in 3:
		var k := 1.0 - layer * 0.22
		var pts := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			var wob := 1.0 + 0.1 * sin(a * 3.0 + ph + layer) + 0.06 * sin(a * 7.0 + ph * 2.0)
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * wob * k)
		draw_colored_polygon(pts, Color(col, alpha if layer == 0 else alpha * 0.35))
		if layer == 0:
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(col, alpha * 0.9), 1.2)


# --- water ------------------------------------------------------------------------------

func _draw_river() -> void:
	var r := paper.river
	var w := paper.river_w
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in r.size():
		var n := Paper.tangent(r, i).orthogonal()
		left.append(r[i] + n * w[i])
		right.append(r[i] - n * w[i])
	for i in r.size() - 1:
		draw_colored_polygon(PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]), Color(WATER, 0.85))
	# a deeper channel down the middle
	for i in r.size() - 1:
		var na := Paper.tangent(r, i).orthogonal() * w[i] * 0.4
		var nb := Paper.tangent(r, i + 1).orthogonal() * w[i + 1] * 0.4
		draw_colored_polygon(PackedVector2Array([r[i] + na, r[i + 1] + nb, r[i + 1] - nb, r[i] - na]), Color(WATER_DEEP, 0.4))
	# broken current lines following each bank
	for i in r.size() - 1:
		if w[i] < 3.0 or (i / 3) % 2 == 1:
			continue
		for side: float in [-1.0, 1.0]:
			var na: Vector2 = Paper.tangent(r, i).orthogonal() * w[i] * 0.62 * side
			var nb: Vector2 = Paper.tangent(r, i + 1).orthogonal() * w[i + 1] * 0.62 * side
			draw_line(r[i] + na, r[i + 1] + nb, Color(Palette.SEPIA, 0.22), 0.5)
	# banks, stopping where the river runs into the lake; grass tufts along the outside
	for bank in [left, right]:
		var run := PackedVector2Array()
		for i in bank.size():
			if _in_lake(bank[i], 0.98):
				break
			run.append(bank[i])
		draw_polyline(run, Color(Palette.SEPIA, 0.85), 0.9)
	for i in range(1, r.size() - 1, 2):
		for side: float in [-1.0, 1.0]:
			var n: Vector2 = Paper.tangent(r, i).orthogonal() * side
			var p: Vector2 = r[i] + n * (w[i] + 1.2)
			if _in_lake(p, 1.1) or _rng.randf() < 0.35:
				continue
			var d := Paper.tangent(r, i)
			draw_line(p, p + n * 1.6 + d * 0.8, Color(Palette.SEPIA, 0.4), 0.5)


func _in_lake(p: Vector2, k: float) -> bool:
	return ((p - LAKE) / LAKE_R).length() < k


func _draw_lake() -> void:
	var lake := _ellipse(LAKE, LAKE_R, 32, 0.08)
	draw_colored_polygon(lake, Color(WATER, 0.85))
	draw_colored_polygon(_ellipse(LAKE + Vector2(-4, 2), LAKE_R * 0.55, 24, 0.1), Color(WATER_DEEP, 0.4))
	draw_polyline(lake + PackedVector2Array([lake[0]]), Color(Palette.SEPIA, 0.85), 0.9)
	# shore lines inside the water, like an engraver's
	for k: float in [0.84, 0.68]:
		for i in range(0, lake.size(), 2):
			var a := LAKE + (lake[i] - LAKE) * k
			var b := LAKE + (lake[(i + 1) % lake.size()] - LAKE) * k
			draw_line(a, b, Color(Palette.SEPIA, 0.3 if k > 0.8 else 0.2), 0.5)
	for i in lake.size():
		var n := (lake[i] - LAKE).normalized()
		if _rng.randf() < 0.5:
			draw_line(lake[i] + n * 1.2, lake[i] + n * 2.8, Color(Palette.SEPIA, 0.4), 0.5)


## The Keep's moat. Its far side runs behind the Keep, so only the near ring shows.
func _draw_moat() -> void:
	var outer := _ellipse(MOAT, MOAT_R + Vector2.ONE * MOAT_W, 48, 0.0)
	var inner := _ellipse(MOAT, MOAT_R - Vector2.ONE * MOAT_W, 48, 0.0)
	for i in outer.size():
		var j := (i + 1) % outer.size()
		draw_colored_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), Color(WATER, 0.85))
	draw_polyline(outer + PackedVector2Array([outer[0]]), Color(Palette.SEPIA, 0.85), 0.9)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(Palette.SEPIA, 0.85), 0.9)
	var mid := _ellipse(MOAT, MOAT_R, 48, 0.0)
	for i in range(0, mid.size(), 3):
		draw_line(mid[i], mid[(i + 1) % mid.size()], Color(Palette.SEPIA, 0.3), 0.5)
	# the gate's bridge across the near side
	var g := MOAT + Vector2(-5, MOAT_R.y)
	var deck := Rect2(g + Vector2(-4, -8), Vector2(8, 16))
	draw_rect(Rect2(deck.position + Vector2(1, 1.5), deck.size), Color(Palette.INK, 0.2))
	draw_rect(deck, Palette.PARCHMENT_MID)
	var y := deck.position.y + 2.0
	while y < deck.end.y - 1.0:
		draw_line(Vector2(deck.position.x, y), Vector2(deck.end.x, y), Color(Palette.SEPIA, 0.6), 0.5)
		y += 2.5
	for x in [deck.position.x, deck.end.x]:
		draw_line(Vector2(x, deck.position.y - 1), Vector2(x, deck.end.y + 1), Palette.SEPIA, 1.0)


## Where the river rises: a thin fall off the mountain's foot into a little tarn.
func _draw_spring(p: Vector2) -> void:
	var tarn := _ellipse(p + Vector2(-0.5, -1.0), Vector2(6.5, 3.2), 20, 0.1)
	draw_colored_polygon(tarn, Color(WATER, 0.9))
	draw_polyline(tarn + PackedVector2Array([tarn[0]]), Color(Palette.SEPIA, 0.85), 0.8)
	draw_line(p + Vector2(-3.5, -1.2), p + Vector2(1.5, -1.2), Color(Palette.SEPIA, 0.3), 0.5)
	for sx: float in [-1.0, 1.0]:
		var fall := PackedVector2Array()
		for k in 7:
			var t := k / 6.0
			fall.append(p + Vector2(sx * 0.9 + sin(t * 9.0 + sx) * 0.4, lerpf(-12.0, -3.5, t)))
		draw_polyline(fall, Color(WATER_DEEP, 0.95), 0.9)
	for sx: float in [-1.0, 1.0]:
		draw_arc(p + Vector2(sx * 2.4, -3.0), 1.3, PI, TAU, 6, Color(Palette.SEPIA, 0.6), 0.5)


func _ellipse(c: Vector2, r: Vector2, n: int, wobble: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		var wob := 1.0 + (sin(a * 3.0 + 1.0) * 0.08 + sin(a * 5.0) * 0.05) * wobble / 0.08
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * wob)
	return pts


# --- land -------------------------------------------------------------------------------

## Strip fields: a small grid of plots, each ploughed a different way, with a hedge along the top.
func _draw_fields(c: Vector2, angle: float, cols: int, rows: int, cell: Vector2) -> void:
	draw_set_transform(c, angle)
	var origin := -Vector2(cols * cell.x, rows * cell.y) * 0.5
	for gx in cols:
		for gy in rows:
			var rect := Rect2(origin + Vector2(gx * cell.x, gy * cell.y) + Vector2.ONE, cell - Vector2.ONE * 2.0)
			var green := (gx + gy) % 2 == 1
			draw_rect(rect, Color(MEADOW if green else OCHRE, 0.2))
			# furrows, alternating direction plot by plot
			if (gx + gy * 2) % 2 == 0:
				var x := rect.position.x + 2.0
				while x < rect.end.x - 1.0:
					draw_line(Vector2(x, rect.position.y + 1.0), Vector2(x, rect.end.y - 1.0), Color(Palette.SEPIA, 0.28), 0.5)
					x += 2.2
			else:
				var y := rect.position.y + 2.0
				while y < rect.end.y - 1.0:
					draw_line(Vector2(rect.position.x + 1.0, y), Vector2(rect.end.x - 1.0, y), Color(Palette.SEPIA, 0.28), 0.5)
					y += 2.2
			draw_rect(rect, Color(Palette.SEPIA, 0.55), false, 0.6)
	var x0 := origin.x
	while x0 < origin.x + cols * cell.x:
		draw_circle(Vector2(x0 + 1.5, origin.y - 0.5), 1.3, Color(Palette.SEPIA, 0.55))
		draw_circle(Vector2(x0 + 1.3, origin.y - 0.8), 0.9, Palette.PARCHMENT_MID)
		x0 += 3.0
	draw_set_transform(Vector2.ZERO)


## The mountains the enemy marches down from: sharp peaks, lit on the left and hatched in shadow
## on the right, with passes left open where the roads come through.
func _draw_mountains() -> void:
	var peaks := [
		Vector3(126, 64, 34), Vector3(160, 58, 42), Vector3(198, 56, 46), Vector3(234, 62, 38),
		Vector3(110, 90, 30), Vector3(144, 94, 36), Vector3(178, 96, 32), Vector3(212, 92, 38), Vector3(246, 88, 28),
		Vector3(22, 70, 26), Vector3(46, 62, 30), Vector3(32, 90, 24),
		Vector3(318, 66, 26), Vector3(342, 60, 30), Vector3(330, 82, 22),
	]
	peaks.sort_custom(func(a, b): return a.y < b.y)
	for pv in peaks:
		_draw_peak(Vector2(pv.x, pv.y), pv.z)


func _draw_peak(base: Vector2, w: float) -> void:
	var h := w * 0.8
	var apex := base + Vector2(_rng.randf_range(-0.1, 0.1) * w, -h)
	var lf := base - Vector2(w * 0.5, 0)
	var rf := base + Vector2(w * 0.5, 0)
	var lr := _ridge(lf, apex, h)
	var rr := _ridge(apex, rf, h)
	var outline := PackedVector2Array(lr + rr.slice(1))
	# paper-toned fill (matching the tinted band) so peaks in front hide the ones behind
	draw_colored_polygon(outline, Palette.PARCHMENT.lerp(Palette.PARCHMENT_MID, 0.35).lerp(UMBER, 0.08))
	# shadow side: from the ridge down to a crooked spur dropping from the peak
	var spur := [apex]
	for i in range(1, 5):
		var t := i / 4.0
		spur.append(apex.lerp(base + Vector2(w * 0.1, 0), t) + Vector2(_rng.randf_range(-0.8, 0.8) + t * 1.5, 0))
	var shade := PackedVector2Array(rr)
	for i in range(spur.size() - 1, 0, -1):
		shade.append(spur[i])
	draw_colored_polygon(shade, Color(UMBER, 0.28))
	var k := 0.06
	while k < 0.96:
		var top := _along(rr, k)
		var bot := _along(spur, k)
		draw_line(top + Vector2(-0.5, 0.8), top.lerp(bot, 0.8), Color(Palette.SEPIA, 0.55), 0.5)
		k += 0.06
	# rock strokes on the lit face
	for i in 3:
		var t := 0.35 + i * 0.2
		var a := _along(lr, t) + Vector2(1.8 + i * 0.6, 1.0)
		draw_line(a, a + Vector2(1.6, 3.0 + i * 0.5), Color(Palette.SEPIA, 0.35), 0.5)
	draw_polyline(PackedVector2Array(spur.slice(0, 4)), Color(Palette.SEPIA, 0.75), 0.6)
	draw_polyline(outline, Color(Palette.INK, 0.85), 0.95)
	draw_line(lf + Vector2(-3, 0.5), lf + Vector2(w * 0.15, 0.5), Color(Palette.SEPIA, 0.45), 0.6)


## A mountain ridge from a to b: concave (steeper near the top), with crags along it.
func _ridge(a: Vector2, b: Vector2, h: float) -> Array:
	var pts := [a]
	for i in range(1, 6):
		var t := i / 6.0
		var sag := sin(PI * t) * h * 0.1 # below the straight line on both flanks
		var jag := _rng.randf_range(-1.0, 1.0) * h * 0.04 if i % 2 == 0 else -h * 0.03
		pts.append(a.lerp(b, t) + Vector2(0, sag + jag))
	pts.append(b)
	return pts


## Point at fraction t along a short polyline (by segment count, good enough for ridges).
func _along(pts: Array, t: float) -> Vector2:
	var f := t * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return (pts[i] as Vector2).lerp(pts[i + 1], f - i)


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
		# fill so hills in front hide the ones behind, then a light shade on the right flank
		draw_colored_polygon(outline, Color(Palette.PARCHMENT, 0.92))
		var shade := outline.slice(8)
		shade.append(base + Vector2(w * 0.08, 0))
		draw_colored_polygon(shade, Color(UMBER, 0.1))
		draw_polyline(outline, Color(Palette.SEPIA, 0.85), 0.9)
		# shading hachures down the shadowed (right) flank
		for k in range(9, 16):
			var top := outline[k]
			var len := (base.y - top.y) * 0.55
			draw_line(top + Vector2(-0.6, 1.0), top + Vector2(-len * 0.35, len), Color(Palette.SEPIA, 0.55), 0.55)
		# ground strokes at the foot
		draw_line(base + Vector2(-w * 0.55, 0.5), base + Vector2(-w * 0.35, 0.5), Color(Palette.SEPIA, 0.5), 0.6)
		draw_line(base + Vector2(w * 0.3, 0.5), base + Vector2(w * 0.6, 0.5), Color(Palette.SEPIA, 0.5), 0.6)


## A clump of trees scattered around `c`, kept off the roads and the water.
func _draw_forest(c: Vector2, radius: float) -> void:
	var trees: Array[Vector2] = []
	for i in int(radius * radius * 0.14):
		var p := c + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * radius
		if paper.near_road(p, 12.0) or paper.river_clearance(p) < 4.0 or not Rect2(12, 30, 336, 598).has_point(p):
			continue
		if trees.any(func(q): return q.distance_to(p) < 6.0):
			continue
		trees.append(p)
	trees.sort_custom(func(a, b): return a.y < b.y)
	for p in trees:
		var s := _rng.randf_range(0.8, 1.2)
		draw_set_transform(p + Vector2(1.5, 2.5) * s, 0.0, Vector2(1.0, 0.45) * s)
		draw_circle(Vector2.ZERO, 3.2, Color(Palette.INK, 0.12))
		draw_set_transform(p, 0.0, Vector2.ONE * s)
		if _rng.randf() < 0.45:
			# conifer
			var tri := PackedVector2Array([Vector2(0, -8), Vector2(3.6, 1), Vector2(-3.6, 1)])
			draw_colored_polygon(tri, Palette.PARCHMENT_MID)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(3.6, 1), Vector2(0.6, 1)]), Color(MEADOW, 0.3))
			draw_polyline(tri + PackedVector2Array([tri[0]]), Color(Palette.SEPIA, 0.9), 0.7)
			draw_line(Vector2(0.5, -5), Vector2(2.2, 0), Color(Palette.SEPIA, 0.6), 0.5)
			draw_line(Vector2(0, 1), Vector2(0, 3), Palette.SEPIA, 0.8)
		else:
			# broadleaf lollipop with a shaded side
			draw_line(Vector2(0, -1), Vector2(0, 3), Palette.SEPIA, 0.9)
			draw_circle(Vector2(0, -4), 3.6, Color(Palette.SEPIA, 0.9))
			draw_circle(Vector2(-0.3, -4.2), 2.9, Palette.PARCHMENT_MID)
			draw_circle(Vector2(0.8, -3.6), 2.0, Color(MEADOW, 0.3))
			draw_line(Vector2(1.2, -6), Vector2(2.2, -3), Color(Palette.SEPIA, 0.6), 0.5)
			draw_line(Vector2(0.4, -4.5), Vector2(1.4, -1.5), Color(Palette.SEPIA, 0.6), 0.5)
		draw_set_transform(Vector2.ZERO)


# --- buildings & landmarks --------------------------------------------------------------

func _draw_hamlet() -> void:
	# a worn lane from the cottages past the mill to the road
	var lane := PackedVector2Array([Vector2(40, 330), Vector2(56, 327), Vector2(72, 321), Vector2(88, 315),
		Vector2(101, 309), Vector2(117, 303), Vector2(134, 300)])
	draw_polyline(lane, Color("#d3b988"), 3.2, true)
	draw_polyline(lane, Color(UMBER, 0.18), 1.2, true)
	# a fenced vegetable plot behind the first cottage
	var plot := Rect2(26, 306, 14, 11)
	draw_rect(plot, Color(MEADOW, 0.35))
	for k in 5:
		var y := plot.position.y + 1.6 + k * 2.1
		draw_line(Vector2(plot.position.x + 1, y), Vector2(plot.end.x - 1, y), Color(UMBER, 0.45), 0.6, true)
		for x in [29.0, 33.5, 37.5]:
			draw_circle(Vector2(x + (k % 2) * 1.2, y - 0.6), 0.7, Color(MEADOW.darkened(0.25), 0.9))
	draw_rect(plot, Color(Palette.SEPIA, 0.85), false, 0.5)
	for i in 8:
		var t := i / 7.0
		for post in [Vector2(lerpf(plot.position.x, plot.end.x, t), plot.position.y),
				Vector2(lerpf(plot.position.x, plot.end.x, t), plot.end.y)]:
			draw_line(post, post + Vector2(0, -1.4), Palette.SEPIA, 0.5)
	var order: Array = range(HOUSES.size())
	order.sort_custom(func(a, b): return HOUSES[a].y < HOUSES[b].y)
	for i: int in order:
		draw_texture_rect(COTTAGES[i], Rect2(HOUSES[i] + COTTAGE_RECT.position, COTTAGE_RECT.size), false)


## A stone tower mill on a grassy mound (the sails are drawn turning by ambient.gd).
func _draw_windmill(p: Vector2) -> void:
	draw_texture_rect(WINDMILL_TEX, Rect2(p + WINDMILL_RECT.position, WINDMILL_RECT.size), false)


## A ruined round tower and a broken wall, stones scattered in the grass.
func _draw_ruins(p: Vector2) -> void:
	draw_set_transform(p + Vector2(4, 2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 14.0, Color(Palette.INK, 0.1))
	draw_set_transform(Vector2.ZERO)
	# broken wall running off to the right
	var wall := PackedVector2Array([p + Vector2(4, 0), p + Vector2(4, -5), p + Vector2(8, -4), p + Vector2(10, -6),
		p + Vector2(13, -3), p + Vector2(17, -3.5), p + Vector2(18, 0)])
	draw_colored_polygon(wall, Palette.PARCHMENT_MID)
	draw_polyline(wall, Palette.SEPIA, 0.7)
	for x in [7.0, 11.0, 15.0]:
		draw_line(p + Vector2(x, -2), p + Vector2(x + 1.5, -2), Color(Palette.SEPIA, 0.5), 0.5)
	# the tower stump with a jagged top
	var tower := PackedVector2Array([p + Vector2(-5, 1), p + Vector2(-5, -9), p + Vector2(-3, -12), p + Vector2(-1, -9.5),
		p + Vector2(1, -13), p + Vector2(2.5, -10), p + Vector2(5, -8), p + Vector2(5, 1)])
	draw_colored_polygon(tower, Palette.PARCHMENT_MID)
	draw_colored_polygon(PackedVector2Array([p + Vector2(1.5, 1), p + Vector2(1.5, -11), p + Vector2(2.5, -10), p + Vector2(5, -8),
		p + Vector2(5, 1)]), Color(Palette.SEPIA, 0.25))
	draw_polyline(tower + PackedVector2Array([tower[0]]), Palette.SEPIA, 0.75)
	draw_rect(Rect2(p + Vector2(-1.5, -6), Vector2(2, 3)), Palette.SEPIA)
	for y in [-3.0, -7.0]:
		draw_line(p + Vector2(-5, y), p + Vector2(-2, y), Color(Palette.SEPIA, 0.5), 0.5)
	for off in [Vector2(-9, 2), Vector2(-7, 4), Vector2(9, 3), Vector2(21, 1), Vector2(13, 4)]:
		draw_circle(p + off, 1.1, Palette.PARCHMENT_MID)
		draw_arc(p + off, 1.1, 0.0, TAU, 8, Palette.SEPIA, 0.5)


## Little standing stones beside the roads, every so often.
func _draw_milestones() -> void:
	for r in paper.roads.size():
		var line := paper.roads[r]
		var walked := 0.0
		var next := 70.0 + r * 30.0
		var side := 1.0 if r == 0 else -1.0
		for i in line.size() - 1:
			walked += line[i].distance_to(line[i + 1])
			if walked < next:
				continue
			next += 115.0
			side = -side
			var p := line[i] + Paper.tangent(line, i).orthogonal() * side * (Paper.ROAD_W + 5.0)
			if p.y < 120.0 or p.y > 500.0 or paper.river_clearance(p) < 8.0 or paper.near_road(p, Paper.ROAD_W + 3.0):
				continue
			draw_set_transform(p + Vector2(1, 1.2), 0.0, Vector2(1.0, 0.4))
			draw_circle(Vector2.ZERO, 2.2, Color(Palette.INK, 0.18))
			draw_set_transform(Vector2.ZERO)
			var stone := PackedVector2Array([p + Vector2(-1.6, 0.5), p + Vector2(-1.6, -3), p + Vector2(-0.8, -4.2),
				p + Vector2(0.8, -4.2), p + Vector2(1.6, -3), p + Vector2(1.6, 0.5)])
			draw_colored_polygon(stone, Palette.PARCHMENT_MID)
			draw_polyline(stone, Palette.SEPIA, 0.6)
			draw_line(p + Vector2(-0.7, -2.4), p + Vector2(0.7, -2.4), Color(Palette.SEPIA, 0.6), 0.4)


## A fingerpost where the two roads meet, pointing back up both of them.
func _draw_signpost(p: Vector2) -> void:
	draw_set_transform(p + Vector2(1, 0.5), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 2.5, Color(Palette.INK, 0.18))
	draw_set_transform(Vector2.ZERO)
	draw_line(p, p + Vector2(0, -12), Palette.SEPIA, 1.0)
	for arm in [[-0.35, -11.0, -1.0], [0.3, -8.0, 1.0]]:
		draw_set_transform(p + Vector2(0, arm[1]), arm[0])
		var s: float = arm[2]
		var board := PackedVector2Array([Vector2(0, -1.2), Vector2(6.5 * s, -1.2), Vector2(8.0 * s, 0), Vector2(6.5 * s, 1.2), Vector2(0, 1.2)])
		draw_colored_polygon(board, Palette.PARCHMENT_MID)
		draw_polyline(board + PackedVector2Array([board[0]]), Palette.SEPIA, 0.5)
		draw_set_transform(Vector2.ZERO)


# --- cartography ------------------------------------------------------------------------

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
	_label("N", c + Vector2(0, -r - 5), 9, Palette.INK)


func _draw_scale_bar(p: Vector2) -> void:
	for i in 4:
		var r := Rect2(p + Vector2(i * 11.0, 0), Vector2(11, 3))
		draw_rect(r, Palette.SEPIA if i % 2 == 0 else Palette.PARCHMENT)
		draw_rect(r, Palette.SEPIA, false, 0.6)
	_label("Leagues", p + Vector2(22, 9), 7, Color(Palette.INK, 0.8))


## Place names, lettered in an old engraver's hand.
func _draw_names() -> void:
	_label("THE  DREAD  MARCHES", Vector2(180, 108), 8, Color(Palette.RED, 0.8), 1.2)
	_label("Littlebrook", Vector2(64, 342), 7, Color(Palette.INK, 0.75))
	_label("Serpent Mere", Vector2(40, 448), 7, Color(Palette.INK, 0.75))
	_label("Gloamwood", Vector2(64, 526), 7, Color(Palette.INK, 0.75))
	_label("Kingsfield", Vector2(184, 381), 7, Color(Palette.INK, 0.75))
	# the river's name follows its bend, on the stretch east of the right-hand bridge
	var r := paper.river
	var pts := PackedVector2Array()
	for i in r.size():
		if r[i].y > 282.0 and r[i].x > 250.0:
			pts.append(r[i] + Paper.tangent(r, i).orthogonal() * -(paper.river_w[i] + 7.0))
	if pts.size() > 2:
		if pts[0].x > pts[-1].x:
			pts.reverse()
		_label_along("River Wend", pts, 7, Color(Palette.INK, 0.75))


## Text centered on c (c.y is the middle of the lowercase letters), with a parchment halo so it
## reads over hatching.
func _label(text: String, c: Vector2, size: int, col: Color, spacing := 0.0) -> void:
	var widths := _glyph_widths(text, size, spacing)
	var total := 0.0
	for w in widths:
		total += w
	for pass_i in 2:
		var x := c.x - total * 0.5
		for i in text.length():
			_glyph(text[i], Vector2(x, c.y), 0.0, Vector2(0, size * 0.35), size, col, pass_i == 0)
			x += widths[i]


## Text laid along a polyline (left to right), centered on it.
func _label_along(text: String, pts: PackedVector2Array, size: int, col: Color) -> void:
	var cum: Array[float] = [0.0]
	for i in pts.size() - 1:
		cum.append(cum[-1] + pts[i].distance_to(pts[i + 1]))
	var widths := _glyph_widths(text, size, 0.4)
	var total := 0.0
	for w in widths:
		total += w
	for pass_i in 2:
		var s := (cum[-1] - total) * 0.5
		for i in text.length():
			var mid := s + widths[i] * 0.5
			var k := 0
			while k < pts.size() - 2 and cum[k + 1] < mid:
				k += 1
			var seg := pts[k + 1] - pts[k]
			var p := pts[k] + seg * clampf((mid - cum[k]) / maxf(seg.length(), 0.001), 0.0, 1.0)
			_glyph(text[i], p, seg.angle(), Vector2(-widths[i] * 0.5, size * 0.35), size, col, pass_i == 0)
			s += widths[i]


## Letters are rasterized at the bake's resolution (this node is drawn scaled up), so they stay sharp.
func _glyph_widths(text: String, size: int, spacing: float) -> Array[float]:
	var out: Array[float] = []
	for ch in text:
		out.append(_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size * Paper.BAKE_SCALE).x / Paper.BAKE_SCALE + spacing)
	return out


func _glyph(ch: String, at: Vector2, angle: float, off: Vector2, size: int, col: Color, halo: bool) -> void:
	var k := float(Paper.BAKE_SCALE)
	draw_set_transform(at, angle, Vector2.ONE / k)
	if halo:
		draw_char_outline(_font, off * k, ch, size * Paper.BAKE_SCALE, 4, Color(Palette.PARCHMENT, 0.6))
	else:
		draw_char(_font, off * k, ch, size * Paper.BAKE_SCALE, col)
	draw_set_transform(Vector2.ZERO)
