extends Node3D

@export_node_path("Skeleton3D") var skeleton_path: NodePath = NodePath(
	"clock_fbx_1/RootNode_2/Rotation_system_3/Object_4_4/GLTF_created_0/Skeleton3D"
)

@export_group("Bone Names")
@export var hour_bone_name := "hour_hand_04_13"
@export var minute_bone_name := "minute_hand_02_9"
@export var second_bone_name := "second_hand_03_11"

@export_group("Clock Motion")
@export var sync_to_system_time := true
@export var show_second_hand := true
@export var smooth_second_hand := false
@export var rotation_axis := Vector3.RIGHT
@export_range(-1.0, 1.0, 1.0) var direction_sign := -1.0
@export var update_when_paused := true

@export_group("Hand Offsets (Degrees)")
@export var hour_offset_degrees := 0.0
@export var minute_offset_degrees := 0.0
@export var second_offset_degrees := 0.0

var _skeleton: Skeleton3D
var _hour_bone := -1
var _minute_bone := -1
var _second_bone := -1

var _hour_rest := Quaternion.IDENTITY
var _minute_rest := Quaternion.IDENTITY
var _second_rest := Quaternion.IDENTITY


func _ready() -> void:
	_resolve_skeleton_and_bones()
	process_mode = Node.PROCESS_MODE_ALWAYS if update_when_paused else Node.PROCESS_MODE_INHERIT
	set_process(true)
	_update_hands()


func _process(_delta: float) -> void:
	if _skeleton == null or _hour_bone < 0 or _minute_bone < 0 or _second_bone < 0:
		_resolve_skeleton_and_bones()
		if _skeleton == null:
			return

	if not sync_to_system_time:
		return
	_update_hands()


func _resolve_skeleton_and_bones() -> void:
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		_skeleton = _find_skeleton_fallback()
	if _skeleton == null:
		push_warning("Clock: Skeleton3D not found at path '%s'." % str(skeleton_path))
		return

	_hour_bone = _skeleton.find_bone(hour_bone_name)
	_minute_bone = _skeleton.find_bone(minute_bone_name)
	_second_bone = _skeleton.find_bone(second_bone_name)

	if _hour_bone < 0 or _minute_bone < 0 or _second_bone < 0:
		push_warning(
			"Clock: missing hand bone(s). hour='%s' minute='%s' second='%s'." % [
				hour_bone_name,
				minute_bone_name,
				second_bone_name,
			]
		)
		_skeleton = null
		return

	_hour_rest = _skeleton.get_bone_rest(_hour_bone).basis.get_rotation_quaternion()
	_minute_rest = _skeleton.get_bone_rest(_minute_bone).basis.get_rotation_quaternion()
	_second_rest = _skeleton.get_bone_rest(_second_bone).basis.get_rotation_quaternion()


func _update_hands() -> void:
	if _skeleton == null:
		return

	var hour_24 := 0
	var minute := 0
	var second_value := 0.0
	var game_time_now := _get_game_time_clock()
	if not game_time_now.is_empty():
		hour_24 = int(game_time_now.get("hour", 0))
		minute = int(game_time_now.get("minute", 0))
		second_value = float(game_time_now.get("second", 0.0))
		if not smooth_second_hand:
			second_value = float(int(floor(second_value)))
	else:
		var now: Dictionary = Time.get_datetime_dict_from_system()
		hour_24 = int(now.get("hour", 0))
		minute = int(now.get("minute", 0))
		second_value = float(now.get("second", 0))
		if smooth_second_hand:
			second_value += _fractional_second_from_unix_time()

	var second_angle := TAU * (second_value / 60.0)
	var minute_angle := TAU * ((float(minute) + (second_value / 60.0)) / 60.0)
	var hour_angle := TAU * ((float(hour_24 % 12) + (float(minute) / 60.0) + (second_value / 3600.0)) / 12.0)

	_apply_bone_angle(_hour_bone, _hour_rest, hour_angle, deg_to_rad(hour_offset_degrees))
	_apply_bone_angle(_minute_bone, _minute_rest, minute_angle, deg_to_rad(minute_offset_degrees))

	if show_second_hand:
		_apply_bone_angle(_second_bone, _second_rest, second_angle, deg_to_rad(second_offset_degrees))

	if _skeleton.has_method("force_update_all_bone_transforms"):
		_skeleton.call("force_update_all_bone_transforms")


func _apply_bone_angle(bone_idx: int, rest_rotation: Quaternion, angle_rad: float, angle_offset: float) -> void:
	var axis := rotation_axis.normalized()
	if axis.is_zero_approx():
		axis = Vector3.RIGHT
	var q := Quaternion(axis, direction_sign * angle_rad + angle_offset)
	_skeleton.set_bone_pose_rotation(bone_idx, rest_rotation * q)


func _fractional_second_from_unix_time() -> float:
	var unix_time = Time.get_unix_time_from_system()
	return fposmod(float(unix_time), 1.0)


func _get_game_time_clock() -> Dictionary:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return {}
	var game_time := tree.root.get_node_or_null("GameTime")
	if game_time == null:
		return {}
	var now = game_time.call("get_clock_time")
	if now is Dictionary:
		return now as Dictionary
	return {}


func _find_skeleton_fallback() -> Skeleton3D:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			var child_node := child as Node
			if child_node == null:
				continue
			if child_node is Skeleton3D:
				var skel := child_node as Skeleton3D
				if skel.find_bone(hour_bone_name) >= 0 and skel.find_bone(minute_bone_name) >= 0 and skel.find_bone(second_bone_name) >= 0:
					return skel
			stack.push_back(child_node)
	return null
