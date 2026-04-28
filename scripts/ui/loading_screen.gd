extends Control

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const PROGRESS_CREEP_PER_SEC := 18.0
const PROGRESS_CREEP_MAX := 92.0
const PROGRESS_SMOOTH_SPEED := 3.0
const UI_MAX_DELTA := 0.05

@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar

var _transition_started := false
var _target_progress := 0.0
var _display_progress := 0.0


func _ready() -> void:
	if progress_bar != null:
		progress_bar.min_value = 0.0
		progress_bar.max_value = 100.0
		progress_bar.value = 0.0
	_target_progress = 0.0
	_display_progress = 0.0
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_target_progress = 100.0
		_display_progress = 100.0
		if progress_bar != null:
			progress_bar.value = 100.0
		_transition_to_loaded_scene()
		return
	var error := ResourceLoader.load_threaded_request(GAME_SCENE_PATH, "", true)
	if error != OK and error != ERR_BUSY:
		push_error("Failed to start threaded load for game scene: %s" % GAME_SCENE_PATH)
		_change_to_game_scene_directly()
		return
	set_process(true)


func _process(delta: float) -> void:
	if _transition_started:
		return
	var ui_delta := minf(maxf(delta, 0.0), UI_MAX_DELTA)

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress)
	if not progress.is_empty():
		var reported := clampf(float(progress[0]) * 100.0, 0.0, 100.0)
		_target_progress = maxf(_target_progress, reported)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and _target_progress < PROGRESS_CREEP_MAX:
		_target_progress = minf(PROGRESS_CREEP_MAX, _target_progress + PROGRESS_CREEP_PER_SEC * ui_delta)

	_display_progress = move_toward(
		_display_progress,
		_target_progress,
		PROGRESS_SMOOTH_SPEED * 100.0 * ui_delta
	)
	if progress_bar != null:
		progress_bar.value = _display_progress

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_target_progress = 100.0
			_display_progress = 100.0
			if progress_bar != null:
				progress_bar.value = 100.0
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
