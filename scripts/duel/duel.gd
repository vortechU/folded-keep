class_name Duel
extends CanvasLayer
## Duel of Champions (DESIGN.md, task #23): when a boss arrives the map freezes and the Champion
## faces it in first person. Read the wind-up and swipe (dodge left / dodge right / swipe up =
## shield), tap to strike while it's open, fill the stagger bar, then fold the page onto it.
## Runs while the tree is paused (process_mode ALWAYS). main.gd awaits `finished`.
## Placeholder art is drawn in code; `assets/sprites/duel/*.png` replaces it when present.
## Owner: Claude.

signal finished(won: bool)

enum Stage { INTRO, TELL, STRIKE, WAIT, FINISHER, SLAM, OUTRO }
enum Move { LEFT, RIGHT, OVERHEAD } ## where the boss's blow comes from
enum Answer { NONE, DODGE_LEFT, DODGE_RIGHT, BLOCK }

const PAGE := Vector2(360, 640)
const FEET := Vector2(180, 470) ## where the boss stands on the page
const CHEST := Vector2(0, -140) ## boss chest, relative to its feet (the finisher must cover it)
const ART_DIR := "res://assets/sprites/duel/"
const BOSSES := {
	"warlord": {"name": "THE IRON WARLORD", "stagger": 100.0, "tell": 1.15, "tell_min": 0.7, "fakes": 0.0,
		"armor": Color("#62646e"), "cloth": Color("#A8322D"), "weapon": "axe",
		"win": "The Warlord falls!", "lose": "The Warlord marches on your Keep!"},
	"driver": {"name": "THE RAM'S DRIVER", "stagger": 120.0, "tell": 1.0, "tell_min": 0.6, "fakes": 0.4,
		"armor": Color("#7a5a3a"), "cloth": Color("#6E4B2A"), "weapon": "maul",
		"win": "The Ram rolls in wounded: one crush left!", "lose": "The Ram rolls in at full strength!"},
}
const CHAMPION_HP := 3
const STRIKE_TIME := 1.6
const TAP_DAMAGE := 5.0
const COUNTER_DAMAGE := 8.0 ## for reading the blow right
const SWIPE_MIN := 34.0
const EDGE_GRAB := 44.0
const HINT_ROUNDS := 2 ## the answer arrow is shown for the first rounds (no fake-outs until after)
const STEEL := Color("#b9bcc4")

@export var boss := "warlord"

var stage := Stage.INTRO
var won := false
var stagger := 0.0
var hp := CHAMPION_HP
var move := Move.LEFT ## the blow that will actually land
var shown := Move.LEFT ## what the wind-up shows (differs during a fake-out)
var answer := Answer.NONE
var round_no := 0

var _data: Dictionary
var _ctl: Control
var _font: Font
var _o := Vector2.ZERO ## page origin on screen (+ shake) for the current frame
var _timer := 0.0
var _t := 0.0
var _fake_at := -1.0
var _tex := {}
# animated state (tweened)
var _fade := 0.0
var _boss_off := Vector2.ZERO
var _boss_scale := Vector2.ONE
var _boss_lean := 0.0
var _boss_flash := 0.0
var _weapon := -1.2 ## weapon angle around the boss's hands
var _reach := 1.0 ## < 0: the weapon comes at the camera (overhead smash)
var _flat := 0.0 ## squashed by the finisher
var _view_x := 0.0 ## the world slides when the Champion dodges
var _shield := 0.0 ## 1 = raised
var _swing := 0.0 ## sword strike
var _jolt := 0.0 ## hands knocked down when hit
var _glow := 0.0 ## telegraph glow
var _shake := 0.0
var _red := 0.0
var _white := 0.0
var _texts: Array[Dictionary] = []
var _wounds: Array[Dictionary] = [] ## ink splats on the boss (boss-local)
var _splash: Array[Dictionary] = [] ## ink thrown over the page by the finisher
var _cracks: Array[PackedVector2Array] = []
var _press := Vector2.INF
var _swiped := false
var _grab := Vector2.INF ## finisher fold: grab point on the page edge
var _pointer := Vector2.ZERO


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("duel")
	_data = BOSSES.get(boss, BOSSES["warlord"])
	_font = ThemeDB.fallback_font
	_ctl = Control.new()
	_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	_ctl.draw.connect(_draw_all)
	_ctl.gui_input.connect(_on_input)
	add_child(_ctl)
	for k in ["idle", "windup", "hurt"]:
		_tex[k] = _load("duel_%s_%s" % [boss, k])
	_tex["arm"] = _load("duel_champion_arm")
	_tex["shield"] = _load("duel_champion_shield")
	_tex["bg"] = _load("duel_bg")
	Engine.time_scale = 1.0
	Audio.play_music("boss")
	Audio.play_sfx("wave_horn")
	Events.duel_started.emit(boss)
	_intro()


static func _load(n: String) -> Texture2D:
	var path := ART_DIR + n + ".png"
	return load(path) if ResourceLoader.exists(path) else null


## Tests / skip: end the duel right away with this outcome.
func resolve(result: bool) -> void:
	won = result
	_finish()


# --- flow -----------------------------------------------------------------------------

