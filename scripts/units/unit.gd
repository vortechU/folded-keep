class_name Unit
extends Node2D
## A little ink figure printed on the map. Follows a road toward the Keep.
## Placeholder art is drawn in _draw() until the real sprites land.

signal died(unit: Unit)
signal reached_keep(unit: Unit)

enum Team { ENEMY, ALLY }

@export var team := Team.ENEMY
@export var speed := 16.0
@export var slaps_to_kill := 2
@export var slap_immune := false

var path: PackedVector2Array = []
var path_index := 0
var stun := 0.0

var _alive := true
var _t := 0.0


func _ready() -> void:
	add_to_group("unit")
	add_to_group("enemy" if team == Team.ENEMY else "ally")
	_t = randf() * 10.0


func is_alive() -> bool:
	return _alive


func _process(delta: float) -> void:
	if not _alive:
		return
	_t += delta
	queue_redraw()
	if stun > 0.0:
		stun -= delta
		return
	if path_index >= path.size():
		return
	var target := path[path_index]
	var to := target - position
	if to.length() < 3.0:
		path_index += 1
		if path_index >= path.size() and team == Team.ENEMY:
			_alive = false
			reached_keep.emit(self)
			queue_free()
		return
	position += to.normalized() * speed * delta


func on_crushed() -> void:
	if not _alive:
		return
	_alive = false
	var splats := get_tree().get_first_node_in_group("splats")
	if splats:
		splats.add_splat(position, Palette.RED if team == Team.ENEMY else Palette.BLUE)
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.9, 0.12), 0.06)
	tw.tween_callback(queue_free)


func on_slapped(dir: Vector2) -> void:
	if not _alive or slap_immune:
		return
	slaps_to_kill -= 1
	if slaps_to_kill <= 0:
		on_crushed()
		return
	stun = 1.5
	var tw := create_tween()
	tw.tween_property(self, "position", (position + dir * 14.0).clamp(Vector2(4, 4), Vector2(356, 636)), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	scale = Vector2(1.4, 0.6)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func on_flipped(to: Vector2) -> void:
	if not _alive:
		return
	position = to
	stun = 1.0
	# Resume at the closest waypoint so a flipped unit doesn't walk back up the road.
	var best := path_index
	var best_d := INF
	for i in range(path.size()):
		var d := to.distance_squared_to(path[i])
		if d < best_d:
			best_d = d
			best = i
	path_index = best
	scale = Vector2(1.5, 0.5)
	rotation = PI
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", 0.0, 0.3)


func _draw() -> void:
	var fill := Palette.RED if team == Team.ENEMY else Palette.BLUE
	var walking := stun <= 0.0
	var bob := absf(sin(_t * 9.0)) * 1.5 if walking else 0.0
	draw_circle(Vector2(0, 3), 4.0, Color(0, 0, 0, 0.15))
	# body
	draw_rect(Rect2(-3.5, -4.0 - bob, 7, 7), Palette.INK)
	draw_rect(Rect2(-2.5, -3.0 - bob, 5, 5), fill)
	# head
	draw_circle(Vector2(0, -7.0 - bob), 3.0, Palette.INK)
	draw_circle(Vector2(0, -7.0 - bob), 2.0, Palette.PARCHMENT)
	# weapon
	if team == Team.ENEMY:
		draw_line(Vector2(5, -12 - bob), Vector2(5, 3 - bob), Palette.INK, 1.0)
		draw_rect(Rect2(4, -14 - bob, 3, 2), Palette.INK)
	else:
		draw_rect(Rect2(-7, -4 - bob, 3, 5), Palette.INK)
		draw_line(Vector2(5, -9 - bob), Vector2(5, 1 - bob), Palette.PARCHMENT_SHADOW, 1.0)
	if not walking:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 6.0, -12.0 + sin(a) * 2.0), 1.0, Palette.GOLD)
