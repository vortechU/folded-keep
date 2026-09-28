extends Node
## Scripted check of the fold-aware enemies: Pin-Bearer, Crow Rider, Ink Imp.
## Run: Godot.exe --path . res://scenes/tests/enemies_test.tscn -- --autotest-enemies=<dir>

var _dir := ""
var _main: Node
var _intros: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest-enemies="):
			_dir = arg.trim_prefix("--autotest-enemies=")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Events.enemy_introduced.connect(func(k: String): _intros.append(k))
	_run()


func _run() -> void:
	await _wait(0.8)
	var screens := _main.find_child("GameScreens", true, false)
	if screens:
		screens._on_primary_pressed()
	_main._autotest = true
	_main._start_wave()
	var fold: FoldController = _main.fold

	# 1) Pin-Bearer walks to the top-left corner and nails it down
	var pin: Unit = _main._spawn_enemy("pinner")
	pin.position = Vector2(70, -10)
	await _wait(1.6)
	await _shot("70_pinner_hammering")
	await _wait(4.0)
	await _shot("71_pinned")
	var refused := not fold.begin_fold(Vector2(60, 2)) and not fold.begin_fold(Vector2(2, 100))
	await _wait(0.1)
	await _shot("72_refused")
	var other := fold.begin_fold(Vector2(250, 2))
	fold.release() # too short: cancels
	await _wait(0.3)
	print("ENEMIES pinner corner=%s planted=%s refused=%s other_ok=%s" % [pin.corner, pin.planted, refused, other])
	# counterplay: grab outside the pinned zone and slap him twice
	await _fold(fold, Vector2(200, 0), pin.position, "73_pinner_slap_aim")
	await _fold(fold, Vector2(200, 0), pin.position, "")
	print("ENEMIES pinner dead=%s free=%s" % [_dead(pin), fold.pin_at(Vector2(60, 0)) == null])

	# 2) Crow Rider: slams pass under it; flipping and flinging work
	var crow := _enemy("flyer", Vector2(180, 300))
	await _fold(fold, Vector2(360, 300), Vector2(180, 300), "74_flyer_under_flap")
	print("ENEMIES flyer after landing-zone slam alive=%s stun=%.1f" % [not _dead(crow), crow.stun])
	crow.position = Vector2(300, 300)
	await _fold(fold, Vector2(360, 300), Vector2(100, 300), "75_flyer_flip_aim")
	print("ENEMIES flyer flipped to x=%.0f" % crow.position.x)
	crow.position = Vector2(330, 590)
	await _fold(fold, Vector2(360, 420), Vector2(130, 200), "76_flyer_fling_aim")
	print("ENEMIES flyer flung=%s" % _dead(crow))
	var hp_before: int = _main.keep_hp
	var diver: Unit = _main._spawn_enemy("flyer")
	diver.position = Vector2(180, 480)
	await _wait(6.0)
	print("ENEMIES flyer reached keep: hp %d -> %d" % [hp_before, _main.keep_hp])

	# 3) Ink Imp gnaws next to a tower until the map tears (and the tower falls in)
	var tower: Building = _main._add_building("tower", Vector2(100, 380), Vector2(22, 22))
	var imp := _enemy("imp", Vector2(80, 330))
	imp.speed = 32.0
	imp.gnaw_spot = Vector2(112, 380)
	var kills: int = _main.kills
	var holes: int = fold.holes.size()
	await _wait(4.0)
	await _shot("77_imp_gnawing")
	await _wait(2.5)
	await _shot("78_imp_tore")
	print("ENEMIES imp tore holes %d -> %d tower_gone=%s imp_gone=%s kills_unchanged=%s" % [holes, fold.holes.size(),
		not is_instance_valid(tower) or not tower.is_in_group("building"), _dead(imp), _main.kills == kills])
	# a second imp gets slapped mid-gnaw: no tear
	var imp2 := _enemy("imp", Vector2(250, 200))
	imp2.gnaw_spot = Vector2(250, 200)
	await _wait(1.5)
	await _fold(fold, Vector2(360, 200), Vector2(250, 200), "79_imp_slap_aim")
	print("ENEMIES imp2 dead=%s holes=%d" % [_dead(imp2), fold.holes.size()])
	print("ENEMIES intros=%s" % [_intros])
	get_tree().quit()


func _fold(fold: FoldController, g: Vector2, p: Vector2, shot: String) -> void:
	fold.begin_fold(g)
	for i in 10:
		fold.drag_to(g.lerp(p, (i + 1) / 10.0))
		await get_tree().process_frame
	await _wait(0.15)
	if shot != "":
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
