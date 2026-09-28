extends Node
## Scripted juice check: crush / slap / flip / immune in one fold, a stamp and a Keep hit.
## Run: Godot.exe --path . res://scenes/tests/juice_test.tscn -- --autotest-juice=<dir>

var _dir := ""
var _main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest-juice="):
			_dir = arg.trim_prefix("--autotest-juice=")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _wait(0.8)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed() # dismiss the main menu
	_main._autotest = true # no wave spawns
	_main._start_wave()
	for p in [Vector2(150, 244), Vector2(160, 256), Vector2(152, 262)]:
		_enemy("grunt", p)
	_enemy("grunt", Vector2(172, 320))
	_enemy("runner", Vector2(60, 400))
	_enemy("brute", Vector2(135, 360))
	await _wait(0.3)
	var fold: FoldController = _main.fold
	fold.begin_fold(Vector2(0, 250))
	for i in 10:
		fold.drag_to(Vector2(0, 250).lerp(Vector2(200, 250), (i + 1) / 10.0))
		await get_tree().process_frame
	await _wait(0.2)
	await _shot("30_aim")
	fold.release()
	await _wait(0.1)
	await _shot("31_impact")
	await _wait(0.25)
	await _shot("32_impact_late")
	await _wait(0.5)
	await _shot("33_after")
	_main._set_ink(20)
	_main._on_place_requested("tower", Vector2(250, 200), 0.0)
	await _wait(0.06)
	await _shot("34_stamp")
	await _wait(0.12)
	await _shot("35_stamp_land")
	Events.keep_hit.emit()
	await _wait(0.08)
	await _shot("36_keep_hit")
	get_tree().quit()


func _enemy(kind: String, pos: Vector2) -> Unit:
	var u: Unit = _main._spawn_enemy(kind)
	u.position = pos
	u.speed = 0.0
	return u


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if _dir != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
