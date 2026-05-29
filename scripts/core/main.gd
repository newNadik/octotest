extends Node3D


const CLICK_TARGET_COLLISION_MASK := (1 << 0) | (1 << 1) | (1 << 5)
const CAMERA_OBSTACLE_COLLISION_MASK := (1 << 0) | (1 << 1) | (1 << 5) | (1 << 6)
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SETTINGS_MENU_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const InteractionControllerScript = preload("res://scripts/interaction/interaction_controller.gd")
const PLASTER_MATERIAL := preload("res://assets/materials/plaster.tres")
const PLASTER_MOBILE_MATERIAL := preload("res://assets/materials/plaster_mobile.tres")
const CONCRETE_MATERIAL := preload("res://assets/materials/concrete.tres")
const FLOOR_MATERIAL := preload("res://assets/materials/floor.tres")
const GROUND_MATERIAL := preload("res://assets/materials/ground.tres")
const OCTO_START_Y := 0.08
const AUTOSAVE_MIN_INTERVAL_SEC := 1.0
const CAMERA_FOLLOW_HEIGHT := 0.65
const CAMERA_MIN_WORLD_Y := 1.25
const CAMERA_PROBE_RADIUS := 0.72
const CAMERA_MIN_MARGIN := 0.7
const CAMERA_NEAR_CLIP := 0.12
const MOBILE_OS_NAMES := ["iOS", "Android"]
const ROOM_STREAM_UPDATE_INTERVAL_SEC := 0.35
const FPS_LABEL_UPDATE_INTERVAL_SEC := 0.25
const EXIT_CODE_MIN := 1100
const EXIT_CODE_MAX := 1900
# Must match loading_screen.gd — rooms within this radius of player start are
# preloaded by the loading screen and can be sync-instantiated from cache.
const INITIAL_LOAD_RADIUS := 20.0
const ROOM_REGISTRY: Array[Dictionary] = [
	{"name": "atrium",      "layers": ["res://scenes/station/atrium/atrium_arch.tscn",         "res://scenes/station/atrium/atrium_details.tscn"],         "center": Vector3(0.93,   0.0,  28.47), "neighbors": ["workshop", "chem_lab"]},
	{"name": "chem_lab",    "layers": ["res://scenes/station/chem_lab/chem_lab_arch.tscn",     "res://scenes/station/chem_lab/chem_lab_details.tscn"],     "center": Vector3(11.72,  0.0,  -7.54),  "neighbors": ["atrium"]},
	{"name": "energy_lab",  "layers": ["res://scenes/station/energy_lab/energy_lab_arch.tscn", "res://scenes/station/energy_lab/energy_lab_details.tscn"], "center": Vector3(10.32,  0.0,  14.32),  "neighbors": []},
	{"name": "office",      "layers": ["res://scenes/station/office/office_arch.tscn",         "res://scenes/station/office/office_details.tscn"],         "center": Vector3(0.78,   0.0, -17.63),  "neighbors": []},
	{"name": "quarters",    "layers": ["res://scenes/station/quarters/quarters_arch.tscn",     "res://scenes/station/quarters/quarters_details.tscn"],     "center": Vector3(0.0,    0.0,   0.0),   "neighbors": []},
	{"name": "systems",     "layers": ["res://scenes/station/systems/systems_arch.tscn",       "res://scenes/station/systems/systems_details.tscn"],       "center": Vector3(-4.45,  0.0, -17.0),   "neighbors": []},
	{"name": "wetroom",     "layers": ["res://scenes/station/wetroom/wetroom_arch.tscn",       "res://scenes/station/wetroom/wetroom_details.tscn"],       "center": Vector3(9.65,   0.0,  24.85),  "neighbors": []},
	{"name": "workshop",    "layers": ["res://scenes/station/workshop/workshop_arch.tscn",     "res://scenes/station/workshop/workshop_details.tscn"],     "center": Vector3(25.78,  0.0,   5.67),  "neighbors": ["atrium"]},
	{"name": "surrounding", "layers": ["res://scenes/effects/surrounding_full.tscn"],                                                                      "center": Vector3.ZERO,                  "neighbors": [], "deferred": true},
]
const ROOM_LIGHT_ISOLATION_LAYER_BITS := {
	"atrium": 16,
	"office": 17,
	"systems": 18,
	"quarters": 19,
}
const DEFAULT_VISUAL_LAYER_MASK := 1
const HUB_SEAM_LIGHT_NAME := "HubSeamLight"
const HUB_SEAM_LIGHT_POSITION := Vector3(0.0, 4.8, -18.5)
const HUB_SEAM_LIGHT_RANGE := 8.0
const HUB_SEAM_LIGHT_ENERGY := 0.38

@export var orbit_sensitivity := 0.2
@export var drag_orbit_threshold_px := 10.0
@export var orbit_pitch_min_degrees := -80.0
@export var orbit_pitch_max_degrees := 20.0
@export var min_zoom := 2.4
@export var max_zoom := 10.0
@export var zoom_step := 1.0
@export var focus_zoom_distance := 2.0
@export var focus_tween_duration := 0.24
@export var focus_return_tween_duration := 0.36
@export var focus_pan_sensitivity := 0.0016
@export var focus_pan_max_distance := 0.7
@export var camera_follow_lerp_speed := 10.0
@export var camera_follow_deadzone := 0.03
@export var underwater_light_motion_enabled := true
@export var underwater_light_motion_speed := 0.58
@export var underwater_light_pitch_amplitude := 5.8
@export var underwater_light_yaw_amplitude := 9.5
@export var underwater_light_energy_amplitude := 0.24
@export var sync_main_light_with_god_rays := true
@export var main_light_sway_enabled := false
@export var main_light_min_factor := 0.5
@export var main_light_max_factor := 0.8
@export var room_streaming_enabled := true
@export var room_load_distance := 80.0
@export var room_unload_distance := 96.0
@export var room_names_to_always_keep: PackedStringArray = PackedStringArray(["atrium", "surrounding"])
@export var ios_render_scale := 0.70

@onready var player: CharacterBody3D = $Player
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_yaw: Node3D = $CameraPivot/CameraYaw
@onready var camera_pitch: Node3D = $CameraPivot/CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraPivot/CameraYaw/CameraPitch/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/CameraYaw/CameraPitch/SpringArm3D/Camera3D
@onready var pause_menu_button: Button = $UI/PauseMenuButton
@onready var hud_root: Control = $UI/HUD
@onready var hint_label: Label = $UI/HUD/HintPanel/HintMargin/HintLabel
@onready var save_status_icon: TextureRect = $UI/SaveStatusIcon
@onready var fps_label: Label = $UI/FPSLabel
@onready var in_game_menu: Control = $UI/InGameMenu
@onready var in_game_resume_button: Button = $UI/InGameMenu/MenuCenter/MenuPanel/MenuMargin/MenuButtons/ResumeButton
@onready var in_game_save_button: Button = $UI/InGameMenu/MenuCenter/MenuPanel/MenuMargin/MenuButtons/SaveButton
@onready var in_game_main_menu_button: Button = $UI/InGameMenu/MenuCenter/MenuPanel/MenuMargin/MenuButtons/MainMenuButton
@onready var in_game_settings_button: Button = $UI/InGameMenu/MenuCenter/MenuPanel/MenuMargin/MenuButtons/SettingsButton
@onready var room_light: OmniLight3D = get_node_or_null("OmniLight3D") as OmniLight3D
@onready var sun_light: DirectionalLight3D = get_node_or_null("lights/DirectionalLight3D") as DirectionalLight3D
@onready var skylight_hero_light: SpotLight3D = get_node_or_null("lights/SkylightHeroLight") as SpotLight3D
@onready var god_rays_node: Node = get_node_or_null("lights/GodRays")
@onready var world_environment: WorldEnvironment = $WorldEnvironment

