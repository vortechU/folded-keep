extends Control
## Main, pause, and end screens. Gameplay requests go through Events.

const Style := preload("res://scripts/ui/ui_style.gd")
const Accessibility := preload("res://scripts/ui/accessibility_settings.gd")
const KEEP_ART := preload("res://assets/sprites/buildings/keep.png")
const GuideScript := preload("res://scripts/ui/field_guide.gd")
const ReportScript := preload("res://scripts/ui/battle_report.gd")

## Survives reload_current_scene() (the script instance is new, but the class stays
## loaded), so a restart can skip straight back into play instead of re-showing the menu.
static var _skip_menu_on_ready := false

var _screen := "menu"
var _decree_open := false
var _wave := 1
var _total_waves := 12
var _keep_hp := 10
var _keep_max_hp := 10
var _pause_button: Button
var _title: Label
var _subtitle: Label
var _body: Label
var _primary: Button
var _secondary: Button
var _settings_header: Label
var _large_text_button: Button
var _contrast_button: Button
var _sound_button: Button
var _help_button: Button
var _guide: Control
var _report: Control
var _report_data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_button = _button("PAUSE", Vector2(272, 32), Vector2(56, 40), 11)
	_pause_button.pressed.connect(_pause_game)
	_title = _label(Vector2(42, 195), Vector2(276, 103), 42)
	_title.add_theme_constant_override("line_spacing", -8)
	_subtitle = _label(Vector2(48, 303), Vector2(264, 26), 11)
	_body = _label(Vector2(52, 352), Vector2(256, 76), 14)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_primary = _button("PLAY", Vector2(52, 448), Vector2(256, 48), 22)
	Style.button(_primary, true)
	_primary.add_theme_font_override("font", Style.TITLE_FONT)
	_primary.add_theme_font_size_override("font_size", 22)
	_primary.pressed.connect(_on_primary_pressed)
	_secondary = _button("", Vector2(88, 508), Vector2(184, 40), 13)
	_secondary.pressed.connect(_restart_game)
	_settings_header = _label(Vector2(52, 232), Vector2(256, 30), 18)
	_settings_header.text = "Accessibility"
	_large_text_button = _button("", Vector2(52, 270), Vector2(256, 42), 14)
	_large_text_button.pressed.connect(_toggle_large_text)
	_contrast_button = _button("", Vector2(52, 320), Vector2(256, 42), 14)
	_contrast_button.pressed.connect(_toggle_outlines)
	_sound_button = _button("", Vector2(52, 370), Vector2(256, 42), 14)
	_sound_button.pressed.connect(_cycle_sound)
	_help_button = _button("Field guide", Vector2(52, 422), Vector2(256, 40), 14)
	_help_button.pressed.connect(func() -> void:
		Audio.play_sfx("ui_click")
		_guide.open())
	_report = ReportScript.new()
	_report.position = Vector2(52, 250)
	_report.size = Vector2(256, 238)
	add_child(_report)
	_guide = GuideScript.new()
	add_child(_guide)
	Events.battle_report_ready.connect(func(report: Dictionary) -> void:
		_report_data = report
		_report.show_report(report))
	Events.phase_changed.connect(_on_phase_changed)
	Events.decree_offered.connect(func(_ids: Array) -> void:
		_decree_open = true
		_pause_button.hide())
	Events.decree_chosen.connect(func(_id: String) -> void:
		_decree_open = false
		_pause_button.visible = _screen == "")
	Events.duel_started.connect(func(_boss: String) -> void: _pause_button.hide())
	Events.duel_finished.connect(func(_won: bool) -> void: _pause_button.visible = _screen == "")
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
	draw_rect(Rect2(0, 0, 360, 640), Color(0.16, 0.11, 0.07, 1.0))
	Style.sheet(self, Rect2(24, 62, 312, 514))
	if _screen == "menu":
		draw_texture_rect(KEEP_ART, Rect2(127, 86, 106, 110), false)
		Style.rule(self, 341, 52, 308)
	elif _screen == "victory" or _screen == "defeat":
		draw_texture_rect(KEEP_ART, Rect2(153, 82, 54, 56), false)
		Style.rule(self, 241, 52, 308)
	Style.rule(self, 558, 124, 236)


