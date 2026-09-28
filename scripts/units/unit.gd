class_name Unit
extends Node2D
## A little ink figure printed on the map. Follows a road toward the Keep.
## Placeholder art is drawn in _draw() until the real sprites land.

signal died(unit: Unit)
signal reached_keep(unit: Unit)

enum Team { ENEMY, ALLY }

## hp = sword hits it takes in melee (knights vs enemies). Folds ignore hp.
const KINDS := {
	"grunt": {"speed": 16.0, "slaps": 2, "slap_immune": false, "size": 1.0, "hp": 3, "hit": 1},
	"runner": {"speed": 30.0, "slaps": 1, "slap_immune": false, "size": 0.85, "hp": 2, "hit": 1},
	"brute": {"speed": 9.0, "slaps": 99, "slap_immune": true, "size": 1.5, "hp": 8, "hit": 2},
	"knight": {"speed": 26.0, "slaps": 2, "slap_immune": false, "size": 1.0, "hp": 5, "hit": 1},
	"ram": {"speed": 7.0, "slaps": 99, "slap_immune": true, "size": 2.2, "crushes": 3, "hp": 9999, "hit": 3},
}
const ATTACK_INTERVAL := 1.0
## Painted sprites (ART_BRIEF.md) and their on-map width in base pixels. Kinds without a file
## fall back to the placeholder drawing.
const SPRITES := {
	"grunt": ["enemy_grunt", 14.0], "runner": ["enemy_runner", 17.0], "brute": ["enemy_brute", 22.0],
	"ram": ["boss_siege_ram", 40.0], "knight": ["ally_knight", 15.0],
}
static var _textures := {}
const MELEE := 9.0 ## knights engage within this distance
const AGGRO := 48.0 ## knights chase enemies this close to their post
const LEASH := 70.0 ## ...but never further than this from it

@export var team := Team.ENEMY
@export var kind := "grunt"
@export var speed := 16.0
@export var slaps_to_kill := 2
@export var slap_immune := false
@export var crushes_to_kill := 1

var path: PackedVector2Array = []
var path_index := 0
var stun := 0.0

var hp := 3
var hit := 1
## Knights: the road point they guard. Enemies: unused.
var post := Vector2.ZERO
## Melee opponent (knight <-> enemy). Enemies stand still while a knight holds them.
var foe: Unit

var _alive := true
var _t := 0.0
var _size := 1.0
var _attack_cd := 0.0
var _flash := 0.0
var _face := 1.0 ## 1 = facing right, -1 = mirrored
var _last_x := 0.0


## Apply the stats of a kind from KINDS. Call before adding to the tree.
func setup(unit_kind: String) -> void:
	kind = unit_kind
	var k: Dictionary = KINDS[kind]
	speed = k.speed * randf_range(0.9, 1.1)
	slaps_to_kill = k.slaps
	slap_immune = k.slap_immune
	crushes_to_kill = k.get("crushes", 1)
	_size = k.size
	hp = k.hp
	hit = k.hit


## How far from its center a unit can be hit by a slammed building.
func hit_radius() -> float:
	return 4.0 * _size


func _ready() -> void:
	add_to_group("unit")
	add_to_group("enemy" if team == Team.ENEMY else "ally")
	_t = randf() * 10.0


func is_alive() -> bool:
	return _alive


func _process(delta: float) -> void:
	if not _alive:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if stun > 0.0:
		stun -= delta
		return
	if foe and not (is_instance_valid(foe) and foe.is_alive()):
		foe = null
	if team == Team.ALLY:
		_knight_step(delta)
		return
	if foe:
		_fight(delta)
		return
	if path_index >= path.size():
		return
	var target := path[path_index]
	var to := target - position
	var wall := _blocking_wall(to.normalized())
	if wall:
		_attack_cd -= delta
		if _attack_cd <= 0.0:
			_attack_cd = ATTACK_INTERVAL
			wall.damage({"brute": 3, "ram": 6}.get(kind, 1))
		return
	if to.length() < 3.0:
		path_index += 1
		if path_index >= path.size() and team == Team.ENEMY:
			_alive = false
			reached_keep.emit(self)
			queue_free()
		return
	position += to.normalized() * speed * delta


## Guard the post; charge enemies that come near it; fight them in melee.
func _knight_step(delta: float) -> void:
	if foe == null:
		foe = _find_prey()
	if foe:
		var to := foe.position - position
		if to.length() > MELEE:
			if foe.position.distance_to(post) > LEASH:
				foe = null
				return
			position += to.normalized() * speed * delta
			return
		# Pin it: the enemy turns to fight us if it isn't fighting someone already.
		if foe.foe == null:
			foe.foe = self
		_fight(delta)
		return
	var home := post - position
	if home.length() > 2.0:
		position += home.normalized() * minf(speed * delta, home.length())


