extends Node2D
## Game driver: build phase → wave → build phase … → victory / defeat. Juice on slams.
## Run with `-- --autotest=<dir>` to play a scripted fold + build and save screenshots there.

const UnitScript := preload("res://scripts/units/unit.gd")
const BuildingScript := preload("res://scripts/buildings/building.gd")

enum Phase { BUILD, WAVE, OVER }
## The map is rendered at this multiple of its 360x640 logical size, so painted art stays sharp.
## Gameplay coordinates are unaffected.
const RENDER_SCALE := 2

@onready var map_viewport: SubViewport = $MapViewport
@onready var paper: Paper = $MapViewport/World/Paper
@onready var units: Node2D = $MapViewport/World/Units
@onready var buildings: Node2D = $MapViewport/World/Buildings
@onready var board: Node2D = $Board
@onready var display: Sprite2D = $Board/MapDisplay
@onready var fold: FoldController = $Board/FoldController
@onready var build: BuildController = $Board/BuildController

var phase := Phase.BUILD
var wave := 0 # waves completed / index of next wave
var keep_hp := Waves.KEEP_MAX_HP
var ink := Waves.START_INK
var kills := 0

var _queue: Array[String] = []
var _spawn_timer := 0.0
var _shake := 0.0
var _autotest := false


func _ready() -> void:
	Engine.time_scale = 1.0
	map_viewport.size = Vector2i(Paper.SIZE * RENDER_SCALE)
	$MapViewport/World.scale = Vector2.ONE * RENDER_SCALE
	display.scale = Vector2.ONE / RENDER_SCALE
	display.texture = map_viewport.get_texture()
	fold.setup(display)
	fold.slammed.connect(_on_slammed)
	build.paper = paper
	build.place_requested.connect(_on_place_requested)
	build.disarmed.connect(func(): fold.enabled = true)
	Events.build_requested.connect(_on_build_requested)
	Events.start_wave_requested.connect(_start_wave)
	Events.restart_requested.connect(func(): get_tree().reload_current_scene())

	_add_building("keep", Paper.KEEP_POS + Vector2(0, 10), Vector2(76, 44))
	_add_building("tower", Vector2(45, 250), Vector2(22, 22))
	_add_building("tower", Vector2(315, 400), Vector2(22, 22))

	Events.ink_changed.emit(ink)
	Events.keep_hp_changed.emit(keep_hp, Waves.KEEP_MAX_HP)
	Events.wave_changed.emit(wave + 1, Waves.LIST.size())
	_enter_build()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			_run_autotest(arg.trim_prefix("--autotest="))


# --- phases ---------------------------------------------------------------------------

func _enter_build() -> void:
	phase = Phase.BUILD
	_fill_squads()
	Events.phase_changed.emit("build")
	Events.banner.emit("BUILD, THEN FIGHT!" if wave == 0 else "WAVE CLEARED")


func _start_wave() -> void:
	if phase != Phase.BUILD:
		return
	build.disarm()
	phase = Phase.WAVE
	_queue = Waves.queue_for(wave)
	_spawn_timer = 0.5
	Events.wave_changed.emit(wave + 1, Waves.LIST.size())
	Events.phase_changed.emit("wave")
	Events.banner.emit("FINAL WAVE" if Waves.LIST[wave].get("boss", false) else "WAVE %d" % (wave + 1))


func _check_wave_end() -> void:
	if phase != Phase.WAVE or not _queue.is_empty():
		return
	if get_tree().get_nodes_in_group("enemy").any(func(u): return u.is_alive()):
		return
	wave += 1
	if wave >= Waves.LIST.size():
		_game_over(true)
		return
	_set_ink(ink + Waves.WAVE_BONUS_INK)
	Events.wave_changed.emit(wave + 1, Waves.LIST.size())
	_enter_build()


func _game_over(won: bool) -> void:
	phase = Phase.OVER
	build.disarm()
	Events.phase_changed.emit("victory" if won else "defeat")
	Events.banner.emit(("VICTORY!" if won else "THE KEEP HAS FALLEN") + "\ntap to play again")


# --- building -------------------------------------------------------------------------

