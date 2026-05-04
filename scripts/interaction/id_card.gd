extends StaticBody3D

@export var card_display_name := "ID Card"
@export var card_item_id := "card_main"
@export var access_level := 1
@export var card_face_texture: Texture2D
@export var card_face_mesh_path: NodePath = NodePath("id_MeshInstance3D")
@export var interactable_path: NodePath = NodePath("Interactable")

@onready var sim = $LanyardSkeleton/SpringBoneSimulator3D
@onready var floor = $LanyardSkeleton/SpringBoneSimulator3D/FloorCollision
@onready var _main_scene := get_tree().current_scene

const FLOOR_ACTIVE_POSITION := Vector3(0.0, 0.02, 0.0)
const FLOOR_DISABLED_POSITION := Vector3(0.0, -1000.0, 0.0)



func _ready() -> void:
	var interactable = get_node_or_null(interactable_path)
	if interactable != null:
		interactable.display_name = card_display_name
		interactable.item_id = card_item_id
		interactable.set_meta("access_level", access_level)

	if card_face_texture != null:
		var face_mesh := get_node_or_null(card_face_mesh_path) as MeshInstance3D
		if face_mesh != null:
			var material := face_mesh.get_active_material(0) as StandardMaterial3D
			if material != null:
				# Each instance needs its own material, otherwise all card instances share one texture.
				var unique_material := material.duplicate() as StandardMaterial3D
				if unique_material != null:
					unique_material.albedo_texture = card_face_texture
					face_mesh.set_surface_override_material(0, unique_material)
	
	_update_floor_collision_state()

func _process(_delta: float) -> void:
	_update_floor_collision_state()


func _update_floor_collision_state() -> void:
	if floor == null:
		return

	var focus_active := false
	if _main_scene != null and _main_scene.has_method("is_focus_mode_active"):
		focus_active = bool(_main_scene.call("is_focus_mode_active"))

	floor.global_position = FLOOR_DISABLED_POSITION if focus_active else FLOOR_ACTIVE_POSITION
