@tool
extends Node3D
class_name OctoRig

const OctoArmType = preload("res://scripts/rig/OctoArm.gd")
const OctoHeadType = preload("res://scripts/rig/OctoHead.gd")
const OctoSurfaceLocomotionType = preload("res://scripts/rig/OctoSurfaceLocomotion.gd")

enum ArmAnimMode {
	STATIC,
	IDLE,
	CRAWL,
	HOLD,
}

# Replace these placeholder names with your real imported skeleton bone names.
const ARM_CONFIGS: Dictionary = {
	"arm_0": {
		"side": "left",
		"role_bias": "front",
		"bones": ["11.006", "12.006", "13.006", "14.006", "15.006", "21.006", "22.006", "23.006", "24.006", "25.006", "31.006", "32.006", "33.006", "34.006", "35.006"],
	},
	"arm_1": {
		"side": "right",
		"role_bias": "front",
		"bones": ["11.002", "12.002", "13.002", "14.002", "15.002", "21.002", "22.002", "23.002", "24.002", "25.002", "31.002", "32.002", "33.002", "34.002", "35.002"],
	},
	"arm_2": {
		"side": "left",
		"role_bias": "front_mid",
		"bones": ["11", "12", "13", "14", "15", "21", "22", "23", "24", "25", "31", "32", "33", "34", "35"],
	},
	"arm_3": {
		"side": "right",
		"role_bias": "front_mid",
		"bones": ["11.004", "12.004", "13.004", "14.004", "15.004", "21.004", "22.004", "23.004", "24.004", "25.004", "31.004", "32.004", "33.004", "34.004", "35.004"],
	},
	"arm_4": {
		"side": "right",
		"role_bias": "back_mid",
		"bones": ["11.001", "12.001", "13.001", "14.001", "15.001", "21.001", "22.001", "23.001", "24.001", "25.001", "31.001", "32.001", "33.001", "34.001", "35.001"],
	},
	"arm_5": {
		"side": "left",
		"role_bias": "back_mid",
		"bones": ["11.005", "12.005", "13.005", "14.005", "15.005", "21.005", "22.005", "23.005", "24.005", "25.005", "31.005", "32.005", "33.005", "34.005", "35.005"],
	},
	"arm_6": {
		"side": "left",
		"role_bias": "back",
		"bones": ["11.003", "12.003", "13.003", "14.003", "15.003", "21.003", "22.003", "23.003", "24.003", "25.003", "31.003", "32.003", "33.003", "34.003", "35.003"],
	},
	"arm_7": {
		"side": "right",
		"role_bias": "back",
		"bones": ["11.007", "12.007", "13.007", "14.007", "15.007", "21.007", "22.007", "23.007", "24.007", "25.007", "31.007", "32.007", "33.007", "34.007", "35.007"],
	}
}

const HEAD_BONE_NAMES: Array[String] = ["HEAD_01", "Bone.001", "Bone.002", "Bone.003"]
const HOLD_ARM_PRIORITY: PackedStringArray = ["arm_2", "arm_3", "arm_5", "arm_4", "arm_0", "arm_1", "arm_6", "arm_7"]
const CRAWL_PREVIEW_NEUTRAL_BASE_BEND := 0.81
const CRAWL_PREVIEW_NEUTRAL_MID_BEND := 1.83
const CRAWL_PREVIEW_NEUTRAL_TIP_BEND := 3.5
const CRAWL_PREVIEW_MAX_ACTIVE_BEND := 1.8
const CRAWL_PREVIEW_BASE_ANGLE_BACK_LIMIT := -7.5
const CRAWL_PREVIEW_BASE_ANGLE_FORWARD_LIMIT := 5.0

var debug_print_on_ready = true
var print_indices_on_ready = false
var apply_arm_pose_each_frame = true
var default_base_bend = 0.67
var default_mid_bend = 0.0
var default_tip_bend = 0.0
var enable_arm_animation_mixer = true
var use_surface_locomotion := true
var surface_locomotion_debug := true
var surface_locomotion_debug_print := false
var surface_locomotion_debug_draw_3d := false
var surface_locomotion_debug_normal_len := 0.18
var surface_hold_blend_strength := 1.0
var crawl_profile_gait_frequency := 5.0
var crawl_profile_stride_sweep_gain := 10.0
var crawl_profile_swing_lift := 0.16
var crawl_profile_base_angle_gain := 6.8
var crawl_profile_base_angle_back_bias := -1.3
# Legacy IK tuning (not exposed; raw skeleton IK path is disabled).
var use_arm_ik := false
var ik_influence := 0.35
var ik_max_iterations := 24
var ik_min_distance := 0.01
var ik_target_lerp := 0.5
var use_idle_when_stationary = true
var idle_stationary_speed_threshold = 0.08
var idle_entry_pose_memory = true
var idle_entry_memory_decay_speed = 2.4
var crawl_requires_motion = true
var crawl_speed_for_full_cycle = 2.5
var preview_motion_speed = 0.6
var hold_arm_names: PackedStringArray = []
var hold_base_bend = 1.0
var hold_mid_bend = 0.68
var hold_tip_bend = -0.83
var hold_base_bend_angle = 0.2
var hold_mid_bend_angle = 0.2
var hold_tip_bend_angle = 0.2
var hold_animate_bend_angles = true
var hold_bend_angle_min = 0.0
var hold_bend_angle_max = 0.5
var hold_bend_angle_hz = 0.2
var enable_head_look = true
var head_look_follow_mouse = true
var head_look_weight = 0.65
var head_max_yaw = 0.4
var head_max_pitch = 0.3
var head_look_yaw_sign = 1.0
var head_look_pitch_sign = -1.0
var head_forward_sign = 1.0
var head_look_lerp_speed = 6.0
var head_return_lerp_speed = 1.2
var head_front_guard = -0.08
var preview_in_editor = false
var preview_animation_mode := 0
var preview_animate_in_editor = true
var preview_apply_to_all_arms = true
var preview_arm_name := "arm_0"
var preview_base_bend: float = 0.0
var preview_base_bend_angle = 0.0
var preview_mid_bend: float = 0.0
var preview_mid_bend_angle = 0.0
var preview_tip_bend: float = 0.0
var preview_tip_bend_angle = 0.0

# Internal debug toggles (kept in code, hidden from inspector by default).
var head_debug_strong_follow = false
var head_debug_logs = false
var head_debug_log_interval = 0.5
var preview_confirm_logs = false
var preview_run_skin_diagnostics = true
var preview_force_single_bone_test = false
var preview_force_bone_name = "HEAD_01"
var preview_force_bone_angle = 1.2

# Idle and head-sway tuning (code-only; keep clean inspector, easy to tweak here).
var head_idle_sway = true
var head_idle_sway_weight = 0.85
var head_idle_sway_yaw = 0.08
var head_idle_sway_pitch = 0.05
var head_idle_sway_hz = 0.28
var idle_base_bend_center = 0.68
var idle_mid_bend_center = 1.5
var idle_tip_bend_center = 0.5
var idle_base_bend_amplitude = 0.1
var idle_mid_bend_amplitude = 0.5
var idle_tip_bend_amplitude = 2.2
var idle_base_bend_angle_offset = 0.0
var idle_mid_bend_angle_offset = 1.7
var idle_tip_bend_angle_offset = 0.0
var idle_frequency_hz = 0.05
var idle_per_arm_amplitude_variation = 0.22
var idle_per_arm_frequency_variation = 0.18
var idle_per_arm_angle_variation = 0.3
var idle_randomize_mid_angle_sign = true
var idle_split_mid_angle_even_odd = false
var idle_mid_angle_invert_fraction = 0.5
var idle_run_base_center_jitter = 0.06
var idle_run_mid_center_jitter = 0.14
var idle_run_tip_center_jitter = 0.1
var idle_run_base_angle_jitter = 0.2
var idle_run_mid_angle_jitter = 0.45
var idle_run_tip_angle_jitter = 0.28

var skeleton: Skeleton3D
var head
var arms: Array = []

