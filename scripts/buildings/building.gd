class_name Building
extends Node2D
## A structure inked on the map. Heavy buildings crush whatever a fold slams them onto.
## Placeholder art is drawn in _draw() until the real sprites land.

@export var kind := "tower"
@export var heavy := true
@export var size := Vector2(22, 22)


func _ready() -> void:
	add_to_group("building")


func contains_point(p: Vector2) -> bool:
	return Rect2(position - size * 0.5, size).has_point(p)


func _draw() -> void:
	var h := size * 0.5
	draw_rect(Rect2(-h + Vector2(2, 3), size), Color(0, 0, 0, 0.12))
	match kind:
		"keep":
			_block(Rect2(-h, size))
			for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(-h.x, h.y), Vector2(h.x, h.y)]:
				draw_circle(c, 8.0, Palette.INK)
				draw_circle(c, 6.5, Palette.BLUE_LIGHT)
			draw_rect(Rect2(-6, h.y - 12, 12, 12), Palette.INK)
			draw_line(Vector2(0, -h.y), Vector2(0, -h.y - 14), Palette.INK, 1.0)
			draw_rect(Rect2(1, -h.y - 14, 8, 5), Palette.BLUE)
		"wall":
			_block(Rect2(-h, size))
		_:
			draw_circle(Vector2.ZERO, h.x, Palette.INK)
			draw_circle(Vector2.ZERO, h.x - 1.5, Palette.BLUE)
			draw_circle(Vector2.ZERO, h.x - 5.0, Palette.BLUE_LIGHT)
			draw_line(Vector2(0, 0), Vector2(0, -h.y - 8), Palette.INK, 1.0)
			draw_rect(Rect2(1, -h.y - 8, 6, 4), Palette.RED_LIGHT if kind == "barracks" else Palette.BLUE)


func _block(r: Rect2) -> void:
	draw_rect(r, Palette.INK)
	draw_rect(r.grow(-1.5), Palette.BLUE)
	var x := r.position.x
	while x < r.end.x - 3.0:
		draw_rect(Rect2(x, r.position.y - 3.0, 4, 4), Palette.INK)
		x += 7.0
