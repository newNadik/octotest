extends CharacterBody3D


const WALL_COLLISION_MASK := 1 << 0
const GROUND_COLLISION_MASK := 1 << 1
const PLAYER_COLLISION_LAYER := 1 << 2
const MovementMath = preload("res://scripts/core/movement_math.gd")

var move_speed := 6.0
var acceleration := 22.0
var stop_distance := 0.2
var gravity_scale := 1.0
var turn_speed := 10.0
var step_height := 0.4
var mantle_height := 1.2
var mantle_duration := 0.75
var climb_probe_distance := 1.0
var climb_surface_min_up_dot := 0.7
var climb_wall_max_up_dot := 0.3
var mantle_landing_forward := 0.28
var mantle_clearance := 0.08
var min_landing_half_extent := 0.14
var climb_collision_mask := WALL_COLLISION_MASK | GROUND_COLLISION_MASK

var _has_target := false
var _target_position := Vector3.ZERO
var _gravity := 9.8
var _half_height := 0.5
var _mantling := false
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_progress := 0.0
var _mantle_duration_active := 0.75
var _post_mantle_turn_timer := 0.0
const POST_MANTLE_TURN_DAMP_TIME := 0.22


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	collision_layer = PLAYER_COLLISION_LAYER
	collision_mask = WALL_COLLISION_MASK | GROUND_COLLISION_MASK
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is BoxShape3D:
		_half_height = (shape_node.shape as BoxShape3D).size.y * 0.5


func set_move_target(world_target: Vector3) -> void:
	_target_position = world_target
	_has_target = true


func clear_move_target() -> void:
	_has_target = false
	_mantling = false


func _physics_process(delta: float) -> void:
	if _mantling:
		_process_mantle(delta)
		return

	if _post_mantle_turn_timer > 0.0:
		_post_mantle_turn_timer = maxf(0.0, _post_mantle_turn_timer - delta)

	var floor_normal := Vector3.UP
	var grounded := is_on_floor()
	if grounded:
		floor_normal = get_floor_normal()

	if _has_target and MovementMath.arrived_2d(global_position, _target_position, stop_distance):
		_has_target = false

	var move_target := global_position
	if _has_target:
		move_target = _target_position

	velocity = MovementMath.next_velocity_2d(
		velocity,
		global_position,
		move_target,
		move_speed,
		acceleration,
		stop_distance,
		delta
	)

	if grounded:
		_align_planar_velocity_to_slope(floor_normal)

	if not grounded:
		velocity.y -= _gravity * gravity_scale * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if _has_target and grounded:
		_try_begin_climb()

	move_and_slide()
	_rotate_toward_motion(delta)


func _rotate_toward_motion(delta: float) -> void:
	var planar_velocity := Vector2(velocity.x, velocity.z)
	if planar_velocity.length() <= 0.08:
		return
	var speed := turn_speed
	if _post_mantle_turn_timer > 0.0:
		speed *= 0.35
	_rotate_toward_planar(planar_velocity, delta, speed)


func _rotate_toward_planar(planar_direction: Vector2, delta: float, speed: float) -> void:
	if planar_direction.length() <= 0.01:
		return
	var target_yaw := atan2(planar_direction.x, planar_direction.y)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, speed * delta))


func _align_planar_velocity_to_slope(floor_normal: Vector3) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed <= 0.001:
		return

	var direction_hint := Vector3(velocity.x, 0.0, velocity.z)
	if _has_target:
		direction_hint = _target_position - global_position

	var slope_direction := MovementMath.project_planar_direction_on_surface(direction_hint, floor_normal)
	if slope_direction == Vector3.ZERO:
		return

	velocity.x = slope_direction.x * planar_speed
	velocity.z = slope_direction.z * planar_speed


