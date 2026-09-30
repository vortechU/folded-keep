extends Control
## Campaign HUD. State and gameplay requests pass exclusively through Events.
const Style := preload("res://scripts/ui/ui_style.gd")
const Accessibility := preload("res://scripts/ui/accessibility_settings.gd")
const ScreensScene := preload("res://scenes/ui/game_screens.tscn")
const DecreeScene := preload("res://scenes/ui/royal_decrees.tscn")
const EnemyIntroScene := preload("res://scenes/ui/enemy_intro.tscn")
const TutorialScript := preload("res://scripts/ui/fold_tutorial.gd")
const HELP := {
	"tower": "Stamp on open paper. Fold a tower onto enemies to crush them and drop a guard.",
	"barracks": "Stamp on open paper. Two knights hold enemies on the nearest road.",
	"wall": "Stamp across a road to block enemies. Fold the wall onto them to crush."
}
var _keep_hp := 0
var _keep_max_hp := 0
var _ink := 0
var _wave := 0
var _total_waves := 12
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
var _costs: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_costs = Waves.COSTS
	_keep_label = Style.label("", Rect2(10, 0, 112, 21), 11, Style.PAPER)
	_ink_label = Style.label("", Rect2(126, 0, 90, 21), 11, Style.PAPER)
	_wave_label = Style.label("", Rect2(230, 0, 120, 21), 11, Style.PAPER)
	_ink_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label in [_keep_label, _ink_label, _wave_label]:
		add_child(label)
	_phase_label = Style.label("", Rect2(40, 476, 280, 42), 12)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_phase_label)
	_make_banner()
	# Stamps sit in two side columns so the keep (x 138-222) stays visible between them.
	_buttons["tower"] = _build_button("Tower", "tower", Vector2(8, 526))
	_buttons["barracks"] = _build_button("Barracks", "barracks", Vector2(8, 564))
	_buttons["wall"] = _build_button("Wall", "wall", Vector2(226, 526))
	var fight := Button.new()
	fight.position = Vector2(226, 564)
	fight.size = Vector2(126, 72)
	fight.text = "To battle"
	Style.button(fight, true)
	fight.add_theme_font_override("font", Style.TITLE_FONT)
	fight.add_theme_font_size_override("font_size", 21)
	fight.pressed.connect(func() -> void: Events.start_wave_requested.emit())
	add_child(fight)
	_buttons["fight"] = fight
	Events.keep_hp_changed.connect(func(hp: int, maximum: int) -> void:
		_keep_hp = hp
		_keep_max_hp = maximum
		_refresh())
	Events.ink_changed.connect(func(ink: int) -> void:
		_ink = ink
		if _selected_kind != "" and ink < int(_costs.get(_selected_kind, 0)):
			_selected_kind = ""
		_refresh())
	Events.wave_changed.connect(func(wave: int, total: int) -> void:
		_wave = wave
		_total_waves = total
		_refresh())
	Events.phase_changed.connect(_on_phase_changed)
	Events.banner.connect(_show_banner)
	_refresh()
	add_child(TutorialScript.new())
	add_child(EnemyIntroScene.instantiate())
	add_child(DecreeScene.instantiate())
	# Menus cover the entire HUD, including decree details.
	add_child(ScreensScene.instantiate())
	call_deferred("_apply_accessibility")

func _apply_accessibility() -> void:
	Accessibility.apply_to(self)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 360, 22), Style.INK)
	draw_line(Vector2(0, 21), Vector2(360, 21), Style.GOLD)
	draw_line(Vector2(120, 5), Vector2(120, 16), Style.SEPIA)
	draw_line(Vector2(226, 5), Vector2(226, 16), Style.SEPIA)
	if _phase == "build":
		Style.box(Style.PAPER, Style.GOLD).draw(get_canvas_item(), Rect2(32, 474, 296, 46))

func _build_button(caption: String, kind: String, pos: Vector2) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = Vector2(126 if pos.x > 180 else 128, 34)
	Style.button(button)
	button.text = "%s   %d" % [caption, _costs[kind]]
	button.tooltip_text = "%s ink. %s" % [_costs[kind], HELP[kind]]
	button.icon = load("res://assets/sprites/buildings/%s.png" % kind) as Texture2D
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 25)
	button.add_theme_constant_override("h_separation", 4)
	button.pressed.connect(_request_build.bind(kind))
	add_child(button)
	return button

func _request_build(kind: String) -> void:
	_selected_kind = "" if _selected_kind == kind else kind
	Events.build_requested.emit(kind)
	_refresh()

func _on_phase_changed(phase: String) -> void:
	_phase = phase
	_selected_kind = ""
	if phase == "victory" or phase == "defeat":
		_banner_panel.hide()
	_refresh()

func _refresh() -> void:
	_keep_label.text = "KEEP  %d / %d" % [_keep_hp, _keep_max_hp]
	_keep_label.add_theme_color_override("font_color", Color("ffb9a0") if _keep_hp <= 3 else Style.PAPER)
	_ink_label.text = "INK  %d" % _ink
	_wave_label.text = "WAVE  %d / %d" % [_wave, _total_waves]
	_phase_label.text = HELP[_selected_kind] if _selected_kind != "" else "Prepare your defenses\nChoose a stamp · Costs shown in ink"
	_phase_label.visible = _phase == "build"
	for kind in ["tower", "barracks", "wall"]:
		var button: Button = _buttons[kind]
		button.visible = _phase == "build"
		button.disabled = _ink < int(_costs[kind])
		var selected: bool = _selected_kind == kind
		button.add_theme_stylebox_override("normal", Style.box(Style.BLUE if selected else Style.LIGHT, Style.INK))
		button.add_theme_color_override("font_color", Style.LIGHT if selected else Style.INK)
	_buttons["fight"].visible = _phase == "build"
	queue_redraw()

func _make_banner() -> void:
	_banner_panel = PanelContainer.new()
	_banner_panel.position = Vector2(44, 191)
	_banner_panel.size = Vector2(272, 54)
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.add_theme_stylebox_override("panel", Style.box(Style.PAPER, Style.SEPIA))
	add_child(_banner_panel)
	_banner_label = Style.label("", Rect2(), 21, Style.INK, true)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_panel.add_child(_banner_label)
	_banner_panel.hide()

func _show_banner(message: String) -> void:
	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()
	if _phase == "victory" or _phase == "defeat":
		return
	_banner_label.text = message
	_banner_panel.show()
	_banner_panel.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(2.2 if message.contains("\n") else 1.1)
	_banner_tween.tween_property(_banner_panel, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(_banner_panel.hide)
