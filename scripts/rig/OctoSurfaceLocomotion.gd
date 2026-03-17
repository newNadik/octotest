extends RefCounted
class_name OctoSurfaceLocomotion


enum ArmStepState {
	SEARCH,
	REACH,
	GRAB,
	PUSH_PULL,
	RELEASE,
}

const ARM_SOCKET_ANGLE_BY_NAME := {
	"arm_0": 2.36,
	"arm_1": 0.78,
	"arm_2": 2.62,
	"arm_3": 0.52,
	"arm_4": -0.52,
	"arm_5": -2.62,
	"arm_6": -2.36,
	"arm_7": -0.78,
}

var enabled := false
var debug_enabled := true
var debug_print_state_changes := false
var debug_print_crawl_base_pose := true
var debug_crawl_pose_log_interval := 0.05

var ground_probe_height := 0.65
var ground_probe_depth := 1.25
var ground_probe_lateral := 0.2
var min_ground_up_dot := 0.55

var workspace_min_radius := 0.45
var workspace_max_radius := 1.4
var workspace_half_angle := 2.4
var reach_forward_distance := 0.62
var reach_side_bias := 0.34

var reach_speed := 7.0
var reach_timeout := 0.42
var release_duration := 0.2
var grip_duration := 0.04
var push_duration := 2.3
var grab_distance := 0.4
var anchor_slip_distance := 0.52
var anchor_stick_tolerance := 0.08

var arm_push_force := 8.4
var max_drive_speed := 3.2
var velocity_response := 7.0
var support_normal_lerp := 6.5
var traction_min := 0.25
var traction_max := 1.0
var slip_force_threshold := 4.2
var min_support_arms := 3
var command_deadzone := 0.06
var no_anchor_fallback_speed := 0.35
var no_anchor_fallback_delay := 0.6
var grab_drive_force_ratio := 0.45

var soft_lift_amplitude := 0.12
var soft_tip_wiggle := 0.18
var gait_frequency := 0.92
var gait_duty_cycle := 0.78
var crawl_bend_plane_offset := 0.0
var role_phase_visual_gain := 1.25
var role_stride_sweep_gain := 2.2
var role_support_gain := 1.15
var role_error_soft_limit := 0.18
var role_error_hard_limit := 0.42
var role_focus_segment := "all" # all | base | mid | tip
var role_focus_blend := 0.72
var role_focus_base_bend_gain := 1.0
var role_focus_base_angle_gain := 4.2
var role_mid_plane_offset := 1.8
var role_mid_bend_sign := 1.0
var crawl_neutral_base_bend := 0.81
var crawl_neutral_mid_bend := 1.83
var crawl_neutral_tip_bend := 3.5
var crawl_swing_lift := 0.16
var crawl_support_contact_blend := 0.38
var crawl_swing_contact_blend := 0.08
var crawl_max_active_bend := 1.8
var simplify_crawl_motion := true

var _rig
var _arms: Array = []
var _arm_runtime_by_name: Dictionary = {}
var _cycle_time := 0.0
var _drive_velocity := Vector3.ZERO
var _support_normal := Vector3.UP
var _anchored_count := 0
var _debug_lines: PackedStringArray = []
var _no_anchor_time := 0.0


func setup(rig, arms: Array) -> void:
	_rig = rig
	_arms = arms.duplicate()
	_arm_runtime_by_name.clear()
	for i in _arms.size():
		var arm = _arms[i]
		if arm == null:
			continue
		var arm_name := str(arm.arm_name)
		var phase = float(i) / maxf(1.0, float(_arms.size()))
		var angle_center := 0.0
		if ARM_SOCKET_ANGLE_BY_NAME.has(arm_name):
			angle_center = float(ARM_SOCKET_ANGLE_BY_NAME[arm_name])
		_arm_runtime_by_name[arm_name] = {
			"name": arm_name,
			"state": ArmStepState.SEARCH,
			"state_time": 0.0,
			"phase": phase,
			"step_group": i % 2,
			"angle_center": angle_center,
			"tip_target": Vector3.ZERO,
			"pole_target": Vector3.ZERO,
			"anchor": Vector3.ZERO,
			"anchor_valid": false,
			"support_normal": Vector3.UP,
			"traction": 1.0,
			"anchor_error": 0.0,
			"last_force": 0.0,
			"crawl_phase": "idle",
			"crawl_phase_t": 0.0,
		}


