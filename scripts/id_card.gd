extends StaticBody3D

@export var card_display_name := "ID Card"
@export var card_item_id := "card_main"
@export var access_level := 1
@export var card_face_texture: Texture2D
@export var card_face_mesh_path: NodePath = NodePath("id_MeshInstance3D")
@export var interactable_path: NodePath = NodePath("Interactable")


func _ready() -> void:
	var interactable = get_node_or_null(interactable_path)
	if interactable != null:
		interactable.display_name = card_display_name
		interactable.item_id = card_item_id
		interactable.set_meta("access_level", access_level)

	if card_face_texture == null:
		return

	var face_mesh := get_node_or_null(card_face_mesh_path) as MeshInstance3D
	if face_mesh == null:
		return

	var material := face_mesh.get_active_material(0) as StandardMaterial3D
	if material == null:
		return

	# Each instance needs its own material, otherwise all card instances share one texture.
	var unique_material := material.duplicate() as StandardMaterial3D
	if unique_material == null:
		return
	unique_material.albedo_texture = card_face_texture
	face_mesh.set_surface_override_material(0, unique_material)
