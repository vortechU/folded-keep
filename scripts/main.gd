extends Node2D
## Game driver: build phase → wave → build phase … → victory / defeat. Juice on slams.
## Run with `-- --autotest=<dir>` to play a scripted fold + build and save screenshots there.

const UnitScript := preload("res://scripts/units/unit.gd")
const BuildingScript := preload("res://scripts/buildings/building.gd")
const ArcherTowerScript := preload("res://scripts/buildings/archer_tower.gd")
const DuelScene := preload("res://scenes/duel/duel.tscn")
const CloudsShader := preload("res://shaders/clouds.gdshader")
const UiStyle := preload("res://scripts/ui/ui_style.gd")
## Ink for beating the Iron Warlord in his duel.
const DUEL_REWARD := 12
## Keep damage when the Champion loses a duel (never drops the Keep below 1).
const DUEL_LOSS_DAMAGE := 2
const TOWER_GUARD_LIMIT := 2 ## active guards a tower can drop onto the battlefield
const TOWER_GUARD_LIFETIME := 18.0 ## seconds before a dropped guard fades away

enum Phase { BUILD, WAVE, OVER }
## The map is rendered at this multiple of its 360x640 logical size, so painted art stays sharp.
## Gameplay coordinates are unaffected.
const RENDER_SCALE := 2
const LOOK_ZOOM := 2.0

@onready var map_viewport: SubViewport = $MapViewport
@onready var paper: Paper = $MapViewport/World/Paper
@onready var units: Node2D = $MapViewport/World/Units
@onready var buildings: Node2D = $MapViewport/World/Buildings
@onready var board: Node2D = $Board
@onready var display: Sprite2D = $Board/MapDisplay
@onready var fold: FoldController = $Board/FoldController
@onready var build: BuildController = $Board/BuildController
@onready var hud: Control = $UI/Hud

var phase := Phase.BUILD
var wave := 0 # waves completed / index of next wave
var keep_hp := Waves.KEEP_MAX_HP
var ink := Waves.START_INK
var kills := 0
var enemies_crushed := 0
var biggest_fold := 0
var folds_made := 0
var duels_won := 0
var duels_fought := 0
var _tower_lesson_done := false
var _lesson_timer := 0.0

var _queue: Array[String] = []
var _spawn_timer := 0.0
var _shake := 0.0
var _origin := Vector2.ZERO ## where the map sits on screen (centered; the table fills the rest)
var _autotest := false
var _introduced := {} ## enemy kinds seen this run
var _dueling := false
var _debug := false ## wave-skip key on (see _read_debug_args)
var weather: Weather
var _flash: ColorRect ## lightning lights up the whole screen
var _looking := false
var _look_dragging := false
var _look_pan := Vector2.ZERO ## top-left map point visible while inspecting
var _look_button: Button
var _look_hint: Label
var _archer_button: Button


func _ready() -> void:
	Engine.time_scale = 1.0
	# Tall phones and wide desktop windows get more table around the map instead of black bars.
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_viewport().size_changed.connect(_layout)
	_layout()
	map_viewport.size = Vector2i(Paper.SIZE * RENDER_SCALE)
	$MapViewport/World.scale = Vector2.ONE * RENDER_SCALE
	display.scale = Vector2.ONE / RENDER_SCALE
	display.texture = map_viewport.get_texture()
	fold.setup(display)
	fold.slammed.connect(_on_slammed)
	build.paper = paper
	build.place_requested.connect(_on_place_requested)
	build.disarmed.connect(func(): fold.enabled = true)
	_add_look_control()
	_add_archer_button()
	build.disarmed.connect(_refresh_archer_button)
	Events.build_requested.connect(_on_build_requested)
	Events.start_wave_requested.connect(_start_wave)
	Events.restart_requested.connect(func(): get_tree().reload_current_scene())
	Events.decree_chosen.connect(_on_decree_chosen)
	Events.duel_finished.connect(_record_duel)
	Decrees.reset()
	_add_atmosphere()

	_add_building("keep", Paper.KEEP_POS + Vector2(0, 10), Vector2(76, 44))
	_add_building("tower", Vector2(45, 250), Vector2(22, 22))
	_add_building("tower", Vector2(315, 400), Vector2(22, 22))

	_read_debug_args()
	Events.ink_changed.emit(ink)
	Events.keep_hp_changed.emit(keep_hp, Waves.KEEP_MAX_HP)
	Events.wave_changed.emit(wave + 1, Waves.LIST.size())
	_enter_build()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			_run_autotest(arg.trim_prefix("--autotest="))


