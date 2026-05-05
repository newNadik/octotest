extends Node3D

const SLIDE_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/sliding-noise.wav")

signal open_requested(source: Node, actor: Node)
signal door_opened(source: Node)

enum TitleSide {
	FRONT,
	BACK,
}

@export var open_distance := 1.35
@export var open_duration := 0.55
@export var close_duration := 0.55
@export var auto_close_delay := 2.8
@export var auto_close_retry_interval := 0.65
@export var locked := false
@export_group("Metadata")
@export var privacy_glass_enabled := false
@export var door_title := ""
@export var title_side: TitleSide = TitleSide.FRONT
@export_group("Audio")
@export var slide_sound: AudioStream = SLIDE_SOUND_DEFAULT
@export var slide_sound_volume_db := -6.0
@export var slide_sound_pitch_scale := 1.0
@export var slide_sound_pitch_min := 0.94
@export var slide_sound_pitch_max := 1.08
@export var slide_sound_volume_jitter_db := 1.5

@onready var _door_body: Node3D = $StaticBody3D
@onready var _indicator_front: MeshInstance3D = get_node_or_null("StaticBody3D/door_indicator_front") as MeshInstance3D
@onready var _indicator_back: MeshInstance3D = get_node_or_null("StaticBody3D/door_indicator_back") as MeshInstance3D
@onready var _interactable: Interactable = $Interactable
@onready var _close_sensor: Area3D = $CloseSensor
@onready var _glass_mesh: MeshInstance3D = get_node_or_null("StaticBody3D/glass") as MeshInstance3D
@onready var _privacy_glass_mesh: MeshInstance3D = get_node_or_null("StaticBody3D/PrivacyGlassPlane") as MeshInstance3D
@onready var _title_front_label: Label3D = get_node_or_null("StaticBody3D/TitleFront") as Label3D
@onready var _title_back_label: Label3D = get_node_or_null("StaticBody3D/TitleBack") as Label3D

var _closed_position := Vector3.ZERO
var _is_open := false
var _is_moving := false
var _auto_close_ticket := 0
var _group_highlight := false
var _group_visual_override_active := false
var _slide_player: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _indicator_green_material: StandardMaterial3D
var _indicator_yellow_material: StandardMaterial3D
var _indicator_red_material: StandardMaterial3D
var _indicator_dark_material: StandardMaterial3D
var _indicator_green_highlight_material: StandardMaterial3D
var _indicator_yellow_highlight_material: StandardMaterial3D
var _indicator_red_highlight_material: StandardMaterial3D
var _allow_interaction_when_locked := false
var _is_access_disabled := false
var _blink_tween: Tween


func _ready() -> void:
	add_to_group("save_state_provider")
	add_to_group("autosave_door")
	_rng.randomize()
	_closed_position = _door_body.position
	if _close_sensor != null:
		# Player is on layer 4, loose items are on layer 8.
		_close_sensor.collision_mask = 12
	_build_indicator_materials()
	_update_button_state()
	_ensure_audio_player()
	_apply_metadata_visuals()
	if _interactable != null and not _interactable.clicked.is_connected(_on_door_clicked):
		_interactable.clicked.connect(_on_door_clicked)


func open() -> void:
	if not can_open():
		return
	_auto_close_ticket += 1
	_animate_open()


func force_open() -> void:
	if _is_moving or _is_open:
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


func set_allow_interaction_when_locked(value: bool) -> void:
	_allow_interaction_when_locked = value
	_update_button_state()


func set_access_disabled(value: bool) -> void:
	_is_access_disabled = value
	_update_button_state()


func trigger_indicator_blink(granted: bool) -> void:
	if _indicator_green_material == null:
		_build_indicator_materials()
	if _blink_tween != null and _blink_tween.is_running():
		_blink_tween.kill()
	var blink_mat := _indicator_green_material if granted else _indicator_red_material
	_blink_tween = create_tween()
	for _i in 2:
		_blink_tween.tween_callback(func(): _set_both_indicators(blink_mat))
		_blink_tween.tween_interval(0.13)
		_blink_tween.tween_callback(func(): _set_both_indicators(_indicator_dark_material))
		_blink_tween.tween_interval(0.08)
	_blink_tween.tween_callback(_update_button_state)


func _set_both_indicators(mat: StandardMaterial3D) -> void:
	if _indicator_front != null:
		_indicator_front.material_override = mat
	if _indicator_back != null:
		_indicator_back.material_override = mat


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


