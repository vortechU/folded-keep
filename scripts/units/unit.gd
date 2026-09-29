class_name Unit
extends Node2D
## A little ink figure printed on the map. Follows a road toward the Keep.
## Placeholder art is drawn in _draw() until the real sprites land.

signal died(unit: Unit)

const InkShader := preload("res://shaders/ink.gdshader")
signal reached_keep(unit: Unit)
## Ink Imp finished gnawing: the map should tear here.
signal gnawed(pos: Vector2)

enum Team { ENEMY, ALLY }

## hp = sword hits it takes in melee (knights vs enemies). Folds ignore hp.
const KINDS := {
	"grunt": {"speed": 16.0, "slaps": 2, "slap_immune": false, "size": 1.0, "hp": 3, "hit": 1},
	"runner": {"speed": 30.0, "slaps": 1, "slap_immune": false, "size": 0.85, "hp": 2, "hit": 1},
	"brute": {"speed": 9.0, "slaps": 99, "slap_immune": true, "size": 1.5, "hp": 8, "hit": 2},
	"knight": {"speed": 26.0, "slaps": 2, "slap_immune": false, "size": 1.0, "hp": 5, "hit": 1},
	"ram": {"speed": 7.0, "slaps": 99, "slap_immune": true, "size": 2.2, "crushes": 3, "hp": 9999, "hit": 3},
	# fold-aware enemies (DESIGN.md): they fight the map, not the Keep
	"pinner": {"speed": 20.0, "slaps": 2, "slap_immune": false, "size": 1.3, "hp": 4, "hit": 1},
	"flyer": {"speed": 19.0, "slaps": 99, "slap_immune": true, "size": 1.0, "hp": 99, "hit": 1},
	"imp": {"speed": 32.0, "slaps": 1, "slap_immune": false, "size": 0.8, "hp": 2, "hit": 1},
	# mid-boss (wave 6): two crushes, shrugs off slaps, cleaves knights and walls
	"warlord": {"speed": 9.0, "slaps": 99, "slap_immune": true, "size": 1.9, "crushes": 2, "hp": 9999, "hit": 3},
}
## Pin-Bearer: folds can't be grabbed this close to the corner he nails down.
const PIN_RADIUS := 140.0
const HAMMER_TIME := 1.4
## Ink Imp: seconds of gnawing until the map tears.
const GNAW_TIME := 4.0
const ATTACK_INTERVAL := 1.0
## Painted sprites (ART_BRIEF.md) and their on-map width in base pixels. Kinds without a file
## fall back to the placeholder drawing.
const SPRITES := {
	"grunt": ["enemy_grunt", 14.0], "runner": ["enemy_runner", 17.0], "brute": ["enemy_brute", 22.0],
	"ram": ["boss_siege_ram", 40.0], "knight": ["ally_knight", 15.0],
	"pinner": ["enemy_pinner", 17.0], "flyer": ["enemy_flyer", 24.0], "imp": ["enemy_imp", 13.0],
	"warlord": ["boss_warlord", 30.0],
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
## Pin-Bearer: the map corner he goes for (INF until chosen), and whether the nail is in.
var corner := Vector2.INF
var planted := false
## Ink Imp: the spot it gnaws (INF until chosen) and its progress 0..1.
var gnaw_spot := Vector2.INF
var gnaw := 0.0
## Left the map on its own (an imp diving through its tear): no ink for that.
var escaped := false

var _alive := true
var _t := 0.0
var _size := 1.0
var _attack_cd := 0.0
var _flash := 0.0
var _face := 1.0 ## 1 = facing right, -1 = mirrored
var _last_x := 0.0
var _hammer := 0.0
var _inked := false ## drawn onto the map yet (happens as it steps inside the frame)
var _refuse := 0.0 ## red shake on the nail when a fold is refused


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
	var mat := ShaderMaterial.new()
	mat.shader = InkShader
	mat.set_shader_parameter("seed", randf() * 100.0)
	mat.set_shader_parameter("reveal", 0.0)
	mat.set_shader_parameter("center", Vector2(0, -7.0 * _size))
	mat.set_shader_parameter("radius", 14.0 * _size)
	material = mat


func _set_reveal(v: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("reveal", v)


## An invisible quill sketches the unit in as it steps onto the map, then the ink floods it.
func _ink_in() -> void:
	_inked = true
	create_tween().tween_method(_set_reveal, 0.0, 1.0, 0.45)
	var fx := Fx.of(self)
	if fx:
		fx.scribble(position + Vector2(0, -6) * _size, 8.0 * _size)


func is_alive() -> bool:
	return _alive


func _process(delta: float) -> void:
	if not _alive:
		return
	_t += delta
	if not _inked and Rect2(Vector2.ZERO, Paper.SIZE).grow(-2.0).has_point(position):
		_ink_in()
	_flash = maxf(0.0, _flash - delta)
	_refuse = maxf(0.0, _refuse - delta)
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
	match kind:
		"pinner":
			_pinner_step(delta)
			return
		"flyer":
			_flyer_step(delta)
			return
		"imp":
			_imp_step(delta)
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
			wall.damage({"brute": 3, "ram": 6, "warlord": 4}.get(kind, 1))
		return
	if to.length() < 3.0:
		path_index += 1
		if path_index >= path.size() and team == Team.ENEMY:
			_arrive()
		return
	position += to.normalized() * speed * delta


func _arrive() -> void:
	_alive = false
	reached_keep.emit(self)
	queue_free()


# --- fold-aware enemies ---------------------------------------------------------------

## Unit vector from a map corner toward the middle of the map.
static func inward(c: Vector2) -> Vector2:
	return Vector2(1.0 if c.x < 1.0 else -1.0, 1.0 if c.y < 1.0 else -1.0)


## Where the Pin-Bearer's nail goes (just inside his corner).
func nail_pos() -> Vector2:
	return corner + inward(corner) * Vector2(22, 32)


## Pin-Bearer: walk off the road to the nearest free corner, hammer the nail in, stand guard.
func _pinner_step(delta: float) -> void:
	if planted:
		return
	if not corner.is_finite():
		corner = _pick_corner()
	var stand := corner + inward(corner) * Vector2(40, 50)
	var to := stand - position
	if to.length() > 2.0:
		position += to.normalized() * minf(speed * delta, to.length())
		_hammer = 0.0
		return
	var before := int(_hammer * 3.0)
	_hammer += delta
	var fx := Fx.of(self)
	if int(_hammer * 3.0) != before and fx:
		fx.dust(nail_pos(), Vector2.ZERO, 3, 3.0)
		fx.star(nail_pos() + Vector2(0, -4), Palette.PARCHMENT)
	if _hammer >= HAMMER_TIME:
		planted = true
		Audio.play_sfx("pin")
		if fx:
			fx.dust_ring(nail_pos(), 10.0, 10)
			fx.ring(nail_pos(), PIN_RADIUS * 0.5, Palette.RED, 0.45)
			fx.text(nail_pos() + Vector2(0, 16), "PINNED!", Palette.RED_LIGHT)


func _pick_corner() -> Vector2:
	var taken: Array[Vector2] = []
	for u in get_tree().get_nodes_in_group("enemy"):
		if u != self and u.kind == "pinner" and u.is_alive():
			taken.append(u.corner)
	var best := Vector2.ZERO
	var best_d := INF
	for c in [Vector2.ZERO, Vector2(Paper.SIZE.x, 0), Vector2(0, Paper.SIZE.y), Paper.SIZE]:
		var d := position.distance_to(c)
		if not taken.has(c) and d < best_d:
			best_d = d
			best = c
	return best


## A fold was grabbed too close to this pin: shake the nail red.
func refuse() -> void:
	_refuse = 0.4
	var fx := Fx.of(self)
	if fx:
		fx.ring(nail_pos(), 14.0, Palette.RED, 0.3)
		fx.text(nail_pos() + Vector2(0, 16), "PINNED!", Palette.RED_LIGHT)
	Audio.play_sfx("pin_block")


## Crow Rider: straight for the Keep, over roads, walls and knights.
func _flyer_step(delta: float) -> void:
	var to := Paper.KEEP_POS - position
	if to.length() < 6.0:
		_arrive()
		return
	position += to.normalized() * speed * delta


## Ink Imp: run to a spot (usually next to one of your buildings) and gnaw until the map tears.
func _imp_step(delta: float) -> void:
	if not gnaw_spot.is_finite():
		gnaw_spot = _pick_gnaw_spot()
	var to := gnaw_spot - position
	if to.length() > 2.0:
		position += to.normalized() * minf(speed * delta, to.length())
		return
	var before := int(gnaw * 10.0)
	gnaw += delta / GNAW_TIME
	var fx := Fx.of(self)
	if int(gnaw * 10.0) != before and fx:
		fx.dust(gnaw_spot + Vector2(randf_range(-6, 6), randf_range(-4, 4)), Vector2.ZERO, 2, 2.0)
	if gnaw < 1.0:
		return
	# Through the paper: the map tears and the imp dives into its hole.
	_alive = false
	escaped = true
	gnawed.emit(gnaw_spot)
	died.emit(self)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "rotation", TAU, 0.35)
	tw.chain().tween_callback(queue_free)


func _pick_gnaw_spot() -> Vector2:
	var targets: Array = get_tree().get_nodes_in_group("building").filter(func(b): return b.kind != "keep")
	for i in 20:
		var p: Vector2
		if not targets.is_empty() and randf() < 0.7:
			p = targets.pick_random().position + Vector2.from_angle(randf() * TAU) * randf_range(6.0, 12.0)
		else:
			p = Vector2(randf_range(36, 324), randf_range(70, 500))
		if Rect2(28, 40, 304, 540).has_point(p) and not FoldController.KEEP_ZONE.grow(16.0).has_point(p):
			return p
	return Vector2(randf_range(60, 300), randf_range(120, 420))


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
		if not e.is_alive() or e.is_flying():
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
	tw.tween_interval(0.08)
	# the ink soaks away into the paper (the splat stays)
	tw.tween_method(_set_reveal, 1.0, 0.0, 0.3)
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
	if not _alive or is_flying():
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


## Walked into a tear in the map: tumble through it and gone.
func on_fell(hole: Vector2) -> void:
	if not _alive:
		return
	_alive = false
	foe = null
	died.emit(self)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position", hole, 0.25)
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "rotation", TAU * 1.5, 0.35)
	tw.chain().tween_callback(queue_free)


