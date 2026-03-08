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
var rest_positions: Dictionary = {}
var rest_transforms: Dictionary = {}

var current_state: ArmState = ArmState.IDLE
var phase_offset: float = 0.0
var held_item: Node3D
var target_position: Vector3 = Vector3.ZERO
var target_node: Node3D

# Parameter-driven pose controls (radians for angle params, unitless for tip_bias).
var spread_angle: float = 0.0
var curl_amount: float = 0.0
var lift_amount: float = 0.0
var twist_amount: float = 0.0
var tip_bias: float = 0.0

# Per-parameter scales let each arm be tuned independently.
var spread_scale: float = 1.0
var curl_scale: float = 0.8
var lift_scale: float = 0.35
var twist_scale: float = 1.0
var tip_bias_scale: float = 1.0
var lift_outward_sign: float = 1.0

var target_spread_angle: float = 0.0
var target_curl_amount: float = 0.0
var target_lift_amount: float = 0.0
var target_twist_amount: float = 0.0
var target_tip_bias: float = 0.0

var param_lerp_speed: float = 8.0

enum LocalAxis {
	X,
	Y,
	Z,
}

# Axis mapping can vary per imported rig. Tune these values if motion looks incorrect.
var spread_axis: LocalAxis = LocalAxis.Y
var spread_axis_sign: float = 1.0
var curl_axis: LocalAxis = LocalAxis.X
var curl_axis_sign: float = 1.0
var lift_axis: LocalAxis = LocalAxis.Z
var lift_axis_sign: float = 1.0
var twist_axis: LocalAxis = LocalAxis.Y
var twist_axis_sign: float = 1.0

var errors: Array[String] = []
var warnings: Array[String] = []

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
	lift_outward_sign = 1.0
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
	auto_configure_lift_direction()
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


func set_target_pose_params(
	new_spread_angle: float = 0.0,
	new_curl_amount: float = 0.0,
	new_lift_amount: float = 0.0,
	new_twist_amount: float = 0.0,
	new_tip_bias: float = 0.0
) -> void:
	target_spread_angle = new_spread_angle
	target_curl_amount = new_curl_amount
	target_lift_amount = new_lift_amount
	target_twist_amount = new_twist_amount
	target_tip_bias = new_tip_bias


func set_axis_mapping(
	new_spread_axis: LocalAxis,
	new_curl_axis: LocalAxis,
	new_lift_axis: LocalAxis,
	new_twist_axis: LocalAxis,
	new_spread_sign: float = 1.0,
	new_curl_sign: float = 1.0,
	new_lift_sign: float = 1.0,
	new_twist_sign: float = 1.0
) -> void:
	spread_axis = new_spread_axis
	curl_axis = new_curl_axis
	lift_axis = new_lift_axis
	twist_axis = new_twist_axis
	spread_axis_sign = new_spread_sign
	curl_axis_sign = new_curl_sign
	lift_axis_sign = new_lift_sign
	twist_axis_sign = new_twist_sign


func set_param_scales(
	new_spread_scale: float = 1.0,
	new_curl_scale: float = 0.8,
	new_lift_scale: float = 0.35,
	new_twist_scale: float = 1.0,
	new_tip_bias_scale: float = 1.0
) -> void:
	spread_scale = new_spread_scale
	curl_scale = new_curl_scale
	lift_scale = new_lift_scale
	twist_scale = new_twist_scale
	tip_bias_scale = new_tip_bias_scale


func update_params(delta: float) -> void:
	var alpha := 1.0 - exp(-param_lerp_speed * maxf(delta, 0.0))
	spread_angle = lerp_angle(spread_angle, target_spread_angle, alpha)
	curl_amount = lerp_angle(curl_amount, target_curl_amount, alpha)
	lift_amount = lerp_angle(lift_amount, target_lift_amount, alpha)
	twist_amount = lerp_angle(twist_amount, target_twist_amount, alpha)
	tip_bias = lerpf(tip_bias, target_tip_bias, alpha)


