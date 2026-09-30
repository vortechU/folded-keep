extends Node2D
## Blood/ink marks spread, linger, then fade; storage stays bounded during busy battles.

const BLEED_TIME := 0.5 ## seconds for a fresh splat to spread into the paper
const FADE_START := 12.0 ## seconds before ink starts fading
const FADE_TIME := 4.0
const MAX_BLOBS := 512 ## includes the central blot and its small droplets

var _blobs: Array[Array] = [] ## [pos, radius, color, born]
var _patches: Array[Array] = [] ## stitched-up tears: [pos, radius]
var _time := 0.0


func _ready() -> void:
	add_to_group("splats")
	set_process(not _blobs.is_empty())


func _process(delta: float) -> void:
	_time += delta
	var changed := false
	for i in range(_blobs.size() - 1, -1, -1):
		var age: float = _time - _blobs[i][3]
		if age >= FADE_START + FADE_TIME:
			_blobs.remove_at(i)
			changed = true
		elif age < BLEED_TIME + 0.05 or age >= FADE_START:
			changed = true
	if changed:
		queue_redraw()
	if _blobs.is_empty():
		set_process(false)


func add_splat(pos: Vector2, color: Color) -> void:
	_blobs.append([pos, 6.0, color, _time])
	for i in randi_range(5, 9):
		var off := Vector2.from_angle(randf() * TAU) * randf_range(3.0, 11.0)
		# droplets further out land a moment later
		_blobs.append([pos + off, randf_range(1.0, 3.5), color, _time + off.length() * 0.01])
	while _blobs.size() > MAX_BLOBS:
		_blobs.pop_front()
	set_process(true)
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
			draw_circle(b[0], r * 1.35, Color(b[2], 0.18 * _opacity(b[3])))
	for b in _blobs:
		var r: float = b[1] * _grown(b[3])
		if r > 0.1:
			draw_circle(b[0], r, Color(b[2], 0.85 * _opacity(b[3])))


func _opacity(born: float) -> float:
	return 1.0 - clampf((_time - born - FADE_START) / FADE_TIME, 0.0, 1.0)


func _grown(born: float) -> float:
	var k := clampf((_time - born) / BLEED_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)