func _intro() -> void:
	stage = Stage.INTRO
	_boss_off = Vector2(0, 60)
	_boss_scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(self, "_fade", 1.0, 0.3)
	tw.parallel().tween_property(self, "_boss_off", Vector2.ZERO, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_boss_scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_text(Vector2(180, 118), "DUEL OF CHAMPIONS", Palette.GOLD, 22, 2.0, 0.0)
	_text(Vector2(180, 146), _data.name, Palette.RED_LIGHT, 15, 2.0, 0.0)
	_text(Vector2(180, 560), "SWIPE to dodge  -  TAP to strike", Palette.PARCHMENT, 12, 2.0, 0.0)
	tw.tween_interval(1.5)
	tw.tween_callback(_next_round)


func _next_round() -> void:
	if stage == Stage.OUTRO or stage == Stage.SLAM:
		return
	round_no += 1
	stage = Stage.TELL
	answer = Answer.NONE
	move = [Move.LEFT, Move.RIGHT, Move.OVERHEAD].pick_random()
	var tell: float = maxf(_data.tell_min, _data.tell - 0.08 * (round_no - 1))
	shown = move
	_fake_at = -1.0
	if round_no > HINT_ROUNDS and randf() < _data.fakes:
		# fake-out: wind up one way, then switch at the last moment
		shown = [Move.LEFT, Move.RIGHT, Move.OVERHEAD].filter(func(m): return m != move).pick_random()
		_fake_at = tell
		tell += 0.5
	_timer = tell
	_windup(shown, 0.3)
	Audio.play_sfx("duel_windup")


func _windup(m: Move, dur: float) -> void:
	var lean := 0.0
	var ang := -PI * 0.5
	var scl := Vector2(0.97, 1.07)
	match m:
		Move.LEFT:
			lean = -0.13
			ang = -2.4
			scl = Vector2(1.03, 0.98)
		Move.RIGHT:
			lean = 0.13
			ang = -0.75
			scl = Vector2(1.03, 0.98)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_boss_lean", lean, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_weapon", ang, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_reach", 1.0, dur)
	tw.tween_property(self, "_boss_scale", scl, dur)
	tw.tween_property(self, "_boss_off", Vector2(0, -6), dur)
	_glow = 1.0


static func answer_for(m: Move) -> Answer:
	match m:
		Move.LEFT:
			return Answer.DODGE_RIGHT
		Move.RIGHT:
			return Answer.DODGE_LEFT
	return Answer.BLOCK


## The blow lands.
func _attack() -> void:
	stage = Stage.WAIT
	_timer = 99.0
	var correct := answer == answer_for(move)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_boss_scale", Vector2(1.18, 1.14), 0.12).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "_boss_off", Vector2(0, 34), 0.12).set_ease(Tween.EASE_IN)
	match move:
		Move.LEFT:
			tw.tween_property(self, "_weapon", -2.0 * PI - 0.5, 0.16).set_ease(Tween.EASE_IN)
		Move.RIGHT:
			tw.tween_property(self, "_weapon", PI + 0.5, 0.16).set_ease(Tween.EASE_IN)
		Move.OVERHEAD:
			tw.tween_property(self, "_reach", -1.4, 0.16).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_impact.bind(correct))
	Audio.play_sfx("duel_swing")