func step(
	delta: float,
	body_position: Vector3,
	body_basis: Basis,
	desired_direction: Vector3,
	current_velocity: Vector3,
	space_state: PhysicsDirectSpaceState3D
) -> void:
	if not enabled or _rig == null:
		_drive_velocity = Vector3.ZERO
		return
	if _arms.is_empty():
		_drive_velocity = Vector3.ZERO
		_support_normal = Vector3.UP
		_anchored_count = 0
		_debug_lines = PackedStringArray(["surface: no arms"])
		return

	_cycle_time += maxf(0.0, delta)
	var desired_planar := Vector3(desired_direction.x, 0.0, desired_direction.z)
	var has_command := desired_planar.length() > command_deadzone
	if has_command:
		desired_planar = desired_planar.normalized()
	else:
		desired_planar = Vector3.ZERO

	var support_normal_accum := Vector3.ZERO
	var support_count := 0
	var propulsion_force := Vector3.ZERO
	_anchored_count = 0
	_debug_lines = PackedStringArray()
	for arm in _arms:
		if arm == null:
			continue
		var arm_name := str(arm.arm_name)
		if not _arm_runtime_by_name.has(arm_name):
			continue
		var runtime: Dictionary = _arm_runtime_by_name[arm_name]
		runtime["state_time"] = float(runtime["state_time"]) + delta
		runtime["last_force"] = 0.0
		_update_arm_state(runtime, arm, body_position, body_basis, desired_planar, has_command, space_state, delta)
		_apply_arm_pose(runtime, arm, body_position, body_basis, has_command)

		if bool(runtime["anchor_valid"]):
			_anchored_count += 1
			if has_command and (
				int(runtime["state"]) == ArmStepState.PUSH_PULL or int(runtime["state"]) == ArmStepState.GRAB
			):
				var anchor: Vector3 = runtime["anchor"]
				var normal: Vector3 = runtime["support_normal"]
				var anchor_to_body := _project_on_plane(body_position - anchor, normal)
				var drive_dir := _project_on_plane(desired_planar, normal)
				if anchor_to_body.length_squared() > 0.0001:
					anchor_to_body = anchor_to_body.normalized()
				if drive_dir.length_squared() > 0.0001:
					drive_dir = drive_dir.normalized()
				# Grip-driven direction: use anchor/body geometry, but keep it aligned with desired travel.
				var push_dir := drive_dir
				if anchor_to_body.length_squared() > 0.0001:
					push_dir = anchor_to_body
					if drive_dir.length_squared() > 0.0001 and push_dir.dot(drive_dir) < 0.0:
						push_dir = -push_dir
				var traction := clampf(float(runtime["traction"]), 0.0, traction_max)
				var state_force_scale := 1.0 if int(runtime["state"]) == ArmStepState.PUSH_PULL else grab_drive_force_ratio
				var arm_force = arm_push_force * traction * state_force_scale
				propulsion_force += push_dir * arm_force
				runtime["last_force"] = arm_force
				support_normal_accum += normal
				support_count += 1
			else:
				runtime["last_force"] = 0.0

		_arm_runtime_by_name[arm_name] = runtime
		if debug_enabled:
			_debug_lines.append(_debug_line(runtime))

	var target_support := Vector3.UP
	if support_count > 0:
		var averaged := support_normal_accum / float(support_count)
		if averaged.length_squared() > 0.000001:
			target_support = averaged.normalized()
	var current_support := _support_normal
	if current_support.length_squared() <= 0.000001:
		current_support = Vector3.UP
	else:
		current_support = current_support.normalized()
	if target_support.length_squared() <= 0.000001:
		target_support = Vector3.UP
	else:
		target_support = target_support.normalized()
	_support_normal = current_support.slerp(
		target_support,
		1.0 - exp(-support_normal_lerp * maxf(0.0, delta))
	).normalized()

	if _anchored_count < min_support_arms:
		propulsion_force *= clampf(float(_anchored_count) / maxf(1.0, float(min_support_arms)), 0.0, 1.0)

	if has_command and _anchored_count <= 0:
		_no_anchor_time += maxf(0.0, delta)
	else:
		_no_anchor_time = 0.0

	var desired_velocity := propulsion_force if has_command else Vector3.ZERO
	if has_command and _anchored_count <= 0 and _no_anchor_time >= no_anchor_fallback_delay:
		desired_velocity = desired_planar * no_anchor_fallback_speed
	if desired_velocity.length() > max_drive_speed:
		desired_velocity = desired_velocity.normalized() * max_drive_speed
	var alpha := 1.0 - exp(-velocity_response * maxf(0.0, delta))
	_drive_velocity = _drive_velocity.lerp(desired_velocity, alpha)


func get_drive_velocity() -> Vector3:
	return _drive_velocity


func get_support_normal() -> Vector3:
	return _support_normal


func get_anchored_count() -> int:
	return _anchored_count


func get_debug_lines() -> PackedStringArray:
	return _debug_lines


func get_arm_targets() -> Dictionary:
	var result: Dictionary = {}
	for arm_name in _arm_runtime_by_name.keys():
		var runtime: Dictionary = _arm_runtime_by_name[arm_name]
		result[arm_name] = {
			"tip_target": runtime.get("tip_target", Vector3.ZERO),
			"pole_target": runtime.get("pole_target", Vector3.ZERO),
			"anchor": runtime.get("anchor", Vector3.ZERO),
			"anchor_valid": runtime.get("anchor_valid", false),
			"state": runtime.get("state", ArmStepState.SEARCH),
		}
	return result