## Debug options, for playtesting later waves quickly:
##   web:     index.html?wave=5  (or ?debug)     desktop: -- --wave=5  (or -- --debug)
## `wave=N` starts the run at wave N (with the wave-clear ink of the skipped waves).
## In debug mode (also any debug build) the N key clears the current wave.
func _read_debug_args() -> void:
	var args: Array[String] = []
	args.assign(OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search", true)
		if query is String:
			for part in (query as String).trim_prefix("?").split("&", false):
				args.append("--" + part)
	_debug = OS.is_debug_build()
	for arg in args:
		if arg == "--debug":
			_debug = true
		elif arg.begins_with("--wave="):
			_debug = true
			var start := clampi(arg.trim_prefix("--wave=").to_int(), 1, Waves.LIST.size()) - 1
			wave = start
			ink += Waves.WAVE_BONUS_INK * start
		elif arg.begins_with("--weather="):
			weather.forced = arg.trim_prefix("--weather=")


## Debug: crush every enemy on the map and drop the rest of the wave, so it ends normally.
func _debug_clear_wave() -> void:
	if phase != Phase.WAVE or _dueling:
		return
	_queue.clear()
	for u in get_tree().get_nodes_in_group("enemy"):
		if u.is_alive():
			u.crushes_to_kill = 1
			u.on_crushed()
	_check_wave_end.call_deferred()


## Wind curls on the paper, cloud shadows over everything, and ambient life (sheep, smoke, birds).
func _add_atmosphere() -> void:
	var world := $MapViewport/World
	var wind := Wind.new()
	world.add_child(wind)
	world.move_child(wind, paper.get_index() + 1)
	var clouds := Node2D.new()
	clouds.name = "Clouds"
	var mat := ShaderMaterial.new()
	mat.shader = CloudsShader
	mat.set_shader_parameter("drift", Wind.DIR * Wind.SPEED)
	clouds.material = mat
	clouds.draw.connect(func(): clouds.draw_rect(Rect2(Vector2.ZERO, Paper.SIZE), Color.WHITE))
	world.add_child(clouds)
	# sheep and chimney smoke under the buildings; birds above everything
	var ambient := Ambient.new()
	ambient.paper = paper
	world.add_child(ambient)
	world.move_child(ambient, buildings.get_index())
	fold.slammed.connect(ambient.on_slam)
	world.add_child(Birds.new())
	# weather over everything; its wet spots and scorch marks soak into the paper under the wind curls
	weather = Weather.new()
	world.add_child(weather)
	world.add_child(weather.ground)
	world.move_child(weather.ground, wind.get_index())
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 0.98, 0.88, 0.0)
	layer.add_child(_flash)
	weather.lightning.connect(_on_lightning)


# --- phases ---------------------------------------------------------------------------

func _enter_build() -> void:
	_set_looking(false)
	_look_button.hide()
	phase = Phase.BUILD
	_archer_button.show()
	_refresh_archer_button()
	if Decrees.has("masons_guild"):
		for b in get_tree().get_nodes_in_group("building"):
			if b.kind == "wall":
				b.max_hp = 12
				b.hp = 12
				b.queue_redraw()
	_fill_squads()
	Events.phase_changed.emit("build")
	Events.banner.emit("BUILD, THEN FIGHT!" if wave == 0 else "WAVE CLEARED")


