class_name Paper
extends Node2D
## The parchment itself: aged paper + old-map decoration (baked once, see decor.gd), frame,
## roads and the bridges where they cross the river.

const SIZE := Vector2(360, 640)
const KEEP_POS := Vector2(180, 575)
## Where the two roads join for the last stretch to the Keep.
const MERGE := Vector2(180, 515)
const ROAD_W := 5.0 ## half-width of a road
const ROAD_POINTS := [
	[Vector2(70, -10), Vector2(80, 120), Vector2(140, 230), Vector2(125, 360), Vector2(160, 462), MERGE,
		Vector2(180, 545), KEEP_POS],
	[Vector2(295, -10), Vector2(280, 140), Vector2(220, 260), Vector2(240, 380), Vector2(200, 468), MERGE,
		Vector2(180, 545), KEEP_POS],
]

## The river, as control points (smoothed in _ready): it rises at a spring under the mountains in
## the top-right, runs down the east side, then west across both roads into the lake.
## Decorative: units cross it on the bridges.
const RIVER_POINTS := [Vector2(333, 90), Vector2(331, 120), Vector2(338, 160), Vector2(329, 205),
	Vector2(336, 250), Vector2(326, 290), Vector2(300, 314), Vector2(262, 325), Vector2(228, 318),
	Vector2(198, 330), Vector2(168, 348), Vector2(140, 345), Vector2(112, 352), Vector2(84, 370),
	Vector2(52, 386), Vector2(20, 396)]

const PaperShader := preload("res://shaders/paper.gdshader")
## The map renders at 2x (main.gd RENDER_SCALE); the aged-paper texture is baked at that size.
const BAKE_SCALE := 2

## Road paths (smoothed): enemies walk them point by point.
var roads: Array[PackedVector2Array] = []
var river := PackedVector2Array()
var river_w := PackedFloat32Array() ## half-width of the river at each point
var bridges: Array[Dictionary] = [] ## {pos, road_dir, w (river half-width there)}
var _stains: Array = []
var _base: Texture2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for pts in ROAD_POINTS:
		roads.append(_smooth(pts, 9.0))
	river = _smooth(RIVER_POINTS, 6.0)
	for i in river.size():
		var k := float(i) / (river.size() - 1)
		river_w.append(lerpf(1.3, 7.5, pow(k, 0.75)) * (1.0 + 0.1 * sin(i * 0.9)))
	_find_bridges()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		_stains.append([Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y), rng.randf_range(6, 30), rng.randf_range(0.03, 0.08)])
	_bake()


## Catmull-Rom through the points, sampled about every `spacing` px.
static func _smooth(pts: Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		var steps := maxi(2, ceili(p1.distance_to(p2) / spacing))
		for k in steps:
			var t := float(k) / steps
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[-1])
	return out


## Unit direction of a polyline at point i (averaged over its neighbours).
static func tangent(line: PackedVector2Array, i: int) -> Vector2:
	return (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()


func _find_bridges() -> void:
	for r in roads:
		for i in r.size() - 1:
			for j in river.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(r[i], r[i + 1], river[j], river[j + 1])
				if hit != null:
					bridges.append({"pos": hit, "road_dir": (r[i + 1] - r[i]).normalized(), "w": river_w[j]})


## Render the aged parchment once into a texture (the shader never runs again).
func _bake() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE * BAKE_SCALE)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = SIZE * BAKE_SCALE
	var mat := ShaderMaterial.new()
	mat.shader = PaperShader
	mat.set_shader_parameter("seed", 3.0)
	rect.material = mat
	vp.add_child(rect)
	var decor := Decor.new()
	decor.paper = self
	decor.scale = Vector2.ONE * BAKE_SCALE
	vp.add_child(decor)
	var ink := Node2D.new()
	ink.scale = Vector2.ONE * BAKE_SCALE
	ink.draw.connect(func() -> void: _draw_ink(ink))
	vp.add_child(ink)
	add_child(vp)
	_base = vp.get_texture()


## Closest point on any road: {"point", "dir" (road direction), "dist"}.
func closest_road(p: Vector2) -> Dictionary:
	var best := {"point": Vector2.ZERO, "dir": Vector2.DOWN, "dist": INF}
	for r in roads:
		for i in r.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(p, r[i], r[i + 1])
			var d := c.distance_to(p)
			if d < best.dist:
				best = {"point": c, "dir": (r[i + 1] - r[i]).normalized(), "dist": d}
	return best


## On the river or the lake (nothing can be built there).
func on_water(p: Vector2) -> bool:
	var q := (p - Decor.LAKE) / Decor.LAKE_R
	return q.length() < 1.05 or river_clearance(p) < 3.0


## Distance from p to the river's nearer bank (negative inside the water).
func river_clearance(p: Vector2) -> float:
	var best := INF
	for i in river.size() - 1:
		var d := Geometry2D.get_closest_point_to_segment(p, river[i], river[i + 1]).distance_to(p)
		best = minf(best, d - maxf(river_w[i], river_w[i + 1]))
	return best


func near_road(p: Vector2, dist: float) -> bool:
	for r in roads:
		if _dist_to_line(p, r) < dist:
			return true
	return false


static func _dist_to_line(p: Vector2, line: PackedVector2Array) -> float:
	var best := INF
	for i in line.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1]).distance_to(p))
	return best


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.PARCHMENT)
	if _base:
		draw_texture_rect(_base, Rect2(Vector2.ZERO, SIZE), false)