func _update_arm_state(
	runtime: Dictionary,
	arm,
	body_position: Vector3,
	body_basis: Basis,
	desired_planar: Vector3,
	has_command: bool,
	space_state: PhysicsDirectSpaceState3D,
	delta: float
) -> void:
	var arm_name := str(runtime["name"])
	var tip_now: Vector3 = _rig.get_arm_world_anchor(arm_name, "tip")
	var base_now: Vector3 = _rig.get_arm_world_anchor(arm_name, "base")
	var base_local := base_now - body_position
	base_local.y = 0.0
	var dynamic_angle_center := float(runtime["angle_center"])
	if base_local.length_squared() > 0.0001:
		dynamic_angle_center = atan2(base_local.x, base_local.z)
		runtime["angle_center"] = dynamic_angle_center
	var ground_hit := _sample_ground_contact(tip_now, body_basis, space_state)
	var state: int = int(runtime["state"])
	var state_time: float = float(runtime["state_time"])
	var group := int(runtime.get("step_group", 0))
	# Two 4-arm cohorts oscillate in opposite phase for smoother crawl cadence.
	var group_phase := 0.0 if group == 0 else 0.5
	var group_gait := _gait_value(group_phase)
	var should_step := has_command and group_gait > gait_duty_cycle
	var tip_target: Vector3 = runtime["tip_target"]
	var anchor: Vector3 = runtime["anchor"]

	if not has_command:
		runtime["anchor_valid"] = false
		runtime["traction"] = 1.0
		runtime["last_force"] = 0.0
		runtime["anchor_error"] = 0.0
		var idle_target := _find_idle_target(body_position, body_basis, float(runtime["angle_center"]), space_state)
		if not idle_target.is_empty():
			var settle_target: Vector3 = idle_target.position
			if tip_target == Vector3.ZERO:
				runtime["tip_target"] = settle_target
			else:
				runtime["tip_target"] = tip_target.lerp(settle_target, minf(1.0, delta * 3.0))
			runtime["support_normal"] = idle_target.normal
		runtime["state"] = ArmStepState.SEARCH
		runtime["state_time"] = 0.0
		return

	if state == ArmStepState.SEARCH:
		# Crawl gait: non-stepping arms should stay planted and provide support.
		if has_command and not should_step:
			var hold_hit := _sample_ground_contact(tip_now, body_basis, space_state)
			if hold_hit.is_empty():
				hold_hit = _sample_ground_contact(base_now, body_basis, space_state)
			if not hold_hit.is_empty():
				runtime["anchor"] = hold_hit.position
				runtime["anchor_valid"] = true
				runtime["support_normal"] = hold_hit.normal
				runtime["tip_target"] = hold_hit.position
				_set_state(runtime, ArmStepState.GRAB)
				return

			var candidate := _find_reach_target(
				base_now,
				body_position,
				body_basis,
				desired_planar,
				has_command,
				dynamic_angle_center,
				space_state
			)
			if not candidate.is_empty():
				tip_target = candidate.position
				var pole_sign := 1.0 if sin(float(runtime["angle_center"])) >= 0.0 else -1.0
				runtime["pole_target"] = base_now + body_basis.y * 0.3 + body_basis.x * pole_sign * 0.15
				runtime["support_normal"] = candidate.normal
				runtime["tip_target"] = tip_target
				_set_state(runtime, ArmStepState.REACH)
				return

			# Fallback: if no forward plant point found, use local idle plant point.
			var idle_candidate := _find_idle_target(body_position, body_basis, dynamic_angle_center, space_state)
			if not idle_candidate.is_empty():
				runtime["tip_target"] = idle_candidate.position
				runtime["support_normal"] = idle_candidate.normal
				_set_state(runtime, ArmStepState.REACH)
				return

	if state == ArmStepState.REACH:
		if tip_target == Vector3.ZERO:
			_set_state(runtime, ArmStepState.SEARCH)
			return
		var to_target := tip_target - tip_now
		var advance := minf(1.0, reach_speed * maxf(0.0, delta))
		runtime["tip_target"] = tip_now.lerp(tip_target, advance)
		if to_target.length() <= grab_distance and not ground_hit.is_empty():
			anchor = ground_hit.position
			runtime["anchor"] = anchor
			runtime["anchor_valid"] = true
			runtime["support_normal"] = ground_hit.normal
			_set_state(runtime, ArmStepState.GRAB)
			return
		if state_time >= reach_timeout:
			var forced_hit := _sample_ground_contact(tip_target, body_basis, space_state)
			if forced_hit.is_empty():
				forced_hit = _sample_ground_contact(base_now + (tip_target - base_now).normalized() * workspace_min_radius, body_basis, space_state)
			if not forced_hit.is_empty():
				runtime["anchor"] = forced_hit.position
				runtime["anchor_valid"] = true
				runtime["support_normal"] = forced_hit.normal
				runtime["tip_target"] = forced_hit.position
				_set_state(runtime, ArmStepState.GRAB)
				return
			_set_state(runtime, ArmStepState.SEARCH)
			return
		if not _is_within_workspace(base_now, tip_target, body_position, dynamic_angle_center):
			runtime["tip_target"] = _clamp_target_radius(base_now, tip_target)
			return

	if state == ArmStepState.GRAB:
		if not bool(runtime["anchor_valid"]):
			_set_state(runtime, ArmStepState.SEARCH)
			return
		runtime["tip_target"] = runtime["anchor"]
		if state_time >= grip_duration:
			_set_state(runtime, ArmStepState.PUSH_PULL)
			return

	if state == ArmStepState.PUSH_PULL:
		if not bool(runtime["anchor_valid"]):
			_set_state(runtime, ArmStepState.SEARCH)
			return
		anchor = runtime["anchor"]
		var anchor_error := tip_now.distance_to(anchor)
		runtime["anchor_error"] = anchor_error
		runtime["tip_target"] = anchor
		var traction := traction_max
		if not ground_hit.is_empty():
			var normal: Vector3 = ground_hit.normal
			traction = clampf(normal.dot(Vector3.UP), traction_min, traction_max)
			runtime["support_normal"] = normal
		if anchor_error > anchor_slip_distance:
			traction *= clampf(1.0 - (anchor_error - anchor_stick_tolerance), 0.0, 1.0)
		runtime["traction"] = traction
		var slipping_force := arm_push_force * traction
		if state_time >= push_duration or slipping_force > slip_force_threshold:
			runtime["anchor_valid"] = false
			_set_state(runtime, ArmStepState.RELEASE)
			return
		if anchor_error > anchor_slip_distance:
			runtime["anchor_valid"] = false
			_set_state(runtime, ArmStepState.RELEASE)
			return
		if not _is_within_workspace(base_now, anchor, body_position, dynamic_angle_center):
			runtime["anchor_valid"] = false
			_set_state(runtime, ArmStepState.RELEASE)
			return

	if state == ArmStepState.RELEASE:
		runtime["tip_target"] = tip_now.lerp(base_now, minf(1.0, delta * (reach_speed * 0.7)))
		if state_time >= release_duration:
			_set_state(runtime, ArmStepState.SEARCH)
			return