func is_boss() -> bool:
	return kind == "ram" or kind == "warlord"


func is_flying() -> bool:
	return kind == "flyer"


## Flung off the edge of the map by a huge fold: sails off the table, spinning.
func on_flung(dir: Vector2) -> void:
	if not _alive:
		return
	_alive = false
	foe = null
	died.emit(self)
	var fx := Fx.of(self)
	if fx:
		fx.text(position + Vector2(0, -16), "OFF THE MAP!", Palette.GOLD)
	z_index = 10
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position", position + dir.normalized() * 260.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "rotation", TAU * 3.0, 0.6)
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(queue_free)


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
	# thrown off his corner / her gnawing spot: start over
	planted = false
	_hammer = 0.0
	gnaw = 0.0
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
	_draw_marks()
	var tex := sprite_for(kind)
	if tex:
		_draw_sprite(tex)
		return
	match kind:
		"ram":
			_draw_ram()
			return
		"flyer":
			_draw_flyer()
			return
		"warlord":
			_draw_warlord()
			return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _size)
	var fill := Palette.RED if team == Team.ENEMY else Palette.BLUE
	if kind == "runner" or kind == "imp":
		fill = Palette.RED_LIGHT
	if _flash > 0.0:
		fill = Palette.PARCHMENT
	var walking := stun <= 0.0
	var bob := absf(sin(_t * (16.0 if kind == "imp" else 9.0))) * 1.5 if walking else 0.0
	draw_circle(Vector2(0, 3), 4.0, Color(0, 0, 0, 0.15))
	# body
	draw_rect(Rect2(-3.5, -4.0 - bob, 7, 7), Palette.INK)
	draw_rect(Rect2(-2.5, -3.0 - bob, 5, 5), fill)
	# head
	draw_circle(Vector2(0, -7.0 - bob), 3.0, Palette.INK)
	draw_circle(Vector2(0, -7.0 - bob), 2.0, Palette.PARCHMENT if kind != "imp" else fill)
	match kind:
		"pinner":
			_draw_mallet(bob)
		"imp":
			# horns and a grin full of teeth
			for sx in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(sx * 1.5, -9.5 - bob), Vector2(sx * 3.5, -13.0 - bob),
					Vector2(sx * 2.8, -9.0 - bob)]), Palette.INK)
			draw_line(Vector2(-1.5, -6.5 - bob), Vector2(1.5, -6.5 - bob), Palette.PARCHMENT, 1.0)
		_:
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


