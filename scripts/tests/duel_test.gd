extends Node
## Scripted Duel of Champions with real mouse events: read the blows, strike, take a hit, fold the
## page onto the Warlord (win); then lose to the Ram's driver on purpose.
## Run: Godot.exe --path . res://scenes/tests/duel_test.tscn -- --autotest-duel=<dir>

var _dir := ""
var _main: Node
var _events: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest-duel="):
			_dir = arg.trim_prefix("--autotest-duel=")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Events.duel_started.connect(func(b: String): _events.append("start:" + b))
	Events.duel_finished.connect(func(w: bool): _events.append("won" if w else "lost"))
	_run()


func _run() -> void:
	await _wait(0.8)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed()
	_main._autotest = true
	_main._start_wave()
	var ink0: int = _main.ink

	# --- duel 1: the Iron Warlord, won with a fold finisher -----------------------------
	_main._duel("warlord")
	await get_tree().process_frame
	var duel: Duel = get_tree().get_first_node_in_group("duel")
	await _wait(0.8)
	await _shot("90_duel_intro")
	var rounds := 0
	var took_hit := false
	while is_instance_valid(duel) and duel.stage != Duel.Stage.FINISHER and rounds < 12:
		await _until(func(): return duel.stage == Duel.Stage.TELL or duel.stage == Duel.Stage.FINISHER)
		if duel.stage == Duel.Stage.FINISHER:
			break
		rounds += 1
		await _wait(0.15)
		if rounds == 1:
			await _shot("91_tell")
		if rounds == 2 and not took_hit:
			# don't answer: take the blow
			took_hit = true
			await _until(func(): return duel.hp < Duel.CHAMPION_HP)
			await _wait(0.05)
			await _shot("94_hurt")
			continue
		await _until(func(): return duel.shown == duel.move) # wait out fake-outs
		var dir: Vector2 = {Duel.Answer.DODGE_LEFT: Vector2.LEFT, Duel.Answer.DODGE_RIGHT: Vector2.RIGHT,
			Duel.Answer.BLOCK: Vector2.UP}[Duel.answer_for(duel.move)]
		await _swipe(duel, Vector2(180, 400), dir * 70.0)
		if rounds == 1:
			await _wait(0.1)
			await _shot("92_dodge")
		await _until(func(): return duel.stage == Duel.Stage.STRIKE or duel.stage == Duel.Stage.FINISHER)
		for i in 9:
			if duel.stage != Duel.Stage.STRIKE:
				break
			await _click(duel, Vector2(randf_range(120, 240), randf_range(220, 380)))
			await _wait(0.08)
			if rounds == 1 and i == 4:
				await _shot("93_strike")
	print("DUEL warlord rounds=%d hp=%d stagger=%.0f stage=%s" % [rounds, duel.hp, duel.stagger, Duel.Stage.keys()[duel.stage]])
	await _wait(0.6)
	await _shot("95_finisher")
	# fold the right edge over him
	var g := Vector2(354, 330)
	await _mouse(duel, g, true)
	for i in 10:
		await _motion(duel, g.lerp(Vector2(80, 300), (i + 1) / 10.0))
	await _wait(0.1)
	await _shot("96_fold_aim")
	print("DUEL covers=%s" % duel.fold_covers_boss())
	await _mouse(duel, Vector2(80, 300), false)
	await _wait(0.12)
	await _shot("97_slam")
	await _until(func(): return get_tree().get_nodes_in_group("duel").is_empty(), 6.0)
	await _wait(0.3)
	await _shot("98_after_warlord")
	var warlords := get_tree().get_nodes_in_group("enemy").filter(func(u): return u.kind == "warlord")
	print("DUEL warlord done: paused=%s ink +%d warlords_on_map=%d" % [get_tree().paused, _main.ink - ink0, warlords.size()])
	await _wait(Audio.BOSS_CHECK_SECONDS + 0.1)
	print("DUEL music after warlord won: %s (want battle)" % Audio._current_track)

	# --- duel 2: the Ram's driver, lost on purpose ------------------------------------
	var hp0: int = _main.keep_hp
	_main._duel("ram")
	await get_tree().process_frame
	duel = get_tree().get_first_node_in_group("duel")
	await _until(func(): return duel.stage == Duel.Stage.TELL)
	await _wait(0.25)
	await _shot("99_driver_tell")
	await _until(func(): return duel.stage == Duel.Stage.OUTRO, 20.0)
	await _wait(0.4)
	await _shot("100_ko")
	await _until(func(): return get_tree().get_nodes_in_group("duel").is_empty(), 6.0)
	await get_tree().process_frame
	var rams := get_tree().get_nodes_in_group("enemy").filter(func(u): return u.kind == "ram")
	print("DUEL driver lost: keep %d -> %d, ram crushes=%s paused=%s events=%s" % [hp0, _main.keep_hp,
		rams.map(func(r): return r.crushes_to_kill), get_tree().paused, _events])
	await _wait(Audio.BOSS_CHECK_SECONDS + 0.1)
	print("DUEL music with the ram on the map: %s (want boss)" % Audio._current_track)
	while not rams.is_empty() and rams[0].is_alive():
		rams[0].on_crushed()
	await _wait(Audio.BOSS_CHECK_SECONDS + 0.1)
	print("DUEL music after the ram died: %s (want battle)" % Audio._current_track)
	get_tree().quit()


func _swipe(duel: Duel, from: Vector2, d: Vector2) -> void:
	await _mouse(duel, from, true)
	for i in 4:
		await _motion(duel, from + d * (i + 1) / 4.0)
	await _mouse(duel, from + d, false)


func _click(duel: Duel, p: Vector2) -> void:
	await _mouse(duel, p, true)
	await _mouse(duel, p, false)


func _screen(duel: Duel, p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * (duel._page_origin() + p)


func _mouse(duel: Duel, p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = _screen(duel, p)
	e.global_position = e.position
	Input.parse_input_event(e)
	await get_tree().process_frame


func _motion(duel: Duel, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _screen(duel, p)
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	await get_tree().process_frame


func _until(cond: Callable, timeout := 10.0) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if _dir != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
