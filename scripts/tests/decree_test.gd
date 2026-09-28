extends Node
## Scripted check of Royal Decree effects and the fling-off-the-map rule.
## Run: Godot.exe --path . res://scenes/tests/decree_test.tscn -- --autotest-decree=<dir>

var _dir := ""
var _main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest-decree="):
			_dir = arg.trim_prefix("--autotest-decree=")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _wait(0.8)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed()
	_main._autotest = true
	for id: String in Decrees.LIST:
		Decrees.active.append(id)
	_main._start_wave()
	var fold: FoldController = _main.fold
	# 1) crush + wet ink splash + aftershock: tower (45,250) lands on (140,250)
	var crushed := _enemy("grunt", Vector2(140, 250))
	var splashed := _enemy("grunt", Vector2(140, 270)) # slapped, but next to the crush: wet ink
	var stunned := _enemy("grunt", Vector2(300, 420)) # far away: aftershock
	var safe := _enemy("grunt", Vector2(300, 420))
	await _fold(fold, Vector2(0, 250), Vector2(190, 250), "60_crush")
	print("DECREE crushed=%s splashed=%s stunned=%.1f safe=%.1f" % [_dead(crushed), _dead(splashed), stunned.stun, safe.stun])
	# 2) fling: a diagonal fold from the bottom-left whose flap hangs off the map
	var a := _enemy("grunt", Vector2(40, 600))
	var b := _enemy("runner", Vector2(70, 612))
	await _fold(fold, Vector2(0, 400), Vector2(200, 200), "61_fling_aim")
	await _wait(0.3)
	await _shot("62_flung")
	print("DECREE flung a=%s b=%s kills=%d" % [_dead(a), _dead(b), _main.kills])
	get_tree().quit()


func _fold(fold: FoldController, g: Vector2, p: Vector2, shot: String) -> void:
	fold.begin_fold(g)
	for i in 10:
		fold.drag_to(g.lerp(p, (i + 1) / 10.0))
		await get_tree().process_frame
	await _wait(0.15)
	await _shot(shot)
	fold.release()
	await _wait(1.0)


func _enemy(kind: String, pos: Vector2) -> Unit:
	var u: Unit = _main._spawn_enemy(kind)
	u.position = pos
	u.speed = 0.0
	return u


func _dead(u: Variant) -> bool:
	return not is_instance_valid(u) or not u.is_alive()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if _dir != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
