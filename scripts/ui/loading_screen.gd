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
const NEW_GAME_START_XZ := Vector2(0.0, 16.0)
const ROOM_PATHS: Array[Dictionary] = [
	{"name": "atrium",     "path": "res://scenes/station/atrium_room.tscn",     "center": Vector2(0.93,  28.47), "neighbors": ["workshop", "chem_lab"]},
	{"name": "chem_lab",   "path": "res://scenes/station/chem_lab_room.tscn",   "center": Vector2(11.72, -7.54),  "neighbors": ["atrium"]},
	{"name": "energy_lab", "path": "res://scenes/station/energy_lab_room.tscn", "center": Vector2(10.32, 14.32),  "neighbors": []},
	{"name": "office",     "path": "res://scenes/station/office_room.tscn",     "center": Vector2(0.78,  -17.63), "neighbors": []},
	{"name": "quarters",   "path": "res://scenes/station/quarters_room.tscn",   "center": Vector2(0.0,    0.0),   "neighbors": []},
	{"name": "systems",    "path": "res://scenes/station/systems_room.tscn",    "center": Vector2(-4.45, -17.0),  "neighbors": []},
	{"name": "wetroom",    "path": "res://scenes/station/wetroom_room.tscn",    "center": Vector2(9.65,  24.85),  "neighbors": []},
	{"name": "workshop",   "path": "res://scenes/station/workshop_room.tscn",   "center": Vector2(25.78,  5.67),  "neighbors": ["atrium"]},
]

@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar

var _transition_started := false
var _pending_loads: Array[String] = []
var _target_progress := 0.0
var _display_progress := 0.0


func _ready() -> void:
	if progress_bar != null:
		progress_bar.min_value = 0.0
		progress_bar.max_value = 100.0
		progress_bar.value = 0.0

	# Main scene loads with sub-threads so its own deps (player, UI, etc.) come in parallel.
	var err := ResourceLoader.load_threaded_request(GAME_SCENE_PATH, "", true)
	if err != OK and err != ERR_BUSY:
		push_error("Failed to start threaded load for game scene: %s" % GAME_SCENE_PATH)
		_change_to_game_scene_directly()
		return
	_pending_loads.append(GAME_SCENE_PATH)

	# Kick off threaded loads for rooms near the player start position,
	# plus any rooms that share geometry with a near room (neighbors).
	var player_start_xz := _get_player_start_xz()
	print("[LoadingScreen] Player start XZ: ", player_start_xz)

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
			print("[LoadingScreen] Preloading room (dist=%.1f): " % dist, room_name)
			var room_err := ResourceLoader.load_threaded_request(path)
			if room_err == OK or room_err == ERR_BUSY:
				_pending_loads.append(path)
		else:
			# Start loading but don't gate transition on it — gives far rooms a head start.
			print("[LoadingScreen] Background room (dist=%.1f): " % dist, room_name)
			ResourceLoader.load_threaded_request(path)

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
		_target_progress = 100.0
		_display_progress = 100.0
		if progress_bar != null:
			progress_bar.value = 100.0
		_transition_to_loaded_scene()


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
