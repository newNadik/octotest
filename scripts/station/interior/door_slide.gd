extends Node3D

const SLIDE_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/sliding-noise.wav")

signal open_requested(source: Node)
signal door_opened(source: Node)

@export var open_distance := 1.35
@export var open_duration := 0.55
@export var close_duration := 0.55
@export var auto_close_delay := 2.8
@export var auto_close_retry_interval := 0.65
@export var locked := false
@export_group("Audio")
@export var slide_sound: AudioStream = SLIDE_SOUND_DEFAULT
@export var slide_sound_volume_db := -6.0
@export var slide_sound_pitch_scale := 1.0
@export var slide_sound_pitch_min := 0.94
@export var slide_sound_pitch_max := 1.08
@export var slide_sound_volume_jitter_db := 1.5

@onready var _door_body: Node3D = $StaticBody3D
@onready var _button_mesh: MeshInstance3D = $StaticBody3D/button
@onready var _interactable: Interactable = $Interactable
@onready var _close_sensor: Area3D = $CloseSensor

var _closed_position := Vector3.ZERO
var _is_open := false
var _is_moving := false
var _auto_close_ticket := 0
var _group_highlight := false
var _group_visual_override_active := false
var _slide_player: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _button_green_material: StandardMaterial3D
var _button_red_material: StandardMaterial3D
var _button_green_highlight_material: StandardMaterial3D
var _button_red_highlight_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("save_state_provider")
	add_to_group("autosave_door")
	_rng.randomize()
	_closed_position = _door_body.position
	if _close_sensor != null:
		# Player is on layer 4, loose items are on layer 8.
		_close_sensor.collision_mask = 12
	_build_button_materials()
	_update_button_state()
	_ensure_audio_player()
	if _interactable != null and not _interactable.clicked.is_connected(_on_door_clicked):
		_interactable.clicked.connect(_on_door_clicked)


func open() -> void:
	if not can_open():
		return
	_auto_close_ticket += 1
	_animate_open()


func can_open() -> bool:
	return not locked and not _is_moving and not _is_open


func set_locked(value: bool) -> void:
	locked = value
	_update_button_state()


func lock() -> void:
	set_locked(true)


func unlock() -> void:
	set_locked(false)


func is_locked() -> bool:
	return locked


func set_open_distance(value: float) -> void:
	open_distance = maxf(0.01, value)


func set_group_highlight(active: bool) -> void:
	if _group_highlight == active:
		return
	_group_highlight = active
	_update_button_state()


func is_highlight_active_for_group() -> bool:
	if _interactable == null:
		return false
	if not _interactable.has_method("get_visual_state"):
		return false
	if _group_visual_override_active:
		return false
	var state := int(_interactable.call("get_visual_state"))
	return state == Interactable.VisualState.HOVERED \
		or state == Interactable.VisualState.IN_RANGE \
		or state == Interactable.VisualState.BLOCKED


func get_group_visual_state() -> int:
	if _interactable == null:
		return Interactable.VisualState.IDLE
	if not _interactable.has_method("get_visual_state"):
		return Interactable.VisualState.IDLE
	return int(_interactable.call("get_visual_state"))


func apply_group_visual_state(state: int, active: bool) -> void:
	if _interactable == null:
		return
	_group_visual_override_active = active
	var desired_state := Interactable.VisualState.IDLE
	if active:
		match state:
			Interactable.VisualState.HOVERED:
				desired_state = Interactable.VisualState.HOVERED
			Interactable.VisualState.IN_RANGE:
				desired_state = Interactable.VisualState.IN_RANGE
			Interactable.VisualState.BLOCKED:
				desired_state = Interactable.VisualState.BLOCKED
			_:
				desired_state = Interactable.VisualState.IDLE
	_interactable.set_visual_state(desired_state)


func clear_group_visual_state() -> void:
	if _interactable == null:
		return
	_group_visual_override_active = false


func get_interactable() -> Interactable:
	return _interactable


func close_if_clear() -> void:
	if not _is_open or _is_moving:
		return
	if _is_close_blocked_for_group():
		_schedule_auto_close(auto_close_retry_interval)
		return
	_animate_close()


func _on_door_clicked(_interactable_ref: Interactable, _actor: Node) -> void:
	emit_signal("open_requested", self)
	open()


