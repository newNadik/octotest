extends InteractionBehavior
class_name CardReader


signal card_tap_result(granted: bool)

enum ReaderState {
	IDLE,
	DENIED,
	GRANTED,
}

@export var allowed_access_levels: PackedInt32Array = PackedInt32Array([3])
@export var linked_door_group_path: NodePath
@export var indicator_mesh_path: NodePath = NodePath("Node3D/indicator")
@export var granted_label_path: NodePath = NodePath("access_granted_label")
@export var denied_label_path: NodePath = NodePath("access_denied_label")
@export var feedback_duration := 1.1

var _indicator_mesh: MeshInstance3D
var _granted_label: Label3D
var _denied_label: Label3D
var _linked_door_group: Node
var _state: ReaderState = ReaderState.IDLE
var _feedback_ticket := 0
var _yellow_material: StandardMaterial3D
var _red_material: StandardMaterial3D
var _green_material: StandardMaterial3D


func _ready() -> void:
	_indicator_mesh = get_node_or_null(indicator_mesh_path) as MeshInstance3D
	_granted_label = get_node_or_null(granted_label_path) as Label3D
	_denied_label = get_node_or_null(denied_label_path) as Label3D
	_linked_door_group = get_node_or_null(linked_door_group_path)
	_yellow_material = _make_led_material(Color(0.96, 0.84, 0.2, 1.0))
	_red_material = _make_led_material(Color(0.9, 0.2, 0.2, 1.0))
	_green_material = _make_led_material(Color(0.2, 0.92, 0.3, 1.0))
	_set_state(ReaderState.IDLE)


func on_interacted(_actor: Node) -> void:
	pass


func can_receive_item(item: Interactable) -> bool:
	return can_accept_card(item)


func receive_item(item: Interactable) -> bool:
	return try_tap_card(item)


func should_consume_received_item(_item: Interactable) -> bool:
	return false


func can_accept_card(card) -> bool:
	return card != null and card.is_card()


func try_tap_card(card) -> bool:
	if not can_accept_card(card):
		_show_denied_feedback()
		return false

	var card_level := int(card.get_meta("access_level", 0))
	var granted := allowed_access_levels.has(card_level)
	if granted:
		_show_granted_feedback()
		_open_linked_door_group()
	else:
		_show_denied_feedback()
	emit_signal("card_tap_result", granted)
	return granted


func _open_linked_door_group() -> void:
	if _linked_door_group == null:
		return
	if _linked_door_group.has_method("grant_access_and_open"):
		_linked_door_group.call("grant_access_and_open")


func _show_granted_feedback() -> void:
	_set_state(ReaderState.GRANTED)
	_schedule_reset_feedback()


func _show_denied_feedback() -> void:
	_set_state(ReaderState.DENIED)
	_schedule_reset_feedback()


func _schedule_reset_feedback() -> void:
	_feedback_ticket += 1
	var ticket := _feedback_ticket
	var timer := get_tree().create_timer(maxf(0.05, feedback_duration))
	timer.timeout.connect(func() -> void:
		if ticket != _feedback_ticket:
			return
		_set_state(ReaderState.IDLE)
	)


func _set_state(state: ReaderState) -> void:
	_state = state
	if _indicator_mesh != null:
		match _state:
			ReaderState.IDLE:
				_indicator_mesh.material_override = _yellow_material
			ReaderState.DENIED:
				_indicator_mesh.material_override = _red_material
			ReaderState.GRANTED:
				_indicator_mesh.material_override = _green_material

	if _granted_label != null:
		_granted_label.visible = _state == ReaderState.GRANTED
	if _denied_label != null:
		_denied_label.visible = _state == ReaderState.DENIED


func _make_led_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	material.roughness = 0.35
	return material
