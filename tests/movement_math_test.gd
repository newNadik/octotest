extends SceneTree


const EPSILON := 0.0001
const MovementMath = preload("res://scripts/core/movement_math.gd")

var _failures := 0


func _init() -> void:
	_test_arrived_2d()
	_test_next_velocity_accelerates_toward_target()
	_test_next_velocity_brakes_inside_stop_distance()
	_test_project_planar_direction_on_surface_flat()
	_test_project_planar_direction_on_surface_slope()
	_test_simulated_path_gets_close_to_target()

	if _failures == 0:
		print("movement_math_test: PASS")
		quit(0)
		return

	printerr("movement_math_test: FAIL (%d failures)" % _failures)
	quit(1)


func _test_arrived_2d() -> void:
	_expect_true(
		MovementMath.arrived_2d(Vector3(0.0, 0.0, 0.0), Vector3(0.1, 0.0, 0.1), 0.2),
		"arrived_2d should return true when inside stop distance"
	)
	_expect_true(
		not MovementMath.arrived_2d(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 0.2),
		"arrived_2d should return false outside stop distance"
	)


func _test_next_velocity_accelerates_toward_target() -> void:
	var next_velocity := MovementMath.next_velocity_2d(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3(10.0, 0.0, 0.0),
		6.0,
		20.0,
		0.2,
		0.1
	)
	_expect_true(next_velocity.x > 0.0, "velocity should accelerate toward positive X target")
	_expect_approx(next_velocity.x, 2.0, "acceleration limit should clamp velocity change")
	_expect_approx(next_velocity.y, 0.0, "vertical velocity should be preserved")
	_expect_approx(next_velocity.z, 0.0, "no lateral Z velocity should be introduced")


func _test_next_velocity_brakes_inside_stop_distance() -> void:
	var next_velocity := MovementMath.next_velocity_2d(
		Vector3(3.0, 1.5, 0.0),
		Vector3.ZERO,
		Vector3(0.1, 0.0, 0.0),
		6.0,
		10.0,
		0.2,
		0.1
	)
	_expect_approx(next_velocity.x, 2.0, "planar velocity should brake by acceleration * delta")
	_expect_approx(next_velocity.y, 1.5, "vertical velocity should remain unchanged by planar solver")


func _test_project_planar_direction_on_surface_flat() -> void:
	var projected := MovementMath.project_planar_direction_on_surface(
		Vector3(4.0, 0.0, 2.0),
		Vector3.UP
	)
	_expect_approx(projected.length(), 1.0, "projected flat direction should be normalized")
	_expect_approx(projected.y, 0.0, "flat projection should not create vertical component")
	_expect_true(projected.x > 0.0 and projected.z > 0.0, "flat projection should preserve heading")


func _test_project_planar_direction_on_surface_slope() -> void:
	var slope_normal := Vector3(0.0, cos(deg_to_rad(25.0)), -sin(deg_to_rad(25.0))).normalized()
	var projected := MovementMath.project_planar_direction_on_surface(Vector3(0.0, 0.0, 1.0), slope_normal)
	_expect_approx(projected.length(), 1.0, "slope projection should remain normalized")
	_expect_true(projected.y > 0.0, "moving uphill should include positive vertical direction")
	_expect_true(absf(projected.dot(slope_normal)) <= EPSILON, "projected direction should be tangent to slope")
	var zero_projected := MovementMath.project_planar_direction_on_surface(Vector3.ZERO, slope_normal)
	_expect_true(zero_projected == Vector3.ZERO, "zero direction should remain zero after projection")


func _test_simulated_path_gets_close_to_target() -> void:
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var target := Vector3(4.0, 0.0, 3.0)
	var dt := 1.0 / 60.0

	for i in range(180):
		velocity = MovementMath.next_velocity_2d(
			velocity,
			position,
			target,
			5.5,
			24.0,
			0.2,
			dt
		)
		position += Vector3(velocity.x, 0.0, velocity.z) * dt

	var remaining_distance := Vector2(target.x - position.x, target.z - position.z).length()
	_expect_true(remaining_distance < 0.35, "simulated path should converge near the click target")


func _expect_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: ", message)


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) <= EPSILON:
		return
	_failures += 1
	printerr("FAIL: %s (expected %.4f got %.4f)" % [message, expected, actual])
