extends Node3D

@export var sway_enabled := true
@export var sway_speed := 0.22
@export var rig_pitch_amplitude := 1.2
@export var rig_yaw_amplitude := 2.2
@export var ray_pitch_amplitude := 2.4
@export var ray_yaw_amplitude := 3.6
@export var camera_angle_fade_enabled := true
@export var axis_dot_fade_start := 0.6
@export var axis_dot_fade_end := 0.9
@export var near_distance_start := 0.8
@export var near_distance_end := 3.0
@export var min_visibility := 0.28
@export var max_extra_transparency := 0.78

var _time := 0.0
var _base_rotation := Vector3.ZERO
var _rays: Array[MeshInstance3D] = []
var _ray_base_rotation_by_path: Dictionary = {}
# cross quads are children of each ray — keyed by ray NodePath
var _cross_quads: Dictionary = {}


func _ready() -> void:
	_base_rotation = rotation_degrees
	_collect_rays()


func _physics_process(delta: float) -> void:
	if sway_enabled:
		_time += delta * maxf(sway_speed, 0.0)
		var sway_a := sin(_time)
		var sway_b := sin(_time * 0.67 + 1.2)
		rotation_degrees = Vector3(
			_base_rotation.x + sway_a * rig_pitch_amplitude,
			_base_rotation.y + sway_b * rig_yaw_amplitude,
			_base_rotation.z
		)
		for index in range(_rays.size()):
			var ray := _rays[index]
			if ray == null or not is_instance_valid(ray):
				continue
			var ray_path := ray.get_path()
			if not _ray_base_rotation_by_path.has(ray_path):
				_ray_base_rotation_by_path[ray_path] = ray.rotation_degrees
			var base_ray_rotation: Vector3 = _ray_base_rotation_by_path[ray_path]
			var phase := float(index) * 0.63
			ray.rotation_degrees = Vector3(
				base_ray_rotation.x + sin(_time * 0.93 + phase) * ray_pitch_amplitude,
				base_ray_rotation.y + sin(_time * 0.57 + 0.8 + phase) * ray_yaw_amplitude,
				base_ray_rotation.z
			)

	if camera_angle_fade_enabled:
		_apply_camera_angle_fade()
	else:
		_restore_base_transparency()


func _collect_rays() -> void:
	for crosses in _cross_quads.values():
		for cq in crosses:
			if is_instance_valid(cq):
				cq.queue_free()
	_cross_quads.clear()
	_rays.clear()
	_ray_base_rotation_by_path.clear()

	for ray_node in find_children("Ray*", "MeshInstance3D", true, false):
		var ray := ray_node as MeshInstance3D
		if ray != null:
			_rays.append(ray)
	if _rays.is_empty():
		for mesh_node in find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_node as MeshInstance3D
			if mesh != null:
				_rays.append(mesh)

	for ray in _rays:
		if ray == null or not is_instance_valid(ray):
			continue
		ray.set_instance_shader_parameter("camera_fade", 1.0)
		var crosses: Array[MeshInstance3D] = []
		for angle_deg in [60.0, 120.0]:
			var cross := MeshInstance3D.new()
			cross.mesh = ray.mesh
			cross.material_override = ray.material_override
			cross.cast_shadow = ray.cast_shadow
			ray.add_child(cross)
			cross.rotation_degrees = Vector3(0.0, angle_deg, 0.0)
			cross.set_instance_shader_parameter("camera_fade", 1.0)
			crosses.append(cross)
		_cross_quads[ray.get_path()] = crosses


func _apply_camera_angle_fade() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for ray in _rays:
		if ray == null or not is_instance_valid(ray):
			continue
		var to_camera: Vector3 = camera.global_position - ray.global_position
		var camera_distance: float = to_camera.length()
		var visibility: float
		if camera_distance < 0.001:
			visibility = min_visibility
		else:
			var camera_forward: Vector3 = (-camera.global_transform.basis.z).normalized()
			var ray_forward: Vector3 = ray.global_transform.basis.y.normalized()
			var axis_dot: float = absf(camera_forward.dot(ray_forward))
			var angle_visibility: float = 1.0 - smoothstep(axis_dot_fade_start, axis_dot_fade_end, axis_dot)
			var near_visibility: float = smoothstep(near_distance_start, near_distance_end, camera_distance)
			visibility = clampf(angle_visibility * near_visibility, min_visibility, 1.0)
		ray.set_instance_shader_parameter("camera_fade", visibility)
		var ray_path := ray.get_path()
		if _cross_quads.has(ray_path):
			for cross in _cross_quads[ray_path]:
				if is_instance_valid(cross):
					cross.set_instance_shader_parameter("camera_fade", visibility)


func _restore_base_transparency() -> void:
	for ray in _rays:
		if ray == null or not is_instance_valid(ray):
			continue
		ray.set_instance_shader_parameter("camera_fade", 1.0)
		var ray_path := ray.get_path()
		if _cross_quads.has(ray_path):
			for cross in _cross_quads[ray_path]:
				if is_instance_valid(cross):
					cross.set_instance_shader_parameter("camera_fade", 1.0)