## Things printed on the paper around the unit: the Pin-Bearer's nail, the imp's bite marks.
func _draw_marks() -> void:
	if kind == "pinner" and corner.is_finite() and (planted or _hammer > 0.0):
		var c := nail_pos() - position
		if _refuse > 0.0:
			c += Vector2(randf_range(-2, 2), randf_range(-1, 1))
		var sunk := 1.0 if planted else clampf(_hammer / HAMMER_TIME, 0.0, 1.0)
		var h := lerpf(12.0, 2.0, sunk)
		draw_set_transform(c + Vector2(2, 2), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 8.0, Color(Palette.INK, 0.25))
		draw_set_transform(Vector2.ZERO)
		for i in 5:
			var d := Vector2.from_angle(i * TAU / 5.0 + 0.4)
			draw_line(c + d * 5.0, c + d * (8.0 + 4.0 * sunk), Palette.SEPIA, 1.0)
		draw_line(c, c + Vector2(0, -h), Palette.INK, 3.0)
		var iron := Palette.RED_LIGHT if _refuse > 0.0 else Color("#80828a")
		draw_line(c, c + Vector2(0, -h), Palette.INK, 4.0)
		draw_circle(c + Vector2(0, -h), 7.5, Palette.INK)
		draw_circle(c + Vector2(0, -h), 5.8, iron)
		draw_circle(c + Vector2(-2, -h - 2), 1.8, Color(1, 1, 1, 0.45))
	elif kind == "imp" and gnaw > 0.0 and gnaw_spot.is_finite():
		var c := gnaw_spot - position
		var r := FoldController.TEAR_RADIUS
		# ragged bite marks growing in the paper, and a ring that fills up
		if gnaw > 0.1:
			var pts := PackedVector2Array()
			for k in 12:
				pts.append(c + Vector2.from_angle(TAU * k / 12.0) * r * gnaw * (0.55 if k % 2 else 0.8))
			draw_colored_polygon(pts, Color(Palette.INK, 0.35))
		draw_arc(c, r + 3.0, 0.0, TAU, 24, Color(Palette.INK, 0.25), 2.0)
		draw_arc(c, r + 3.0, -PI * 0.5, -PI * 0.5 + TAU * gnaw, 24, Palette.RED, 2.0)


