extends Node
## Itch page capture: stages a few dramatic moments and saves screenshots + GIF frames.
## Run at a big portrait window:
##   Godot.exe --path . --resolution 576x1024 res://scenes/tests/capture.tscn -- --autotest-capture=<dir>
## Then build the GIF / cover with tools/itch_media.py.

var _dir := ""
var _main: Node
var _fold: FoldController


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest-capture="):
			_dir = arg.trim_prefix("--autotest-capture=")
	DirAccess.make_dir_recursive_absolute(_dir + "/gif")
	var tut: GDScript = load("res://scripts/ui/fold_tutorial.gd")
	tut.set("_done", true) # no tutorial overlay in marketing shots
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _wait(0.8)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed()
	_fold = _main.fold
	_main._autotest = true
	_main._set_ink(30)
	# --- build phase: stamp defenses ---
	_main._on_place_requested("barracks", Vector2(290, 264), 0.0)
	_wall(Vector2(236, 350))
	_main._on_place_requested("tower", Vector2(226, 182), 0.0)
	await _wait(2.2)
	await _shot("shot_1_build")
	# --- wave: a column on the left road, a fight on the right ---
	_main._start_wave()
	for p in [Vector2(138, 222), Vector2(146, 236), Vector2(132, 240), Vector2(143, 208), Vector2(128, 255)]:
		_enemy("grunt", p)
	_enemy("runner", Vector2(60, 140))
	_enemy("brute", Vector2(110, 300))
	for p in [Vector2(226, 280), Vector2(233, 300), Vector2(284, 110)]:
		_enemy("grunt", p, 6.0)
	_enemy("runner", Vector2(279, 60), 12.0)
	await _wait(2.4)
	await _shot("shot_2_wave")
	# --- the fold: drag the left edge in so the tower lands on the column (GIF) ---
	var g := Vector2(0, 250)
	var p := Vector2(186, 250)
	_fold.begin_fold(g)
	var frame := 0
	for i in 22:
		var k := clampf(i / 18.0, 0.0, 1.0)
		_fold.drag_to(g.lerp(p, 1.0 - pow(1.0 - k, 2.0)))
		await _gif(frame)
		frame += 1
	await _shot("shot_3_aim")
	for i in 4:
		await _gif(frame)
		frame += 1
	_fold.release()
	for i in 34:
		await _gif(frame)
		frame += 1
		if i == 5:
			await _shot("shot_4_slam")
	await _wait(1.0)
	# --- wear & tear: three folds meeting on the right road ---
	var t := Vector2(235, 232)
	await _fold_through(t, Vector2(1, 0))
	await _fold_through(t, Vector2(0, 1))
	for q in [Vector2(262, 186), Vector2(268, 168), Vector2(273, 150)]:
		_enemy("grunt", q, 22.0)
	var d := Vector2(1, -1).normalized()
	var g3 := _edge_point(t, d)
	_fold.begin_fold(g3)
	for i in 10:
		_fold.drag_to(g3.lerp(2.0 * t - g3, (i + 1) / 10.0))
		await get_tree().process_frame
	await _wait(0.15)
	await _shot("shot_5_tear_aim")
	_fold.release()
	await _wait(0.9)
	await _shot("shot_6_torn")
	# --- boss ---
	var ram: Unit = _enemy("ram", Vector2(170, 440), 0.0)
	_enemy("grunt", Vector2(150, 420), 0.0)
	_enemy("grunt", Vector2(192, 425), 0.0)
	Events.banner.emit("THE SIEGE RAM!")
	await _wait(1.8)
	await _shot("shot_7_boss")
	print("CAPTURE done, ram hp=%d" % ram.crushes_to_kill)
	get_tree().quit()


## Fold whose crease passes through t, along direction `along`, grabbing the nearest edge.
func _fold_through(t: Vector2, normal: Vector2) -> void:
	var g := _edge_point(t, normal)
	_fold.begin_fold(g)
	for i in 8:
		_fold.drag_to(g.lerp(2.0 * t - g, (i + 1) / 8.0))
		await get_tree().process_frame
	_fold.release()
	await _wait(1.1)


## The nearer map-edge point from t along +/-dir, so the fold's pointer (mirror of the grab
## across t) stays on the map.
func _edge_point(t: Vector2, dir: Vector2) -> Vector2:
	var best := t
	for d in [dir, -dir]:
		var p := t
		while Rect2(Vector2.ZERO, Paper.SIZE).has_point(p + d):
			p += d
		if best == t or p.distance_to(t) < best.distance_to(t):
			best = p
	return best


func _wall(near: Vector2) -> void:
	var road: Dictionary = _main.paper.closest_road(near)
	_main._on_place_requested("wall", road.point.round(), road.dir.angle() + PI * 0.5)


func _enemy(kind: String, pos: Vector2, speed := 0.0) -> Unit:
	var u: Unit = _main._spawn_enemy(kind)
	u.position = pos
	u.speed = speed
	# walk on along whichever road segment is closest
	var best := INF
	for r: PackedVector2Array in _main.paper.roads:
		for i in r.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(pos, r[i], r[i + 1])
			if q.distance_to(pos) < best:
				best = q.distance_to(pos)
				u.path = r
				u.path_index = i + 1
	return u


func _gif(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/gif/%03d.png" % [_dir, i])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