func _impact(correct: bool) -> void:
	_glow = 0.0
	_weapon = wrapf(_weapon, -1.5 * PI, 0.5 * PI)
	if correct:
		if answer == Answer.BLOCK:
			_shake = 7.0
			_white = 0.5
			_text(Vector2(180, 380), "CLANG!", Palette.GOLD, 20, 0.7)
			Audio.play_sfx("duel_clang")
		else:
			_text(Vector2(180, 380), "DODGED!", Palette.PARCHMENT, 18, 0.7)
			Audio.play_sfx("duel_whoosh")
		_hurt_boss(COUNTER_DAMAGE)
		# thrown off balance: open for a counter-attack
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "_boss_lean", 0.06, 0.25)
		tw.tween_property(self, "_boss_scale", Vector2(1.06, 0.95), 0.25)
		tw.tween_property(self, "_boss_off", Vector2(0, 12), 0.25)
		tw.tween_property(self, "_reach", 1.0, 0.25)
		tw.tween_property(self, "_view_x", 0.0, 0.3).set_delay(0.1)
		tw.tween_property(self, "_shield", 0.0, 0.25).set_delay(0.1)
		if stagger >= _data.stagger:
			_finisher()
			return
		stage = Stage.STRIKE
		_timer = STRIKE_TIME
		_text(Vector2(180, 250), "STRIKE!", Palette.GOLD, 26, 0.8)
		return
	# hit
	hp -= 1
	_red = 1.0
	_shake = 16.0
	_add_crack()
	_text(Vector2(180, 360), "OOF!" if hp > 0 else "KNOCKED DOWN!", Palette.RED_LIGHT, 20, 0.9)
	Audio.play_sfx("duel_hurt")
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_jolt", 1.0, 0.08)
	tw.chain().tween_property(self, "_jolt", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_view_x", 0.0, 0.3)
	tw.parallel().tween_property(self, "_shield", 0.0, 0.3)
	_recover(0.5)
	if hp <= 0:
		_end.call_deferred(false)
		return
	stage = Stage.WAIT
	_timer = 0.9


func _recover(dur: float) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_boss_lean", 0.0, dur)
	tw.tween_property(self, "_weapon", -1.2, dur)
	tw.tween_property(self, "_reach", 1.0, dur)
	tw.tween_property(self, "_boss_scale", Vector2.ONE, dur)
	tw.tween_property(self, "_boss_off", Vector2.ZERO, dur)


## A tap during the strike window: the Champion's sword connects.
func _strike(p: Vector2) -> void:
	_hurt_boss(TAP_DAMAGE)
	_shake = 4.0
	var tw := create_tween()
	tw.tween_property(self, "_swing", 1.0, 0.05)
	tw.tween_property(self, "_swing", 0.0, 0.12)
	_text(p + Vector2(0, -20), "HIT!", Palette.GOLD, 12, 0.4)
	Audio.play_sfx("duel_hit")
	if stagger >= _data.stagger:
		_finisher()


func _hurt_boss(amount: float) -> void:
	stagger = minf(_data.stagger, stagger + amount)
	_boss_flash = 1.0
	_wounds.append({"pos": Vector2(randf_range(-50, 50), randf_range(-230, -70)), "r": randf_range(4, 9),
		"rot": randf() * TAU})
	if _wounds.size() > 40:
		_wounds.pop_front()
	var s := _boss_scale
	var tw := create_tween()
	tw.tween_property(self, "_boss_scale", s * Vector2(1.06, 0.94), 0.04)
	tw.tween_property(self, "_boss_scale", s, 0.1)


func _finisher() -> void:
	stage = Stage.FINISHER
	_text(Vector2(180, 250), "FOLD IT!", Palette.GOLD, 30, 1.4)
	_text(Vector2(180, 280), "drag the page's edge over him", Palette.PARCHMENT, 12, 2.5)
	Audio.play_sfx("duel_stagger")
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_boss_lean", 0.1, 0.4)
	tw.tween_property(self, "_weapon", 1.3, 0.4)
	tw.tween_property(self, "_reach", 1.0, 0.4)
	tw.tween_property(self, "_boss_off", Vector2(0, 16), 0.4)
	tw.tween_property(self, "_view_x", 0.0, 0.3)
	tw.tween_property(self, "_shield", 0.0, 0.3)


func _slam() -> void:
	stage = Stage.SLAM
	_texts.clear()
	_white = 1.0
	_shake = 24.0
	Audio.play_sfx("slam")
	Audio.play_sfx("crush")
	var chest := FEET + CHEST
	for i in 26:
		var d := Vector2.from_angle(randf() * TAU) * randf_range(20, 190) * Vector2(1.0, 1.4)
		_splash.append({"pos": chest + d, "r": randf_range(5, 20) * (1.0 - d.length() / 300.0), "rot": randf() * TAU})
	var tw := create_tween()
	tw.tween_property(self, "_flat", 1.0, 0.06)
	tw.tween_interval(0.45)
	tw.tween_method(func(v: Vector2): _pointer = v, _pointer, _grab, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _grab = Vector2.INF)
	tw.tween_callback(_end.bind(true))
	_text(Vector2(180, 240), "FOLDED!", Palette.GOLD, 34, 1.2)


func _end(result: bool) -> void:
	if stage == Stage.OUTRO:
		return
	stage = Stage.OUTRO
	won = result
	_texts.clear()
	_text(Vector2(180, 300), "VICTORY!" if won else "KNOCKED OUT!", Palette.GOLD if won else Palette.RED_LIGHT, 30, 2.2, 0.0)
	_text(Vector2(180, 332), _data.win if won else _data.lose, Palette.PARCHMENT, 12, 2.2, 0.0)
	if not won:
		var tw0 := create_tween().set_parallel()
		tw0.tween_property(self, "_boss_scale", Vector2(1.12, 1.12), 0.5)
		tw0.tween_property(self, "_weapon", -PI * 0.5 - 0.3, 0.5)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(self, "_fade", 0.0, 0.35)
	tw.tween_callback(_finish)


func _finish() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	Events.duel_finished.emit(won)
	finished.emit(won)
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	_boss_flash = maxf(0.0, _boss_flash - delta * 6.0)
	_red = maxf(0.0, _red - delta * 2.5)
	_white = maxf(0.0, _white - delta * 3.0)
	_shake = maxf(0.0, _shake - delta * 50.0)
	for i in range(_texts.size() - 1, -1, -1):
		var tx: Dictionary = _texts[i]
		tx.t += delta
		tx.pos.y -= tx.rise * delta
		if tx.t >= tx.life:
			_texts.remove_at(i)
	match stage:
		Stage.TELL:
			_timer -= delta
			if _fake_at > 0.0 and _timer <= _fake_at:
				_fake_at = -1.0
				shown = move
				_windup(move, 0.14)
				_text(Vector2(180, 200), "!", Palette.RED_LIGHT, 34, 0.4)
			if _timer <= 0.0:
				_attack()
		Stage.STRIKE:
			_timer -= delta
			if _timer <= 0.0:
				stage = Stage.WAIT
				_timer = 0.35
				_recover(0.3)
		Stage.WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_next_round()
	_ctl.modulate.a = _fade
	_ctl.queue_redraw()


# --- input ----------------------------------------------------------------------------

func _page_origin() -> Vector2:
	return ((_ctl.size - PAGE) * 0.5).floor()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position - _page_origin()
		if event.pressed:
			_press = p
			_swiped = false
			if stage == Stage.STRIKE:
				_strike(p)
			elif stage == Stage.FINISHER:
				_begin_fold(p)
		else:
			if stage == Stage.FINISHER and _grab.is_finite():
				_release_fold()
			_press = Vector2.INF
	elif event is InputEventMouseMotion:
		var p: Vector2 = event.position - _page_origin()
		if stage == Stage.FINISHER and _grab.is_finite():
			_pointer = p.clamp(Vector2.ZERO, PAGE)
		elif _press.is_finite() and not _swiped and p.distance_to(_press) > SWIPE_MIN:
			_swiped = true
			swipe(p - _press)


## A swipe during the wind-up: commit to a dodge or raise the shield.
func swipe(d: Vector2) -> void:
	if stage != Stage.TELL or answer != Answer.NONE:
		return
	if absf(d.x) > absf(d.y):
		answer = Answer.DODGE_RIGHT if d.x > 0.0 else Answer.DODGE_LEFT
	elif d.y < 0.0:
		answer = Answer.BLOCK
	else:
		return
	var tw := create_tween()
	match answer:
		Answer.DODGE_RIGHT:
			tw.tween_property(self, "_view_x", -80.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Answer.DODGE_LEFT:
			tw.tween_property(self, "_view_x", 80.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Answer.BLOCK:
			tw.tween_property(self, "_shield", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_sfx("duel_dodge")


func _begin_fold(p: Vector2) -> void:
	var g := p
	if p.x < EDGE_GRAB:
		g.x = 0.0
	elif p.x > PAGE.x - EDGE_GRAB:
		g.x = PAGE.x
	elif p.y < EDGE_GRAB:
		g.y = 0.0
	elif p.y > PAGE.y - EDGE_GRAB:
		g.y = PAGE.y
	else:
		return
	_grab = g
	_pointer = p
	Audio.play_sfx("paper_grab")


## True when the flap (grab -> pointer) lands on the boss's chest.
func fold_covers_boss() -> bool:
	if not _grab.is_finite() or _grab.distance_to(_pointer) < 40.0:
		return false
	var m := FoldMath.line_point(_grab, _pointer)
	var n := FoldMath.normal(_grab, _pointer)
	var chest := FEET + CHEST
	return FoldMath.side(chest, m, n) < 0.0 and Rect2(Vector2.ZERO, PAGE).has_point(FoldMath.mirror(chest, m, n))


func _release_fold() -> void:
	if fold_covers_boss():
		_slam()
		return
	_text(Vector2(180, 250), "COVER HIM WITH THE PAGE!", Palette.PARCHMENT, 13, 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: Vector2): _pointer = v, _pointer, _grab, 0.18)
	tw.tween_callback(func(): _grab = Vector2.INF)


# --- juice helpers --------------------------------------------------------------------

func _text(pos: Vector2, msg: String, color: Color, size: int, life: float, rise := 20.0) -> void:
	_texts.append({"pos": pos, "msg": msg, "color": color, "size": size, "life": life, "t": 0.0, "rise": rise})


func _add_crack() -> void:
	var start := Vector2(randf_range(40, 320), randf_range(120, 520))
	for k in 3:
		var pts := PackedVector2Array([start])
		var dir := Vector2.from_angle(randf() * TAU)
		for i in 5:
			dir = dir.rotated(randf_range(-0.6, 0.6))
			pts.append(pts[-1] + dir * randf_range(14, 30))
		_cracks.append(pts)
	while _cracks.size() > 12:
		_cracks.pop_front()


# --- drawing --------------------------------------------------------------------------

func _draw_all() -> void:
	var vis := _ctl.size
	_ctl.draw_rect(Rect2(Vector2.ZERO, vis), Color(Palette.TABLE, 0.92))
	_o = _page_origin() + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_ctl.draw_set_transform(_o)
	_draw_bg()
	_draw_boss()
	_draw_telegraph()
	_draw_splash()
	_draw_champion()
	_draw_hint()
	_draw_fold()
	_ctl.draw_set_transform(_o)
	for c in _cracks:
		_ctl.draw_polyline(c, Color(Palette.INK, 0.75), 2.0)
	if _red > 0.0:
		_ctl.draw_rect(Rect2(Vector2.ZERO, PAGE), Color(Palette.RED, 0.5 * _red))
	if _white > 0.0:
		_ctl.draw_rect(Rect2(Vector2.ZERO, PAGE), Color(1, 1, 1, 0.8 * _white))
	_draw_hud()
	for tx in _texts:
		_draw_text(tx)
	_ctl.draw_set_transform(Vector2.ZERO)


func _draw_bg() -> void:
	var c := _ctl
	var px := _view_x * 0.35
	if _tex.bg:
		c.draw_texture_rect(_tex.bg, Rect2(Vector2(px - 30, 0), PAGE + Vector2(60, 0)), false)
	else:
		# a painted sky over the plain before your castle
		for i in 20:
			var y := i * 20.0
			c.draw_rect(Rect2(0, y, PAGE.x, 21), Palette.PARCHMENT.lerp(Color("#f3e7c6"), i / 20.0))
		var hills := PackedVector2Array([Vector2(-40, 400)])
		for i in 9:
			hills.append(Vector2(-40 + i * 55 + px * 0.6, 356 - sin(i * 1.7) * 18))
		hills.append(Vector2(440, 400))
		c.draw_colored_polygon(hills, Color(Palette.PARCHMENT_SHADOW, 0.55))
		# your Keep on the horizon, behind the Champion
		var k := Vector2(60 + px, 372)
		c.draw_rect(Rect2(k + Vector2(-22, -26), Vector2(44, 26)), Color(Palette.SEPIA, 0.7))
		for x in [-26.0, 16.0]:
			c.draw_rect(Rect2(k + Vector2(x, -38), Vector2(10, 38)), Color(Palette.SEPIA, 0.7))
		c.draw_line(k + Vector2(0, -26), k + Vector2(0, -44), Color(Palette.SEPIA, 0.7), 1.0)
		c.draw_rect(Rect2(k + Vector2(1, -44), Vector2(9, 5)), Color(Palette.BLUE, 0.7))
		c.draw_rect(Rect2(0, 390, PAGE.x, PAGE.y - 390), Palette.PARCHMENT_MID)
		# ink hatching running to the horizon
		var vp := Vector2(180 + px * 1.5, 390)
		for i in 13:
			var x := -300.0 + i * 80.0 + _view_x * 1.2
			c.draw_line(vp.lerp(Vector2(x, PAGE.y), 0.08), Vector2(x, PAGE.y), Color(Palette.SEPIA, 0.25), 1.0)
		for i in 6:
			var y := 390.0 + pow(i / 6.0, 2.0) * 250.0 + 6.0
			c.draw_line(Vector2(0, y), Vector2(PAGE.x, y), Color(Palette.SEPIA, 0.15), 1.0)
	c.draw_rect(Rect2(Vector2(6, 6), PAGE - Vector2(12, 12)), Palette.SEPIA, false, 1.0)
	c.draw_rect(Rect2(Vector2(9, 9), PAGE - Vector2(18, 18)), Color(Palette.SEPIA, 0.5), false, 1.0)


func _boss_pose() -> String:
	if _boss_flash > 0.0 or stage == Stage.STRIKE or stage == Stage.FINISHER or _flat > 0.0:
		return "hurt"
	return "windup" if stage == Stage.TELL else "idle"


func _draw_boss() -> void:
	var c := _ctl
	var pos := FEET + _boss_off + Vector2(_view_x, 0)
	var breathe := 1.0 + sin(_t * 2.2) * 0.012
	var scl := _boss_scale * Vector2(1.0 + 0.5 * _flat, breathe * (1.0 - 0.88 * _flat))
	# shadow
	c.draw_set_transform(_o + pos + Vector2(0, 4), 0.0, Vector2(1.0, 0.22))
	c.draw_circle(Vector2.ZERO, 95.0 * scl.x, Color(Palette.INK, 0.25))
	c.draw_set_transform(_o + pos, _boss_lean, scl)
	var tex: Texture2D = _tex.get(_boss_pose())
	if tex:
		var h := 300.0
		var w := tex.get_size().x * h / tex.get_size().y
		var mod := Color(2.0, 2.0, 2.0) if _boss_flash > 0.5 else Color.WHITE
		c.draw_texture_rect(tex, Rect2(-w * 0.5, -h, w, h), false, mod)
	else:
		_draw_boss_body()
	for w in _wounds:
		_splat(w.pos, w.r, w.rot, Color(Palette.INK, 0.85))
	if stage == Stage.STRIKE or stage == Stage.FINISHER:
		for i in 4:
			var a := _t * 5.0 + i * TAU / 4.0
			c.draw_circle(Vector2(cos(a) * 44.0, -268.0 + sin(a) * 9.0), 4.0, Palette.GOLD)
	c.draw_set_transform(_o)


func _tint(col: Color) -> Color:
	return col.lerp(Color.WHITE, _boss_flash * 0.75)


## Placeholder boss: a towering armored figure seen from the front.
func _draw_boss_body() -> void:
	var c := _ctl
	var armor: Color = _tint(_data.armor)
	var cloth: Color = _tint(_data.cloth)
	var ink := _tint(Palette.INK)
	# cape
	c.draw_colored_polygon(PackedVector2Array([Vector2(-72, -205), Vector2(72, -205), Vector2(92, -12), Vector2(-92, -12)]), cloth)
	# legs and boots
	for sx in [-1.0, 1.0]:
		c.draw_rect(Rect2(sx * 26 - 17, -95, 34, 90), ink)
		c.draw_rect(Rect2(sx * 26 - 13, -91, 26, 72), armor)
		c.draw_rect(Rect2(sx * 26 - 22, -14, 44, 16), ink)
	# torso
	c.draw_colored_polygon(PackedVector2Array([Vector2(-66, -212), Vector2(66, -212), Vector2(50, -86), Vector2(-50, -86)]), ink)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-59, -206), Vector2(59, -206), Vector2(45, -92), Vector2(-45, -92)]), armor)
	c.draw_line(Vector2(0, -204), Vector2(0, -94), Color(ink, 0.5), 2.0)
	for y in [-176.0, -146.0, -118.0]:
		c.draw_line(Vector2(-50, y), Vector2(50, y), Color(ink, 0.35), 2.0)
	c.draw_rect(Rect2(-54, -98, 108, 14), ink)
	c.draw_rect(Rect2(-9, -99, 18, 16), _tint(Palette.GOLD))
	# pauldrons
	for sx in [-1.0, 1.0]:
		c.draw_circle(Vector2(sx * 66, -204), 30.0, ink)
		c.draw_circle(Vector2(sx * 66, -204), 25.0, armor)
		c.draw_circle(Vector2(sx * 60, -212), 8.0, Color(1, 1, 1, 0.18))
	# head
	var head := Vector2(0, -250)
	if _data.weapon == "axe":
		for sx in [-1.0, 1.0]:
			c.draw_colored_polygon(PackedVector2Array([head + Vector2(sx * 24, -14), head + Vector2(sx * 70, -62),
				head + Vector2(sx * 56, -40), head + Vector2(sx * 30, 6)]), _tint(Palette.PARCHMENT_MID))
		c.draw_circle(head, 36.0, ink)
		c.draw_circle(head, 31.0, armor)
		c.draw_rect(Rect2(head + Vector2(-30, -2), Vector2(60, 7)), ink)
	else:
		# a leather hood and brass goggles
		c.draw_circle(head, 36.0, ink)
		c.draw_circle(head, 31.0, cloth)
		c.draw_circle(head + Vector2(0, 8), 22.0, _tint(Color("#c9a27a")))
		c.draw_rect(Rect2(head + Vector2(-30, -6), Vector2(60, 8)), ink)
	var glow := Color(Palette.RED_LIGHT, 0.7 + 0.3 * sin(_t * 8.0))
	for sx in [-1.0, 1.0]:
		c.draw_circle(head + Vector2(sx * 12, 1), 5.0 if _data.weapon == "axe" else 8.0, ink if _data.weapon == "axe" else _tint(Palette.GOLD))
		c.draw_circle(head + Vector2(sx * 12, 1), 3.0, glow)
	_draw_weapon()