var _interaction_controller
var _orbiting := false
var _primary_pointer_down := false
var _primary_pointer_dragging := false
var _primary_pointer_start := Vector2.ZERO
var _yaw := 35.0
var _pitch := -35.0
var _roll := 0.0
var _focus_mode := false
var _focus_target
var _focus_pending_target
var _hide_held_items_in_focus := false
var _focus_tween: Tween
var _saved_spring_length := 9.0
var _saved_yaw := 35.0
var _saved_pitch := -35.0
var _saved_roll := 0.0
var _saved_min_zoom := 0.0
var _saved_max_zoom := 0.0
var _saved_zoom_step := 0.0
var _focus_pan_offset := Vector3.ZERO
var _player_visual_root: Node3D
var _settings_overlay: Control
var _underwater_light_time := 0.0
var _sun_base_rotation := Vector3.ZERO
var _sun_base_energy := 0.0
var _hero_base_energy := 0.0
var _loaded_save_data: Dictionary = {}
var _pending_world_state: Dictionary = {}
var _last_save_unix_time := -1000.0
var _save_status_tween: Tween
var _stream_station_root: Node3D
var _stream_rooms: Dictionary = {}
# Pending async loads: key = "room_name:layer_idx", value = resource path
var _stream_pending: Dictionary = {}
var _stream_start_ms: Dictionary = {}
var _stream_update_accum := 0.0
var _deferred_started := false
var _room_nav_regions: Dictionary = {}
var _player_current_room: String = ""
var _is_new_game: bool = false
var _new_game_priority_room: String = ""
var _fps_label_update_accum := 0.0
var _exit_code := 0


func _ready() -> void:
	print("[Main] _ready at %s (t=%dms)" % [Time.get_time_string_from_system(), Time.get_ticks_msec()])
	process_mode = Node.PROCESS_MODE_ALWAYS
	in_game_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_apply_mobile_render_scale_overrides()
	_apply_platform_visual_overrides()
	var starting_position := Vector3(5.0, OCTO_START_Y, -26.0)
	var is_loading_saved_game := _consume_pending_load_request()
	_is_new_game = not is_loading_saved_game
	if is_loading_saved_game:
		_loaded_save_data = _load_saved_game()
		starting_position = _extract_player_position(_loaded_save_data, starting_position)
		_initialize_game_time(_loaded_save_data)
		var world = _loaded_save_data.get("world", {})
		if world is Dictionary:
			_pending_world_state = (world as Dictionary).duplicate()
		MusicManager.play_game_loop()
	else:
		_initialize_game_time({})
		MusicManager.play_game_start()
	_initialize_exit_code(is_loading_saved_game)
	player.global_position = starting_position
	var follow_position := player.global_position + Vector3(0.0, CAMERA_FOLLOW_HEIGHT, 0.0)
	follow_position.y = maxf(follow_position.y, CAMERA_MIN_WORLD_Y)
	camera_pivot.global_position = follow_position
	_apply_camera_angles()
	_configure_camera_collision()
	_make_click_through(hud_root)
	_create_interaction_controller()
	_player_visual_root = player.get_node_or_null("PlayerVisual") as Node3D
	if _player_visual_root == null:
		_player_visual_root = player.get_node_or_null("MeshInstance3D") as Node3D
	_apply_player_room_light_layers()
	in_game_resume_button.pressed.connect(_on_resume_pressed)
	in_game_save_button.pressed.connect(_on_save_pressed)
	in_game_settings_button.pressed.connect(_on_settings_pressed)
	in_game_main_menu_button.pressed.connect(_on_main_menu_pressed)
	pause_menu_button.pressed.connect(_on_pause_menu_button_pressed)
	pause_menu_button.visible = OS.has_feature("mobile")
	_connect_autosave_doors()
	_connect_shadow_setting()
	_initialize_room_streaming()
	_apply_loaded_world_state()
	_apply_exit_code_to_scene(self)
	_set_in_game_menu_visible(false)
	_update_fps_label()
	

func _process(delta: float) -> void:
	_fps_label_update_accum += delta
	if _fps_label_update_accum < FPS_LABEL_UPDATE_INTERVAL_SEC:
		return
	_fps_label_update_accum = 0.0
	_update_fps_label()


func _update_fps_label() -> void:
	if fps_label == null:
		return
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _apply_platform_visual_overrides() -> void:
	if not _should_use_mobile_visual_fallbacks():
		return
	_apply_mobile_material_fallbacks()
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.volumetric_fog_enabled = false


func _apply_mobile_render_scale_overrides() -> void:
	if OS.get_name() != "iOS":
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	viewport.set("scaling_3d_scale", clampf(ios_render_scale, 0.5, 1.0))


func _should_use_mobile_visual_fallbacks() -> bool:
	return OS.has_feature("mobile") or MOBILE_OS_NAMES.has(OS.get_name())


func _apply_mobile_material_fallbacks() -> void:
	_replace_plaster_with_mobile_fallback()
	_simplify_mobile_standard_material(PLASTER_MATERIAL, true)
	_simplify_mobile_standard_material(CONCRETE_MATERIAL)
	_simplify_mobile_standard_material(FLOOR_MATERIAL)
	_simplify_mobile_standard_material(GROUND_MATERIAL)


func _replace_plaster_with_mobile_fallback() -> void:
	_replace_material_references_recursive(self, PLASTER_MATERIAL, PLASTER_MOBILE_MATERIAL)


