extends Node
## Scripted barracks check: place a barracks, knights pin grunts on the road, then a fold.
## Run: Godot.exe --path . res://scenes/tests/knights_test.tscn -- --autotest-knights=<dir>

var _dir := ""
var _main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest-knights="):
			_dir = arg.trim_prefix("--autotest-knights=")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _wait(0.8)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed()
	_main._autotest = true
	_main._set_ink(20)
	_main._on_place_requested("barracks", Vector2(95, 300), 0.0)
	await _wait(0.8)
	await _shot("40_barracks")
	_main._start_wave()
	var road: PackedVector2Array = _main.paper.roads[0]
	var k := _nearest(road, Vector2(80, 120))
	for i in 3:
		var g: Unit = _main._spawn_enemy("grunt")
		g.path = road
		g.position = road[k] + Vector2(0, -i * 14.0)
		g.path_index = k + 1
	# wait for the grunts to walk into the knights (up to 14 s)
	for i in 28:
		await _wait(0.5)
		if i >= 17 and get_tree().get_nodes_in_group("enemy").any(func(e): return e.foe != null):
			await _wait(0.6)
			break
	await _shot("41_melee")
	var knights := get_tree().get_nodes_in_group("ally").size()
	var pinned := get_tree().get_nodes_in_group("enemy").filter(func(e): return e.foe != null).size()
	print("KNIGHTS alive=%d pinned=%d" % [knights, pinned])
	var fold: FoldController = _main.fold
	var target: Vector2 = get_tree().get_nodes_in_group("enemy")[0].position
	# fold the left edge so the tower at (45, 250) lands on the pinned fight
	var px := 45.0 + target.x
	fold.begin_fold(Vector2(0, 250))
	for i in 10:
		fold.drag_to(Vector2(0, 250).lerp(Vector2(px, 250 + (target.y - 250) * 2.0), (i + 1) / 10.0))
		await get_tree().process_frame
	await _wait(0.2)
	await _shot("42_aim")
	fold.release()
	await _wait(1.0)
	await _shot("43_after")
	print("KNIGHTS alive=%d enemies=%d kills=%d" % [get_tree().get_nodes_in_group("ally").filter(func(k): return k.is_alive()).size(),
		get_tree().get_nodes_in_group("enemy").size(), _main.kills])
	get_tree().quit()


## Index of the road waypoint closest to p.
func _nearest(road: PackedVector2Array, p: Vector2) -> int:
	var best := 0
	for i in road.size():
		if road[i].distance_to(p) < road[best].distance_to(p):
			best = i
	return best


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if _dir != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