func _draw_weapon() -> void:
	var c := _ctl
	var ink := _tint(Palette.INK)
	var hands := Vector2(0, -150)
	var d := Vector2.from_angle(_weapon)
	var close := maxf(0.0, -_reach) ## how far it swings out at the camera
	var tip := hands + d * 175.0 * _reach
	var butt := hands - d * 40.0 * signf(_reach)
	c.draw_line(butt, tip, ink, 11.0 + close * 6.0)
	c.draw_line(butt, tip, _tint(Palette.SEPIA), 7.0 + close * 4.0)
	var s := 1.0 + close * 0.9
	var side := d.orthogonal() * s
	var along := d * signf(_reach) * s
	if _data.weapon == "axe":
		var blade := PackedVector2Array([tip - along * 8.0, tip - along * 40.0 + side * 12.0, tip - along * 50.0 + side * 58.0,
			tip - along * 20.0 + side * 70.0, tip + along * 6.0 + side * 60.0, tip + along * 2.0 + side * 12.0])
		c.draw_colored_polygon(blade, ink)
		c.draw_polyline(blade, _tint(STEEL), 3.0)
	else:
		var r := 34.0 * s
		var block := PackedVector2Array([tip + side * r + along * 22.0 * s, tip - side * r + along * 22.0 * s,
			tip - side * r - along * 22.0 * s, tip + side * r - along * 22.0 * s])
		c.draw_colored_polygon(block, ink)
		c.draw_polyline(block, _tint(Palette.SEPIA), 3.0)
	# gauntlets on the haft
	c.draw_circle(hands + d * 6.0 * _reach, 15.0, ink)
	c.draw_circle(hands + d * 6.0 * _reach, 11.0, _tint(_data.armor))
	c.draw_circle(hands + d * 34.0 * _reach, 14.0, ink)
	c.draw_circle(hands + d * 34.0 * _reach, 10.0, _tint(_data.armor))


