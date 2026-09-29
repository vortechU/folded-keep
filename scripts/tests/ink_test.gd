extends Node
## Visual check of the ink look: units inked in as they appear, line boil, stamp soak, crush dissolve,
## splats bleeding into the paper. Saves crops of the 2x map render.
## Run: Godot.exe --path . res://scenes/tests/ink_test.tscn -- --autotest-ink=<dir>

var _dir := ""
var _main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest-ink="):
			_dir = arg.trim_prefix("--autotest-ink=")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _wait(0.8)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed()
	_main._autotest = true
	_main._start_wave()
	var units: Array[Unit] = []
	var x := 70.0
	for kind in ["grunt", "runner", "brute", "pinner", "imp", "flyer"]:
		var u: Unit = _main._spawn_enemy(kind)
		u.position = Vector2(x, 300)
		u.speed = 0.0
		units.append(u)
		x += 45.0
	await _wait(0.2)
	await _map("a_inking_in")
	await _wait(0.6)
	await _map("b_inked")
	await _wait(0.26)
	await _map("c_boil_next_frame")
	_main._add_building("tower", Vector2(120, 400), Vector2(22, 22))
	await _wait(0.12)
	await _map("d_stamp_soaking")
	units[0].on_crushed()
	units[2].crushes_to_kill = 1
	units[2].on_crushed()
	await _wait(0.2)
	await _map("e_crush_dissolve")
	await _wait(0.6)
	await _map("f_splat_bled")
	# atmosphere: aged paper, wind curls drawing on and blowing away, cloud shadows
	await _wait(1.5)
	await _map("g_atmosphere_1")
	await _wait(2.5)
	await _map("g_atmosphere_2")
	# ambient life: a flock of birds overhead, then a slam next to the sheep
	var world: Node = _main.get_node("MapViewport/World")
	for c in world.get_children():
		if c is Birds:
			c._spawn()
			c._flocks[-1].pos = Vector2(150, 200)
	await _wait(0.3)
	await _map("h_birds_and_sheep")
	var fold: FoldController = _main.fold
	fold.begin_fold(Vector2(360, 240))
	for i in 10:
		fold.drag_to(Vector2(360, 240).lerp(Vector2(120, 240), (i + 1) / 10.0))
		await get_tree().process_frame
	fold.release()
	await _wait(0.45)
	await _map("i_sheep_scatter")
	var scared := 0
	for c in world.get_children():
		if c is Ambient:
			scared = c._sheep.filter(func(sh): return sh.panic > 0.0).size()
	print("AMBIENT scared sheep=%d" % scared)
	print("INK done")
	get_tree().quit()


func _map(name: String) -> void:
	await RenderingServer.frame_post_draw
	if _dir != "":
		_main.map_viewport.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
