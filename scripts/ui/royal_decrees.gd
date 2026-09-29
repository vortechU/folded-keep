extends Control
## The King's three choices and the small record of decrees kept this run.

const PAPER := Color("#EAD9B0")
const PAPER_SHADE := Color("#D8C08A")
const INK := Color("#3A2A1C")
const SEPIA := Color("#6E4B2A")
const GOLD := Color("#D9A43A")
const WAX := Color("#A8322D")

var _phase := "build"
var _offered: Array[String] = []
var _cards: Array[Button] = []
var _seals: Array[Button] = []
var _title: Label
var _prompt: Label
var _hint: Label
var _detail: Label
var _detail_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _label("THE KING DECREES", 22, INK)
	_prompt = _label("CHOOSE ONE ROYAL EDICT", 11, SEPIA)
	_hint = _label("Tap a card to bind it to this run", 11, INK)
	_detail = _label("", 11, INK)
	add_child(_title)
	add_child(_prompt)
	add_child(_hint)
	add_child(_detail)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.visible = false
	for index in 3:
		var card := Button.new()
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("normal", _card_style(PAPER, SEPIA))
		card.add_theme_stylebox_override("hover", _card_style(Color("#F5E5C0"), GOLD))
		card.add_theme_stylebox_override("pressed", _card_style(PAPER_SHADE, WAX))
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		card.pressed.connect(_choose.bind(index))
		add_child(card)
		var name_label := _label("", 17, INK)
		name_label.name = "Name"
		name_label.position = Vector2(17, 10)
		name_label.size = Vector2(252, 27)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_child(name_label)
		var text_label := _label("", 12, SEPIA)
		text_label.name = "Description"
		text_label.position = Vector2(17, 37)
		text_label.size = Vector2(252, 50)
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		card.add_child(text_label)
		_cards.append(card)
	Events.decree_offered.connect(_on_decree_offered)
	Events.phase_changed.connect(_on_phase_changed)
	resized.connect(_layout)
	_layout()
	_refresh_offer()
	_refresh_seals()


func _draw() -> void:
	if _detail.visible and _offered.is_empty():
		var detail_box := Rect2(size.x * 0.5 - 151, 55, 302, 52)
		draw_rect(detail_box, INK)
		draw_rect(detail_box.grow(-2), PAPER)
	if _offered.is_empty():
		return
	var center_x := size.x * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.06, 0.035, 0.76))
	draw_rect(Rect2(center_x - 162, 46, 324, 516), INK)
	draw_rect(Rect2(center_x - 158, 50, 316, 508), PAPER_SHADE)
	draw_rect(Rect2(center_x - 152, 56, 304, 496), SEPIA, false, 1.0)
	draw_line(Vector2(center_x - 128, 151), Vector2(center_x + 128, 151), SEPIA, 1.0)
	draw_circle(Vector2(center_x, 82), 25, GOLD)
	draw_circle(Vector2(center_x, 82), 21, WAX)
	# A tiny stamped crown, drawn in ink so no external icon is required.
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 12, 87), Vector2(center_x - 12, 76),
		Vector2(center_x - 6, 81), Vector2(center_x, 71),
		Vector2(center_x + 6, 81), Vector2(center_x + 12, 76),
		Vector2(center_x + 12, 87)]), PAPER)
	draw_line(Vector2(center_x - 11, 90), Vector2(center_x + 11, 90), PAPER, 2.0)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style


func _seal_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(11)
	return style


func _layout() -> void:
	var center_x := size.x * 0.5
	_title.position = Vector2(center_x - 145, 109)
	_title.size = Vector2(290, 35)
	_prompt.position = Vector2(center_x - 145, 158)
	_prompt.size = Vector2(290, 24)
	_hint.position = Vector2(center_x - 145, 526)
	_hint.size = Vector2(290, 21)
	for index in _cards.size():
		_cards[index].position = Vector2(center_x - 145, 190 + index * 108)
		_cards[index].size = Vector2(290, 96)
	_layout_seals()


func _layout_seals() -> void:
	var count := _seals.size()
	var start_x := size.x * 0.5 - float(count * 25 - 3) * 0.5
	for index in count:
		_seals[index].position = Vector2(start_x + index * 25, 28)
	_detail.position = Vector2(size.x * 0.5 - 145, 57)
	_detail.size = Vector2(290, 48)


func _on_decree_offered(ids: Array) -> void:
	_offered.clear()
	for value in ids:
		var id := String(value)
		if Decrees.LIST.has(id) and not _offered.has(id) and _offered.size() < 3:
			_offered.append(id)
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
			(card.get_node("Name") as Label).text = String(data.get("name", _offered[index]))
			(card.get_node("Description") as Label).text = String(data.get("text", ""))
	for seal in _seals:
		seal.visible = not showing and _phase == "build"
	_detail.visible = not showing and _phase == "build" and _detail_id != ""
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
	if phase != "build":
		_detail_id = ""
		_detail.visible = false
	else:
		_refresh_seals()
	_refresh_offer()


func _refresh_seals() -> void:
	for seal in _seals:
		seal.queue_free()
	_seals.clear()
	for id in Decrees.active:
		if not Decrees.LIST.has(id):
			continue
		var data: Dictionary = Decrees.LIST[id]
		var seal := Button.new()
		seal.text = String(data.get("name", "?")).left(1).to_upper()
		seal.size = Vector2(22, 22)
		seal.mouse_filter = Control.MOUSE_FILTER_STOP
		seal.focus_mode = Control.FOCUS_NONE
		seal.add_theme_font_size_override("font_size", 10)
		seal.add_theme_color_override("font_color", PAPER)
		seal.add_theme_color_override("font_hover_color", PAPER)
		seal.add_theme_stylebox_override("normal", _seal_style(WAX, GOLD))
		seal.add_theme_stylebox_override("hover", _seal_style(Color("#C64B3D"), PAPER))
		seal.add_theme_stylebox_override("pressed", _seal_style(Color("#75231F"), GOLD))
		seal.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		seal.mouse_entered.connect(_show_detail.bind(id))
		seal.mouse_exited.connect(_hide_detail.bind(id))
		seal.pressed.connect(_show_detail.bind(id))
		add_child(seal)
		_seals.append(seal)
	_layout_seals()
	_refresh_offer()


func _show_detail(id: String) -> void:
	_detail_id = id
	var data: Dictionary = Decrees.LIST[id]
	_detail.text = "%s — %s" % [data.get("name", id), data.get("text", "")]
	_detail.visible = _phase == "build" and _offered.is_empty()
	queue_redraw()


func _hide_detail(id: String) -> void:
	if _detail_id == id:
		_detail_id = ""
		_detail.visible = false
		queue_redraw()


