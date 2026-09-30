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

static func button(node: Button, primary: bool = false) -> void:
	var fill := RED if primary else LIGHT
	var foreground := LIGHT if primary else INK
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.add_theme_font_size_override("font_size", 13)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, foreground)
	node.add_theme_color_override("font_disabled_color", Color("8c7a5e"))
	node.add_theme_stylebox_override("normal", box(fill, SEPIA))
	node.add_theme_stylebox_override("hover", box(fill.lightened(0.08), BLUE))
	node.add_theme_stylebox_override("pressed", box(fill.darkened(0.1), INK))
	node.add_theme_stylebox_override("disabled", box(SHADE, Color("b7a078")))
	var focus := box(Color.TRANSPARENT, BLUE, 2)
	node.add_theme_stylebox_override("focus", focus)

static func sheet(canvas: CanvasItem, rect: Rect2) -> void:
	box(PAPER, SEPIA).draw(canvas.get_canvas_item(), rect)
	canvas.draw_rect(rect.grow(-5), GOLD, false, 1.0)
	for corner in [rect.position + Vector2(11, 11), Vector2(rect.end.x - 11, rect.position.y + 11), rect.end - Vector2(11, 11), Vector2(rect.position.x + 11, rect.end.y - 11)]:
		canvas.draw_line(corner - Vector2(3, 0), corner + Vector2(3, 0), SEPIA, 1.0)
		canvas.draw_line(corner - Vector2(0, 3), corner + Vector2(0, 3), SEPIA, 1.0)

static func rule(canvas: CanvasItem, y: float, left: float = 48, right: float = 312) -> void:
	canvas.draw_line(Vector2(left, y), Vector2(right, y), GOLD, 1.0)
	var x := (left + right) * 0.5
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x-3, y), Vector2(x, y-3), Vector2(x+3, y), Vector2(x, y+3)]), SEPIA)
