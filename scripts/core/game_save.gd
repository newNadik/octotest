extends Node

const SAVE_FILE_PATH := "user://save_game.json"
const SAVE_VERSION := 1

var _load_on_next_game_start := false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)


func request_load_on_next_game_start() -> void:
	_load_on_next_game_start = true


func clear_load_request() -> void:
	_load_on_next_game_start = false


func consume_load_request() -> bool:
	var should_load := _load_on_next_game_start
	_load_on_next_game_start = false
	return should_load


func clear_save() -> bool:
	if not has_save():
		return true
	var absolute_path := ProjectSettings.globalize_path(SAVE_FILE_PATH)
	var remove_error := DirAccess.remove_absolute(absolute_path)
	return remove_error == OK


func save_game(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_at_unix"] = Time.get_unix_time_from_system()

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	return true


func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var raw := file.get_as_text()
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
