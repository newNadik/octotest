extends Node


const SETTINGS_PATH := "user://settings.cfg"
const SECTION_GENERAL := "general"
const SECTION_AUDIO := "audio"
const SECTION_ACCESSIBILITY := "accessibility"
const SECTION_GRAPHICS := "graphics"
const KEY_LOCALE := "locale"
const KEY_EXIT_CODE := "exit_code"
const KEY_MUSIC_VOLUME := "music_volume"
const KEY_SOUND_VOLUME := "sound_volume"
const KEY_AMBIENCE_VOLUME := "ambience_volume"
const KEY_SUBTITLES_ENABLED := "subtitles_enabled"
const KEY_GOD_RAYS_ENABLED := "god_rays_enabled"
const DEFAULT_LOCALE := "en_GB"
const DEFAULT_MUSIC_VOLUME := 1.0
const DEFAULT_SOUND_VOLUME := 1.0
const DEFAULT_AMBIENCE_VOLUME := 1.0
const DEFAULT_SUBTITLES_ENABLED := true
const DEFAULT_GOD_RAYS_ENABLED := true
const EXIT_CODE_MIN := 1100
const EXIT_CODE_MAX := 1900

signal god_rays_enabled_changed(enabled: bool)

var _config := ConfigFile.new()
var _locale := DEFAULT_LOCALE
var _music_volume := DEFAULT_MUSIC_VOLUME
var _sound_volume := DEFAULT_SOUND_VOLUME
var _ambience_volume := DEFAULT_AMBIENCE_VOLUME
var _subtitles_enabled := DEFAULT_SUBTITLES_ENABLED
var _god_rays_enabled := DEFAULT_GOD_RAYS_ENABLED
var _exit_code := 0


func _ready() -> void:
	_ensure_required_audio_buses()
	load_settings()
	_apply_locale()
	_apply_audio_settings()


func get_locale() -> String:
	return _locale


func get_exit_code() -> int:
	return _exit_code


func set_exit_code(value: int) -> void:
	var clamped := clampi(value, EXIT_CODE_MIN, EXIT_CODE_MAX)
	if _exit_code == clamped:
		return
	_exit_code = clamped
	save_settings()


func generate_new_exit_code() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_exit_code = rng.randi_range(EXIT_CODE_MIN, EXIT_CODE_MAX)
	save_settings()
	return _exit_code


func set_locale(locale: String) -> void:
	if locale.is_empty():
		return
	if _locale == locale:
		return
	_locale = locale
	_apply_locale()
	save_settings()


func get_music_volume() -> float:
	return _music_volume


func set_music_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(_music_volume, clamped):
		return
	_music_volume = clamped
	_apply_audio_settings()
	save_settings()


func get_sound_volume() -> float:
	return _sound_volume


func set_sound_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(_sound_volume, clamped):
		return
	_sound_volume = clamped
	_apply_audio_settings()
	save_settings()


func get_subtitles_enabled() -> bool:
	return _subtitles_enabled


func get_ambience_volume() -> float:
	return _ambience_volume


func set_ambience_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(_ambience_volume, clamped):
		return
	_ambience_volume = clamped
	_apply_audio_settings()
	save_settings()


func set_subtitles_enabled(enabled: bool) -> void:
	if _subtitles_enabled == enabled:
		return
	_subtitles_enabled = enabled
	save_settings()


func get_god_rays_enabled() -> bool:
	return _god_rays_enabled


func set_god_rays_enabled(enabled: bool) -> void:
	if _god_rays_enabled == enabled:
		return
	_god_rays_enabled = enabled
	god_rays_enabled_changed.emit(enabled)
	save_settings()


