@tool
extends Node3D

const Utils = preload("res://scripts/station/fish_school_utils.gd")

@export_group("Fish Sources")
@export var randomize_models_from_folder := true
@export_dir var fish_models_folder := "res://assets/models/fish"
@export var fish_scene_pool: Array[PackedScene] = []

@export_group("School Composition")
@export var species_per_school_min := 1
@export var species_per_school_max := 2
@export var randomize_count := true
@export var fish_count_min := 12
@export var fish_count_max := 36
@export var fish_count := 24
@export var school_cluster_radius := 2.8
@export var max_distance_from_cluster := 4.5
@export var cluster_pull_strength := 1.9

@export_group("School Timing")
@export var delay_between_schools_min := 1.5
@export var delay_between_schools_max := 5.0

@export_group("Movement")
@export_enum("Two-Way", "Four-Way XZ", "Fixed Direction") var direction_mode := 0
@export var flow_direction := Vector3(0.0, 0.0, 1.0)
@export var randomize_direction := true
@export var allow_reverse_direction := true
@export var direction_variation_degrees := 15.0
@export var speed_min := 0.9
@export var speed_max := 1.8
@export var randomize_school_speed_scale := true
@export var school_speed_scale_min := 0.85
@export var school_speed_scale_max := 1.4
@export var turn_strength := 3.2
@export var bob_amplitude := 0.14
@export var bob_speed := 1.2

@export_group("Schooling Forces")
@export var flow_strength := 2.4
@export var cohesion_strength := 0.55
@export var alignment_strength := 0.75
@export var separation_strength := 1.2
@export var noise_strength := 0.03
@export var neighbor_radius := 3.0
@export var separation_radius := 1.2
@export var min_forward_dot := 0.45

@export_group("Volume")
@export var show_volume_preview_in_editor := true
@export var use_swim_volume := true
@export_node_path("CollisionShape3D") var swim_volume_shape_path: NodePath
@export var school_center := Vector3.ZERO
@export var school_bounds := Vector3(14.0, 4.0, 12.0)
@export var stream_spawn_outside_distance := 3.0
@export var stream_recycle_front_distance := 2.0

@export_group("Rendering")
@export var cast_shadows := true
@export var mesh_rotation_offset_degrees := Vector3.ZERO
@export var animation_speed_min := 0.85
@export var animation_speed_max := 1.25

@export_group("Platform")
@export var disable_on_mobile := true

@onready var fish_root: Node3D = $FishRoot
@onready var volume_preview: MeshInstance3D = $VolumePreview

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _school_speed_scale := 1.0
var _cluster_center := Vector3.ZERO
var _current_flow := Vector3.FORWARD
var _school_anchor_speed := 1.0
var _travel_axis := 2
var _travel_sign := 1.0
var _next_school_timer := 0.0
var _school_active := false

var _fish_nodes: Array[Node3D] = []
var _positions: Array[Vector3] = []
var _dirs: Array[Vector3] = []
var _speeds: Array[float] = []
var _phases: Array[float] = []
var _steers: Array[Vector3] = []
var _active_species: Array[PackedScene] = []
var _mesh_offset_basis := Basis.IDENTITY
var _flock_frame := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_editor_preview()
		set_process(true)
		return
	if _should_disable_for_platform():
		queue_free()
		return
	if volume_preview != null:
		volume_preview.visible = false
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return

	_rng.randomize()
	if use_swim_volume:
		_apply_swim_volume_overrides()
	if randomize_models_from_folder:
		fish_scene_pool = _collect_scene_pool(fish_models_folder)
	_schedule_next_school(0.2)
	var _screen_enabler := VisibleOnScreenEnabler3D.new()
	_screen_enabler.aabb = AABB(school_center - school_bounds * 0.5, school_bounds)
	add_child(_screen_enabler)


func _should_disable_for_platform() -> bool:
	if disable_on_mobile and OS.has_feature("mobile"):
		return true
	return false


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_editor_preview()
		return

	_time += maxf(delta, 0.0)
	if _school_active:
		_step_school(delta)
		if _is_school_finished():
			_clear_school()
			_schedule_next_school(_random_school_delay())
	else:
		_next_school_timer -= maxf(delta, 0.0)
		if _next_school_timer <= 0.0:
			_spawn_school()