func _apply_arm_pose(runtime: Dictionary, arm, body_position: Vector3, body_basis: Basis, has_command: bool) -> void:
	var arm_name := str(runtime["name"])
	var base_pos: Vector3 = _rig.get_arm_world_anchor(arm_name, "base")
	var tip_target: Vector3 = runtime["tip_target"]
	if tip_target == Vector3.ZERO:
		tip_target = _rig.get_arm_world_anchor(arm_name, "tip")

	var to_target := tip_target - base_pos
	var distance := maxf(0.001, to_target.length())
	var dir := to_target / distance
	var pole_target: Vector3 = runtime["pole_target"]
	var pole_dir := body_basis.y
	if pole_target != Vector3.ZERO:
		var pole_vec := pole_target - base_pos
		if pole_vec.length_squared() > 0.0001:
			pole_dir = pole_vec.normalized()
	var arm_side_sign := 1.0
	if str(arm.side) == "left":
		arm_side_sign = -1.0
	elif str(arm.side) == "right":
		arm_side_sign = 1.0
	else:
		arm_side_sign = 1.0 if sin(float(runtime["angle_center"])) >= 0.0 else -1.0
	var local_pole := body_basis.inverse() * pole_dir
	var local_dir := body_basis.inverse() * dir
	var planar_local := Vector3(local_dir.x, 0.0, local_dir.z)
	if planar_local.length_squared() > 0.0001:
		planar_local = planar_local.normalized()
	else:
		planar_local = Vector3(arm_side_sign * 0.25, 0.0, 1.0).normalized()
	var stretch := clampf(distance / workspace_max_radius, 0.0, 1.0)
	var soft_wave := sin((_cycle_time + float(runtime["phase"])) * TAU * gait_frequency)
	var swing_yaw := atan2(planar_local.x, maxf(0.001, planar_local.z))
	var step_state: int = int(runtime["state"])
	var state_time: float = float(runtime.get("state_time", 0.0))
	var stride_wave := sin((_cycle_time * gait_frequency + float(runtime["phase"])) * TAU)
	var role_swing := swing_yaw + stride_wave * 0.38 * role_stride_sweep_gain

	var pose: Dictionary = {}
	var crawl_phase := "idle"
	var crawl_phase_t := 0.0

	if not has_command:
		# Neutral grounded idle while waiting for command.
		pose = {
			"base_bend": 0.72 + soft_wave * 0.06,
			"mid_bend": 1.02 + soft_wave * 0.08,
			"tip_bend": 0.5 + soft_wave * 0.04,
			"base_angle": 0.12 * arm_side_sign,
			"mid_angle": 0.08 * arm_side_sign,
			"tip_angle": 0.06 * arm_side_sign,
		}
	else:
		crawl_phase = _resolve_crawl_phase(step_state, state_time)
		crawl_phase_t = _phase_progress_for_state(step_state, state_time)
		pose = _build_role_pose_for_phase(
			crawl_phase,
			crawl_phase_t,
			stretch,
			role_swing,
			arm_side_sign,
			local_pole.x
		)

	var base_bend: float = float(pose.get("base_bend", 0.2))
	var mid_bend: float = float(pose.get("mid_bend", 0.2))
	var tip_bend: float = float(pose.get("tip_bend", 0.12))
	var base_angle: float = float(pose.get("base_angle", 0.0))
	var mid_angle: float = float(pose.get("mid_angle", 0.0))
	var tip_angle: float = float(pose.get("tip_angle", 0.0))
	var ground_plane_angle := arm_side_sign * crawl_bend_plane_offset

	var tip_now_world: Vector3 = _rig.get_arm_world_anchor(arm_name, "tip")
	var tip_error := tip_now_world.distance_to(tip_target)
	var err_alpha := inverse_lerp(role_error_hard_limit, role_error_soft_limit, tip_error)
	err_alpha = clampf(err_alpha, 0.0, 1.0)
	if simplify_crawl_motion:
		err_alpha = 1.0

	# If arm cannot track target well, dampen exaggerated phase motion and bias to contact posture.
	var contact_base_bend := 0.34
	var contact_mid_bend := 0.2
	var contact_tip_bend := 0.1
	base_bend = lerpf(contact_base_bend, base_bend, err_alpha)
	mid_bend = lerpf(contact_mid_bend, mid_bend, err_alpha)
	tip_bend = lerpf(contact_tip_bend, tip_bend, err_alpha)
	base_angle = lerpf(ground_plane_angle, base_angle, err_alpha)
	mid_angle = lerpf(ground_plane_angle, mid_angle, err_alpha)
	tip_angle = lerpf(ground_plane_angle, tip_angle, err_alpha)

	var penetration := tip_target.y - tip_now_world.y
	if penetration > 0.015 and role_focus_segment != "mid":
		var lift_fix := clampf(penetration * 2.2, 0.0, 0.32)
		base_bend += lift_fix
		mid_bend += lift_fix * 1.15
		tip_bend += lift_fix * 0.9

	if has_command and crawl_phase != "idle":
		var focus_blend := role_focus_blend * err_alpha
		var focused_pose := _apply_segment_focus(
			role_focus_segment,
			focus_blend,
			crawl_phase,
			crawl_phase_t,
			stretch,
			role_swing,
			arm_side_sign,
			ground_plane_angle,
			base_bend,
			mid_bend,
			tip_bend,
			base_angle,
			mid_angle,
			tip_angle
		)
		base_bend = float(focused_pose["base_bend"])
		mid_bend = float(focused_pose["mid_bend"])
		tip_bend = float(focused_pose["tip_bend"])
		base_angle = float(focused_pose["base_angle"])
		mid_angle = float(focused_pose["mid_angle"])
		tip_angle = float(focused_pose["tip_angle"])

		var neutral_pose := _apply_crawl_neutral_baseline(
			crawl_phase,
			crawl_phase_t,
			arm_side_sign,
			ground_plane_angle,
			base_bend,
			mid_bend,
			tip_bend,
			base_angle,
			mid_angle,
			tip_angle
		)
		base_bend = float(neutral_pose["base_bend"])
		mid_bend = float(neutral_pose["mid_bend"])
		tip_bend = float(neutral_pose["tip_bend"])
		base_angle = float(neutral_pose["base_angle"])
		mid_angle = float(neutral_pose["mid_angle"])
		tip_angle = float(neutral_pose["tip_angle"])

		if role_focus_segment == "mid":
			# Prevent phase/lift leakage while tuning mid crawl curvature.
			base_bend = crawl_neutral_base_bend
			tip_bend = crawl_neutral_tip_bend
			base_angle = ground_plane_angle
			tip_angle = ground_plane_angle

	var bend_max := crawl_max_active_bend if has_command and crawl_phase != "idle" else 1.5
	var bend_min := -bend_max if has_command and crawl_phase != "idle" else -1.5
	base_bend = clampf(base_bend, bend_min, bend_max)
	mid_bend = clampf(mid_bend, bend_min, bend_max)
	tip_bend = clampf(tip_bend, bend_min, bend_max)
	runtime["crawl_phase"] = crawl_phase
	runtime["crawl_phase_t"] = crawl_phase_t

	arm.set_target_section_bend(
		base_bend,
		base_angle,
		mid_bend,
		mid_angle,
		tip_bend,
		tip_angle
	)
	runtime["base_bend"] = base_bend
	runtime["base_angle"] = base_angle
	if debug_print_crawl_base_pose and has_command and crawl_phase == "swing":
		var last_pose_log_t := float(runtime.get("last_crawl_pose_log_t", -INF))
		if _cycle_time - last_pose_log_t >= maxf(0.01, debug_crawl_pose_log_interval):
			print(
				"crawl pose %s | phase=%s(%.2f) | base_bend=%.3f | base_angle=%.3f"
				% [
					str(runtime["name"]),
					crawl_phase,
					crawl_phase_t,
					base_bend,
					base_angle,
				]
			)
			runtime["last_crawl_pose_log_t"] = _cycle_time


