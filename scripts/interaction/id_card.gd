extends StaticBody3D

@export var card_display_name := "ID Card"
@export var card_item_id := "card_main"
@export var access_level := 1
@export var card_face_texture: Texture2D
@export var card_face_mesh_path: NodePath = NodePath("id_MeshInstance3D")
@export var interactable_path: NodePath = NodePath("Interactable")

@onready var sim = $LanyardSkeleton/SpringBoneSimulator3D
@onready var _floor_collision = $LanyardSkeleton/SpringBoneSimulator3D/FloorCollision
@onready var _main_scene := get_tree().current_scene

const FLOOR_DISABLED_LOCAL_POSITION := Vector3(0.0, -1000.0, 0.0)
const FLOOR_ACTIVE_HELD_POSITION := Vector3(0.0, 0.02, 0.0)
const FLOOR_ACTIVE_DROPPED_POSITION := Vector3(0.0, -0.01, 0.0)
var _floor_collision_drop_delay := 0.0
var _interactable
var _is_held := false
var _drop_delay_left := 0.0


func _ready() -> void:
	var interactable = get_node_or_null(interactable_path)
	_interactable = interactable
	if interactable != null:
		interactable.display_name = card_display_name
		interactable.item_id = card_item_id
		interactable.set_meta("access_level", access_level)
		if interactable.has_signal("picked_up") and not interactable.picked_up.is_connected(_on_interactable_picked_up):
			interactable.picked_up.connect(_on_interactable_picked_up)
		if interactable.has_signal("dropped") and not interactable.dropped.is_connected(_on_interactable_dropped):
			interactable.dropped.connect(_on_interactable_dropped)

	if card_face_texture != null:
		var face_mesh := get_node_or_null(card_face_mesh_path) as MeshInstance3D
		if face_mesh != null:
			var material := face_mesh.get_active_material(0) as StandardMaterial3D
			if material != null:
				var unique_material := material.duplicate() as StandardMaterial3D
				if unique_material != null:
					unique_material.albedo_texture = card_face_texture
					face_mesh.set_surface_override_material(0, unique_material)

	_update_floor_collision_state()


func _process(delta: float) -> void:
	if _drop_delay_left > 0.0:
		_drop_delay_left = maxf(0.0, _drop_delay_left - delta)
	_update_floor_collision_state()


func _update_floor_collision_state() -> void:
	if _floor_collision == null:
		return

	var focus_active := false
	if _main_scene != null and _main_scene.has_method("is_focus_mode_active"):
		focus_active = bool(_main_scene.call("is_focus_mode_active"))

	if focus_active:
		_floor_collision.global_position = FLOOR_DISABLED_LOCAL_POSITION
	elif _is_card_held() or _drop_delay_left > 0.0:
		_floor_collision.global_position = FLOOR_ACTIVE_HELD_POSITION
	else:
		_floor_collision.global_position = FLOOR_ACTIVE_DROPPED_POSITION
		#print("ready card=", global_position, " _floor_collision_local=", _floor_collision.position, " _floor_collision_global=", _floor_collision.global_position)




func _is_card_held() -> bool:
	return _is_held


func _on_interactable_picked_up(_interactable_ref, _actor) -> void:
	_is_held = true


func _on_interactable_dropped(_interactable_ref, _actor) -> void:
	_is_held = false
	_drop_delay_left = _floor_collision_drop_delay
