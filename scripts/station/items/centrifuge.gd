extends StaticBody3D

const CENTRIFUGE_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/santrifuj.mp3")

@export_group("Animation")
@export var animation_player_path: NodePath = NodePath("Sketchfab_Scene/AnimationPlayer")
@export var animation_name := ""

@export_group("Audio")
@export var spin_sound: AudioStream = CENTRIFUGE_SOUND_DEFAULT
@export var spin_sound_volume_db := -8.0
@export var spin_sound_pitch_min := 0.98
@export var spin_sound_pitch_max := 1.03
@export_group("")

var _interactable: Interactable
var _animation_player: AnimationPlayer
var _audio_player: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _is_playing := false


func _ready() -> void:
	_rng.randomize()
	_interactable = get_node_or_null("Interactable") as Interactable
	_animation_player = _resolve_animation_player()
	if _interactable != null and not _interactable.clicked.is_connected(_on_interactable_clicked):
		_interactable.clicked.connect(_on_interactable_clicked)
	_ensure_audio_player()


func _on_interactable_clicked(_interactable_ref: Interactable, _actor: Node) -> void:
	_play_scene_animation_once()


func _play_scene_animation_once() -> void:
	if _is_playing:
		return
	if _animation_player == null:
		return

	var clip_name := _resolve_animation_name()
	if clip_name.is_empty():
		return

	_is_playing = true
	if _interactable != null:
		_interactable.set_interaction_enabled(false)
	_play_spin_sound()
	_animation_player.stop()
	_animation_player.play(clip_name)

	var clip := _animation_player.get_animation(clip_name)
	if clip != null and clip.loop_mode != Animation.LOOP_NONE:
		await get_tree().create_timer(maxf(0.01, clip.length)).timeout
		_animation_player.stop()
	else:
		await _animation_player.animation_finished
	_is_playing = false
	if _interactable != null:
		_interactable.set_interaction_enabled(true)


func _ensure_audio_player() -> void:
	if _audio_player != null:
		return
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "CentrifugeAudio"
	_audio_player.max_distance = 14.0
	_audio_player.bus = _resolve_sfx_bus_name()
	add_child(_audio_player)


func _play_spin_sound() -> void:
	if spin_sound == null:
		return
	_ensure_audio_player()
	_audio_player.stop()
	_audio_player.stream = spin_sound
	_audio_player.volume_db = spin_sound_volume_db
	_audio_player.pitch_scale = _rng.randf_range(
		minf(spin_sound_pitch_min, spin_sound_pitch_max),
		maxf(spin_sound_pitch_min, spin_sound_pitch_max)
	)
	_audio_player.play()


func _resolve_sfx_bus_name() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"


func _resolve_animation_player() -> AnimationPlayer:
	if not animation_player_path.is_empty():
		var explicit := get_node_or_null(animation_player_path) as AnimationPlayer
		if explicit != null:
			return explicit
	for node in find_children("*", "AnimationPlayer", true, false):
		if node is AnimationPlayer:
			return node as AnimationPlayer
	return null


func _resolve_animation_name() -> StringName:
	if _animation_player == null:
		return StringName("")
	if not animation_name.is_empty():
		return StringName(animation_name)
	var names := _animation_player.get_animation_list()
	if names.is_empty():
		return StringName("")
	return names[0]
