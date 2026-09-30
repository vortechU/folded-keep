extends Control
## First-wave fold hint. Drawn above the map, but never intercepts pointer input.

const Style := preload("res://scripts/ui/ui_style.gd")

const REVEAL_DELAY := 1.5
const PAPER := Color("#EAD9B0")
const INK := Color("#3A2A1C")
const WAX := Color("#A8322D")
const GOLD := Color("#D9A43A")
## Empty paper left of the roads and above the Keep (x 140-220, y 545-625), off every road.
const PANEL_RECT := Rect2(32, 440, 248, 70)
const HAND_START := Vector2(350, 310)
const HAND_END := Vector2(240, 310)

## Survives reload_current_scene(): once a fold (or the timeout) has taught the player, a
## restart must not nag again.
static var _done := false

var _wave := 0
var _elapsed := 0.0
var _active := false
var _pressed := false
var _title: Label
var _detail: Label
var _guide: Dictionary = {}
var _celebrating := false
var _inspecting := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _make_label("Your towers are the hammer", Vector2(PANEL_RECT.position.x + 8, PANEL_RECT.position.y + 4), 13, INK)
	_detail = _make_label("Drag an edge to land a tower\non a red invader.", Vector2(PANEL_RECT.position.x + 8, PANEL_RECT.position.y + 29), 12, INK)
	_detail.size.y = 38
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Events.wave_changed.connect(_on_wave_changed)
	Events.phase_changed.connect(_on_phase_changed)
	Events.fold_lesson_changed.connect(_on_guide_changed)
	Events.tower_crush_landed.connect(_on_tower_crush)
	Events.map_inspection_changed.connect(func(active: bool) -> void:
		_inspecting = active
		if active:
			visible = false)
	visible = false
	set_process(false)


func _make_label(caption: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(PANEL_RECT.size.x - 16, 24)
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	if font_size == 13:
		label.add_theme_font_override("font", Style.TITLE_FONT)
		label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _on_wave_changed(wave: int, _total: int) -> void:
	_wave = wave


func _on_phase_changed(phase: String) -> void:
	if phase == "wave" and _wave == 1 and not _done:
		_active = true
		_elapsed = 0.0
		set_process(true)
	else:
		_hide()


func _on_guide_changed(guide: Dictionary) -> void:
	_guide = guide
	if not _active or _celebrating:
		return
	_title.text = "Release to crush!" if guide.get("ready", false) else "Your towers are the hammer"
	_detail.text = "The red X marks a crushing hit." if guide.get("ready", false) else "Aim the folded tower at an invader.\nLook for a red X, then release."
	queue_redraw()


func _on_tower_crush() -> void:
	if not _active:
		return
	_done = true
	_celebrating = true
	_elapsed = 0.0
	_title.text = "That's a tower crush!"
	_detail.text = "A guard drops in to hold the road."


func _input(event: InputEvent) -> void:
	# Watch (never consume) the pointer so the hint steps aside while the player drags.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed


func _hide() -> void:
	_active = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	if _celebrating and _elapsed >= 2.6:
		_hide()
		return
	visible = not _inspecting and (_celebrating or _elapsed >= REVEAL_DELAY)
	_title.visible = visible
	_detail.visible = visible
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	Style.sheet(self, PANEL_RECT)
	if _celebrating or _pressed or _guide.get("dragging", false):
		return
	if not _guide.get("has_target", false):
		return
	var start: Vector2 = _guide.get("grab", HAND_START)
	var finish: Vector2 = _guide.get("pointer", HAND_END)
	var tower: Vector2 = _guide.tower
	var enemy: Vector2 = _guide.enemy
	draw_arc(tower, 19.0, 0.0, TAU, 32, Style.BLUE, 2.0, true)
	draw_arc(enemy, 16.0, 0.0, TAU, 32, WAX, 2.0, true)
	# The hand starts on the right edge and traces a fold inward.
	draw_dashed_line(start, finish, Color(WAX, 0.65), 2.0, 7.0)
	var direction := (finish - start).normalized()
	draw_line(finish - direction.rotated(0.55) * 12.0, finish, WAX, 2.0)
	draw_line(finish - direction.rotated(-0.55) * 12.0, finish, WAX, 2.0)
	draw_arc(start, 12.0, 0.0, TAU, 20, Color(GOLD, 0.85), 2.0)
	var cycle := fposmod(_elapsed - REVEAL_DELAY, 2.8)
	var progress := 1.0 - pow(1.0 - clampf((cycle - 0.35) / 1.55, 0.0, 1.0), 3.0)
	var alpha := 1.0 - clampf((cycle - 2.15) / 0.45, 0.0, 1.0)
	_draw_hand(start.lerp(finish, progress), alpha)


func _draw_hand(at: Vector2, alpha: float) -> void:
	# Pointing hand, fingertip at `at`. All outlines first, then all fills, so the joins stay clean.
	var outline := Color(INK, alpha)
	var fill := Color("#FFF6DC", alpha)
	draw_circle(at, 6.0, Color(GOLD, 0.5 * alpha)) # touch point
	for pass_index in 2:
		var grow := 3.0 if pass_index == 0 else 0.0
		var col := outline if pass_index == 0 else fill
		draw_line(at + Vector2(1, 0), at + Vector2(16, 0), col, 8.0 + grow, true) # index finger
		draw_circle(at + Vector2(22, 5), 11.0 + grow * 0.5, col) # palm
		draw_circle(at + Vector2(16, 12), 4.5 + grow * 0.5, col) # curled fingers
		draw_circle(at + Vector2(23, 15), 4.5 + grow * 0.5, col)
		draw_line(at + Vector2(30, 8), at + Vector2(38, 8), col, 12.0 + grow, true) # cuff