func _draw_mallet(bob: float) -> void:
	# over the shoulder, or swinging down on the nail
	var hammering := not planted and _hammer > 0.0
	var a := -PI * 0.5 - 0.6
	if hammering:
		a = -PI * 0.5 + absf(sin(_hammer * 3.0 * PI)) * 1.9
	var hand := Vector2(3, -3 - bob)
	var d := Vector2.from_angle(a) * Vector2(_face, 1.0)
	var head := hand + d * 11.0
	draw_line(hand, head, Palette.SEPIA, 1.5)
	draw_set_transform(head * _size, a * _face, Vector2.ONE * _size)
	draw_rect(Rect2(-2.5, -3.5, 5, 7), Palette.INK)
	draw_rect(Rect2(-1.5, -2.5, 3, 5), Color("#80828a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _size)


## Crow Rider, seen from above: shadow on the paper, the crow flapping over it.
func _draw_flyer() -> void:
	var lift := 14.0 + sin(_t * 3.0) * 2.0
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 7.0, Color(Palette.INK, 0.22))
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
	var flap := sin(_t * (14.0 if stun <= 0.0 else 4.0))
	var span := 11.0 + 4.0 * flap
	var body := Palette.INK if _flash <= 0.0 else Palette.PARCHMENT
	for sx in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(sx * 2.0, -3.0), Vector2(sx * span, -4.0 - flap * 3.0),
			Vector2(sx * (span - 3.0), 0.0), Vector2(sx * 2.0, 2.5)]), body)
	# tail feathers, body, head and beak (flying down the map)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -5), Vector2(0, -10), Vector2(3, -5)]), body)
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(0.7, 1.0))
	draw_circle(Vector2.ZERO, 5.5, body)
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
	draw_circle(Vector2(0, 5), 2.6, body)
	draw_colored_polygon(PackedVector2Array([Vector2(-1.2, 6.5), Vector2(0, 10), Vector2(1.2, 6.5)]), Palette.GOLD)
	# the rider
	draw_circle(Vector2(0, -1), 2.6, Palette.PARCHMENT)
	draw_circle(Vector2(0, -1), 1.8, Palette.RED)
	draw_line(Vector2(2, -3), Vector2(4, 6), Palette.SEPIA, 1.0)
	draw_set_transform(Vector2.ZERO)
	if stun > 0.0:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 7.0, -lift - 9.0 + sin(a) * 2.0), 1.0, Palette.GOLD)