func _on_door_clicked(_interactable_ref: Interactable, actor: Node) -> void:
	emit_signal("open_requested", self, actor)
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_method("request_open_from_slide"):
		parent_node.call("request_open_from_slide", self, actor)
		return
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
	if _indicator_green_material == null:
		_build_indicator_materials()

	var door_can_open := can_open()
	var door_can_interact := (not _is_moving and not _is_open and (door_can_open or _allow_interaction_when_locked))

	# door_slide2 in a double door is rotated 180° (flipped X basis), so its
	# door_indicator_front faces inward. Swap outside/inside assignment for it.
	var flipped := transform.basis.x.dot(Vector3.RIGHT) < 0.0
	var outside_indicator := _indicator_back if flipped else _indicator_front
	var inside_indicator := _indicator_front if flipped else _indicator_back

	# Outside: green = unlocked, yellow = card required, red = disabled
	var outside_mat: StandardMaterial3D
	var outside_mat_hi: StandardMaterial3D
	if door_can_open:
		outside_mat = _indicator_green_material
		outside_mat_hi = _indicator_green_highlight_material
	elif _is_access_disabled:
		outside_mat = _indicator_red_material
		outside_mat_hi = _indicator_red_highlight_material
	elif _allow_interaction_when_locked:
		outside_mat = _indicator_yellow_material
		outside_mat_hi = _indicator_yellow_highlight_material
	else:
		outside_mat = _indicator_red_material
		outside_mat_hi = _indicator_red_highlight_material

	# Inside: green = accessible from inside (unlocked or card-locked), red = fully disabled
	var inside_mat: StandardMaterial3D
	var inside_mat_hi: StandardMaterial3D
	if door_can_open or (_allow_interaction_when_locked and not _is_access_disabled):
		inside_mat = _indicator_green_material
		inside_mat_hi = _indicator_green_highlight_material
	else:
		inside_mat = _indicator_red_material
		inside_mat_hi = _indicator_red_highlight_material

	if outside_indicator != null:
		outside_indicator.material_override = outside_mat_hi if _group_highlight else outside_mat
	if inside_indicator != null:
		inside_indicator.material_override = inside_mat_hi if _group_highlight else inside_mat

	if _interactable != null:
		_interactable.set_interaction_enabled(door_can_interact)
		if door_can_open:
			_interactable.prompt_action = "Open"
		elif _is_access_disabled:
			_interactable.prompt_action = "Locked"
		elif _allow_interaction_when_locked:
			_interactable.prompt_action = "Swipe Card"
		else:
			_interactable.prompt_action = "Locked"


func _build_indicator_materials() -> void:
	_indicator_dark_material = _make_indicator_material(Color(0.02, 0.02, 0.02, 1.0))
	_indicator_dark_material.emission_energy_multiplier = 0.05
	_indicator_green_material = _make_indicator_material(Color(0.2, 0.92, 0.3, 1.0))
	_indicator_green_highlight_material = _indicator_green_material.duplicate()
	_indicator_green_highlight_material.albedo_color = _indicator_green_material.albedo_color.lightened(0.32)
	_indicator_green_highlight_material.emission = _indicator_green_material.emission.lightened(0.45)

	_indicator_yellow_material = _make_indicator_material(Color(0.96, 0.84, 0.2, 1.0))
	_indicator_yellow_highlight_material = _indicator_yellow_material.duplicate()
	_indicator_yellow_highlight_material.albedo_color = _indicator_yellow_material.albedo_color.lightened(0.32)
	_indicator_yellow_highlight_material.emission = _indicator_yellow_material.emission.lightened(0.45)

	_indicator_red_material = _make_indicator_material(Color(0.9, 0.2, 0.2, 1.0))
	_indicator_red_highlight_material = _indicator_red_material.duplicate()
	_indicator_red_highlight_material.albedo_color = _indicator_red_material.albedo_color.lightened(0.32)
	_indicator_red_highlight_material.emission = _indicator_red_material.emission.lightened(0.45)


func _make_indicator_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	material.roughness = 0.35
	return material


func _apply_metadata_visuals() -> void:
	_apply_privacy_glass_visual()
	_apply_title_visual()


func apply_metadata_visuals() -> void:
	_apply_metadata_visuals()


func _apply_privacy_glass_visual() -> void:
	if _privacy_glass_mesh != null:
		_privacy_glass_mesh.visible = privacy_glass_enabled
	if _glass_mesh != null:
		_glass_mesh.visible = not privacy_glass_enabled


func _apply_title_visual() -> void:
	var localized_title := tr(door_title).strip_edges()
	var has_title := not localized_title.is_empty()
	if _title_front_label != null:
		_title_front_label.text = localized_title
		_title_front_label.visible = has_title and title_side == TitleSide.FRONT
	if _title_back_label != null:
		_title_back_label.text = localized_title
		_title_back_label.visible = has_title and title_side == TitleSide.BACK


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
