extends Node
class_name WearController

const OctoRigScript = preload("res://scripts/rig/OctoRig.gd")

# Local offsets applied on top of the head bone transform.
# Positive Y = up relative to head bone, positive Z = forward.
@export var hat_position_offset := Vector3(0.0, 0.18, 0.0)
@export var hat_rotation_degrees := Vector3(0.0, 0.0, 0.0)
@export var glasses_position_offset := Vector3(0.0, -0.04, 0.18)
@export var glasses_rotation_degrees := Vector3(0.0, 0.0, 0.0)

var _rig: OctoRigScript
var _hat_anchor: Node3D
var _glasses_anchor: Node3D
var _worn: Dictionary = {}  # slot_name -> WearableInteractable
var _original_scales: Dictionary = {}  # slot_name -> Vector3
var _original_rotations: Dictionary = {}  # slot_name -> Vector3
var _world_root: Node3D
var _player: CharacterBody3D


func initialize(player: CharacterBody3D, world_root: Node3D) -> void:
	_player = player
	_world_root = world_root
	var visual = player.get_node_or_null("PlayerVisual")
	if visual is OctoRigScript:
		_rig = visual as OctoRigScript

	_hat_anchor = Node3D.new()
	_hat_anchor.name = "HatAnchor"
	player.add_child(_hat_anchor)

	_glasses_anchor = Node3D.new()
	_glasses_anchor.name = "GlassesAnchor"
	player.add_child(_glasses_anchor)


func process_wear(delta: float) -> void:
	if _rig == null:
		return
	var head_xform := _rig.get_head_world_transform()
	if _hat_anchor != null:
		_hat_anchor.global_transform = head_xform * _make_local_transform(hat_position_offset, hat_rotation_degrees)
	if _glasses_anchor != null:
		_glasses_anchor.global_transform = head_xform * _make_local_transform(glasses_position_offset, glasses_rotation_degrees)


func get_worn_in_slot(slot_name: String) -> WearableInteractable:
	return _worn.get(slot_name, null)


func try_wear(item: WearableInteractable) -> bool:
	var slot := item.get_wear_slot_name()
	if _worn.has(slot):
		return false
	var anchor := _get_anchor(slot)
	if anchor == null:
		return false
	var pickup_root := item.get_pickup_root()
	_original_scales[slot] = pickup_root.scale
	_original_rotations[slot] = pickup_root.rotation
	item.set_worn(pickup_root.scale, pickup_root.rotation)
	_worn[slot] = item
	pickup_root.reparent(anchor, false)
	pickup_root.position = item.wear_offset
	pickup_root.rotation = item.wear_rotation_degrees * PI / 180.0
	pickup_root.scale = Vector3.ONE * item.wear_scale
	item.set_held(true)
	return true


func try_unwear(item: WearableInteractable) -> void:
	var slot := item.get_wear_slot_name()
	if not _worn.has(slot):
		return
	_worn.erase(slot)
	var pickup_root := item.get_pickup_root()
	if _world_root != null:
		pickup_root.reparent(_world_root, true)
	pickup_root.scale = _original_scales.get(slot, Vector3.ONE)
	pickup_root.rotation = Vector3.ZERO
	_original_scales.erase(slot)
	_original_rotations.erase(slot)
	item.set_unworn()
	item.set_held(false)
	item.drop(_player)


func set_worn_item_visuals_visible(is_visible: bool) -> void:
	for item in _worn.values():
		var root: Node3D = item.get_pickup_root()
		if root != null:
			root.visible = is_visible


func is_worn(item) -> bool:
	for worn_item in _worn.values():
		if worn_item == item:
			return true
	return false


func get_worn_item(slot_name: String) -> WearableInteractable:
	return _worn.get(slot_name, null)


func _get_anchor(slot_name: String) -> Node3D:
	match slot_name:
		"hat": return _hat_anchor
		"glasses": return _glasses_anchor
	return null


func _make_local_transform(offset: Vector3, rotation_deg: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(rotation_deg * PI / 180.0), offset)
