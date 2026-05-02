extends Node3D
class_name CansBox

@export var required_item_id := "energy_drink"
@export var required_can_variant_id := ""
@export var missing_can_path: NodePath = NodePath("missing_can")

var _is_filled := false
@onready var _missing_can: Node3D = get_node_or_null(missing_can_path) as Node3D


func _ready() -> void:
	_update_visual_state()


func can_accept_energy_drink(item) -> bool:
	if _is_filled or item == null:
		return false
	if not is_instance_valid(item):
		return false
	var can_root = item.get_parent()
	if required_can_variant_id.strip_edges() != "":
		if can_root == null or not can_root.has_method("get"):
			return false
		var can_variant_id := str(can_root.get("can_variant_id"))
		return can_variant_id == required_can_variant_id
	var item_id := str(item.get("item_id")) if item.has_method("get") else ""
	if not item_id.is_empty():
		return item_id == required_item_id
	var display_name := str(item.get("display_name")) if item.has_method("get") else ""
	return display_name.strip_edges().to_lower() == "energy drink"


func insert_energy_drink(item) -> bool:
	if not can_accept_energy_drink(item):
		return false
	_is_filled = true
	_update_visual_state()
	return true


func is_box_filled() -> bool:
	return _is_filled


func _update_visual_state() -> void:
	if _missing_can != null:
		_missing_can.visible = _is_filled
