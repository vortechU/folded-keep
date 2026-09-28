extends Node2D
## v0.1 prototype driver: sets up the board, spawns enemies along the roads, handles juice.
## Run with `-- --autotest=<dir>` to play a scripted fold and save screenshots there.

const UnitScript := preload("res://scripts/units/unit.gd")
const BuildingScript := preload("res://scripts/buildings/building.gd")

const SPAWN_INTERVAL := 1.6

@onready var map_viewport: SubViewport = $MapViewport
@onready var paper: Paper = $MapViewport/World/Paper
@onready var units: Node2D = $MapViewport/World/Units
@onready var buildings: Node2D = $MapViewport/World/Buildings
@onready var board: Node2D = $Board
@onready var display: Sprite2D = $Board/MapDisplay
@onready var fold: FoldController = $Board/FoldController
@onready var hud: Label = $UI/Hud

var keep_hp := 10
var kills := 0
var spawning := true
var _spawn_timer := 0.0
var _shake := 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	display.texture = map_viewport.get_texture()
	fold.setup(display)
	fold.slammed.connect(_on_slammed)
	_place_buildings()
	for x in [150.0, 210.0]:
		var k := _spawn_unit(Unit.Team.ALLY, Vector2(x, 530))
		k.path = PackedVector2Array([k.position])
	_update_hud()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			_autotest(arg.trim_prefix("--autotest="))


func _place_buildings() -> void:
	_add_building("keep", Paper.KEEP_POS + Vector2(0, 10), Vector2(56, 40))
	for p in [Vector2(45, 250), Vector2(45, 420), Vector2(315, 230), Vector2(315, 400)]:
		_add_building("tower", p, Vector2(22, 22))
	_add_building("wall", Vector2(180, 110), Vector2(40, 10))


func _add_building(kind: String, pos: Vector2, size: Vector2) -> void:
	var b: Building = BuildingScript.new()
	b.kind = kind
	b.size = size
	b.position = pos
	buildings.add_child(b)


func _spawn_unit(team: int, pos: Vector2) -> Unit:
	var u: Unit = UnitScript.new()
	u.team = team
	u.position = pos
	units.add_child(u)
	u.died.connect(_on_unit_died)
	u.reached_keep.connect(_on_reached_keep)
	return u


func _spawn_enemy_on_road() -> Unit:
	var road: PackedVector2Array = paper.roads.pick_random()
	var u := _spawn_unit(Unit.Team.ENEMY, road[0])
	u.path = road
	u.path_index = 1
	u.speed = randf_range(13.0, 19.0)
	return u


func _process(delta: float) -> void:
	if spawning:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_INTERVAL
			_spawn_enemy_on_road()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 40.0)
		board.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		board.position = board.position.round()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _on_slammed(_m: Vector2, _n: Vector2, outcomes: Array) -> void:
	var crushes := outcomes.filter(func(e): return e.outcome == FoldController.Outcome.CRUSH).size()
	_shake = 4.0 + crushes * 1.5
	# hit-stop: freeze for a heartbeat so the slam lands
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.07 + 0.02 * mini(crushes, 4), true, false, true).timeout
	Engine.time_scale = 1.0


func _on_unit_died(u: Unit) -> void:
	if u.team == Unit.Team.ENEMY:
		kills += 1
	_update_hud()


func _on_reached_keep(_u: Unit) -> void:
	keep_hp = maxi(0, keep_hp - 1)
	_shake = 3.0
	_update_hud()


func _update_hud() -> void:
	hud.text = "KEEP %d   CRUSHED %d\ndrag any map edge to fold" % [keep_hp, kills]


# --- scripted test -------------------------------------------------------------------

func _autotest(dir: String) -> void:
	spawning = false
	for u in get_tree().get_nodes_in_group("enemy"):
		u.queue_free()
	var demo := [Vector2(125, 250), Vector2(132, 262), Vector2(130, 310), Vector2(50, 380), Vector2(240, 300)]
	for p in demo:
		var u := _spawn_enemy_on_road()
		u.position = p
		u.speed = 0.0
	await _wait(0.3)
	await _shot(dir + "/01_idle.png")
	fold.begin_fold(Vector2(4, 330))
	for i in 10:
		fold.drag_to(Vector2(4, 330).lerp(Vector2(170, 322), (i + 1) / 10.0))
		await get_tree().process_frame
	await _wait(0.2)
	await _shot(dir + "/02_drag.png")
	fold.release()
	await _wait(0.1)
	await _shot(dir + "/03_slam.png")
	await _wait(0.9)
	await _shot(dir + "/04_after.png")
	# corner fold
	fold.begin_fold(Vector2(356, 4))
	for i in 10:
		fold.drag_to(Vector2(356, 4).lerp(Vector2(200, 200), (i + 1) / 10.0))
		await get_tree().process_frame
	await _wait(0.2)
	await _shot(dir + "/05_corner_drag.png")
	fold.release()
	await _wait(0.8)
	# real input path: window coords (540x960 window) must map to map coords (360x640)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(3, 480)
	Input.parse_input_event(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(255, 480)
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await get_tree().process_frame
	print("AUTOTEST input grab=%s pointer=%s (expect ~(0,320) / ~(170,320))" % [fold.grab, fold.pointer])
	print("AUTOTEST kills=%d" % kills)
	get_tree().quit()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
