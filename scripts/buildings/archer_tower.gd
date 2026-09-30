class_name ArcherTower
extends Building
## A light watchtower that automatically shoots Crow Riders above the map.

const RANGE := 90.0
const SHOT_INTERVAL := 1.6
const SHOT_FLASH := 0.16

var _cooldown := 0.0
var _shot_flash := 0.0
var _shot_end := Vector2.ZERO


func _process(delta: float) -> void:
	_shot_flash = maxf(0.0, _shot_flash - delta)
	if _shot_flash > 0.0:
		queue_redraw()
	if not is_in_group("building"):
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_flyer()
	if target == null:
		return
	_cooldown = SHOT_INTERVAL
	_shot_end = target.position - position + Vector2(0, -7)
	_shot_flash = SHOT_FLASH
	target.on_arrow_hit()
	queue_redraw()


func _find_flyer() -> Unit:
	var nearest: Unit = null
	var closest_keep := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var flyer := enemy as Unit
		if flyer == null or not flyer.is_alive() or not flyer.is_flying():
			continue
		if position.distance_squared_to(flyer.position) > RANGE * RANGE:
			continue
		var keep_distance := flyer.position.distance_squared_to(Paper.KEEP_POS)
		if keep_distance < closest_keep:
			closest_keep = keep_distance
			nearest = flyer
	return nearest


func _draw() -> void:
	super._draw()
	var tex := sprite_for(kind)
	var muzzle := Vector2(0, -10)
	if tex:
		var art_width: float = SPRITE_WIDTH[kind]
		var art_height := tex.get_size().y * art_width / tex.get_size().x
		muzzle = Vector2(art_width * 0.2, size.y * 0.5 + 3.0 - art_height * 0.92)
	else:
		# Keep a readable bow silhouette if the art is unavailable.
		draw_arc(Vector2(0, -8), 8.0, PI * 0.65, PI * 2.35, 16, Palette.GOLD, 1.8)
		draw_line(Vector2(-5, -2), Vector2(5, -14), Palette.INK, 1.5)
		draw_line(Vector2(-3, -11), Vector2(6, -5), Palette.BLUE_LIGHT, 1.5)
	if _shot_flash > 0.0:
		var alpha := _shot_flash / SHOT_FLASH
		draw_line(muzzle, _shot_end, Color(Palette.GOLD, alpha), 2.0)
		draw_circle(_shot_end, 2.5, Color(Palette.GOLD, alpha))
