extends InteractionBehavior
class_name Beatle

const HELICOPTER_MOUTH_SFX := preload("res://assets/sound/helicopter-mouth.mp3")

@export var missing_fin_path: NodePath = NodePath("Node3D/missing_fin")
@export var propeller_path: NodePath = NodePath("Node3D/prepeller")
@export var focus_target_path: NodePath = NodePath("FocusTarget")
@export var interactable_path: NodePath = NodePath("Interactable")
@export var printed_fin_item_id := "printed_fin"
@export var propeller_item_id := "propeller"
@export var spin_duration := 4.5
@export var spin_degrees := 2160.0
@export var ready_prompt_action := "Spin propeller"

var _printed_fin_applied := false
var _propeller_applied := false
var _is_spinning := false

@onready var _missing_fin: Node3D = get_node_or_null(missing_fin_path) as Node3D
@onready var _propeller: Node3D = get_node_or_null(propeller_path) as Node3D
@onready var _focus_target: Node = get_node_or_null(focus_target_path)
@onready var _interactable: Interactable = get_node_or_null(interactable_path) as Interactable

var _audio_player: AudioStreamPlayer3D


func _ready() -> void:
	_ensure_audio_player()
	_update_visual_state()
	if _is_ready():
		_enable_click_mode()


func on_interacted(_actor: Node) -> void:
	if not _is_ready() or _is_spinning or _propeller == null:
		return
	_is_spinning = true
	if _audio_player != null:
		_audio_player.play()
	var start_z := _propeller.rotation_degrees.z
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_propeller, "rotation_degrees:z", start_z + spin_degrees, maxf(0.01, spin_duration))
	tween.finished.connect(func() -> void:
		_is_spinning = false
	)


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
	if _is_ready():
		_enable_click_mode()
	return true


func _update_visual_state() -> void:
	if _missing_fin != null:
		_missing_fin.visible = _printed_fin_applied
	if _propeller != null:
		_propeller.visible = _propeller_applied


func _is_ready() -> bool:
	return _printed_fin_applied and _propeller_applied


func _enable_click_mode() -> void:
	if _focus_target != null and is_instance_valid(_focus_target):
		_focus_target.queue_free()
		_focus_target = null
	if _interactable != null and is_instance_valid(_interactable):
		_interactable.prompt_action = ready_prompt_action


func _ensure_audio_player() -> void:
	if _audio_player != null:
		return
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.stream = HELICOPTER_MOUTH_SFX
	_audio_player.volume_db = -4.0
	add_child(_audio_player)
