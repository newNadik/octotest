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

const FLOOR_DISABLED_LOCAL_POSITION := Vector3(0.0, -1000.0, 0.0)
const FLOOR_ACTIVE_HELD_POSITION := Vector3(0.0, 0.02, 0.0)
const FLOOR_ACTIVE_DROPPED_POSITION := Vector3(0.0, -0.14, 0.0)
@export var floor_drop_delay := 0.0
var _interactable
var _is_held := false
var _drop_delay_left := 0.0
var _floor_enabled_after_first_pickup := false
var _initial_save_key := ""



func _ready() -> void:
	add_to_group("save_state_provider")
	_initial_save_key = str(get_path())

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
				# Each instance needs its own material, otherwise all card instances share one texture.
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
	if floor == null:
		return

	var focus_active := false
	if _main_scene != null and _main_scene.has_method("is_focus_mode_active"):
		focus_active = bool(_main_scene.call("is_focus_mode_active"))

	if focus_active:
		floor.global_position = FLOOR_DISABLED_LOCAL_POSITION
	elif not _floor_enabled_after_first_pickup:
		floor.global_position = FLOOR_DISABLED_LOCAL_POSITION
	elif _is_card_held() or _drop_delay_left > 0.0:
		floor.global_position = FLOOR_ACTIVE_HELD_POSITION
	else:
		floor.position = FLOOR_ACTIVE_DROPPED_POSITION
		#print("ready card=", global_position, " floor_local=", floor.position, " floor_global=", floor.global_position)


func _is_card_held() -> bool:
	return _is_held


func _on_interactable_picked_up(_interactable_ref, _actor) -> void:
	_is_held = true
	_floor_enabled_after_first_pickup = true


func _on_interactable_dropped(_interactable_ref, _actor) -> void:
	_is_held = false
	_drop_delay_left = floor_drop_delay


func get_save_key() -> String:
	if _interactable != null and _interactable.has_method("get_save_key"):
		return "%s:id_card" % str(_interactable.call("get_save_key"))
	return "%s:id_card" % _initial_save_key


func get_save_state() -> Dictionary:
	return {
		"floor_enabled_after_first_pickup": _floor_enabled_after_first_pickup
	}


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_floor_enabled_after_first_pickup = bool(state.get("floor_enabled_after_first_pickup", false))
