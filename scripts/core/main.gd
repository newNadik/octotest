extends Node3D


const CLICK_TARGET_COLLISION_MASK := (1 << 0) | (1 << 1)
const CAMERA_OBSTACLE_COLLISION_MASK := (1 << 0) | (1 << 1) | (1 << 4)
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
# Preloads make these room scenes dependencies of main.gd, so the loading
# screen's threaded load pulls them all into the resource cache. When
# _initialize_room_streaming() calls load() on them they return instantly.
const _SCENE_ATRIUM     := preload("res://scenes/station/atrium_room.tscn")
const _SCENE_CHEM_LAB   := preload("res://scenes/station/chem_lab_room.tscn")
const _SCENE_ENERGY_LAB := preload("res://scenes/station/energy_lab_room.tscn")
const _SCENE_OFFICE     := preload("res://scenes/station/office_room.tscn")
const _SCENE_QUARTERS   := preload("res://scenes/station/quarters_room.tscn")
const _SCENE_SYSTEMS    := preload("res://scenes/station/systems_room.tscn")
const _SCENE_WETROOM    := preload("res://scenes/station/wetroom_room.tscn")
const _SCENE_WORKSHOP   := preload("res://scenes/station/workshop_room.tscn")
const ROOM_REGISTRY: Array[Dictionary] = [
	{"name": "atrium",     "path": "res://scenes/station/atrium_room.tscn"},
	{"name": "checm_lab",  "path": "res://scenes/station/chem_lab_room.tscn"},
	{"name": "energy_lab", "path": "res://scenes/station/energy_lab_room.tscn"},
	{"name": "office",     "path": "res://scenes/station/office_room.tscn"},
	{"name": "quarters",   "path": "res://scenes/station/quarters_room.tscn"},
	{"name": "systems",    "path": "res://scenes/station/systems_room.tscn"},
	{"name": "wetroom",    "path": "res://scenes/station/wetroom_room.tscn"},
	{"name": "workshop",   "path": "res://scenes/station/workshop_room.tscn"},
]

@export var orbit_sensitivity := 0.2
@export var drag_orbit_threshold_px := 10.0
@export var orbit_pitch_min_degrees := -80.0
@export var orbit_pitch_max_degrees := 20.0
@export var min_zoom := 2.4
@export var max_zoom := 10.0
@export var zoom_step := 1.0
@export var focus_zoom_distance := 2.0
@export var focus_tween_duration := 0.24
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
@export var room_names_to_always_keep: PackedStringArray = PackedStringArray(["atrium"])

@onready var player: CharacterBody3D = $Player
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_yaw: Node3D = $CameraPivot/CameraYaw
@onready var camera_pitch: Node3D = $CameraPivot/CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraPivot/CameraYaw/CameraPitch/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/CameraYaw/CameraPitch/SpringArm3D/Camera3D
@onready var gameplay_fx: ColorRect = $UI/GameplayFX
@onready var pause_menu_button: Button = $UI/PauseMenuButton
@onready var hud_root: Control = $UI/HUD
@onready var hint_label: Label = $UI/HUD/HintPanel/HintMargin/HintLabel
@onready var save_status_icon: TextureRect = $UI/SaveStatusIcon
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
var _focus_mode := false
var _focus_target
var _focus_pending_target
var _focus_tween: Tween
var _saved_spring_length := 9.0
var _player_visual_root: Node3D
var _settings_overlay: Control
var _underwater_light_time := 0.0
var _sun_base_rotation := Vector3.ZERO
var _sun_base_energy := 0.0
var _hero_base_energy := 0.0
var _loaded_save_data: Dictionary = {}
var _last_save_unix_time := -1000.0
var _save_status_tween: Tween
var _stream_station_root: Node3D
var _stream_rooms: Dictionary = {}
var _stream_pending_loads: Dictionary = {}
var _stream_update_accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	in_game_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_apply_platform_visual_overrides()
	var starting_position := Vector3(0.0, OCTO_START_Y, 16.0)
	var is_loading_saved_game := _consume_pending_load_request()
	if is_loading_saved_game:
		_loaded_save_data = _load_saved_game()
		starting_position = _extract_player_position(_loaded_save_data, starting_position)
		_initialize_game_time(_loaded_save_data)
		MusicManager.play_game_loop()
	else:
		_initialize_game_time({})
		MusicManager.play_game_start()
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
	in_game_resume_button.pressed.connect(_on_resume_pressed)
	in_game_save_button.pressed.connect(_on_save_pressed)
	in_game_settings_button.pressed.connect(_on_settings_pressed)
	in_game_main_menu_button.pressed.connect(_on_main_menu_pressed)
	pause_menu_button.pressed.connect(_on_pause_menu_button_pressed)
	_connect_autosave_doors()
	_apply_loaded_world_state()
	_initialize_room_streaming()
	_set_in_game_menu_visible(false)


