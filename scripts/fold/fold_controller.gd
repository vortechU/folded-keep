class_name FoldController
extends Node2D
## Owns the fold: edge-grab input, the shader uniforms, slam resolution, creases.
## Also draws the aiming overlay (who gets crushed / slapped / flipped).
## Owner: Claude (see DESIGN.md).

signal fold_started
signal slammed(line_point: Vector2, normal: Vector2, outcomes: Array)
signal unfolded

enum State { IDLE, DRAGGING, BUSY }
enum Outcome { CRUSH, SLAP, FLIP }

const EDGE_MARGIN := 28.0
const MIN_DRAG := 24.0
const DRAG_TIME_SCALE := 0.45
const SLAM_TIME := 0.07
const UNFOLD_DELAY := 0.35
const UNFOLD_TIME := 0.22
const MAX_CREASES := 16

var map_size := Vector2(360, 640)
var enabled := true
var state := State.IDLE
var grab := Vector2.ZERO
var pointer := Vector2.ZERO
var lift := 0.0
var creases: Array[Vector4] = []

var _mat: ShaderMaterial
var _preview: Array = []
var _pulse := 0.0


func setup(display: Sprite2D) -> void:
	_mat = display.material
	_mat.set_shader_parameter("map_size", map_size)
	_apply()


func _process(delta: float) -> void:
	if state == State.DRAGGING:
		_pulse += delta / Engine.time_scale
		_update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_fold(event.position)
		else:
			release()
	elif event is InputEventMouseMotion and state == State.DRAGGING:
		drag_to(event.position)


## Returns true if the press was close enough to an edge to start a fold.
func begin_fold(pos: Vector2) -> bool:
	if state != State.IDLE or not enabled:
		return false
	var g := _snap_to_edge(pos)
	if not g.is_finite():
		return false
	grab = g
	pointer = g
	lift = 1.0
	state = State.DRAGGING
	Engine.time_scale = DRAG_TIME_SCALE
	fold_started.emit()
	drag_to(pos)
	return true


func drag_to(pos: Vector2) -> void:
	if state != State.DRAGGING:
		return
	pointer = pos.clamp(Vector2.ZERO, map_size)
	_update_preview()
	_apply()


func release() -> void:
	if state != State.DRAGGING:
		return
	Engine.time_scale = 1.0
	_preview.clear()
	queue_redraw()
	if grab.distance_to(pointer) < MIN_DRAG:
		_unfold(0.1)
		return
	state = State.BUSY
	var tw := create_tween()
	tw.tween_method(_set_lift, lift, 0.0, SLAM_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_impact)
	tw.tween_interval(UNFOLD_DELAY)
	tw.tween_callback(_unfold.bind(UNFOLD_TIME))


## Every unit affected by a slam along this fold, as [{unit, outcome, pos, target}].
func compute_outcomes(m: Vector2, n: Vector2) -> Array:
	var out: Array = []
	for u in get_tree().get_nodes_in_group("unit"):
		if not u.is_alive():
			continue
		var pos: Vector2 = u.position
		var q := FoldMath.mirror(pos, m, n)
		if not _in_map(q):
			continue
		var entry := {"unit": u, "pos": pos, "target": q}
		if FoldMath.side(pos, m, n) > 0.0:
			entry.outcome = Outcome.FLIP
		elif _heavy_building_at(q) != null:
			entry.outcome = Outcome.CRUSH
		else:
			entry.outcome = Outcome.SLAP
		out.append(entry)
	return out


func _impact() -> void:
	var m := FoldMath.line_point(grab, pointer)
	var n := FoldMath.normal(grab, pointer)
	var outcomes := compute_outcomes(m, n)
	for e in outcomes:
		match e.outcome:
			Outcome.CRUSH:
				e.unit.on_crushed()
			Outcome.SLAP:
				e.unit.on_slapped(-n)
			Outcome.FLIP:
				e.unit.on_flipped(e.target)
	_add_crease(m, n)
	slammed.emit(m, n, outcomes)


func _unfold(duration: float) -> void:
	state = State.BUSY
	lift = 0.25
	var tw := create_tween()
	tw.tween_method(_set_pointer, pointer, grab, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(_finish_unfold)


func _finish_unfold() -> void:
	state = State.IDLE
	lift = 0.0
	pointer = grab
	_apply()
	unfolded.emit()


func _set_lift(v: float) -> void:
	lift = v
	_apply()


func _set_pointer(v: Vector2) -> void:
	pointer = v
	_apply()


func _apply() -> void:
	if _mat == null:
		return
	var active := state != State.IDLE and grab.distance_squared_to(pointer) > 1.0
	_mat.set_shader_parameter("fold_active", active)
	if active:
		_mat.set_shader_parameter("fold_point", FoldMath.line_point(grab, pointer))
		_mat.set_shader_parameter("fold_normal", FoldMath.normal(grab, pointer))
		_mat.set_shader_parameter("lift", lift)


func _add_crease(m: Vector2, n: Vector2) -> void:
	creases.append(Vector4(m.x, m.y, n.x, n.y))
	if creases.size() > MAX_CREASES:
		creases.pop_front()
	var arr := PackedVector4Array()
	arr.resize(MAX_CREASES)
	for i in creases.size():
		arr[i] = creases[i]
	_mat.set_shader_parameter("creases", arr)
	_mat.set_shader_parameter("crease_count", creases.size())


func _update_preview() -> void:
	if grab.distance_to(pointer) < MIN_DRAG:
		_preview.clear()
	else:
		_preview = compute_outcomes(FoldMath.line_point(grab, pointer), FoldMath.normal(grab, pointer))
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_pulse * 12.0)
	for e in _preview:
		var p: Vector2 = e.pos.round()
		match e.outcome:
			Outcome.CRUSH:
				var c := Palette.RED.lerp(Color.WHITE, pulse * 0.3)
				draw_arc(p, 8.0 + pulse, 0.0, TAU, 16, c, 1.5)
				draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), c, 1.5)
				draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), c, 1.5)
			Outcome.SLAP:
				draw_arc(p, 7.0, 0.0, TAU, 12, Palette.GOLD, 1.0)
			Outcome.FLIP:
				var t: Vector2 = e.target.round()
				draw_dashed_line(p, t, Palette.BLUE_LIGHT, 1.0, 3.0)
				draw_arc(t, 4.0, 0.0, TAU, 10, Palette.BLUE_LIGHT, 1.0)


func _snap_to_edge(pos: Vector2) -> Vector2:
	var g := pos.clamp(Vector2.ZERO, map_size)
	var near := false
	if g.x < EDGE_MARGIN:
		g.x = 0.0
		near = true
	elif g.x > map_size.x - EDGE_MARGIN:
		g.x = map_size.x
		near = true
	if g.y < EDGE_MARGIN:
		g.y = 0.0
		near = true
	elif g.y > map_size.y - EDGE_MARGIN:
		g.y = map_size.y
		near = true
	return g if near else Vector2.INF


func _in_map(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < map_size.x and p.y < map_size.y


func _heavy_building_at(p: Vector2) -> Node:
	for b in get_tree().get_nodes_in_group("building"):
		if b.heavy and b.contains_point(p):
			return b
	return null