func _splat(p: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		pts.append(p + Vector2.from_angle(rot + TAU * k / 10.0) * r * (1.0 if k % 2 == 0 else 0.55))
	_ctl.draw_colored_polygon(pts, col)


func _draw_splash() -> void:
	if _splash.is_empty():
		return
	_ctl.draw_set_transform(_o + Vector2(_view_x, 0))
	for s in _splash:
		_splat(s.pos, s.r, s.rot, Color(Palette.RED, 0.9))
	_ctl.draw_set_transform(_o)


## Where the blow comes from: a red glow on that side, and (early rounds) the answer arrow.
func _draw_telegraph() -> void:
	if stage != Stage.TELL:
		return
	var c := _ctl
	var pulse := 0.6 + 0.4 * sin(_t * 18.0)
	for i in 8:
		var a := 0.07 * (8 - i) * pulse
		var w := 10.0
		match shown:
			Move.LEFT:
				c.draw_rect(Rect2(i * w, 0, w, PAGE.y), Color(Palette.RED, a))
			Move.RIGHT:
				c.draw_rect(Rect2(PAGE.x - (i + 1) * w, 0, w, PAGE.y), Color(Palette.RED, a))
			Move.OVERHEAD:
				c.draw_rect(Rect2(0, i * w, PAGE.x, w), Color(Palette.RED, a))



## The answer arrow for the first rounds (drawn above the Champion's hands).
func _draw_hint() -> void:
	var c := _ctl
	if stage == Stage.TELL and round_no <= HINT_ROUNDS and answer == Answer.NONE:
		var ans := answer_for(shown)
		var dir := Vector2.UP if ans == Answer.BLOCK else (Vector2.RIGHT if ans == Answer.DODGE_RIGHT else Vector2.LEFT)
		var ctr := Vector2(180, 500) + dir * sin(_t * 8.0) * 8.0
		var col := Color(Palette.PARCHMENT, 0.95)
		c.draw_line(ctr - dir * 34.0, ctr + dir * 34.0, Palette.INK, 12.0)
		c.draw_line(ctr - dir * 34.0, ctr + dir * 34.0, col, 7.0)
		var tip := ctr + dir * 44.0
		var tri := PackedVector2Array([tip, tip - dir * 22.0 + dir.orthogonal() * 18.0, tip - dir * 22.0 - dir.orthogonal() * 18.0])
		c.draw_colored_polygon(tri, col)
		c.draw_polyline(tri + PackedVector2Array([tip]), Palette.INK, 2.0)
		var label := "SHIELD UP!" if ans == Answer.BLOCK else "DODGE!"
		_draw_text({"pos": Vector2(180, 556), "msg": "SWIPE: " + label, "color": Palette.PARCHMENT, "size": 14, "t": 0.0, "life": 1.0})


func _draw_champion() -> void:
	var c := _ctl
	var sway := Vector2(-_view_x * 0.25, sin(_t * 2.0) * 2.0 + _jolt * 40.0)
	# sword arm, bottom right
	var ang := -0.22 - _swing * 0.8
	var base := Vector2(330, 700) + sway + Vector2(-_swing * 60.0, -_swing * 60.0) + Vector2(0, _shield * 30.0)
	c.draw_set_transform(_o + base, ang, Vector2.ONE * 0.85)
	if _tex.arm:
		var t: Texture2D = _tex.arm
		var h := 420.0
		var w := t.get_size().x * h / t.get_size().y
		c.draw_texture_rect(t, Rect2(-w * 0.5, -h, w, h), false)
	else:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-30, 20), Vector2(30, 20), Vector2(22, -150), Vector2(-22, -150)]), Palette.INK)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-25, 16), Vector2(25, 16), Vector2(17, -146), Vector2(-17, -146)]), Color("#8e919b"))
		for y in [-30.0, -70.0, -110.0]:
			c.draw_line(Vector2(-22, y), Vector2(22, y - 4), Color(Palette.INK, 0.5), 2.0)
		# blade, crossguard, grip, gauntlet
		c.draw_colored_polygon(PackedVector2Array([Vector2(-11, -205), Vector2(11, -205), Vector2(8, -400), Vector2(0, -428), Vector2(-8, -400)]), Palette.INK)
		c.draw_colored_polygon(PackedVector2Array([Vector2(-8, -205), Vector2(8, -205), Vector2(5, -398), Vector2(0, -420), Vector2(-5, -398)]), STEEL)
		c.draw_line(Vector2(0, -210), Vector2(0, -395), Color(1, 1, 1, 0.6), 2.0)
		c.draw_rect(Rect2(-46, -210, 92, 14), Palette.INK)
		c.draw_rect(Rect2(-43, -207, 86, 8), Palette.GOLD)
		c.draw_circle(Vector2(0, -170), 30.0, Palette.INK)
		c.draw_circle(Vector2(0, -170), 25.0, Color("#8e919b"))
		for i in 4:
			c.draw_rect(Rect2(-22 + i * 11, -196, 10, 12), Palette.INK)
			c.draw_rect(Rect2(-20 + i * 11, -194, 6, 8), STEEL)
	# shield, bottom left (raised to cover the face on BLOCK)
	var spos := Vector2(62, 590).lerp(Vector2(180, 430), _shield) + sway * Vector2(1.0, 1.0 - _shield)
	var srot := lerpf(0.22, 0.0, _shield)
	var sscl := Vector2.ONE * lerpf(1.0, 1.55, _shield)
	c.draw_set_transform(_o + spos, srot, sscl)
	if _tex.shield:
		var t: Texture2D = _tex.shield
		var h := 180.0
		var w := t.get_size().x * h / t.get_size().y
		c.draw_texture_rect(t, Rect2(-w * 0.5, -h * 0.5, w, h), false)
	else:
		var outline := PackedVector2Array([Vector2(-66, -78), Vector2(66, -78), Vector2(66, 8), Vector2(40, 60), Vector2(0, 92),
			Vector2(-40, 60), Vector2(-66, 8)])
		c.draw_colored_polygon(outline, Palette.INK)
		var inner := PackedVector2Array()
		for p in outline:
			inner.append(p * 0.9 + Vector2(0, -2))
		c.draw_colored_polygon(inner, Palette.GOLD)
		var field := PackedVector2Array()
		for p in outline:
			field.append(p * 0.8 + Vector2(0, -4))
		c.draw_colored_polygon(field, Palette.BLUE)
		# the King's keep on the shield
		c.draw_rect(Rect2(-22, -24, 44, 32), Palette.GOLD)
		for x in [-26.0, 14.0]:
			c.draw_rect(Rect2(x, -40, 12, 48), Palette.GOLD)
		c.draw_rect(Rect2(-6, -6, 12, 14), Palette.BLUE)
		c.draw_line(Vector2(-60, -60), Vector2(-30, -74), Color(1, 1, 1, 0.3), 3.0)
	c.draw_set_transform(_o)