func _apply_platform_visual_overrides() -> void:
	if not _should_use_mobile_visual_fallbacks():
		return
	#_apply_mobile_environment_fallbacks()
	_apply_mobile_material_fallbacks()
	#_apply_mobile_light_fallbacks()
	#_apply_mobile_omni_fallbacks()


func _should_use_mobile_visual_fallbacks() -> bool:
	return OS.has_feature("mobile") or MOBILE_OS_NAMES.has(OS.get_name())


func _apply_mobile_environment_fallbacks() -> void:
	var environment := world_environment.environment
	if environment == null:
		return

	# iOS/Metal drops or changes several desktop-biased features; lean on plain depth fog instead.
	environment.fog_enabled = true
	environment.fog_density = 0.026
	environment.fog_depth_begin = 2.6
	environment.fog_depth_end = 20.0
	environment.fog_sky_affect = 0.16
	environment.volumetric_fog_enabled = false
	environment.ambient_light_sky_contribution = 0.58
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.0
	environment.adjustment_saturation = 0.96


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


func _apply_mobile_light_fallbacks() -> void:
	if sun_light != null:
		sun_light.shadow_enabled = false
		sun_light.shadow_blur = 0.0
		sun_light.light_energy = 0.24

	if skylight_hero_light != null:
		skylight_hero_light.shadow_enabled = true
		skylight_hero_light.shadow_blur = 0.0
		skylight_hero_light.shadow_bias = 0.03
		skylight_hero_light.shadow_normal_bias = 0.18
		skylight_hero_light.light_volumetric_fog_energy = 0.0
		skylight_hero_light.light_energy = 1.05
		skylight_hero_light.light_indirect_energy = 0.42

	_set_mobile_spot_light("lights/GodRays/RoofShaft", false, 0.0, 0.0)
	_set_mobile_spot_light("lights/GodRays/RoofShaftFillA", false, 0.0, 0.0)
	_set_mobile_spot_light("lights/GodRays/RoofShaftFillB", false, 0.0, 0.0)
	_set_mobile_spot_light("lights/Caustics/CausticLightA", false, 0.0, 20.0)
	_set_mobile_spot_light("lights/Caustics/CausticLightB", false, 0.0, 20.0)
	_set_mobile_spot_light("lights/Caustics2/CausticLightA", false, 0.0, 20.0)
	_set_mobile_spot_light("lights/Caustics2/CausticLightB", false, 0.0, 20.0)


func _set_mobile_spot_light(light_path: String, keep_shadow: bool, blur: float, energy: float) -> void:
	var spot_light := get_node_or_null(light_path) as SpotLight3D
	if spot_light == null:
		return
	spot_light.shadow_enabled = keep_shadow
	spot_light.shadow_blur = blur
	spot_light.light_volumetric_fog_energy = 0.0
	spot_light.light_energy = energy