func _process_mantle(delta: float) -> void:
	_mantle_progress += delta / maxf(0.01, _mantle_duration_active)
	var t := minf(_mantle_progress, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	global_position = _mantle_from.lerp(_mantle_to, eased)
	velocity = Vector3.ZERO
	var mantle_planar := Vector2(_mantle_to.x - global_position.x, _mantle_to.z - global_position.z)
	_rotate_toward_planar(mantle_planar, delta, turn_speed * 0.65)
	if t >= 1.0:
		_mantling = false
		_post_mantle_turn_timer = POST_MANTLE_TURN_DAMP_TIME


func _try_begin_climb() -> void:
	var to_target := _target_position - global_position
	var planar_direction := Vector3(to_target.x, 0.0, to_target.z)
	if planar_direction.length() <= 0.01:
		planar_direction = Vector3(velocity.x, 0.0, velocity.z)
		if planar_direction.length() <= 0.01:
			return
	planar_direction = planar_direction.normalized()

	var wall_hit := _find_wall_hit(planar_direction)
	var top_hit := Dictionary()
	if not wall_hit.is_empty():
		var top_probe_start: Vector3 = wall_hit.position + planar_direction * 0.12 + Vector3.UP * (mantle_height + mantle_clearance)
		var top_probe_end: Vector3 = top_probe_start + Vector3.DOWN * (mantle_height + step_height + 0.35)
		top_hit = _cast_ray(top_probe_start, top_probe_end, climb_collision_mask)

	if top_hit.is_empty():
		top_hit = _find_target_top_hit()
		if top_hit.is_empty():
			return

	var top_normal: Vector3 = top_hit.normal
	if top_normal.dot(Vector3.UP) < climb_surface_min_up_dot:
		return
	if not _has_landing_footprint(top_hit.position, planar_direction):
		return

	var target_center_y: float = top_hit.position.y + _half_height + 0.01
	var climb_delta: float = target_center_y - global_position.y
	if climb_delta <= 0.01 or climb_delta > mantle_height:
		return

	var landing_point: Vector3 = top_hit.position + planar_direction * mantle_landing_forward
	var target_position := Vector3(landing_point.x, target_center_y, landing_point.z)

	_mantling = true
	_mantle_from = global_position
	_mantle_to = target_position
	_mantle_progress = 0.0
	var height_ratio := clampf(climb_delta / maxf(0.01, mantle_height), 0.0, 1.0)
	var duration_scale := lerpf(0.55, 1.15, height_ratio)
	if climb_delta <= step_height:
		duration_scale = maxf(0.45, duration_scale * 0.8)
	_mantle_duration_active = mantle_duration * duration_scale


func _cast_ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = mask
	query.collide_with_areas = false
	query.exclude = [self]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _find_wall_hit(planar_direction: Vector3) -> Dictionary:
	var foot_y := global_position.y - _half_height + 0.05
	var base_from := Vector3(global_position.x, foot_y, global_position.z)
	var right := Vector3.UP.cross(planar_direction).normalized()
	var side_offset := 0.28

	var center_hit := _wall_probe(base_from, planar_direction)
	if not center_hit.is_empty():
		return center_hit

	var right_hit := _wall_probe(base_from + right * side_offset, planar_direction)
	if not right_hit.is_empty():
		return right_hit

	return _wall_probe(base_from - right * side_offset, planar_direction)


func _wall_probe(ray_from: Vector3, planar_direction: Vector3) -> Dictionary:
	var ray_to := ray_from + planar_direction * climb_probe_distance
	var hit := _cast_ray(ray_from, ray_to, climb_collision_mask)
	if hit.is_empty():
		return hit

	var wall_normal: Vector3 = hit.normal
	if wall_normal.y > climb_wall_max_up_dot:
		return {}
	return hit


func _find_target_top_hit() -> Dictionary:
	var to_target := _target_position - global_position
	var planar_distance := Vector2(to_target.x, to_target.z).length()
	if planar_distance > climb_probe_distance + 0.9:
		return {}
	if _target_position.y <= global_position.y + 0.03:
		return {}

	var down_from := Vector3(
		_target_position.x,
		_target_position.y + mantle_height + mantle_clearance + 0.25,
		_target_position.z
	)
	var down_to := Vector3(
		_target_position.x,
		_target_position.y - (mantle_height + step_height + 0.65),
		_target_position.z
	)
	return _cast_ray(down_from, down_to, climb_collision_mask)


func _has_landing_footprint(top_point: Vector3, planar_direction: Vector3) -> bool:
	var right := Vector3.UP.cross(planar_direction).normalized()
	var offsets := [
		planar_direction * min_landing_half_extent,
		-planar_direction * min_landing_half_extent,
		right * min_landing_half_extent,
		-right * min_landing_half_extent
	]
	for offset in offsets:
		var sample_point: Vector3 = top_point + offset
		var from: Vector3 = sample_point + Vector3.UP * 0.3
		var to: Vector3 = sample_point + Vector3.DOWN * 0.4
		var sample_hit := _cast_ray(from, to, climb_collision_mask)
		if sample_hit.is_empty():
			return false
		var sample_normal: Vector3 = sample_hit.normal
		if sample_normal.dot(Vector3.UP) < climb_surface_min_up_dot:
			return false
		if absf((sample_hit.position as Vector3).y - top_point.y) > 0.06:
			return false
	return true
