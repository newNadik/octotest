extends Node3D


const CLICK_TARGET_COLLISION_MASK := (1 << 0) | (1 << 1)
const CAMERA_OBSTACLE_COLLISION_MASK := (1 << 0) | (1 << 1)
const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const SETTINGS_MENU_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const InteractionControllerScript = preload("res://scripts/interaction/interaction_controller.gd")
const OCTO_START_Y := 0.26
const CAMERA_FOLLOW_HEIGHT := 0.65
const CAMERA_MIN_WORLD_Y := 1.25
const CAMERA_PROBE_RADIUS := 0.32
const CAMERA_MIN_MARGIN := 0.4
const CAMERA_NEAR_CLIP := 0.12

@export var orbit_sensitivity := 0.2
@export var drag_orbit_threshold_px := 10.0
@export var min_zoom := 2.4
@export var max_zoom := 10.0
@export var zoom_step := 1.0
@export var focus_zoom_distance := 2.0
@export var focus_tween_duration := 0.24
@export var camera_follow_lerp_speed := 10.0
@export var camera_follow_deadzone := 0.03

@onready var player: CharacterBody3D = $Player
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_yaw: Node3D = $CameraPivot/CameraYaw
@onready var camera_pitch: Node3D = $CameraPivot/CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraPivot/CameraYaw/CameraPitch/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/CameraYaw/CameraPitch/SpringArm3D/Camera3D
@onready var hud_root: Control = $UI/HUD
@onready var hint_label: Label = $UI/HUD/HintPanel/HintMargin/HintLabel
@onready var in_game_menu: Control = $UI/InGameMenu
@onready var in_game_resume_button: Button = $UI/InGameMenu/MenuCenter/MenuPanel/MenuMargin/MenuButtons/ResumeButton
@onready var in_game_main_menu_button: Button = $UI/InGameMenu/MenuCenter/MenuPanel/MenuMargin/MenuButtons/MainMenuButton
@onready var in_game_settings_button: Button = $UI/InGameMenu/MenuCenter/MenuPanel/MenuMargin/MenuButtons/SettingsButton
@onready var room_light: OmniLight3D = $OmniLight3D

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	in_game_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.global_position = Vector3(0.0, OCTO_START_Y, 0.0)
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
	in_game_settings_button.pressed.connect(_on_settings_pressed)
	in_game_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_set_in_game_menu_visible(false)


func _physics_process(delta: float) -> void:
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
	_pitch = clampf(_pitch - relative.y * orbit_sensitivity, -80.0, -10.0)
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
	# Keep camera collision on both so SpringArm prevents wall clipping consistently.
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
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error != OK:
		push_error("Failed to load main menu scene: %s" % MAIN_MENU_SCENE_PATH)


func _on_resume_pressed() -> void:
	_set_in_game_menu_visible(false)


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