func _start_wave() -> void:
	if phase != Phase.BUILD:
		return
	build.disarm()
	phase = Phase.WAVE
	_archer_button.hide()
	_look_button.show()
	_queue = Waves.queue_for(wave)
	_spawn_timer = 0.5
	Events.wave_changed.emit(wave + 1, Waves.LIST.size())
	Events.phase_changed.emit("wave")
	var sky := weather.roll(wave, Waves.LIST[wave].has("flyer"))
	if wave == Waves.LIST.size() - 1:
		Events.banner.emit("FINAL WAVE" + ("\n" + sky if sky else ""))
	elif Waves.LIST[wave].get("boss", false):
		Events.banner.emit("WAVE %d\nA CHAMPION APPROACHES" % (wave + 1))
	else:
		Events.banner.emit("WAVE %d" % (wave + 1) + ("\n" + sky if sky else ""))


func _check_wave_end() -> void:
	if phase != Phase.WAVE or not _queue.is_empty():
		return
	if get_tree().get_nodes_in_group("enemy").any(func(u): return u.is_alive()):
		return
	_set_looking(false)
	_look_button.hide()
	_archer_button.hide()
	wave += 1
	if wave >= Waves.LIST.size():
		_game_over(true)
		return
	_set_ink(ink + Waves.WAVE_BONUS_INK)
	Events.wave_changed.emit(wave + 1, Waves.LIST.size())
	_offer_decrees()


## The King offers 3 decrees; the UI answers with Events.decree_chosen. Without a decree UI
## (or in scripted tests) we skip straight to the build phase.
func _offer_decrees() -> void:
	var ids := Decrees.roll(3)
	if ids.is_empty() or _autotest or Events.decree_offered.get_connections().is_empty():
		_enter_build()
		return
	phase = Phase.OVER # nothing runs while the King speaks
	Events.decree_offered.emit(ids)


func _on_decree_chosen(id: String) -> void:
	if Decrees.has(id) or not Decrees.LIST.has(id):
		return
	Decrees.active.append(id)
	match id:
		"stone_keep":
			keep_hp = Waves.KEEP_MAX_HP + 4
			Events.keep_hp_changed.emit(keep_hp, keep_max_hp())
	_enter_build()


func squad_size() -> int:
	return Waves.SQUAD_SIZE + (1 if Decrees.has("reinforcements") else 0)


func keep_max_hp() -> int:
	return Waves.KEEP_MAX_HP + (4 if Decrees.has("stone_keep") else 0)


func _game_over(won: bool) -> void:
	_set_looking(false)
	_look_button.hide()
	_archer_button.hide()
	phase = Phase.OVER
	build.disarm()
	Events.battle_report_ready.emit({
		"won": won, "kills": kills, "crushed": enemies_crushed,
		"biggest_fold": biggest_fold, "folds": folds_made,
		"duels_won": duels_won, "duels_fought": duels_fought,
		"keep_hp": keep_hp, "keep_max_hp": keep_max_hp(),
		"waves_cleared": wave, "total_waves": Waves.LIST.size(),
	})
	Events.phase_changed.emit("victory" if won else "defeat")
	Events.banner.emit(("VICTORY!" if won else "THE KEEP HAS FALLEN") + "\ntap to play again")


# --- building -------------------------------------------------------------------------

func _on_build_requested(kind: String) -> void:
	if phase != Phase.BUILD or ink < Waves.COSTS[kind]:
		Audio.play_sfx("ui_cancel")
		return
	if build.armed == kind:
		Audio.play_sfx("ui_cancel")
		build.disarm()
		return
	Audio.play_sfx("ui_click")
	fold.enabled = false
	build.arm(kind)
	_refresh_archer_button()
	if kind == "archer_tower":
		Events.banner.emit("ARCHER TOWER\nTwo arrows ground a Crow Rider")


