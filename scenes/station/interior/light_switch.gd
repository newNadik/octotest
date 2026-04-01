# LightSwitch.gd
extends Node3D
class_name LightSwitch

signal toggled(is_on: bool)

@export var start_on := true
var is_on := true
var _interactable: Interactable

func _ready() -> void:
	add_to_group("save_state_provider")
	is_on = start_on
	_interactable = get_node_or_null("Interactable") as Interactable
	if _interactable != null and not _interactable.clicked.is_connected(_on_interactable_clicked):
		_interactable.clicked.connect(_on_interactable_clicked)
	_apply_visual()

# Call this from click/input/raycast interaction
func interact() -> void:
	set_switch_state(not is_on, true)


func _on_interactable_clicked(_interactable_ref: Interactable, _actor: Node) -> void:
	interact()


func _apply_visual() -> void:
	# Optional: animate switch mesh, play sound, etc.
	pass


func set_switch_state(next_is_on: bool, emit_toggled: bool = true) -> void:
	if is_on == next_is_on:
		return
	is_on = next_is_on
	_apply_visual()
	if emit_toggled:
		toggled.emit(is_on)


func get_save_state() -> Dictionary:
	return {
		"is_on": is_on
	}


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	set_switch_state(bool(state.get("is_on", start_on)), true)
