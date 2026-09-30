extends Node
const WeatherAudio := preload("res://scripts/autoload/weather_audio.gd")
## Global music and sound effects. Missing human-made assets are intentionally silent.

const MUSIC_NAMES := ["menu", "battle", "boss", "victory", "defeat"]
const SFX_NAMES := [
	"paper_grab", "paper_fold", "slam", "crush", "splat", "stamp",
	"ink_gain", "keep_hit", "wave_horn", "tear", "ui_click", "ui_cancel", "pin", "pin_block",
	"duel_windup", "duel_swing", "duel_clang", "duel_whoosh", "duel_hurt", "duel_hit",
	"duel_stagger", "duel_dodge", "baa", "thunder", "wind_gust",
]
## Looping weather beds in `assets/audio/ambience/` (Weather sets one per wave).
const AMBIENCE_NAMES := ["rain", "storm"]
const AMBIENCE_VOLUME_DB := -12.0
const AMBIENCE_FADE := 2.0
## Alternate takes `<name>_2`, `<name>_3`, ... are picked at random when present.
const MAX_VARIANTS := 4
const SFX_POOL_SIZE := 8
const MUSIC_VOLUME_DB := -14.0
const SFX_VOLUME_DB := -5.0
const CROSSFADE_SECONDS := 0.8
const SILENCE_DB := -60.0
const BOSS_CHECK_SECONDS := 0.5

var _streams: Dictionary = {}
var _variant_counts: Dictionary = {} ## sfx name -> how many takes exist
var _music_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _ambience_tween: Tween
var _active_music := -1
var _outgoing_music := -1
var _current_track := ""
var _fade_time := CROSSFADE_SECONDS
var _outgoing_gain := 0.0
var _next_sfx_player := 0
var _last_ink := -1
var _phase := ""
var _boss_check := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.volume_db = SILENCE_DB
		add_child(player)
		_music_players.append(player)
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.volume_db = SFX_VOLUME_DB
		add_child(player)
		_sfx_players.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.volume_db = SILENCE_DB
	add_child(_ambience)
	Events.phase_changed.connect(_on_phase_changed)
	Events.slammed.connect(_on_slammed)
	Events.unit_crushed.connect(_on_unit_crushed)
	Events.building_placed.connect(_on_building_placed)
	Events.ink_changed.connect(_on_ink_changed)
	Events.keep_hit.connect(_on_keep_hit)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.decree_chosen.connect(_on_decree_chosen)
	Events.start_wave_requested.connect(_on_start_wave_requested)
	Events.restart_requested.connect(_on_restart_requested)
	play_music("menu")


func _process(delta: float) -> void:
	_boss_check -= delta
	if _boss_check <= 0.0:
		_boss_check = BOSS_CHECK_SECONDS
		_check_boss_gone()
	if _fade_time >= CROSSFADE_SECONDS:
		return
	_fade_time = minf(_fade_time + delta, CROSSFADE_SECONDS)
	var blend := _fade_time / CROSSFADE_SECONDS
	if _active_music >= 0:
		_set_music_gain(_music_players[_active_music], sin(blend * PI * 0.5))
	if _outgoing_music >= 0:
		_set_music_gain(_music_players[_outgoing_music], _outgoing_gain * cos(blend * PI * 0.5))
		if _fade_time >= CROSSFADE_SECONDS:
			_music_players[_outgoing_music].stop()
			_outgoing_music = -1


func play_music(name: String) -> void:
	if not MUSIC_NAMES.has(name):
		return
	if name == _current_track and _active_music >= 0 and _music_players[_active_music].playing:
		return
	var stream := _get_stream("music", name, ["mp3", "ogg", "wav"])
	if stream == null:
		stop_music()
		return
	if _outgoing_music >= 0:
		_music_players[_outgoing_music].stop()
		_outgoing_music = -1
	if _active_music >= 0:
		_outgoing_music = _active_music
		_outgoing_gain = db_to_linear(_music_players[_outgoing_music].volume_db - MUSIC_VOLUME_DB)
	_active_music = 1 - _active_music if _active_music >= 0 else 0
	var player := _music_players[_active_music]
	player.stop()
	player.stream = stream
	_set_music_gain(player, 0.0)
	_start_player(player)
	_current_track = name
	_fade_time = 0.0


## Fades the looping weather bed to `name` ("" = silence). Missing files stay silent.
func set_ambience(name: String) -> void:
	var stream: AudioStream = _get_stream("ambience", name, ["ogg", "wav", "mp3"]) if AMBIENCE_NAMES.has(name) else null
	if stream != null and _ambience.playing and _ambience.stream == stream:
		return
	if _ambience_tween:
		_ambience_tween.kill()
	_ambience_tween = create_tween()
	if _ambience.playing:
		_ambience_tween.tween_property(_ambience, "volume_db", SILENCE_DB, AMBIENCE_FADE * 0.5)
	_ambience_tween.tween_callback(func():
		_ambience.stop()
		if stream != null:
			_ambience.stream = stream
			_start_player(_ambience))
	if stream != null:
		_ambience_tween.tween_property(_ambience, "volume_db", AMBIENCE_VOLUME_DB, AMBIENCE_FADE)


