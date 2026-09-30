class_name BuildController
extends Node2D
## Placement mode: once armed with a building kind, press/drag on the map to position a ghost
## (offset above the finger), release to place. Towers go on open paper, walls snap across roads.

signal place_requested(kind: String, pos: Vector2, rot: float)
signal disarmed

const FINGER_OFFSET := Vector2(0, -26)
const SIZES := {"tower": Vector2(22, 22), "wall": Vector2(34, 9), "barracks": Vector2(26, 20),
	"archer_tower": Vector2(22, 22)}
const PLAY_RECT := Rect2(14, 34, 332, 520)

var armed := ""
var paper: Paper
var _ghost := Vector2.ZERO
var _rot := 0.0
var _touching := false
var _valid := false


func arm(kind: String) -> void:
	armed = kind
	_touching = false
	queue_redraw()


func disarm() -> void:
	armed = ""
	_touching = false
	queue_redraw()
	disarmed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if armed == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touching = true
			_move(get_parent().to_local(event.position))
		elif _touching:
			_touching = false
			if _valid:
				place_requested.emit(armed, _ghost, _rot)
			else:
				Audio.play_sfx("ui_cancel")
			queue_redraw()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _touching:
		_move(get_parent().to_local(event.position))
		get_viewport().set_input_as_handled()


func _move(pointer: Vector2) -> void:
	_ghost = (pointer + FINGER_OFFSET).round()
	_rot = 0.0
	if armed == "wall":
		var road := paper.closest_road(_ghost)
		if road.dist < 14.0:
			_ghost = road.point.round()
			_rot = road.dir.angle() + PI * 0.5
	_valid = can_place(armed, _ghost, _rot)
	queue_redraw()


func can_place(kind: String, pos: Vector2, rot: float) -> bool:
	if not PLAY_RECT.has_point(pos):
		return false
	var road := paper.closest_road(pos)
	if kind == "wall":
		if road.dist > 1.0:
			return false
	elif road.dist < 16.0 or paper.on_water(pos):
		return false
	var probe := Building.new()
	probe.size = SIZES[kind]
	probe.position = pos
	probe.rotation = rot
	var r := probe.size.length() * 0.5
	probe.free()
	for b in get_tree().get_nodes_in_group("building"):
		if b.position.distance_to(pos) < r + b.size.length() * 0.5 - 2.0:
			return false
	return true


func _draw() -> void:
	if armed == "" or not _touching:
		return
	var c := Palette.BLUE_LIGHT if _valid else Palette.RED
	draw_set_transform(_ghost, _rot)
	var s: Vector2 = SIZES[armed]
	if armed == "tower" or armed == "archer_tower":
		draw_arc(Vector2.ZERO, s.x * 0.5, 0.0, TAU, 20, c, 1.5)
		if armed == "archer_tower":
			draw_line(Vector2(-5, -5), Vector2(5, 5), c, 1.5)
			draw_line(Vector2(-5, 5), Vector2(5, -5), c, 1.5)
	else:
		draw_rect(Rect2(-s * 0.5, s), c, false, 1.5)
	draw_set_transform(Vector2.ZERO)
	draw_dashed_line(_ghost, _ghost - FINGER_OFFSET, Color(c, 0.6), 1.0, 2.0)
