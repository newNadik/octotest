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
