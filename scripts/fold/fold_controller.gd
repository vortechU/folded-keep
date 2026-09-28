class_name FoldController
extends Node2D
## Owns the fold: edge-grab input, the shader uniforms, slam resolution, creases.
## Also draws the aiming overlay (who gets crushed / slapped / flipped).
## Owner: Claude (see DESIGN.md).

signal fold_started
signal slammed(line_point: Vector2, normal: Vector2, outcomes: Array)
signal unfolded
signal torn(pos: Vector2)

enum State { IDLE, DRAGGING, BUSY }
enum Outcome { CRUSH, SLAP, FLIP, FLING }

const EDGE_MARGIN := 28.0
const MIN_DRAG := 24.0
const DRAG_TIME_SCALE := 0.45
const SLAM_TIME := 0.07
const UNFOLD_DELAY := 0.35
const UNFOLD_TIME := 0.22
const MAX_CREASES := 16
## Wear & tear: where a new crease crosses two old ones within TEAR_REACH, the map rips open.
const TEAR_REACH := 12.0
const TEAR_RADIUS := 13.0
const TEAR_CAPACITY := 3 ## units a hole swallows before it gets stitched shut
const MAX_HOLES := 8
const KEEP_ZONE := Rect2(130, 520, 100, 120) ## the Keep's paper never tears

var map_size := Vector2(360, 640)
var enabled := true
var state := State.IDLE
var grab := Vector2.ZERO
var pointer := Vector2.ZERO
var lift := 0.0
var creases: Array[Vector4] = []
## Open tears: [{pos, r, left}]
var holes: Array[Dictionary] = []

var _mat: ShaderMaterial
var _preview: Array = []
var _preview_tears: Array[Vector2] = []
var _pulse := 0.0
## Scripted tests drive the fold directly; ignore the real mouse so it can't interfere.
var _scripted := Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--autotest"))


func _ready() -> void:
	# The juice layer sits above the folded map, so dust flies over the flap too.
	get_parent().add_child.call_deferred(Fx.new())


func setup(display: Sprite2D) -> void:
	_mat = display.material
	_mat.set_shader_parameter("map_size", map_size)
	_apply()


func _process(delta: float) -> void:
	if state == State.DRAGGING:
		_pulse += delta / Engine.time_scale
		_update_preview()
	if not holes.is_empty():
		_swallow()


func _unhandled_input(event: InputEvent) -> void:
	if _scripted:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_fold(_local(event.position))
		else:
			release()
	elif event is InputEventMouseMotion and state == State.DRAGGING:
		drag_to(_local(event.position))


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
	Engine.time_scale = DRAG_TIME_SCALE * (0.6 if Decrees.has("slow_time") else 1.0)
	Audio.play_sfx("paper_grab")
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
	_preview_tears.clear()
	queue_redraw()
	if grab.distance_to(pointer) < MIN_DRAG:
		_unfold(0.1)
		return
	state = State.BUSY
	Audio.play_sfx("paper_fold")
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
		var on_flap := FoldMath.side(pos, m, n) > 0.0
		var entry := {"unit": u, "pos": pos, "target": q}
		if not _in_map(q):
			# On a flap so big its far end hangs off the map: flung off the table
			# (bosses are too heavy to fling).
			if on_flap and not u.is_boss():
				entry.outcome = Outcome.FLING
				out.append(entry)
			continue
		if on_flap:
			entry.outcome = Outcome.FLIP
		elif u.is_flying():
			continue # the flap passes under it
		elif _heavy_building_at(q, u.hit_radius()) != null:
			entry.outcome = Outcome.CRUSH
		elif Decrees.has("paper_cut") and _edge_dist(q) < 6.0:
			entry.outcome = Outcome.CRUSH # sliced by the flap's edge
		else:
			entry.outcome = Outcome.SLAP
		out.append(entry)
	if Decrees.has("wet_ink"):
		# crushes splash: slapped units right next to a crush are crushed too
		var crushes := out.filter(func(e): return e.outcome == Outcome.CRUSH)
		for e in out:
			if e.outcome == Outcome.SLAP and crushes.any(func(c): return c.pos.distance_to(e.pos) < 26.0):
				e.outcome = Outcome.CRUSH
	return out