## The finisher fold: the lifted part of the page shows the table; its back lands mirrored.
func _draw_fold() -> void:
	var c := _ctl
	if stage == Stage.FINISHER and not _grab.is_finite():
		# glowing edges + a hint arrow from the right edge
		var a := 0.35 + 0.35 * sin(_t * 6.0)
		for i in 4:
			var w := 5.0 * (4 - i)
			c.draw_rect(Rect2(Vector2.ZERO, PAGE).grow(-w * 0.5), Color(Palette.GOLD, a * 0.35), false, w)
		var k := fmod(_t * 0.8, 1.0)
		var from := Vector2(350, 330)
		var to := Vector2(90, 330)
		c.draw_dashed_line(from, to, Color(Palette.GOLD, 0.8), 3.0, 10.0)
		c.draw_circle(from.lerp(to, k), 11.0, Palette.INK)
		c.draw_circle(from.lerp(to, k), 8.0, Palette.PARCHMENT)
	if not _grab.is_finite() or _grab.distance_to(_pointer) < 2.0:
		return
	var m := FoldMath.line_point(_grab, _pointer)
	var n := FoldMath.normal(_grab, _pointer)
	var rect := PackedVector2Array([Vector2.ZERO, Vector2(PAGE.x, 0), PAGE, Vector2(0, PAGE.y)])
	var flap := _clip(rect, m, n)
	if flap.size() < 3:
		return
	c.draw_colored_polygon(flap, Palette.TABLE)
	var back := PackedVector2Array()
	for p in flap:
		back.append(FoldMath.mirror(p, m, n))
	c.draw_colored_polygon(back, Palette.PARCHMENT_MID if stage != Stage.SLAM else Palette.PARCHMENT)
	# shading toward the crease + outline
	c.draw_polyline(back + PackedVector2Array([back[0]]), Palette.SEPIA, 2.0)
	var t := n.orthogonal()
	c.draw_line(m - t * 800.0, m + t * 800.0, Color(Palette.INK, 0.35), 3.0)
	if fold_covers_boss() and stage == Stage.FINISHER:
		var chest := FEET + CHEST + Vector2(_view_x, 0)
		c.draw_arc(chest, 30.0 + 4.0 * sin(_t * 12.0), 0.0, TAU, 24, Palette.RED, 3.0)


