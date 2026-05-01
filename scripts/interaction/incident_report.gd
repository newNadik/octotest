extends Node3D
class_name IncidentReport

const FOLDER_ANIMATION := "folder_animation"
const DOC_TWEEN_DURATION := 0.3
const FOLDER_ANIMATION_SPEED := 1.8
const PAGE_FLIP_SOUND := preload("res://assets/sound/page_flip.wav")

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _interactable: Interactable = $Interactable
@onready var _focus_target: FocusTarget = $FocusTarget

var _document_interactables: Array[Interactable] = []
var _documents: Array[Node3D] = []
var _doc_initial_positions: Array[Vector3] = []
var _doc_initial_rotations: Array[Vector3] = []
var _stage := 0
var _busy := false
var _page_flip_player: AudioStreamPlayer3D


func _ready() -> void:
	_collect_documents()
	_setup_focus_angles()
	_setup_page_flip_player()
	_set_documents_interaction_enabled(false)
	_set_documents_indicators_visible(false)
	if _interactable != null and not _interactable.clicked.is_connected(_on_interactable_clicked):
		_interactable.clicked.connect(_on_interactable_clicked)


func _on_interactable_clicked(_interactable_ref: Interactable, _actor: Node) -> void:
	if _busy:
		return
	match _stage:
		0:
			_open_folder_stage()
		1:
			_reveal_second_document_stage()
		2:
			_reveal_third_document_stage()
		3:
			_reset_and_close_stage()


func _collect_documents() -> void:
	_document_interactables.clear()
	_documents.clear()
	_doc_initial_positions.clear()
	_doc_initial_rotations.clear()
	for child in get_children():
		if not (child is Node3D):
			continue
		if child.name.begins_with("DocumentItem"):
			var doc := child as Node3D
			_documents.append(doc)
			_doc_initial_positions.append(doc.position)
			_doc_initial_rotations.append(doc.rotation_degrees)
		var interactable := child.get_node_or_null("Interactable") as Interactable
		if interactable == null:
			continue
		_document_interactables.append(interactable)
	_documents.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return String(a.name) < String(b.name)
	)


func _set_documents_interaction_enabled(is_enabled: bool) -> void:
	for interactable in _document_interactables:
		if interactable == null:
			continue
		interactable.set_interaction_enabled(is_enabled)


func _set_documents_indicators_visible(is_visible: bool) -> void:
	for interactable in _document_interactables:
		if interactable == null:
			continue
		interactable.set_indicator_visible(is_visible)


func _open_folder_stage() -> void:
	if _animation_player == null or _focus_target == null:
		return
	_busy = true
	_animation_player.play(FOLDER_ANIMATION, -1.0, FOLDER_ANIMATION_SPEED)
	var duration := _get_animation_length(FOLDER_ANIMATION)
	await get_tree().create_timer(duration + 0.03).timeout
	_stage = 1
	_busy = false


func _reveal_second_document_stage() -> void:
	if _documents.size() < 2:
		return
	_busy = true
	_play_page_flip()
	var doc1 := _documents[0]
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(doc1, "position", _doc_initial_positions[0] + Vector3(-0.76, 0.0, 0.02), DOC_TWEEN_DURATION)
	await tween.finished
	_stage = 2
	_busy = false


func _reveal_third_document_stage() -> void:
	if _documents.size() < 3:
		return
	_busy = true
	_play_page_flip()
	var doc2 := _documents[1]
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(doc2, "position", _doc_initial_positions[1] + Vector3(0.0, 0.025, 0.0), DOC_TWEEN_DURATION * 0.55)
	tween.tween_property(doc2, "position", _doc_initial_positions[1] + Vector3(-0.76, 0.025, 0.03), DOC_TWEEN_DURATION * 0.9)
	await tween.finished
	_stage = 3
	_busy = false


func _reset_and_close_stage() -> void:
	_busy = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in range(min(_documents.size(), _doc_initial_positions.size())):
		var doc := _documents[i]
		if doc == null:
			continue
		tween.parallel().tween_property(doc, "position", _doc_initial_positions[i], DOC_TWEEN_DURATION)
		tween.parallel().tween_property(doc, "rotation_degrees", _doc_initial_rotations[i], DOC_TWEEN_DURATION)
	await tween.finished

	if _animation_player != null:
		_animation_player.play(FOLDER_ANIMATION, -1.0, -FOLDER_ANIMATION_SPEED, true)
		var duration := _get_animation_length(FOLDER_ANIMATION)
		await get_tree().create_timer(duration + 0.03).timeout
	_stage = 0
	_request_exit_focus_mode()
	_busy = false


func _get_animation_length(name: String) -> float:
	if _animation_player == null:
		return 0.0
	var animation := _animation_player.get_animation(name)
	if animation == null:
		return 0.0
	return animation.length / maxf(0.001, absf(FOLDER_ANIMATION_SPEED))


func _request_exit_focus_mode() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("exit_focus_mode"):
		scene.call("exit_focus_mode")


func _setup_page_flip_player() -> void:
	_page_flip_player = AudioStreamPlayer3D.new()
	_page_flip_player.stream = PAGE_FLIP_SOUND
	_page_flip_player.volume_db = -6.0
	_page_flip_player.max_distance = 18.0
	_page_flip_player.unit_size = 1.0
	add_child(_page_flip_player)


func _play_page_flip() -> void:
	if _page_flip_player == null:
		return
	_page_flip_player.pitch_scale = randf_range(0.95, 1.05)
	_page_flip_player.play()


func _setup_focus_angles() -> void:
	if _focus_target == null:
		return
	# Use the same stable reading orientation we use for document items.
	_focus_target.use_angle_override = true
	_focus_target.focus_yaw_degrees = wrapf(global_rotation_degrees.y - 180.0, -180.0, 180.0)
	_focus_target.focus_pitch_degrees = -90.0
	_focus_target.focus_roll_degrees = 180.0
	_focus_target.focus_zoom_start = 1.0
	_focus_target.focus_min_zoom = 0.25
	_focus_target.focus_max_zoom = 2.2
	_focus_target.focus_zoom_step = 0.08
