extends StaticBody3D

const SPIN_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/metal_squeak.wav")

@export_group("Spin")
@export var spin_degrees_per_click := 540.0
@export var spin_duration := 5.2

@export_group("Audio")
@export var spin_sound: AudioStream = SPIN_SOUND_DEFAULT
@export var spin_sound_volume_db := -8.0
@export var spin_sound_pitch_min := 0.94
@export var spin_sound_pitch_max := 1.06
@export_group("")

var _interactable: Interactable
var _spin_tween: Tween
var _audio_player: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_interactable = get_node_or_null("Interactable") as Interactable
	if _interactable != null and not _interactable.clicked.is_connected(_on_interactable_clicked):
		_interactable.clicked.connect(_on_interactable_clicked)
	_ensure_audio_player()


func _on_interactable_clicked(_interactable_ref: Interactable, _actor: Node) -> void:
	spin()


func spin() -> void:
	if _spin_tween != null and _spin_tween.is_running():
		_spin_tween.kill()

	var target_rotation_y := rotation.y - deg_to_rad(spin_degrees_per_click)
	_spin_tween = create_tween()
	_spin_tween.set_trans(Tween.TRANS_QUART)
	_spin_tween.set_ease(Tween.EASE_OUT)
	_spin_tween.tween_property(self, "rotation:y", target_rotation_y, spin_duration)
	_play_spin_sound()


func _ensure_audio_player() -> void:
	if _audio_player != null:
		return
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "SpinAudio"
	_audio_player.max_distance = 14.0
	_audio_player.bus = _resolve_sfx_bus_name()
	add_child(_audio_player)


func _play_spin_sound() -> void:
	if spin_sound == null:
		return
	_ensure_audio_player()
	if _audio_player.playing:
		return
	_audio_player.stream = spin_sound
	_audio_player.volume_db = spin_sound_volume_db
	_audio_player.pitch_scale = _rng.randf_range(
		minf(spin_sound_pitch_min, spin_sound_pitch_max),
		maxf(spin_sound_pitch_min, spin_sound_pitch_max)
	)
	_audio_player.play()


func _resolve_sfx_bus_name() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
