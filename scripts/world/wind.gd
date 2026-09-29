class_name Wind
extends Node2D
## Old-map wind curls printed on the parchment: faint quill strokes that follow a gentle flow
## field, end in a curl, draw themselves on, drift and blow away. Purely decorative.
## Lives in the map World (above the paper, below splats), so it folds with the map.
## Owner: Claude.

const InkShader := preload("res://shaders/ink.gdshader")
## Prevailing wind (clouds.gdshader drifts the same way).
const DIR := Vector2(0.94, 0.34)
const SPEED := 7.0 ## how fast strokes drift, px/s
const MAX_STROKES := 7
const SPAWN_EVERY := 1.1
const LIFE := 7.0
const DRAW_ON := 1.6
const BLOW_AWAY := 2.0
const STEP := 3.0
const KEEP_AREA := Rect2(120, 500, 120, 140)
const COLOR := Color("#6E4B2A")

var _strokes: Array[Dictionary] = []
var _noise := FastNoiseLite.new()
var _spawn := 0.0
var _time := 0.0


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.006
	var mat := ShaderMaterial.new()
	mat.shader = InkShader
	mat.set_shader_parameter("boil", 0.8)
	material = mat
	# start with a few already on the page
	for i in 4:
		_add_stroke(randf_range(DRAW_ON, LIFE - BLOW_AWAY))


func _process(delta: float) -> void:
	_time += delta
	_spawn -= delta
	if _spawn <= 0.0 and _strokes.size() < MAX_STROKES:
		_spawn = SPAWN_EVERY * randf_range(0.7, 1.3)
		_add_stroke(0.0)
	for i in range(_strokes.size() - 1, -1, -1):
		_strokes[i].t += delta
		if _strokes[i].t >= LIFE:
			_strokes.remove_at(i)
	queue_redraw()


## The flow field: the prevailing wind, bent by slowly shifting noise.
func _heading(p: Vector2) -> float:
	return DIR.angle() + _noise.get_noise_3d(p.x, p.y, _time * 8.0) * 1.4


func _add_stroke(age: float) -> void:
	var start := Vector2.ZERO
	for i in 10:
		start = Vector2(randf_range(10, 300), randf_range(30, 610))
		if not KEEP_AREA.has_point(start):
			break
	var main := _path(start, randf_range(60, 120), true)
	var side := DIR.orthogonal() * (5.0 if randf() < 0.5 else -5.0)
	var twin := _path(start + side + DIR * 10.0, randf_range(25, 55), false)
	_strokes.append({"lines": [main, twin], "t": age, "drift": DIR * SPEED * randf_range(0.7, 1.3)})


## A quill line integrated along the flow field, optionally ending in an inward curl.
func _path(start: Vector2, length: float, curl: bool) -> PackedVector2Array:
	var pts := PackedVector2Array([start])
	var p := start
	for i in int(length / STEP):
		p += Vector2.from_angle(_heading(p)) * STEP
		pts.append(p)
	if not curl:
		return pts
	var dir := Vector2.from_angle(_heading(p))
	var r := randf_range(6.0, 10.0)
	var center := p + dir.rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0)) * r
	var v0 := p - center
	var turn := 1.0 if v0.normalized().rotated(PI * 0.5).dot(dir) > 0.0 else -1.0
	var steps := 26
	for k in range(1, steps + 1):
		var a := v0.angle() + turn * k * 0.3
		pts.append(center + Vector2.from_angle(a) * r * (1.0 - 0.72 * k / steps))
	return pts


func _draw() -> void:
	for s in _strokes:
		var t: float = s.t
		# drawn on from the tail, then erased from the tail as it blows away
		var head := 1.0 - pow(1.0 - clampf(t / DRAW_ON, 0.0, 1.0), 2.0)
		var tail := clampf((t - (LIFE - BLOW_AWAY)) / BLOW_AWAY, 0.0, 1.0)
		var off: Vector2 = s.drift * t
		var alpha := 0.42 * clampf((1.0 - tail) * 1.5, 0.0, 1.0)
		for line: PackedVector2Array in s.lines:
			var n := line.size() - 1
			var from := int(tail * n)
			var to := int(head * n)
			for i in range(from, to):
				var u := float(i) / n
				var w := 0.35 + 1.1 * pow(sin(PI * clampf(u * 1.15, 0.0, 1.0)), 0.7)
				draw_line(line[i] + off, line[i + 1] + off, Color(COLOR, alpha), w)