func _edge_dist(p: Vector2) -> float:
	return minf(minf(p.x, map_size.x - p.x), minf(p.y, map_size.y - p.y))


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
				if Decrees.has("flip_tax") and e.unit.team == Unit.Team.ENEMY:
					e.unit.on_slapped(-n)
			Outcome.FLING:
				e.unit.on_flung(e.target - e.pos)
				Events.flung.emit(e.unit)
	_decree_effects(m, n, outcomes)
	var tears := tear_points(m, n)
	_add_crease(m, n)
	for t in tears:
		_tear(t)
	_flash()
	var fx := Fx.of(self)
	if fx:
		fx.slam(m, n, outcomes)
	slammed.emit(m, n, outcomes)


## Slam bonuses from Royal Decrees.
func _decree_effects(m: Vector2, n: Vector2, outcomes: Array) -> void:
	var hit := {}
	for e in outcomes:
		hit[e.unit] = true
	for u in get_tree().get_nodes_in_group("enemy"):
		if not u.is_alive() or hit.has(u):
			continue
		if Decrees.has("aftershock"):
			u.stun = maxf(u.stun, 1.0)


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


## The flap's back flares for an instant when it hits the map.
func _flash() -> void:
	_mat.set_shader_parameter("flash", 1.0)
	create_tween().tween_method(func(v: float): _mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.18)


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
		_preview_tears.clear()
	else:
		var m := FoldMath.line_point(grab, pointer)
		var n := FoldMath.normal(grab, pointer)
		_preview = compute_outcomes(m, n)
		_preview_tears = tear_points(m, n)
	queue_redraw()


# --- wear & tear -------------------------------------------------------------

## Where a crease along (m, n) would rip the map: spots where it crosses two existing creases
## close together (three folds meeting weaken the paper until it gives).
func tear_points(m: Vector2, n: Vector2) -> Array[Vector2]:
	var hits: Array[Vector2] = []
	for c in creases:
		var p := _intersect(m, n, Vector2(c.x, c.y), Vector2(c.z, c.w))
		if p.is_finite() and Rect2(Vector2.ZERO, map_size).grow(-16.0).has_point(p):
			hits.append(p)
	var out: Array[Vector2] = []
	for i in hits.size():
		for j in range(i + 1, hits.size()):
			if hits[i].distance_to(hits[j]) > TEAR_REACH:
				continue
			var t := (hits[i] + hits[j]) * 0.5
			if KEEP_ZONE.has_point(t) or _near_tear(t, out):
				continue
			out.append(t)
	return out


func _near_tear(p: Vector2, extra: Array[Vector2]) -> bool:
	for h in holes:
		if h.pos.distance_to(p) < TEAR_RADIUS * 2.0:
			return true
	for q in extra:
		if q.distance_to(p) < TEAR_RADIUS * 2.0:
			return true
	return false


## Intersection of two lines given as (point, normal). INF when nearly parallel.
static func _intersect(m1: Vector2, n1: Vector2, m2: Vector2, n2: Vector2) -> Vector2:
	var det := n1.x * n2.y - n1.y * n2.x
	if absf(det) < 0.15:
		return Vector2.INF
	var c1 := m1.dot(n1)
	var c2 := m2.dot(n2)
	return Vector2(c1 * n2.y - n1.y * c2, n1.x * c2 - c1 * n2.x) / det


func _tear(p: Vector2) -> void:
	if holes.size() >= MAX_HOLES:
		return
	holes.append({"pos": p, "r": TEAR_RADIUS, "left": TEAR_CAPACITY * (2 if Decrees.has("deep_rips") else 1)})
	# whatever was printed there falls through (the Keep's zone never tears)
	for b in get_tree().get_nodes_in_group("building"):
		if b.kind != "keep" and b.contains_point(p, TEAR_RADIUS * 0.5):
			b.crumble()
	var fx := Fx.of(self)
	if fx:
		fx.dust_ring(p, TEAR_RADIUS, 14)
		fx.droplets(p, Palette.PARCHMENT_SHADOW, 10, 1.2)
		fx.text(p + Vector2(0, -22), "RIIIP!", Palette.PARCHMENT, true)
	_apply_holes()
	Audio.play_sfx("tear")
	torn.emit(p)


