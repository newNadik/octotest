@tool
extends StaticBody3D

enum BallColor {
	YELLOW,
	RED,
	BLUE,
	GREEN,
	ORANGE,
	PURPLE,
	PINK,
	CYAN,
}

const COLOR_BY_TYPE := {
	BallColor.YELLOW: Color8(242, 251, 25),
	BallColor.RED: Color8(220, 58, 58),
	BallColor.BLUE: Color8(74, 132, 255),
	BallColor.GREEN: Color8(67, 188, 112),
	BallColor.ORANGE: Color8(242, 150, 46),
	BallColor.PURPLE: Color8(150, 102, 228),
	BallColor.PINK: Color8(236, 110, 180),
	BallColor.CYAN: Color8(66, 206, 222),
}

@export_enum("Yellow", "Red", "Blue", "Green", "Orange", "Purple", "Pink", "Cyan") var ball_color: int = BallColor.YELLOW:
	set(value):
		ball_color = value
		_apply_ball_color()

@onready var _color_mesh: MeshInstance3D = $"pCube12/pCube13/pCube1_Paint Matte Yellow_0"

func _ready() -> void:
	_apply_ball_color()

func _enter_tree() -> void:
	_apply_ball_color()

func _apply_ball_color() -> void:
	if not is_instance_valid(_color_mesh):
		return
	if _color_mesh.mesh == null:
		return

	var color_material := _color_mesh.get_active_material(0) as StandardMaterial3D
	if color_material == null:
		color_material = _color_mesh.mesh.surface_get_material(0) as StandardMaterial3D
	if color_material == null:
		return

	color_material = color_material.duplicate() as StandardMaterial3D
	color_material.albedo_color = COLOR_BY_TYPE.get(ball_color, Color.WHITE)
	_color_mesh.set_surface_override_material(0, color_material)