func _on_place_requested(kind: String, pos: Vector2, rot: float) -> void:
	if ink < Waves.COSTS[kind]:
		return
	_set_ink(ink - Waves.COSTS[kind])
	var b := _add_building(kind, pos, BuildController.SIZES[kind])
	b.rotation = rot
	_shake = 2.0
	Events.building_placed.emit(kind, pos)
	if kind == "barracks":
		_fill_squads.call_deferred()
	if ink < Waves.COSTS[kind]:
		build.disarm()


func _add_building(kind: String, pos: Vector2, size: Vector2) -> Building:
	var b: Building = ArcherTowerScript.new() if kind == "archer_tower" else BuildingScript.new()
	b.kind = kind
	b.size = size
	b.position = pos
	if kind == "wall":
		b.max_hp = 12 if Decrees.has("masons_guild") else 6
	elif kind == "barracks" or kind == "archer_tower":
		b.heavy = false
	buildings.add_child(b)
	return b


# --- units ----------------------------------------------------------------------------

func _spawn_enemy(kind: String) -> Unit:
	var road: PackedVector2Array = paper.roads.pick_random()
	if kind == "flyer":
		# crows ignore the roads: a straight line from anywhere along the top
		road = PackedVector2Array([Vector2(randf_range(50, 310), -12), Paper.KEEP_POS])
	var u: Unit = UnitScript.new()
	u.team = Unit.Team.ENEMY
	u.setup(kind)
	u.position = road[0]
	u.path = road
	u.path_index = 1
	units.add_child(u)
	u.died.connect(_on_unit_died)
	u.reached_keep.connect(_on_reached_keep)
	u.gnawed.connect(func(p: Vector2): fold.tear_at(p))
	if not _introduced.has(kind):
		_introduced[kind] = true
		if kind != "grunt":
			Events.enemy_introduced.emit(kind)
	if Waves.BOSSES.has(kind):
		Events.boss_spawned.emit()
		Events.banner.emit(Waves.BOSSES[kind])
	return u


## Duel of Champions: the map freezes while the Champion fights the boss (or its driver).
## Win: the Warlord is defeated outright / the Ram enters with one crush left.
## Lose: the boss enters at full strength and the Keep takes DUEL_LOSS_DAMAGE.
func _duel(kind: String) -> void:
	_set_looking(false)
	_look_button.hide()
	_dueling = true
	var duel: Duel = DuelScene.instantiate()
	duel.boss = "driver" if kind == "ram" else kind
	add_child(duel)
	get_tree().paused = true
	var won: bool = await duel.finished
	get_tree().paused = false
	_dueling = false
	if phase == Phase.OVER:
		return
	_look_button.show()
	if kind == "warlord" and won:
		kills += 1
		_set_ink(ink + DUEL_REWARD)
		_shake = 8.0
		Events.banner.emit("THE WARLORD FALLS!\n+%d INK" % DUEL_REWARD)
		_check_wave_end.call_deferred()
		return
	var b := _spawn_enemy(kind)
	if won:
		b.crushes_to_kill = 1
		Events.banner.emit("THE RAM LIMPS IN!\nONE CRUSH LEFT")
	else:
		keep_hp = maxi(1, keep_hp - DUEL_LOSS_DAMAGE)
		_shake = 6.0
		Events.keep_hit.emit()
		Events.keep_hp_changed.emit(keep_hp, keep_max_hp())


## Each barracks keeps its squad of knights topped up during waves.
func _update_barracks(delta: float) -> void:
	for b in get_tree().get_nodes_in_group("building"):
		if b.kind != "barracks":
			continue
		b.squad = b.squad.filter(func(k): return is_instance_valid(k) and k.is_alive())
		if b.squad.size() >= squad_size():
			b.spawn_cd = 0.0
			continue
		b.spawn_cd -= delta
		if b.spawn_cd <= 0.0:
			b.spawn_cd = Waves.KNIGHT_RESPAWN
			b.squad.append(_spawn_knight(b))
		b.queue_redraw()