## The part of a convex polygon on the flap side of the line (m, n).
static func _clip(poly: PackedVector2Array, m: Vector2, n: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var da := FoldMath.side(a, m, n)
		var db := FoldMath.side(b, m, n)
		if da > 0.0:
			out.append(a)
		if (da > 0.0) != (db > 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


func _draw_hud() -> void:
	var c := _ctl
	# boss name + stagger bar
	_draw_text({"pos": Vector2(180, 30), "msg": _data.name, "color": Palette.RED_LIGHT, "size": 14, "t": 0.0, "life": 1.0})
	var bar := Rect2(50, 42, 260, 14)
	c.draw_rect(bar.grow(3), Palette.INK)
	c.draw_rect(bar, Color(Palette.PARCHMENT_SHADOW, 0.8))
	var f := stagger / float(_data.stagger)
	var full := f >= 1.0
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)),
		Palette.GOLD.lerp(Color.WHITE, 0.4 * (0.5 + 0.5 * sin(_t * 12.0))) if full else Palette.GOLD)
	_draw_text({"pos": Vector2(180, 70), "msg": "STAGGERED!" if full else "STAGGER", "color": Palette.PARCHMENT, "size": 9, "t": 0.0, "life": 1.0})
	# the Champion's hearts
	for i in CHAMPION_HP:
		var p := Vector2(152 + i * 28, 618)
		var col := Palette.RED_LIGHT if i < hp else Color(Palette.INK, 0.5)
		c.draw_circle(p + Vector2(-5, -3), 7.0, Palette.INK)
		c.draw_circle(p + Vector2(5, -3), 7.0, Palette.INK)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, -1), p + Vector2(12, -1), p + Vector2(0, 13)]), Palette.INK)
		c.draw_circle(p + Vector2(-5, -3), 5.0, col)
		c.draw_circle(p + Vector2(5, -3), 5.0, col)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-9.5, -1), p + Vector2(9.5, -1), p + Vector2(0, 10)]), col)
	if stage == Stage.STRIKE:
		var k := _timer / STRIKE_TIME
		c.draw_rect(Rect2(110, 292, 140, 6), Color(Palette.INK, 0.6))
		c.draw_rect(Rect2(110, 292, 140 * k, 6), Palette.GOLD)
		var pop := 1.0 + 0.08 * sin(_t * 30.0)
		_draw_text({"pos": Vector2(180, 318), "msg": "TAP! TAP! TAP!", "color": Palette.GOLD, "size": int(16 * pop), "t": 0.0, "life": 1.0})


func _draw_text(tx: Dictionary) -> void:
	var size: int = tx.size
	var k: float = tx.t / tx.life
	var a := clampf((1.0 - k) * 4.0, 0.0, 1.0)
	var msg: String = tx.msg
	var w := _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p: Vector2 = tx.pos + Vector2(-w * 0.5, size * 0.35)
	_ctl.draw_string_outline(_font, p, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(3, size / 4), Color(Palette.INK, a))
	_ctl.draw_string(_font, p, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(tx.color, a))
