extends StyleBox
## A hand-inked plate for buttons and panels: paper-grain fill, raised lip, double ink rule and
## gold corner studs. Drawn as vectors so it stays crisp at any window scale.

const GRAIN := preload("res://assets/sprites/ui/paper_grain.png")
const TILE := 128.0

var fill := Color("f3e7ca")
var border := Color("6e4b2a")
var trim := Color("b1873c")
## Depth of the raised lip below the plate; a pressed plate sinks by this much.
var lift := 2.0
var sunk := false
var studs := true
## 1 = full paper grain; lower values keep large sheets calm.
var grain := 1.0
var _margin_y := 4.0


func _init(margin_x: float = 10.0, margin_y: float = 4.0) -> void:
	_margin_y = margin_y
	content_margin_left = margin_x
	content_margin_right = margin_x
	set_depth(lift, false)


## Keeps text centred on the face: the face sits at the top of the rect until pressed.
func set_depth(depth: float, pressed: bool) -> void:
	lift = depth
	sunk = pressed
	content_margin_top = _margin_y + (depth if pressed else 0.0)
	content_margin_bottom = _margin_y + (0.0 if pressed else depth)


func _draw(ci: RID, rect: Rect2) -> void:
	var face := Rect2(rect.position, rect.size - Vector2(0, lift))
	if sunk:
		face.position.y += lift
	elif lift > 0.0:
		# the lip: a darker edge under the face, then a soft cast shadow
		RenderingServer.canvas_item_add_rect(ci, Rect2(rect.position + Vector2(1, lift + 1), rect.size - Vector2(1, lift)), Color(0.12, 0.07, 0.03, 0.22))
		RenderingServer.canvas_item_add_rect(ci, Rect2(rect.position + Vector2(0, lift), rect.size - Vector2(0, lift)), border.darkened(0.25))
	if grain < 1.0:
		RenderingServer.canvas_item_add_rect(ci, face, fill)
	_grain(ci, face, Color(fill, grain))
	# aged edges: the paper darkens toward its border
	for i in 3:
		_frame(ci, face.grow(-1.0 - i), Color(border, 0.16 - i * 0.05), 1.0)
	RenderingServer.canvas_item_add_line(ci, face.position + Vector2(2, 1.5), Vector2(face.end.x - 2, face.position.y + 1.5), Color(1, 1, 1, 0.32 if not sunk else 0.1), 1.0)
	_frame(ci, face.grow(-0.75), border, 1.5)
	if face.size.y >= 26.0:
		var inner := face.grow(-3.5)
		_frame(ci, inner, Color(trim, 0.85), 1.0)
		if studs:
			for corner in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
				_stud(ci, corner)


func _grain(ci: RID, r: Rect2, tint: Color) -> void:
	var rid := GRAIN.get_rid()
	# offset per plate so neighbouring buttons don't share an identical grain
	var offset := Vector2(fposmod(r.position.x * 1.7, TILE), fposmod(r.position.y * 2.3, TILE))
	var y := r.position.y
	var sy := offset.y
	while y < r.end.y - 0.01:
		var h := minf(TILE - sy, r.end.y - y)
		var x := r.position.x
		var sx := offset.x
		while x < r.end.x - 0.01:
			var w := minf(TILE - sx, r.end.x - x)
			RenderingServer.canvas_item_add_texture_rect_region(ci, Rect2(x, y, w, h), rid, Rect2(sx, sy, w, h), tint)
			x += w
			sx = 0.0
		y += h
		sy = 0.0


func _frame(ci: RID, r: Rect2, color: Color, width: float) -> void:
	var points := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	RenderingServer.canvas_item_add_polyline(ci, points, PackedColorArray([color]), width, true)


func _stud(ci: RID, c: Vector2) -> void:
	var s := 2.6
	var diamond := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	RenderingServer.canvas_item_add_polygon(ci, diamond, PackedColorArray([trim.lightened(0.15)]))
	diamond.append(diamond[0])
	RenderingServer.canvas_item_add_polyline(ci, diamond, PackedColorArray([border]), 0.8, true)
