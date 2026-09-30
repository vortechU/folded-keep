extends Node
## Map art check: saves the bare map (the 2x map viewport, no HUD) and the full screen with a few
## enemies and buildings on it, to judge the terrain art and that red/blue ink stays readable.
##   Godot.exe --path . --resolution 720x1280 res://scenes/tests/map_shot.tscn -- --shots=<dir>

var _dir := ""
var _main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_dir = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(_dir)
	var tut: GDScript = load("res://scripts/ui/fold_tutorial.gd")
	tut.set("_done", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _wait(0.8)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed()
	_main._autotest = true
	await _wait(1.5)
	await RenderingServer.frame_post_draw
	_main.map_viewport.get_texture().get_image().save_png(_dir + "/map_bare.png")
	_main._set_ink(30)
	_main._on_place_requested("tower", Vector2(226, 182), 0.0)
	_main._on_place_requested("barracks", Vector2(290, 264), 0.0)
	var road: Dictionary = _main.paper.closest_road(Vector2(236, 350))
	_main._on_place_requested("wall", road.point.round(), road.dir.angle() + PI * 0.5)
	_main._start_wave()
	for p in [Vector2(80, 120), Vector2(130, 230), Vector2(125, 330), Vector2(282, 90), Vector2(170, 470)]:
		var u: Unit = _main._spawn_enemy("grunt")
		u.position = p
		u.speed = 0.0
	await _wait(1.5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir + "/map_play.png")
	# mid-fold: the flap's back shows the printed map mirrored
	var fold: FoldController = _main.fold
	var g := Vector2(0, 330)
	fold.begin_fold(g)
	for i in 12:
		fold.drag_to(g.lerp(Vector2(200, 300), (i + 1) / 12.0))
		await get_tree().process_frame
	await _wait(0.2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir + "/map_fold.png")
	fold.release()
	await _wait(0.8)
	print("MAPSHOT done")
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