func _animate_open() -> void:
	_is_moving = true
	_update_button_state()
	_play_slide_sound()

	var open_position := _closed_position + Vector3(-open_distance, 0.0, 0.0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(_door_body, "position", open_position, open_duration)
	tween.finished.connect(_on_open_tween_finished)


func _on_open_tween_finished() -> void:
	_is_open = true
	_is_moving = false
	_stop_slide_sound()
	_update_button_state()
	emit_signal("door_opened", self)
	_schedule_auto_close(auto_close_delay)


func _animate_close() -> void:
	_is_moving = true
	_update_button_state()
	_play_slide_sound()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(_door_body, "position", _closed_position, close_duration)
	tween.finished.connect(_on_close_tween_finished)


func _on_close_tween_finished() -> void:
	_is_open = false
	_is_moving = false
	_stop_slide_sound()
	_update_button_state()


func _schedule_auto_close(delay: float) -> void:
	if not _is_open:
		return
	var ticket := _auto_close_ticket
	var timer := get_tree().create_timer(maxf(0.01, delay))
	timer.timeout.connect(func() -> void:
		if ticket != _auto_close_ticket:
			return
		close_if_clear()
	)


func _is_doorway_blocked() -> bool:
	if _close_sensor == null:
		return false
	for body in _close_sensor.get_overlapping_bodies():
		if body == null or not is_instance_valid(body):
			continue
		if not (body is Node):
			continue
		var body_node := body as Node
		if body_node == self or is_ancestor_of(body_node) or body_node.is_ancestor_of(self):
			continue
		if body is CharacterBody3D:
			return true
		if body is RigidBody3D:
			return true
	return false


func is_doorway_blocked() -> bool:
	return _is_doorway_blocked()


func _is_close_blocked_for_group() -> bool:
	if _is_doorway_blocked():
		return true
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_method("is_group_doorway_blocked"):
		return bool(parent_node.call("is_group_doorway_blocked"))
	return false


func _update_button_state() -> void:
	if _button_mesh == null:
		return
	if _button_green_material == null or _button_red_material == null \
		or _button_green_highlight_material == null or _button_red_highlight_material == null:
		_build_button_materials()

	var door_can_open := can_open()
	if door_can_open:
		_button_mesh.material_override = _button_green_highlight_material if _group_highlight else _button_green_material
	else:
		_button_mesh.material_override = _button_red_highlight_material if _group_highlight else _button_red_material
	if _interactable != null:
		_interactable.set_interaction_enabled(door_can_open)
		_interactable.prompt_action = "Open" if door_can_open else "Locked"


func _build_button_materials() -> void:
	_button_green_material = StandardMaterial3D.new()
	_button_green_material.albedo_color = Color("#3ed180")
	_button_green_material.emission_enabled = true
	_button_green_material.emission = Color("#1f6e44")
	_button_green_material.metallic = 0.15
	_button_green_material.roughness = 0.52

	_button_green_highlight_material = _button_green_material.duplicate()
	_button_green_highlight_material.albedo_color = _button_green_material.albedo_color.lightened(0.32)
	_button_green_highlight_material.emission = _button_green_material.emission.lightened(0.45)

	_button_red_material = StandardMaterial3D.new()
	_button_red_material.albedo_color = Color("#de3d4d")
	_button_red_material.emission_enabled = true
	_button_red_material.emission = Color("#7a1f2b")
	_button_red_material.metallic = 0.15
	_button_red_material.roughness = 0.52

	_button_red_highlight_material = _button_red_material.duplicate()
	_button_red_highlight_material.albedo_color = _button_red_material.albedo_color.lightened(0.32)
	_button_red_highlight_material.emission = _button_red_material.emission.lightened(0.45)


func get_save_state() -> Dictionary:
	return {
		"locked": locked,
		"is_open": _is_open
	}


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	if state.has("locked"):
		set_locked(bool(state["locked"]))
	var should_be_open := bool(state.get("is_open", false))
	_set_open_state_immediate(should_be_open)


func _set_open_state_immediate(is_open: bool) -> void:
	_auto_close_ticket += 1
	_is_moving = false
	_stop_slide_sound()
	_is_open = is_open and not locked
	if _door_body != null:
		if _is_open:
			_door_body.position = _closed_position + Vector3(-open_distance, 0.0, 0.0)
		else:
			_door_body.position = _closed_position
	_update_button_state()
	if _is_open:
		_schedule_auto_close(auto_close_delay)


func _ensure_audio_player() -> void:
	if _slide_player != null:
		return
	_slide_player = AudioStreamPlayer3D.new()
	_slide_player.name = "SlideAudio"
	_slide_player.stream = slide_sound
	_slide_player.volume_db = slide_sound_volume_db
	_slide_player.pitch_scale = slide_sound_pitch_scale
	_slide_player.max_distance = 16.0
	_slide_player.bus = _resolve_sfx_bus_name()
	if _door_body != null:
		_door_body.add_child(_slide_player)
	else:
		add_child(_slide_player)


func _play_slide_sound() -> void:
	if slide_sound == null:
		return
	_ensure_audio_player()
	_slide_player.stream = slide_sound
	var random_volume_jitter := _rng.randf_range(-absf(slide_sound_volume_jitter_db), absf(slide_sound_volume_jitter_db))
	_slide_player.volume_db = slide_sound_volume_db + random_volume_jitter
	var random_pitch := _rng.randf_range(minf(slide_sound_pitch_min, slide_sound_pitch_max), maxf(slide_sound_pitch_min, slide_sound_pitch_max))
	_slide_player.pitch_scale = slide_sound_pitch_scale * random_pitch
	if _slide_player.playing:
		_slide_player.stop()
	_slide_player.play()


func _stop_slide_sound() -> void:
	if _slide_player == null:
		return
	if _slide_player.playing:
		_slide_player.stop()


func _resolve_sfx_bus_name() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