var _setup_valid = false
var _validation_errors: Array[String] = []
var _validation_warnings: Array[String] = []
var _preview_animation_state_by_path: Dictionary = {}
var _preview_log_accum = 0.0
var _skin_diag_printed = false
var _crawl_phase = 0.0
var _arm_mode_overrides: Dictionary = {}
var _runtime_hold_arms: Dictionary = {}
var _head_yaw = 0.0
var _head_pitch = 0.0
var _head_debug_accum = 0.0
var _head_dbg_mouse_accepted = false
var _head_dbg_forward_component = 0.0
var _head_dbg_mouse_target = Vector2.ZERO
var _was_moving_for_idle = false
var _idle_entry_blend = 0.0
var _idle_entry_offsets: Dictionary = {}
var _idle_run_offsets: Dictionary = {}
var _idle_mid_signs: Dictionary = {}
var _idle_rng := RandomNumberGenerator.new()
var _surface_locomotion = OctoSurfaceLocomotionType.new()
var _surface_drive_velocity := Vector3.ZERO
var _surface_support_normal := Vector3.UP
var _surface_debug_lines: PackedStringArray = []
var _surface_debug_accum := 0.0
var _surface_idle_blend_state := 0.0
var _surface_debug_mesh_instance: MeshInstance3D
var _surface_debug_immediate: ImmediateMesh
var _arm_ik_nodes: Dictionary = {}
var _arm_ik_targets: Dictionary = {}
const SURFACE_IDLE_BLEND_SPEED := 8.0


func _ready() -> void:
	set_process(true)
	_idle_rng.randomize()
	_sync_surface_locomotion_profile()
	_setup_valid = build_rig()
	if _setup_valid and debug_print_on_ready:
		print_debug_summary()
		if print_indices_on_ready:
			print_resolved_bone_indices()
	elif not _setup_valid:
		_print_validation_failures()
	if Engine.is_editor_hint():
		_on_preview_property_changed()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if not preview_in_editor:
			_restore_preview_animation_players()
			_preview_log_accum = 0.0
			_skin_diag_printed = false
			return
		_process_editor_preview(delta)
		return
	if not _setup_valid:
		return
	if skeleton == null:
		return
	skeleton.clear_bones_global_pose_override()
	_update_non_surface_animation_targets(delta)
	if apply_arm_pose_each_frame:
		for arm in arms:
			arm.update_params(delta)
			arm.apply_pose(skeleton)
	_update_head_pose(delta)
	_update_surface_debug_draw()


func _update_non_surface_animation_targets(delta: float) -> void:
	# Surface locomotion owns crawl/idle targets via `step_surface_locomotion()`.
	if use_surface_locomotion:
		return
	if enable_arm_animation_mixer:
		_update_arm_animation_targets(delta)


func build_rig() -> bool:
	_clear_runtime_data()
	skeleton = _find_best_skeleton_for_config()
	if skeleton == null:
		_validation_errors.append(
			"OctoRig: no matching Skeleton3D found under '%s'. Check imported model hierarchy and bone names." % name
		)
		return false

	if ARM_CONFIGS.is_empty():
		_validation_errors.append("OctoRig: ARM_CONFIGS has no entries.")
		return false

	var assignment_sources = _collect_assignment_sources()
	_validation_warnings.append_array(_detect_duplicate_assignments(assignment_sources))

	head = OctoHeadType.new()
	if not head.setup(skeleton, HEAD_BONE_NAMES):
		_validation_errors.append_array(head.errors)

	var arm_keys: Array = ARM_CONFIGS.keys()
	arm_keys.sort()

	for arm_i in arm_keys.size():
		var arm_key = str(arm_keys[arm_i])
		var arm_config_variant: Variant = ARM_CONFIGS[arm_key]
		if not (arm_config_variant is Dictionary):
			_validation_errors.append("Arm '%s': config must be a Dictionary." % arm_key)
			continue
		var arm_config: Dictionary = arm_config_variant
		var configured_names = _to_string_array(arm_config.get("bones", []), "Arm '%s' bones" % arm_key)
		var side = str(arm_config.get("side", "unknown"))
		var role_bias = str(arm_config.get("role_bias", "neutral"))
		var arm = OctoArmType.new()
		var arm_valid = arm.setup(skeleton, arm_key, arm_i, configured_names, side, role_bias)
		if not arm_valid:
			_validation_errors.append_array(arm.errors)
		if not arm.warnings.is_empty():
			_validation_warnings.append_array(arm.warnings)
		if not arm_valid:
			continue

		# Optional per-arm tuning overrides.
		var scales_variant: Variant = arm_config.get("scales", {})
		if scales_variant is Dictionary:
			var scales: Dictionary = scales_variant
			arm.set_section_bend_scales(
				float(scales.get("base_bend", 1.0)),
				float(scales.get("mid_bend", 1.0)),
				float(scales.get("tip_bend", 1.0))
			)

		var axis_signs_variant: Variant = arm_config.get("axis_signs", {})
		if axis_signs_variant is Dictionary:
			var axis_signs: Dictionary = axis_signs_variant
			arm.set_axis_mapping(
				arm.curl_axis,
				arm.lift_axis,
				float(axis_signs.get("curl", arm.curl_axis_sign)),
				float(axis_signs.get("lift", arm.lift_axis_sign))
			)
		arm.set_target_pose_params(
			default_base_bend,
			0.0,
			default_mid_bend,
			0.0,
			default_tip_bend,
			0.0
		)
		arm.snap_to_target_params()
		arm.phase_offset = (TAU / maxf(1.0, float(arm_keys.size()))) * float(arm_i)
		arms.append(arm)

	if arms.is_empty():
		_validation_errors.append("OctoRig: no arms were created.")

	_setup_valid = _validation_errors.is_empty()
	if _setup_valid:
		_surface_locomotion.setup(self, arms)
		_sync_surface_locomotion_profile()
		_surface_locomotion.enabled = use_surface_locomotion
		_surface_locomotion.debug_enabled = surface_locomotion_debug
		_setup_arm_ik()
	return _setup_valid


func has_valid_setup() -> bool:
	return _setup_valid


func get_all_arm_bones() -> Array[int]:
	var unique = {}
	for arm in arms:
		for bone_index in arm.bone_indices:
			unique[bone_index] = true

	var result: Array[int] = []
	for key in unique.keys():
		result.append(int(key))
	result.sort()
	return result


func print_debug_summary() -> void:
	print("Octo rig setup complete")
	if head != null:
		print("Head: %d bones" % head.bone_indices.size())
	for arm in arms:
		print(
			"Arm %s (%s/%s): %d bones | base %d | mid %d | tip %d" % [
				arm.arm_name,
				arm.side,
				arm.role_bias,
				arm.bone_indices.size(),
				arm.base_bones.size(),
				arm.mid_bones.size(),
				arm.tip_bones.size(),
			]
		)

	for warning in _validation_warnings:
		push_warning(warning)


func print_resolved_bone_indices() -> void:
	if head != null:
		print("Head indices: %s" % str(head.bone_indices))

	for arm in arms:
		print("Arm %s indices: %s" % [arm.arm_name, str(arm.bone_indices)])


func set_arm_target_section_bend(
	arm_name: String,
	base_bend: float = 0.0,
	base_bend_angle: float = 0.0,
	mid_bend: float = 0.0,
	mid_bend_angle: float = 0.0,
	tip_bend: float = 0.0,
	tip_bend_angle: float = 0.0
) -> void:
	for arm in arms:
		if arm.arm_name == arm_name:
			arm.set_target_section_bend(
				base_bend,
				base_bend_angle,
				mid_bend,
				mid_bend_angle,
				tip_bend,
				tip_bend_angle
			)
			return


func set_arm_animation_mode(arm_name: String, mode: ArmAnimMode) -> void:
	_arm_mode_overrides[arm_name] = int(mode)


func clear_arm_animation_mode(arm_name: String) -> void:
	_arm_mode_overrides.erase(arm_name)


func clear_all_arm_animation_modes() -> void:
	_arm_mode_overrides.clear()


func set_arm_hold_enabled(arm_name: String, enabled: bool) -> void:
	if enabled:
		_runtime_hold_arms[arm_name] = true
	else:
		_runtime_hold_arms.erase(arm_name)


