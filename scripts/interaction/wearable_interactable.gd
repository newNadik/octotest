extends Interactable
class_name WearableInteractable

enum WearSlot { HAT, GLASSES }

@export var wear_slot: WearSlot = WearSlot.HAT
@export var wear_offset := Vector3.ZERO
@export var wear_rotation_degrees := Vector3.ZERO
@export var wear_scale := 1.0

func get_wear_slot_name() -> String:
	match wear_slot:
		WearSlot.HAT: return "hat"
		WearSlot.GLASSES: return "glasses"
	return "hat"