func _spawn_school() -> void:
	_clear_school()

	_active_species = Utils.pick_school_species(_rng, fish_scene_pool, species_per_school_min, species_per_school_max)
	if randomize_count:
		fish_count = _rng.randi_range(maxi(fish_count_min, 0), maxi(fish_count_max, fish_count_min))

	_school_speed_scale = 1.0
	if randomize_school_speed_scale:
		_school_speed_scale = Utils.random_range(_rng, school_speed_scale_min, school_speed_scale_max)

	_current_flow = Utils.pick_school_flow(_rng, direction_mode, flow_direction, randomize_direction, allow_reverse_direction)
	_current_flow = Utils.apply_direction_variation(_rng, _current_flow, direction_variation_degrees)
	_assign_travel_axis_from_flow()

	var count := maxi(fish_count, 0)
	if count == 0:
		_schedule_next_school(_random_school_delay())
		return

	_fish_nodes.resize(count)
	_positions.resize(count)
	_dirs.resize(count)
	_speeds.resize(count)
	_phases.resize(count)
	_steers.resize(count)
	_flock_frame = 0

	var half := school_bounds * 0.5
	_mesh_offset_basis = Basis.from_euler(mesh_rotation_offset_degrees * (PI / 180.0))
	var mesh_offset_basis := _mesh_offset_basis
	_cluster_center = school_center + Vector3(
		_rng.randf_range(-half.x * 0.35, half.x * 0.35),
		_rng.randf_range(-half.y * 0.35, half.y * 0.35),
		_rng.randf_range(-half.z * 0.35, half.z * 0.35)
	)
	var spawn_axis := (-_travel_half_extent(half) - maxf(stream_spawn_outside_distance, 0.0)) if _travel_sign > 0.0 else (_travel_half_extent(half) + maxf(stream_spawn_outside_distance, 0.0))
	# Keep initial school spawn clearly outside the volume on the travel axis.
	spawn_axis += _rng.randf_range(-0.35, 0.35)
	if _travel_axis == 0:
		_cluster_center.x = school_center.x + spawn_axis
	else:
		_cluster_center.z = school_center.z + spawn_axis
	_school_anchor_speed = Utils.random_range(_rng, speed_min, speed_max) * _school_speed_scale

	for i in count:
		var carrier := Node3D.new()
		carrier.name = "Fish_%03d" % i
		fish_root.add_child(carrier)
		_attach_fish_visual(carrier)
		_set_shadow_recursive(
			carrier,
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		_play_animation_recursive(carrier)

		var radial := Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-0.6, 0.6),
			_rng.randf_range(-1.0, 1.0)
		).normalized() * _rng.randf_range(0.1, school_cluster_radius)
		# Prevent part of a school popping in inside the volume at spawn.
		if _travel_axis == 0:
			radial.x = 0.0
		else:
			radial.z = 0.0
		var pos := _cluster_center + radial
		var random_dir := Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-0.2, 0.2),
			_rng.randf_range(-1.0, 1.0)
		).normalized()
		var dir := _current_flow.slerp(random_dir if not random_dir.is_zero_approx() else _current_flow, 0.2).normalized()
		_positions[i] = pos
		_dirs[i] = dir
		_speeds[i] = Utils.random_range(_rng, speed_min, speed_max) * _school_speed_scale
		_phases[i] = _rng.randf_range(0.0, TAU)
		carrier.transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * mesh_offset_basis, pos)
		_fish_nodes[i] = carrier
	_school_active = true


