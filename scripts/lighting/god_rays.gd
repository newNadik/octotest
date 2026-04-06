extends Node3D

const MOBILE_OS_NAMES := ["iOS", "Android"]

@export var sway_speed := 1.25
@export var sway_pitch_degrees := 1.8
@export var sway_yaw_degrees := 3.1
@export var energy_pulse_strength := 0.45
@export var volumetric_pulse_strength := 0.55

var _time := 0.0
var _ray_lights: Array[SpotLight3D] = []
var _base_rotations: Dictionary = {}
var _base_energy: Dictionary = {}
var _base_volumetric_energy: Dictionary = {}
var master_pulse_normalized := 0.0
var master_pulse_01 := 0.5


func _ready() -> void:
	_cache_ray_lights()
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return
	_apply(bool(settings.call("get_god_rays_enabled")))
	settings.god_rays_enabled_changed.connect(_apply)


func _process(delta: float) -> void:
	if not visible or _ray_lights.is_empty():
		return

	_time += delta * maxf(sway_speed, 0.0)
	var main_wave := sin(_time * 1.83)
	var secondary_wave := sin(_time * 0.94 + 1.5)
	var pulse_mix := main_wave * energy_pulse_strength + secondary_wave * 0.05
	var pulse_denom := maxf(energy_pulse_strength + 0.05, 0.001)
	master_pulse_normalized = clampf(pulse_mix / pulse_denom, -1.0, 1.0)
	master_pulse_01 = 0.5 + 0.5 * master_pulse_normalized
	for i in _ray_lights.size():
		var light := _ray_lights[i]
		if light == null:
			continue
		var base_rotation: Vector3 = _base_rotations.get(light, light.rotation_degrees)
		var base_light_energy: float = _base_energy.get(light, light.light_energy)
		var base_volumetric_energy: float = _base_volumetric_energy.get(light, light.light_volumetric_fog_energy)
		var phase := _time + float(i) * 1.37
		var sway_pitch := sin(phase) * sway_pitch_degrees
		var sway_yaw := sin(phase * 0.73 + 0.8) * sway_yaw_degrees
		var pulse := 1.0 + sin(phase * 1.83) * energy_pulse_strength + sin(phase * 0.94 + 1.5) * 0.05
		var volumetric_pulse := 1.0 + sin(phase * 1.46 + 0.5) * volumetric_pulse_strength
		light.rotation_degrees = Vector3(
			base_rotation.x + sway_pitch,
			base_rotation.y + sway_yaw,
			base_rotation.z
		)
		light.light_energy = maxf(0.0, base_light_energy * pulse)
		light.light_volumetric_fog_energy = maxf(0.0, base_volumetric_energy * volumetric_pulse)


func _cache_ray_lights() -> void:
	_ray_lights.clear()
	_base_rotations.clear()
	_base_energy.clear()
	_base_volumetric_energy.clear()
	for child in get_children():
		if child is SpotLight3D:
			var light := child as SpotLight3D
			_ray_lights.append(light)
			_base_rotations[light] = light.rotation_degrees
			_base_energy[light] = light.light_energy
			_base_volumetric_energy[light] = light.light_volumetric_fog_energy


func _apply(enabled: bool) -> void:
	visible = enabled
	var world := get_world_3d()
	if world != null and world.environment != null:
		if _should_control_volumetric_fog():
			world.environment.volumetric_fog_enabled = enabled


func _should_control_volumetric_fog() -> bool:
	return not OS.has_feature("mobile") and not MOBILE_OS_NAMES.has(OS.get_name())
