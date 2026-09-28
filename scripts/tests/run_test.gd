extends Node
## Fast-forwards a whole 12-wave run: starts every wave, kills enemies as they step onto the map,
## picks the first decree each time (through the decree UI) and checks both bosses show up.
## Duels are skipped: lost vs the Warlord (so he walks the map), won vs the Ram's driver (1 crush left).
## Run: Godot.exe --path . res://scenes/tests/run_test.tscn -- --autotest-run=<dir>

const SPEED := 6.0

var _dir := ""
var _main: Node
var _log := {"waves": 0, "bosses": [], "decrees": 0, "intros": [], "duels": [], "result": ""}
var _boss_seen := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest-run="):
			_dir = arg.trim_prefix("--autotest-run=")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Events.phase_changed.connect(func(p: String):
		if p == "wave":
			_log.waves += 1
		elif p == "victory" or p == "defeat":
			_log.result = p)
	Events.decree_offered.connect(func(_ids: Array): _pick_decree.call_deferred())
	Events.enemy_introduced.connect(func(k: String): _log.intros.append(k))
	Events.duel_started.connect(func(b: String):
		_log.duels.append(b)
		(func(): get_tree().get_first_node_in_group("duel").resolve(b == "driver")).call_deferred())
	_run()


func _run() -> void:
	await _wait(0.8)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed()
	var t := 0.0
	while _log.result == "" and t < 240.0:
		Engine.time_scale = SPEED
		if _main.phase == _main.Phase.BUILD:
			Events.start_wave_requested.emit()
		for u in get_tree().get_nodes_in_group("enemy"):
			if not u.is_alive() or u.position.y < 30.0:
				continue
			if u.is_boss() and u.position.y < 120.0:
				continue # let it walk into view for the screenshot
			if u.is_boss() and not _boss_seen.has(u.kind):
				_boss_seen[u.kind] = true
				_log.bosses.append("%s@wave%d(%d crushes)" % [u.kind, _main.wave + 1, u.crushes_to_kill])
				Engine.time_scale = 1.0
				await _wait(0.4)
				await _shot("80_boss_%s" % u.kind)
				continue
			u.crushes_to_kill = 1
			u.on_crushed()
		await get_tree().process_frame
		t += get_process_delta_time() / Engine.time_scale
	Engine.time_scale = 1.0
	await _wait(0.5)
	await _shot("81_end")
	print("RUN result=%s waves=%d/%d duels=%s bosses=%s decrees=%d keep=%d intros=%s" % [_log.result, _log.waves,
		Waves.LIST.size(), _log.duels, _log.bosses, _log.decrees, _main.keep_hp, _log.intros])
	get_tree().quit()


func _pick_decree() -> void:
	_log.decrees += 1
	for c in _main.find_children("*", "Control", true, false):
		if c.has_method("_choose"):
			c._choose(0)
			return
	Events.decree_chosen.emit(Decrees.roll(1)[0])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if _dir != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
