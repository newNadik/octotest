extends Interactable
class_name WearableInteractable

enum WearSlot { HAT, GLASSES }

@export var wear_slot: WearSlot = WearSlot.HAT
@export var wear_offset := Vector3.ZERO
@export var wear_rotation_degrees := Vector3.ZERO
@export var wear_scale := 1.0

var _pre_wear_scale := Vector3.ONE
var _pre_wear_rotation := Vector3.ZERO
var _is_worn := false


func get_wear_slot_name() -> String:
	match wear_slot:
		WearSlot.HAT: return "hat"
		WearSlot.GLASSES: return "glasses"
	return "hat"


func set_worn(original_scale: Vector3, original_rotation: Vector3) -> void:
	_pre_wear_scale = original_scale
	_pre_wear_rotation = original_rotation
	_is_worn = true


func set_unworn() -> void:
	_is_worn = false


func get_save_state() -> Dictionary:
	var state := super.get_save_state()
	if _is_worn:
		state["is_worn"] = true
		state["pre_wear_scale"] = [_pre_wear_scale.x, _pre_wear_scale.y, _pre_wear_scale.z]
		state["pre_wear_rotation"] = [_pre_wear_rotation.x, _pre_wear_rotation.y, _pre_wear_rotation.z]
	return state


func apply_save_state(state: Dictionary) -> void:
	if not state.get("is_worn", false):
		super.apply_save_state(state)
		return
	if state.has("interaction_enabled") and not _is_managed_by_door_state():
		set_interaction_enabled(bool(state["interaction_enabled"]))
	var pickup_root := get_pickup_root()
	if pickup_root != null:
		if state.has("pre_wear_scale"):
			var s: Array = state["pre_wear_scale"]
			pickup_root.scale = Vector3(float(s[0]), float(s[1]), float(s[2]))
		if state.has("pre_wear_rotation"):
			var r: Array = state["pre_wear_rotation"]
			pickup_root.rotation = Vector3(float(r[0]), float(r[1]), float(r[2]))
	set_held(false)
