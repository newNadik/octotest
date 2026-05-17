extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

const WALL_COLLISION_MASK := 1 << 0
const GROUND_COLLISION_MASK := 1 << 1
const PLAYER_COLLISION_LAYER := 1 << 2
const MovementMath = preload("res://scripts/core/movement_math.gd")
const CLIMB_PHASE_FIRST_REACH := 0
const CLIMB_PHASE_SECOND_REACH := 1
const CLIMB_PHASE_TRANSITION := 2
const INTERACTION_ARM_PHASE_REACH := 0
const INTERACTION_ARM_PHASE_HOLD := 1
const INTERACTION_ARM_PHASE_RETURN := 2

var move_speed := 6.0
var acceleration := 22.0
var stop_distance := 0.2
var gravity_scale := 1.0
var turn_speed := 10.0
var crawl_turn_speed_scale := 0.55
var crawl_heading_smoothing := 10.0
var step_height := 0.4
var mantle_height := 1.2
var mantle_duration := 0.75
var climb_probe_distance := 1.0
var climb_surface_min_up_dot := 0.7
var climb_wall_max_up_dot := 0.3
var mantle_landing_forward := 0.28
var mantle_clearance := 0.08
var min_landing_half_extent := 0.14
var climb_collision_mask := WALL_COLLISION_MASK | GROUND_COLLISION_MASK
var use_surface_locomotion := true
var surface_align_strength := 7.5
var climb_front_arm_a := "arm_0"
var climb_front_arm_b := "arm_1"
var climb_first_arm_lead_duration := 0.1
var climb_reach_phase_duration := 0.14
var climb_turn_phase_duration := 0.08
var climb_turn_speed := 12.0
var climb_head_tilt_degrees := 7.0
var interaction_arm_reach_duration := 0.22
var interaction_arm_hold_duration := 0.06
var interaction_arm_return_duration := 0.28
var interaction_post_move_slow_duration := 2.2
var interaction_post_move_speed_scale_min := 0.05
var interaction_face_duration := 0.32
var interaction_face_turn_speed := 14.0

var _has_target := false
var _target_position := Vector3.ZERO
var _gravity := 9.8
var _half_height := 0.5
var _mantling := false
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_control := Vector3.ZERO
var _mantle_progress := 0.0
var _mantle_duration_active := 0.75
var _post_mantle_turn_timer := 0.0
var _octo_rig: Node
var _visual_root: Node3D
var _smoothed_motion_dir := Vector2(0.0, 1.0)
var _blocked_move_feedback_time := 0.0
var _blocked_move_feedback_duration := 0.62
var _blocked_move_feedback_roll := deg_to_rad(2.0)
var _blocked_move_feedback_yaw := deg_to_rad(9.0)
var _climb_head_tilt := 0.0
var _pre_mantle_active := false
var _pre_mantle_phase := 0
var _pre_mantle_phase_time := 0.0
var _pre_mantle_planar_direction := Vector3.ZERO
var _pre_mantle_turn_target_yaw := 0.0
var _post_mantle_move_target := Vector3.ZERO
var _has_post_mantle_move_target := false
var _interaction_arm_active := false
var _interaction_arm_name := ""
var _interaction_arm_phase := INTERACTION_ARM_PHASE_REACH
var _interaction_arm_phase_time := 0.0
var _interaction_face_active := false
var _interaction_face_time := 0.0
var _interaction_face_target := Vector3.ZERO
var _interaction_post_move_slow_time := 0.0
const POST_MANTLE_TURN_DAMP_TIME := 0.22


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	collision_layer = PLAYER_COLLISION_LAYER
	collision_mask = WALL_COLLISION_MASK | GROUND_COLLISION_MASK
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is BoxShape3D:
		_half_height = (shape_node.shape as BoxShape3D).size.y * 0.5
	_octo_rig = get_node_or_null("PlayerVisual")
	_visual_root = _octo_rig as Node3D
	if _visual_root == null:
		_visual_root = get_node_or_null("MeshInstance3D") as Node3D
	var forward := -global_transform.basis.z
	var planar_forward := Vector2(forward.x, forward.z)
	if planar_forward.length_squared() > 0.0001:
		_smoothed_motion_dir = planar_forward.normalized()