func get_hold_arm_priority() -> PackedStringArray:
	var result := PackedStringArray()
	var available := {}
	for arm in arms:
		available[arm.arm_name] = true
	for arm_name in HOLD_ARM_PRIORITY:
		var key = str(arm_name)
		if available.has(key):
			result.append(key)
	var remaining: Array[String] = []
	for arm in arms:
		if not result.has(arm.arm_name):
			remaining.append(arm.arm_name)
	remaining.sort()
	for arm_name in remaining:
		result.append(arm_name)
	return result


func get_head_world_transform() -> Transform3D:
	if skeleton == null or head == null or head.bone_indices.is_empty():
		return global_transform
	var bone_index: int = int(head.bone_indices[0])
	var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
	return skeleton.global_transform * bone_pose


func get_arm_world_anchor(arm_name: String, section: String = "tip") -> Vector3:
	if skeleton == null:
		return global_position
	for arm in arms:
		if arm.arm_name != arm_name:
			continue
		var bone_index = -1
		match section:
			"base":
				if not arm.base_bones.is_empty():
					bone_index = int(arm.base_bones[0])
			"mid", "middle":
				if not arm.mid_bones.is_empty():
					bone_index = int(arm.mid_bones[arm.mid_bones.size() - 1])
			_:
				if arm.tip_bone >= 0:
					bone_index = int(arm.tip_bone)
		if bone_index < 0:
			return global_position
		var bone_global: Transform3D = skeleton.get_bone_global_pose(bone_index)
		return skeleton.global_transform * bone_global.origin
	return global_position


func step_surface_locomotion(
	delta: float,
	body_position: Vector3,
	desired_direction: Vector3,
	current_velocity: Vector3
) -> Vector3:
	if not use_surface_locomotion or not _setup_valid or skeleton == null:
		_surface_drive_velocity = Vector3.ZERO
		_surface_support_normal = Vector3.UP
		_surface_debug_lines = PackedStringArray()
		return Vector3.ZERO

	var world = get_world_3d()
	if world == null:
		return _surface_drive_velocity
	var space_state = world.direct_space_state
	_sync_surface_locomotion_profile()
	_surface_locomotion.enabled = use_surface_locomotion
	_surface_locomotion.debug_enabled = surface_locomotion_debug
	_surface_locomotion.step(
		delta,
		body_position,
		global_transform.basis,
		desired_direction,
		current_velocity,
		space_state
	)
	_apply_surface_animation_overrides(delta, _has_surface_command_input(desired_direction))
	_surface_drive_velocity = _surface_locomotion.get_drive_velocity()
	_surface_support_normal = _surface_locomotion.get_support_normal()
	_surface_debug_lines = _surface_locomotion.get_debug_lines()
	_update_arm_ik_targets()
	if surface_locomotion_debug_print:
		_surface_debug_accum += delta
		if _surface_debug_accum >= 0.5:
			_surface_debug_accum = 0.0
			for line in _surface_debug_lines:
				print("surface debug | %s" % line)
	return _surface_drive_velocity


func get_surface_support_normal() -> Vector3:
	return _surface_support_normal


func get_surface_anchored_arm_count() -> int:
	return _surface_locomotion.get_anchored_count()


func get_surface_debug_lines() -> PackedStringArray:
	return _surface_debug_lines


func _setup_arm_ik() -> void:
	_clear_arm_ik_nodes()
	# Built-in section controls in OctoArm are the active IK layer.
	# Raw bone-level CCD (global pose overrides) is intentionally disabled here
	# because this rig's multiple parallel chains produce unstable deformations.
	return


func _find_valid_ik_chain_indices(arm) -> Dictionary:
	if skeleton == null:
		return {}
	var best_root := -1
	var best_tip := -1
	var best_length := -1
	for root_variant in arm.bone_indices:
		var root_index := int(root_variant)
		for tip_variant in arm.bone_indices:
			var tip_index := int(tip_variant)
			if root_index == tip_index:
				continue
			var chain_len := _ik_chain_length_if_ancestor(root_index, tip_index)
			if chain_len > best_length:
				best_length = chain_len
				best_root = root_index
				best_tip = tip_index
	if best_root < 0 or best_tip < 0:
		return {}
	return {
		"root": best_root,
		"tip": best_tip,
	}


func _find_preferred_ik_chain_indices(arm) -> PackedInt32Array:
	var row: Array = []
	for i in arm.bone_names.size():
		var bone_name := str(arm.bone_names[i])
		var prefix := bone_name.split(".")[0]
		var number := int(prefix)
		if number >= 21 and number <= 25:
			row.append(int(arm.bone_indices[i]))
	if row.size() < 2:
		return PackedInt32Array()
	row.sort()
	var root_index := int(row[0])
	var tip_index := int(row[row.size() - 1])
	return _build_ik_chain_indices(root_index, tip_index)


func _ik_chain_length_if_ancestor(root_index: int, tip_index: int) -> int:
	var length := 0
	var current := tip_index
	while current >= 0:
		if current == root_index:
			return length
		current = skeleton.get_bone_parent(current)
		length += 1
	return -1


func _arm_bone_name_for_index(arm, bone_index: int) -> String:
	for i in arm.bone_indices.size():
		if int(arm.bone_indices[i]) == bone_index:
			return str(arm.bone_names[i])
	return str(skeleton.get_bone_name(bone_index))


func _build_ik_chain_indices(root_index: int, tip_index: int) -> PackedInt32Array:
	var reversed: PackedInt32Array = PackedInt32Array()
	var current := tip_index
	while current >= 0:
		reversed.append(current)
		if current == root_index:
			break
		current = skeleton.get_bone_parent(current)
	if reversed.is_empty() or reversed[reversed.size() - 1] != root_index:
		return PackedInt32Array()
	var chain: PackedInt32Array = PackedInt32Array()
	for i in reversed.size():
		chain.append(reversed[reversed.size() - 1 - i])
	return chain


func _update_arm_ik_targets() -> void:
	# Arm targets still come from OctoSurfaceLocomotion, but are resolved through
	# section-level arm controls in `_apply_arm_pose()`.
	return


func _update_surface_debug_draw() -> void:
	if not surface_locomotion_debug_draw_3d or not use_surface_locomotion or not _setup_valid:
		if _surface_debug_mesh_instance != null:
			_surface_debug_mesh_instance.visible = false
		return
	if Engine.is_editor_hint():
		return
	_ensure_surface_debug_draw_node()
	if _surface_debug_immediate == null or _surface_debug_mesh_instance == null:
		return
	var targets: Dictionary = _surface_locomotion.get_arm_targets()
	_surface_debug_immediate.clear_surfaces()
	_surface_debug_immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for arm in arms:
		if arm == null:
			continue
		var arm_name := str(arm.arm_name)
		var base_world := get_arm_world_anchor(arm_name, "base")
		var tip_world := get_arm_world_anchor(arm_name, "tip")
		var base_local := to_local(base_world)
		var tip_local := to_local(tip_world)
		_surface_debug_immediate.surface_set_color(Color(0.65, 0.65, 0.65, 0.9))
		_surface_debug_immediate.surface_add_vertex(base_local)
		_surface_debug_immediate.surface_add_vertex(tip_local)
		if not targets.has(arm_name):
			continue
		var data: Dictionary = targets[arm_name]
		var target_world: Vector3 = data.get("tip_target", tip_world)
		if target_world == Vector3.ZERO:
			target_world = tip_world
		var target_local := to_local(target_world)
		_surface_debug_immediate.surface_set_color(Color(1.0, 0.92, 0.2, 0.95))
		_surface_debug_immediate.surface_add_vertex(tip_local)
		_surface_debug_immediate.surface_add_vertex(target_local)
		var anchored := bool(data.get("anchor_valid", false))
		if anchored:
			var anchor_world: Vector3 = data.get("anchor", target_world)
			var anchor_local := to_local(anchor_world)
			_surface_debug_immediate.surface_set_color(Color(0.2, 1.0, 0.55, 0.95))
			_surface_debug_immediate.surface_add_vertex(tip_local)
			_surface_debug_immediate.surface_add_vertex(anchor_local)
			# Arm normal is not currently exposed directly; use rig support normal fallback.
			var normal_world := _surface_support_normal
			var normal_tip_world := anchor_world + normal_world * surface_locomotion_debug_normal_len
			_surface_debug_immediate.surface_set_color(Color(0.15, 0.8, 1.0, 0.95))
			_surface_debug_immediate.surface_add_vertex(anchor_local)
			_surface_debug_immediate.surface_add_vertex(to_local(normal_tip_world))
	_surface_debug_immediate.surface_end()
	_surface_debug_mesh_instance.visible = true