## Barracks start every wave (and arrive) with a full squad.
func _fill_squads() -> void:
	for b in get_tree().get_nodes_in_group("building"):
		if b.kind == "barracks":
			b.squad = b.squad.filter(func(k): return is_instance_valid(k) and k.is_alive())
			while b.squad.size() < squad_size():
				b.squad.append(_spawn_knight(b))
			b.spawn_cd = Waves.KNIGHT_RESPAWN
			b.queue_redraw()


func _spawn_knight(b: Building) -> Unit:
	# Guard the nearest road, a few steps apart from squadmates.
	var road := paper.closest_road(b.position)
	return _spawn_knight_at(b.position + Vector2(0, b.size.y * 0.5 + 2),
		road.point + road.dir * (b.squad.size() * 14.0 - 7.0))


func _spawn_knight_at(start: Vector2, guard_post: Vector2) -> Unit:
	var k: Unit = UnitScript.new()
	k.team = Unit.Team.ALLY
	k.setup("knight")
	k.position = start
	k.post = guard_post
	k.died.connect(_on_unit_died)
	units.add_child(k)
	var fx := Fx.of(self)
	if fx:
		fx.dust_ring(k.position, 6.0, 5)
	return k


## Tower crews tumble onto the map when their tower lands a crushing blow. Only one crewman
## drops per tower per slam, and the short lifetime keeps towers distinct from barracks.
func _drop_tower_guards(outcomes: Array) -> void:
	var used_towers := {}
	for outcome in outcomes:
		if outcome.outcome != FoldController.Outcome.CRUSH:
			continue
		var victim: Unit = outcome.unit
		if victim.team != Unit.Team.ENEMY:
			continue
		for building in get_tree().get_nodes_in_group("building"):
			var tower := building as Building
			if tower == null or tower.kind != "tower" or used_towers.has(tower.get_instance_id()):
				continue
			if not tower.contains_point(outcome.target, victim.hit_radius()):
				continue
			used_towers[tower.get_instance_id()] = true
			_drop_tower_guard(tower, outcome.pos)
			break


