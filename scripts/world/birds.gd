class_name Birds
extends Node2D
## Now and then a flock of doodled birds crosses the map in a V, their shadows gliding over the
## paper far below. Purely cosmetic; drawn above the units (and cloud shadows). Owner: Claude.

const InkShader := preload("res://shaders/ink.gdshader")
const EVERY := Vector2(9.0, 16.0) ## seconds between flocks (min, max)
const SPEED := 34.0
const SHADOW := Vector2(14, 26) ## how far below (on the paper) the shadows fall

var _flocks: Array[Dictionary] = []
var _next := 3.0


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = InkShader
	mat.set_shader_parameter("boil", 0.7)
	material = mat


func _process(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(EVERY.x, EVERY.y)
		_spawn()
	for i in range(_flocks.size() - 1, -1, -1):
		var f: Dictionary = _flocks[i]
		f.t += delta
		f.pos += f.dir * SPEED * delta
		if not Rect2(-120, -120, 600, 880).has_point(f.pos):
			_flocks.remove_at(i)
	queue_redraw()


## Fly in from the upwind side (mostly) and cross the map.
func _spawn() -> void:
	var dir := Wind.DIR.rotated(randf_range(-0.5, 0.5))
	if randf() < 0.3:
		dir = -dir
	# start outside the map, on the line through a random point of it
	var through := Vector2(randf_range(60, 300), randf_range(120, 520))
	var birds: Array[Vector2] = [Vector2.ZERO]
	for i in range(1, randi_range(3, 7)):
		var side := 1.0 if i % 2 == 1 else -1.0
		var rank := ceilf(i / 2.0)
		birds.append(Vector2(-rank * 9.0, side * rank * 7.0)) # in flock space: x = along flight
	_flocks.append({"pos": through - dir * 420.0, "dir": dir, "t": randf() * 5.0, "birds": birds})


func _draw() -> void:
	for f in _flocks:
		var d: Vector2 = f.dir
		for i in f.birds.size():
			var o: Vector2 = f.birds[i]
			var p: Vector2 = f.pos + d * o.x + d.orthogonal() * o.y
			var flap := sin(f.t * 9.0 + i * 1.3)
			_bird(p + SHADOW, flap, Color(Palette.INK, 0.12), 1.2)
			_bird(p, flap, Color(Palette.INK, 0.8), 0.8)


## The classic doodled bird: two little arcs meeting at the body.
func _bird(p: Vector2, flap: float, col: Color, w: float) -> void:
	var tip := Vector2(4.5, -1.8 - flap * 2.2)
	var mid := Vector2(2.2, -2.2 - flap * 0.8)
	for sx in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([p + Vector2(tip.x * sx, tip.y), p + Vector2(mid.x * sx, mid.y), p]), col, w)