func _apply_segment_focus(
	segment_name: String,
	blend: float,
	phase_name: String,
	phase_t: float,
	stretch: float,
	role_swing: float,
	arm_side_sign: float,
	ground_plane_angle: float,
	base_bend: float,
	mid_bend: float,
	tip_bend: float,
	base_angle: float,
	mid_angle: float,
	tip_angle: float
) -> Dictionary:
	var a := clampf(blend, 0.0, 1.0)
	var out_base_bend := base_bend
	var out_mid_bend := mid_bend
	var out_tip_bend := tip_bend
	var out_base_angle := base_angle
	var out_mid_angle := mid_angle
	var out_tip_angle := tip_angle
	match segment_name:
		"all":
			# Compose all role-focus profiles so "all" reflects tuned base/mid/tip behaviors.
			var base_pose := _apply_segment_focus(
				"base",
				a,
				phase_name,
				phase_t,
				stretch,
				role_swing,
				arm_side_sign,
				ground_plane_angle,
				base_bend,
				mid_bend,
				tip_bend,
				base_angle,
				mid_angle,
				tip_angle
			)
			var mid_pose := _apply_segment_focus(
				"mid",
				a,
				phase_name,
				phase_t,
				stretch,
				role_swing,
				arm_side_sign,
				ground_plane_angle,
				base_bend,
				mid_bend,
				tip_bend,
				base_angle,
				mid_angle,
				tip_angle
			)
			var tip_pose := _apply_segment_focus(
				"tip",
				a,
				phase_name,
				phase_t,
				stretch,
				role_swing,
				arm_side_sign,
				ground_plane_angle,
				base_bend,
				mid_bend,
				tip_bend,
				base_angle,
				mid_angle,
				tip_angle
			)
			out_base_bend = (float(base_pose["base_bend"]) + float(mid_pose["base_bend"]) + float(tip_pose["base_bend"])) / 3.0
			out_mid_bend = (float(base_pose["mid_bend"]) + float(mid_pose["mid_bend"]) + float(tip_pose["mid_bend"])) / 3.0
			out_tip_bend = (float(base_pose["tip_bend"]) + float(mid_pose["tip_bend"]) + float(tip_pose["tip_bend"])) / 3.0
			out_base_angle = (float(base_pose["base_angle"]) + float(mid_pose["base_angle"]) + float(tip_pose["base_angle"])) / 3.0
			out_mid_angle = (float(base_pose["mid_angle"]) + float(mid_pose["mid_angle"]) + float(tip_pose["mid_angle"])) / 3.0
			out_tip_angle = (float(base_pose["tip_angle"]) + float(mid_pose["tip_angle"]) + float(tip_pose["tip_angle"])) / 3.0
		"base":
			# Explicit long-stroke sweep per phase:
			# push/load leaves arm behind, recover/swing moves it far forward.
			var sweep := _base_focus_sweep_curve(phase_name, phase_t)
			var arch := _base_focus_bend_curve(phase_name, phase_t)
			# Keep bend low; drive sweep mostly by angle to avoid vertical "umbrella" pose.
			out_base_bend = (0.08 + arch * 0.12 + (1.0 - stretch) * 0.06) * role_focus_base_bend_gain
			out_base_angle = ground_plane_angle + clampf(
				(role_swing * 0.85) + sweep * role_focus_base_angle_gain,
				-2.6,
				2.6
			)
			# Keep mid/tip in passive contact posture (no forced downward curl).
			out_mid_bend = lerpf(out_mid_bend, 0.04, a)
			out_tip_bend = lerpf(out_tip_bend, 0.02, a)
			out_mid_angle = lerpf(out_mid_angle, ground_plane_angle + sweep * 0.06, a)
			out_tip_angle = lerpf(out_tip_angle, ground_plane_angle + sweep * 0.04, a)
		"mid":
			# Mid role: strong power bend in curl plane (no lift-dominant angle).
			var forward_bias := _mid_focus_forward_curve(phase_name, phase_t)
			var mid_plane_angle := arm_side_sign * role_mid_plane_offset
			var phase_back_bias := 0.0
			if phase_name == "load":
				phase_back_bias = 0.14
			elif phase_name == "push":
				phase_back_bias = 0.22
			elif phase_name == "stabilize":
				phase_back_bias = 0.08
			out_mid_bend = lerpf(
				out_mid_bend,
				(0.72 + forward_bias * 0.2 + phase_back_bias * 0.35) * role_mid_bend_sign,
				a
			)
			out_mid_angle = lerp_angle(
				out_mid_angle,
				mid_plane_angle + clampf((role_swing * 0.12) + forward_bias * 0.07, -0.2, 0.2),
				a
			)
			# Keep base neutral; tip stays flatter so curvature reads in mid/body contact zone.
			out_base_bend = lerpf(out_base_bend, crawl_neutral_base_bend, a)
			out_tip_bend = lerpf(out_tip_bend, crawl_neutral_tip_bend, a)
			out_base_angle = lerpf(out_base_angle, ground_plane_angle, a)
			out_tip_angle = lerp_angle(out_tip_angle, ground_plane_angle, a * 0.85)
		"tip":
			out_tip_bend = out_tip_bend * 1.45
			out_tip_angle = ground_plane_angle + (out_tip_angle - ground_plane_angle) * 1.6
			out_base_bend = lerpf(out_base_bend, 0.18, a)
			out_mid_bend = lerpf(out_mid_bend, 0.14, a)
			out_base_angle = lerpf(out_base_angle, ground_plane_angle, a)
			out_mid_angle = lerpf(out_mid_angle, ground_plane_angle, a)
		_:
			pass

	return {
		"base_bend": out_base_bend,
		"mid_bend": out_mid_bend,
		"tip_bend": out_tip_bend,
		"base_angle": out_base_angle,
		"mid_angle": out_mid_angle,
		"tip_angle": out_tip_angle,
	}