func _ensure_surface_debug_draw_node() -> void:
	if _surface_debug_mesh_instance != null and is_instance_valid(_surface_debug_mesh_instance):
		return
	_surface_debug_immediate = ImmediateMesh.new()
	_surface_debug_mesh_instance = MeshInstance3D.new()
	_surface_debug_mesh_instance.name = "SurfaceDebugDraw"
	_surface_debug_mesh_instance.mesh = _surface_debug_immediate
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_surface_debug_mesh_instance.material_override = mat
	add_child(_surface_debug_mesh_instance)


func _solve_arm_chain_ccd(chain: PackedInt32Array, target_world: Vector3, pole_world: Vector3) -> void:
	_solve_arm_chain_ccd_with_params(chain, target_world, pole_world, ik_influence, ik_max_iterations, ik_min_distance)


func _solve_arm_chain_ccd_with_params(
	chain: PackedInt32Array,
	target_world: Vector3,
	pole_world: Vector3,
	influence: float,
	max_iterations: int,
	min_distance: float
) -> void:
	if chain.size() < 2:
		return
	var target_local := skeleton.global_transform.affine_inverse() * target_world
	var tip_index := int(chain[chain.size() - 1])
	var iterations := mini(max_iterations, 24)
	for _iter in iterations:
		var tip_pose := skeleton.get_bone_global_pose(tip_index)
		var tip_pos: Vector3 = tip_pose.origin
		if tip_pos.distance_to(target_local) <= min_distance:
			break
		for i in range(chain.size() - 2, -1, -1):
			var bone_index := int(chain[i])
			var bone_pose := skeleton.get_bone_global_pose(bone_index)
			var bone_pos: Vector3 = bone_pose.origin
			var to_tip := tip_pos - bone_pos
			var to_target := target_local - bone_pos
			var tip_len := to_tip.length()
			var target_len := to_target.length()
			if tip_len <= 0.00001 or target_len <= 0.00001:
				continue
			to_tip /= tip_len
			to_target /= target_len
			var axis := to_tip.cross(to_target)
			var axis_len := axis.length()
			if axis_len <= 0.00001:
				continue
			axis /= axis_len
			var dot_val := clampf(to_tip.dot(to_target), -1.0, 1.0)
			var angle := acos(dot_val)
			if angle <= 0.0001:
				continue
			var step_angle := minf(angle, 0.35)
			var rot := Basis(axis, step_angle)
			var new_basis := (rot * bone_pose.basis).orthonormalized()
			var new_pose := Transform3D(new_basis, bone_pose.origin)
			skeleton.set_bone_global_pose_override(bone_index, new_pose, influence, false)
			tip_pose = skeleton.get_bone_global_pose(tip_index)
			tip_pos = tip_pose.origin

	if pole_world != Vector3.ZERO and chain.size() >= 3:
		var root_index := int(chain[0])
		var mid_index := int(chain[1])
		var tip_pose_final := skeleton.get_bone_global_pose(tip_index)
		var root_pose := skeleton.get_bone_global_pose(root_index)
		var mid_pose := skeleton.get_bone_global_pose(mid_index)
		var axis_dir := (tip_pose_final.origin - root_pose.origin).normalized()
		var pole_local := skeleton.global_transform.affine_inverse() * pole_world
		var current_vec := mid_pose.origin - root_pose.origin
		var desired_vec := pole_local - root_pose.origin
		var cur_proj := current_vec - axis_dir * current_vec.dot(axis_dir)
		var des_proj := desired_vec - axis_dir * desired_vec.dot(axis_dir)
		if cur_proj.length_squared() > 0.00001 and des_proj.length_squared() > 0.00001:
			cur_proj = cur_proj.normalized()
			des_proj = des_proj.normalized()
			var signed := atan2(axis_dir.dot(cur_proj.cross(des_proj)), cur_proj.dot(des_proj))
			var pole_step := clampf(signed, -0.25, 0.25)
			var pole_rot := Basis(axis_dir, pole_step)
			var new_root_basis := (pole_rot * root_pose.basis).orthonormalized()
			skeleton.set_bone_global_pose_override(root_index, Transform3D(new_root_basis, root_pose.origin), influence, false)


func _clear_arm_ik_nodes() -> void:
	if skeleton != null:
		skeleton.clear_bones_global_pose_override()
	for target_variant in _arm_ik_targets.values():
		if target_variant is Node3D:
			var target := target_variant as Node3D
			if is_instance_valid(target):
				target.queue_free()
	_arm_ik_nodes.clear()
	_arm_ik_targets.clear()


func set_arm_target_pose_params(
	arm_name: String,
	base_bend: float = 0.0,
	base_bend_angle: float = 0.0,
	mid_bend: float = 0.0,
	mid_bend_angle: float = 0.0,
	tip_bend: float = 0.0,
	tip_bend_angle: float = 0.0
) -> void:
	# Backward-compatible alias.
	set_arm_target_section_bend(
		arm_name,
		base_bend,
		base_bend_angle,
		mid_bend,
		mid_bend_angle,
		tip_bend,
		tip_bend_angle
	)


func _update_arm_animation_targets(delta: float, speed_override: float = -1.0) -> void:
	var speed = speed_override if speed_override >= 0.0 else _get_owner_speed()
	var speed_factor = _get_crawl_speed_factor(speed)
	var cycle_drive = _get_crawl_cycle_drive(speed_factor)
	_crawl_phase = wrapf(_crawl_phase + TAU * crawl_profile_gait_frequency * cycle_drive * delta, 0.0, TAU)
	_update_idle_entry_state(speed, delta)

	for arm in arms:
		match _get_arm_anim_mode(arm, speed):
			ArmAnimMode.CRAWL:
				_apply_crawl_target(arm)
			ArmAnimMode.HOLD:
				_apply_hold_target(arm)
			ArmAnimMode.IDLE:
				_apply_idle_target(arm)
			_:
				_apply_default_target(arm)


func _get_arm_anim_mode(arm, speed: float) -> ArmAnimMode:
	if _is_hold_arm(arm.arm_name):
		return ArmAnimMode.HOLD
	if _arm_mode_overrides.has(arm.arm_name):
		var mode_value = int(_arm_mode_overrides[arm.arm_name])
		if mode_value < ArmAnimMode.STATIC or mode_value > ArmAnimMode.HOLD:
			return ArmAnimMode.CRAWL
		return mode_value
	if use_idle_when_stationary and speed <= idle_stationary_speed_threshold:
		return ArmAnimMode.IDLE
	return ArmAnimMode.CRAWL


func _is_hold_arm(arm_name: String) -> bool:
	if _runtime_hold_arms.has(arm_name):
		return true
	for hold_name in hold_arm_names:
		if str(hold_name) == arm_name:
			return true
	return false


func _apply_default_target(arm) -> void:
	arm.set_target_section_bend(default_base_bend, 0.0, default_mid_bend, 0.0, default_tip_bend, 0.0)