## Stains, the frame, roads and bridges: baked on top of the decoration (see _bake).
func _draw_ink(ci: CanvasItem) -> void:
	for s in _stains:
		ci.draw_circle(s[0], s[1], Color(Palette.PARCHMENT_SHADOW, s[2]))
	# cartographer's frame
	ci.draw_rect(Rect2(Vector2(6, 6), SIZE - Vector2(12, 12)), Palette.SEPIA, false, 1.0)
	ci.draw_rect(Rect2(Vector2(9, 9), SIZE - Vector2(18, 18)), Color(Palette.SEPIA, 0.5), false, 1.0)
	_draw_roads(ci)
	for b in bridges:
		_bridge(ci, b.pos, b.road_dir, b.w)


# --- roads ------------------------------------------------------------------------------

## Half-width of road `r` at point i: a little uneven, like a track worn by feet and carts.
func _road_w(r: int, i: int) -> float:
	return ROAD_W * (1.0 + 0.08 * sin(i * 0.7 + r * 2.0) + 0.05 * sin(i * 2.3))


## Worn verge, packed-earth surface, cart ruts, then broken ink edges. The second road is drawn only
## down to MERGE (the first one carries on to the Keep); where it overlaps the first, its surface is
## clipped away and its edges skipped, so the two join into one clean Y.
func _draw_roads(ci: CanvasItem) -> void:
	_rng.seed = 23
	var ends: Array[int] = [roads[0].size(), roads[1].size()]
	for i in roads[1].size():
		if roads[1][i].distance_to(MERGE) < 0.5:
			ends[1] = i + 1
			break
	var drawn: Array[PackedVector2Array] = [roads[0], roads[1].slice(0, ends[1])]
	for pass_i in 2:
		var grow := 3.0 if pass_i == 0 else 0.0
		var col := Color(Palette.PARCHMENT_SHADOW, 0.22) if pass_i == 0 else Color(Palette.PARCHMENT_SHADOW, 0.5)
		for i in ends[0] - 1:
			ci.draw_colored_polygon(_road_quad(0, i, grow), col)
		for i in ends[1] - 1:
			var parts: Array[PackedVector2Array] = [_road_quad(1, i, grow)]
			for j in ends[0] - 1:
				if roads[0][j].distance_to(roads[1][i]) > 30.0:
					continue
				var cut: Array[PackedVector2Array] = []
				for part in parts:
					cut.append_array(Geometry2D.clip_polygons(part, _road_quad(0, j, grow)))
				parts = cut
			for part in parts:
				ci.draw_colored_polygon(part, col)
	for r in roads.size():
		var line := roads[r]
		var other := drawn[1 - r]
		for side: float in [-1.0, 1.0]:
			for i in ends[r] - 1:
				var a := line[i] + tangent(line, i).orthogonal() * side * _road_w(r, i)
				var b := line[i + 1] + tangent(line, i + 1).orthogonal() * side * _road_w(r, i + 1)
				if _dist_to_line((a + b) * 0.5, other) < ROAD_W - 0.5:
					continue
				# ruts: faint and broken
				var ra := line[i] + tangent(line, i).orthogonal() * side * 2.2
				var rb := line[i + 1] + tangent(line, i + 1).orthogonal() * side * 2.2
				if _rng.randf() < 0.7 and _dist_to_line(ra, other) > ROAD_W - 1.0:
					ci.draw_line(ra, rb, Color(Palette.SEPIA, 0.2), 0.7)
				# the inked edge, lifted now and then like a quill running dry
				if _rng.randf() < 0.9:
					var j := Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
					ci.draw_line(a + j, b + j, Color(Palette.SEPIA, 0.8), 0.9)
				if _rng.randf() < 0.18:
					var out := a + tangent(line, i).orthogonal() * side * _rng.randf_range(2.0, 4.0)
					ci.draw_circle(out, _rng.randf_range(0.4, 0.8), Color(Palette.SEPIA, 0.45))


func _road_quad(r: int, i: int, grow: float) -> PackedVector2Array:
	var line := roads[r]
	var na := tangent(line, i).orthogonal() * (_road_w(r, i) + grow)
	var nb := tangent(line, i + 1).orthogonal() * (_road_w(r, i + 1) + grow)
	return PackedVector2Array([line[i] + na, line[i + 1] + nb, line[i + 1] - nb, line[i] - na])


## A plank bridge carrying the road over the river (w = the river's half-width there).
func _bridge(ci: CanvasItem, c: Vector2, d: Vector2, w: float) -> void:
	var n := d.orthogonal()
	var half := w + 5.0
	var bw := ROAD_W + 0.5
	var deck := PackedVector2Array([c - d * half - n * bw, c + d * half - n * bw, c + d * half + n * bw, c - d * half + n * bw])
	var shadow := PackedVector2Array()
	for p in deck:
		shadow.append(p + Vector2(1, 1.5))
	ci.draw_colored_polygon(shadow, Color(Palette.INK, 0.2))
	ci.draw_colored_polygon(deck, Palette.PARCHMENT_MID)
	var k := -half + 2.0
	while k < half - 1.0:
		ci.draw_line(c + d * k - n * bw, c + d * k + n * bw, Color(Palette.SEPIA, 0.6), 0.6)
		k += 3.0
	for sn in [-1.0, 1.0]:
		ci.draw_line(c - d * (half + 1) + n * (bw + 0.5) * sn, c + d * (half + 1) + n * (bw + 0.5) * sn, Palette.SEPIA, 1.2)
		for sd in [-1.0, 1.0]:
			ci.draw_circle(c + d * (half + 1) * sd + n * (bw + 0.5) * sn, 1.2, Palette.INK)
