extends RefCounted
## Pause-menu accessibility choices, shared by every UI scene and saved per player.

const SAVE_PATH := "user://accessibility.cfg"
const SOUND_LEVELS := [1.0, 0.7, 0.4, 0.0]
const SOUND_LABELS := ["100%", "70%", "40%", "OFF"]
const BASE_FONT_META := "accessibility_base_font_size"

static var large_text := false
static var strong_outlines := false
static var sound_level := 0
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if FileAccess.file_exists(SAVE_PATH) and config.load(SAVE_PATH) == OK:
		large_text = bool(config.get_value("accessibility", "large_text", false))
		strong_outlines = bool(config.get_value("accessibility", "strong_outlines", false))
		sound_level = clampi(int(config.get_value("accessibility", "sound_level", 0)), 0, SOUND_LEVELS.size() - 1)
	apply_sound()


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("accessibility", "large_text", large_text)
	config.set_value("accessibility", "strong_outlines", strong_outlines)
	config.set_value("accessibility", "sound_level", sound_level)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save accessibility settings: %s" % error_string(error))


static func apply_sound() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	var level: float = SOUND_LEVELS[sound_level]
	AudioServer.set_bus_mute(master, level <= 0.0)
	if level > 0.0:
		AudioServer.set_bus_volume_db(master, linear_to_db(level))


static func apply_to(node: Node) -> void:
	load_settings()
	if node is Label or node is Button:
		_apply_control(node as Control)
	for child in node.get_children():
		apply_to(child)


static func _apply_control(control: Control) -> void:
	if not control.has_meta(BASE_FONT_META):
		control.set_meta(BASE_FONT_META, control.get_theme_font_size("font_size"))
	var base_size: int = int(control.get_meta(BASE_FONT_META))
	# Small information text gains the most; display headings already have room.
	var size := base_size + 3 if large_text and base_size <= 14 else base_size
	control.add_theme_font_size_override("font_size", size)
	if strong_outlines:
		var ink := control.get_theme_color("font_color")
		control.add_theme_constant_override("outline_size", 2)
		control.add_theme_color_override("font_outline_color", Color.BLACK if ink.get_luminance() > 0.5 else Color.WHITE)
	else:
		control.remove_theme_constant_override("outline_size")
		control.remove_theme_color_override("font_outline_color")
