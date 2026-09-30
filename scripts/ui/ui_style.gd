extends RefCounted
## Shared materials and typography for the campaign's printed interface.
const Accessibility := preload("res://scripts/ui/accessibility_settings.gd")
const PAPER := Color("ead9b0")
const LIGHT := Color("f3e7ca")
const SHADE := Color("d8c08a")
const INK := Color("3a2a1c")
const SEPIA := Color("6e4b2a")
const GOLD := Color("b1873c")
const BLUE := Color("2f4f8f")
const RED := Color("a8322d")
const TITLE_FONT := preload("res://scripts/ui/fonts/im_fell_english.ttf")
const PlateStyle := preload("res://scripts/ui/plate_style.gd")

static func label(text: String, rect: Rect2, font_size: int, color: Color = INK, display: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if display:
		node.add_theme_font_override("font", TITLE_FONT)
	Accessibility.apply_to(node)
	return node

static func box(fill: Color, border: Color = GOLD, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func plate(fill: Color, border: Color = SEPIA, trim: Color = GOLD, depth: float = 2.0, pressed: bool = false) -> StyleBox:
	var style: StyleBox = PlateStyle.new()
	style.fill = fill
	style.border = border
	style.trim = trim
	style.set_depth(depth, pressed)
	return style

static func button(node: Button, primary: bool = false) -> void:
	var fill := RED if primary else LIGHT
	var edge := Color("4a1611") if primary else SEPIA
	var foreground := LIGHT if primary else INK
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.add_theme_font_override("font", TITLE_FONT)
	node.add_theme_font_size_override("font_size", 15)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, foreground)
	node.add_theme_color_override("font_disabled_color", Color("8c7a5e"))
	node.add_theme_stylebox_override("normal", plate(fill, edge))
	node.add_theme_stylebox_override("hover", plate(fill.lightened(0.07), edge, GOLD.lightened(0.3)))
	node.add_theme_stylebox_override("pressed", plate(fill.darkened(0.08), edge, GOLD, 2.0, true))
	node.add_theme_stylebox_override("disabled", plate(SHADE.lerp(PAPER, 0.35), Color("a58c63"), Color("c4a878"), 1.0))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## A build stamp that is currently armed: royal-blue plate, pressed into the bar.
static func select(node: Button, selected: bool) -> void:
	var fill := BLUE if selected else LIGHT
	var edge := INK if selected else SEPIA
	node.add_theme_stylebox_override("normal", plate(fill, edge, GOLD, 2.0, selected))
	node.add_theme_stylebox_override("hover", plate(fill.lightened(0.07), edge, GOLD.lightened(0.3), 2.0, selected))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, LIGHT if selected else INK)
	node.queue_redraw()

## Draws an inked symbol on a text-less button: "pause", "look" or "close".
static func glyph(node: Button, kind: String) -> void:
	if not node.has_meta("glyph"):
		node.draw.connect(func() -> void: _draw_glyph(node))
	node.set_meta("glyph", kind)
	node.queue_redraw()

## The ink cost of a build stamp, as a blot of ink on the right of the button.
static func cost_badge(node: Button, cost: int) -> void:
	node.set_meta("cost", cost)
	node.draw.connect(func() -> void: _draw_cost(node))

static func _face_center(node: Button) -> Vector2:
	# plates are raised 2 px; the face drops onto the lip while pressed
	var pressed := node.get_draw_mode() == BaseButton.DRAW_PRESSED or node.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED
	return Vector2(node.size.x * 0.5, (node.size.y - 2.0) * 0.5 + (2.0 if pressed else 0.0))

static func _draw_glyph(node: Button) -> void:
	var c := _face_center(node)
	var ink := node.get_theme_color("font_disabled_color" if node.disabled else "font_color")
	match String(node.get_meta("glyph", "")):
		"pause":
			for x in [-4.5, 1.5]:
				node.draw_rect(Rect2(c + Vector2(x, -7.5), Vector2(3.5, 15)), ink)
		"look":
			node.draw_arc(c + Vector2(-2, -2), 6.5, 0.0, TAU, 24, ink, 2.2, true)
			node.draw_line(c + Vector2(2.8, 2.8), c + Vector2(8, 8), ink, 3.2, true)
		"swords":
			var top := Vector2(c.x, 21.0 + (c.y - (node.size.y - 2.0) * 0.5))
			for side in [-1.0, 1.0]:
				_sword(node, top + Vector2(-9.0 * side, 8.0), top + Vector2(10.0 * side, -10.0))
		"close":
			node.draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), ink, 2.6, true)
			node.draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), ink, 2.6, true)

static func _sword(node: Button, hilt: Vector2, tip: Vector2) -> void:
	var dir := (tip - hilt).normalized()
	var across := Vector2(-dir.y, dir.x)
	var guard := hilt + dir * 3.5
	node.draw_line(guard, tip, Color("f6ecd2"), 2.4, true)
	node.draw_line(guard, tip - dir * 1.5, Color(INK, 0.35), 0.8, true)
	node.draw_line(guard - across * 4.5, guard + across * 4.5, GOLD.lightened(0.25), 2.2, true)
	node.draw_line(hilt, guard, Color("5a2a14"), 2.0, true)
	node.draw_circle(hilt - dir * 0.8, 1.7, GOLD.lightened(0.25))

static func _draw_cost(node: Button) -> void:
	var cost := int(node.get_meta("cost", 0))
	var c := Vector2(node.size.x - 19.0, _face_center(node).y)
	var blot := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		blot.append(c + Vector2(cos(a), sin(a)) * (9.6 + sin(a * 3.0 + cost) * 0.9 + sin(a * 5.0) * 0.5))
	var ink := INK if not node.disabled else Color(INK, 0.35)
	node.draw_colored_polygon(blot, ink)
	node.draw_circle(c + Vector2(6.5, 7.5), 1.6, ink) # a stray drop
	var font_size := 15
	# IM Fell's old-style figures sit low; lift them to the blot's centre
	var baseline := c.y + (TITLE_FONT.get_ascent(font_size) - TITLE_FONT.get_descent(font_size)) * 0.5 - 1.5
	node.draw_string(TITLE_FONT, Vector2(c.x - 10.0, baseline), str(cost), HORIZONTAL_ALIGNMENT_CENTER, 20.0, font_size, PAPER)

## Fills a rect with the paper grain tinted to `color` (leather bars, parchment panels).
static func grain(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var style: StyleBox = plate(color, color, color, 0.0)
	style.studs = false
	style.draw(canvas.get_canvas_item(), rect)

static func sheet(canvas: CanvasItem, rect: Rect2) -> void:
	var paper: StyleBox = plate(PAPER, SEPIA, GOLD, 3.0)
	paper.studs = false
	paper.grain = 0.55
	paper.draw(canvas.get_canvas_item(), rect)
	for corner in [rect.position + Vector2(11, 11), Vector2(rect.end.x - 11, rect.position.y + 11), rect.end - Vector2(11, 11), Vector2(rect.position.x + 11, rect.end.y - 11)]:
		canvas.draw_line(corner - Vector2(3, 0), corner + Vector2(3, 0), SEPIA, 1.0)
		canvas.draw_line(corner - Vector2(0, 3), corner + Vector2(0, 3), SEPIA, 1.0)

static func rule(canvas: CanvasItem, y: float, left: float = 48, right: float = 312) -> void:
	canvas.draw_line(Vector2(left, y), Vector2(right, y), GOLD, 1.0)
	var x := (left + right) * 0.5
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-3, y), Vector2(x, y-3), Vector2(x+3, y), Vector2(x, y+3)]), SEPIA)
