extends Node3D

@export var close_count := 28
@export var close_bounds := Vector3(14.0, 4.0, 12.0)
@export var close_center := Vector3(0.0, 0.0, 0.0)
@export var close_speed_min := 0.7
@export var close_speed_max := 1.4
@export var close_turn_strength := 0.85
@export var close_bob_amplitude := 0.18
@export var close_bob_speed := 1.6
@export var close_mesh: Mesh

@export var mid_count := 96
@export var mid_bounds := Vector3(34.0, 10.0, 24.0)
@export var mid_center := Vector3(4.0, -1.2, 4.0)
@export var mid_speed_min := 1.0
@export var mid_speed_max := 2.1
@export var mid_turn_strength := 0.55
@export var mid_bob_amplitude := 0.24
@export var mid_bob_speed := 1.15
@export var mid_mesh: Mesh

@onready var close_fish: MultiMeshInstance3D = $CloseFish
@onready var mid_fish: MultiMeshInstance3D = $MidFish

var _rng := RandomNumberGenerator.new()
var _time := 0.0

var _close_positions: Array[Vector3] = []
var _close_dirs: Array[Vector3] = []
var _close_speeds: Array[float] = []
var _close_phases: Array[float] = []

var _mid_positions: Array[Vector3] = []
var _mid_dirs: Array[Vector3] = []
var _mid_speeds: Array[float] = []
var _mid_phases: Array[float] = []


func _ready() -> void:
	_rng.randomize()
	_setup_layer(
		close_fish,
		close_mesh,
		close_count,
		close_center,
		close_bounds,
		close_speed_min,
		close_speed_max,
		_close_positions,
		_close_dirs,
		_close_speeds,
		_close_phases
	)
	_setup_layer(
		mid_fish,
		mid_mesh,
		mid_count,
		mid_center,
		mid_bounds,
		mid_speed_min,
		mid_speed_max,
		_mid_positions,
		_mid_dirs,
		_mid_speeds,
		_mid_phases
	)


func _process(delta: float) -> void:
	_time += maxf(delta, 0.0)
	_step_layer(
		close_fish,
		close_center,
		close_bounds,
		close_turn_strength,
		close_bob_amplitude,
		close_bob_speed,
		_close_positions,
		_close_dirs,
		_close_speeds,
		_close_phases,
		delta
	)
	_step_layer(
		mid_fish,
		mid_center,
		mid_bounds,
		mid_turn_strength,
		mid_bob_amplitude,
		mid_bob_speed,
		_mid_positions,
		_mid_dirs,
		_mid_speeds,
		_mid_phases,
		delta
	)


func _setup_layer(
	mmi: MultiMeshInstance3D,
	mesh: Mesh,
	count: int,
	center: Vector3,
	bounds: Vector3,
	speed_min: float,
	speed_max: float,
	positions: Array[Vector3],
	dirs: Array[Vector3],
	speeds: Array[float],
	phases: Array[float]
) -> void:
	var instance_count := maxi(count, 0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = instance_count
	multimesh.visible_instance_count = instance_count
	multimesh.mesh = mesh if mesh != null else _build_fallback_mesh()
	mmi.multimesh = multimesh

	positions.clear()
	dirs.clear()
	speeds.clear()
	phases.clear()
	positions.resize(instance_count)
	dirs.resize(instance_count)
	speeds.resize(instance_count)
	phases.resize(instance_count)

	var half := bounds * 0.5
	for i in instance_count:
		var pos := center + Vector3(
			_rng.randf_range(-half.x, half.x),
			_rng.randf_range(-half.y, half.y),
			_rng.randf_range(-half.z, half.z)
		)
		var dir := Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-0.15, 0.15),
			_rng.randf_range(-1.0, 1.0)
		).normalized()
		if dir.is_zero_approx():
			dir = Vector3.FORWARD
		positions[i] = pos
		dirs[i] = dir
		speeds[i] = _rng.randf_range(speed_min, maxf(speed_max, speed_min))
		phases[i] = _rng.randf_range(0.0, TAU)
		multimesh.set_instance_transform(i, Transform3D(Basis.looking_at(dir, Vector3.UP), pos))


func _step_layer(
	mmi: MultiMeshInstance3D,
	center: Vector3,
	bounds: Vector3,
	turn_strength: float,
	bob_amplitude: float,
	bob_speed: float,
	positions: Array[Vector3],
	dirs: Array[Vector3],
	speeds: Array[float],
	phases: Array[float],
	delta: float
) -> void:
	if mmi.multimesh == null:
		return

	var half := bounds * 0.5
	for i in positions.size():
		var wander := Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-0.2, 0.2),
			_rng.randf_range(-1.0, 1.0)
		).normalized()
		var dir := (dirs[i] + wander * turn_strength * maxf(delta, 0.0)).normalized()
		if dir.is_zero_approx():
			dir = dirs[i]
		dirs[i] = dir

		var pos := positions[i] + dir * speeds[i] * maxf(delta, 0.0)
		var local := pos - center
		local.x = wrapf(local.x, -half.x, half.x)
		local.y = wrapf(local.y, -half.y, half.y)
		local.z = wrapf(local.z, -half.z, half.z)
		pos = center + local
		positions[i] = pos

		var bob := sin(_time * bob_speed + phases[i]) * bob_amplitude
		var draw_pos := pos + Vector3(0.0, bob, 0.0)
		var basis := Basis.looking_at(dir, Vector3.UP)
		mmi.multimesh.set_instance_transform(i, Transform3D(basis, draw_pos))


func _build_fallback_mesh() -> Mesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.28
	mesh.radial_segments = 6
	mesh.rings = 2
	return mesh
