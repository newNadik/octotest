extends RefCounted
class_name OctoArm


enum ArmState {
	IDLE,
	SUPPORT,
	STEP,
	HOLD,
	REACH,
}

var arm_name: String = ""
var arm_index: int = -1
var side: String = "unknown"
var role_bias: String = "neutral"

var bone_names: Array[String] = []
var bone_indices: Array[int] = []

var base_bones: Array[int] = []
var mid_bones: Array[int] = []
var tip_bones: Array[int] = []

var rest_rotations: Dictionary = {}

var current_state: ArmState = ArmState.IDLE
var phase_offset: float = 0.0
var held_item: Node3D
var target_position: Vector3 = Vector3.ZERO
var target_node: Node3D

# Section-driven pose controls.
# bend = contraction amount, bend_angle = direction around the section axis.
var base_bend: float = 0.0
var base_bend_angle: float = 0.0
var mid_bend: float = 0.0
var mid_bend_angle: float = 0.0
var tip_bend: float = 0.0
var tip_bend_angle: float = 0.0

# Per-section scales let each arm be tuned independently.
var base_bend_scale: float = 1.0
var mid_bend_scale: float = 1.0
var tip_bend_scale: float = 1.0

var target_base_bend: float = 0.0
var target_base_bend_angle: float = 0.0
var target_mid_bend: float = 0.0
var target_mid_bend_angle: float = 0.0
var target_tip_bend: float = 0.0
var target_tip_bend_angle: float = 0.0

var param_lerp_speed: float = 8.0

enum LocalAxis {
	X,
	Y,
	Z,
}

# Axis mapping can vary per imported rig. Tune these values if motion looks incorrect.
var curl_axis: LocalAxis = LocalAxis.X
var curl_axis_sign: float = 1.0
var lift_axis: LocalAxis = LocalAxis.Z
var lift_axis_sign: float = 1.0

var errors: Array[String] = []
var warnings: Array[String] = []

const BASE_BEND_MIN := -1.5
const BASE_BEND_MAX := 1.5
const MID_BEND_MIN := -1.5
const MID_BEND_MAX := 1.5
const TIP_BEND_MIN := -1.5
const TIP_BEND_MAX := 1.5
const BEND_DIRECTION_SIGN := -1.0

var base_bone: int:
	get:
		if base_bones.is_empty():
			return -1
		return base_bones[0]

var middle_bone: int:
	get:
		if bone_indices.is_empty():
			return -1
		return bone_indices[bone_indices.size() / 2]

var tip_bone: int:
	get:
		if tip_bones.is_empty():
			return -1
		return tip_bones[tip_bones.size() - 1]


func setup(
	skeleton: Skeleton3D,
	new_arm_name: String,
	new_arm_index: int,
	new_bone_names: Array[String],
	new_side: String = "unknown",
	new_role_bias: String = "neutral"
) -> bool:
	_clear_data()
	arm_name = new_arm_name
	arm_index = new_arm_index
	side = new_side
	role_bias = new_role_bias
	bone_names = new_bone_names.duplicate()

	if skeleton == null:
		errors.append("Arm '%s': skeleton is null." % arm_name)
		return false

	if bone_names.is_empty():
		errors.append("Arm '%s': no bones configured." % arm_name)
		return false

	if bone_names.size() < 3:
		errors.append("Arm '%s': expected at least 3 bones, got %d." % [arm_name, bone_names.size()])

	var seen_indices := {}
	for bone_name in bone_names:
		var bone_index := skeleton.find_bone(StringName(bone_name))
		if bone_index < 0:
			errors.append("Arm '%s': bone '%s' was not found in skeleton." % [arm_name, bone_name])
			continue
		if seen_indices.has(bone_index):
			warnings.append("Arm '%s': duplicate bone '%s' in this arm chain." % [arm_name, bone_name])
		else:
			seen_indices[bone_index] = true
		bone_indices.append(bone_index)

	if not errors.is_empty():
		return false

	_split_chain_into_parts()
	_cache_rest_pose(skeleton)
	snap_to_target_params()
	return true


func has_valid_setup() -> bool:
	return errors.is_empty() and bone_indices.size() >= 3


func get_all_bones() -> Array[int]:
	return bone_indices.duplicate()


