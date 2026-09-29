extends Node2D
## Permanent ink splats left on the map by crushed units. The map remembers every battle.

const BLEED_TIME := 0.5 ## seconds for a fresh splat to spread into the paper

var _blobs: Array = [] ## [pos, radius, color, born]
var _patches: Array = [] ## stitched-up tears: [pos, radius]
var _time := 0.0
var _last_born := -10.0


func _ready() -> void:
	add_to_group("splats")


func _process(delta: float) -> void:
	_time += delta
	if _time - _last_born < BLEED_TIME + 0.05:
		queue_redraw()


func add_splat(pos: Vector2, color: Color) -> void:
	_last_born = _time
	_blobs.append([pos, 6.0, color, _time])
	for i in randi_range(5, 9):
		var off := Vector2.from_angle(randf() * TAU) * randf_range(3.0, 11.0)
		# droplets further out land a moment later
		_blobs.append([pos + off, randf_range(1.0, 3.5), color, _time + off.length() * 0.01])
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
	# a soft halo where the ink bled into the paper fibers, then the blot itself
	for b in _blobs:
		var r: float = b[1] * _grown(b[3])
		if r > 0.1:
			draw_circle(b[0], r * 1.35, Color(b[2], 0.18))
	for b in _blobs:
		var r: float = b[1] * _grown(b[3])
		if r > 0.1:
			draw_circle(b[0], r, Color(b[2], 0.85))


func _grown(born: float) -> float:
	var k := clampf((_time - born) / BLEED_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)
