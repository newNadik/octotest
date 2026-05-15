extends Node3D
class_name RorySystemsRoomReaction

const REACTION_DELAY := 0.7

@export var light_switch: LightSwitch
@export var flashlight: SpotLight3D

const _DUCK_DB := -10.0
const _DUCK_FADE := 0.35

const _DIALOGUE_STREAM: AudioStream = preload("res://assets/sound/rory/who_tuned_out_the_light.mp3")
const _CLICK_STREAM: AudioStream = preload("res://assets/sound/flashlight-click.mp3")
const _DIALOGUE_TEXT := "Hey, who turned out the lights?"

var _player: AudioStreamPlayer3D
var _sfx_player: AudioStreamPlayer3D
var _is_talking := false
var _duck_tween: Tween


func _ready() -> void:
	_player = AudioStreamPlayer3D.new()
	_player.name = "RoryVoiceAudio"
	_player.bus = "Voice"
	_player.volume_db = 30.0
	_player.max_distance = 20.0
	_player.unit_size = 5.0
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_player.finished.connect(_on_dialogue_finished)
	add_child(_player)

	_sfx_player = AudioStreamPlayer3D.new()
	_sfx_player.name = "FlashlightClickAudio"
	_sfx_player.stream = _CLICK_STREAM
	_sfx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	_sfx_player.volume_db = 5.0
	_sfx_player.max_distance = 15.0
	_sfx_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_sfx_player)

	if light_switch != null:
		light_switch.toggled.connect(_on_light_toggled)


func _on_light_toggled(is_on: bool) -> void:
	if is_on or _is_talking:
		return

	_is_talking = true
	await get_tree().create_timer(REACTION_DELAY).timeout
	_play(_DIALOGUE_STREAM, _DIALOGUE_TEXT)


func _on_dialogue_finished() -> void:
	_is_talking = false
	_set_music_duck(false)
	if flashlight != null and flashlight.light_energy == 0.0:
		flashlight.light_energy = 15.0
		_sfx_player.play()


func _play(stream: AudioStream, subtitle_text: String) -> void:
	if stream == null:
		_is_talking = false
		return
	_player.stream = stream
	_player.play()
	_set_music_duck(true)
	if not subtitle_text.is_empty():
		var display := get_tree().get_first_node_in_group("subtitle_display") as SubtitleDisplay
		if display != null:
			display.show_line(tr(subtitle_text), stream.get_length())


func _set_music_duck(duck: bool) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx < 0:
		return
	var settings := get_node_or_null("/root/GameSettings")
	var base_db := 0.0
	if settings != null and settings.has_method("get_music_volume"):
		var linear := float(settings.call("get_music_volume"))
		base_db = -80.0 if linear <= 0.0 else linear_to_db(linear)
	var target_db := base_db + (_DUCK_DB if duck else 0.0)
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(bus_idx, db),
		AudioServer.get_bus_volume_db(bus_idx),
		target_db,
		_DUCK_FADE
	)
