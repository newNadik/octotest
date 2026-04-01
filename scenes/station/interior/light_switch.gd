# LightSwitch.gd
extends Node3D
class_name LightSwitch

signal toggled(is_on: bool)

@export var start_on := true
var is_on := true
var _interactable: Interactable

func _ready() -> void:
	is_on = start_on
	_interactable = get_node_or_null("Interactable") as Interactable
	if _interactable != null and not _interactable.clicked.is_connected(_on_interactable_clicked):
		_interactable.clicked.connect(_on_interactable_clicked)
	_apply_visual()

# Call this from click/input/raycast interaction
func interact() -> void:
	is_on = !is_on
	_apply_visual()
	toggled.emit(is_on)


func _on_interactable_clicked(_interactable_ref: Interactable, _actor: Node) -> void:
	interact()


func _apply_visual() -> void:
	# Optional: animate switch mesh, play sound, etc.
	pass