func _build_idle_target_data(arm, time_scale: float = 1.0) -> Dictionary:
	_ensure_idle_runtime_state()
	var t = Time.get_ticks_msec() * 0.001
	var phase = arm.phase_offset
	var variation = _arm_variation(arm.arm_index)
	var amp_var = _safe_float(idle_per_arm_amplitude_variation)
	var freq_var = _safe_float(idle_per_arm_frequency_variation)
	var angle_var = _safe_float(idle_per_arm_angle_variation)
	var freq_scale = 1.0 + float(variation.y) * freq_var
	var amp_scale = 1.0 + float(variation.x) * amp_var
	var angle_jitter = float(variation.z) * angle_var
	var final_time_scale = maxf(0.0, time_scale)
	var mid_offset_sign = 1.0
	if idle_randomize_mid_angle_sign:
		if typeof(_idle_mid_signs) == TYPE_DICTIONARY and _idle_mid_signs.has(arm.arm_name):
			mid_offset_sign = float(_idle_mid_signs[arm.arm_name])
	var wave = sin(t * TAU * idle_frequency_hz * freq_scale * final_time_scale + phase)
	var wave2 = sin(t * TAU * idle_frequency_hz * 1.7 * freq_scale * final_time_scale + phase * (1.3 + variation.x * 0.15))
	var mid_angle = idle_mid_bend_angle_offset + wave * 0.35 + angle_jitter * 0.55
	if idle_randomize_mid_angle_sign:
		mid_angle *= mid_offset_sign
	var run_offsets: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	if typeof(_idle_run_offsets) == TYPE_DICTIONARY and _idle_run_offsets.has(arm.arm_name):
		var offsets_variant: Variant = _idle_run_offsets[arm.arm_name]
		if offsets_variant is Array:
			run_offsets = offsets_variant
	var target_base_bend = idle_base_bend_center + wave * idle_base_bend_amplitude * amp_scale
	var target_mid_bend = idle_mid_bend_center + wave2 * idle_mid_bend_amplitude * amp_scale
	var target_tip_bend = idle_tip_bend_center + (wave + wave2) * 0.5 * idle_tip_bend_amplitude * amp_scale
	var target_base_angle = idle_base_bend_angle_offset + wave2 * 0.4 + angle_jitter * 0.25
	var target_mid_angle = mid_angle
	var target_tip_angle = idle_tip_bend_angle_offset + wave2 * 0.5 + angle_jitter * 0.8
	if run_offsets.size() >= 6:
		target_base_bend += float(run_offsets[0])
		target_base_angle += float(run_offsets[1])
		target_mid_bend += float(run_offsets[2])
		target_mid_angle += float(run_offsets[3])
		target_tip_bend += float(run_offsets[4])
		target_tip_angle += float(run_offsets[5])
	if idle_entry_pose_memory and _idle_entry_blend > 0.0 and not use_surface_locomotion:
		if typeof(_idle_entry_offsets) == TYPE_DICTIONARY and _idle_entry_offsets.has(arm.arm_name):
			var offsets: Array = _idle_entry_offsets[arm.arm_name]
			if offsets.size() >= 6:
				target_base_bend += float(offsets[0]) * _idle_entry_blend
				target_base_angle = lerp_angle(target_base_angle, target_base_angle + float(offsets[1]), _idle_entry_blend)
				target_mid_bend += float(offsets[2]) * _idle_entry_blend
				target_mid_angle = lerp_angle(target_mid_angle, target_mid_angle + float(offsets[3]), _idle_entry_blend)
				target_tip_bend += float(offsets[4]) * _idle_entry_blend
				target_tip_angle = lerp_angle(target_tip_angle, target_tip_angle + float(offsets[5]), _idle_entry_blend)
	return {
		"base_bend": target_base_bend,
		"base_angle": target_base_angle,
		"mid_bend": target_mid_bend,
		"mid_angle": target_mid_angle,
		"tip_bend": target_tip_bend,
		"tip_angle": target_tip_angle,
	}


func _apply_idle_target(arm, time_scale: float = 1.0) -> void:
	var target_data = _build_idle_target_data(arm, time_scale)
	arm.set_target_section_bend(
		float(target_data["base_bend"]),
		float(target_data["base_angle"]),
		float(target_data["mid_bend"]),
		float(target_data["mid_angle"]),
		float(target_data["tip_bend"]),
		float(target_data["tip_angle"])
	)


func _apply_hold_target(arm) -> void:
	var base_angle = hold_base_bend_angle
	var mid_angle = hold_mid_bend_angle
	var tip_angle = hold_tip_bend_angle
	if hold_animate_bend_angles:
		var t = Time.get_ticks_msec() * 0.001
		var wave01 = sin(t * TAU * hold_bend_angle_hz + arm.phase_offset) * 0.5 + 0.5
		var shared_angle = lerpf(hold_bend_angle_min, hold_bend_angle_max, wave01)
		base_angle = shared_angle
		mid_angle = shared_angle
		tip_angle = shared_angle
	arm.set_target_section_bend(
		hold_base_bend,
		base_angle,
		hold_mid_bend,
		mid_angle,
		hold_tip_bend,
		tip_angle
	)


func _apply_crawl_target(arm) -> void:
	var phase = wrapf(_crawl_phase + arm.phase_offset, 0.0, TAU)
	var side_sign := _arm_side_sign(arm)
	var stride_wave := sin(phase)
	var role_swing := stride_wave * 0.38 * crawl_profile_stride_sweep_gain
	var swing_lift := maxf(0.0, stride_wave) * crawl_profile_swing_lift

	var base_bend := clampf(
		CRAWL_PREVIEW_NEUTRAL_BASE_BEND + swing_lift * 0.45,
		-CRAWL_PREVIEW_MAX_ACTIVE_BEND,
		CRAWL_PREVIEW_MAX_ACTIVE_BEND
	)
	var mid_bend := clampf(
		CRAWL_PREVIEW_NEUTRAL_MID_BEND + swing_lift * 0.7,
		-CRAWL_PREVIEW_MAX_ACTIVE_BEND,
		CRAWL_PREVIEW_MAX_ACTIVE_BEND
	)
	var tip_bend := clampf(
		CRAWL_PREVIEW_NEUTRAL_TIP_BEND + swing_lift,
		-CRAWL_PREVIEW_MAX_ACTIVE_BEND,
		CRAWL_PREVIEW_MAX_ACTIVE_BEND
	)
	var base_angle := side_sign * clampf(
		role_swing * crawl_profile_base_angle_gain + crawl_profile_base_angle_back_bias,
		CRAWL_PREVIEW_BASE_ANGLE_BACK_LIMIT,
		CRAWL_PREVIEW_BASE_ANGLE_FORWARD_LIMIT
	)
	var mid_bend_angle := side_sign * (clampf(role_swing * 0.9, -0.72, 0.72) + 1.5)
	var tip_angle := side_sign * (clampf(role_swing * 0.42, -0.34, 0.34) + 2.5)

	arm.set_target_section_bend(
		base_bend,
		base_angle,
		mid_bend,
		mid_bend_angle,
		tip_bend,
		tip_angle
	)


func _arm_side_sign(arm) -> float:
	if arm == null:
		return 1.0
	if str(arm.side) == "left":
		return -1.0
	return 1.0


func _get_crawl_speed_factor(speed: float) -> float:
	return clampf(speed / maxf(0.01, crawl_speed_for_full_cycle), 0.0, 1.0)


func _get_crawl_cycle_drive(speed_factor: float) -> float:
	return speed_factor if crawl_requires_motion else maxf(0.2, speed_factor)


func _sync_surface_locomotion_profile() -> void:
	if _surface_locomotion == null:
		return
	_surface_locomotion.gait_frequency = crawl_profile_gait_frequency
	_surface_locomotion.role_stride_sweep_gain = crawl_profile_stride_sweep_gain
	_surface_locomotion.crawl_swing_lift = crawl_profile_swing_lift
	_surface_locomotion.crawl_swing_base_angle_gain = crawl_profile_base_angle_gain
	_surface_locomotion.crawl_swing_base_angle_back_bias = crawl_profile_base_angle_back_bias


func _has_surface_command_input(desired_direction: Vector3) -> bool:
	var planar_len := Vector2(desired_direction.x, desired_direction.z).length()
	return planar_len > _surface_locomotion.command_deadzone


func _apply_surface_animation_overrides(delta: float, has_command_input: bool) -> void:
	if has_command_input:
		var idle_alpha := 1.0 - exp(-SURFACE_IDLE_BLEND_SPEED * maxf(delta, 0.0))
		_surface_idle_blend_state = lerpf(_surface_idle_blend_state, 0.0, idle_alpha)
	else:
		# Immediate handoff to idle on command release avoids one-frame crawl residue pose.
		_surface_idle_blend_state = 1.0
	var idle_blend := clampf(_surface_idle_blend_state, 0.0, 1.0)
	for arm in arms:
		var crawl_target := _capture_arm_target_pose(arm)
		if _is_hold_arm(arm.arm_name):
			_apply_hold_target(arm)
			var hold_target := _capture_arm_target_pose(arm)
			_apply_blended_pose(arm, crawl_target, hold_target, surface_hold_blend_strength)
		else:
			if idle_blend > 0.001:
				_apply_idle_target(arm, 1.0)
				var idle_target := _capture_arm_target_pose(arm)
				_apply_blended_pose(arm, crawl_target, idle_target, idle_blend)
			else:
				_apply_blended_pose(arm, crawl_target, crawl_target, 0.0)