func snap_to_target_params() -> void:
	spread_angle = target_spread_angle
	curl_amount = target_curl_amount
	lift_amount = target_lift_amount
	twist_amount = target_twist_amount
	tip_bias = target_tip_bias


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
		var t := compute_bone_t(i, total_count)
		var spread_value := spread_angle * spread_scale * get_spread_weight(t)
		var curl_value := curl_amount * curl_scale * get_curl_weight(t)
		var lift_weight := get_lift_weight(t)
		var lift_raw := lift_amount * lift_scale * lift_weight
		var lift_value := 0.0
		var twist_value := twist_amount * twist_scale * get_twist_weight(t)
		var tip_value := tip_bias * tip_bias_scale * get_tip_weight(t)

		# Lift opens/closes in the curl plane to move tips away/toward center without yaw tilt.
		curl_value += lift_raw * lift_outward_sign

		# tip_bias should feel like tip curl/softness, not automatic sideways turn.
		curl_value += tip_value * 0.65

		var procedural_offset := _compose_offset_rotation(
			spread_value,
			curl_value,
			lift_value,
			twist_value
		)
		var rest_rotation: Quaternion = rest_rotations[bone_index]
		var final_rotation := rest_rotation * procedural_offset
		skeleton.set_bone_pose_rotation(bone_index, final_rotation)


func compute_bone_t(index: int, total_count: int) -> float:
	if total_count <= 1:
		return 0.0
	return float(index) / float(total_count - 1)


func get_spread_weight(t: float) -> float:
	# Strong at base, fades toward tip.
	return pow(1.0 - _saturate(t), 1.5)


func get_curl_weight(t: float) -> float:
	# Keep base stable; build curl through mid/tip.
	return lerpf(0.35, 1.1, _smoothstep01(t))


func get_lift_weight(t: float) -> float:
	# Mainly base movement with strong attenuation toward tip to avoid over-arching.
	return pow(1.0 - _smoothstep(0.2, 0.85, t), 2.0)


func get_twist_weight(t: float) -> float:
	# Gradually increases toward tip.
	return _smoothstep01(t)


func get_tip_weight(t: float) -> float:
	# Concentrated in final third.
	return _smoothstep(0.66, 1.0, t)


func _clear_data() -> void:
	bone_names.clear()
	bone_indices.clear()
	base_bones.clear()
	mid_bones.clear()
	tip_bones.clear()
	rest_rotations.clear()
	rest_positions.clear()
	rest_transforms.clear()
	errors.clear()
	warnings.clear()
	set_target_pose_params()
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
		rest_transforms[bone_index] = rest
		rest_positions[bone_index] = rest.origin
		rest_rotations[bone_index] = rest.basis.get_rotation_quaternion()


func auto_configure_lift_direction(sample_angle: float = 0.22) -> void:
	if bone_indices.size() < 2:
		return
	var base_index := bone_indices[0]
	var tip_index := bone_indices[bone_indices.size() - 1]
	if not rest_transforms.has(base_index) or not rest_transforms.has(tip_index):
		return

	var base_rest: Transform3D = rest_transforms[base_index]
	var tip_rest: Transform3D = rest_transforms[tip_index]
	var base_pos := base_rest.origin
	var tip_pos := tip_rest.origin
	var arm_vector := tip_pos - base_pos
	if arm_vector.length() <= 0.0001:
		return

	var curl_axis_world := (base_rest.basis * _axis_vector(curl_axis)).normalized()
	if curl_axis_world.length() <= 0.0001:
		return

	var tip_plus := base_pos + arm_vector.rotated(curl_axis_world, sample_angle)
	var tip_minus := base_pos + arm_vector.rotated(curl_axis_world, -sample_angle)
	var plus_distance_sq := tip_plus.length_squared()
	var minus_distance_sq := tip_minus.length_squared()
	lift_outward_sign = 1.0 if plus_distance_sq >= minus_distance_sq else -1.0


func _compose_offset_rotation(
	spread_value: float,
	curl_value: float,
	lift_value: float,
	twist_value: float
) -> Quaternion:
	var q_spread := Quaternion(_axis_vector(spread_axis), spread_value * spread_axis_sign)
	var q_lift := Quaternion(_axis_vector(lift_axis), lift_value * lift_axis_sign)
	var q_curl := Quaternion(_axis_vector(curl_axis), curl_value * curl_axis_sign)
	var q_twist := Quaternion(_axis_vector(twist_axis), twist_value * twist_axis_sign)
	return q_spread * q_lift * q_curl * q_twist


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
