extends Node3D

@export var interactable_path: NodePath = NodePath("Interactable")
@export var armature_path: NodePath = NodePath("Node3D/Armature")

var _interactable: Interactable
var _armature: Node3D


func _ready() -> void:
	_armature = get_node_or_null(armature_path) as Node3D
	if _armature != null:
		_armature.visible = false

	_interactable = get_node_or_null(interactable_path) as Interactable
	if _interactable == null:
		return

	if _interactable.has_signal("picked_up") and not _interactable.picked_up.is_connected(_on_picked_up):
		_interactable.picked_up.connect(_on_picked_up)
	if _interactable.has_signal("dropped") and not _interactable.dropped.is_connected(_on_dropped):
		_interactable.dropped.connect(_on_dropped)


func _on_picked_up(_interactable_ref, _actor) -> void:
	if _armature != null:
		_armature.visible = true


func _on_dropped(_interactable_ref, _actor) -> void:
	if _armature != null:
		_armature.visible = false
