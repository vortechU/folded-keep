extends Control
## Brief, input-transparent field note when a new enemy first appears.

const Style := preload("res://scripts/ui/ui_style.gd")

const INK := Color("#3A2A1C")
const SEPIA := Color("#6E4B2A")
const PAPER := Color("#EAD9B0")
const WAX := Color("#A8322D")

const INTRO := {
	"pinner": {"name": "PIN-BEARER", "tip": "Nails a corner of the map. You can't fold near him until he's gone."},
	"flyer": {"name": "CROW RIDER", "tip": "Immune to crushes and slaps. One flip or two Archer Tower arrows kill it."},
	"imp": {"name": "INK IMP", "tip": "Gnaws the paper. If it finishes, the map tears."},
}

var _queue: Array[String] = []
var _current := ""
var _name_label: Label
var _tip_label: Label
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = _label(17, WAX)
	_tip_label = _label(12, INK)
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_name_label)
	add_child(_tip_label)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 3.0
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(_next)
	add_child(_timer)
	Events.enemy_introduced.connect(_on_enemy_introduced)
	resized.connect(_layout)
	_layout()
	_refresh()


func _draw() -> void:
	if _current == "":
		return
	Style.sheet(self, Rect2(32, 84, 296, 98))


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	if font_size >= 17:
		label.add_theme_font_override("font", Style.TITLE_FONT)
		label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", color)
	return label


func _layout() -> void:
	var left := size.x * 0.5 - 125
	_name_label.position = Vector2(left, 94)
	_name_label.size = Vector2(250, 29)
	_tip_label.position = Vector2(left, 128)
	_tip_label.size = Vector2(250, 49)


func _on_enemy_introduced(kind: String) -> void:
	if not INTRO.has(kind) or kind == _current or _queue.has(kind):
		return
	_queue.append(kind)
	if _current == "":
		_next()


func _next() -> void:
	_timer.stop()
	_current = _queue.pop_front() if not _queue.is_empty() else ""
	_refresh()
	if _current != "":
		_timer.start()


func _refresh() -> void:
	var showing := _current != ""
	_name_label.visible = showing
	_tip_label.visible = showing
	if showing:
		var data: Dictionary = INTRO[_current]
		_name_label.text = String(data["name"])
		_tip_label.text = String(data["tip"])
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _current == "" or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		_next()
