extends Control
## First-wave fold hint. Drawn above the map, but never intercepts pointer input.

const DURATION := 20.0
const REVEAL_DELAY := 1.5
const PAPER := Color("#EAD9B0")
const INK := Color("#3A2A1C")
const WAX := Color("#A8322D")
const GOLD := Color("#D9A43A")
## Empty paper left of the roads and above the Keep (x 140-220, y 545-625), off every road.
const PANEL_RECT := Rect2(8, 440, 132, 50)
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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _make_label("DRAG AN EDGE IN", Vector2(PANEL_RECT.position.x, PANEL_RECT.position.y + 5), 13, INK)
	_detail = _make_label("Let go to slam it down", Vector2(PANEL_RECT.position.x, PANEL_RECT.position.y + 27), 10, INK)
	Events.wave_changed.connect(_on_wave_changed)
	Events.phase_changed.connect(_on_phase_changed)
	Events.slammed.connect(_on_slammed)
	visible = false
	set_process(false)


func _make_label(caption: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(PANEL_RECT.size.x, 20)
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
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


func _on_slammed(_crushes: int) -> void:
	if _active:
		_done = true
		_hide()


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
	if _elapsed >= DURATION:
		_done = true
		_hide()
		return
	visible = _elapsed >= REVEAL_DELAY and not _pressed
	_title.visible = visible
	_detail.visible = visible
	if visible:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	draw_rect(PANEL_RECT, Color(PAPER, 0.94))
	draw_rect(PANEL_RECT, INK, false, 1.5)
	draw_line(PANEL_RECT.position + Vector2(10, 25), PANEL_RECT.end - Vector2(10, 25), GOLD, 1.0)
	# The hand starts on the right edge and traces a fold inward.
	draw_dashed_line(HAND_START, HAND_END, Color(WAX, 0.75), 2.0, 7.0)
	draw_line(HAND_END + Vector2(12, -8), HAND_END, WAX, 2.0)
	draw_line(HAND_END + Vector2(12, 8), HAND_END, WAX, 2.0)
	draw_arc(HAND_START, 12.0, 0.0, TAU, 20, Color(GOLD, 0.85), 2.0)
	var cycle := fposmod(_elapsed - REVEAL_DELAY, 2.8)
	var progress := 1.0 - pow(1.0 - clampf((cycle - 0.35) / 1.55, 0.0, 1.0), 3.0)
	var alpha := 1.0 - clampf((cycle - 2.15) / 0.45, 0.0, 1.0)
	_draw_hand(HAND_START.lerp(HAND_END, progress), alpha)


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
