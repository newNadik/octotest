extends Node3D
class_name FocusTarget


@export var focus_anchor_path: NodePath = NodePath(".")
@export var click_outside_exit_px := 240.0
@export var auto_exit_on_solved := true
@export var solved_method_name := ""
@export var use_angle_override := false
@export var focus_yaw_degrees := 0.0
@export var focus_pitch_degrees := -22.0


func get_focus_position() -> Vector3:
	var anchor := get_node_or_null(focus_anchor_path) as Node3D
	if anchor != null:
		return anchor.global_position
	return global_position


func is_solved() -> bool:
	if solved_method_name.is_empty():
		return false
	var host := get_parent()
	if host != null and host.has_method(solved_method_name):
		return bool(host.call(solved_method_name))
	return false


func get_focus_yaw_degrees(default_yaw: float) -> float:
	if use_angle_override:
		return focus_yaw_degrees
	return default_yaw


func get_focus_pitch_degrees(default_pitch: float) -> float:
	if use_angle_override:
		return focus_pitch_degrees
	return default_pitch
