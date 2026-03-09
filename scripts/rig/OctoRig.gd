@tool
extends Node3D
class_name OctoRig

const OctoArmType = preload("res://scripts/rig/OctoArm.gd")
const OctoHeadType = preload("res://scripts/rig/OctoHead.gd")

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

@export var debug_print_on_ready = true
@export var print_indices_on_ready = false
@export var apply_arm_pose_each_frame = true
@export var default_base_bend = 0.67
@export var default_mid_bend = 0.0
@export var default_tip_bend = 0.0
@export var enable_idle_wiggle_demo = false
@export var idle_base_bend_amplitude = 0.35
@export var idle_mid_bend_amplitude = 0.26
@export var idle_tip_bend_amplitude = 0.2
@export_range(-3.14, 3.14, 0.01) var idle_base_bend_angle_offset = 0.0
@export_range(-3.14, 3.14, 0.01) var idle_mid_bend_angle_offset = 0.45
@export_range(-3.14, 3.14, 0.01) var idle_tip_bend_angle_offset = 0.9
@export var idle_frequency_hz = 0.9
@export var preview_in_editor = false
@export var preview_apply_to_all_arms = true
@export var preview_arm_name = "arm_0"
@export_range(-1.5, 1.5, 0.01) var preview_base_bend: float = 0.0
@export_range(-3.14, 3.14, 0.01) var preview_base_bend_angle = 0.0
@export_range(-1.5, 1.5, 0.01) var preview_mid_bend: float = 0.0
@export_range(-3.14, 3.14, 0.01) var preview_mid_bend_angle = 0.0
@export_range(-1.5, 1.5, 0.01) var preview_tip_bend: float = 0.0
@export_range(-3.14, 3.14, 0.01) var preview_tip_bend_angle = 0.0
@export var preview_confirm_logs = false
@export var preview_run_skin_diagnostics = true
@export var preview_force_single_bone_test = false
@export var preview_force_bone_name = "HEAD_01"
@export_range(-3.14, 3.14, 0.01) var preview_force_bone_angle = 1.2

var skeleton: Skeleton3D
var head
var arms: Array = []

var _setup_valid = false
var _validation_errors: Array[String] = []
var _validation_warnings: Array[String] = []
var _preview_animation_state_by_path: Dictionary = {}
var _preview_log_accum = 0.0
var _skin_diag_printed = false


func _ready() -> void:
	set_process(true)
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
	if enable_idle_wiggle_demo:
		_update_idle_wiggle_targets()
	if apply_arm_pose_each_frame:
		for arm in arms:
			arm.update_params(delta)
			arm.apply_pose(skeleton)


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


func _update_idle_wiggle_targets() -> void:
	var time_s = Time.get_ticks_msec() * 0.001
	var omega = TAU * idle_frequency_hz
	for arm in arms:
		var phase = arm.phase_offset
		var main_wave = sin(time_s * omega + phase)
		var second_wave = sin(time_s * omega * 1.7 + phase * 1.3)
		var third_wave = sin(time_s * omega * 1.2 + phase * 0.8)
		arm.set_target_pose_params(
			main_wave * idle_base_bend_amplitude,
			idle_base_bend_angle_offset + second_wave * 0.5,
			second_wave * idle_mid_bend_amplitude,
			idle_mid_bend_angle_offset + main_wave * 0.4,
			third_wave * idle_tip_bend_amplitude,
			idle_tip_bend_angle_offset + second_wave * 0.6
		)


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
	if not preview_in_editor:
		_restore_preview_animation_players()
		return
	if not _setup_valid:
		_setup_valid = build_rig()
		if not _setup_valid:
			return
	_suspend_animation_players_for_preview()
	_apply_editor_preview_targets()
	for arm in arms:
		arm.snap_to_target_params()
		arm.apply_pose(skeleton)
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
	_apply_editor_preview_targets()
	if preview_force_single_bone_test:
		_apply_force_single_bone_preview()
	for arm in arms:
		# In editor preview, delta may be 0; snap so inspector changes are always visible.
		arm.snap_to_target_params()
		arm.apply_pose(skeleton)

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
	arms.clear()
	head = null
	skeleton = null
	_validation_errors.clear()
	_validation_warnings.clear()
	_setup_valid = false


func _to_string_array(value: Variant, context: String) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	else:
		_validation_errors.append("%s: expected an Array of bone names." % context)
	return result


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


func _print_validation_failures() -> void:
	for error in _validation_errors:
		push_error(error)
	for warning in _validation_warnings:
		push_warning(warning)