func _capture_arm_target_pose(arm) -> Dictionary:
	return {
		"base_bend": float(arm.target_base_bend),
		"base_angle": float(arm.target_base_bend_angle),
		"mid_bend": float(arm.target_mid_bend),
		"mid_angle": float(arm.target_mid_bend_angle),
		"tip_bend": float(arm.target_tip_bend),
		"tip_angle": float(arm.target_tip_bend_angle),
	}


func _apply_blended_pose(arm, from_pose: Dictionary, to_pose: Dictionary, blend: float) -> void:
	var t := clampf(blend, 0.0, 1.0)
	arm.set_target_section_bend(
		lerpf(float(from_pose["base_bend"]), float(to_pose["base_bend"]), t),
		lerp_angle(float(from_pose["base_angle"]), float(to_pose["base_angle"]), t),
		lerpf(float(from_pose["mid_bend"]), float(to_pose["mid_bend"]), t),
		lerp_angle(float(from_pose["mid_angle"]), float(to_pose["mid_angle"]), t),
		lerpf(float(from_pose["tip_bend"]), float(to_pose["tip_bend"]), t),
		lerp_angle(float(from_pose["tip_angle"]), float(to_pose["tip_angle"]), t)
	)


func _update_head_pose(delta: float) -> void:
	if not enable_head_look:
		return
	if skeleton == null or head == null:
		return
	if head.bone_indices.is_empty():
		return

	var look_weight = _safe_float(head_look_weight)
	var max_yaw = _safe_float(head_max_yaw)
	var max_pitch = _safe_float(head_max_pitch)
	var sway_weight = _safe_float(head_idle_sway_weight)
	var sway_yaw = _safe_float(head_idle_sway_yaw)
	var sway_pitch = _safe_float(head_idle_sway_pitch)
	var sway_hz = _safe_float(head_idle_sway_hz)
	var lerp_speed = _safe_float(head_look_lerp_speed)
	var return_lerp_speed = _safe_float(head_return_lerp_speed)
	var yaw_sign = _safe_sign(head_look_yaw_sign, 1.0)
	var pitch_sign = _safe_sign(head_look_pitch_sign, -1.0)
	if head_debug_strong_follow:
		look_weight = 1.0
		max_yaw = 0.75
		max_pitch = 0.55
		lerp_speed = 20.0
		sway_weight = 0.0

	var mouse_target_yaw = 0.0
	var mouse_target_pitch = 0.0
	var mouse_in_view = true
	if head_look_follow_mouse:
		mouse_in_view = _is_mouse_in_viewport(get_viewport())
		if mouse_in_view:
			var mouse_look = _compute_mouse_look_targets(max_yaw, max_pitch, _safe_float(head_front_guard))
			mouse_target_yaw = mouse_look.x * yaw_sign
			mouse_target_pitch = mouse_look.y * pitch_sign
		else:
			_head_dbg_mouse_accepted = false
			_head_dbg_mouse_target = Vector2.ZERO

	var target_yaw = mouse_target_yaw * look_weight
	var target_pitch = mouse_target_pitch * look_weight
	if head_idle_sway and mouse_in_view:
		var t = Time.get_ticks_msec() * 0.001
		target_yaw += sin(t * TAU * sway_hz) * sway_yaw * sway_weight
		target_pitch += cos(t * TAU * sway_hz * 0.8) * sway_pitch * sway_weight
	var active_lerp_speed = lerp_speed if mouse_in_view else return_lerp_speed
	var alpha = 1.0 - exp(-active_lerp_speed * maxf(delta, 0.0))
	_head_yaw = lerp_angle(_head_yaw, target_yaw, alpha)
	_head_pitch = lerp_angle(_head_pitch, target_pitch, alpha)
	_apply_head_rotation(_head_yaw, _head_pitch)
	_log_head_debug(delta, mouse_target_yaw, mouse_target_pitch, target_yaw, target_pitch)


func _compute_mouse_look_targets(max_yaw: float, max_pitch: float, front_guard: float) -> Vector2:
	var viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var mouse_pos = viewport.get_mouse_position()
	var camera = viewport.get_camera_3d()
	if camera == null:
		return Vector2.ZERO
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, global_position.y)
	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if typeof(hit) != TYPE_VECTOR3:
		return Vector2.ZERO
	var world_hit: Vector3 = hit
	var to_target = world_hit - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return Vector2.ZERO
	var dir = to_target.normalized()
	var local_dir = global_transform.basis.inverse() * dir
	var forward_sign = 1.0 if _safe_float(head_forward_sign) >= 0.0 else -1.0
	var forward_component = local_dir.z * forward_sign
	_head_dbg_forward_component = forward_component
	if forward_component <= front_guard:
		_head_dbg_mouse_accepted = false
		_head_dbg_mouse_target = Vector2.ZERO
		return Vector2.ZERO
	var yaw = clampf(atan2(local_dir.x, forward_component), -max_yaw, max_yaw)
	var rect = viewport.get_visible_rect()
	var pitch = 0.0
	if rect.size.y > 1.0:
		var ny = (mouse_pos.y - rect.size.y * 0.5) / (rect.size.y * 0.5)
		pitch = clampf(ny, -1.0, 1.0) * max_pitch
	var result = Vector2(yaw, pitch)
	_head_dbg_mouse_accepted = true
	_head_dbg_mouse_target = result
	return result


func _is_mouse_in_viewport(viewport: Viewport) -> bool:
	if viewport == null:
		return false
	var rect = viewport.get_visible_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return false
	var pos = viewport.get_mouse_position()
	return pos.x >= 0.0 and pos.y >= 0.0 and pos.x <= rect.size.x and pos.y <= rect.size.y


func _update_idle_entry_state(speed: float, delta: float) -> void:
	_ensure_idle_runtime_state()
	if not use_idle_when_stationary:
		_was_moving_for_idle = speed > 0.001
		return
	var moving_now = speed > idle_stationary_speed_threshold
	if _was_moving_for_idle and not moving_now:
		_randomize_idle_run_state()
		_capture_idle_entry_offsets()
		_idle_entry_blend = 1.0 if idle_entry_pose_memory else 0.0
	elif not moving_now and _idle_run_offsets.is_empty():
		# Ensure a randomized idle state also exists when starting from standstill.
		_randomize_idle_run_state()
	elif moving_now:
		_idle_entry_blend = 0.0
	_idle_entry_blend = maxf(0.0, _idle_entry_blend - maxf(0.0, delta) * maxf(0.0, idle_entry_memory_decay_speed))
	_was_moving_for_idle = moving_now


func _randomize_idle_run_state() -> void:
	_ensure_idle_runtime_state()
	_idle_run_offsets.clear()
	_idle_mid_signs.clear()
	var invert_fraction = clampf(_safe_float(idle_mid_angle_invert_fraction), 0.0, 1.0)
	var sorted_arms: Array = arms.duplicate()
	sorted_arms.sort_custom(func(a, b): return str(a.arm_name) < str(b.arm_name))
	var split_flip = -1.0 if _idle_rng.randf() < 0.5 else 1.0
	for arm in sorted_arms:
		_idle_run_offsets[arm.arm_name] = [
			_idle_rng.randf_range(-idle_run_base_center_jitter, idle_run_base_center_jitter),
			_idle_rng.randf_range(-idle_run_base_angle_jitter, idle_run_base_angle_jitter),
			_idle_rng.randf_range(-idle_run_mid_center_jitter, idle_run_mid_center_jitter),
			_idle_rng.randf_range(-idle_run_mid_angle_jitter, idle_run_mid_angle_jitter),
			_idle_rng.randf_range(-idle_run_tip_center_jitter, idle_run_tip_center_jitter),
			_idle_rng.randf_range(-idle_run_tip_angle_jitter, idle_run_tip_angle_jitter),
		]
		var sign_value = 1.0
		if idle_randomize_mid_angle_sign:
			if idle_split_mid_angle_even_odd:
				sign_value = split_flip if (arm.arm_index % 2) == 0 else -split_flip
			elif _idle_rng.randf() < invert_fraction:
				sign_value = -1.0
		_idle_mid_signs[arm.arm_name] = sign_value