func _label(pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Style.label("", Rect2(pos, label_size), font_size, Style.INK, font_size >= 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func _button(caption: String, pos: Vector2, button_size: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = button_size
	button.text = caption
	Style.button(button)
	button.add_theme_font_size_override("font_size", font_size)
	add_child(button)
	return button


func _set_screen(screen: String) -> void:
	_screen = screen
	var showing_panel := screen != ""
	mouse_filter = Control.MOUSE_FILTER_STOP if showing_panel else Control.MOUSE_FILTER_IGNORE
	_pause_button.visible = not showing_panel and not _decree_open
	_title.visible = showing_panel
	_subtitle.visible = showing_panel
	_body.visible = screen == "menu"
	_report.visible = screen == "victory" or screen == "defeat"
	_help_button.visible = screen == "menu" or screen == "pause"
	_guide.hide()
	_primary.visible = showing_panel
	_secondary.visible = screen == "pause"
	for control in [_settings_header, _large_text_button, _contrast_button, _sound_button]:
		control.visible = screen == "pause"
	_title.position = Vector2(42, 120) if screen == "pause" else Vector2(42, 195)
	_title.size = Vector2(276, 70) if screen == "pause" else Vector2(276, 103)
	_subtitle.position = Vector2(48, 191) if screen == "pause" else Vector2(48, 303)
	_primary.position = Vector2(52, 476) if screen == "pause" else Vector2(52, 448)
	_secondary.position = Vector2(52, 530) if screen == "pause" else Vector2(88, 508)
	_secondary.size = Vector2(256, 40) if screen == "pause" else Vector2(184, 40)
	_help_button.position = Vector2(52, 422) if screen == "pause" else Vector2(52, 506)
	if _report.visible:
		_title.position = Vector2(42, 146)
		_title.size = Vector2(276, 62)
		_subtitle.position = Vector2(48, 210)
		_primary.position = Vector2(52, 506)
	var title_size := 42
	match screen:
		"menu":
			_title.text = "Folded\nKeep"
			_subtitle.text = "DEFEND THE CASTLE ON THE MAP"
			_body.text = "Drag an edge. Fold the map.\nRelease to crush the invaders.\nBuild your defenses between waves."
			_primary.text = "Defend the Keep"
		"pause":
			_title.text = "Rest a while"
			title_size = 34
			_subtitle.text = "THE MAP CAN WAIT"
			_primary.text = "Return to battle"
			_secondary.text = "START OVER"
		"victory":
			_title.text = "Victory"
			title_size = 44
			_subtitle.text = "ROYAL BATTLE REPORT · ALL %d WAVES" % _total_waves
			_body.text = "All %d waves repelled.\nKeep strength: %d/%d" % [_total_waves, _keep_hp, _keep_max_hp]
			_primary.text = "Defend it again"
		"defeat":
			_title.text = "The Keep falls"
			title_size = 33
			_subtitle.text = "ROYAL BATTLE REPORT · WAVE %d/%d" % [_wave, _total_waves]
			_body.text = "Reached wave %d of %d.\nThe map is ready for another try." % [_wave, _total_waves]
			_primary.text = "Try again"
	_title.set_meta(Accessibility.BASE_FONT_META, title_size)
	_refresh_settings_labels()
	Accessibility.apply_to(self)
	queue_redraw()


func _refresh_settings_labels() -> void:
	_large_text_button.text = "Larger text: %s" % ("ON" if Accessibility.large_text else "OFF")
	_contrast_button.text = "Strong text outlines: %s" % ("ON" if Accessibility.strong_outlines else "OFF")
	_sound_button.text = "Sound: %s" % Accessibility.SOUND_LABELS[Accessibility.sound_level]


func _toggle_large_text() -> void:
	Accessibility.large_text = not Accessibility.large_text
	Accessibility.save_settings()
	Accessibility.apply_to(get_parent())
	_refresh_settings_labels()
	Audio.play_sfx("ui_click")


func _toggle_outlines() -> void:
	Accessibility.strong_outlines = not Accessibility.strong_outlines
	Accessibility.save_settings()
	Accessibility.apply_to(get_parent())
	_refresh_settings_labels()
	Audio.play_sfx("ui_click")


func _cycle_sound() -> void:
	Accessibility.sound_level = (Accessibility.sound_level + 1) % Accessibility.SOUND_LEVELS.size()
	Accessibility.apply_sound()
	Accessibility.save_settings()
	_refresh_settings_labels()
	Audio.play_sfx("ui_click")


func _on_phase_changed(phase: String) -> void:
	if phase == "victory" or phase == "defeat":
		_set_screen(phase)
		get_tree().paused = true


func _pause_game() -> void:
	Audio.play_sfx("ui_click")
	_set_screen("pause")
	get_tree().paused = true


func _on_primary_pressed() -> void:
	if _screen == "menu" or _screen == "pause":
		Audio.play_sfx("ui_click")
		_set_screen("")
		get_tree().paused = false
	else:
		_restart_game()


func _restart_game() -> void:
	_skip_menu_on_ready = true
	get_tree().paused = false
	Events.restart_requested.emit()