func get_part_bones(part_name: String) -> Array[int]:
	var part := part_name.strip_edges().to_lower()
	match part:
		"base":
			return base_bones.duplicate()
		"mid", "middle":
			return mid_bones.duplicate()
		"tip", "end":
			return tip_bones.duplicate()
		_:
			return []


func set_target_section_bend(
	new_base_bend: float = 0.0,
	new_base_bend_angle: float = 0.0,
	new_mid_bend: float = 0.0,
	new_mid_bend_angle: float = 0.0,
	new_tip_bend: float = 0.0,
	new_tip_bend_angle: float = 0.0
) -> void:
	target_base_bend = clampf(new_base_bend, BASE_BEND_MIN, BASE_BEND_MAX)
	target_base_bend_angle = new_base_bend_angle
	target_mid_bend = clampf(new_mid_bend, MID_BEND_MIN, MID_BEND_MAX)
	target_mid_bend_angle = new_mid_bend_angle
	target_tip_bend = clampf(new_tip_bend, TIP_BEND_MIN, TIP_BEND_MAX)
	target_tip_bend_angle = new_tip_bend_angle


func set_target_pose_params(
	new_base_bend: float = 0.0,
	new_base_bend_angle: float = 0.0,
	new_mid_bend: float = 0.0,
	new_mid_bend_angle: float = 0.0,
	new_tip_bend: float = 0.0,
	new_tip_bend_angle: float = 0.0
) -> void:
	# Backward-compatible alias.
	set_target_section_bend(
		new_base_bend,
		new_base_bend_angle,
		new_mid_bend,
		new_mid_bend_angle,
		new_tip_bend,
		new_tip_bend_angle
	)


func set_axis_mapping(
	new_curl_axis: LocalAxis,
	new_lift_axis: LocalAxis,
	new_curl_sign: float = 1.0,
	new_lift_sign: float = 1.0
) -> void:
	curl_axis = new_curl_axis
	lift_axis = new_lift_axis
	curl_axis_sign = new_curl_sign
	lift_axis_sign = new_lift_sign


func set_section_bend_scales(
	new_base_bend_scale: float = 1.0,
	new_mid_bend_scale: float = 1.0,
	new_tip_bend_scale: float = 1.0
) -> void:
	base_bend_scale = new_base_bend_scale
	mid_bend_scale = new_mid_bend_scale
	tip_bend_scale = new_tip_bend_scale


func update_params(delta: float) -> void:
	var alpha := 1.0 - exp(-param_lerp_speed * maxf(delta, 0.0))
	base_bend = lerpf(base_bend, target_base_bend, alpha)
	base_bend_angle = lerp_angle(base_bend_angle, target_base_bend_angle, alpha)
	mid_bend = lerpf(mid_bend, target_mid_bend, alpha)
	mid_bend_angle = lerp_angle(mid_bend_angle, target_mid_bend_angle, alpha)
	tip_bend = lerpf(tip_bend, target_tip_bend, alpha)
	tip_bend_angle = lerp_angle(tip_bend_angle, target_tip_bend_angle, alpha)


func snap_to_target_params() -> void:
	base_bend = target_base_bend
	base_bend_angle = target_base_bend_angle
	mid_bend = target_mid_bend
	mid_bend_angle = target_mid_bend_angle
	tip_bend = target_tip_bend
	tip_bend_angle = target_tip_bend_angle


func apply_pose(skeleton: Skeleton3D) -> void:
	if skeleton == null:
		return
	var total_count := bone_indices.size()
	if total_count <= 0:
		return

	for i in total_count:
		var bone_index := bone_indices[i]
		if not rest_rotations.has(bone_index):
			continue
		var t := _chain_t(i, total_count)
		var base_influence := _section_bend_influence("base", t)
		var mid_influence := _section_bend_influence("mid", t)
		var tip_influence := _section_bend_influence("tip", t)

		# Positive bend should lift arm upward in the current rig setup.
		var weighted_base_bend := base_bend * base_bend_scale * base_influence * BEND_DIRECTION_SIGN
		var weighted_mid_bend := mid_bend * mid_bend_scale * mid_influence * BEND_DIRECTION_SIGN
		var weighted_tip_bend := tip_bend * tip_bend_scale * tip_influence * BEND_DIRECTION_SIGN
		var curl_value := (
			weighted_base_bend * cos(base_bend_angle)
			+ weighted_mid_bend * cos(mid_bend_angle)
			+ weighted_tip_bend * cos(tip_bend_angle)
		)
		var lift_value := (
			weighted_base_bend * sin(base_bend_angle)
			+ weighted_mid_bend * sin(mid_bend_angle)
			+ weighted_tip_bend * sin(tip_bend_angle)
		)
		var procedural_offset := _compose_offset_rotation(curl_value, lift_value)
		var rest_rotation: Quaternion = rest_rotations[bone_index]
		var final_rotation := rest_rotation * procedural_offset
		skeleton.set_bone_pose_rotation(bone_index, final_rotation)