func _capture_idle_entry_offsets() -> void:
	_idle_entry_offsets.clear()
	for arm in arms:
		_idle_entry_offsets[arm.arm_name] = [
			arm.base_bend - idle_base_bend_center,
			_wrap_angle_pi(arm.base_bend_angle - idle_base_bend_angle_offset),
			arm.mid_bend - idle_mid_bend_center,
			_wrap_angle_pi(arm.mid_bend_angle - idle_mid_bend_angle_offset),
			arm.tip_bend - idle_tip_bend_center,
			_wrap_angle_pi(arm.tip_bend_angle - idle_tip_bend_angle_offset),
		]


func _arm_variation(index: int) -> Vector3:
	# Deterministic per-arm variation in [-1, 1].
	var i = float(index + 1)
	var x = sin(i * 12.9898) * 43758.5453
	var y = sin(i * 78.233) * 14591.372
	var z = sin(i * 39.425) * 9631.417
	return Vector3(
		_fract(x) * 2.0 - 1.0,
		_fract(y) * 2.0 - 1.0,
		_fract(z) * 2.0 - 1.0
	)


func _apply_head_rotation(yaw: float, pitch: float) -> void:
	var count = head.bone_indices.size()
	if count <= 0:
		return
	for i in count:
		var bone_index = head.bone_indices[i]
		if not head.rest_rotations.has(bone_index):
			continue
		var t = 0.0 if count <= 1 else float(i) / float(count - 1)
		var weight = lerpf(0.35, 1.0, _smoothstep01(t))
		var q_yaw = Quaternion(Vector3.UP, yaw * weight)
		var q_pitch = Quaternion(Vector3.RIGHT, pitch * weight)
		var rest_rotation: Quaternion = head.rest_rotations[bone_index]
		skeleton.set_bone_pose_rotation(bone_index, rest_rotation * q_yaw * q_pitch)


func _apply_editor_preview_targets() -> void:
	for arm in arms:
		if preview_apply_to_all_arms or arm.arm_name == preview_arm_name:
			arm.set_target_pose_params(
				_safe_float(preview_base_bend),
				preview_base_bend_angle,
				_safe_float(preview_mid_bend),
				preview_mid_bend_angle,
				_safe_float(preview_tip_bend),
				preview_tip_bend_angle
			)
		else:
			arm.set_target_pose_params(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)


func _on_preview_property_changed() -> void:
	if not Engine.is_editor_hint():
		return
	if not is_inside_tree():
		return
	_sync_surface_locomotion_profile()
	if not preview_in_editor:
		_restore_preview_animation_players()
		return
	if not _setup_valid:
		_setup_valid = build_rig()
		if not _setup_valid:
			return
	_suspend_animation_players_for_preview()
	_apply_preview_targets(1.0 / 60.0)
	for arm in arms:
		arm.snap_to_target_params()
		arm.apply_pose(skeleton)
	_update_head_pose(1.0 / 60.0)
	if skeleton != null and skeleton.has_method("force_update_all_bone_transforms"):
		skeleton.call("force_update_all_bone_transforms")


func _process_editor_preview(delta: float) -> void:
	if _should_rebuild_preview_rig():
		_setup_valid = false

	if not _setup_valid:
		_setup_valid = build_rig()
		if not _setup_valid:
			return
	if skeleton == null:
		return

	_suspend_animation_players_for_preview()
	var preview_delta = delta if delta > 0.0 else 1.0 / 60.0
	_apply_preview_targets(preview_delta)
	if preview_force_single_bone_test:
		_apply_force_single_bone_preview()
	for arm in arms:
		if preview_animation_mode == 0 or not preview_animate_in_editor:
			# In static preview mode, snap so inspector changes are always visible.
			arm.snap_to_target_params()
		else:
			arm.update_params(preview_delta)
		arm.apply_pose(skeleton)
	_update_head_pose(preview_delta)

	if skeleton.has_method("force_update_all_bone_transforms"):
		skeleton.call("force_update_all_bone_transforms")

	if preview_run_skin_diagnostics and not _skin_diag_printed:
		_skin_diag_printed = true
		_print_skin_influence_diagnostics()

	if preview_confirm_logs:
		_preview_log_accum += delta
		if _preview_log_accum >= 0.5:
			_preview_log_accum = 0.0
			_log_preview_confirmation()


func _apply_preview_targets(delta: float) -> void:
	if preview_animation_mode == 0 or not preview_animate_in_editor:
		_apply_editor_preview_targets()
		return
	match preview_animation_mode:
		1:
			for arm in arms:
				_apply_idle_target(arm)
		2:
			if not _apply_surface_preview_crawl(delta):
				# Fallback if editor world/space state is unavailable.
				var preview_speed_factor = _get_crawl_speed_factor(_safe_float(preview_motion_speed))
				var preview_cycle_drive = _get_crawl_cycle_drive(preview_speed_factor)
				_crawl_phase = wrapf(_crawl_phase + TAU * crawl_profile_gait_frequency * preview_cycle_drive * maxf(delta, 1.0 / 60.0), 0.0, TAU)
				for arm in arms:
					_apply_crawl_target(arm)
		3:
			_update_arm_animation_targets(delta, _safe_float(crawl_speed_for_full_cycle))
		4:
			for arm in arms:
				_apply_hold_target(arm)
		_:
			_apply_editor_preview_targets()


func _apply_surface_preview_crawl(delta: float) -> bool:
	if not _setup_valid or skeleton == null:
		return false
	var world := get_world_3d()
	if world == null:
		return false
	var space_state := world.direct_space_state
	if space_state == null:
		return false
	var preview_delta := maxf(delta, 1.0 / 60.0)
	var preview_speed := maxf(0.0, _safe_float(preview_motion_speed))
	var desired_direction := -global_transform.basis.z * preview_speed
	_sync_surface_locomotion_profile()
	_surface_locomotion.enabled = true
	_surface_locomotion.debug_enabled = surface_locomotion_debug
	_surface_locomotion.step(
		preview_delta,
		global_position,
		global_transform.basis,
		desired_direction,
		_surface_drive_velocity,
		space_state
	)
	_apply_surface_animation_overrides(preview_delta, _has_surface_command_input(desired_direction))
	_surface_drive_velocity = _surface_locomotion.get_drive_velocity()
	_surface_support_normal = _surface_locomotion.get_support_normal()
	_surface_debug_lines = _surface_locomotion.get_debug_lines()
	return true


func _log_preview_confirmation() -> void:
	if arms.is_empty() or skeleton == null:
		print("OctoRig preview: no arms or skeleton unavailable.")
		return
	var arm = arms[0]
	if arm.bone_indices.is_empty():
		print("OctoRig preview: first arm has no bones.")
		return
	var bone_index = arm.bone_indices[0]
	var rot: Quaternion = skeleton.get_bone_pose_rotation(bone_index)
	print(
		"OctoRig preview applied | arm=%s bone=%d rot=(%.3f, %.3f, %.3f, %.3f)" % [
			arm.arm_name,
			bone_index,
			rot.x,
			rot.y,
			rot.z,
			rot.w,
		]
	)


func _print_skin_influence_diagnostics() -> void:
	if skeleton == null:
		return
	var weighted_bones = _collect_weighted_bone_indices()
	if weighted_bones.is_empty():
		push_warning("OctoRig preview: no weighted bones detected from child MeshInstance3D skins.")
		return

	var configured_arm_bones = get_all_arm_bones()
	var overlap = 0
	for bone_index in configured_arm_bones:
		if weighted_bones.has(bone_index):
			overlap += 1

	print(
		"OctoRig skin diagnostic | weighted=%d configured_arm=%d overlap=%d" % [
			weighted_bones.size(),
			configured_arm_bones.size(),
			overlap,
		]
	)
	if overlap <= 0:
		push_warning(
			"OctoRig preview: configured arm bones appear unweighted by mesh skin. "
			+ "Choose deform bones (not control/mechanism bones) in ARM_CONFIGS."
		)