## Units that step into an open tear fall through. Each hole swallows TEAR_CAPACITY units,
## then gets stitched shut.
func _swallow() -> void:
	var changed := false
	for u in get_tree().get_nodes_in_group("unit"):
		if not u.is_alive():
			continue
		for h in holes:
			if h.left > 0 and u.position.distance_to(h.pos) < h.r * 0.8:
				u.on_fell(h.pos)
				h.left -= 1
				changed = true
				break
	if not changed:
		return
	for h in holes.duplicate():
		if h.left <= 0:
			holes.erase(h)
			var splats := get_tree().get_first_node_in_group("splats")
			if splats:
				splats.add_patch(h.pos, h.r)
			var fx := Fx.of(self)
			if fx:
				fx.dust_ring(h.pos, h.r, 8)
	_apply_holes()


func _apply_holes() -> void:
	var arr := PackedVector3Array()
	arr.resize(MAX_HOLES)
	for i in holes.size():
		arr[i] = Vector3(holes[i].pos.x, holes[i].pos.y, holes[i].r)
	_mat.set_shader_parameter("holes", arr)
	_mat.set_shader_parameter("hole_count", holes.size())
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_pulse * 12.0)
	# how many more units each tear can swallow
	for h in holes:
		for i in h.left:
			var c: Vector2 = h.pos + Vector2((i - (h.left - 1) * 0.5) * 5.0, h.r + 6.0)
			draw_circle(c, 1.8, Palette.INK)
			draw_circle(c, 1.1, Palette.PARCHMENT)
	# where this fold would rip the map
	for t in _preview_tears:
		var r := TEAR_RADIUS * (0.8 + 0.2 * pulse)
		var pts := PackedVector2Array()
		for k in 17:
			pts.append(t + Vector2.from_angle(TAU * k / 16.0) * r * (0.75 if k % 2 else 1.1))
		draw_polyline(pts, Palette.RED, 1.5)
	for e in _preview:
		var p: Vector2 = e.pos
		match e.outcome:
			Outcome.CRUSH:
				var c := Palette.RED.lerp(Color.WHITE, pulse * 0.3)
				draw_arc(p, 8.0 + pulse, 0.0, TAU, 16, c, 1.5)
				draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), c, 1.5)
				draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), c, 1.5)
			Outcome.SLAP:
				draw_arc(p, 7.0, 0.0, TAU, 12, Palette.GOLD, 1.0)
			Outcome.FLIP:
				var t: Vector2 = e.target
				draw_dashed_line(p, t, Palette.BLUE_LIGHT, 1.0, 3.0)
				draw_arc(t, 4.0, 0.0, TAU, 10, Palette.BLUE_LIGHT, 1.0)
			Outcome.FLING:
				# an arrow off the edge of the map
				var d: Vector2 = (e.target - e.pos).normalized()
				var c := Palette.GOLD.lerp(Color.WHITE, pulse * 0.3)
				draw_arc(p, 6.0, 0.0, TAU, 12, c, 1.5)
				draw_line(p + d * 8.0, p + d * 22.0, c, 2.0)
				draw_line(p + d * 22.0, p + d * 16.0 + d.orthogonal() * 4.0, c, 2.0)
				draw_line(p + d * 22.0, p + d * 16.0 - d.orthogonal() * 4.0, c, 2.0)


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


## Screen -> map coordinates (the Board is centered on screen and shakes).
func _local(screen_pos: Vector2) -> Vector2:
	return get_parent().to_local(screen_pos) if get_parent() is Node2D else screen_pos


func _in_map(p: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x < map_size.x and p.y < map_size.y


func _heavy_building_at(p: Vector2, margin := 0.0) -> Node:
	for b in get_tree().get_nodes_in_group("building"):
		if b.heavy and b.contains_point(p, margin + (6.0 if Decrees.has("heavy_stock") else 0.0)):
			return b
	return null