func _drop_tower_guard(tower: Building, impact: Vector2) -> void:
	tower.squad = tower.squad.filter(func(k): return is_instance_valid(k) and k.is_alive())
	if tower.squad.size() >= TOWER_GUARD_LIMIT:
		return
	var side := -7.0 if tower.squad.is_empty() else 7.0
	var landing := (impact + Vector2(side, 2)).clamp(Vector2(8, 8), Paper.SIZE - Vector2(8, 8))
	var guard := _spawn_knight_at(landing + Vector2(0, -24), paper.closest_road(landing).point)
	guard.stun = 0.4
	guard.scale = Vector2(0.8, 1.25)
	tower.squad.append(guard)
	var drop := guard.create_tween().set_parallel()
	drop.tween_property(guard, "position", landing, 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	drop.tween_property(guard, "scale", Vector2.ONE, 0.28)
	drop.chain().tween_callback(func() -> void:
		var fx := Fx.of(guard)
		if fx:
			fx.dust_ring(landing, 9.0, 8)
			fx.text(landing + Vector2(0, -20), "GUARD DROPPED!", Palette.BLUE_LIGHT))
	var fade := guard.create_tween()
	fade.tween_interval(TOWER_GUARD_LIFETIME)
	fade.tween_property(guard, "modulate:a", 0.0, 0.4)
	fade.tween_callback(guard.queue_free)


func _on_unit_died(u: Unit) -> void:
	if u.escaped:
		_check_wave_end.call_deferred()
		return
	if u.team == Unit.Team.ENEMY:
		kills += 1
		_set_ink(ink + Waves.REWARDS.get(u.kind, 1) + (1 if Decrees.has("royal_treasury") else 0))
	Events.unit_crushed.emit(u)
	_check_wave_end.call_deferred()


func _on_reached_keep(u: Unit) -> void:
	keep_hp = maxi(0, keep_hp - Waves.KEEP_DAMAGE.get(u.kind, 1))
	_shake = 5.0
	Events.keep_hit.emit()
	Events.keep_hp_changed.emit(keep_hp, keep_max_hp())
	if keep_hp <= 0 and phase != Phase.OVER:
		_game_over(false)
	else:
		_check_wave_end.call_deferred()


## True when the Keep itself rides the flap and lands on the map.
func _is_keep_slam(m: Vector2, n: Vector2) -> bool:
	var keep_pos := Paper.KEEP_POS + Vector2(0, 10)
	return FoldMath.side(keep_pos, m, n) > 0.0 and Rect2(Vector2.ZERO, fold.map_size).has_point(FoldMath.mirror(keep_pos, m, n))


func _set_ink(v: int) -> void:
	ink = v
	Events.ink_changed.emit(ink)
	_refresh_archer_button()


# --- frame ----------------------------------------------------------------------------

func _record_duel(won: bool) -> void:
	duels_fought += 1
	if won:
		duels_won += 1


## A live first-wave example uses the existing fold math without changing controls.
## Main reads gameplay objects; the tutorial receives map coordinates through Events.
func _update_fold_lesson(delta: float) -> void:
	if _tower_lesson_done or wave != 0 or phase != Phase.WAVE:
		return
	_lesson_timer -= delta
	if _lesson_timer > 0.0:
		return
	_lesson_timer = 0.1
	var dragging := fold.state == FoldController.State.DRAGGING
	var best_tower: Building
	var best_enemy: Unit
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("building"):
		var tower := node as Building
		if tower.kind != "tower":
			continue
		for enemy_node in get_tree().get_nodes_in_group("enemy"):
			var enemy := enemy_node as Unit
			if not enemy.is_alive() or not Rect2(Vector2(30, 80), Vector2(300, 430)).has_point(enemy.position):
				continue
			var distance := tower.position.distance_squared_to(enemy.position)
			if distance < best_distance:
				best_distance = distance
				best_tower = tower
				best_enemy = enemy
	if best_enemy == null:
		Events.fold_lesson_changed.emit({"has_target": false, "dragging": dragging, "ready": false})
		return
	var midpoint := (best_tower.position + best_enemy.position) * 0.5
	var normal := (best_tower.position - best_enemy.position).normalized()
	var reach := INF
	if absf(normal.x) > 0.001:
		reach = minf(reach, ((356.0 if normal.x > 0.0 else 4.0) - midpoint.x) / normal.x)
	if absf(normal.y) > 0.001:
		reach = minf(reach, ((636.0 if normal.y > 0.0 else 4.0) - midpoint.y) / normal.y)
	var grab := midpoint + normal * reach
	var pointer := midpoint - normal * reach
	var ready := false
	if dragging and fold.grab.distance_to(fold.pointer) >= 24.0:
		for outcome in fold.compute_outcomes(FoldMath.line_point(fold.grab, fold.pointer), FoldMath.normal(fold.grab, fold.pointer)):
			var enemy := outcome.unit as Unit
			if outcome.outcome != FoldController.Outcome.CRUSH or enemy.team != Unit.Team.ENEMY:
				continue
			for node in get_tree().get_nodes_in_group("building"):
				var tower := node as Building
				if tower.kind == "tower" and tower.contains_point(outcome.target, enemy.hit_radius()):
					ready = true
	Events.fold_lesson_changed.emit({
		"has_target": Rect2(Vector2.ZERO, Paper.SIZE).has_point(pointer),
		"tower": best_tower.position, "enemy": best_enemy.position,
		"grab": grab, "pointer": pointer, "dragging": dragging, "ready": ready,
	})


func _process(delta: float) -> void:
	_update_fold_lesson(delta)
	if phase == Phase.WAVE and not _queue.is_empty() and not _autotest and not _dueling:
		_spawn_timer -= delta
		# a boss waits for the player to finish the fold in hand, then calls a duel
		if _spawn_timer <= 0.0 and not (Waves.BOSSES.has(_queue[0]) and fold.state != FoldController.State.IDLE):
			_spawn_timer = Waves.LIST[wave].interval
			var kind: String = _queue.pop_front()
			if Waves.BOSSES.has(kind):
				_duel(kind)
			else:
				_spawn_enemy(kind)
	if phase == Phase.WAVE:
		_update_barracks(delta)
	_shake = maxf(0.0, _shake - delta * 40.0)
	var shake_offset := (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake).round()
	board.position = _origin - _look_pan * board.scale.x + shake_offset


func _on_lightning(_pos: Vector2) -> void:
	_shake = maxf(_shake, 3.0)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.45, 0.04)
	tw.tween_property(_flash, "color:a", 0.1, 0.07)
	tw.tween_property(_flash, "color:a", 0.3, 0.04)
	tw.tween_property(_flash, "color:a", 0.0, 0.35)