func _draw_sprite(tex: Texture2D) -> void:
	var walking := stun <= 0.0
	var w: float = SPRITES[kind][1]
	var s := tex.get_size() * (w / tex.get_size().x)
	var step := sin(_t * (5.0 if kind == "ram" else 9.0))
	var bob := absf(step) * (1.0 if kind == "ram" else 1.5) if walking else 0.0
	var lift := 14.0 + sin(_t * 3.0) * 2.0 if is_flying() else 0.0
	# shadow at the feet
	draw_set_transform(Vector2(1, 2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, w * 0.42, Color(Palette.INK, 0.25))
	# waddle around the feet, mirrored to face the walking direction
	var waddle := step * 0.07 if walking and kind != "ram" and lift == 0.0 else 0.0
	draw_set_transform(Vector2(0, 3 - bob - lift), waddle, Vector2(_face, 1.0))
	var mod := Color(2.2, 2.2, 2.2) if _flash > 0.0 else Color.WHITE
	draw_texture_rect(tex, Rect2(Vector2(-s.x * 0.5, -s.y), s), false, mod)
	draw_set_transform(Vector2.ZERO)
	if kind == "pinner" and not planted and _hammer > 0.0:
		_draw_mallet(0.0)
		draw_set_transform(Vector2.ZERO)
	if is_boss():
		_draw_pips(-s.y - 4)
	if not walking:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * w * 0.45, -s.y - 1.0 - lift + sin(a) * 2.0), 1.1, Palette.GOLD)


## Crushes a boss still needs, as red pips over its head.
func _draw_pips(y: float) -> void:
	for i in crushes_to_kill:
		var x := (i - (crushes_to_kill - 1) * 0.5) * 5.0
		draw_circle(Vector2(x, y), 2.0, Palette.INK)
		draw_circle(Vector2(x, y), 1.2, Palette.RED_LIGHT)


## Iron Warlord placeholder: a hulking armored figure with a horned helm and a great axe.
func _draw_warlord() -> void:
	var walking := stun <= 0.0
	var bob := absf(sin(_t * 5.0)) * 1.2 if walking else 0.0
	var iron := Color("#5d5f68") if _flash <= 0.0 else Palette.PARCHMENT
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 12.0, Color(Palette.INK, 0.25))
	draw_set_transform(Vector2(0, -bob), 0.0, Vector2(_face, 1.0))
	# cape, legs, armored body
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -14), Vector2(8, -14), Vector2(10, 2), Vector2(-10, 2)]), Palette.RED)
	draw_rect(Rect2(-6, -2, 4, 6), Palette.INK)
	draw_rect(Rect2(2, -2, 4, 6), Palette.INK)
	draw_rect(Rect2(-8, -16, 16, 15), Palette.INK)
	draw_rect(Rect2(-6.5, -14.5, 13, 12), iron)
	draw_line(Vector2(-6, -9), Vector2(6, -9), Palette.INK, 1.0)
	# pauldrons
	draw_circle(Vector2(-8, -15), 3.5, Palette.INK)
	draw_circle(Vector2(8, -15), 3.5, Palette.INK)
	# horned great helm with a visor slit
	draw_circle(Vector2(0, -21), 5.5, Palette.INK)
	draw_circle(Vector2(0, -21), 4.3, iron)
	draw_rect(Rect2(-3, -22, 6, 1.5), Palette.RED_LIGHT)
	for sx in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(sx * 3.5, -24), Vector2(sx * 10.0, -30), Vector2(sx * 5.0, -21)]), Palette.PARCHMENT_MID)
	# great axe
	draw_line(Vector2(11, -26), Vector2(11, 4), Palette.SEPIA, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(11, -26), Vector2(18, -30), Vector2(19, -18), Vector2(11, -20)]), Palette.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(12, -25), Vector2(17, -28), Vector2(17.5, -19.5), Vector2(12, -21)]), iron)
	draw_set_transform(Vector2.ZERO)
	_draw_pips(-36.0)
	if not walking:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 11.0, -34.0 + sin(a) * 3.0), 1.3, Palette.GOLD)


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
	_draw_pips(-17.0)
	if not walking:
		for i in 3:
			var a := _t * 6.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 10.0, -20.0 + sin(a) * 3.0), 1.3, Palette.GOLD)