func _apply_mobile_omni_fallbacks() -> void:
	for omni_light in _collect_omni_lights(self):
		omni_light.shadow_enabled = false
		omni_light.light_indirect_energy = 0.0
		omni_light.light_energy = 0.0


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
			"scene_path": room_def["path"],
			"transform": Transform3D.IDENTITY,
			"node": null
		}

	if room_load_distance <= 0.0:
		return

	# Sync-load every room that should be present when gameplay starts.
	# load() returns instantly from cache because the preload constants above
	# caused the loading screen's threaded load to pull them all in already.
	var player_pos := player.global_position
	for room_name in _stream_rooms.keys():
		var room_data: Dictionary = _stream_rooms[room_name]
		var room_origin: Vector3 = (room_data["transform"] as Transform3D).origin
		var distance := player_pos.distance_to(room_origin)
		var should_keep := room_names_to_always_keep.has(String(room_name))
		if should_keep or distance <= room_load_distance:
			_load_room_now(room_name)


func _load_room_now(room_name: String) -> void:
	var room_data: Dictionary = _stream_rooms.get(room_name, {})
	if room_data.is_empty():
		return
	if is_instance_valid(room_data.get("node") as Node):
		return
	var scene_path := String(room_data["scene_path"])
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		return
	var instance := packed_scene.instantiate() as Node3D
	if instance == null:
		return
	instance.name = StringName(room_name)
	instance.transform = room_data["transform"] as Transform3D
	_stream_station_root.add_child(instance)
	room_data["node"] = instance
	_stream_rooms[room_name] = room_data


func _update_room_streaming(delta: float) -> void:
	if not room_streaming_enabled:
		return
	if _stream_rooms.is_empty():
		return
	_check_pending_room_loads()
	_stream_update_accum += delta
	if _stream_update_accum < ROOM_STREAM_UPDATE_INTERVAL_SEC:
		return
	_stream_update_accum = 0.0
	_apply_room_streaming()


func _check_pending_room_loads() -> void:
	if _stream_pending_loads.is_empty():
		return
	for room_name in _stream_pending_loads.keys():
		var scene_path: String = _stream_pending_loads[room_name]
		var status := ResourceLoader.load_threaded_get_status(scene_path)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			continue
		var packed_scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
		_stream_pending_loads.erase(room_name)
		if packed_scene == null:
			continue
		var room_data: Dictionary = _stream_rooms.get(room_name, {})
		if room_data.is_empty():
			continue
		if is_instance_valid(room_data.get("node") as Node):
			continue
		var instance := packed_scene.instantiate() as Node3D
		if instance == null:
			continue
		instance.name = StringName(room_name)
		instance.transform = room_data["transform"] as Transform3D
		_stream_station_root.add_child(instance)
		room_data["node"] = instance
		_stream_rooms[room_name] = room_data


func _apply_room_streaming() -> void:
	if _stream_station_root == null:
		return
	var player_pos := player.global_position
	for room_name in _stream_rooms.keys():
		var room_data: Dictionary = _stream_rooms[room_name]
		var room_origin: Vector3 = (room_data["transform"] as Transform3D).origin
		var distance := player_pos.distance_to(room_origin)
		var is_loaded := is_instance_valid(room_data["node"] as Node)
		var should_keep := room_names_to_always_keep.has(String(room_name))

		if (should_keep or distance <= room_load_distance) and not is_loaded:
			var scene_path := String(room_data["scene_path"])
			if not _stream_pending_loads.has(room_name):
				var err := ResourceLoader.load_threaded_request(scene_path)
				if err == OK or err == ERR_BUSY:
					_stream_pending_loads[room_name] = scene_path
			continue

		if not should_keep and distance >= room_unload_distance:
			_stream_pending_loads.erase(room_name)
			if is_loaded:
				var instance_node := room_data["node"] as Node
				if instance_node != null:
					instance_node.queue_free()
				room_data["node"] = null
				_stream_rooms[room_name] = room_data