func _step_school(delta: float) -> void:
	if _fish_nodes.is_empty():
		return

	var half := school_bounds * 0.5
	var flow := _current_flow
	_cluster_center += flow * _school_anchor_speed * maxf(delta, 0.0)

	# Flocking forces (O(n²)) run every 3rd frame — direction changes are gradual.
	_flock_frame = (_flock_frame + 1) % 3
	if _flock_frame == 0:
		var nr_sq := neighbor_radius * neighbor_radius
		var sr_sq := separation_radius * separation_radius
		var edge_x := half.x * 0.9
		var edge_y := half.y * 0.9
		var edge_z := half.z * 0.9
		for i in _fish_nodes.size():
			var pos := _positions[i]
			var center_sum := Vector3.ZERO
			var alignment_sum := Vector3.ZERO
			var separation_sum := Vector3.ZERO
			var neighbors := 0

			for j in _positions.size():
				if i == j:
					continue
				var to_other := _positions[j] - pos
				var dist_sq := to_other.length_squared()
				if dist_sq > nr_sq:
					continue
				neighbors += 1
				center_sum += _positions[j]
				alignment_sum += _dirs[j]
				if dist_sq < sr_sq:
					separation_sum -= to_other / maxf(dist_sq, 0.001)

			var steer := flow * flow_strength
			var cluster_pull := (_cluster_center - pos)
			if not cluster_pull.is_zero_approx():
				steer += cluster_pull.normalized() * cluster_pull_strength
			if neighbors > 0:
				var inv_n := 1.0 / float(neighbors)
				var cohesion_vec := (center_sum * inv_n) - pos
				if not cohesion_vec.is_zero_approx():
					steer += cohesion_vec.normalized() * cohesion_strength
				var alignment_vec := alignment_sum * inv_n
				if not alignment_vec.is_zero_approx():
					steer += alignment_vec.normalized() * alignment_strength
				if not separation_sum.is_zero_approx():
					steer += separation_sum.normalized() * separation_strength

			var local := pos - school_center
			var containment := Vector3.ZERO
			if absf(local.x) > edge_x:
				containment.x = -sign(local.x)
			if absf(local.y) > edge_y:
				containment.y = -sign(local.y)
			if absf(local.z) > edge_z:
				containment.z = -sign(local.z)
			if _travel_axis == 0:
				containment.x = 0.0
			else:
				containment.z = 0.0
			if not containment.is_zero_approx():
				steer += containment.normalized() * flow_strength

			var wander := Vector3(
				_rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-0.25, 0.25),
				_rng.randf_range(-1.0, 1.0)
			).normalized() * noise_strength
			steer += wander
			_steers[i] = steer

	# Movement and transform update every frame.
	for i in _fish_nodes.size():
		var pos := _positions[i]
		var dir := _dirs[i]

		var target_dir := (dir + _steers[i] * maxf(delta, 0.0)).normalized()
		var blend := clampf(turn_strength * maxf(delta, 0.0), 0.0, 1.0)
		dir = dir.slerp(target_dir, blend).normalized()
		var forward_dot := dir.dot(flow)
		if forward_dot < min_forward_dot:
			dir = dir.slerp(flow, clampf((min_forward_dot - forward_dot), 0.0, 1.0)).normalized()
		if dir.is_zero_approx():
			dir = flow
		_dirs[i] = dir

		pos += dir * _speeds[i] * maxf(delta, 0.0)
		var local := pos - school_center
		if _travel_axis != 0:
			if local.x > half.x:
				local.x = half.x
				_dirs[i].x = -absf(_dirs[i].x)
			elif local.x < -half.x:
				local.x = -half.x
				_dirs[i].x = absf(_dirs[i].x)
		if local.y > half.y:
			local.y = half.y
			_dirs[i].y = -absf(_dirs[i].y)
		elif local.y < -half.y:
			local.y = -half.y
			_dirs[i].y = absf(_dirs[i].y)
		if _travel_axis != 2:
			if local.z > half.z:
				local.z = half.z
				_dirs[i].z = -absf(_dirs[i].z)
			elif local.z < -half.z:
				local.z = -half.z
				_dirs[i].z = absf(_dirs[i].z)

		# Keep fish packed around the moving school anchor.
		var to_cluster := (school_center + local) - _cluster_center
		var dist_to_cluster := to_cluster.length()
		if dist_to_cluster > maxf(max_distance_from_cluster, 0.1):
			var clamped := to_cluster.normalized() * max_distance_from_cluster
			var clamped_world := _cluster_center + clamped
			local = clamped_world - school_center
			_dirs[i] = _dirs[i].slerp(_current_flow, 0.35).normalized()

		pos = school_center + local
		_positions[i] = pos

		var bob := sin(_time * bob_speed + _phases[i]) * bob_amplitude
		var draw_pos := pos + Vector3(0.0, bob, 0.0)
		var basis := Basis.looking_at(_dirs[i], Vector3.UP) * _mesh_offset_basis
		_fish_nodes[i].transform = Transform3D(basis, draw_pos)


