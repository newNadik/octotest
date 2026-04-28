extends Node3D

@export_group("Horizontal Drift")
@export var start_x := -0.12
@export var end_x := 0.15
@export var start_x_jitter := 0.02

@export_group("Variation")
@export var y_jitter := 0.02
@export var z_jitter := 0.01

@export_group("Timing")
@export var travel_time_min := 3.4
@export var travel_time_max := 5.2
@export var reset_delay_min := 0.08
@export var reset_delay_max := 0.45

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for child in get_children():
		var bubble := child as Node3D
		if bubble == null:
			continue
		var mesh := _find_mesh_instance(bubble)
		if mesh == null:
			continue
		_run_bubble_loop(bubble, mesh)


func _run_bubble_loop(bubble: Node3D, mesh: MeshInstance3D) -> void:
	var base_y := bubble.position.y
	var base_z := bubble.position.z
	var initial_delay := _rng.randf_range(0.0, travel_time_max * 0.55)
	await get_tree().create_timer(initial_delay).timeout

	while is_instance_valid(bubble) and is_instance_valid(mesh):
		bubble.position = Vector3(
			start_x + _rng.randf_range(-start_x_jitter, start_x_jitter),
			base_y + _rng.randf_range(-y_jitter, y_jitter),
			base_z + _rng.randf_range(-z_jitter, z_jitter)
		)
		mesh.transparency = 0.0

		var target := Vector3(
			end_x + _rng.randf_range(-0.01, 0.01),
			base_y + _rng.randf_range(-y_jitter, y_jitter),
			base_z + _rng.randf_range(-z_jitter, z_jitter)
		)
		var duration := _rng.randf_range(
			minf(travel_time_min, travel_time_max),
			maxf(travel_time_min, travel_time_max)
		)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(bubble, "position", target, duration)
		tween.tween_property(mesh, "transparency", 1.0, duration)
		await tween.finished

		var reset_delay := _rng.randf_range(
			minf(reset_delay_min, reset_delay_max),
			maxf(reset_delay_min, reset_delay_max)
		)
		await get_tree().create_timer(reset_delay).timeout


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null:
			return mesh
	return null