## Center the 360x640 map (and the HUD drawn over it) in whatever screen we got.
func _layout() -> void:
	var vis := get_viewport().get_visible_rect().size
	_origin = ((vis - Paper.SIZE) * 0.5).floor()
	board.position = _origin - _look_pan * board.scale.x
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.position = _origin
	hud.size = Paper.SIZE


func _unhandled_input(event: InputEvent) -> void:
	if _looking and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_look_dragging = event.pressed
		get_viewport().set_input_as_handled()
	elif _looking and event is InputEventMouseMotion and _look_dragging:
		_look_pan = (_look_pan - event.relative / LOOK_ZOOM).clamp(
			Vector2.ZERO, Paper.SIZE - Paper.SIZE / LOOK_ZOOM)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
	elif _debug and event is InputEventKey and event.pressed and event.keycode == KEY_N:
		_debug_clear_wave()
	elif phase == Phase.OVER and event is InputEventMouseButton and event.pressed:
		Events.restart_requested.emit()


## Inspection is a separate one-pointer mode, so map drags cannot accidentally fold.
func _add_look_control() -> void:
	_look_button = Button.new()
	_look_button.position = Vector2(143, 32)
	_look_button.size = Vector2(74, 36)
	_look_button.text = "LOOK"
	_look_button.tooltip_text = "Zoom in and drag to inspect the map"
	UiStyle.button(_look_button)
	_look_button.pressed.connect(func() -> void: _set_looking(not _looking))
	hud.add_child(_look_button)
	hud.move_child(_look_button, 0) # menus and decree cards stay above it
	_look_button.hide()
	_look_hint = UiStyle.label("Drag to look around", Rect2(80, 76, 200, 28), 13, UiStyle.PAPER)
	_look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_look_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_look_hint)
	hud.move_child(_look_hint, 1)
	_look_hint.hide()


## Third stamp in the left column, under Barracks; the centre stays clear over the keep.
func _add_archer_button() -> void:
	_archer_button = Button.new()
	_archer_button.position = Vector2(8, 602)
	_archer_button.size = Vector2(128, 34)
	_archer_button.text = "Archer   6"
	_archer_button.tooltip_text = "6 ink. Shoots Crow Riders within range; two arrows bring one down."
	_archer_button.icon = load("res://assets/sprites/buildings/archer_tower.png") as Texture2D
	_archer_button.expand_icon = true
	_archer_button.add_theme_constant_override("icon_max_width", 25)
	_archer_button.add_theme_constant_override("h_separation", 4)
	UiStyle.button(_archer_button)
	_archer_button.pressed.connect(func() -> void: Events.build_requested.emit("archer_tower"))
	hud.add_child(_archer_button)
	hud.move_child(_archer_button, 0) # menus and decree cards remain on top
	_archer_button.hide()


func _refresh_archer_button() -> void:
	if _archer_button == null:
		return
	var selected := build.armed == "archer_tower"
	_archer_button.disabled = ink < Waves.COSTS.archer_tower or (build.armed != "" and not selected)
	_archer_button.add_theme_stylebox_override("normal", UiStyle.box(
		UiStyle.BLUE if selected else UiStyle.LIGHT, UiStyle.INK))
	_archer_button.add_theme_color_override("font_color", UiStyle.LIGHT if selected else UiStyle.INK)