func set_move_target(world_target: Vector3) -> void:
	_target_position = world_target
	_has_target = true
	_has_post_mantle_move_target = false


func clear_move_target() -> void:
	_has_target = false
	_mantling = false
	_has_post_mantle_move_target = false
	_cancel_pre_mantle_sequence()


func trigger_blocked_move_feedback() -> void:
	_blocked_move_feedback_time = _blocked_move_feedback_duration
	clear_move_target()


func _physics_process(delta: float) -> void:
	_process_interaction_face_target(delta)

	if _process_climb_phase(delta):
		_process_interaction_arm_gesture(delta)
		_update_visual_feedback(delta)
		return

	if _post_mantle_turn_timer > 0.0:
		_post_mantle_turn_timer = maxf(0.0, _post_mantle_turn_timer - delta)
	_tick_interaction_post_move_window(delta)

	var floor_normal := Vector3.UP
	var grounded := is_on_floor()
	if grounded:
		floor_normal = get_floor_normal()

	if _has_target and _is_move_target_reached():
		_has_target = false

	var move_target := global_position
	if _has_target:
		move_target = _get_drive_target()
	var interaction_speed_scale := _get_interaction_post_move_speed_scale()

	var used_surface_drive := false
	if use_surface_locomotion and _octo_rig != null and _octo_rig.has_method("step_surface_locomotion"):
		var desired_dir := Vector3.ZERO
		if _has_target:
			var to_target := move_target - global_position
			desired_dir = Vector3(to_target.x, 0.0, to_target.z)
		var drive_velocity: Vector3 = _octo_rig.step_surface_locomotion(delta, global_position, desired_dir, velocity)
		drive_velocity.x *= interaction_speed_scale
		drive_velocity.z *= interaction_speed_scale
		velocity.x = move_toward(velocity.x, drive_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, drive_velocity.z, acceleration * delta)
		used_surface_drive = true

	if not used_surface_drive:
		velocity = MovementMath.next_velocity_2d(
			velocity,
			global_position,
			move_target,
			move_speed * interaction_speed_scale,
			acceleration,
			stop_distance,
			delta
		)

	if grounded:
		_align_planar_velocity_to_slope(floor_normal)

	if not grounded:
		velocity.y -= _gravity * gravity_scale * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if _has_target and grounded:
		_try_begin_climb(move_target)

	if interaction_speed_scale < 0.999:
		velocity.x *= interaction_speed_scale
		velocity.z *= interaction_speed_scale

	move_and_slide()
	if use_surface_locomotion and grounded and _octo_rig != null and _octo_rig.has_method("get_surface_support_normal"):
		var support_normal: Vector3 = _octo_rig.get_surface_support_normal()
		if support_normal.length_squared() > 0.0001:
			var planar_forward := -global_transform.basis.z
			var aligned_forward := MovementMath.project_planar_direction_on_surface(planar_forward, support_normal)
			if aligned_forward.length_squared() > 0.0001:
				aligned_forward = aligned_forward.normalized()
				var target_basis := Basis.looking_at(aligned_forward, support_normal)
				global_transform.basis = global_transform.basis.slerp(
					target_basis,
					1.0 - exp(-surface_align_strength * delta)
				).orthonormalized()
	_rotate_toward_motion(delta)
	_process_interaction_arm_gesture(delta)
	_update_visual_feedback(delta)


func _process_climb_phase(delta: float) -> bool:
	if _pre_mantle_active:
		_update_surface_crawl_pose(delta, _pre_mantle_planar_direction)
		_process_pre_mantle(delta)
		return true
	if _mantling:
		var mantle_dir := _mantle_to - global_position
		_update_surface_crawl_pose(delta, Vector3(mantle_dir.x, 0.0, mantle_dir.z))
		_process_mantle(delta)
		return true
	return false


