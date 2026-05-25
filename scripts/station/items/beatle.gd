extends InteractionBehavior
class_name Beatle

@export var missing_fin_path: NodePath = NodePath("Node3D/missing_fin")
@export var propeller_path: NodePath = NodePath("Node3D/prepeller")
@export var printed_fin_item_id := "printed_fin"
@export var propeller_item_id := "propeller"

var _printed_fin_applied := false
var _propeller_applied := false

@onready var _missing_fin: Node3D = get_node_or_null(missing_fin_path) as Node3D
@onready var _propeller: Node3D = get_node_or_null(propeller_path) as Node3D


func _ready() -> void:
	_update_visual_state()


func can_receive_item(item: Interactable) -> bool:
	if item == null or not is_instance_valid(item):
		return false

	var item_id := str(item.get("item_id")) if item.has_method("get") else ""
	if item_id == printed_fin_item_id:
		return not _printed_fin_applied
	if item_id == propeller_item_id:
		return not _propeller_applied
	return false


func receive_item(item: Interactable) -> bool:
	if not can_receive_item(item):
		return false

	var item_id := str(item.get("item_id")) if item.has_method("get") else ""
	if item_id == printed_fin_item_id:
		_printed_fin_applied = true
	elif item_id == propeller_item_id:
		_propeller_applied = true
	else:
		return false

	_update_visual_state()
	return true


func _update_visual_state() -> void:
	if _missing_fin != null:
		_missing_fin.visible = _printed_fin_applied
	if _propeller != null:
		_propeller.visible = _propeller_applied