func _collect_weighted_bone_indices() -> Dictionary:
	var result = {}
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh_node in meshes:
		var mesh_instance = mesh_node as MeshInstance3D
		if mesh_instance == null:
			continue
		var skin = mesh_instance.skin
		if skin == null:
			continue
		var bind_count = skin.get_bind_count()
		for i in bind_count:
			var bone_index = skin.get_bind_bone(i)
			if bone_index >= 0:
				result[bone_index] = true
	return result


func _should_rebuild_preview_rig() -> bool:
	if skeleton == null:
		return true
	if not is_instance_valid(skeleton):
		return true
	if not is_ancestor_of(skeleton):
		return true
	if arms.is_empty():
		return true
	return false


func _apply_force_single_bone_preview() -> void:
	if skeleton == null:
		return
	var bone_index = skeleton.find_bone(StringName(preview_force_bone_name))
	if bone_index < 0:
		push_warning("OctoRig preview: force test bone '%s' not found." % preview_force_bone_name)
		return
	var rest = skeleton.get_bone_rest(bone_index)
	var rest_rot = rest.basis.get_rotation_quaternion()
	var forced_rot = rest_rot * Quaternion(Vector3.RIGHT, preview_force_bone_angle)
	skeleton.set_bone_pose_rotation(bone_index, forced_rot)


func _suspend_animation_players_for_preview() -> void:
	var found_players = find_children("*", "AnimationPlayer", true, false)
	for player_node in found_players:
		var player = player_node as AnimationPlayer
		if player == null:
			continue
		var path = str(get_path_to(player))
		if not _preview_animation_state_by_path.has(path):
			_preview_animation_state_by_path[path] = player.active
		player.stop()
		player.active = false


func _restore_preview_animation_players() -> void:
	if _preview_animation_state_by_path.is_empty():
		return
	for path in _preview_animation_state_by_path.keys():
		var player = get_node_or_null(NodePath(path)) as AnimationPlayer
		if player == null:
			continue
		player.active = bool(_preview_animation_state_by_path[path])
	_preview_animation_state_by_path.clear()


func _clear_runtime_data() -> void:
	_clear_arm_ik_nodes()
	if _surface_debug_mesh_instance != null and is_instance_valid(_surface_debug_mesh_instance):
		_surface_debug_mesh_instance.queue_free()
	_surface_debug_mesh_instance = null
	_surface_debug_immediate = null
	arms.clear()
	head = null
	skeleton = null
	_validation_errors.clear()
	_validation_warnings.clear()
	_setup_valid = false
	_crawl_phase = 0.0
	_arm_mode_overrides.clear()
	_runtime_hold_arms.clear()
	_head_yaw = 0.0
	_head_pitch = 0.0
	_was_moving_for_idle = false
	_idle_entry_blend = 0.0
	_idle_entry_offsets.clear()
	_idle_run_offsets.clear()
	_idle_mid_signs.clear()
	_surface_drive_velocity = Vector3.ZERO
	_surface_support_normal = Vector3.UP
	_surface_debug_lines = PackedStringArray()
	_surface_debug_accum = 0.0
	_surface_idle_blend_state = 0.0
	_surface_locomotion.setup(self, [])


func _to_string_array(value: Variant, context: String) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	else:
		_validation_errors.append("%s: expected an Array of bone names." % context)
	return result


func _get_owner_speed() -> float:
	var body = get_parent() as CharacterBody3D
	if body == null:
		return 0.0
	return body.velocity.length()


func _saturate(value: float) -> float:
	return clampf(value, 0.0, 1.0)


func _smoothstep01(value: float) -> float:
	var x := _saturate(value)
	return x * x * (3.0 - 2.0 * x)


func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 0.0
	var x := (value - edge0) / (edge1 - edge0)
	return _smoothstep01(x)


func _fract(value: float) -> float:
	return value - floor(value)


func _wrap_angle_pi(angle: float) -> float:
	return wrapf(angle, -PI, PI)


func _safe_sign(value: Variant, default_sign: float) -> float:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return default_sign
	var sign_value = float(value)
	if is_zero_approx(sign_value):
		return default_sign
	return 1.0 if sign_value > 0.0 else -1.0


func _log_head_debug(
	delta: float,
	mouse_yaw: float,
	mouse_pitch: float,
	target_yaw: float,
	target_pitch: float
) -> void:
	if not head_debug_logs:
		return
	_head_debug_accum += maxf(delta, 0.0)
	if _head_debug_accum < maxf(0.05, _safe_float(head_debug_log_interval)):
		return
	_head_debug_accum = 0.0
	print(
		"HeadFollow dbg | accepted=%s forward=%.3f mouse=(%.3f, %.3f) target=(%.3f, %.3f) applied=(%.3f, %.3f)" % [
			str(_head_dbg_mouse_accepted),
			_head_dbg_forward_component,
			mouse_yaw,
			mouse_pitch,
			target_yaw,
			target_pitch,
			_head_yaw,
			_head_pitch,
		]
	)


func _find_best_skeleton_for_config() -> Skeleton3D:
	var candidates = find_children("*", "Skeleton3D", true, false)
	if candidates.is_empty():
		return null

	var required_names = _collect_all_configured_bone_names()
	var best_skeleton: Skeleton3D
	var best_score = -1

	for candidate in candidates:
		var skel = candidate as Skeleton3D
		if skel == null:
			continue
		var score = 0
		for bone_name in required_names:
			if skel.find_bone(StringName(bone_name)) >= 0:
				score += 1
		if score > best_score:
			best_score = score
			best_skeleton = skel

	if best_skeleton != null and debug_print_on_ready:
		print(
			"OctoRig: selected skeleton '%s' (matched %d/%d configured bones)." % [
				best_skeleton.get_path(),
				best_score,
				required_names.size(),
			]
		)

	return best_skeleton


func _collect_all_configured_bone_names() -> Array[String]:
	var names: Array[String] = []
	var unique = {}

	for head_name in HEAD_BONE_NAMES:
		var key = str(head_name)
		if not unique.has(key):
			unique[key] = true
			names.append(key)

	for arm_key in ARM_CONFIGS.keys():
		var arm_variant: Variant = ARM_CONFIGS[arm_key]
		if not (arm_variant is Dictionary):
			continue
		var bones_variant: Variant = (arm_variant as Dictionary).get("bones", [])
		if not (bones_variant is Array):
			continue
		for entry in bones_variant:
			var bone_name = str(entry)
			if not unique.has(bone_name):
				unique[bone_name] = true
				names.append(bone_name)

	return names


func _collect_assignment_sources() -> Dictionary:
	var sources = {}

	for bone_name in HEAD_BONE_NAMES:
		_add_assignment_source(sources, bone_name, "head")

	for arm_key in ARM_CONFIGS.keys():
		var source_label = "arm '%s'" % str(arm_key)
		var arm_value: Variant = ARM_CONFIGS[arm_key]
		if not (arm_value is Dictionary):
			continue
		var bones_variant: Variant = (arm_value as Dictionary).get("bones", [])
		if bones_variant is Array:
			for entry in bones_variant:
				_add_assignment_source(sources, str(entry), source_label)

	return sources


func _add_assignment_source(sources: Dictionary, bone_name: String, source: String) -> void:
	if not sources.has(bone_name):
		sources[bone_name] = []
	var assignments: Array = sources[bone_name]
	if not assignments.has(source):
		assignments.append(source)
	sources[bone_name] = assignments


func _detect_duplicate_assignments(sources: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	for bone_name in sources.keys():
		var assignments: Array = sources[bone_name]
		if assignments.size() > 1:
			warnings.append(
				"Duplicate assignment: bone '%s' is used by %s." % [
					bone_name,
					", ".join(PackedStringArray(assignments)),
				]
			)
	return warnings


func _safe_float(value: Variant) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return 0.0


func _ensure_idle_runtime_state() -> void:
	if _idle_entry_offsets == null:
		_idle_entry_offsets = {}
	if _idle_run_offsets == null:
		_idle_run_offsets = {}
	if _idle_mid_signs == null:
		_idle_mid_signs = {}
	if _idle_rng == null:
		_idle_rng = RandomNumberGenerator.new()
		_idle_rng.randomize()


func _print_validation_failures() -> void:
	for error in _validation_errors:
		push_error(error)
	for warning in _validation_warnings:
		push_warning(warning)
