extends RefCounted


const MIN_DIRECTION_LENGTH := 0.0001


static func arrived_2d(current_position: Vector3, target_position: Vector3, stop_distance: float) -> bool:
	var planar_delta := Vector2(
		target_position.x - current_position.x,
		target_position.z - current_position.z
	)
	return planar_delta.length() <= stop_distance


static func project_planar_direction_on_surface(direction: Vector3, surface_normal: Vector3) -> Vector3:
	var planar_direction := Vector3(direction.x, 0.0, direction.z)
	if planar_direction.length() <= MIN_DIRECTION_LENGTH:
		return Vector3.ZERO

	var normalized_surface := surface_normal.normalized()
	var projected_direction := planar_direction.slide(normalized_surface)
	if projected_direction.length() <= MIN_DIRECTION_LENGTH:
		return Vector3.ZERO

	return projected_direction.normalized()


static func next_velocity_2d(
	current_velocity: Vector3,
	current_position: Vector3,
	target_position: Vector3,
	max_speed: float,
	acceleration: float,
	stop_distance: float,
	delta: float
) -> Vector3:
	var to_target := Vector2(
		target_position.x - current_position.x,
		target_position.z - current_position.z
	)
	var distance := to_target.length()
	var planar_velocity := Vector2(current_velocity.x, current_velocity.z)
	var desired_velocity := Vector2.ZERO

	if distance > stop_distance:
		desired_velocity = to_target / distance * max_speed

	var next_planar := planar_velocity.move_toward(desired_velocity, acceleration * delta)
	return Vector3(next_planar.x, current_velocity.y, next_planar.y)
