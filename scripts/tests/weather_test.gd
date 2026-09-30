extends Node
## Weather: each kind fades in on a wave (screenshots), and storm gusts push Crow Riders sideways.
##   Godot.exe --path . --resolution 540x960 res://scenes/tests/weather_test.tscn -- --shots=<dir>
## Prints WEATHER lines and quits; any "FAIL" line means a check failed.

var _dir := ""
var _main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_dir = arg.trim_prefix("--shots=")
	if _dir != "":
		DirAccess.make_dir_recursive_absolute(_dir)
	var tut: GDScript = load("res://scripts/ui/fold_tutorial.gd")
	tut.set("_done", true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_run()


func _run() -> void:
	await _wait(0.6)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed()
	_main._autotest = true
	var weather: Weather = _main.weather
	for kind in ["rain", "fog", "storm"]:
		weather.forced = kind
		_main.phase = _main.Phase.BUILD
		_main.wave = 3
		_main._start_wave()
		_check(weather.kind == kind, "%s rolled" % kind)
		for p in [Vector2(120, 200), Vector2(200, 260), Vector2(160, 120)]:
			var g: Unit = _main._spawn_enemy("grunt")
			g.position = p
			g.speed = 0.0
		await _wait(3.2)
		if kind == "storm":
			weather._strike(Vector2(180, 300))
			await _wait(0.05)
		await _shot("weather_%s" % kind)
		for u in get_tree().get_nodes_in_group("enemy"):
			u.queue_free()
	# storm gust: a Crow Rider on a straight line down the middle drifts sideways
	var crow: Unit = _main._spawn_enemy("flyer")
	crow.position = Vector2(180, 100)
	weather._gust_dir = Vector2.RIGHT
	weather._gust_t = 0.0
	weather._gust_cd = 99.0
	await _wait(1.4)
	print("WEATHER gust=%s crow=%s" % [Weather.gust, crow.position])
	_check(crow.position.x > 195.0, "gust pushes the crow sideways")
	await _shot("weather_gust")
	# the wave ends: the weather fades out and the wind drops
	_main.phase = _main.Phase.BUILD
	Events.phase_changed.emit("build")
	await _wait(3.0)
	_check(weather.kind == "clear" and Weather.gust == Vector2.ZERO, "weather clears after the wave")
	print("WEATHER done")
	get_tree().quit()


func _check(ok: bool, what: String) -> void:
	print("WEATHER %s: %s" % ["ok" if ok else "FAIL", what])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	if _dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