func stop_music() -> void:
	if _outgoing_music >= 0:
		_music_players[_outgoing_music].stop()
		_outgoing_music = -1
	if _active_music >= 0:
		_outgoing_music = _active_music
		_outgoing_gain = db_to_linear(_music_players[_outgoing_music].volume_db - MUSIC_VOLUME_DB)
		_active_music = -1
		_fade_time = 0.0
	_current_track = ""


## `volume_db` is relative to the normal SFX volume.
func play_sfx(name: String, volume_db := 0.0) -> void:
	if not SFX_NAMES.has(name):
		return
	var stream := _get_stream("sfx", _pick_variant(name), ["ogg", "wav", "mp3"])
	if stream == null:
		return
	var chosen := _next_sfx_player
	for offset in SFX_POOL_SIZE:
		var index := (_next_sfx_player + offset) % SFX_POOL_SIZE
		if not _sfx_players[index].playing:
			chosen = index
			break
	_next_sfx_player = (chosen + 1) % SFX_POOL_SIZE
	var player := _sfx_players[chosen]
	player.stop()
	player.stream = stream
	player.volume_db = SFX_VOLUME_DB + volume_db
	_start_player(player)


## The headless Dummy audio server never mixes; creating playback there retains Ogg
## decoders until process exit. Keep loading streams for validation, skip silent playback.
func _start_player(player: AudioStreamPlayer) -> void:
	if DisplayServer.get_name() != "headless":
		player.play()


func _pick_variant(name: String) -> String:
	if not _variant_counts.has(name):
		var count := 1
		while count < MAX_VARIANTS and _get_stream("sfx", "%s_%d" % [name, count + 1], ["ogg", "wav", "mp3"]) != null:
			count += 1
		_variant_counts[name] = count
	var pick := randi() % int(_variant_counts[name])
	return name if pick == 0 else "%s_%d" % [name, pick + 1]


func _get_stream(folder: String, name: String, extensions: Array[String]) -> AudioStream:
	var key := folder + "/" + name
	if _streams.has(key):
		return _streams[key] as AudioStream
	for extension in extensions:
		var path := "res://assets/audio/%s/%s.%s" % [folder, name, extension]
		if not ResourceLoader.exists(path):
			continue
		var stream := ResourceLoader.load(path) as AudioStream
		if stream == null:
			continue
		if folder == "music" or folder == "ambience":
			var should_loop := name != "victory" and name != "defeat"
			if stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = should_loop
			elif stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = should_loop
			elif stream is AudioStreamWAV:
				(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
				(stream as AudioStreamWAV).loop_end = (stream as AudioStreamWAV).data.size() / maxi(1, (2 if (stream as AudioStreamWAV).stereo else 1) * (2 if (stream as AudioStreamWAV).format == AudioStreamWAV.FORMAT_16_BITS else 1))
		_streams[key] = stream
		return stream
	if folder == "ambience" or (folder == "sfx" and name in ["thunder", "wind_gust"]):
		var stream := WeatherAudio.make_sound(name)
		if stream != null:
			_streams[key] = stream
			return stream
	return null


func _exit_tree() -> void:
	if _ambience_tween:
		_ambience_tween.kill()
	for child in get_children():
		if child is AudioStreamPlayer:
			var player := child as AudioStreamPlayer
			player.stop()
			player.stream = null
	_streams.clear()


func _set_music_gain(player: AudioStreamPlayer, gain: float) -> void:
	player.volume_db = MUSIC_VOLUME_DB + linear_to_db(maxf(gain, 0.001))


## Boss music only lasts while a duel runs or a boss is alive on the map; the rest of the wave
## goes back to battle music (a won Warlord duel never puts him on the map at all).
func _check_boss_gone() -> void:
	if _current_track != "boss" or _phase != "wave":
		return
	var tree := get_tree()
	if not tree.get_nodes_in_group("duel").is_empty():
		return
	for u in tree.get_nodes_in_group("enemy"):
		if Waves.BOSSES.has(u.kind) and u.is_alive():
			return
	play_music("battle")


func _on_phase_changed(phase: String) -> void:
	_phase = phase
	match phase:
		"build":
			play_music("menu")
		"wave":
			play_music("battle")
			play_sfx("wave_horn")
		"victory", "defeat":
			play_music(phase)


func _on_slammed(crushes: int) -> void:
	play_sfx("slam")
	if crushes > 0:
		play_sfx("crush")


func _on_unit_crushed(_unit: Node) -> void:
	play_sfx("splat")


func _on_building_placed(_kind: String, _pos: Vector2) -> void:
	play_sfx("stamp")


func _on_ink_changed(ink: int) -> void:
	if _last_ink >= 0 and ink > _last_ink:
		play_sfx("ink_gain")
	_last_ink = ink


func _on_keep_hit() -> void:
	play_sfx("keep_hit")


func _on_boss_spawned() -> void:
	# the duel already sounded the horn for this boss
	if _current_track != "boss":
		play_sfx("wave_horn")
	play_music("boss")


## Build buttons click (or cancel) in main.gd, which knows whether the request was accepted.
func _on_decree_chosen(_id: String) -> void:
	play_sfx("ui_click")


func _on_start_wave_requested() -> void:
	play_sfx("ui_click")


func _on_restart_requested() -> void:
	play_sfx("ui_click")
