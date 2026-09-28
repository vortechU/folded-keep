extends Node2D
## Permanent ink splats left on the map by crushed units. The map remembers every battle.

var _blobs: Array = []


func _ready() -> void:
	add_to_group("splats")


func add_splat(pos: Vector2, color: Color) -> void:
	_blobs.append([pos, 6.0, color])
	for i in randi_range(5, 9):
		var off := Vector2.from_angle(randf() * TAU) * randf_range(3.0, 11.0)
		_blobs.append([pos + off, randf_range(1.0, 3.5), color])
	queue_redraw()


func _draw() -> void:
	for b in _blobs:
		draw_circle(b[0], b[1], Color(b[2], 0.85))