func _unhandled_input(event: InputEvent) -> void:
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
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

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			spring_arm.spring_length = clampf(spring_arm.spring_length - zoom_step, min_zoom, max_zoom)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
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
		return true
	_orbiting = true
	_yaw -= relative.x * orbit_sensitivity
	_pitch = clampf(_pitch - relative.y * orbit_sensitivity, orbit_pitch_min_degrees, orbit_pitch_max_degrees)
	_apply_camera_angles()
	return true


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
	_focus_pending_target = null
	_saved_spring_length = spring_arm.spring_length
	player.clear_move_target()
	_interaction_controller.set_focus_locked(true)
	_interaction_controller.set_focus_display(true, camera)
	_interaction_controller.set_focus_target(_focus_target)
	_set_focus_visuals_enabled(false)
	var target_angles := _compute_focus_angles(target)
	_yaw = target_angles.x
	_pitch = target_angles.y
	_start_focus_tween(_focus_target.get_focus_position(), focus_zoom_distance)


func _exit_focus_mode() -> void:
	if not _focus_mode:
		return
	_focus_mode = false
	_focus_target = null
	_focus_pending_target = null
	_interaction_controller.set_focus_locked(false)
	_interaction_controller.set_focus_display(false, null)
	_interaction_controller.set_focus_target(null)
	_set_focus_visuals_enabled(true)
	var follow_position := player.global_position + Vector3(0.0, CAMERA_FOLLOW_HEIGHT, 0.0)
	follow_position.y = maxf(follow_position.y, CAMERA_MIN_WORLD_Y)
	_start_focus_tween(follow_position, _saved_spring_length)


func _start_focus_tween(target_pivot_position: Vector3, target_zoom: float) -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_focus_tween.tween_property(camera_pivot, "global_position", target_pivot_position, focus_tween_duration)
	_focus_tween.parallel().tween_property(spring_arm, "spring_length", target_zoom, focus_tween_duration)
	_focus_tween.parallel().tween_property(camera_yaw, "rotation_degrees:y", _yaw, focus_tween_duration)
	_focus_tween.parallel().tween_property(camera_pitch, "rotation_degrees:x", _pitch, focus_tween_duration)


func _set_focus_visuals_enabled(is_enabled: bool) -> void:
	if _player_visual_root != null:
		_player_visual_root.visible = is_enabled
	_interaction_controller.set_held_item_visuals_visible(is_enabled or _focus_mode)


func _compute_focus_angles(target) -> Vector2:
	var host := target.get_parent() as Node3D
	var default_yaw := _yaw
	if host != null:
		default_yaw = wrapf(rad_to_deg(host.global_rotation.y) - 180.0, -180.0, 180.0)
	var desired_yaw = target.get_focus_yaw_degrees(default_yaw)
	var desired_pitch = target.get_focus_pitch_degrees(-22.0)
	return Vector2(desired_yaw, desired_pitch)


func _create_interaction_controller() -> void:
	_interaction_controller = InteractionControllerScript.new()
	_interaction_controller.name = "InteractionController"
	add_child(_interaction_controller)
	_interaction_controller.process_mode = Node.PROCESS_MODE_PAUSABLE
	_interaction_controller.initialize(player, camera, hint_label, self, room_light)


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
	if gameplay_fx != null:
		gameplay_fx.visible = not is_visible
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
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
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
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		return

	var settings_menu := SETTINGS_MENU_SCENE.instantiate() as Control
	settings_menu.set("is_overlay", true)
	settings_menu.closed.connect(_on_settings_overlay_closed)
	add_child(settings_menu)
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
	if _loaded_save_data.is_empty():
		return
	var world_state = _loaded_save_data.get("world", {})
	if not (world_state is Dictionary):
		return
	var providers := world_state as Dictionary
	for key in providers.keys():
		var node := _resolve_node_from_save_key(str(key))
		if node == null or not node.has_method("apply_save_state"):
			continue
		var state = providers[key]
		if state is Dictionary:
			node.call("apply_save_state", state)
	_loaded_save_data.clear()


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
			"position": [player.global_position.x, player.global_position.y, player.global_position.z]
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
