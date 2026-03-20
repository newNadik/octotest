extends Node


const SETTINGS_PATH := "user://settings.cfg"
const SECTION_GENERAL := "general"
const KEY_LOCALE := "locale"
const DEFAULT_LOCALE := "en_GB"

var _config := ConfigFile.new()
var _locale := DEFAULT_LOCALE


func _ready() -> void:
	load_settings()
	_apply_locale()


func get_locale() -> String:
	return _locale


func set_locale(locale: String) -> void:
	if locale.is_empty():
		return
	if _locale == locale:
		return
	_locale = locale
	_apply_locale()
	save_settings()


func load_settings() -> void:
	var error := _config.load(SETTINGS_PATH)
	if error == OK:
		_locale = str(_config.get_value(SECTION_GENERAL, KEY_LOCALE, DEFAULT_LOCALE))
	elif error == ERR_FILE_NOT_FOUND:
		_locale = DEFAULT_LOCALE
	else:
		push_warning("Failed to load settings file: %s" % SETTINGS_PATH)
		_locale = DEFAULT_LOCALE

	if _locale.is_empty():
		_locale = DEFAULT_LOCALE


func save_settings() -> void:
	_config.set_value(SECTION_GENERAL, KEY_LOCALE, _locale)
	var error := _config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Failed to save settings file: %s" % SETTINGS_PATH)


func _apply_locale() -> void:
	TranslationServer.set_locale(_locale)
