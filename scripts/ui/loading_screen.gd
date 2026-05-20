extends Control

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const PROGRESS_CREEP_MAX := 99.2
const PROGRESS_CREEP_MIN_PER_SEC := 0.35
const PROGRESS_CREEP_FACTOR := 0.22
const PROGRESS_SMOOTH_SPEED := 28.0
const UI_MAX_DELTA := 0.05

# Rooms within this XZ radius of the player position are preloaded here so
# they are cache-ready the moment the game scene initialises. Must match the
# value in main.gd. Rooms outside this radius are loaded async at runtime.
const INITIAL_LOAD_RADIUS := 20.0
# Default XZ for a fresh game. Overridden by save data when continuing.
const NEW_GAME_START_XZ := Vector2(5.0, -26.0)
const ROOM_PATHS: Array[Dictionary] = [
	{"name": "atrium",     "path": "res://scenes/station/atrium_room.tscn",     "center": Vector2(0.93,  28.47), "neighbors": ["workshop", "chem_lab"]},
	{"name": "chem_lab",   "path": "res://scenes/station/chem_lab_room.tscn",   "center": Vector2(11.72, -7.54),  "neighbors": ["atrium"]},
	{"name": "energy_lab", "path": "res://scenes/station/energy_lab_room.tscn", "center": Vector2(10.32, 14.32),  "neighbors": []},
	{"name": "office",     "path": "res://scenes/station/data_office/office_arch.tscn", "center": Vector2(0.78,  -17.63), "neighbors": []},
	{"name": "quarters",   "path": "res://scenes/station/quarters_room.tscn",   "center": Vector2(0.0,    0.0),   "neighbors": []},
	{"name": "systems",    "path": "res://scenes/station/systems_room.tscn",    "center": Vector2(-4.45, -17.0),  "neighbors": []},
	{"name": "wetroom",    "path": "res://scenes/station/wetroom_room.tscn",    "center": Vector2(9.65,  24.85),  "neighbors": []},
	{"name": "workshop",   "path": "res://scenes/station/workshop_room.tscn",   "center": Vector2(25.78,  5.67),  "neighbors": ["atrium"]},
]

@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar

var _transition_started := false
var _pending_loads: Array[String] = []
var _pending_load_enqueue_ms: Dictionary = {}
var _target_progress := 0.0
var _display_progress := 0.0
var _t0: int = 0
var _logged_completed: Array[String] = []
# New game loads in two sequential phases to avoid thread competition:
# phase 0 = main.tscn, phase 1 = priority room (office), then transition.
var _phase := 0
var _new_game_priority_path := ""


func _ms() -> String:
	return "[%s +%dms]" % [Time.get_time_string_from_system(), Time.get_ticks_msec() - _t0]


func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	if progress_bar != null:
		progress_bar.min_value = 0.0
		progress_bar.max_value = 100.0
		progress_bar.value = 0.0

	print("[LoadingScreen] %s Started, requesting main scene" % _ms())
	var err := ResourceLoader.load_threaded_request(GAME_SCENE_PATH, "", true)
	if err != OK and err != ERR_BUSY:
		push_error("Failed to start threaded load for game scene: %s" % GAME_SCENE_PATH)
		_change_to_game_scene_directly()
		return
	_pending_loads.append(GAME_SCENE_PATH)
	_pending_load_enqueue_ms[GAME_SCENE_PATH] = Time.get_ticks_msec()

	var player_start_xz := _get_player_start_xz()
	var is_new_game := _is_new_game()

	if is_new_game:
		# Phase 0: main.tscn only. Phase 1 will load the priority room after.
		_new_game_priority_path = _find_nearest_room_path(player_start_xz)
		print("[LoadingScreen] %s New game — phase 0: main scene, phase 1: %s" % [_ms(), _new_game_priority_path.get_file()])
	else:
		var near_names: Array[String] = []
		for room in ROOM_PATHS:
			if player_start_xz.distance_to(room["center"] as Vector2) <= INITIAL_LOAD_RADIUS:
				near_names.append(room["name"] as String)
		for room in ROOM_PATHS:
			if near_names.has(room["name"] as String):
				for neighbor in (room["neighbors"] as Array):
					if not near_names.has(neighbor as String):
						near_names.append(neighbor as String)
		for room in ROOM_PATHS:
			var room_name := room["name"] as String
			var dist := player_start_xz.distance_to(room["center"] as Vector2)
			var path: String = room["path"]
			if near_names.has(room_name):
				print("[LoadingScreen] %s Preloading room (dist=%.1f): %s" % [_ms(), dist, room_name])
				var room_err := ResourceLoader.load_threaded_request(path)
				if room_err == OK or room_err == ERR_BUSY:
					_pending_loads.append(path)
					_pending_load_enqueue_ms[path] = Time.get_ticks_msec()
			else:
				print("[LoadingScreen] %s Background room (dist=%.1f): %s" % [_ms(), dist, room_name])
				ResourceLoader.load_threaded_request(path)

	print("[LoadingScreen] %s Phase %d queued, waiting for %d loads" % [_ms(), _phase, _pending_loads.size()])
	set_process(true)


