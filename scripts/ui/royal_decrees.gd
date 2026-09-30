extends Control
## Royal edicts: three choices, plus an expandable run ledger during preparation.
const Style := preload("res://scripts/ui/ui_style.gd")
var _phase := "build"
var _offered: Array[String] = []
var _cards: Array[Button] = []
var _title: Label
var _prompt: Label
var _hint: Label
var _ledger_button: Button
var _ledger: PanelContainer
var _entries: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = Style.label("The King decrees", Rect2(40, 100, 280, 42), 32, Style.INK, true)
	_prompt = Style.label("Choose one blessing for this campaign.", Rect2(40, 149, 280, 30), 12, Style.SEPIA)
	_hint = Style.label("Your chosen decree lasts for the entire run.", Rect2(40, 531, 280, 26), 11, Style.SEPIA)
	for label in [_title, _prompt, _hint]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
	for index in 3:
		var card := Button.new()
		card.position = Vector2(40, 194 + index * 110)
		card.size = Vector2(280, 100)
		Style.button(card)
		card.pressed.connect(_choose.bind(index))
		add_child(card)
		var title := Style.label("", Rect2(16, 10, 248, 28), 22, Style.BLUE, true)
		title.name = "Name"
		card.add_child(title)
		var detail := Style.label("", Rect2(16, 41, 246, 51), 12)
		detail.name = "Description"
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		card.add_child(detail)
		_cards.append(card)
	_ledger_button = Button.new()
	_ledger_button.position = Vector2(32, 32)
	_ledger_button.size = Vector2(102, 40)
	Style.button(_ledger_button)
	_ledger_button.pressed.connect(func() -> void:
		_ledger.visible = not _ledger.visible
		Audio.play_sfx("ui_click"))
	add_child(_ledger_button)
	_ledger = PanelContainer.new()
	_ledger.position = Vector2(32, 80)
	_ledger.size = Vector2(296, 354)
	_ledger.add_theme_stylebox_override("panel", Style.box(Style.PAPER, Style.SEPIA))
	add_child(_ledger)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ledger.add_child(scroll)
	var scrollbar := scroll.get_v_scroll_bar()
	scrollbar.add_theme_stylebox_override("scroll", Style.box(Style.SHADE, Style.SHADE, 0))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(state, Style.box(Style.SEPIA, Style.SEPIA, 0))
	_entries = VBoxContainer.new()
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_theme_constant_override("separation", 10)
	scroll.add_child(_entries)
	_ledger.hide()
	Events.decree_offered.connect(_on_decree_offered)
	Events.phase_changed.connect(_on_phase_changed)
	_refresh_ledger()
	_refresh_offer()

func _draw() -> void:
	if _offered.is_empty():
		return
	draw_rect(Rect2(0, 0, 360, 640), Color(0.16, 0.11, 0.07, 1.0))
	Style.sheet(self, Rect2(24, 62, 312, 514))
	Style.rule(self, 184, 48, 312)
	# The decree is stamped with a small red wax seal.
	draw_circle(Vector2(180, 81), 11, Style.RED)
	draw_arc(Vector2(180, 81), 8, 0, TAU, 24, Style.SHADE, 1.0, true)

func _on_decree_offered(ids: Array) -> void:
	_offered.clear()
	for value in ids:
		var id := String(value)
		if Decrees.LIST.has(id) and not _offered.has(id) and _offered.size() < 3:
			_offered.append(id)
	_ledger.hide()
	_refresh_offer()

func _refresh_offer() -> void:
	var showing := not _offered.is_empty()
	mouse_filter = Control.MOUSE_FILTER_STOP if showing else Control.MOUSE_FILTER_IGNORE
	_title.visible = showing
	_prompt.visible = showing
	_hint.visible = showing
	for index in _cards.size():
		var card := _cards[index]
		card.visible = index < _offered.size()
		if card.visible:
			var data: Dictionary = Decrees.LIST[_offered[index]]
			(card.get_node("Name") as Label).text = data.name
			(card.get_node("Description") as Label).text = data.text
	_ledger_button.visible = not showing and _phase == "build" and not Decrees.active.is_empty()
	if not _ledger_button.visible:
		_ledger.hide()
	queue_redraw()

func _choose(index: int) -> void:
	if index >= _offered.size():
		return
	var id := _offered[index]
	_offered.clear()
	_refresh_offer()
	Events.decree_chosen.emit(id)

func _on_phase_changed(phase: String) -> void:
	_phase = phase
	_ledger.hide()
	if phase == "build":
		_refresh_ledger()
	_refresh_offer()

func _refresh_ledger() -> void:
	for child in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	_ledger_button.text = "Decrees · %d" % Decrees.active.size()
	for id in Decrees.active:
		if not Decrees.LIST.has(id):
			continue
		var data: Dictionary = Decrees.LIST[id]
		var title := Style.label(data.name, Rect2(), 21, Style.BLUE, true)
		_entries.add_child(title)
		var detail := Style.label(data.text, Rect2(), 12)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_entries.add_child(detail)
		var line := HSeparator.new()
		var separator := StyleBoxLine.new()
		separator.color = Style.GOLD
		separator.thickness = 1
		line.add_theme_stylebox_override("separator", separator)
		_entries.add_child(line)