func _is_school_finished() -> bool:
	if _positions.is_empty():
		return true
	var min_axis := INF
	var max_axis := -INF
	for pos in _positions:
		var local := pos - school_center
		var axis_value := local.x if _travel_axis == 0 else local.z
		min_axis = minf(min_axis, axis_value)
		max_axis = maxf(max_axis, axis_value)
	var half_extent := (school_bounds.x * 0.5) if _travel_axis == 0 else (school_bounds.z * 0.5)
	if _travel_sign > 0.0:
		# Recycle only after the trailing fish has also cleared the volume.
		return min_axis > (half_extent + maxf(stream_recycle_front_distance, 0.0))
	# Recycle only after the trailing fish has also cleared the volume.
	return max_axis < (-half_extent - maxf(stream_recycle_front_distance, 0.0))


func _clear_school() -> void:
	for child in fish_root.get_children():
		child.queue_free()
	_fish_nodes.clear()
	_positions.clear()
	_dirs.clear()
	_speeds.clear()
	_phases.clear()
	_steers.clear()
	_school_active = false


func _schedule_next_school(delay: float) -> void:
	_next_school_timer = maxf(delay, 0.0)


func _random_school_delay() -> float:
	return Utils.random_range(_rng, delay_between_schools_min, delay_between_schools_max)


func _assign_travel_axis_from_flow() -> void:
	if absf(_current_flow.x) >= absf(_current_flow.z):
		_travel_axis = 0
		_travel_sign = 1.0 if _current_flow.x >= 0.0 else -1.0
	else:
		_travel_axis = 2
		_travel_sign = 1.0 if _current_flow.z >= 0.0 else -1.0


func _travel_half_extent(half: Vector3) -> float:
	return half.x if _travel_axis == 0 else half.z


func _attach_fish_visual(carrier: Node3D) -> void:
	var fish_scene := _pick_random_fish_scene()
	if fish_scene == null:
		var fallback := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.06
		mesh.height = 0.28
		mesh.radial_segments = 6
		mesh.rings = 2
		fallback.mesh = mesh
		carrier.add_child(fallback)
		return

	var fish_instance := fish_scene.instantiate()
	if fish_instance == null:
		return
	carrier.add_child(fish_instance)


func _pick_random_fish_scene() -> PackedScene:
	if _active_species.is_empty():
		return null
	return _active_species[_rng.randi_range(0, _active_species.size() - 1)]


func _collect_scene_pool(folder_path: String) -> Array[PackedScene]:
	var pool: Array[PackedScene] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return pool

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir():
			continue
		var ext := entry.get_extension().to_lower()
		if ext != "glb" and ext != "gltf" and ext != "scn" and ext != "tscn":
			continue
		var path := "%s/%s" % [folder_path, entry]
		var res := load(path)
		if res is PackedScene:
			pool.append(res as PackedScene)
	dir.list_dir_end()
	return pool


func _set_shadow_recursive(node: Node, shadow_setting: int) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = shadow_setting
	for child in node.get_children():
		_set_shadow_recursive(child, shadow_setting)


func _play_animation_recursive(node: Node) -> void:
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		var names := player.get_animation_list()
		if not names.is_empty():
			player.speed_scale = _rng.randf_range(
				minf(animation_speed_min, animation_speed_max),
				maxf(animation_speed_min, animation_speed_max)
			)
			player.play(names[0])
	for child in node.get_children():
		_play_animation_recursive(child)


func _apply_swim_volume_overrides() -> void:
	if swim_volume_shape_path.is_empty():
		return
	var shape_node := get_node_or_null(swim_volume_shape_path) as CollisionShape3D
	if shape_node == null:
		return
	var box_shape := shape_node.shape as BoxShape3D
	if box_shape == null:
		return

	var shape_scale := shape_node.global_basis.get_scale().abs()
	school_bounds = Vector3(
		box_shape.size.x * shape_scale.x,
		box_shape.size.y * shape_scale.y,
		box_shape.size.z * shape_scale.z
	)
	school_center = to_local(shape_node.global_position)


func _update_editor_preview() -> void:
	if volume_preview == null:
		return
	volume_preview.visible = show_volume_preview_in_editor
	var mesh := volume_preview.mesh as BoxMesh
	if mesh != null:
		mesh.size = school_bounds