func _find_prey() -> Unit:
	var best: Unit = null
	var best_d := AGGRO
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive():
			continue
		var d: float = e.position.distance_to(post)
		if d < best_d:
			best_d = d
			best = e
	return best


func _fight(delta: float) -> void:
	_attack_cd -= delta
	if _attack_cd > 0.0:
		return
	_attack_cd = ATTACK_INTERVAL * randf_range(0.85, 1.15)
	# a little lunge toward the foe
	var d := (foe.position - position).normalized()
	var tw := create_tween()
	tw.tween_property(self, "position", position + d * 3.0, 0.06)
	tw.tween_property(self, "position", position, 0.12)
	foe.take_hit(hit, d)


## Hurt by a sword (not a fold).
func take_hit(amount: int, dir: Vector2) -> void:
	if not _alive:
		return
	hp -= amount
	_flash = 0.12
	var fx := Fx.of(self)
	if fx:
		fx.droplets(position + Vector2(0, -4), Palette.RED if team == Team.ENEMY else Palette.BLUE, 3, 0.6)
		fx.star(position + dir * 3.0 + Vector2(0, -5), Palette.PARCHMENT)
	if hp <= 0:
		crushes_to_kill = 1
		on_crushed()


func _blocking_wall(dir: Vector2) -> Node:
	if team != Team.ENEMY:
		return null
	var ahead := position + dir * 7.0 * _size
	for b in get_tree().get_nodes_in_group("building"):
		if b.kind == "wall" and b.contains_point(ahead):
			return b
	return null


func on_crushed() -> void:
	if not _alive:
		return
	crushes_to_kill -= 1
	if crushes_to_kill > 0:
		_hurt()
		return
	_alive = false
	var splats := get_tree().get_first_node_in_group("splats")
	if splats:
		splats.add_splat(position, Palette.RED if team == Team.ENEMY else Palette.BLUE)
	var fx := Fx.of(self)
	if fx:
		fx.droplets(position, Palette.RED if team == Team.ENEMY else Palette.BLUE, int(8 * _size), 1.1)
		fx.dust(position, Vector2.ZERO, 4, 5.0 * _size)
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.9, 0.12), 0.05)
	tw.tween_interval(0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)


## Survived a crush (boss): splat, stun, squash.
func _hurt() -> void:
	var splats := get_tree().get_first_node_in_group("splats")
	if splats:
		splats.add_splat(position, Palette.RED)
	var fx := Fx.of(self)
	if fx:
		fx.droplets(position, Palette.RED, 16, 1.4)
		fx.ring(position, 34.0, Palette.RED, 0.35)
		fx.text(position + Vector2(0, -26), "%d MORE!" % crushes_to_kill, Palette.RED_LIGHT)
	stun = 1.5
	scale = Vector2(1.6, 0.4)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func on_slapped(dir: Vector2) -> void:
	if not _alive:
		return
	var fx := Fx.of(self)
	if slap_immune:
		# Too heavy to slap: a dull thud, it doesn't even flinch.
		if fx:
			fx.star(position + Vector2(0, -6) * _size, Palette.PARCHMENT_SHADOW)
		scale = Vector2(1.1, 0.9)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.15)
		return
	if fx:
		fx.star(position + Vector2(0, -6))
		fx.dust(position, dir, 3)
	slaps_to_kill -= 1
	if slaps_to_kill <= 0:
		on_crushed()
		return
	stun = 1.5
	foe = null
	var tw := create_tween()
	tw.tween_property(self, "position", (position + dir * 14.0).clamp(Vector2(4, 4), Vector2(356, 636)), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	scale = Vector2(1.4, 0.6)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func on_flipped(to: Vector2) -> void:
	if not _alive:
		return
	foe = null
	var fx := Fx.of(self)
	if fx:
		fx.dust_ring(to, 8.0, 6)
		fx.ring(to, 12.0, Palette.BLUE_LIGHT, 0.25)
	position = to
	stun = 1.0
	# Resume at the closest waypoint so a flipped unit doesn't walk back up the road.
	# (Knights just march back to their post.)
	var best := path_index
	var best_d := INF
	for i in range(path.size()):
		var d := to.distance_squared_to(path[i])
		if d < best_d:
			best_d = d
			best = i
	path_index = best
	scale = Vector2(1.5, 0.5)
	rotation = PI
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", 0.0, 0.3)


static func sprite_for(k: String) -> Texture2D:
	if not _textures.has(k):
		var path := "res://assets/sprites/units/%s.png" % SPRITES[k][0] if SPRITES.has(k) else ""
		_textures[k] = load(path) if path != "" and ResourceLoader.exists(path) else null
	return _textures[k]


func _draw() -> void:
	var dx := position.x - _last_x
	if absf(dx) > 0.05:
		_face = signf(dx)
	_last_x = position.x
	var tex := sprite_for(kind)
	if tex:
		_draw_sprite(tex)
		return
	if kind == "ram":
		_draw_ram()
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _size)
	var fill := Palette.RED if team == Team.ENEMY else Palette.BLUE
	if kind == "runner":
		fill = Palette.RED_LIGHT
	if _flash > 0.0:
		fill = Palette.PARCHMENT
	var walking := stun <= 0.0
	var bob := absf(sin(_t * 9.0)) * 1.5 if walking else 0.0
	draw_circle(Vector2(0, 3), 4.0, Color(0, 0, 0, 0.15))
	# body
	draw_rect(Rect2(-3.5, -4.0 - bob, 7, 7), Palette.INK)
	draw_rect(Rect2(-2.5, -3.0 - bob, 5, 5), fill)
	# head
	draw_circle(Vector2(0, -7.0 - bob), 3.0, Palette.INK)
	draw_circle(Vector2(0, -7.0 - bob), 2.0, Palette.PARCHMENT)
	# weapon
	if team == Team.ENEMY:
		draw_line(Vector2(5, -12 - bob), Vector2(5, 3 - bob), Palette.INK, 1.0)
		draw_rect(Rect2(4, -14 - bob, 3, 2), Palette.INK)
	else:
		# shield, sword, helmet plume
		draw_rect(Rect2(-8, -5 - bob, 4, 6), Palette.INK)
		draw_rect(Rect2(-7, -4 - bob, 2, 4), Palette.BLUE_LIGHT)
		draw_line(Vector2(5, -11 - bob), Vector2(5, 1 - bob), Palette.INK, 1.0)
		draw_line(Vector2(3, -3 - bob), Vector2(7, -3 - bob), Palette.INK, 1.0)
		draw_rect(Rect2(-1, -12 - bob, 2, 3), Palette.BLUE_LIGHT)
	if not walking:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 6.0, -12.0 + sin(a) * 2.0), 1.0, Palette.GOLD)


