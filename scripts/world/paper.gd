class_name Paper
extends Node2D
## The parchment itself: base texture, frame, roads and terrain decals.
## Procedural placeholder until the parchment tile and terrain sprites land.

const SIZE := Vector2(360, 640)
const KEEP_POS := Vector2(180, 575)

var roads: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(70, -10), Vector2(80, 120), Vector2(140, 230), Vector2(125, 360), Vector2(165, 470), KEEP_POS]),
	PackedVector2Array([Vector2(295, -10), Vector2(280, 140), Vector2(220, 260), Vector2(240, 380), Vector2(195, 480), KEEP_POS]),
]

var _stains: Array = []
var _trees: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		_stains.append([Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y), rng.randf_range(6, 30), rng.randf_range(0.04, 0.12)])
	for i in 40:
		var p := Vector2(rng.randf_range(14, SIZE.x - 14), rng.randf_range(14, SIZE.y - 90))
		if _near_road(p, 22.0):
			continue
		_trees.append(p.round())


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


func _near_road(p: Vector2, dist: float) -> bool:
	for r in roads:
		for i in r.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(p, r[i], r[i + 1])
			if c.distance_to(p) < dist:
				return true
	return false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Palette.PARCHMENT)
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
	for t in _trees:
		draw_line(t + Vector2(0, 1), t + Vector2(0, 5), Palette.SEPIA, 1.0)
		draw_circle(t, 4.0, Palette.SEPIA)
		draw_circle(t + Vector2(-1, -1), 2.5, Palette.PARCHMENT_MID)
	_compass(Vector2(320, 40))


func _compass(c: Vector2) -> void:
	for i in 4:
		var a := i * PI * 0.5
		var tip := c + Vector2.from_angle(a - PI * 0.5) * 16.0
		var side := Vector2.from_angle(a) * 4.0
		draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]), Palette.SEPIA if i % 2 == 0 else Palette.PARCHMENT_SHADOW)
	draw_arc(c, 9.0, 0.0, TAU, 20, Palette.SEPIA, 1.0)
