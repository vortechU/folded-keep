extends Node
## Scripted wear & tear check: three folds meet on the left road, the map rips, grunts fall in
## until the hole is stitched shut.
## Run: Godot.exe --path . res://scenes/tests/tear_test.tscn -- --autotest-tear=<dir>

const T := Vector2(132, 300) ## where the three creases meet (on the left road)

var _dir := ""
var _main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest-tear="):
			_dir = arg.trim_prefix("--autotest-tear=")
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
	var fold: FoldController = _main.fold
	# every fold's line passes through T: grab g, pointer = mirror of g across a line through T
	await _fold(fold, Vector2(0, 300), Vector2(264, 300), false)
	await _fold(fold, Vector2(132, 0), Vector2(132, 600), false)
	await _fold(fold, Vector2(0, 168), Vector2(264, 432), true)
	print("TEAR holes=%d" % fold.holes.size())
	await _wait(0.4)
	await _shot("51_torn")
	for i in 4:
		var g: Unit = _main._spawn_enemy("grunt")
		g.path = _main.paper.roads[0]
		g.position = Vector2(140, 232) + Vector2(0, -i * 16.0)
		g.path_index = 3
		g.speed = 30.0
	await _wait(1.6)
	await _shot("52_falling")
	await _wait(3.0)
	await _shot("53_patched")
	print("TEAR holes=%d kills=%d" % [fold.holes.size(), _main.kills])
	get_tree().quit()


func _fold(fold: FoldController, g: Vector2, p: Vector2, shoot: bool) -> void:
	fold.begin_fold(g)
	for i in 10:
		fold.drag_to(g.lerp(p, (i + 1) / 10.0))
		await get_tree().process_frame
	await _wait(0.15)
	if shoot:
		await _shot("50_tear_preview")
	fold.release()
	await _wait(1.2)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if _dir != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
