extends Node3D
class_name OctoRig

const OctoArmType = preload("res://scripts/OctoArm.gd")
const OctoHeadType = preload("res://scripts/OctoHead.gd")

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
		"side": "left",
		"role_bias": "back",
		"bones": ["11.007", "12.007", "13.007", "14.007", "15.007", "21.007", "22.007", "23.007", "24.007", "25.007", "31.007", "32.007", "33.007", "34.007", "35.007"],
	}
}

const HEAD_BONE_NAMES: Array[String] = ["HEAD_01", "Bone.001", "Bone.002", "Bone.003"]

@export var skeleton: Skeleton3D
@export var skeleton_path: NodePath
@export var debug_print_on_ready := true
@export var print_indices_on_ready := false

var head: OctoHead
var arms: Array[OctoArm] = []

var _setup_valid := false
var _validation_errors: Array[String] = []
var _validation_warnings: Array[String] = []


func _ready() -> void:
	_setup_valid = build_rig()
	if _setup_valid and debug_print_on_ready:
		print_debug_summary()
		if print_indices_on_ready:
			print_resolved_bone_indices()
	elif not _setup_valid:
		_print_validation_failures()


func build_rig() -> bool:
	_clear_runtime_data()

	if skeleton == null:
		if skeleton_path != NodePath():
			skeleton = get_node_or_null(skeleton_path) as Skeleton3D
		if skeleton == null:
			skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		_validation_errors.append(
			"OctoRig: skeleton reference is null. Assign Skeleton3D or skeleton_path on '%s'." % name
		)
		return false

	if ARM_CONFIGS.is_empty():
		_validation_errors.append("OctoRig: ARM_CONFIGS has no entries.")
		return false

	var assignment_sources := _collect_assignment_sources()
	_validation_warnings.append_array(_detect_duplicate_assignments(assignment_sources))

	head = OctoHeadType.new() as OctoHead
	if not head.setup(skeleton, HEAD_BONE_NAMES):
		_validation_errors.append_array(head.errors)

	var arm_keys: Array = ARM_CONFIGS.keys()
	arm_keys.sort()

	for arm_i in arm_keys.size():
		var arm_key := str(arm_keys[arm_i])
		var arm_config_variant: Variant = ARM_CONFIGS[arm_key]
		if not (arm_config_variant is Dictionary):
			_validation_errors.append("Arm '%s': config must be a Dictionary." % arm_key)
			continue
		var arm_config: Dictionary = arm_config_variant
		var configured_names := _to_string_array(arm_config.get("bones", []), "Arm '%s' bones" % arm_key)
		var side := str(arm_config.get("side", "unknown"))
		var role_bias := str(arm_config.get("role_bias", "neutral"))
		var arm := OctoArmType.new() as OctoArm
		if not arm.setup(skeleton, arm_key, arm_i, configured_names, side, role_bias):
			_validation_errors.append_array(arm.errors)
		if not arm.warnings.is_empty():
			_validation_warnings.append_array(arm.warnings)
		arms.append(arm)

	if arms.is_empty():
		_validation_errors.append("OctoRig: no arms were created.")

	_setup_valid = _validation_errors.is_empty()
	return _setup_valid


func has_valid_setup() -> bool:
	return _setup_valid


func get_all_arm_bones() -> Array[int]:
	var unique := {}
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


func _clear_runtime_data() -> void:
	arms.clear()
	head = null
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


func _collect_assignment_sources() -> Dictionary:
	var sources := {}

	for bone_name in HEAD_BONE_NAMES:
		_add_assignment_source(sources, bone_name, "head")

	for arm_key in ARM_CONFIGS.keys():
		var source_label := "arm '%s'" % str(arm_key)
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


func _print_validation_failures() -> void:
	for error in _validation_errors:
		push_error(error)
	for warning in _validation_warnings:
		push_warning(warning)
