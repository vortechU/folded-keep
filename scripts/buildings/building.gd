class_name Building
extends Node2D
## A structure inked on the map. Heavy buildings crush whatever a fold slams them onto.
## Placeholder art is drawn in _draw() until the real sprites land.

@export var kind := "tower"
@export var heavy := true
@export var size := Vector2(22, 22)
@export var max_hp := 0 ## 0 = indestructible

signal destroyed(building: Building)

var hp := 0


func _ready() -> void:
	add_to_group("building")
	hp = max_hp


func contains_point(p: Vector2) -> bool:
	return Rect2(-size * 0.5, size).has_point((p - position).rotated(-rotation))


func damage(amount: int) -> void:
	if max_hp <= 0 or hp <= 0:
		return
	hp -= amount
	queue_redraw()
	scale = Vector2(1.15, 0.85)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)
	if hp <= 0:
		remove_from_group("building")
		destroyed.emit(self)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)


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
			if max_hp > 0:
				for i in max_hp - hp:
					var x := -h.x + 4.0 + i * (size.x - 8.0) / max_hp
					draw_line(Vector2(x, -h.y + 1), Vector2(x + 2, h.y - 1), Palette.PARCHMENT, 1.0)
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