func _replace_material_references_recursive(node: Node, source_material: Material, replacement_material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.material_override == source_material:
			mesh_instance.material_override = replacement_material
		var surface_count := mesh_instance.get_surface_override_material_count()
		for surface_index in surface_count:
			if mesh_instance.get_surface_override_material(surface_index) == source_material:
				mesh_instance.set_surface_override_material(surface_index, replacement_material)

	for child in node.get_children():
		_replace_material_references_recursive(child, source_material, replacement_material)


func _simplify_mobile_standard_material(material: Material, remove_next_pass: bool = false) -> void:
	if material == null or not material is StandardMaterial3D:
		return

	var standard_material := material as StandardMaterial3D
	standard_material.heightmap_enabled = false
	if remove_next_pass:
		standard_material.next_pass = null

func _collect_omni_lights(node: Node) -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	if node is OmniLight3D:
		lights.append(node as OmniLight3D)
	for child in node.get_children():
		lights.append_array(_collect_omni_lights(child))
	return lights


func _physics_process(delta: float) -> void:
	_animate_underwater_light(delta)
	_update_room_streaming(delta)

	if not _focus_mode:
		var follow_position := player.global_position + Vector3(0.0, CAMERA_FOLLOW_HEIGHT, 0.0)
		follow_position.y = maxf(follow_position.y, CAMERA_MIN_WORLD_Y)
		var to_follow := follow_position - camera_pivot.global_position
		if to_follow.length() > camera_follow_deadzone:
			var follow_alpha := 1.0 - exp(-camera_follow_lerp_speed * maxf(delta, 0.0))
			camera_pivot.global_position = camera_pivot.global_position.lerp(follow_position, follow_alpha)

	if in_game_menu.visible:
		_interaction_controller.set_interaction_enabled(false)
		return

	_interaction_controller.set_interaction_enabled(true)
	_interaction_controller.process_interactions(delta)
	_process_focus_mode()
	_process_pending_focus_entry()


func _initialize_room_streaming() -> void:
	if not room_streaming_enabled:
		return
	if room_unload_distance <= room_load_distance:
		room_unload_distance = room_load_distance + 12.0

	_stream_station_root = get_node_or_null("station") as Node3D
	if _stream_station_root == null:
		return

	_stream_rooms.clear()
	for room_def in ROOM_REGISTRY:
		_stream_rooms[room_def["name"]] = {
			"layers": (room_def["layers"] as Array).duplicate(),
			"nodes": [],
			"center": room_def["center"] as Vector3,
			"neighbors": room_def["neighbors"] as Array,
			"deferred": room_def.get("deferred", false),
		}

	if room_load_distance <= 0.0:
		return

	var start_pos := player.global_position

	if _is_new_game:
		# Find the single nearest room. Loading screen preloaded all its layers.
		# All other rooms wait until this one is ready (see _apply_room_streaming).
		var nearest_dist := INF
		for room_name in _stream_rooms.keys():
			var d: Dictionary = _stream_rooms[room_name]
			if d.get("deferred", false):
				continue
			var dist := start_pos.distance_to(d["center"] as Vector3)
			if dist < nearest_dist:
				nearest_dist = dist
				_new_game_priority_room = room_name
		# Arch is in loading screen cache — sync-load for instant startup.
		# All layers queue async; details will be a fast cache hit.
		_load_room_arch_sync(_new_game_priority_room)
		_queue_room(_new_game_priority_room)
	else:
		# Continue game: sync-load arch of rooms within INITIAL_LOAD_RADIUS
		# (they were preloaded by the loading screen). Everything else async.
		# Always-keep rooms that are far (e.g. atrium) load async to avoid blocking.
		for room_name in _stream_rooms.keys():
			var d: Dictionary = _stream_rooms[room_name]
			if d.get("deferred", false):
				continue
			var dist := start_pos.distance_to(d["center"] as Vector3)
			if dist <= INITIAL_LOAD_RADIUS:
				print("[RoomStream] Near (dist=%.1f), sync arch + async details: %s" % [dist, room_name])
				_load_room_arch_sync(room_name)
				_queue_room(room_name)
			else:
				print("[RoomStream] Far  (dist=%.1f), async-loading: %s" % [dist, room_name])
				_queue_room(room_name)

	_check_if_should_start_deferred()


func _load_room_arch_sync(room_name: String) -> void:
	var d: Dictionary = _stream_rooms.get(room_name, {})
	var layers: Array = d.get("layers", [])
	if layers.is_empty():
		return
	var nodes: Array = d.get("nodes", [])
	while nodes.size() < layers.size():
		nodes.append(null)
	if is_instance_valid(nodes[0] as Node):
		return
	var path := String(layers[0])
	var t_load := Time.get_ticks_msec()
	var packed := load(path) as PackedScene
	var t_inst := Time.get_ticks_msec()
	if packed == null:
		return
	var inst := packed.instantiate() as Node3D
	var t_done := Time.get_ticks_msec()
	if inst == null:
		return
	_add_layer_node(room_name, 0, inst, path)
	nodes[0] = inst
	d["nodes"] = nodes
	_stream_rooms[room_name] = d
	print("[RoomStream] Sync loaded '%s' arch: load=%dms  instantiate=%dms  total=%dms" % [room_name, t_inst - t_load, t_done - t_inst, t_done - t_load])


func _queue_room(room_name: String) -> void:
	var d: Dictionary = _stream_rooms.get(room_name, {})
	var layers: Array = d.get("layers", [])
	var nodes: Array = d.get("nodes", [])
	for i in layers.size():
		if i < nodes.size() and is_instance_valid(nodes[i] as Node):
			continue
		var key := _lkey(room_name, i)
		if _stream_pending.has(key):
			continue
		var path := String(layers[i])
		var err := ResourceLoader.load_threaded_request(path)
		if err == OK or err == ERR_BUSY:
			_stream_pending[key] = path
			_stream_start_ms[key] = Time.get_ticks_msec()


func _add_layer_node(room_name: String, layer: int, inst: Node3D, path: String) -> void:
	inst.name = StringName(room_name if layer == 0 else path.get_file().get_basename())
	_get_room_parent(room_name).add_child(inst)
	_apply_room_light_isolation(inst, room_name)
	_apply_exit_code_to_scene(inst)
	if layer == 0:
		_register_room_nav_regions(room_name, inst)
		_ensure_hub_seam_light()
		_connect_autosave_doors()
	_apply_pending_world_state()
	if _interaction_controller != null and _interaction_controller.has_method("retry_pending_restores"):
		_interaction_controller.call("retry_pending_restores")


func _lkey(room_name: String, layer: int) -> String:
	return room_name + ":" + str(layer)


func _is_arch_loaded(room_name: String) -> bool:
	var d: Dictionary = _stream_rooms.get(room_name, {})
	var nodes: Array = d.get("nodes", [])
	return not nodes.is_empty() and is_instance_valid(nodes[0] as Node)


func _update_room_streaming(delta: float) -> void:
	if not room_streaming_enabled:
		return
	if _stream_rooms.is_empty():
		return
	_check_pending_loads()
	_stream_update_accum += delta
	if _stream_update_accum < ROOM_STREAM_UPDATE_INTERVAL_SEC:
		return
	_stream_update_accum = 0.0
	_apply_room_streaming()


func _check_pending_loads() -> void:
	if _stream_pending.is_empty():
		return
	for key in _stream_pending.keys():
		var path: String = _stream_pending[key]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			continue
		var elapsed_ms: int = Time.get_ticks_msec() - int(_stream_start_ms.get(key, Time.get_ticks_msec()))
		var packed := ResourceLoader.load_threaded_get(path) as PackedScene
		_stream_pending.erase(key)
		_stream_start_ms.erase(key)
		if packed == null:
			continue
		var sep: int = key.rfind(":")
		var room_name: String = key.left(sep)
		var layer := int(key.substr(sep + 1))
		var d: Dictionary = _stream_rooms.get(room_name, {})
		if d.is_empty():
			continue
		var nodes: Array = d.get("nodes", [])
		while nodes.size() <= layer:
			nodes.append(null)
		if is_instance_valid(nodes[layer] as Node):
			continue
		var t_inst := Time.get_ticks_msec()
		var inst := packed.instantiate() as Node3D
		var t_done := Time.get_ticks_msec()
		if inst == null:
			continue
		_add_layer_node(room_name, layer, inst, path)
		nodes[layer] = inst
		d["nodes"] = nodes
		_stream_rooms[room_name] = d
		print("[RoomStream] Async loaded '%s' L%d: thread=%dms  instantiate=%dms" % [room_name, layer, elapsed_ms, t_done - t_inst])
	_check_if_should_start_deferred()


func _check_if_should_start_deferred() -> void:
	if _deferred_started or _new_game_priority_room != "":
		return
	for key in _stream_pending.keys():
		var sep: int = key.rfind(":")
		if int(key.substr(sep + 1)) == 0:
			var room_name: String = key.left(sep)
			if not (_stream_rooms.get(room_name, {}) as Dictionary).get("deferred", false):
				return
	_start_deferred_room_loads()


func _start_deferred_room_loads() -> void:
	if _deferred_started or _new_game_priority_room != "":
		return
	_deferred_started = true
	for room_name in _stream_rooms.keys():
		var d: Dictionary = _stream_rooms[room_name]
		if not d.get("deferred", false):
			continue
		if _is_arch_loaded(room_name):
			continue
		_queue_room(room_name)
		print("[RoomStream] Deferred async-load started: %s" % room_name)


func _register_room_nav_regions(room_name: String, room_node: Node3D) -> void:
	var regions: Array[NavigationRegion3D] = []
	_collect_nav_regions(room_node, regions)
	if not regions.is_empty():
		_room_nav_regions[room_name] = regions


func _collect_nav_regions(node: Node, result: Array[NavigationRegion3D]) -> void:
	if node is NavigationRegion3D:
		result.append(node as NavigationRegion3D)
	for child in node.get_children():
		_collect_nav_regions(child, result)


func _detect_player_room() -> String:
	var player_pos := player.global_position
	var nav_agent := player.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav_agent != null:
		var nav_map := nav_agent.get_navigation_map()
		var owner_rid := NavigationServer3D.map_get_closest_point_owner(nav_map, player_pos)
		if owner_rid.is_valid():
			for room_name in _room_nav_regions.keys():
				for region: NavigationRegion3D in (_room_nav_regions[room_name] as Array[NavigationRegion3D]):
					if region.get_rid() == owner_rid:
						return room_name
	# Fallback: nearest room center (used for rooms with no nav mesh)
	var best_room := ""
	var best_dist := INF
	for room_name in _stream_rooms.keys():
		var room_data: Dictionary = _stream_rooms[room_name]
		if room_data.get("deferred", false):
			continue
		var dist := player_pos.distance_to(room_data["center"] as Vector3)
		if dist < best_dist:
			best_dist = dist
			best_room = room_name
	return best_room


func _get_room_parent(room_name: String) -> Node3D:
	var room_data: Dictionary = _stream_rooms.get(room_name, {})
	if room_data.get("deferred", false):
		return _stream_station_root.get_parent() as Node3D
	return _stream_station_root


func _apply_room_light_isolation(room_root: Node3D, room_name: String) -> void:
	if room_root == null:
		return
	if not ROOM_LIGHT_ISOLATION_LAYER_BITS.has(room_name):
		return
	var layer_bit := int(ROOM_LIGHT_ISOLATION_LAYER_BITS[room_name])
	var room_visual_mask := 1 << (layer_bit - 1)
	var room_light_mask := room_visual_mask
	_apply_room_visual_layer_recursive(room_root, room_visual_mask)
	_apply_room_light_cull_mask_recursive(room_root, room_light_mask)


func _build_all_room_light_layers_mask() -> int:
	var mask := DEFAULT_VISUAL_LAYER_MASK
	for room_name in ROOM_LIGHT_ISOLATION_LAYER_BITS.keys():
		var bit := int(ROOM_LIGHT_ISOLATION_LAYER_BITS[room_name])
		mask |= 1 << (bit - 1)
	return mask


func _apply_player_room_light_layers() -> void:
	if _player_visual_root == null:
		return
	var player_mask := _build_all_room_light_layers_mask()
	_apply_visual_layer_recursive(_player_visual_root, player_mask)


func apply_cross_room_visual_layers(node: Node) -> void:
	if node == null:
		return
	var cross_room_mask := _build_all_room_light_layers_mask()
	_apply_visual_layer_recursive(node, cross_room_mask)


func _apply_visual_layer_recursive(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_mask
	for child in node.get_children():
		_apply_visual_layer_recursive(child, layer_mask)


func _ensure_hub_seam_light() -> void:
	if _stream_station_root == null:
		return
	if _stream_station_root.get_node_or_null(HUB_SEAM_LIGHT_NAME) != null:
		return
	if not ROOM_LIGHT_ISOLATION_LAYER_BITS.has("atrium"):
		return
	var atrium_layer_bit := int(ROOM_LIGHT_ISOLATION_LAYER_BITS["atrium"])
	var atrium_layer_mask := 1 << (atrium_layer_bit - 1)

	var seam_light := OmniLight3D.new()
	seam_light.name = HUB_SEAM_LIGHT_NAME
	seam_light.position = HUB_SEAM_LIGHT_POSITION
	seam_light.light_color = Color(0.78, 0.86, 0.98, 1.0)
	seam_light.light_energy = HUB_SEAM_LIGHT_ENERGY
	seam_light.light_specular = 0.0
	seam_light.shadow_enabled = false
	seam_light.omni_range = HUB_SEAM_LIGHT_RANGE
	seam_light.omni_attenuation = 1.0
	seam_light.light_cull_mask = atrium_layer_mask
	_stream_station_root.add_child(seam_light)


func _apply_room_visual_layer_recursive(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		var visual := node as VisualInstance3D
		# Put room visuals on room-only layer so room lights do not spill into
		# neighboring room geometry.
		visual.layers = layer_mask
	for child in node.get_children():
		_apply_room_visual_layer_recursive(child, layer_mask)


func _apply_room_light_cull_mask_recursive(node: Node, light_mask: int) -> void:
	if node is Light3D:
		# Force a narrowed mask: shared/default visuals + allowed room layers.
		var light := node as Light3D
		light.light_cull_mask = light_mask
	for child in node.get_children():
		_apply_room_light_cull_mask_recursive(child, light_mask)


func _apply_room_streaming() -> void:
	if _stream_station_root == null:
		return
	if _new_game_priority_room != "":
		if not _is_arch_loaded(_new_game_priority_room):
			return
		print("[RoomStream] Priority room '%s' ready, starting all other rooms" % _new_game_priority_room)
		_new_game_priority_room = ""

	var detected_room := _detect_player_room()
	if detected_room != _player_current_room:
		print("[RoomStream] Player room: %s → %s" % [_player_current_room if _player_current_room != "" else "none", detected_room])
		_player_current_room = detected_room
	var current_neighbors: Array = []
	if _player_current_room != "" and _stream_rooms.has(_player_current_room):
		current_neighbors = _stream_rooms[_player_current_room]["neighbors"] as Array

	var player_pos := player.global_position
	for room_name in _stream_rooms.keys():
		var d: Dictionary = _stream_rooms[room_name]
		if d.get("deferred", false):
			continue
		var dist := player_pos.distance_to(d["center"] as Vector3)
		var in_range: bool = room_names_to_always_keep.has(String(room_name)) \
			or room_name == _player_current_room \
			or current_neighbors.has(room_name) \
			or dist <= room_load_distance

		if in_range and not _is_arch_loaded(room_name):
			_queue_room(room_name)
		elif not in_range and dist >= room_unload_distance:
			_unload_room(room_name)


func _unload_room(room_name: String) -> void:
	var d: Dictionary = _stream_rooms.get(room_name, {})
	var nodes: Array = d.get("nodes", [])
	var any_freed := false
	for i in nodes.size():
		if is_instance_valid(nodes[i] as Node):
			(nodes[i] as Node).queue_free()
			nodes[i] = null
			any_freed = true
	if any_freed:
		d["nodes"] = nodes
		_stream_rooms[room_name] = d
	var layers: Array = d.get("layers", [])
	for i in layers.size():
		var key := _lkey(room_name, i)
		_stream_pending.erase(key)
		_stream_start_ms.erase(key)
	_room_nav_regions.erase(room_name)
	if any_freed:
		print("[RoomStream] Unloaded '%s'" % room_name)


func _unhandled_input(event: InputEvent) -> void:
	if _has_settings_overlay():
		if _is_escape_press(event):
			_close_settings_overlay()
			get_viewport().set_input_as_handled()
		return

	if _is_escape_press(event):
		if _focus_mode:
			_exit_focus_mode()
			get_viewport().set_input_as_handled()
			return
		if _interaction_controller != null and _interaction_controller.consume_escape():
			get_viewport().set_input_as_handled()
			return
		_set_in_game_menu_visible(not in_game_menu.visible)
		get_viewport().set_input_as_handled()
		return

	if in_game_menu.visible:
		return


func _input(event: InputEvent) -> void:
	_handle_pointer_input(event)


func _handle_pointer_input(event: InputEvent) -> void:
	if _has_settings_overlay():
		return

	if in_game_menu.visible:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if _focus_mode and not _is_document_focus_active():
				get_viewport().set_input_as_handled()
				return
			spring_arm.spring_length = clampf(spring_arm.spring_length - zoom_step, min_zoom, max_zoom)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if _focus_mode and not _is_document_focus_active():
				get_viewport().set_input_as_handled()
				return
			spring_arm.spring_length = clampf(spring_arm.spring_length + zoom_step, min_zoom, max_zoom)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_primary_pointer(event.position)
			else:
				if _end_primary_pointer(event.position):
					get_viewport().set_input_as_handled()
			return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_primary_pointer(event.position)
		else:
			if _end_primary_pointer(event.position):
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		if _update_primary_pointer_drag(event.position, event.relative):
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		if _update_primary_pointer_drag(event.position, event.relative):
			get_viewport().set_input_as_handled()
		return


func _begin_primary_pointer(screen_position: Vector2) -> void:
	_primary_pointer_down = true
	_primary_pointer_dragging = false
	_primary_pointer_start = screen_position


func _end_primary_pointer(screen_position: Vector2) -> bool:
	if not _primary_pointer_down:
		return false
	var was_dragging := _primary_pointer_dragging
	_primary_pointer_down = false
	_primary_pointer_dragging = false
	_orbiting = false
	if was_dragging:
		return true
	return _handle_primary_click(screen_position)


func _update_primary_pointer_drag(screen_position: Vector2, relative: Vector2) -> bool:
	if not _primary_pointer_down:
		return false
	if not _primary_pointer_dragging and screen_position.distance_to(_primary_pointer_start) >= drag_orbit_threshold_px:
		_primary_pointer_dragging = true
	if not _primary_pointer_dragging:
		return false
	if _focus_mode:
		_apply_focus_pan(relative)
		return true
	_orbiting = true
	_yaw -= relative.x * orbit_sensitivity
	_pitch = clampf(_pitch - relative.y * orbit_sensitivity, orbit_pitch_min_degrees, orbit_pitch_max_degrees)
	_apply_camera_angles()
	return true


func _apply_focus_pan(relative: Vector2) -> void:
	if not _is_document_focus_active():
		return
	if _focus_target == null or not is_instance_valid(_focus_target):
		return
	if _focus_tween != null:
		_focus_tween.kill()
	var scale := focus_pan_sensitivity * maxf(0.2, spring_arm.spring_length)
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var delta := (-right * relative.x + up * relative.y) * scale
	_focus_pan_offset += delta
	if _focus_pan_offset.length() > focus_pan_max_distance:
		_focus_pan_offset = _focus_pan_offset.normalized() * focus_pan_max_distance
	camera_pivot.global_position = _focus_target.get_focus_position() + _focus_pan_offset


func _is_document_focus_active() -> bool:
	if not _focus_mode:
		return false
	if _focus_target == null or not is_instance_valid(_focus_target):
		return false
	var focus_host = _focus_target.get_parent()
	return focus_host is DocumentItem or focus_host is IncidentReport


func _handle_primary_click(screen_position: Vector2) -> bool:
	if _focus_mode:
		if _interaction_controller.try_handle_interaction_click(screen_position):
			return true
		if _interaction_controller.try_interact_with_focus_target(screen_position):
			return true
		if _interaction_controller.is_click_over_focus_items(screen_position):
			return true
		_exit_focus_mode()
		return true

	var clicked_focus_target = _interaction_controller.get_focus_target_at_screen(screen_position)
	if clicked_focus_target != null:
		_focus_pending_target = clicked_focus_target
		var focus_host = clicked_focus_target.get_parent()
		if focus_host is IncidentReport:
			_interaction_controller.try_handle_interaction_click(screen_position)
		if _interaction_controller.can_enter_focus_target(clicked_focus_target):
			_enter_focus_mode(clicked_focus_target)
		else:
			_interaction_controller.request_approach_focus_target(clicked_focus_target)
		return true
	if _interaction_controller.try_handle_interaction_click(screen_position):
		return true
	if clicked_focus_target != null:
		_interaction_controller.request_approach_focus_target(clicked_focus_target)
		return true
	var click_position: Vector3 = _raycast_to_ground(screen_position)
	if click_position.is_finite():
		if _interaction_controller.try_handle_ground_move_click():
			return true
		player.set_move_target(click_position)
		return true
	return false


func _process_pending_focus_entry() -> void:
	if _focus_mode:
		return
	if _focus_pending_target == null:
		return
	if not is_instance_valid(_focus_pending_target):
		_focus_pending_target = null
		return
	if _interaction_controller.can_enter_focus_target(_focus_pending_target):
		_enter_focus_mode(_focus_pending_target)
		_focus_pending_target = null


func _process_focus_mode() -> void:
	if not _focus_mode:
		return
	if _focus_target == null or not is_instance_valid(_focus_target):
		_exit_focus_mode()
		return
	if _focus_target.auto_exit_on_solved and _interaction_controller.is_focus_target_solved(_focus_target):
		_exit_focus_mode()


func _enter_focus_mode(target) -> void:
	if target == null:
		return
	_focus_mode = true
	_focus_target = target
	_focus_pan_offset = Vector3.ZERO
	_focus_pending_target = null
	_saved_spring_length = spring_arm.spring_length
	_saved_yaw = _yaw
	_saved_pitch = _pitch
	_saved_roll = _roll
	_saved_min_zoom = min_zoom
	_saved_max_zoom = max_zoom
	_saved_zoom_step = zoom_step
	var focus_host: Node = target.get_parent()
	var is_document_focus := (
		focus_host is DocumentItem
		or focus_host is IncidentReport
	)
	_hide_held_items_in_focus = is_document_focus
	if is_document_focus:
		if target.focus_min_zoom > 0.0:
			min_zoom = target.focus_min_zoom
		if target.focus_max_zoom > 0.0:
			max_zoom = target.focus_max_zoom
		if target.focus_zoom_step > 0.0:
			zoom_step = target.focus_zoom_step
	player.clear_move_target()
	_interaction_controller.set_focus_locked(true)
	_interaction_controller.set_focus_display(true, camera)
	_interaction_controller.set_focus_target_visual_suppressed(not is_document_focus and not (focus_host is IncidentReport))
	_interaction_controller.set_focus_target(_focus_target)
	_set_focus_visuals_enabled(false)
	var target_angles := _compute_focus_angles(target)
	_yaw = target_angles.x
	_pitch = target_angles.y
	_roll = target_angles.z
	var zoom: float = _saved_spring_length
	if target.focus_zoom_start > 0.0:
		zoom = target.focus_zoom_start
	elif is_document_focus:
		zoom = focus_zoom_distance if target.focus_zoom_start <= 0.0 else target.focus_zoom_start
	_start_focus_tween(_focus_target.get_focus_position(), zoom)


func _exit_focus_mode() -> void:
	if not _focus_mode:
		return
	var exiting_target = _focus_target
	_focus_pan_offset = Vector3.ZERO
	_focus_mode = false
	_focus_target = null
	_focus_pending_target = null
	_hide_held_items_in_focus = false
	_interaction_controller.set_focus_locked(false)
	_interaction_controller.set_focus_display(false, null)
	_interaction_controller.set_focus_target_visual_suppressed(false)
	_interaction_controller.set_focus_target(null)
	_set_focus_visuals_enabled(true)
	_yaw = _saved_yaw
	_pitch = _saved_pitch
	_roll = _saved_roll
	min_zoom = _saved_min_zoom
	max_zoom = _saved_max_zoom
	zoom_step = _saved_zoom_step
	var follow_position := player.global_position + Vector3(0.0, CAMERA_FOLLOW_HEIGHT, 0.0)
	follow_position.y = maxf(follow_position.y, CAMERA_MIN_WORLD_Y)
	var is_document_focus := (
		exiting_target != null
		and (
			exiting_target.get_parent() is DocumentItem
			or exiting_target.get_parent() is IncidentReport
		)
	)
	if is_document_focus:
		_start_focus_tween(
			follow_position,
			_saved_spring_length,
			focus_return_tween_duration,
			Tween.TRANS_SINE,
			Tween.EASE_IN_OUT
		)
	else:
		_start_focus_tween(follow_position, _saved_spring_length)


func _start_focus_tween(
	target_pivot_position: Vector3,
	target_zoom: float,
	duration: float = focus_tween_duration,
	trans: Tween.TransitionType = Tween.TRANS_CUBIC,
	ease: Tween.EaseType = Tween.EASE_OUT
) -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	var current_yaw := camera_yaw.rotation_degrees.y
	var current_pitch := camera_pitch.rotation_degrees.x
	var current_roll := camera_pitch.rotation_degrees.z
	var tween_yaw := _shortest_angle_target_degrees(current_yaw, _yaw)
	var tween_pitch := _shortest_angle_target_degrees(current_pitch, _pitch)
	var tween_roll := _shortest_angle_target_degrees(current_roll, _roll)
	_focus_tween = create_tween().set_ease(ease).set_trans(trans)
	_focus_tween.tween_property(camera_pivot, "global_position", target_pivot_position, duration)
	_focus_tween.parallel().tween_property(spring_arm, "spring_length", target_zoom, duration)
	_focus_tween.parallel().tween_property(camera_yaw, "rotation_degrees:y", tween_yaw, duration)
	_focus_tween.parallel().tween_property(camera_pitch, "rotation_degrees:x", tween_pitch, duration)
	_focus_tween.parallel().tween_property(camera_pitch, "rotation_degrees:z", tween_roll, duration)


func _set_focus_visuals_enabled(is_enabled: bool) -> void:
	if _player_visual_root != null:
		_player_visual_root.visible = is_enabled
	var items_visible := is_enabled or (_focus_mode and not _hide_held_items_in_focus)
	_interaction_controller.set_held_item_visuals_visible(items_visible)
	var wear_controller := _player_visual_root.get_parent().get_node_or_null("WearController") as WearController if _player_visual_root != null else null
	if wear_controller != null:
		# Worn items should follow octo visibility, not held-item focus visibility.
		wear_controller.set_worn_item_visuals_visible(is_enabled)


func _compute_focus_angles(target) -> Vector3:
	var target_position: Vector3 = target.get_focus_position()
	var to_camera: Vector3 = camera.global_position - target_position
	to_camera.y = 0.0
	var default_yaw := _yaw
	if to_camera.length_squared() > 0.0001:
		# Keep the camera on the same side of the target when entering focus.
		default_yaw = wrapf(rad_to_deg(atan2(to_camera.x, to_camera.z)), -180.0, 180.0)
	else:
		var host := target.get_parent() as Node3D
		if host != null:
			default_yaw = wrapf(rad_to_deg(host.global_rotation.y) - 180.0, -180.0, 180.0)
	var desired_yaw = target.get_focus_yaw_degrees(default_yaw)
	var desired_pitch = target.get_focus_pitch_degrees(-22.0)
	var desired_roll = target.get_focus_roll_degrees(0.0)
	return Vector3(desired_yaw, desired_pitch, desired_roll)


func _shortest_angle_target_degrees(current: float, target: float) -> float:
	return current + wrapf(target - current, -180.0, 180.0)


func _create_interaction_controller() -> void:
	_interaction_controller = InteractionControllerScript.new()
	_interaction_controller.name = "InteractionController"
	add_child(_interaction_controller)
	_interaction_controller.process_mode = Node.PROCESS_MODE_PAUSABLE
	_interaction_controller.initialize(player, camera, hint_label, self)


func _configure_camera_collision() -> void:
	# Imported station meshes can end up on layer 1 while manual blockers use layer 2.
	# Layer 5 is reserved for authored camera blockers.
	# Keep camera collision on all three so SpringArm prevents wall clipping consistently.
	spring_arm.collision_mask = CAMERA_OBSTACLE_COLLISION_MASK
	if spring_arm.margin < CAMERA_MIN_MARGIN:
		spring_arm.margin = CAMERA_MIN_MARGIN
	if spring_arm.shape == null:
		var probe_shape := SphereShape3D.new()
		probe_shape.radius = CAMERA_PROBE_RADIUS
		spring_arm.shape = probe_shape
	camera.near = CAMERA_NEAR_CLIP


func _apply_camera_angles() -> void:
	camera_yaw.rotation_degrees.y = _yaw
	camera_pitch.rotation_degrees.x = _pitch
	camera_pitch.rotation_degrees.z = _roll


func _raycast_to_ground(screen_position: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_position)
	var ray_normal := camera.project_ray_normal(screen_position)
	var to := from + ray_normal * 500.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = CLICK_TARGET_COLLISION_MASK
	query.collide_with_areas = false
	query.exclude = [player]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.INF

	var hit_position: Vector3 = result.position
	var hit_normal: Vector3 = result.normal
	if hit_normal.dot(Vector3.UP) >= 0.65:
		return hit_position

	# If player clicks an object side, bias target to its top surface.
	var down_from := hit_position + Vector3.UP * 1.6
	var down_to := hit_position + Vector3.DOWN * 0.6
	var down_query := PhysicsRayQueryParameters3D.create(down_from, down_to)
	down_query.collision_mask = CLICK_TARGET_COLLISION_MASK
	down_query.collide_with_areas = false
	down_query.exclude = [player]
	var top_result := get_world_3d().direct_space_state.intersect_ray(down_query)
	if not top_result.is_empty() and (top_result.normal as Vector3).dot(Vector3.UP) >= 0.65:
		return top_result.position

	return hit_position


func _is_escape_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	return false


func _set_in_game_menu_visible(is_visible: bool) -> void:
	if is_visible and _focus_mode:
		_exit_focus_mode()
	in_game_menu.visible = is_visible
	get_tree().paused = is_visible
	_orbiting = false
	if is_visible:
		_interaction_controller.set_interaction_enabled(false)
	if is_visible:
		in_game_resume_button.grab_focus()


func is_focus_target_active(target) -> bool:
	if not _focus_mode:
		return false
	if target == null:
		return false
	return _focus_target == target


func is_focus_mode_active() -> bool:
	return _focus_mode


func exit_focus_mode() -> void:
	_exit_focus_mode()


func _make_click_through(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child: Node in node.get_children():
		_make_click_through(child)


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	_clear_pending_load_request()
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error != OK:
		push_error("Failed to load main menu scene: %s" % MAIN_MENU_SCENE_PATH)


func _on_resume_pressed() -> void:
	_set_in_game_menu_visible(false)


func _on_pause_menu_button_pressed() -> void:
	if _has_settings_overlay():
		return
	if _focus_mode:
		_exit_focus_mode()
	_set_in_game_menu_visible(not in_game_menu.visible)


func _on_save_pressed() -> void:
	var save_ok := _save_game(false)
	if save_ok:
		_show_save_feedback("Game Saved", false)
	else:
		_show_save_feedback("Save Failed", true)


func _on_settings_pressed() -> void:
	if _has_settings_overlay():
		return

	var settings_menu := SETTINGS_MENU_SCENE.instantiate() as Control
	settings_menu.set("is_overlay", true)
	settings_menu.closed.connect(_on_settings_overlay_closed)
	$UI.add_child(settings_menu)
	settings_menu.call_deferred("_grab_initial_focus")
	_settings_overlay = settings_menu
	in_game_menu.visible = false


func _on_settings_overlay_closed() -> void:
	_close_settings_overlay()


func _close_settings_overlay() -> void:
	if _settings_overlay == null:
		return
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
	_settings_overlay = null
	in_game_menu.visible = true
	in_game_resume_button.grab_focus()


func _has_settings_overlay() -> bool:
	return _settings_overlay != null and is_instance_valid(_settings_overlay)


func _connect_shadow_setting() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return
	var enabled := true
	if settings.has_method("get_shadows_enabled"):
		enabled = bool(settings.call("get_shadows_enabled"))
	_apply_positional_shadows(enabled)
	if settings.has_signal("shadows_enabled_changed"):
		settings.shadows_enabled_changed.connect(_apply_positional_shadows)


func _apply_positional_shadows(enabled: bool) -> void:
	_set_positional_shadows_recursive(self, enabled)


func _set_positional_shadows_recursive(node: Node, enabled: bool) -> void:
	if node is DirectionalLight3D:
		(node as Light3D).shadow_enabled = enabled
	elif node is OmniLight3D:
		(node as Light3D).shadow_enabled = enabled
	elif node is SpotLight3D:
		var spot := node as SpotLight3D
		if spot.light_projector == null:
			spot.shadow_enabled = enabled
	for child in node.get_children():
		_set_positional_shadows_recursive(child, enabled)


func _connect_autosave_doors() -> void:
	for node in get_tree().get_nodes_in_group("autosave_door"):
		if not (node is Node):
			continue
		var door := node as Node
		if not is_ancestor_of(door):
			continue
		if not door.has_signal("door_opened"):
			continue
		var handler := Callable(self, "_on_autosave_door_opened")
		if not door.is_connected("door_opened", handler):
			door.connect("door_opened", handler)


func _on_autosave_door_opened(_source: Node) -> void:
	if _save_game(true):
		_show_save_feedback("Autosaved", false)


func _apply_loaded_world_state() -> void:
	_apply_pending_world_state()
	_loaded_save_data.clear()


func _apply_pending_world_state() -> void:
	if _pending_world_state.is_empty():
		return
	var applied: Array[String] = []
	for key in _pending_world_state.keys():
		var node := _resolve_node_from_save_key(str(key))
		if node == null or not node.has_method("apply_save_state"):
			continue
		var state = _pending_world_state[key]
		if state is Dictionary:
			node.call("apply_save_state", state)
			applied.append(str(key))
	for key in applied:
		_pending_world_state.erase(key)


func _extract_player_position(save_data: Dictionary, fallback: Vector3) -> Vector3:
	if save_data.is_empty():
		return fallback
	var player_data = save_data.get("player", {})
	if not (player_data is Dictionary):
		return fallback
	var position_data = (player_data as Dictionary).get("position", [])
	if position_data is Array and (position_data as Array).size() == 3:
		var p := position_data as Array
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	return fallback


func _save_game(is_autosave: bool) -> bool:
	var now := Time.get_unix_time_from_system()
	if is_autosave and (now - _last_save_unix_time) < AUTOSAVE_MIN_INTERVAL_SEC:
		return false

	var payload := {
		"player": {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"room": _player_current_room,
		},
		"world": _capture_world_state(),
		"game_time": _capture_game_time_state()
	}
	var save_ok := _save_payload(payload)
	if save_ok:
		_last_save_unix_time = now
	return save_ok


func _capture_world_state() -> Dictionary:
	var result := {}
	for provider in _collect_save_providers():
		if provider == null or not is_instance_valid(provider):
			continue
		if not provider.has_method("get_save_state"):
			continue
		var state = provider.call("get_save_state")
		if not (state is Dictionary):
			continue
		result[_provider_to_save_key(provider)] = state
	return result


func _collect_save_providers() -> Array[Node]:
	var providers: Array[Node] = []
	for node in get_tree().get_nodes_in_group("save_state_provider"):
		if not (node is Node):
			continue
		var provider := node as Node
		if is_ancestor_of(provider):
			providers.append(provider)
	return providers


func _node_path_to_save_key(node: Node) -> String:
	return str(node.get_path())


func _provider_to_save_key(provider: Node) -> String:
	if provider != null and provider.has_method("get_save_key"):
		var custom_key = provider.call("get_save_key")
		if custom_key is String:
			var key := (custom_key as String).strip_edges()
			if not key.is_empty():
				return key
	return _node_path_to_save_key(provider)


func _resolve_node_from_save_key(path_key: String) -> Node:
	var node := get_node_or_null(NodePath(path_key))
	if node != null:
		return node
	node = _resolve_provider_by_custom_save_key(path_key)
	if node != null:
		return node
	var this_path := str(get_path())
	var prefix := "/root/%s/" % name
	if path_key.begins_with(prefix):
		var relative := path_key.trim_prefix(prefix)
		if not relative.is_empty():
			return get_node_or_null(NodePath(relative))
	elif path_key.begins_with("%s/" % this_path):
		var relative_from_self := path_key.trim_prefix("%s/" % this_path)
		if not relative_from_self.is_empty():
			return get_node_or_null(NodePath(relative_from_self))
	return null


func _resolve_provider_by_custom_save_key(path_key: String) -> Node:
	for provider in _collect_save_providers():
		if provider == null or not is_instance_valid(provider):
			continue
		if not provider.has_method("get_save_key"):
			continue
		var custom_key = provider.call("get_save_key")
		if custom_key is String and str(custom_key) == path_key:
			return provider
	return null


func _initialize_game_time(save_data: Dictionary) -> void:
	var game_time := _get_game_time()
	if game_time == null:
		return
	if save_data.is_empty():
		game_time.call("start_new_game", 17, 0, 0.0)
		return
	var game_time_data = save_data.get("game_time", {})
	if game_time_data is Dictionary and game_time.call("load_save_state", game_time_data):
		return
	game_time.call("start_new_game", 17, 0, 0.0)


func _capture_game_time_state() -> Dictionary:
	var game_time := _get_game_time()
	if game_time == null:
		return {}
	var state = game_time.call("get_save_state")
	if state is Dictionary:
		return state as Dictionary
	return {}


func _get_game_save() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GameSave")


func _get_game_time() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GameTime")


func _consume_pending_load_request() -> bool:
	var game_save := _get_game_save()
	if game_save == null:
		return false
	return bool(game_save.call("consume_load_request"))


func _load_saved_game() -> Dictionary:
	var game_save := _get_game_save()
	if game_save == null:
		return {}
	var loaded = game_save.call("load_game")
	if loaded is Dictionary:
		return loaded as Dictionary
	return {}


func _save_payload(payload: Dictionary) -> bool:
	var game_save := _get_game_save()
	if game_save == null:
		return false
	return bool(game_save.call("save_game", payload))


func _clear_pending_load_request() -> void:
	var game_save := _get_game_save()
	if game_save == null:
		return
	game_save.call("clear_load_request")


func _show_save_feedback(message: String, is_error: bool) -> void:
	if save_status_icon == null:
		return
	if _save_status_tween != null:
		_save_status_tween.kill()
	_save_status_tween = null
	save_status_icon.tooltip_text = message
	save_status_icon.scale = Vector2(0.96, 0.96)
	save_status_icon.modulate = Color(1.0, 0.86, 0.86, 0.0) if is_error else Color(0.94, 0.98, 1.0, 0.0)
	save_status_icon.visible = true
	_save_status_tween = create_tween()
	_save_status_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_save_status_tween.parallel().tween_property(save_status_icon, "modulate:a", 0.8, 0.24)
	_save_status_tween.parallel().tween_property(save_status_icon, "scale", Vector2.ONE, 0.26)
	_save_status_tween.tween_interval(1.35)
	_save_status_tween.parallel().tween_property(save_status_icon, "modulate:a", 0.0, 0.55)
	_save_status_tween.parallel().tween_property(save_status_icon, "scale", Vector2(0.98, 0.98), 0.55)
	_save_status_tween.finished.connect(func() -> void:
		save_status_icon.visible = false
		save_status_icon.scale = Vector2.ONE
	)


func _get_game_settings() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GameSettings")


func _initialize_exit_code(is_loading_saved_game: bool) -> void:
	var settings := _get_game_settings()
	if settings == null:
		_exit_code = _generate_random_exit_code()
		return
	if not is_loading_saved_game and settings.has_method("generate_new_exit_code"):
		_exit_code = int(settings.call("generate_new_exit_code"))
		return
	if settings.has_method("get_exit_code"):
		_exit_code = int(settings.call("get_exit_code"))
	if _exit_code >= EXIT_CODE_MIN and _exit_code <= EXIT_CODE_MAX:
		return
	if settings.has_method("generate_new_exit_code"):
		_exit_code = int(settings.call("generate_new_exit_code"))
	else:
		_exit_code = _generate_random_exit_code()


func _generate_random_exit_code() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(EXIT_CODE_MIN, EXIT_CODE_MAX)


func _apply_exit_code_to_scene(root_node: Node) -> void:
	if root_node == null:
		return
	var exit_code_text := "%04d" % clampi(_exit_code, EXIT_CODE_MIN, EXIT_CODE_MAX)
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != null and node.name == "ExitCodeLabel" and node is Label3D:
			(node as Label3D).text = exit_code_text
		if node == null:
			continue
		for child in node.get_children():
			stack.append(child)


func _animate_underwater_light(delta: float) -> void:
	if not underwater_light_motion_enabled or sun_light == null:
		return
	if _underwater_light_time == 0.0:
		_sun_base_rotation = sun_light.rotation_degrees
		_sun_base_energy = sun_light.light_energy
		if skylight_hero_light != null:
			_hero_base_energy = skylight_hero_light.light_energy

	var motion_speed := maxf(underwater_light_motion_speed, 0.0)
	if sync_main_light_with_god_rays and god_rays_node != null:
		var rays_speed = god_rays_node.get("sway_speed")
		if rays_speed is float or rays_speed is int:
			motion_speed = maxf(float(rays_speed), 0.0)

	_underwater_light_time += delta * motion_speed
	var sway_a := sin(_underwater_light_time)
	var sway_b := sin(_underwater_light_time * 0.67 + 1.2)
	if main_light_sway_enabled:
		sun_light.rotation_degrees = Vector3(
			_sun_base_rotation.x + sway_a * underwater_light_pitch_amplitude,
			_sun_base_rotation.y + sway_b * underwater_light_yaw_amplitude,
			_sun_base_rotation.z
		)
	else:
		sun_light.rotation_degrees = _sun_base_rotation
	var pulse_01 := 0.5 + 0.5 * sin(_underwater_light_time + 0.4)
	if sync_main_light_with_god_rays and god_rays_node != null:
		var ray_pulse = god_rays_node.get("master_pulse_01")
		if ray_pulse is float or ray_pulse is int:
			pulse_01 = clampf(float(ray_pulse), 0.0, 1.0)
	var light_factor := lerpf(main_light_min_factor, main_light_max_factor, pulse_01)
	sun_light.light_energy = maxf(0.0, _sun_base_energy * light_factor)
	if skylight_hero_light != null:
		skylight_hero_light.light_energy = maxf(0.0, _hero_base_energy + sway_a * underwater_light_energy_amplitude * 0.7)
