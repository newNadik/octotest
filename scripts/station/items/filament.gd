extends Node3D

@export var min_saturation := 0.55
@export var max_saturation := 0.9
@export var min_value := 0.7
@export var max_value := 1.0
@export_range(0.0, 1.0) var white_chance := 0.1
@export_range(0.0, 1.0) var black_chance := 0.1

@onready var _cylinder: MeshInstance3D = $Node3D/Cylinder


func _ready() -> void:
	if _cylinder == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var roll := rng.randf()
	var color: Color
	if roll < white_chance:
		color = Color.WHITE
	elif roll < white_chance + black_chance:
		color = Color.BLACK
	else:
		color = Color.from_hsv(
			rng.randf(),
			rng.randf_range(min_saturation, max_saturation),
			rng.randf_range(min_value, max_value)
		)
	var base_material := _cylinder.get_active_material(0) as StandardMaterial3D
	var material := base_material.duplicate() as StandardMaterial3D if base_material != null else StandardMaterial3D.new()
	material.albedo_color = color
	_cylinder.material_override = material
