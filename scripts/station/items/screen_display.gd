@tool
extends Node3D

@export var screen_image: Texture2D:
	set(value):
		screen_image = value
		_update_screen()

func _ready() -> void:
	_update_screen()

func _update_screen() -> void:
	if not is_inside_tree():
		return
	var mesh: MeshInstance3D = get_node_or_null("screen_mesh")
	if not mesh or not screen_image:
		return
	var mat := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	if not mat:
		return
	mat.albedo_texture = screen_image
	mat.emission_texture = screen_image
	mesh.set_surface_override_material(0, mat)
