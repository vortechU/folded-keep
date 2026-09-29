class_name Paper
extends Node2D
## The parchment itself: aged paper + old-map decoration (baked once, see decor.gd), frame,
## roads and the bridges where they cross the river.

const SIZE := Vector2(360, 640)
const KEEP_POS := Vector2(180, 575)

var roads: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(70, -10), Vector2(80, 120), Vector2(140, 230), Vector2(125, 360), Vector2(165, 470), KEEP_POS]),
	PackedVector2Array([Vector2(295, -10), Vector2(280, 140), Vector2(220, 260), Vector2(240, 380), Vector2(195, 480), KEEP_POS]),
]

## The river, as control points (smoothed in _ready). Decorative: units cross it on the bridges.
const RIVER_POINTS := [Vector2(364, 290), Vector2(330, 300), Vector2(295, 318), Vector2(260, 326), Vector2(228, 318),
	Vector2(198, 330), Vector2(168, 348), Vector2(140, 345), Vector2(112, 352), Vector2(84, 370), Vector2(52, 386),
	Vector2(20, 396)]

const PaperShader := preload("res://shaders/paper.gdshader")
## The map renders at 2x (main.gd RENDER_SCALE); the aged-paper texture is baked at that size.
const BAKE_SCALE := 2

var river := PackedVector2Array()
var _stains: Array = []
var _bridges: Array[Dictionary] = [] ## {pos, road_dir}
var _base: Texture2D


func _ready() -> void:
	river = _smooth(RIVER_POINTS, 6)
	_find_bridges()
	_bake()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		_stains.append([Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y), rng.randf_range(6, 30), rng.randf_range(0.03, 0.08)])


## Catmull-Rom through the points, `steps` samples per segment.
static func _smooth(pts: Array, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for k in steps:
			var t := float(k) / steps
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[-1])
	return out


func _find_bridges() -> void:
	for r in roads:
		for i in r.size() - 1:
			for j in river.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(r[i], r[i + 1], river[j], river[j + 1])
				if hit != null:
					_bridges.append({"pos": hit, "road_dir": (r[i + 1] - r[i]).normalized()})


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
	return q.length() < 1.05 or near_river(p, 8.0)


func near_river(p: Vector2, dist: float) -> bool:
	for i in river.size() - 1:
		if Geometry2D.get_closest_point_to_segment(p, river[i], river[i + 1]).distance_to(p) < dist:
			return true
	return false


func near_road(p: Vector2, dist: float) -> bool:
	for r in roads:
		for i in r.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(p, r[i], r[i + 1])
			if c.distance_to(p) < dist:
				return true
	return false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.PARCHMENT)
	if _base:
		draw_texture_rect(_base, Rect2(Vector2.ZERO, SIZE), false)
	for s in _stains:
		draw_circle(s[0], s[1], Color(Palette.PARCHMENT_SHADOW, s[2]))
	# cartographer's frame
	draw_rect(Rect2(Vector2(6, 6), SIZE - Vector2(12, 12)), Palette.SEPIA, false, 1.0)
	draw_rect(Rect2(Vector2(9, 9), SIZE - Vector2(18, 18)), Color(Palette.SEPIA, 0.5), false, 1.0)
	for r in roads:
		for i in r.size() - 1:
			draw_line(r[i], r[i + 1], Color(Palette.PARCHMENT_SHADOW, 0.6), 9.0)
		for i in r.size() - 1:
			draw_dashed_line(r[i], r[i + 1], Palette.SEPIA, 1.0, 4.0)
	for b in _bridges:
		_bridge(b.pos, b.road_dir)


## A plank bridge carrying the road over the river.
func _bridge(c: Vector2, d: Vector2) -> void:
	var n := d.orthogonal()
	var deck := PackedVector2Array([c - d * 10 - n * 5, c + d * 10 - n * 5, c + d * 10 + n * 5, c - d * 10 + n * 5])
	draw_colored_polygon(PackedVector2Array([deck[0] + Vector2(1, 1.5), deck[1] + Vector2(1, 1.5), deck[2] + Vector2(1, 1.5),
		deck[3] + Vector2(1, 1.5)]), Color(Palette.INK, 0.2))
	draw_colored_polygon(deck, Palette.PARCHMENT_MID)
	for k in range(-8, 9, 3):
		draw_line(c + d * k - n * 5, c + d * k + n * 5, Color(Palette.SEPIA, 0.6), 0.6)
	for sn in [-1.0, 1.0]:
		draw_line(c - d * 11 + n * 5.5 * sn, c + d * 11 + n * 5.5 * sn, Palette.SEPIA, 1.2)
		for sd in [-1.0, 1.0]:
			draw_circle(c + d * 11 * sd + n * 5.5 * sn, 1.2, Palette.INK)
