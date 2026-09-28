extends Node2D
## Permanent ink splats left on the map by crushed units. The map remembers every battle.

var _blobs: Array = []
var _patches: Array = [] ## stitched-up tears: [pos, radius]


func _ready() -> void:
	add_to_group("splats")


func add_splat(pos: Vector2, color: Color) -> void:
	_blobs.append([pos, 6.0, color])
	for i in randi_range(5, 9):
		var off := Vector2.from_angle(randf() * TAU) * randf_range(3.0, 11.0)
		_blobs.append([pos + off, randf_range(1.0, 3.5), color])
	queue_redraw()


## A mended tear: a parchment patch with ink stitches.
func add_patch(pos: Vector2, radius: float) -> void:
	_patches.append([pos, radius])
	queue_redraw()


func _draw() -> void:
	for pt in _patches:
		var p: Vector2 = pt[0]
		var r: float = pt[1] * 1.15
		var rect := Rect2(p - Vector2(r, r * 0.85), Vector2(r * 2.0, r * 1.7))
		draw_rect(Rect2(rect.position + Vector2(1.5, 2), rect.size), Color(Palette.INK, 0.2))
		draw_rect(rect, Palette.PARCHMENT_MID)
		draw_rect(rect, Palette.SEPIA, false, 1.0)
		var x := rect.position.x + 3.0
		while x < rect.end.x - 2.0:
			draw_line(Vector2(x, rect.position.y - 2), Vector2(x + 2, rect.position.y + 2), Palette.INK, 1.0)
			draw_line(Vector2(x, rect.end.y - 2), Vector2(x + 2, rect.end.y + 2), Palette.INK, 1.0)
			x += 5.0
	for b in _blobs:
		draw_circle(b[0], b[1], Color(b[2], 0.85))
