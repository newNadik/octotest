extends InteractionBehavior
class_name EquipmentSwitchController

const CLICK_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/light-switch.wav")

@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var animation_name: StringName = &"Take 01"
@export var switch_button_path: NodePath = NodePath("power_switch/button")
@export var interactable_path: NodePath = NodePath("Interactable")
@export var off_button_x_degrees := -97.0
@export var on_button_x_degrees := -85.0
@export var off_prompt_action := "Turn On"
@export var on_prompt_action := "Turn Off"
@export var start_on := false
@export var click_sound: AudioStream = CLICK_SOUND_DEFAULT
@export var click_sound_volume_db := -7.0
@export var click_pitch_min := 0.97
@export var click_pitch_max := 1.03

var _is_on := false
var _click_player: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()

@onready var _animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer
@onready var _switch_button: Node3D = get_node_or_null(switch_button_path) as Node3D
@onready var _interactable: Interactable = get_node_or_null(interactable_path) as Interactable


func _ready() -> void:
	add_to_group("save_state_provider")
	_rng.randomize()
	_is_on = start_on
	_ensure_audio_player()
	if _animation_player != null and not _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.connect(_on_animation_finished)
	_apply_state()


func on_interacted(_actor: Node) -> void:
	_play_click_sound()
	set_on(not _is_on)


func set_on(next_is_on: bool) -> void:
	if _is_on == next_is_on:
		return
	_is_on = next_is_on
	_apply_state()


func _apply_state() -> void:
	if _switch_button != null:
		var btn_rotation := _switch_button.rotation_degrees
		btn_rotation.x = on_button_x_degrees if _is_on else off_button_x_degrees
		_switch_button.rotation_degrees = btn_rotation

	if _animation_player != null:
		if _is_on:
			_animation_player.play(animation_name)
		else:
			_animation_player.stop()
			_animation_player.seek(0.0, true)

	if _interactable != null and is_instance_valid(_interactable):
		_interactable.prompt_action = on_prompt_action if _is_on else off_prompt_action


func get_save_state() -> Dictionary:
	return {
		"is_on": _is_on,
	}


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_is_on = bool(state.get("is_on", _is_on))
	_apply_state()


func _ensure_audio_player() -> void:
	if _click_player != null:
		return
	_click_player = AudioStreamPlayer3D.new()
	_click_player.name = "SwitchClickAudio"
	_click_player.stream = click_sound
	_click_player.volume_db = click_sound_volume_db
	_click_player.max_distance = 12.0
	_click_player.bus = _resolve_sfx_bus_name()
	add_child(_click_player)


func _play_click_sound() -> void:
	if click_sound == null:
		return
	_ensure_audio_player()
	_click_player.stream = click_sound
	_click_player.volume_db = click_sound_volume_db
	_click_player.pitch_scale = _rng.randf_range(minf(click_pitch_min, click_pitch_max), maxf(click_pitch_min, click_pitch_max))
	_click_player.play()


func _resolve_sfx_bus_name() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"


func _on_animation_finished(finished_animation: StringName) -> void:
	if _is_on and _animation_player != null and finished_animation == animation_name:
		_animation_player.play(animation_name)
