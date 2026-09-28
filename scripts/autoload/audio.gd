extends Node
## Global music and sound effects. Missing human-made assets are intentionally silent.

const MUSIC_NAMES := ["menu", "battle", "boss", "victory", "defeat"]
const SFX_NAMES := [
	"paper_grab", "paper_fold", "slam", "crush", "splat", "stamp",
	"ink_gain", "keep_hit", "wave_horn", "tear", "ui_click",
]
const SFX_POOL_SIZE := 8
const MUSIC_VOLUME_DB := -14.0
const SFX_VOLUME_DB := -5.0
const CROSSFADE_SECONDS := 0.8
const SILENCE_DB := -60.0

var _streams: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _active_music := -1
var _outgoing_music := -1
var _current_track := ""
var _fade_time := CROSSFADE_SECONDS
var _outgoing_gain := 0.0
var _next_sfx_player := 0
var _last_ink := -1


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
	Events.phase_changed.connect(_on_phase_changed)
	Events.slammed.connect(_on_slammed)
	Events.unit_crushed.connect(_on_unit_crushed)
	Events.building_placed.connect(_on_building_placed)
	Events.ink_changed.connect(_on_ink_changed)
	Events.keep_hit.connect(_on_keep_hit)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.build_requested.connect(_on_build_requested)
	Events.start_wave_requested.connect(_on_start_wave_requested)
	Events.restart_requested.connect(_on_restart_requested)
	play_music("menu")


func _process(delta: float) -> void:
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
	player.play()
	_current_track = name
	_fade_time = 0.0


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


func play_sfx(name: String) -> void:
	if not SFX_NAMES.has(name):
		return
	var stream := _get_stream("sfx", name, ["ogg", "wav", "mp3"])
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
	player.play()


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
		if folder == "music":
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
	return null


func _set_music_gain(player: AudioStreamPlayer, gain: float) -> void:
	player.volume_db = MUSIC_VOLUME_DB + linear_to_db(maxf(gain, 0.001))


func _on_phase_changed(phase: String) -> void:
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
	play_music("boss")
	play_sfx("wave_horn")


func _on_build_requested(_kind: String) -> void:
	play_sfx("ui_click")


func _on_start_wave_requested() -> void:
	play_sfx("ui_click")


func _on_restart_requested() -> void:
	play_sfx("ui_click")
