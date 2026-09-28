extends Control
## PLACEHOLDER HUD, built in code so gameplay is testable. Helper agent replaces this with the
## real wax-seal HUD (TASKS.md #8). It talks to gameplay ONLY through the Events autoload.

var _top: Label
var _banner: Label
var _bar: HBoxContainer
var _buttons := {}
var _ink := 0
var _phase := "build"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_top = _label(Vector2(8, 4), Vector2(344, 16), 10)
	_banner = _label(Vector2(0, 280), Vector2(360, 40), 20)
	_banner.add_theme_color_override("font_outline_color", Palette.PARCHMENT)
	_banner.add_theme_constant_override("outline_size", 4)

	_bar = HBoxContainer.new()
	_bar.position = Vector2(8, 606)
	_bar.size = Vector2(344, 28)
	_bar.add_theme_constant_override("separation", 4)
	add_child(_bar)
	for kind in ["tower", "wall"]:
		_buttons[kind] = _button("%s %d" % [kind.to_upper(), Waves.COSTS[kind]], func(): Events.build_requested.emit(kind))
	_buttons["fight"] = _button("FIGHT!", func(): Events.start_wave_requested.emit())

	Events.ink_changed.connect(func(v): _ink = v; _refresh())
	Events.keep_hp_changed.connect(func(hp, mx): set_meta("hp", "%d/%d" % [hp, mx]); _refresh())
	Events.wave_changed.connect(func(w, t): set_meta("wave", "%d/%d" % [w, t]); _refresh())
	Events.phase_changed.connect(_on_phase)
	Events.banner.connect(_show_banner)


func _label(pos: Vector2, sz: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Palette.INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(cb)
	_bar.add_child(b)
	return b


func _on_phase(phase: String) -> void:
	_phase = phase
	_bar.visible = phase == "build"
	_refresh()


func _refresh() -> void:
	_top.text = "WAVE %s    KEEP %s    INK %d" % [get_meta("wave", "-"), get_meta("hp", "-"), _ink]
	for kind in ["tower", "wall"]:
		_buttons[kind].disabled = _ink < Waves.COSTS[kind]


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4 if not text.contains("\n") else 999.0)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
