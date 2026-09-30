extends Control
## Generated comic pages, read at the player's pace while gameplay stays paused.
signal finished

const Style := preload("res://scripts/ui/ui_style.gd")
const Accessibility := preload("res://scripts/ui/accessibility_settings.gd")
const PAGE_PATHS := [
	"res://assets/sprites/ui/intro/comic_page_1.png",
	"res://assets/sprites/ui/intro/comic_page_2.png",
	"res://assets/sprites/ui/intro/comic_page_3.png",
]
const PAGE_SIZE := Vector2(312, 468)
const ZOOM := 1.65

var page := 0
var _counter: Label
var _next: Button
var _back: Button
var _skip: Button
var _zoom_button: Button
var _picture: TextureRect
var _pages: Array[Texture2D] = []
var _press_position := Vector2.ZERO
var _last_position := Vector2.ZERO
var _pressed := false
var _zoomed := false
var _pan := Vector2.ZERO
var _return_to_menu := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(360, 640)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for path in PAGE_PATHS:
		_pages.append(load(path) as Texture2D)
	_counter = Style.label("", Rect2(60, 523, 240, 24), 13)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_counter)
	_back = _button("Back", Rect2(24, 12, 68, 36), false)
	_back.pressed.connect(func() -> void: show_page(page - 1))
	_skip = _button("Skip", Rect2(266, 12, 70, 36), false)
	_skip.pressed.connect(_finish)
	_zoom_button = _button("Read closer", Rect2(104, 12, 150, 36), false)
	_zoom_button.pressed.connect(_toggle_zoom)
	_next = _button("", Rect2(46, 553, 268, 48), true)
	_next.pressed.connect(advance)
	var pane := Control.new()
	pane.position = Vector2(24, 56)
	pane.size = PAGE_SIZE
	pane.clip_contents = true
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pane)
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pane.add_child(_picture)
	hide()


func _button(words: String, rect: Rect2, primary: bool) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = words
	Style.button(button, primary)
	button.add_theme_font_size_override("font_size", 20 if primary else 15)
	add_child(button)
	return button


func open(return_to_menu: bool = false) -> void:
	_return_to_menu = return_to_menu
	_pressed = false
	_skip.text = "Close" if return_to_menu else "Skip"
	_zoomed = Accessibility.large_text
	show_page(0, false)
	show()


func show_page(index: int, sound: bool = true) -> void:
	page = clampi(index, 0, _pages.size() - 1)
	_pressed = false
	_picture.texture = _pages[page]
	_counter.text = "Page %d of %d%s" % [page + 1, _pages.size(), " · Drag to read" if _zoomed else ""]
	_back.disabled = page == 0
	_next.text = "Turn the page" if page < 2 else ("Back to menu" if _return_to_menu else "Defend the Keep")
	_reset_picture()
	Accessibility.apply_to(self)
	if sound:
		Audio.play_sfx("paper_grab")


func _reset_picture() -> void:
	_picture.size = PAGE_SIZE * (ZOOM if _zoomed else 1.0)
	_pan = Vector2((PAGE_SIZE.x - _picture.size.x) * 0.5, 0)
	_picture.position = _pan
	_zoom_button.text = "Full page" if _zoomed else "Read closer"


func _toggle_zoom() -> void:
	_zoomed = not _zoomed
	show_page(page, false)
	Audio.play_sfx("ui_click")


func advance() -> void:
	if not visible:
		return
	if page < _pages.size() - 1:
		show_page(page + 1)
	else:
		_finish()


func _finish() -> void:
	if not visible:
		return
	_pressed = false
	hide()
	Audio.play_sfx("ui_click")
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	# Advance on release; the menu's opening click cannot also turn the first page.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
			_last_position = event.position
			_pressed = true
		elif _pressed:
			_pressed = false
			if not _zoomed and event.position.distance_to(_press_position) < 20.0:
				advance()
		accept_event()
	elif event is InputEventMouseMotion and _pressed and _zoomed:
		_pan = (_pan + event.position - _last_position).clamp(PAGE_SIZE - _picture.size, Vector2.ZERO)
		_last_position = event.position
		_picture.position = _pan
		accept_event()


func _draw() -> void:
	Style.grain(self, Rect2(Vector2.ZERO, size), Style.PAPER)
	Style.rule(self, 611, 120, 240)