func _rotate_toward_motion(delta: float) -> void:
	var planar_velocity := Vector2(velocity.x, velocity.z)
	if planar_velocity.length() <= 0.08:
		return
	var target_dir := planar_velocity.normalized()
	var speed := turn_speed
	if use_surface_locomotion:
		var dir_alpha := 1.0 - exp(-crawl_heading_smoothing * maxf(delta, 0.0))
		_smoothed_motion_dir = _smoothed_motion_dir.lerp(target_dir, dir_alpha)
		if _smoothed_motion_dir.length_squared() > 0.0001:
			target_dir = _smoothed_motion_dir.normalized()
		speed *= crawl_turn_speed_scale
	if _post_mantle_turn_timer > 0.0:
		speed *= 0.35
	_rotate_toward_planar(target_dir, delta, speed)


func _rotate_toward_planar(planar_direction: Vector2, delta: float, speed: float) -> void:
	if planar_direction.length() <= 0.01:
		return
	var target_yaw := atan2(planar_direction.x, planar_direction.y)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, speed * delta))


func _align_planar_velocity_to_slope(floor_normal: Vector3) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed <= 0.001:
		return

	var direction_hint := Vector3(velocity.x, 0.0, velocity.z)
	if _has_target:
		direction_hint = _target_position - global_position

	var slope_direction := MovementMath.project_planar_direction_on_surface(direction_hint, floor_normal)
	if slope_direction == Vector3.ZERO:
		return

	velocity.x = slope_direction.x * planar_speed
	velocity.z = slope_direction.z * planar_speed


func _update_visual_feedback(delta: float) -> void:
	if _visual_root == null:
		return
	var tilt_target := 0.0
	if _pre_mantle_active:
		tilt_target = deg_to_rad(climb_head_tilt_degrees * 0.6)
	elif _mantling:
		tilt_target = deg_to_rad(climb_head_tilt_degrees)
	_climb_head_tilt = lerpf(_climb_head_tilt, tilt_target, minf(1.0, 8.0 * delta))

	if _blocked_move_feedback_time <= 0.0:
		_visual_root.rotation = _visual_root.rotation.lerp(
			Vector3(_climb_head_tilt, 0.0, 0.0),
			minf(1.0, 8.0 * delta)
		)
		return

	_blocked_move_feedback_time = maxf(0.0, _blocked_move_feedback_time - delta)
	var progress := 1.0 - (_blocked_move_feedback_time / _blocked_move_feedback_duration)
	var envelope := sin(progress * PI)
	var phase := progress * TAU * 1.35
	var yaw := sin(phase) * _blocked_move_feedback_yaw * envelope
	_visual_root.rotation = Vector3(
		_climb_head_tilt,
		yaw,
		(-yaw * 0.2) + (sin(phase + PI * 0.5) * _blocked_move_feedback_roll * envelope)
	)