func load_settings() -> void:
	var error := _config.load(SETTINGS_PATH)
	if error == OK:
		_locale = str(_config.get_value(SECTION_GENERAL, KEY_LOCALE, DEFAULT_LOCALE))
		_exit_code = int(_config.get_value(SECTION_GENERAL, KEY_EXIT_CODE, 0))
		_music_volume = float(_config.get_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, DEFAULT_MUSIC_VOLUME))
		_sound_volume = float(_config.get_value(SECTION_AUDIO, KEY_SOUND_VOLUME, DEFAULT_SOUND_VOLUME))
		_ambience_volume = float(_config.get_value(SECTION_AUDIO, KEY_AMBIENCE_VOLUME, DEFAULT_AMBIENCE_VOLUME))
		_subtitles_enabled = bool(_config.get_value(SECTION_ACCESSIBILITY, KEY_SUBTITLES_ENABLED, DEFAULT_SUBTITLES_ENABLED))
		_god_rays_enabled = bool(_config.get_value(SECTION_GRAPHICS, KEY_GOD_RAYS_ENABLED, DEFAULT_GOD_RAYS_ENABLED))
	elif error == ERR_FILE_NOT_FOUND:
		_locale = DEFAULT_LOCALE
		_exit_code = 0
		_music_volume = DEFAULT_MUSIC_VOLUME
		_sound_volume = DEFAULT_SOUND_VOLUME
		_ambience_volume = DEFAULT_AMBIENCE_VOLUME
		_subtitles_enabled = DEFAULT_SUBTITLES_ENABLED
		_god_rays_enabled = DEFAULT_GOD_RAYS_ENABLED
	else:
		push_warning("Failed to load settings file: %s" % SETTINGS_PATH)
		_locale = DEFAULT_LOCALE
		_exit_code = 0
		_music_volume = DEFAULT_MUSIC_VOLUME
		_sound_volume = DEFAULT_SOUND_VOLUME
		_ambience_volume = DEFAULT_AMBIENCE_VOLUME
		_subtitles_enabled = DEFAULT_SUBTITLES_ENABLED
		_god_rays_enabled = DEFAULT_GOD_RAYS_ENABLED

	if _locale.is_empty():
		_locale = DEFAULT_LOCALE
	if _exit_code < EXIT_CODE_MIN or _exit_code > EXIT_CODE_MAX:
		_exit_code = 0
	_music_volume = clampf(_music_volume, 0.0, 1.0)
	_sound_volume = clampf(_sound_volume, 0.0, 1.0)
	_ambience_volume = clampf(_ambience_volume, 0.0, 1.0)


func save_settings() -> void:
	_config.set_value(SECTION_GENERAL, KEY_LOCALE, _locale)
	_config.set_value(SECTION_GENERAL, KEY_EXIT_CODE, _exit_code)
	_config.set_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, _music_volume)
	_config.set_value(SECTION_AUDIO, KEY_SOUND_VOLUME, _sound_volume)
	_config.set_value(SECTION_AUDIO, KEY_AMBIENCE_VOLUME, _ambience_volume)
	_config.set_value(SECTION_ACCESSIBILITY, KEY_SUBTITLES_ENABLED, _subtitles_enabled)
	_config.set_value(SECTION_GRAPHICS, KEY_GOD_RAYS_ENABLED, _god_rays_enabled)
	var error := _config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Failed to save settings file: %s" % SETTINGS_PATH)


func _apply_locale() -> void:
	TranslationServer.set_locale(_locale)


func _apply_audio_settings() -> void:
	_set_bus_volume_if_exists("Music", _music_volume)
	_set_bus_volume_if_exists("SFX", _sound_volume)
	_set_bus_volume_if_exists("Ambience", _ambience_volume)


func _set_bus_volume_if_exists(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var volume_db := -80.0 if linear_value <= 0.0 else linear_to_db(linear_value)
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func _ensure_required_audio_buses() -> void:
	_ensure_bus_exists("Music")
	_ensure_bus_exists("SFX")
	_ensure_bus_exists("Ambience")


func _ensure_bus_exists(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus(AudioServer.bus_count)
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, "Master")