func _set_looking(active: bool) -> void:
	if active and (phase != Phase.WAVE or _dueling or fold.state != FoldController.State.IDLE):
		return
	_looking = active
	_look_dragging = false
	_look_pan = (Paper.SIZE - Paper.SIZE / LOOK_ZOOM) * 0.5 if active else Vector2.ZERO
	board.scale = Vector2.ONE * (LOOK_ZOOM if active else 1.0)
	board.position = _origin - _look_pan * board.scale.x
	fold.enabled = not active
	_look_button.text = "BACK" if active else "LOOK"
	_look_hint.visible = active
	Events.map_inspection_changed.emit(active)


func _on_slammed(m: Vector2, n: Vector2, outcomes: Array) -> void:
	var crushes := outcomes.filter(func(e): return e.outcome == FoldController.Outcome.CRUSH).size()
	var fold_kills := 0
	var tower_crush := false
	for outcome in outcomes:
		var victim := outcome.unit as Unit
		if not is_instance_valid(victim) or victim.team != Unit.Team.ENEMY:
			continue
		if not victim.is_alive():
			fold_kills += 1
		if outcome.outcome != FoldController.Outcome.CRUSH:
			continue
		if not victim.is_alive() and phase == Phase.WAVE:
			enemies_crushed += 1
		for node in get_tree().get_nodes_in_group("building"):
			var tower := node as Building
			if tower.kind == "tower" and tower.contains_point(outcome.target, victim.hit_radius()):
				tower_crush = true
	if phase == Phase.WAVE:
		folds_made += 1
		biggest_fold = maxi(biggest_fold, fold_kills)
		if tower_crush and not _tower_lesson_done:
			_tower_lesson_done = true
			Events.tower_crush_landed.emit()
	Events.slammed.emit(crushes)
	_drop_tower_guards(outcomes)
	_shake = 4.0 + crushes * 1.5
	if _is_keep_slam(m, n):
		_shake += 6.0
		Events.keep_slammed.emit()
		Events.banner.emit("KEEP SLAM!")
		if keep_hp > 1 and phase == Phase.WAVE and not Decrees.has("thick_parchment"):
			keep_hp = maxi(1, keep_hp - Waves.KEEP_SLAM_COST)
			Events.keep_hp_changed.emit(keep_hp, keep_max_hp())
	# hit-stop: freeze for a heartbeat so the slam lands
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.07 + 0.02 * mini(crushes, 4), true, false, true).timeout
	Engine.time_scale = 1.0


# --- scripted test --------------------------------------------------------------------

func _run_autotest(dir: String) -> void:
	_autotest = true
	await _wait(0.5) # let the window settle so tap mapping is right
	_start_wave()
	var ram := _spawn_enemy("ram")
	ram.position = Vector2(180, 462)
	ram.speed = 0.0
	for x in [150.0, 212.0]:
		var g := _spawn_enemy("grunt")
		g.position = Vector2(x, 470)
		g.speed = 0.0
	await _wait(0.3)
	await _shot(dir + "/20_boss.png")
	# Keep Slam: fold the bottom edge up so the Keep lands on the ram
	fold.begin_fold(Vector2(180, 636))
	for i in 10:
		fold.drag_to(Vector2(180, 636).lerp(Vector2(180, 420), (i + 1) / 10.0))
		await get_tree().process_frame
	await _wait(0.2)
	await _shot(dir + "/21_keep_slam_aim.png")
	fold.release()
	await _wait(0.12)
	await _shot(dir + "/22_keep_slam_impact.png")
	await _wait(1.0)
	await _shot(dir + "/23_after.png")
	print("AUTOTEST ram crushes left=%d keep_hp=%d kills=%d" % [ram.crushes_to_kill, keep_hp, kills])
	get_tree().quit()


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = get_tree().root.get_final_transform() * (pos + _origin)
		Input.parse_input_event(e)
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