func _process_mantle(delta: float) -> void:
	_mantle_progress += delta / maxf(0.01, _mantle_duration_active)
	var t := minf(_mantle_progress, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	global_position = _quadratic_bezier(_mantle_from, _mantle_control, _mantle_to, eased)
	velocity = Vector3.ZERO
	var mantle_planar := Vector2(_mantle_to.x - global_position.x, _mantle_to.z - global_position.z)
	_rotate_toward_planar(mantle_planar, delta, turn_speed * 0.65)
	if t >= 1.0:
		_mantling = false
		_clear_climb_arm_overrides()
		_post_mantle_turn_timer = POST_MANTLE_TURN_DAMP_TIME
		_resume_post_mantle_move_target()


func _try_begin_climb(drive_target: Vector3) -> void:
	var to_target := drive_target - global_position
	var planar_direction := Vector3(to_target.x, 0.0, to_target.z)
	if planar_direction.length() <= 0.01:
		planar_direction = Vector3(velocity.x, 0.0, velocity.z)
		if planar_direction.length() <= 0.01:
			return
	planar_direction = planar_direction.normalized()

	var wall_hit := _find_wall_hit(planar_direction)
	var top_hit := Dictionary()
	if not wall_hit.is_empty():
		var top_probe_start: Vector3 = wall_hit.position + planar_direction * 0.12 + Vector3.UP * (mantle_height + mantle_clearance)
		var top_probe_end: Vector3 = top_probe_start + Vector3.DOWN * (mantle_height + step_height + 0.35)
		top_hit = _cast_ray(top_probe_start, top_probe_end, climb_collision_mask)

	if top_hit.is_empty():
		top_hit = _find_target_top_hit(drive_target)
		if top_hit.is_empty():
			return

	var top_normal: Vector3 = top_hit.normal
	if top_normal.dot(Vector3.UP) < climb_surface_min_up_dot:
		return
	if not _has_landing_footprint(top_hit.position, planar_direction):
		return

	var target_center_y: float = top_hit.position.y + _half_height + 0.01
	var climb_delta: float = target_center_y - global_position.y
	if climb_delta <= 0.01 or climb_delta > mantle_height:
		return

	var desired_click_target := _target_position
	var landing_point := _find_edge_landing_point(top_hit.position, planar_direction)
	var target_position := Vector3(landing_point.x, target_center_y, landing_point.z)

	var height_ratio := clampf(climb_delta / maxf(0.01, mantle_height), 0.0, 1.0)
	var duration_scale := lerpf(0.55, 1.15, height_ratio)
	if climb_delta <= step_height:
		duration_scale = maxf(0.45, duration_scale * 0.8)
	_queue_post_mantle_move_target(desired_click_target, target_center_y)
	_begin_pre_mantle_sequence(target_position, planar_direction, mantle_duration * duration_scale)


func _begin_pre_mantle_sequence(target_position: Vector3, planar_direction: Vector3, mantle_time: float) -> void:
	_cancel_interaction_arm_gesture()
	_mantle_to = target_position
	_mantle_duration_active = mantle_time
	_pre_mantle_planar_direction = planar_direction.normalized()
	_pre_mantle_active = true
	_pre_mantle_phase = 0
	_pre_mantle_phase_time = 0.0
	_has_target = false
	velocity = Vector3.ZERO
	var target_yaw := atan2(_pre_mantle_planar_direction.x, _pre_mantle_planar_direction.z)
	_pre_mantle_turn_target_yaw = target_yaw
	_apply_climb_arm_reach_pose(climb_front_arm_a, 0.0)
	_apply_climb_arm_reach_pose(climb_front_arm_b, 0.0)


func _process_pre_mantle(delta: float) -> void:
	velocity = Vector3.ZERO
	_pre_mantle_phase_time += delta
	var target_planar := Vector2(sin(_pre_mantle_turn_target_yaw), cos(_pre_mantle_turn_target_yaw))
	_rotate_toward_planar(target_planar, delta, climb_turn_speed)
	match _pre_mantle_phase:
		CLIMB_PHASE_FIRST_REACH:
			var t0 := clampf(_pre_mantle_phase_time / maxf(0.01, climb_first_arm_lead_duration), 0.0, 1.0)
			_apply_climb_arm_reach_pose(climb_front_arm_a, t0)
			_apply_climb_arm_reach_pose(climb_front_arm_b, 0.0)
			if t0 >= 1.0:
				_pre_mantle_phase = CLIMB_PHASE_SECOND_REACH
				_pre_mantle_phase_time = 0.0
		CLIMB_PHASE_SECOND_REACH:
			var t1 := clampf(_pre_mantle_phase_time / maxf(0.01, climb_reach_phase_duration), 0.0, 1.0)
			_apply_climb_arm_reach_pose(climb_front_arm_a, 1.0)
			_apply_climb_arm_reach_pose(climb_front_arm_b, t1)
			if t1 >= 0.78:
				_pre_mantle_phase = CLIMB_PHASE_TRANSITION
				_pre_mantle_phase_time = 0.0
		CLIMB_PHASE_TRANSITION:
			var t2 := clampf(_pre_mantle_phase_time / maxf(0.01, climb_turn_phase_duration), 0.0, 1.0)
			_apply_climb_arm_reach_pose(climb_front_arm_a, 1.0)
			_apply_climb_arm_reach_pose(climb_front_arm_b, 1.0)
			if t2 >= 1.0:
				_start_mantle_after_pre_climb()


func _start_mantle_after_pre_climb() -> void:
	_pre_mantle_active = false
	_pre_mantle_phase = 0
	_pre_mantle_phase_time = 0.0
	_mantling = true
	_mantle_from = global_position
	_mantle_control = _build_mantle_control_point(_mantle_from, _mantle_to)
	_mantle_progress = 0.0


func _cancel_pre_mantle_sequence() -> void:
	_pre_mantle_active = false
	_pre_mantle_phase = 0
	_pre_mantle_phase_time = 0.0
	_clear_climb_arm_overrides()


func play_interaction_arm_gesture(arm_name: String, target_position: Vector3 = Vector3.INF) -> bool:
	if _pre_mantle_active or _mantling:
		return false
	if not _is_valid_climb_arm(arm_name):
		return false
	if target_position.is_finite():
		_interaction_face_active = true
		_interaction_face_time = interaction_face_duration
		_interaction_face_target = target_position
	_interaction_post_move_slow_time = maxf(_interaction_post_move_slow_time, interaction_post_move_slow_duration)
	_interaction_arm_active = true
	_interaction_arm_name = arm_name
	_interaction_arm_phase = INTERACTION_ARM_PHASE_REACH
	_interaction_arm_phase_time = 0.0
	return true


func _process_interaction_arm_gesture(delta: float) -> void:
	if not _interaction_arm_active:
		return
	if _pre_mantle_active or _mantling:
		_cancel_interaction_arm_gesture()
		return
	if not _is_valid_climb_arm(_interaction_arm_name):
		_cancel_interaction_arm_gesture()
		return

	match _interaction_arm_phase:
		INTERACTION_ARM_PHASE_REACH:
			_interaction_arm_phase_time += delta
			var t_reach := clampf(_interaction_arm_phase_time / maxf(0.01, interaction_arm_reach_duration), 0.0, 1.0)
			_apply_interaction_arm_reach_pose(_interaction_arm_name, _ease_interaction_arm_t(t_reach))
			if t_reach >= 1.0:
				_interaction_arm_phase = INTERACTION_ARM_PHASE_HOLD
				_interaction_arm_phase_time = 0.0
		INTERACTION_ARM_PHASE_HOLD:
			_interaction_arm_phase_time += delta
			_apply_interaction_arm_reach_pose(_interaction_arm_name, 1.0)
			if _interaction_arm_phase_time >= maxf(0.01, interaction_arm_hold_duration):
				_interaction_arm_phase = INTERACTION_ARM_PHASE_RETURN
				_interaction_arm_phase_time = 0.0
		INTERACTION_ARM_PHASE_RETURN:
			_interaction_arm_phase_time += delta
			var t_return := clampf(_interaction_arm_phase_time / maxf(0.01, interaction_arm_return_duration), 0.0, 1.0)
			_apply_interaction_arm_reach_pose(_interaction_arm_name, 1.0 - _ease_interaction_arm_t(t_return))
			if t_return >= 1.0:
				_cancel_interaction_arm_gesture()


func _cancel_interaction_arm_gesture() -> void:
	if _interaction_arm_active and _is_valid_climb_arm(_interaction_arm_name):
		_octo_rig.call("clear_arm_animation_mode", _interaction_arm_name)
	_interaction_arm_active = false
	_interaction_arm_name = ""
	_interaction_arm_phase = INTERACTION_ARM_PHASE_REACH
	_interaction_arm_phase_time = 0.0


func _process_interaction_face_target(delta: float) -> void:
	if not _interaction_face_active:
		return
	if _interaction_face_time <= 0.0:
		_interaction_face_active = false
		return
	_interaction_face_time = maxf(0.0, _interaction_face_time - delta)
	if _pre_mantle_active or _mantling:
		return
	var to_target := _interaction_face_target - global_position
	var planar := Vector2(to_target.x, to_target.z)
	if planar.length_squared() <= 0.0001:
		return
	_rotate_toward_planar(planar.normalized(), delta, interaction_face_turn_speed)


func _ease_interaction_arm_t(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	# Cubic smoothstep for softer acceleration/deceleration at phase ends.
	return x * x * (3.0 - 2.0 * x)


func _tick_interaction_post_move_window(delta: float) -> void:
	if _interaction_post_move_slow_time <= 0.0:
		return
	_interaction_post_move_slow_time = maxf(0.0, _interaction_post_move_slow_time - delta)


func _get_interaction_post_move_speed_scale() -> float:
	if _interaction_post_move_slow_time <= 0.0 or interaction_post_move_slow_duration <= 0.0:
		return 1.0
	var progress := 1.0 - clampf(_interaction_post_move_slow_time / interaction_post_move_slow_duration, 0.0, 1.0)
	# Stay slow longer, then recover near the end of the window.
	var eased_recovery := progress * progress
	return lerpf(interaction_post_move_speed_scale_min, 1.0, eased_recovery)


func _apply_climb_arm_reach_pose(arm_name: String, intensity: float) -> void:
	if not _is_valid_climb_arm(arm_name):
		return
	var t := clampf(intensity, 0.0, 1.0)
	var inward_sign := _get_climb_arm_inward_sign(arm_name)
	_set_climb_arm_mode_static(arm_name)
	_set_climb_arm_pose(
		arm_name,
		lerpf(0.72, 1.0, t),
		lerpf(0.0, -0.4 * inward_sign, t),
		lerpf(1.3, 0.28, t),
		lerpf(1.1, -0.4 * inward_sign, t),
		lerpf(0.6, -0.5, t),
		lerpf(0.45, 0.14 * inward_sign, t)
	)


func _apply_interaction_arm_reach_pose(arm_name: String, intensity: float) -> void:
	if not _is_valid_climb_arm(arm_name):
		return
	var t := clampf(intensity, 0.0, 1.0)
	var inward_sign := _get_climb_arm_inward_sign(arm_name)
	_set_climb_arm_mode_static(arm_name)
	_set_climb_arm_pose(
		arm_name,
		lerpf(0.72, 1.08, t),
		lerpf(0.0, -0.52 * inward_sign, t),
		lerpf(1.3, 0.12, t),
		lerpf(1.1, -0.52 * inward_sign, t),
		lerpf(0.6, -0.62, t),
		lerpf(0.45, 0.12 * inward_sign, t)
	)


func _clear_climb_arm_overrides() -> void:
	if _octo_rig == null:
		return
	if _is_valid_climb_arm(climb_front_arm_a):
		_octo_rig.call("clear_arm_animation_mode", climb_front_arm_a)
	if _is_valid_climb_arm(climb_front_arm_b):
		_octo_rig.call("clear_arm_animation_mode", climb_front_arm_b)


func _update_surface_crawl_pose(delta: float, desired_dir: Vector3) -> void:
	if not _can_step_surface_pose():
		return
	_octo_rig.call("step_surface_locomotion", delta, global_position, desired_dir, velocity)




func _get_climb_arm_inward_sign(arm_name: String) -> float:
	match arm_name:
		"arm_0", "arm_2", "arm_5", "arm_6":
			return -1.0
		"arm_1", "arm_3", "arm_4", "arm_7":
			return 1.0
		_:
			return 0.0


func _can_step_surface_pose() -> bool:
	return use_surface_locomotion and _octo_rig != null and _octo_rig.has_method("step_surface_locomotion")


func _is_valid_climb_arm(arm_name: String) -> bool:
	return _octo_rig != null and not arm_name.is_empty()


func _set_climb_arm_mode_static(arm_name: String) -> void:
	# 0 maps to OctoRig.ArmAnimMode.STATIC.
	_octo_rig.call("set_arm_animation_mode", arm_name, 0)


func _set_climb_arm_pose(
	arm_name: String,
	base_bend: float,
	base_bend_angle: float,
	mid_bend: float,
	mid_bend_angle: float,
	tip_bend: float,
	tip_bend_angle: float
) -> void:
	_octo_rig.call(
		"set_arm_target_section_bend",
		arm_name,
		base_bend,
		base_bend_angle,
		mid_bend,
		mid_bend_angle,
		tip_bend,
		tip_bend_angle
	)


func _cast_ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = mask
	query.collide_with_areas = false
	query.exclude = [self]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _find_wall_hit(planar_direction: Vector3) -> Dictionary:
	var foot_y := global_position.y - _half_height + 0.05
	var base_from := Vector3(global_position.x, foot_y, global_position.z)
	var right := Vector3.UP.cross(planar_direction).normalized()
	var side_offset := 0.28

	var center_hit := _wall_probe(base_from, planar_direction)
	if not center_hit.is_empty():
		return center_hit

	var right_hit := _wall_probe(base_from + right * side_offset, planar_direction)
	if not right_hit.is_empty():
		return right_hit

	return _wall_probe(base_from - right * side_offset, planar_direction)


func _wall_probe(ray_from: Vector3, planar_direction: Vector3) -> Dictionary:
	var ray_to := ray_from + planar_direction * climb_probe_distance
	var hit := _cast_ray(ray_from, ray_to, climb_collision_mask)
	if hit.is_empty():
		return hit

	var wall_normal: Vector3 = hit.normal
	if wall_normal.y > climb_wall_max_up_dot:
		return {}
	return hit


func _find_target_top_hit(target: Vector3) -> Dictionary:
	var to_target := target - global_position
	var planar_distance := Vector2(to_target.x, to_target.z).length()
	if planar_distance > climb_probe_distance + 0.9:
		return {}
	if target.y <= global_position.y + 0.03:
		return {}

	var down_from := Vector3(
		target.x,
		target.y + mantle_height + mantle_clearance + 0.25,
		target.z
	)
	var down_to := Vector3(
		target.x,
		target.y - (mantle_height + step_height + 0.65),
		target.z
	)
	return _cast_ray(down_from, down_to, climb_collision_mask)


func _has_landing_footprint(top_point: Vector3, planar_direction: Vector3) -> bool:
	var right := Vector3.UP.cross(planar_direction).normalized()
	var offsets := [
		planar_direction * min_landing_half_extent,
		-planar_direction * min_landing_half_extent,
		right * min_landing_half_extent,
		-right * min_landing_half_extent
	]
	for offset in offsets:
		var sample_point: Vector3 = top_point + offset
		var from: Vector3 = sample_point + Vector3.UP * 0.3
		var to: Vector3 = sample_point + Vector3.DOWN * 0.4
		var sample_hit := _cast_ray(from, to, climb_collision_mask)
		if sample_hit.is_empty():
			return false
		var sample_normal: Vector3 = sample_hit.normal
		if sample_normal.dot(Vector3.UP) < climb_surface_min_up_dot:
			return false
		if absf((sample_hit.position as Vector3).y - top_point.y) > 0.06:
			return false
	return true


func _find_edge_landing_point(top_point: Vector3, planar_direction: Vector3) -> Vector3:
	var edge_sample_step := 0.08
	var max_backtrack := climb_probe_distance + 0.65
	var last_supported := top_point
	var found_supported := false
	var distance := 0.0
	while distance <= max_backtrack:
		var sample_point := top_point - planar_direction * distance
		var from := sample_point + Vector3.UP * 0.35
		var to := sample_point + Vector3.DOWN * 0.6
		var sample_hit := _cast_ray(from, to, climb_collision_mask)
		var supported := false
		if not sample_hit.is_empty():
			var sample_normal: Vector3 = sample_hit.normal
			if sample_normal.dot(Vector3.UP) >= climb_surface_min_up_dot:
				supported = true
				last_supported = sample_hit.position
				found_supported = true
		if found_supported and not supported:
			break
		distance += edge_sample_step
	return last_supported + planar_direction * mantle_landing_forward


func _queue_post_mantle_move_target(desired_target: Vector3, target_center_y: float) -> void:
	_post_mantle_move_target = Vector3(desired_target.x, target_center_y, desired_target.z)
	_has_post_mantle_move_target = true


func _resume_post_mantle_move_target() -> void:
	if not _has_post_mantle_move_target:
		return
	_has_post_mantle_move_target = false
	_target_position = _post_mantle_move_target
	_has_target = true


func _build_mantle_control_point(from: Vector3, to: Vector3) -> Vector3:
	var mid := from.lerp(to, 0.5)
	var climb_delta := maxf(0.0, to.y - from.y)
	var lift := maxf(mantle_clearance + 0.08, climb_delta * 0.35)
	mid.y = maxf(from.y, to.y) + lift
	return mid


func _quadratic_bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var ab := a.lerp(b, t)
	var bc := b.lerp(c, t)
	return ab.lerp(bc, t)


func _get_drive_target() -> Vector3:
	return _target_position


func _is_move_target_reached() -> bool:
	return MovementMath.arrived_2d(global_position, _target_position, stop_distance)
