class_name Unit
extends Node2D
## A little ink figure printed on the map. Follows a road toward the Keep.
## Placeholder art is drawn in _draw() until the real sprites land.

signal died(unit: Unit)
signal reached_keep(unit: Unit)

enum Team { ENEMY, ALLY }

const KINDS := {
	"grunt": {"speed": 16.0, "slaps": 2, "slap_immune": false, "size": 1.0},
	"runner": {"speed": 30.0, "slaps": 1, "slap_immune": false, "size": 0.85},
	"brute": {"speed": 9.0, "slaps": 99, "slap_immune": true, "size": 1.5},
	"knight": {"speed": 18.0, "slaps": 2, "slap_immune": false, "size": 1.0},
	"ram": {"speed": 7.0, "slaps": 99, "slap_immune": true, "size": 2.2, "crushes": 3},
}
const ATTACK_INTERVAL := 1.0

@export var team := Team.ENEMY
@export var kind := "grunt"
@export var speed := 16.0
@export var slaps_to_kill := 2
@export var slap_immune := false
@export var crushes_to_kill := 1

var path: PackedVector2Array = []
var path_index := 0
var stun := 0.0

var _alive := true
var _t := 0.0
var _size := 1.0
var _attack_cd := 0.0


## Apply the stats of a kind from KINDS. Call before adding to the tree.
func setup(unit_kind: String) -> void:
	kind = unit_kind
	var k: Dictionary = KINDS[kind]
	speed = k.speed * randf_range(0.9, 1.1)
	slaps_to_kill = k.slaps
	slap_immune = k.slap_immune
	crushes_to_kill = k.get("crushes", 1)
	_size = k.size


## How far from its center a unit can be hit by a slammed building.
func hit_radius() -> float:
	return 4.0 * _size


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
	var wall := _blocking_wall(to.normalized())
	if wall:
		_attack_cd -= delta
		if _attack_cd <= 0.0:
			_attack_cd = ATTACK_INTERVAL
			wall.damage({"brute": 3, "ram": 6}.get(kind, 1))
		return
	if to.length() < 3.0:
		path_index += 1
		if path_index >= path.size() and team == Team.ENEMY:
			_alive = false
			reached_keep.emit(self)
			queue_free()
		return
	position += to.normalized() * speed * delta


func _blocking_wall(dir: Vector2) -> Node:
	if team != Team.ENEMY:
		return null
	var ahead := position + dir * 7.0 * _size
	for b in get_tree().get_nodes_in_group("building"):
		if b.kind == "wall" and b.contains_point(ahead):
			return b
	return null


func on_crushed() -> void:
	if not _alive:
		return
	crushes_to_kill -= 1
	if crushes_to_kill > 0:
		_hurt()
		return
	_alive = false
	var splats := get_tree().get_first_node_in_group("splats")
	if splats:
		splats.add_splat(position, Palette.RED if team == Team.ENEMY else Palette.BLUE)
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.9, 0.12), 0.06)
	tw.tween_callback(queue_free)


## Survived a crush (boss): splat, stun, squash.
func _hurt() -> void:
	var splats := get_tree().get_first_node_in_group("splats")
	if splats:
		splats.add_splat(position, Palette.RED)
	stun = 1.5
	scale = Vector2(1.6, 0.4)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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
	if kind == "ram":
		_draw_ram()
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _size)
	var fill := Palette.RED if team == Team.ENEMY else Palette.BLUE
	if kind == "runner":
		fill = Palette.RED_LIGHT
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


func _draw_ram() -> void:
	var walking := stun <= 0.0
	var bob := absf(sin(_t * 5.0)) * 1.0 if walking else 0.0
	draw_rect(Rect2(-11, -2, 22, 14), Color(0, 0, 0, 0.15))
	# wheels
	for x in [-9.0, 9.0]:
		for y in [-6.0, 6.0]:
			draw_circle(Vector2(x, y), 3.0, Palette.INK)
	# body + roof
	draw_rect(Rect2(-9, -12 - bob, 18, 20), Palette.INK)
	draw_rect(Rect2(-7.5, -10.5 - bob, 15, 17), Palette.RED)
	for y in [-7.0, -3.0, 1.0]:
		draw_line(Vector2(-7, y - bob), Vector2(7, y - bob), Palette.INK, 1.0)
	# ram log pointing down the road
	draw_rect(Rect2(-2.5, 6 - bob, 5, 10), Palette.SEPIA)
	draw_rect(Rect2(-3.5, 14 - bob, 7, 4), Palette.INK)
	# crush pips
	for i in crushes_to_kill:
		draw_circle(Vector2(-5 + i * 5, -17), 2.0, Palette.INK)
		draw_circle(Vector2(-5 + i * 5, -17), 1.2, Palette.RED_LIGHT)
	if not walking:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 10.0, -20.0 + sin(a) * 3.0), 1.3, Palette.GOLD)
