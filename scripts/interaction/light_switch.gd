# LightSwitch.gd
extends Node3D
class_name LightSwitch

const CLICK_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/light-switch.wav")

signal toggled(is_on: bool)

@export var start_on := false
@export var click_sound: AudioStream = CLICK_SOUND_DEFAULT
@export var click_sound_volume_db := -7.0
@export var click_pitch_min := 0.97
@export var click_pitch_max := 1.03
var is_on := true
var _interactable: Interactable
var _click_player: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("save_state_provider")
	_rng.randomize()
	is_on = start_on
	_interactable = get_node_or_null("Interactable") as Interactable
	if _interactable != null and not _interactable.clicked.is_connected(_on_interactable_clicked):
		_interactable.clicked.connect(_on_interactable_clicked)
	_ensure_audio_player()
	_apply_visual()

# Call this from click/input/raycast interaction
func interact() -> void:
	_play_click_sound()
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
	# Save-load restoration should not retrigger startup/toggle effects.
	set_switch_state(bool(state.get("is_on", start_on)), false)


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
