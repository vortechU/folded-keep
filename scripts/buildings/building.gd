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
## Barracks: its knights and the respawn timer (driven by main.gd).
var squad: Array[Node] = []
var spawn_cd := 0.0


func _ready() -> void:
	add_to_group("building")
	hp = max_hp
	_stamp()


## Buildings are stamped onto the map: drop in big, squash, settle.
func _stamp() -> void:
	scale = Vector2(1.45, 1.45)
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(self, "scale", Vector2(1.18, 0.82), 0.09).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "modulate:a", 1.0, 0.06)
	tw.chain().tween_callback(func():
		var fx := Fx.of(self)
		if fx:
			fx.dust_ring(position, maxf(size.x, size.y) * 0.6, 12 if kind == "keep" else 8))
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


## A quick squash, e.g. when the Keep is hit.
func jolt(squash: Vector2) -> void:
	scale = squash
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func contains_point(p: Vector2, margin := 0.0) -> bool:
	return Rect2(-size * 0.5, size).grow(margin).has_point((p - position).rotated(-rotation))


func damage(amount: int) -> void:
	if max_hp <= 0 or hp <= 0:
		return
	hp -= amount
	queue_redraw()
	scale = Vector2(1.15, 0.85)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)
	var fx := Fx.of(self)
	if fx:
		fx.droplets(position, Palette.BLUE, 2 + amount, 0.7)
		if hp <= 0:
			fx.dust(position, Vector2.ZERO, 12, size.x * 0.4)
			fx.droplets(position, Palette.INK, 10, 1.0)
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
		"barracks":
			# a long hall with a pitched roof and a banner
			draw_rect(Rect2(-h, size), Palette.INK)
			draw_rect(Rect2(-h + Vector2(1.5, 1.5), size - Vector2(3, 3)), Palette.PARCHMENT_MID)
			draw_colored_polygon(PackedVector2Array([Vector2(-h.x - 2, -h.y + 4), Vector2(0, -h.y - 7),
				Vector2(h.x + 2, -h.y + 4)]), Palette.INK)
			draw_colored_polygon(PackedVector2Array([Vector2(-h.x + 1, -h.y + 3), Vector2(0, -h.y - 5),
				Vector2(h.x - 1, -h.y + 3)]), Palette.BLUE)
			draw_rect(Rect2(-3, h.y - 7, 6, 7), Palette.INK)
			draw_line(Vector2(h.x - 3, -h.y), Vector2(h.x - 3, -h.y - 12), Palette.INK, 1.0)
			draw_rect(Rect2(h.x - 2, -h.y - 12, 6, 4), Palette.BLUE_LIGHT)
			for i in squad.size():
				draw_circle(Vector2(-h.x + 5 + i * 5, h.y + 3), 1.5, Palette.BLUE)
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
