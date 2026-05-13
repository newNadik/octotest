extends Node3D

const MOBILE_OS_NAMES := ["iOS", "Android"]

@export var projector_texture: Texture2D
@export_range(64, 512, 1) var projector_resolution := 256
@export_range(8, 48, 1) var primary_point_count := 18
@export_range(8, 64, 1) var secondary_point_count := 28
@export var texture_seed := 1337
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
var _projector_texture: Texture2D


func _ready() -> void:
	_cache_lights()
	_apply_base_light_energy()
	_projector_texture = projector_texture if projector_texture != null else _generate_projector_texture()
	for light in _lights:
		light.light_projector = _projector_texture if _supports_light_projector() else null
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return
	_apply(bool(settings.call("get_god_rays_enabled")))
	settings.god_rays_enabled_changed.connect(_apply)


func _supports_light_projector() -> bool:
	return true #not OS.has_feature("mobile") and not MOBILE_OS_NAMES.has(OS.get_name())


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


func _generate_projector_texture() -> Texture2D:
	var image := Image.create(projector_resolution, projector_resolution, false, Image.FORMAT_RGBA8)
	var primary_points := _build_points(texture_seed, primary_point_count)
	var secondary_points := _build_points(texture_seed + 7919, secondary_point_count)
	for y in range(projector_resolution):
		for x in range(projector_resolution):
			var uv := Vector2(
				(float(x) + 0.5) / float(projector_resolution),
				(float(y) + 0.5) / float(projector_resolution)
			)
			var warped_uv := _warp_uv(uv)
			var layer_a := _voronoi_edge(warped_uv, primary_points)
			var layer_b := _voronoi_edge(_fract_vec2(warped_uv * 1.31 + Vector2(0.17, 0.09)), secondary_points)
			var caustic := maxf(layer_a, layer_b * 0.72)
			caustic = pow(clampf(caustic, 0.0, 1.0), 1.65)
			var center_falloff := 1.0 - smoothstep(0.38, 0.76, (uv - Vector2.ONE * 0.5).length())
			var brightness := clampf(caustic * (0.72 + center_falloff * 0.28), 0.0, 1.0)
			image.set_pixel(x, y, Color(brightness, brightness, brightness, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _build_points(seed_value: int, count: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points: Array[Vector2] = []
	points.resize(count)
	for index in range(count):
		points[index] = Vector2(rng.randf(), rng.randf())
	return points


func _voronoi_edge(sample_uv: Vector2, points: Array[Vector2]) -> float:
	var nearest := INF
	var second_nearest := INF
	for point in points:
		var delta := _wrapped_delta(sample_uv, point)
		var distance_squared := delta.length_squared()
		if distance_squared < nearest:
			second_nearest = nearest
			nearest = distance_squared
		elif distance_squared < second_nearest:
			second_nearest = distance_squared
	var edge_distance := sqrt(second_nearest) - sqrt(nearest)
	return 1.0 - smoothstep(0.028, 0.09, edge_distance)


func _warp_uv(uv: Vector2) -> Vector2:
	var tau := PI * 2.0
	var warp := Vector2(
		sin((uv.y * 6.2 + uv.x * 1.8) * tau) + cos((uv.x * 4.3 - uv.y * 2.1) * tau),
		cos((uv.x * 5.4 + uv.y * 2.6) * tau) + sin((uv.y * 7.1 - uv.x * 2.8) * tau)
	) * 0.018
	return _fract_vec2(uv + warp)


func _wrapped_delta(a: Vector2, b: Vector2) -> Vector2:
	var delta := a - b
	delta.x = fposmod(delta.x + 0.5, 1.0) - 0.5
	delta.y = fposmod(delta.y + 0.5, 1.0) - 0.5
	return delta


func _fract_vec2(value: Vector2) -> Vector2:
	return Vector2(
		fposmod(value.x, 1.0),
		fposmod(value.y, 1.0)
	)


func _apply(enabled: bool) -> void:
	visible = enabled
