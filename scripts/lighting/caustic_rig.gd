extends Node3D

@export_range(0.0, 64.0, 0.1) var light_energy := 20.0:
	set(value):
		light_energy = maxf(0.0, value)
		_apply_base_light_energy()
@export var rotation_speed_a_degrees := 9.0
@export var rotation_speed_b_degrees := -13.0
@export var energy_pulse_speed := 0.75
@export var energy_pulse_strength := 0.12
@export_range(0.0, 100.0, 0.5) var fade_begin_distance := 12.0
@export_range(0.0, 100.0, 0.5) var fade_end_distance := 18.0

var _time := 0.0
var _lights: Array[SpotLight3D] = []
var _base_rotations: Dictionary = {}
var _base_energy: Dictionary = {}


var _frame_skip := false


func _ready() -> void:
	if OS.has_feature("mobile"):
		var settings := get_node_or_null("/root/GameSettings")
		if settings != null:
			visible = bool(settings.call("get_shadows_enabled"))
			settings.shadows_enabled_changed.connect(func(enabled: bool) -> void: visible = enabled)
		else:
			visible = false
		return
	_cache_lights()
	_apply_base_light_energy()


func _process(delta: float) -> void:
	if not visible or _lights.is_empty():
		return
	_frame_skip = not _frame_skip
	if _frame_skip:
		return

	_time += delta
	var distance_scale := _get_distance_scale()
	var rotation_offsets := PackedFloat32Array([
		_time * rotation_speed_a_degrees,
		_time * rotation_speed_b_degrees
	])
	for index in range(_lights.size()):
		var light := _lights[index]
		if light == null:
			continue
		var base_rotation: Vector3 = _base_rotations.get(light, light.rotation_degrees)
		var base_energy: float = _base_energy.get(light, light.light_energy)
		var phase := _time * energy_pulse_speed + float(index) * 1.6
		var pulse := 1.0 + sin(phase) * energy_pulse_strength + sin(phase * 1.91 + 0.8) * 0.04
		var rotation_offset: float = rotation_offsets[min(index, rotation_offsets.size() - 1)]
		light.rotation_degrees = Vector3(
			base_rotation.x,
			base_rotation.y,
			base_rotation.z + rotation_offset
		)
		light.light_energy = maxf(0.0, base_energy * pulse * distance_scale)


func _get_distance_scale() -> float:
	if fade_end_distance <= fade_begin_distance:
		return 1.0
	var viewport := get_viewport()
	if viewport == null:
		return 1.0
	var camera := viewport.get_camera_3d()
	if camera == null:
		return 1.0
	var dist := global_position.distance_to(camera.global_position)
	return 1.0 - clampf((dist - fade_begin_distance) / (fade_end_distance - fade_begin_distance), 0.0, 1.0)


func _cache_lights() -> void:
	_lights.clear()
	_base_rotations.clear()
	_base_energy.clear()
	for child in get_children():
		if child is SpotLight3D:
			var light := child as SpotLight3D
			_lights.append(light)
			_base_rotations[light] = light.rotation_degrees
			_base_energy[light] = light.light_energy


func _apply_base_light_energy() -> void:
	var target_lights: Array[SpotLight3D] = _lights
	if target_lights.is_empty():
		target_lights = []
		for child in get_children():
			if child is SpotLight3D:
				target_lights.append(child as SpotLight3D)

	for light in target_lights:
		if light == null:
			continue
		_base_energy[light] = light_energy
		light.light_energy = light_energy
