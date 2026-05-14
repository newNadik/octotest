extends Node3D
class_name NeilBedDialogue

const REACTION_DELAY := 0.7

@export var light_switch: LightSwitch

var on_count := 0
var off_count := 0

const DUCK_DB := -10.0
const DUCK_FADE := 0.35

var _player: AudioStreamPlayer3D
var _hide_timer: SceneTreeTimer
var _duck_tween: Tween
var _is_talking := false

const _ON_STREAMS: Array = [
	preload("res://assets/sound/neil_dialogue/light_switch_on_1.mp3"),
	preload("res://assets/sound/neil_dialogue/light_switch_on_2.mp3"),
	preload("res://assets/sound/neil_dialogue/light_switch_on_3.mp3"),
	preload("res://assets/sound/neil_dialogue/light_switch_on_4.mp3"),
	preload("res://assets/sound/neil_dialogue/light_switch_on_5.mp3"),
	preload("res://assets/sound/neil_dialogue/light_switch_on_6.mp3"),
	preload("res://assets/sound/neil_dialogue/light_switch_on_7.mp3"),
	preload("res://assets/sound/neil_dialogue/light_switch_on_8.mp3"),
]
const _ON_TEXTS: Array[String] = [
	"Mike, I told you... I have night shift. Please",
	"Seriously? I need to sleep",
	"Are you kidding me right now?",
	"Mike! What is WRONG with you?!",
	"I swear to god, Mike... I'm putting in a complaint",
	"THAT'S IT. I'm writing this down. Date, time, EVERYTHING",
	"You know what? Fine. FINE. You win. Hope you're happy",
	"You are being CHILDISH. I won't speak to you ever again. We're done. DONE",
]

# off_4 has no audio — slot is null/empty so the index stays aligned with off_count
const _OFF_STREAMS: Array = [
	preload("res://assets/sound/neil_dialogue/light_switch_off_1.mp3"),
	preload("res://assets/sound/neil_dialogue/light_switch_off_2.mp3"),
	preload("res://assets/sound/neil_dialogue/light_switch_off_3.mp3"),
	null,
	preload("res://assets/sound/neil_dialogue/light_switch_off_5.mp3"),
]
const _OFF_TEXTS: Array[String] = [
	"Thank you",
	"*grumbles* ...fine",
	"*heavy sigh* ...thank you",
	"",
	"Unbelievable... every single time... ridiculous...",
]


func _ready() -> void:
	add_to_group("save_state_provider")
	_player = AudioStreamPlayer3D.new()
	_player.name = "DialogueAudio"
	_player.bus = "Voice"
	_player.volume_db = 30.0
	_player.max_distance = 20.0
	_player.unit_size = 5.0
	_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_player.finished.connect(_on_dialogue_finished)
	add_child(_player)
	if light_switch != null:
		light_switch.toggled.connect(_on_light_toggled)


func _on_light_toggled(is_on: bool) -> void:
	if _is_talking:
		return
	if is_on:
		on_count += 1
		if on_count <= _ON_STREAMS.size():
			_is_talking = true
			await get_tree().create_timer(REACTION_DELAY).timeout
			_play(_ON_STREAMS[on_count - 1], _ON_TEXTS[on_count - 1])
	else:
		off_count += 1
		if off_count <= _OFF_STREAMS.size():
			_is_talking = true
			await get_tree().create_timer(REACTION_DELAY).timeout
			_play(_OFF_STREAMS[off_count - 1], _OFF_TEXTS[off_count - 1])


func _play(stream: AudioStream, subtitle_key: String) -> void:
	if stream == null:
		_is_talking = false
		return
	_player.stream = stream
	_player.play()
	_set_music_duck(true)
	if not subtitle_key.is_empty():
		var display := get_tree().get_first_node_in_group("subtitle_display") as SubtitleDisplay
		if display != null:
			display.show_line(tr(subtitle_key), stream.get_length())


func _on_dialogue_finished() -> void:
	_is_talking = false
	_set_music_duck(false)


func _set_music_duck(duck: bool) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx < 0:
		return
	var settings := get_node_or_null("/root/GameSettings")
	var base_db := 0.0
	if settings != null and settings.has_method("get_music_volume"):
		var linear := float(settings.call("get_music_volume"))
		base_db = -80.0 if linear <= 0.0 else linear_to_db(linear)
	var target_db := base_db + (DUCK_DB if duck else 0.0)
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(bus_idx, db),
		AudioServer.get_bus_volume_db(bus_idx),
		target_db,
		DUCK_FADE
	)


func get_save_key() -> String:
	return "neil_bed_dialogue"


func get_save_state() -> Dictionary:
	return {"on_count": on_count, "off_count": off_count}


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	on_count = int(state.get("on_count", 0))
	off_count = int(state.get("off_count", 0))