func _apply_crawl_neutral_baseline(
	phase_name: String,
	phase_t: float,
	arm_side_sign: float,
	ground_plane_angle: float,
	base_bend: float,
	mid_bend: float,
	tip_bend: float,
	base_angle: float,
	mid_angle: float,
	tip_angle: float
) -> Dictionary:
	var support_phase := phase_name == "plant" or phase_name == "load" or phase_name == "push" or phase_name == "stabilize"
	var contact_blend := crawl_support_contact_blend if support_phase else crawl_swing_contact_blend
	var t := clampf(phase_t, 0.0, 1.0)
	var swing_lift := 0.0
	if phase_name == "swing":
		swing_lift = sin(t * PI) * crawl_swing_lift
	elif phase_name == "recover":
		swing_lift = (1.0 - t) * crawl_swing_lift * 0.45

	var target_base_bend := crawl_neutral_base_bend + swing_lift * 0.45
	var target_mid_bend := crawl_neutral_mid_bend + swing_lift * 0.7
	var target_tip_bend := crawl_neutral_tip_bend + swing_lift

	var base_blend := contact_blend
	if role_focus_segment == "mid":
		# Keep base stable and avoid fold-over while tuning mid.
		base_blend *= 0.65
	var out_base_bend := lerpf(base_bend, target_base_bend, base_blend)
	var out_mid_bend := lerpf(mid_bend, target_mid_bend, contact_blend) * 2
	var out_tip_bend := lerpf(tip_bend, target_tip_bend, contact_blend) * 2

	var base_angle_contact_blend := contact_blend * 0.08
	var mid_angle_target := ground_plane_angle
	var tip_angle_target := ground_plane_angle
	var mid_angle_blend := contact_blend * 0.95
	var tip_angle_blend := contact_blend * 0.95
	if role_focus_segment == "mid":
		# Preserve lateral mid bend plane while still allowing mild stabilization.
		mid_angle_target = arm_side_sign * role_mid_plane_offset
		tip_angle_target = ground_plane_angle
		mid_angle_blend = contact_blend * 0.2
		tip_angle_blend = contact_blend * 0.35

	var out_base_angle := lerpf(base_angle, ground_plane_angle, base_angle_contact_blend)
	var out_mid_angle := lerp_angle(mid_angle, mid_angle_target, mid_angle_blend) + 1.5 * arm_side_sign
	var out_tip_angle := lerp_angle(tip_angle, tip_angle_target, tip_angle_blend) + 2.5 * arm_side_sign

	return {
		"base_bend": out_base_bend,
		"mid_bend": out_mid_bend,
		"tip_bend": out_tip_bend,
		"base_angle": out_base_angle,
		"mid_angle": out_mid_angle,
		"tip_angle": out_tip_angle,
	}


func _base_focus_sweep_curve(phase_name: String, phase_t: float) -> float:
	var t := clampf(phase_t, 0.0, 1.0)
	match phase_name:
		"plant":
			return lerpf(0.35, 0.08, t)
		"load":
			return lerpf(0.08, -0.62, t)
		"push":
			return lerpf(-0.62, -1.18, t)
		"stabilize":
			return lerpf(-1.18, -0.82, t)
		"recover":
			return lerpf(-0.82, 0.66, t)
		"swing":
			return lerpf(0.66, 1.22, t)
		_:
			return 0.0


func _base_focus_bend_curve(phase_name: String, phase_t: float) -> float:
	var t := clampf(phase_t, 0.0, 1.0)
	match phase_name:
		"push":
			return 0.45 + sin(t * PI) * 0.55
		"swing":
			return 0.35 + sin(t * PI) * 0.65
		"recover":
			return 0.3 + t * 0.35
		"load":
			return 0.4 + t * 0.3
		_:
			return 0.32


func _mid_focus_forward_curve(phase_name: String, phase_t: float) -> float:
	var t := clampf(phase_t, 0.0, 1.0)
	match phase_name:
		"load":
			return lerpf(0.2, 0.7, t)
		"push":
			return lerpf(0.7, 1.0, t)
		"stabilize":
			return lerpf(1.0, 0.45, t)
		"recover":
			return lerpf(0.45, 0.15, t)
		"swing":
			return lerpf(0.15, 0.35, t)
		_:
			return 0.15


func _resolve_crawl_phase(state: int, state_time: float) -> String:
	match state:
		ArmStepState.REACH:
			return "swing"
		ArmStepState.RELEASE:
			return "recover"
		ArmStepState.GRAB:
			return "plant" if state_time < grip_duration * 0.6 else "load"
		ArmStepState.PUSH_PULL:
			var t := clampf(state_time / maxf(0.001, push_duration), 0.0, 1.0)
			if t < 0.05:
				return "load"
			if t < 0.95:
				return "push"
			return "stabilize"
		ArmStepState.SEARCH:
			return "plant"
		_:
			return "idle"


func _phase_progress_for_state(state: int, state_time: float) -> float:
	match state:
		ArmStepState.REACH:
			return clampf(state_time / maxf(0.001, reach_timeout), 0.0, 1.0)
		ArmStepState.RELEASE:
			return clampf(state_time / maxf(0.001, release_duration), 0.0, 1.0)
		ArmStepState.GRAB:
			return clampf(state_time / maxf(0.001, grip_duration), 0.0, 1.0)
		ArmStepState.PUSH_PULL:
			return clampf(state_time / maxf(0.001, push_duration), 0.0, 1.0)
		_:
			return 0.0