func _on_build_requested(kind: String) -> void:
	if phase != Phase.BUILD or ink < Waves.COSTS[kind]:
		return
	if build.armed == kind:
		build.disarm()
		return
	fold.enabled = false
	build.arm(kind)


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
	var b: Building = BuildingScript.new()
	b.kind = kind
	b.size = size
	b.position = pos
	if kind == "wall":
		b.max_hp = 6
	elif kind == "barracks":
		b.heavy = false
	buildings.add_child(b)
	return b


# --- units ----------------------------------------------------------------------------

func _spawn_enemy(kind: String) -> Unit:
	var road: PackedVector2Array = paper.roads.pick_random()
	var u: Unit = UnitScript.new()
	u.team = Unit.Team.ENEMY
	u.setup(kind)
	u.position = road[0]
	u.path = road
	u.path_index = 1
	units.add_child(u)
	u.died.connect(_on_unit_died)
	u.reached_keep.connect(_on_reached_keep)
	if kind == "ram":
		Events.boss_spawned.emit()
		Events.banner.emit("THE SIEGE RAM!")
	return u


## Each barracks keeps its squad of knights topped up during waves.
func _update_barracks(delta: float) -> void:
	for b in get_tree().get_nodes_in_group("building"):
		if b.kind != "barracks":
			continue
		b.squad = b.squad.filter(func(k): return is_instance_valid(k) and k.is_alive())
		if b.squad.size() >= Waves.SQUAD_SIZE:
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
			while b.squad.size() < Waves.SQUAD_SIZE:
				b.squad.append(_spawn_knight(b))
			b.spawn_cd = Waves.KNIGHT_RESPAWN
			b.queue_redraw()


func _spawn_knight(b: Building) -> Unit:
	var k: Unit = UnitScript.new()
	k.team = Unit.Team.ALLY
	k.setup("knight")
	k.position = b.position + Vector2(0, b.size.y * 0.5 + 2)
	# Guard the nearest road, a few steps apart from squadmates.
	var road := paper.closest_road(b.position)
	k.post = road.point + road.dir * (b.squad.size() * 14.0 - 7.0)
	k.died.connect(_on_unit_died)
	units.add_child(k)
	var fx := Fx.of(self)
	if fx:
		fx.dust_ring(k.position, 6.0, 5)
	return k


func _on_unit_died(u: Unit) -> void:
	if u.team == Unit.Team.ENEMY:
		kills += 1
		_set_ink(ink + Waves.REWARDS.get(u.kind, 1))
	Events.unit_crushed.emit(u)
	_check_wave_end.call_deferred()


func _on_reached_keep(u: Unit) -> void:
	keep_hp = maxi(0, keep_hp - Waves.KEEP_DAMAGE.get(u.kind, 1))
	_shake = 5.0
	Events.keep_hit.emit()
	Events.keep_hp_changed.emit(keep_hp, Waves.KEEP_MAX_HP)
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


# --- frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.WAVE and not _queue.is_empty() and not _autotest:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = Waves.LIST[wave].interval
			_spawn_enemy(_queue.pop_front())
	if phase == Phase.WAVE:
		_update_barracks(delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 40.0)
		board.position = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake).round()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
	elif phase == Phase.OVER and event is InputEventMouseButton and event.pressed:
		Events.restart_requested.emit()


func _on_slammed(m: Vector2, n: Vector2, outcomes: Array) -> void:
	var crushes := outcomes.filter(func(e): return e.outcome == FoldController.Outcome.CRUSH).size()
	Events.slammed.emit(crushes)
	_shake = 4.0 + crushes * 1.5
	if _is_keep_slam(m, n):
		_shake += 6.0
		Events.keep_slammed.emit()
		Events.banner.emit("KEEP SLAM!")
		if keep_hp > 1 and phase == Phase.WAVE:
			keep_hp = maxi(1, keep_hp - Waves.KEEP_SLAM_COST)
			Events.keep_hp_changed.emit(keep_hp, Waves.KEEP_MAX_HP)
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
		e.position = get_tree().root.get_final_transform() * pos
		Input.parse_input_event(e)
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
