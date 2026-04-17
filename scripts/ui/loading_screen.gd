extends Control

const GAME_SCENE_PATH := "res://scenes/main.tscn"

@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar

var _transition_started := false


func _ready() -> void:
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_transition_to_loaded_scene()
		return
	var error := ResourceLoader.load_threaded_request(GAME_SCENE_PATH, "", true)
	if error != OK and error != ERR_BUSY:
		push_error("Failed to start threaded load for game scene: %s" % GAME_SCENE_PATH)
		_change_to_game_scene_directly()
		return
	set_process(true)


func _process(_delta: float) -> void:
	if _transition_started:
		return

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress)
	if not progress.is_empty() and progress_bar != null:
		progress_bar.value = clampf(float(progress[0]) * 100.0, 0.0, 100.0)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_transition_to_loaded_scene()
		_:
			_transition_started = true
			push_error("Threaded load failed for game scene: %s" % GAME_SCENE_PATH)
			_change_to_game_scene_directly()


func _transition_to_loaded_scene() -> void:
	_transition_started = true
	var packed_scene := ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Threaded load completed but returned null scene: %s" % GAME_SCENE_PATH)
		_change_to_game_scene_directly()
		return
	var error := get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		push_error("Failed to change to loaded game scene: %s" % GAME_SCENE_PATH)
		_change_to_game_scene_directly()


func _change_to_game_scene_directly() -> void:
	var error := get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		push_error("Failed to load game scene: %s" % GAME_SCENE_PATH)