func _process(delta: float) -> void:
	if _transition_started:
		return
	var ui_delta := minf(maxf(delta, 0.0), UI_MAX_DELTA)

	var total := _pending_loads.size()
	var completed := 0
	var progress_sum := 0.0
	var any_failed := false

	for path in _pending_loads:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				progress_sum += clampf(float(progress[0]) if not progress.is_empty() else 0.0, 0.0, 1.0)
			ResourceLoader.THREAD_LOAD_LOADED:
				progress_sum += 1.0
				completed += 1
				if not _logged_completed.has(path):
					_logged_completed.append(path)
					var file_ms: int = Time.get_ticks_msec() - int(_pending_load_enqueue_ms.get(path, Time.get_ticks_msec()))
					var cache_hint := " (cached)" if file_ms < 400 else ""
					print("[LoadingScreen] %s Done%s (%dms): %s" % [_ms(), cache_hint, file_ms, path.get_file()])

			_:
				any_failed = true

	if any_failed:
		_transition_started = true
		push_error("A threaded load failed; falling back to direct scene change.")
		_change_to_game_scene_directly()
		return

	var reported := clampf(progress_sum / maxf(1.0, float(total)) * 100.0, 0.0, 100.0)
	if reported > _target_progress:
		var catch_up_step := maxf(6.0 * ui_delta, (reported - _target_progress) * 0.26)
		_target_progress = minf(reported, _target_progress + catch_up_step)

	var all_done := completed == total
	if not all_done and _target_progress < PROGRESS_CREEP_MAX:
		var remaining := maxf(0.0, PROGRESS_CREEP_MAX - _target_progress)
		var creep_step := (PROGRESS_CREEP_MIN_PER_SEC + remaining * PROGRESS_CREEP_FACTOR) * ui_delta
		_target_progress = minf(PROGRESS_CREEP_MAX, _target_progress + creep_step)

	_display_progress = move_toward(_display_progress, _target_progress, PROGRESS_SMOOTH_SPEED * ui_delta)
	if progress_bar != null:
		progress_bar.value = _display_progress

	if all_done:
		if _phase == 0 and _new_game_priority_path != "":
			_start_phase_1()
		else:
			_target_progress = 100.0
			_display_progress = 100.0
			if progress_bar != null:
				progress_bar.value = 100.0
			_transition_to_loaded_scene()


func _start_phase_1() -> void:
	_phase = 1
	_pending_loads.clear()
	_logged_completed.clear()
	_pending_load_enqueue_ms.clear()
	_target_progress = 0.0
	_display_progress = 0.0
	print("[LoadingScreen] %s Phase 1: loading priority room %s" % [_ms(), _new_game_priority_path.get_file()])
	var err := ResourceLoader.load_threaded_request(_new_game_priority_path)
	if err == OK or err == ERR_BUSY:
		_pending_loads.append(_new_game_priority_path)
		_pending_load_enqueue_ms[_new_game_priority_path] = Time.get_ticks_msec()
	else:
		push_error("Failed to start priority room load: %s" % _new_game_priority_path)
		_transition_to_loaded_scene()


func _transition_to_loaded_scene() -> void:
	_transition_started = true
	print("[LoadingScreen] %s All done, transitioning to game scene" % _ms())
	var packed_scene := ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Threaded load completed but returned null scene: %s" % GAME_SCENE_PATH)
		_change_to_game_scene_directly()
		return
	var error := get_tree().change_scene_to_packed(packed_scene)
	if error != OK:
		push_error("Failed to change to loaded game scene: %s" % GAME_SCENE_PATH)
		_change_to_game_scene_directly()


func _find_nearest_room_path(from_xz: Vector2) -> String:
	var best_path := ""
	var best_dist := INF
	for room in ROOM_PATHS:
		var dist := from_xz.distance_to(room["center"] as Vector2)
		if dist < best_dist:
			best_dist = dist
			best_path = room["path"] as String
	return best_path


func _is_new_game() -> bool:
	var game_save := get_node_or_null("/root/GameSave")
	return game_save == null or not bool(game_save.call("has_save"))


func _get_player_start_xz() -> Vector2:
	var game_save := get_node_or_null("/root/GameSave")
	if game_save != null and bool(game_save.call("has_save")):
		var data = game_save.call("load_game")
		if data is Dictionary:
			var player_data = (data as Dictionary).get("player", {})
			if player_data is Dictionary:
				var pos_arr = (player_data as Dictionary).get("position", [])
				if pos_arr is Array and (pos_arr as Array).size() >= 3:
					var p := pos_arr as Array
					return Vector2(float(p[0]), float(p[2]))
	return NEW_GAME_START_XZ


func _change_to_game_scene_directly() -> void:
	var error := get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		push_error("Failed to load game scene: %s" % GAME_SCENE_PATH)