func _build_role_pose_for_phase(
	phase_name: String,
	phase_t: float,
	stretch: float,
	role_swing: float,
	arm_side_sign: float,
	pole_x: float
) -> Dictionary:
	var ground_plane_angle := arm_side_sign * crawl_bend_plane_offset
	var t := clampf(phase_t, 0.0, 1.0)
	var ease := t * t * (3.0 - 2.0 * t)
	var vg := role_phase_visual_gain
	var sg := role_support_gain
	match phase_name:
		"plant":
			# Base role: place and spread on floor. Mid/tip roles: light contact only.
			return {
				"base_bend": lerpf(0.78, 0.44, stretch) * (1.0 - ease * 0.2) * (1.0 + (vg - 1.0) * 0.25),
				"mid_bend": lerpf(0.16, 0.06, stretch) * (1.0 + (vg - 1.0) * 0.2),
				"tip_bend": lerpf(0.06, 0.0, stretch) * (1.0 + (vg - 1.0) * 0.18),
				"base_angle": ground_plane_angle + clampf(role_swing * 1.24, -1.12, 1.12),
				"mid_angle": ground_plane_angle + clampf(role_swing * 0.18 + pole_x * 0.03, -0.2, 0.2),
				"tip_angle": ground_plane_angle + clampf(role_swing * 0.1, -0.1, 0.1),
			}
		"load":
			# Mid role: build load for propulsion while base stays planted.
			return {
				"base_bend": lerpf(0.42, 0.24, stretch) * (1.0 + (vg - 1.0) * 0.25),
				"mid_bend": (lerpf(0.54, 0.3, stretch) + ease * 0.24) * (1.0 + (vg - 1.0) * 0.55),
				"tip_bend": (lerpf(0.22, 0.12, stretch) + ease * 0.12) * (1.0 + (vg - 1.0) * 0.45),
				"base_angle": ground_plane_angle + clampf(role_swing * 1.28, -1.16, 1.16),
				"mid_angle": ground_plane_angle + clampf(role_swing * 0.74 + pole_x * 0.05, -0.66, 0.66),
				"tip_angle": ground_plane_angle + clampf(role_swing * 0.42, -0.38, 0.38),
			}
		"push":
			# Push role: mid dominates propulsion, base guides sweep, tip maintains grip.
			var push_drive := sin(ease * PI)
			return {
				"base_bend": (lerpf(0.34, 0.18, stretch) + push_drive * 0.1 * sg) * (1.0 + (vg - 1.0) * 0.28),
				"mid_bend": (lerpf(0.8, 0.44, stretch) + push_drive * 0.34 * sg) * (1.0 + (vg - 1.0) * 0.7),
				"tip_bend": (lerpf(0.36, 0.2, stretch) + push_drive * 0.18 * sg) * (1.0 + (vg - 1.0) * 0.6),
				"base_angle": ground_plane_angle + clampf(role_swing * 1.35, -1.15, 1.15),
				"mid_angle": ground_plane_angle + clampf(role_swing * 1.02 + pole_x * 0.1, -0.86, 0.86),
				"tip_angle": ground_plane_angle + clampf(role_swing * 0.66, -0.54, 0.54),
			}
		"stabilize":
			# Stabilize role: unload while preserving floor contact.
			return {
				"base_bend": lerpf(0.42, 0.22, stretch) * (1.0 - ease * 0.25),
				"mid_bend": lerpf(0.42, 0.18, stretch) * (1.0 - ease * 0.45),
				"tip_bend": lerpf(0.2, 0.08, stretch) * (1.0 - ease * 0.5),
				"base_angle": ground_plane_angle + clampf(role_swing * 0.4, -0.36, 0.36),
				"mid_angle": ground_plane_angle + clampf(role_swing * 0.3 + pole_x * 0.03, -0.26, 0.26),
				"tip_angle": ground_plane_angle + clampf(role_swing * 0.18, -0.16, 0.16),
			}
		"recover":
			# Recover role: release support and prepare swing.
			return {
				"base_bend": lerpf(0.5, 0.24, stretch),
				"mid_bend": lerpf(0.32, 0.12, stretch),
				"tip_bend": lerpf(0.14, 0.04, stretch),
				"base_angle": ground_plane_angle + clampf(role_swing * 1.44, -1.24, 1.24),
				"mid_angle": ground_plane_angle + clampf(role_swing * 0.48 + pole_x * 0.04, -0.4, 0.4),
				"tip_angle": ground_plane_angle + clampf(role_swing * 0.3, -0.26, 0.26),
			}
		"swing":
			# Swing role: base leads stride; mid/tip tuck then extend toward plant.
			var swing_lift := sin(ease * PI)
			return {
				"base_bend": (lerpf(0.92, 0.52, stretch) + swing_lift * 0.72 * vg) * (1.0 + (vg - 1.0) * 0.35),
				"mid_bend": (lerpf(0.26, 0.08, stretch) + swing_lift * 0.12 * vg) * (1.0 + (vg - 1.0) * 0.35),
				"tip_bend": (lerpf(0.08, 0.02, stretch) + swing_lift * 0.06 * vg) * (1.0 + (vg - 1.0) * 0.25),
				"base_angle": ground_plane_angle + clampf(role_swing * 6.2, -5.2, 5.2),
				"mid_angle": ground_plane_angle + clampf(role_swing * 0.9 + pole_x * 0.06, -0.72, 0.72),
				"tip_angle": ground_plane_angle + clampf(role_swing * 0.42, -0.34, 0.34),
			}
		_:
			return {
				"base_bend": 0.22,
				"mid_bend": 0.14,
				"tip_bend": 0.08,
				"base_angle": ground_plane_angle,
				"mid_angle": ground_plane_angle,
				"tip_angle": ground_plane_angle,
			}


func _sample_ground_contact(
	tip_world: Vector3,
	body_basis: Basis,
	space_state: PhysicsDirectSpaceState3D
) -> Dictionary:
	if space_state == null:
		return {}
	var right := body_basis.x.normalized()
	var forward := (-body_basis.z).normalized()
	var starts: Array[Vector3] = [
		tip_world + Vector3.UP * ground_probe_height,
		tip_world + right * ground_probe_lateral + Vector3.UP * ground_probe_height,
		tip_world - right * ground_probe_lateral + Vector3.UP * ground_probe_height,
		tip_world + forward * (ground_probe_lateral * 0.55) + Vector3.UP * ground_probe_height,
	]
	var best_hit: Dictionary = {}
	var best_dist := INF
	for start: Vector3 in starts:
		var finish: Vector3 = start + Vector3.DOWN * (ground_probe_height + ground_probe_depth)
		var query := PhysicsRayQueryParameters3D.create(start, finish)
		query.collide_with_areas = false
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		if normal.dot(Vector3.UP) < min_ground_up_dot:
			continue
		var hit_pos: Vector3 = hit.position
		var dist: float = start.distance_to(hit_pos)
		if dist < best_dist:
			best_hit = hit
			best_dist = dist
	return best_hit


