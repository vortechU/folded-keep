extends Control
## A paused, one-pointer field guide. Scroll long pages without hiding the close button.
signal closed

const Style := preload("res://scripts/ui/ui_style.gd")
const Accessibility := preload("res://scripts/ui/accessibility_settings.gd")
const PAGES := [
	[
		["crush", "Crush", "Fold a tower, wall or Keep onto an invader. A red X previews the hit."],
		["slap", "Slap", "Blank paper stuns and knocks back. Runners die from a slap; brutes and bosses ignore it."],
		["flip", "Flip & fling", "Units on the flap move to the mirrored spot. A Crow Rider dies from one flip. Fling others off the page to kill them; bosses stay on."],
		["tear", "Mind the paper", "Three nearby crossing creases rip a hole. It swallows three units, then patches shut. Buildings on a rip are lost."],
	],
	[
		["tower", "Tower · 4 ink", "Attacks through folds. Each tower crush drops a temporary guard, up to two per tower."],
		["archer_tower", "Archer Tower · 6 ink", "Fires automatically at nearby Crow Riders. Two arrows kill one. This light tower cannot crush."],
		["wall", "Wall · 3 ink", "Stamp across a road to hold enemies in place. Walls are heavy enough to crush with a fold."],
		["barracks", "Barracks · 5 ink", "Knights pin enemies on the nearest road. Your folds hit friendly knights too."],
		["keep", "Keep Slam", "Fold the bottom edge up to use your castle as a hammer. Costs one Keep health during a wave, but never your last point."],
		["duel", "Duel of Champions", "Left attack: swipe right. Right attack: swipe left. Overhead: swipe up. Tap to strike after a correct read; fold the edge when stagger is full."],
	],
	[
		["enemy_grunt", "Grunt & Runner", "Crush either. Slap a grunt to stun it; a slap kills a runner."],
		["enemy_brute", "Brute", "Ignores slaps. Land a heavy building on it to crush it."],
		["enemy_pinner", "Pin-Bearer", "Nails a corner, blocking nearby grabs. Kill him with a crush or two slaps; flipping him pulls out his nail."],
		["enemy_flyer", "Crow Rider", "Flies over walls, knights, slaps and crushes. One flip, an off-map fling, or two Archer Tower arrows kill it."],
		["enemy_imp", "Ink Imp", "Gnaws holes near your buildings. Kill or flip it before the progress ring fills."],
		["boss_warlord", "Warlord & Siege Ram", "Warlord: two crushes. Ram: three. Duel wins defeat the Warlord or leave the Ram needing one crush. Neither can be flung off the page."],
	],
]

var _tabs: Array[Button] = []
var _scroll: ScrollContainer
var _entries: VBoxContainer
var _scroll_dragging := false
var _icons: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var title := Style.label("The Field Guide", Rect2(44, 75, 272, 45), 32, Style.INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	for i in 3:
		var tab := Button.new()
		tab.position = Vector2(44 + i * 92, 130)
		tab.size = Vector2(88, 38)
		tab.text = ["Folding", "Defense", "Enemies"][i]
		Style.button(tab)
		tab.pressed.connect(_show_page.bind(i))
		add_child(tab)
		_tabs.append(tab)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(44, 184)
	_scroll.size = Vector2(272, 316)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_entries = VBoxContainer.new()
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_theme_constant_override("separation", 18)
	_scroll.add_child(_entries)
	var back := Button.new()
	back.position = Vector2(52, 518)
	back.size = Vector2(256, 44)
	back.text = "Close guide"
	Style.button(back, true)
	back.pressed.connect(func() -> void:
		Audio.play_sfx("ui_click")
		hide()
		closed.emit())
	add_child(back)
	_show_page(0, false)
	hide()


func open() -> void:
	_scroll_dragging = false
	_show_page(0, false)
	Accessibility.apply_to(self)
	show()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_scroll_dragging = event.pressed and _scroll.get_global_rect().has_point(event.position)
	elif event is InputEventMouseMotion and _scroll_dragging:
		_scroll.scroll_vertical -= int(event.relative.y)
		get_viewport().set_input_as_handled()


func _show_page(index: int, sound: bool = true) -> void:
	if sound:
		Audio.play_sfx("ui_click")
	for i in _tabs.size():
		Style.button(_tabs[i], i == index)
	for child in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	for data in PAGES[index]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_entries.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(42, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key := String(data[0])
		if not _icons.has(key):
			var folder := "units" if key.begins_with("enemy_") or key == "boss_warlord" else "buildings"
			var path := "res://assets/sprites/%s/%s.png" % [folder, key]
			if ResourceLoader.exists(path):
				_icons[key] = load(path) as Texture2D
		icon.draw.connect(_draw_icon.bind(icon, key))
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 3)
		row.add_child(words)
		var heading := Style.label(data[1], Rect2(), 21, Style.INK, true)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(heading)
		var body := Style.label(data[2], Rect2(), 13)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(body)
	_scroll.scroll_vertical = 0
	Accessibility.apply_to(self)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 360, 640), Color("2a1d14"))
	Style.sheet(self, Rect2(24, 62, 312, 514))
	Style.rule(self, 174, 44, 316)


func _draw_icon(icon: Control, key: String) -> void:
	if _icons.has(key):
		var texture: Texture2D = _icons[key]
		var factor := minf(40.0 / texture.get_width(), 46.0 / texture.get_height())
		var extent := texture.get_size() * factor
		icon.draw_texture_rect(texture, Rect2((Vector2(42, 48) - extent) * 0.5, extent), false)
		return
	var center := Vector2(21, 24)
	match key:
		"crush":
			icon.draw_rect(Rect2(6, 5, 30, 36), Style.SHADE)
			icon.draw_line(center - Vector2(9, 9), center + Vector2(9, 9), Style.RED, 3.0, true)
			icon.draw_line(center + Vector2(-9, 9), center + Vector2(9, -9), Style.RED, 3.0, true)
		"slap":
			icon.draw_arc(center, 13, 0, TAU, 32, Style.SEPIA, 2.0, true)
			icon.draw_circle(center, 3, Style.SEPIA)
		"flip":
			icon.draw_dashed_line(Vector2(4, 32), Vector2(36, 14), Style.BLUE, 2.0, 4)
			icon.draw_line(Vector2(25, 14), Vector2(36, 14), Style.BLUE, 2.0)
			icon.draw_line(Vector2(33, 25), Vector2(36, 14), Style.BLUE, 2.0)
		"tear":
			icon.draw_colored_polygon(PackedVector2Array([Vector2(10, 10), Vector2(25, 16), Vector2(34, 8), Vector2(29, 28), Vector2(35, 37), Vector2(18, 32), Vector2(8, 40), Vector2(14, 23)]), Style.INK)
		"duel":
			icon.draw_line(Vector2(9, 39), Vector2(33, 9), Style.BLUE, 4, true)
			icon.draw_line(Vector2(9, 24), Vector2(24, 36), Style.SEPIA, 3, true)