func _draw_sprite(tex: Texture2D) -> void:
	var walking := stun <= 0.0
	var w: float = SPRITES[kind][1]
	var s := tex.get_size() * (w / tex.get_size().x)
	var step := sin(_t * (5.0 if kind == "ram" else 9.0))
	var bob := absf(step) * (1.0 if kind == "ram" else 1.5) if walking else 0.0
	# shadow at the feet
	draw_set_transform(Vector2(1, 2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, w * 0.42, Color(Palette.INK, 0.25))
	# waddle around the feet, mirrored to face the walking direction
	var waddle := step * 0.07 if walking and kind != "ram" else 0.0
	draw_set_transform(Vector2(0, 3 - bob), waddle, Vector2(_face, 1.0))
	var mod := Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE
	draw_texture_rect(tex, Rect2(Vector2(-s.x * 0.5, -s.y), s), false, mod)
	draw_set_transform(Vector2.ZERO)
	if kind == "ram":
		for i in crushes_to_kill:
			draw_circle(Vector2(-5 + i * 5, -s.y - 4), 2.0, Palette.INK)
			draw_circle(Vector2(-5 + i * 5, -s.y - 4), 1.2, Palette.RED_LIGHT)
	if not walking:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * w * 0.45, -s.y - 1.0 + sin(a) * 2.0), 1.1, Palette.GOLD)


func _draw_ram() -> void:
	var walking := stun <= 0.0
	var bob := absf(sin(_t * 5.0)) * 1.0 if walking else 0.0
	draw_rect(Rect2(-11, -2, 22, 14), Color(0, 0, 0, 0.15))
	# wheels
	for x in [-9.0, 9.0]:
		for y in [-6.0, 6.0]:
			draw_circle(Vector2(x, y), 3.0, Palette.INK)
	# body + roof
	draw_rect(Rect2(-9, -12 - bob, 18, 20), Palette.INK)
	draw_rect(Rect2(-7.5, -10.5 - bob, 15, 17), Palette.RED)
	for y in [-7.0, -3.0, 1.0]:
		draw_line(Vector2(-7, y - bob), Vector2(7, y - bob), Palette.INK, 1.0)
	# ram log pointing down the road
	draw_rect(Rect2(-2.5, 6 - bob, 5, 10), Palette.SEPIA)
	draw_rect(Rect2(-3.5, 14 - bob, 7, 4), Palette.INK)
	# crush pips
	for i in crushes_to_kill:
		draw_circle(Vector2(-5 + i * 5, -17), 2.0, Palette.INK)
		draw_circle(Vector2(-5 + i * 5, -17), 1.2, Palette.RED_LIGHT)
	if not walking:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 10.0, -20.0 + sin(a) * 3.0), 1.3, Palette.GOLD)