func _find_reach_target(
	base_position: Vector3,
	body_position: Vector3,
	body_basis: Basis,
	desired_planar: Vector3,
	has_command: bool,
	arm_angle_center: float,
	space_state: PhysicsDirectSpaceState3D
) -> Dictionary:
	if space_state == null:
		return {}
	var radial_local := Vector3(sin(arm_angle_center), 0.0, cos(arm_angle_center))
	var radial_world := (body_basis * radial_local).normalized()
	var forward := radial_world
	if has_command and desired_planar.length_squared() > 0.0001:
		forward = desired_planar.normalized()
	forward = radial_world.lerp(forward, 0.55).normalized()
	var stride_scale := 1.0
	if not simplify_crawl_motion and has_command and desired_planar.length_squared() > 0.0001:
		stride_scale += absf(radial_world.dot(forward)) * 0.32
	var lateral_dir := Vector3.UP.cross(forward).normalized()
	if lateral_dir.length_squared() <= 0.0001:
		lateral_dir = body_basis.x.normalized()
	var angle_sin := sin(arm_angle_center)
	var ring_side := clampf(angle_sin, -1.0, 1.0)
	var offset := (
		forward * (reach_forward_distance * stride_scale)
		+ lateral_dir * (reach_side_bias * ring_side * stride_scale)
		+ radial_world * (0.24 * stride_scale)
	)
	var search_origin := base_position + offset
	search_origin.y += ground_probe_height
	var search_end := search_origin + Vector3.DOWN * (ground_probe_height + ground_probe_depth + 0.7)
	var query := PhysicsRayQueryParameters3D.create(search_origin, search_end)
	query.collide_with_areas = false
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		var fallback_dir := radial_world
		if desired_planar.length_squared() > 0.0001:
			fallback_dir = desired_planar.normalized()
		var fallback_origin := base_position + fallback_dir * (reach_forward_distance * 0.66)
		fallback_origin.y += ground_probe_height
		var fallback_end := fallback_origin + Vector3.DOWN * (ground_probe_height + ground_probe_depth + 0.7)
		var fallback_query := PhysicsRayQueryParameters3D.create(fallback_origin, fallback_end)
		fallback_query.collide_with_areas = false
		hit = space_state.intersect_ray(fallback_query)
		if hit.is_empty():
			return {}
	var normal: Vector3 = hit.normal
	if normal.dot(Vector3.UP) < min_ground_up_dot:
		return {}
	var hit_pos: Vector3 = hit.position
	if not _is_within_workspace(base_position, hit_pos, body_position, arm_angle_center):
		hit["position"] = _clamp_target_radius(base_position, hit_pos)
	return hit


func _find_idle_target(
	body_position: Vector3,
	body_basis: Basis,
	arm_angle_center: float,
	space_state: PhysicsDirectSpaceState3D
) -> Dictionary:
	if space_state == null:
		return {}
	var radial_local := Vector3(sin(arm_angle_center), 0.0, cos(arm_angle_center))
	var radial_world := (body_basis * radial_local).normalized()
	var origin := body_position + radial_world * (workspace_min_radius + 0.22)
	origin.y += ground_probe_height
	var end := origin + Vector3.DOWN * (ground_probe_height + ground_probe_depth + 0.6)
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = false
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit.normal
	if normal.dot(Vector3.UP) < min_ground_up_dot:
		return {}
	return hit


func _is_within_workspace(base_pos: Vector3, target: Vector3, body_position: Vector3, angle_center: float) -> bool:
	var local := target - body_position
	local.y = 0.0
	if local.length_squared() <= 0.0001:
		return false
	var radius := base_pos.distance_to(target)
	if radius < workspace_min_radius or radius > workspace_max_radius:
		return false
	var target_angle := atan2(local.x, local.z)
	var angle_delta := absf(wrapf(target_angle - angle_center, -PI, PI))
	return angle_delta <= workspace_half_angle


func _clamp_target_radius(base_pos: Vector3, target: Vector3) -> Vector3:
	var offset := target - base_pos
	offset.y = 0.0
	var planar_len := offset.length()
	if planar_len <= 0.0001:
		return target
	var clamped_radius := clampf(planar_len, workspace_min_radius * 0.9, workspace_max_radius * 0.92)
	var planar_dir := offset / planar_len
	return Vector3(
		base_pos.x + planar_dir.x * clamped_radius,
		target.y,
		base_pos.z + planar_dir.z * clamped_radius
	)


func _set_state(runtime: Dictionary, next_state: int) -> void:
	var prev_state = int(runtime["state"])
	runtime["state"] = next_state
	runtime["state_time"] = 0.0
	if debug_print_state_changes and prev_state != next_state:
		print(
			"surface arm %s: %s -> %s"
			% [runtime["name"], _state_name(prev_state), _state_name(next_state)]
		)


func _gait_value(phase: float) -> float:
	var t := _cycle_time * gait_frequency + phase
	return 0.5 + 0.5 * sin(t * TAU)


func _debug_line(runtime: Dictionary) -> String:
	return "%s | %s/%s(%.2f) | anchored=%s | traction=%.2f | force=%.2f | err=%.3f | base_bend=%.3f | base_angle=%.3f" % [
		str(runtime["name"]),
		_state_name(int(runtime["state"])),
		str(runtime.get("crawl_phase", "idle")),
		float(runtime.get("crawl_phase_t", 0.0)),
		str(bool(runtime["anchor_valid"])),
		float(runtime["traction"]),
		float(runtime["last_force"]),
		float(runtime["anchor_error"]),
		float(runtime.get("base_bend", 0.0)),
		float(runtime.get("base_angle", 0.0)),
	]


func _state_name(state: int) -> String:
	match state:
		ArmStepState.SEARCH:
			return "SEARCH"
		ArmStepState.REACH:
			return "REACH"
		ArmStepState.GRAB:
			return "GRAB"
		ArmStepState.PUSH_PULL:
			return "PUSH_PULL"
		ArmStepState.RELEASE:
			return "RELEASE"
		_:
			return "UNKNOWN"


func _project_on_plane(vector: Vector3, normal: Vector3) -> Vector3:
	return vector - normal * vector.dot(normal)