func _chain_t(index: int, count: int) -> float:
	if count <= 1:
		return 0.0
	return float(index) / float(count - 1)


func _section_bend_influence(section: String, t: float) -> float:
	var blend := _section_blend_weight(section, t)
	if blend <= 0.0:
		return 0.0
	var local_t := _section_local_t(section, t)
	var contraction := lerpf(0.2, 1.0, _smoothstep01(local_t))
	return blend * contraction


func _section_blend_weight(section: String, t: float) -> float:
	# Overlapping windows so base/mid/tip transitions stay smooth.
	match section:
		"base":
			return 1.0 - _smoothstep(0.22, 0.55, t)
		"mid":
			var rise := _smoothstep(0.18, 0.5, t)
			var fall := 1.0 - _smoothstep(0.5, 0.82, t)
			return rise * fall
		"tip":
			return _smoothstep(0.45, 0.78, t)
		_:
			return 0.0


func _section_local_t(section: String, t: float) -> float:
	# Local progress used for contraction profile while preserving section overlap.
	match section:
		"base":
			return _remap_clamped(t, 0.0, 0.55)
		"mid":
			return _remap_clamped(t, 0.18, 0.82)
		"tip":
			return _remap_clamped(t, 0.45, 1.0)
		_:
			return 0.0


func _clear_data() -> void:
	bone_names.clear()
	bone_indices.clear()
	base_bones.clear()
	mid_bones.clear()
	tip_bones.clear()
	rest_rotations.clear()
	errors.clear()
	warnings.clear()
	set_target_section_bend()
	snap_to_target_params()


func _split_chain_into_parts() -> void:
	var total := bone_indices.size()
	if total <= 0:
		return

	var base_count := total / 3
	var mid_count := total / 3
	var tip_count := total / 3

	match total % 3:
		1:
			base_count += 1
		2:
			base_count += 1
			mid_count += 1
		_:
			pass

	# Guarantees all parts remain populated for valid chains (>=3 bones).
	if total >= 3:
		base_count = maxi(base_count, 1)
		mid_count = maxi(mid_count, 1)
		tip_count = maxi(tip_count, 1)

	while base_count + mid_count + tip_count > total:
		if tip_count > 1:
			tip_count -= 1
		elif mid_count > 1:
			mid_count -= 1
		elif base_count > 1:
			base_count -= 1
		else:
			break

	while base_count + mid_count + tip_count < total:
		tip_count += 1

	base_bones = bone_indices.slice(0, base_count)
	mid_bones = bone_indices.slice(base_count, base_count + mid_count)
	tip_bones = bone_indices.slice(base_count + mid_count, total)


func _cache_rest_pose(skeleton: Skeleton3D) -> void:
	for bone_index in bone_indices:
		var rest := skeleton.get_bone_rest(bone_index)
		rest_rotations[bone_index] = rest.basis.get_rotation_quaternion()


func _compose_offset_rotation(curl_value: float, lift_value: float) -> Quaternion:
	var q_lift := Quaternion(_axis_vector(lift_axis), lift_value * lift_axis_sign)
	var q_curl := Quaternion(_axis_vector(curl_axis), curl_value * curl_axis_sign)
	return q_lift * q_curl


func _axis_vector(axis: LocalAxis) -> Vector3:
	match axis:
		LocalAxis.X:
			return Vector3.RIGHT
		LocalAxis.Y:
			return Vector3.UP
		LocalAxis.Z:
			return Vector3.FORWARD
		_:
			return Vector3.RIGHT


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


func _remap_clamped(value: float, in_min: float, in_max: float) -> float:
	if is_equal_approx(in_min, in_max):
		return 0.0
	return _saturate((value - in_min) / (in_max - in_min))
