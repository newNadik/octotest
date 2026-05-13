extends Node3D

@export_range(0.0, 64.0, 0.1) var light_energy := 20.0:
	set(value):
		light_energy = maxf(0.0, value)
		_apply_base_light_energy()
@export var rotation_speed_a_degrees := 9.0
@export var rotation_speed_b_degrees := -13.0
@export var energy_pulse_speed := 0.75
@export var energy_pulse_strength := 0.12

var _time := 0.0
var _lights: Array[SpotLight3D] = []
var _base_rotations: Dictionary = {}
var _base_energy: Dictionary = {}


func _ready() -> void:
	_cache_lights()
	_make_projectors_runtime_unique()
	_apply_base_light_energy()
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return
	_apply(bool(settings.call("get_god_rays_enabled")))
	settings.god_rays_enabled_changed.connect(_apply)


func _process(delta: float) -> void:
	if not visible or _lights.is_empty():
		return

	_time += delta
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
		light.light_energy = maxf(0.0, base_energy * pulse)


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


func _make_projectors_runtime_unique() -> void:
	for light in _lights:
		if light == null or light.light_projector == null:
			continue
		var source_image := light.light_projector.get_image()
		if source_image == null or source_image.is_empty():
			continue
		light.light_projector = ImageTexture.create_from_image(source_image.duplicate())


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


func _apply(enabled: bool) -> void:
	visible = enabled
