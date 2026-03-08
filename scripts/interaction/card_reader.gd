extends StaticBody3D
class_name CardReader


enum ReaderState {
	EMPTY,
	WRONG,
	CORRECT,
}

@export var required_card_id = "card_main"
@export var led_mesh_path: NodePath = NodePath("Led")
@export var slot_anchor_path: NodePath = NodePath("CardSlotAnchor")
@export var inserted_card_local_position = Vector3(0.0, -0.08, -0.32)
@export var inserted_card_local_rotation_degrees = Vector3(0.0, 0.0, 0.0)

var _led_mesh: MeshInstance3D
var _slot_anchor: Node3D
var _inserted_card
var _state: ReaderState = ReaderState.EMPTY
var _yellow_material: StandardMaterial3D
var _red_material: StandardMaterial3D
var _green_material: StandardMaterial3D


func _ready() -> void:
	_led_mesh = get_node_or_null(led_mesh_path) as MeshInstance3D
	_slot_anchor = get_node_or_null(slot_anchor_path) as Node3D
	if _slot_anchor == null:
		_slot_anchor = self

	_yellow_material = _make_led_material(Color(0.96, 0.84, 0.2, 1.0))
	_red_material = _make_led_material(Color(0.9, 0.2, 0.2, 1.0))
	_green_material = _make_led_material(Color(0.2, 0.92, 0.3, 1.0))
	_set_state(ReaderState.EMPTY)


func has_inserted_card() -> bool:
	return _inserted_card != null


func is_correct_card_inserted() -> bool:
	return _state == ReaderState.CORRECT


func can_accept_card(card) -> bool:
	if card == null:
		return false
	if has_inserted_card():
		return false
	return card.is_card()


func insert_card(card) -> bool:
	if card == null or not can_accept_card(card):
		return false
	if has_inserted_card():
		return false

	_inserted_card = card
	_inserted_card.set_interaction_enabled(true)
	var pickup_root = card.get_pickup_root()
	var preserved_global_scale = pickup_root.global_basis.get_scale().abs()
	pickup_root.reparent(_slot_anchor, true)
	var local_basis = Basis.from_euler(Vector3(
		deg_to_rad(inserted_card_local_rotation_degrees.x),
		deg_to_rad(inserted_card_local_rotation_degrees.y),
		deg_to_rad(inserted_card_local_rotation_degrees.z)
	))
	var slot_local_transform = Transform3D(local_basis, inserted_card_local_position)
	var target_global = _slot_anchor.global_transform * slot_local_transform
	var target_rotation = target_global.basis.orthonormalized()
	target_global.basis = target_rotation.scaled(preserved_global_scale)
	pickup_root.global_transform = target_global

	if _inserted_card.item_id == required_card_id:
		_set_state(ReaderState.CORRECT)
	else:
		_set_state(ReaderState.WRONG)

	return true


func eject_card() :
	if _inserted_card == null:
		return null

	var card = _inserted_card
	_inserted_card = null
	card.set_interaction_enabled(true)
	_set_state(ReaderState.EMPTY)
	return card


func is_inserted_card(card) -> bool:
	return card != null and card == _inserted_card


func get_inserted_card_position() -> Vector3:
	if _inserted_card != null:
		return _inserted_card.get_pickup_root().global_position
	return _slot_anchor.global_position


func get_slot_position() -> Vector3:
	return _slot_anchor.global_position


func _set_state(state: ReaderState) -> void:
	_state = state
	if _led_mesh == null:
		return

	match _state:
		ReaderState.EMPTY:
			_led_mesh.material_override = _yellow_material
		ReaderState.WRONG:
			_led_mesh.material_override = _red_material
		ReaderState.CORRECT:
			_led_mesh.material_override = _green_material


func _make_led_material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	material.roughness = 0.35
	return material
