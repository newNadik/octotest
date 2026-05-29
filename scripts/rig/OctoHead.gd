extends RefCounted
class_name OctoHead

var bone_names: Array[String] = []
var bone_indices: Array[int] = []

var base_bones: Array[int] = []
var mid_bones: Array[int] = []
var tip_bones: Array[int] = []

var rest_rotations: Dictionary = {}
var rest_positions: Dictionary = {}
var rest_transforms: Dictionary = {}

var errors: Array[String] = []

var base_bone: int:
	get:
		if base_bones.is_empty():
			return -1
		return base_bones[0]

var middle_bone: int:
	get:
		if bone_indices.is_empty():
			return -1
		return bone_indices[int(bone_indices.size() / 2.0)]

var tip_bone: int:
	get:
		if tip_bones.is_empty():
			return -1
		return tip_bones[tip_bones.size() - 1]


func setup(skeleton: Skeleton3D, configured_bone_names: Array[String]) -> bool:
	_clear_data()
	bone_names = configured_bone_names.duplicate()

	if skeleton == null:
		errors.append("Head: skeleton is null.")
		return false

	if bone_names.is_empty():
		errors.append("Head: no bones configured.")
		return false

	for bone_name in bone_names:
		var bone_index := skeleton.find_bone(StringName(bone_name))
		if bone_index < 0:
			errors.append("Head: bone '%s' was not found in skeleton." % bone_name)
			continue
		bone_indices.append(bone_index)

	if not errors.is_empty():
		return false

	_split_chain_into_parts()
	_cache_rest_pose(skeleton)
	return true


func has_valid_setup() -> bool:
	return errors.is_empty() and not bone_indices.is_empty()


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


func _split_chain_into_parts() -> void:
	var total := bone_indices.size()
	if total <= 0:
		return

	var base_count := int(total / 3.0)
	var mid_count := int(total / 3.0)
	var tip_count := int(total / 3.0)

	match total % 3:
		1:
			base_count += 1
		2:
			base_count += 1
			mid_count += 1
		_:
			pass

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
