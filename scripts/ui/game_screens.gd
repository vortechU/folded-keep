extends Control
## Main, pause, and end screens. Gameplay requests go through Events.

const PAPER := Color("#EAD9B0")
const PAPER_SHADE := Color("#D8C08A")
const INK := Color("#3A2A1C")
const SEPIA := Color("#6E4B2A")
const GOLD := Color("#D9A43A")
const WAX := Color("#A8322D")
const WAX_LIT := Color("#C64B3D")
const WAX_DARK := Color("#75231F")

## Survives reload_current_scene() (the script instance is new, but the class stays
## loaded), so a restart can skip straight back into play instead of re-showing the menu.
static var _skip_menu_on_ready := false

var _screen := "menu"
var _wave := 1
var _total_waves := 7
var _keep_hp := 10
var _keep_max_hp := 10
var _pause_button: Button
var _title: Label
var _subtitle: Label
var _body: Label
var _primary: Button
var _secondary: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_button = _button("PAUSE", Vector2(272, 34), Vector2(54, 30), 10)
	_pause_button.pressed.connect(_pause_game)
	_title = _label(Vector2(42, 174), Vector2(276, 82), 32)
	_subtitle = _label(Vector2(48, 265), Vector2(264, 36), 12)
	_body = _label(Vector2(48, 324), Vector2(264, 86), 13)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_primary = _button("PLAY", Vector2(88, 436), Vector2(184, 52), 18)
	_primary.pressed.connect(_on_primary_pressed)
	_secondary = _button("", Vector2(106, 499), Vector2(148, 36), 12)
	_secondary.pressed.connect(_restart_game)
	Events.phase_changed.connect(_on_phase_changed)
	Events.wave_changed.connect(func(wave: int, total: int) -> void:
		_wave = wave
		_total_waves = total
	)
	Events.keep_hp_changed.connect(func(hp: int, max_hp: int) -> void:
		_keep_hp = hp
		_keep_max_hp = max_hp
	)
	# The gameplay capture path must enter play without a pointer press.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			_set_screen("")
			return
	if _skip_menu_on_ready:
		# Reloaded after a restart request: go straight back into play instead of
		# showing the menu again, which reads as broken after a fresh Keep HP reset.
		_skip_menu_on_ready = false
		_set_screen("")
		get_tree().paused = false
		return
	_set_screen("menu")
	get_tree().paused = true


func _draw() -> void:
	if _screen == "":
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(360, 640)), Color(0.12, 0.07, 0.04, 0.74))
	draw_rect(Rect2(23, 119, 314, 429), INK)
	draw_rect(Rect2(27, 123, 306, 421), PAPER)
	draw_rect(Rect2(32, 128, 296, 411), PAPER_SHADE, false, 1.0)
	draw_rect(Rect2(42, 144, 276, 4), WAX)
	draw_line(Vector2(50, 311), Vector2(310, 311), SEPIA, 1.0)
	draw_circle(Vector2(180, 311), 4.0, GOLD)
	# Simple battlements make the menu feel printed in the same ink as the map.
	for i in 7:
		var x := 144.0 + float(i) * 12.0
		draw_rect(Rect2(x, 155, 8, 7), SEPIA)
	draw_rect(Rect2(144, 161, 80, 12), SEPIA)
	draw_rect(Rect2(154, 172, 60, 3), GOLD)


func _label(pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	add_child(label)
	return label


func _button(caption: String, pos: Vector2, button_size: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = button_size
	button.text = caption
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_stylebox_override("normal", _button_style(WAX, GOLD))
	button.add_theme_stylebox_override("hover", _button_style(WAX_LIT, PAPER))
	button.add_theme_stylebox_override("pressed", _button_style(WAX_DARK, GOLD))
	button.add_theme_stylebox_override("focus", _button_style(WAX_LIT, PAPER))
	add_child(button)
	return button


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 3
	return style


func _set_screen(screen: String) -> void:
	_screen = screen
	var showing_panel := screen != ""
	mouse_filter = Control.MOUSE_FILTER_STOP if showing_panel else Control.MOUSE_FILTER_IGNORE
	_pause_button.visible = not showing_panel
	_title.visible = showing_panel
	_subtitle.visible = showing_panel
	_body.visible = showing_panel
	_primary.visible = showing_panel
	_secondary.visible = screen == "pause"
	match screen:
		"menu":
			_title.text = "FOLDED\nKEEP"
			_subtitle.text = "DEFEND THE CASTLE ON THE MAP"
			_body.text = "Drag a paper edge inward, then release to strike.\nStamp defenses between waves."
			_primary.text = "PLAY"
		"pause":
			_title.text = "PAUSED"
			_subtitle.text = "THE MAP CAN WAIT"
			_body.text = "Take a breath. Your Keep will be here when you return."
			_primary.text = "RESUME"
			_secondary.text = "START OVER"
		"victory":
			_title.text = "VICTORY!"
			_subtitle.text = "THE KEEP STILL STANDS"
			_body.text = "All %d waves repelled.\nKeep strength: %d/%d" % [_total_waves, _keep_hp, _keep_max_hp]
			_primary.text = "PLAY AGAIN"
		"defeat":
			_title.text = "DEFEAT"
			_subtitle.text = "THE KEEP HAS FALLEN"
			_body.text = "Reached wave %d of %d.\nThe map is ready for another try." % [_wave, _total_waves]
			_primary.text = "TRY AGAIN"
	queue_redraw()


func _on_phase_changed(phase: String) -> void:
	if phase == "victory" or phase == "defeat":
		_set_screen(phase)
		get_tree().paused = true


func _pause_game() -> void:
	_set_screen("pause")
	get_tree().paused = true


func _on_primary_pressed() -> void:
	if _screen == "menu" or _screen == "pause":
		_set_screen("")
		get_tree().paused = false
	else:
		_restart_game()


func _restart_game() -> void:
	_skip_menu_on_ready = true
	get_tree().paused = false
	Events.restart_requested.emit()
