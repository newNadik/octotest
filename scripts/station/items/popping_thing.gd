extends InteractionBehavior

const PICK_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/pick.wav")

@export var animation_node_path: NodePath = NodePath("Node3D")
@export var default_mesh_path: NodePath = NodePath("Node3D/defaultMaterial")
@export var pressed_mesh_path: NodePath = NodePath("Node3D/defaultMaterial_001")
@export var squash_duration := 0.09
@export var recover_duration := 0.13
@export var pressed_hold_duration := 0.12
@export var press_sound: AudioStream = PICK_SOUND_DEFAULT
@export var press_sound_volume_db := -9.0

var is_pressed := false
var _anim_node: Node3D
var _default_mesh: MeshInstance3D
var _pressed_mesh: MeshInstance3D
var _interactable: Interactable
var _base_scale := Vector3.ONE
var _active_tween: Tween
var _release_tween: Tween
var _is_pointer_holding := false
var _press_player: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("save_state_provider")
	_anim_node = get_node_or_null(animation_node_path) as Node3D
	_default_mesh = get_node_or_null(default_mesh_path) as MeshInstance3D
	_pressed_mesh = get_node_or_null(pressed_mesh_path) as MeshInstance3D
	_interactable = get_node_or_null("Interactable") as Interactable

	if _anim_node != null:
		_base_scale = _anim_node.scale
	if _pressed_mesh != null:
		_pressed_mesh.visible = false
	if _interactable != null and not _interactable.clicked.is_connected(_on_interactable_clicked):
		_interactable.clicked.connect(_on_interactable_clicked)
	if _interactable != null and not _interactable.input_event.is_connected(_on_interactable_input_event):
		_interactable.input_event.connect(_on_interactable_input_event)
	_ensure_audio_player()

	_apply_visual_state(false)


func _input(event: InputEvent) -> void:
	if not _is_pointer_holding:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			return
		_release_pointer_press()
		return
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			return
		_release_pointer_press()
		return


func on_interacted(_actor: Node) -> void:
	if _is_pointer_holding:
		return
	is_pressed = true
	_play_press_sound()
	_play_pop_animation()
	_set_pressed_visual(true)
	_schedule_release()


func get_save_state() -> Dictionary:
	return {
		"is_pressed": is_pressed,
	}


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	is_pressed = bool(state.get("is_pressed", false))
	_apply_visual_state(true)


func _play_pop_animation() -> void:
	if _anim_node == null:
		return
	if _active_tween != null:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_anim_node, "scale", _base_scale * Vector3(0.9, 1.08, 0.9), squash_duration)
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.tween_property(_anim_node, "scale", _base_scale, recover_duration)


func _crossfade_to_state(show_pressed: bool) -> void:
	_set_pressed_visual(show_pressed)


func _set_pressed_visual(show_pressed: bool) -> void:
	if _default_mesh == null or _pressed_mesh == null:
		return
	_default_mesh.visible = not show_pressed
	_pressed_mesh.visible = show_pressed


func _schedule_release() -> void:
	if _release_tween != null:
		_release_tween.kill()
	_release_tween = create_tween()
	_release_tween.tween_interval(maxf(0.01, pressed_hold_duration))
	_release_tween.finished.connect(func() -> void:
		is_pressed = false
		_set_pressed_visual(false)
	)


func _on_interactable_clicked(_interactable_ref: Interactable, actor: Node) -> void:
	on_interacted(actor)


func _on_interactable_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_pointer_press()
		else:
			_release_pointer_press()
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_pointer_press()
		else:
			_release_pointer_press()
		return


func _begin_pointer_press() -> void:
	_is_pointer_holding = true
	is_pressed = true
	if _release_tween != null:
		_release_tween.kill()
	_play_press_sound()
	_set_pressed_visual(true)
	_play_pop_animation()


func _release_pointer_press() -> void:
	_is_pointer_holding = false
	is_pressed = false
	_set_pressed_visual(false)


func _ensure_audio_player() -> void:
	if _press_player != null:
		return
	_press_player = AudioStreamPlayer3D.new()
	_press_player.name = "PressAudio"
	_press_player.stream = press_sound
	_press_player.volume_db = press_sound_volume_db
	_press_player.max_distance = 18.0
	_press_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_press_player)


func _play_press_sound() -> void:
	if press_sound == null:
		return
	_ensure_audio_player()
	_press_player.stream = press_sound
	_press_player.volume_db = press_sound_volume_db
	_press_player.pitch_scale = 1.0
	_press_player.play()


func _apply_visual_state(immediate: bool) -> void:
	if _default_mesh == null or _pressed_mesh == null:
		return

	if immediate:
		_set_pressed_visual(is_pressed)
		return

	_default_mesh.visible = true
	_pressed_mesh.visible = false
