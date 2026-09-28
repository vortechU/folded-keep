extends Control
## Parchment HUD. Gameplay state and requests pass exclusively through Events.

const PANEL := Color("#2A1D14")
const WAX := Color("#A8322D")
const WAX_LIT := Color("#C64B3D")
const WAX_DARK := Color("#75231F")
const GOLD := Color("#D9A43A")
const PAPER := Color("#EAD9B0")
const INK := Color("#3A2A1C")
const BLUE := Color("#5B7FC0")

var _keep_hp := 0
var _keep_max_hp := 0
var _ink := 0
var _wave := 0
var _total_waves := 0
var _phase := "build"
var _selected_kind := ""
var _buttons: Dictionary = {}
var _keep_label: Label
var _ink_label: Label
var _wave_label: Label
var _phase_label: Label
var _banner_panel: PanelContainer
var _banner_label: Label
var _banner_tween: Tween
var _costs: Dictionary = {"tower": 4, "wall": 3}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_costs = Waves.COSTS
	_keep_label = _label(Vector2(6, 2), Vector2(108, 18), 10)
	_ink_label = _label(Vector2(126, 2), Vector2(94, 18), 10)
	_wave_label = _label(Vector2(234, 2), Vector2(120, 18), 10)
	_keep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ink_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_label = _label(Vector2(0, 520), Vector2(360, 17), 9)
	_phase_label.add_theme_color_override("font_color", GOLD)
	_make_banner()
	# Keep the Keep (x 140-220, y 545-625) and the bottom edge clear: buttons sit in the
	# side bands only (0-140 and 220-360), never over the Keep's footprint.
	_buttons["tower"] = _seal("TOWER\n%d INK" % _costs.get("tower", 4), 38.0, func() -> void: _request_build("tower"))
	_buttons["wall"] = _seal("WALL\n%d INK" % _costs.get("wall", 3), 224.0, func() -> void: _request_build("wall"))
	_buttons["fight"] = _seal("FIGHT!", 296.0, func() -> void: Events.start_wave_requested.emit())
	Events.keep_hp_changed.connect(_on_keep_hp_changed)
	Events.ink_changed.connect(_on_ink_changed)
	Events.wave_changed.connect(_on_wave_changed)
	Events.phase_changed.connect(_on_phase_changed)
	Events.banner.connect(_show_banner)
	_refresh()


func _draw() -> void:
	# Dark wood rail keeps the top status readable over the parchment map. Kept <=22px
	# tall per the HUD layout rules and always input-transparent (root mouse_filter IGNORE).
	draw_rect(Rect2(0, 0, 360, 21), PANEL)
	draw_rect(Rect2(0, 20, 360, 1), GOLD)
	draw_line(Vector2(120, 3), Vector2(120, 17), GOLD.darkened(0.38), 1.0)
	draw_line(Vector2(228, 3), Vector2(228, 17), GOLD.darkened(0.38), 1.0)
	# The build bar only exists during the build phase, and even then it leaves the
	# Keep's footprint (x 140-220, y 545-625) uncovered so it's always visible/grabbable.
	if _phase == "build":
		draw_rect(Rect2(0, 548, 140, 92), PANEL)
		draw_rect(Rect2(220, 548, 140, 92), PANEL)
		draw_rect(Rect2(0, 548, 140, 2), GOLD)
		draw_rect(Rect2(220, 548, 140, 2), GOLD)


func _label(pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", PAPER)
	add_child(label)
	return label


func _make_banner() -> void:
	_banner_panel = PanelContainer.new()
	_banner_panel.position = Vector2(30, 264)
	_banner_panel.size = Vector2(300, 76)
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#EAD9B0", 0.96)
	style.border_color = INK
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	_banner_panel.add_theme_stylebox_override("panel", style)
	add_child(_banner_panel)
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label.add_theme_font_size_override("font_size", 18)
	_banner_label.add_theme_color_override("font_color", INK)
	_banner_panel.add_child(_banner_label)
	_banner_panel.visible = false


func _seal(caption: String, x: float, callback: Callable) -> Button:
	var button := Button.new()
	button.position = Vector2(x, 571)
	button.size = Vector2(64, 64)
	button.text = caption
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_color_override("font_disabled_color", Color("#B89A62"))
	button.add_theme_stylebox_override("hover", _seal_style(WAX_LIT, GOLD))
	button.add_theme_stylebox_override("pressed", _seal_style(WAX_DARK, PAPER))
	button.add_theme_stylebox_override("disabled", _seal_style(Color("#62443A"), Color("#876D4B")))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	add_child(button)
	return button


func _seal_style(fill: Color, ring: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = ring
	style.set_border_width_all(3)
	style.set_corner_radius_all(32)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 3
	return style


func _request_build(kind: String) -> void:
	_selected_kind = "" if _selected_kind == kind else kind
	Events.build_requested.emit(kind)
	_refresh()


func _on_keep_hp_changed(hp: int, max_hp: int) -> void:
	_keep_hp = hp
	_keep_max_hp = max_hp
	_refresh()


func _on_ink_changed(ink: int) -> void:
	_ink = ink
	if _selected_kind != "" and ink < int(_costs.get(_selected_kind, 0)):
		_selected_kind = ""
	_refresh()


func _on_wave_changed(wave: int, total: int) -> void:
	_wave = wave
	_total_waves = total
	_refresh()


func _on_phase_changed(phase: String) -> void:
	_phase = phase
	_selected_kind = ""
	queue_redraw()
	_refresh()


func _refresh() -> void:
	_keep_label.text = "KEEP %d/%d" % [_keep_hp, _keep_max_hp]
	_ink_label.text = "INK %d" % _ink
	_wave_label.text = "WAVE %d/%d" % [_wave, _total_waves]
	_phase_label.text = "STAMP A DEFENSE" if _phase == "build" else "FOLD AN EDGE TO STRIKE"
	_phase_label.visible = _phase == "build" or _phase == "wave"
	for kind in ["tower", "wall"]:
		var button: Button = _buttons[kind]
		button.visible = _phase == "build"
		button.disabled = _ink < int(_costs.get(kind, 0))
		button.add_theme_stylebox_override("normal", _seal_style(BLUE if _selected_kind == kind else WAX, PAPER if _selected_kind == kind else GOLD))
	_buttons["fight"].visible = _phase == "build"
	_buttons["fight"].add_theme_stylebox_override("normal", _seal_style(WAX, GOLD))


func _show_banner(message: String) -> void:
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	_banner_label.text = message
	_banner_panel.visible = true
	_banner_panel.modulate.a = 1.0
	if message.contains("\n"):
		return
	_banner_tween = create_tween()
	_banner_tween.tween_interval(1.4)
	_banner_tween.tween_property(_banner_panel, "modulate:a", 0.0, 0.35)
	_banner_tween.tween_callback(func() -> void: _banner_panel.visible = false)
