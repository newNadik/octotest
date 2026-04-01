# RoomLighting.gd
extends Node3D

const LAMP_ON_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/lamp-on.wav")

@export var light_switch: LightSwitch
@export var ceiling_mesh: MeshInstance3D
@export var ceiling_surface := 0
@export var emission_on_color := Color(0.95, 0.97, 1.0)
@export var emission_off_color := Color(0, 0, 0)
@export var emission_energy_on := 2.0
@export var emission_energy_off := 0.0
@export var ceiling_albedo_boost_on := 1.18
@export var ceiling_albedo_boost_off := 0.78
@export var auto_collect_lamp_lights := true
@export var lamp_lights: Array[Light3D] = []

@export_group("Flicker")
@export var flicker_on_startup := true         # flicker when switched on
@export var flicker_count_min := 1             # minimum blink count
@export var flicker_count_max := 2             # maximum blink count
@export var flicker_off_time_min := 0.04       # seconds light stays off per blink
@export var flicker_off_time_max := 0.18
@export var flicker_on_time_min := 0.03        # seconds light stays on between blinks
@export var flicker_on_time_max := 0.12
@export var flicker_settle_delay := 0.3        # pause before final stable on
@export_group("Audio")
@export var lamp_on_sound: AudioStream = LAMP_ON_SOUND_DEFAULT
@export var lamp_on_volume_db := 10.0

var _ceiling_mat: Material
var _is_on := false
var _flickering := false
var _lamp_on_player: AudioStreamPlayer3D
var _allow_runtime_toggle_fx := false

func _ready() -> void:
	add_to_group("save_state_provider")
	_make_ceiling_material_unique()
	_populate_lamp_lights_if_needed()
	_ensure_audio_player()
	if light_switch != null:
		light_switch.toggled.connect(_on_switch_toggled)
		_on_switch_toggled(light_switch.start_on)
	else:
		_on_switch_toggled(false)
	_allow_runtime_toggle_fx = true

func _make_ceiling_material_unique() -> void:
	if ceiling_mesh == null:
		return
	var src := ceiling_mesh.get_active_material(ceiling_surface)
	if src == null:
		return
	_ceiling_mat = src.duplicate()
	ceiling_mesh.set_surface_override_material(ceiling_surface, _ceiling_mat)

func _on_switch_toggled(is_on: bool) -> void:
	_is_on = is_on
	if _allow_runtime_toggle_fx and is_on:
		_play_lamp_on_sound()
	if is_on and flicker_on_startup:
		flicker()
	else:
		_apply_state(is_on)

# Call this from anywhere — e.g. a faulty wire event, a horror moment, etc.
func flicker() -> void:
	if _flickering:
		return
	_flickering = true

	var blinks := randi_range(flicker_count_min, flicker_count_max)
	for i in blinks:
		_apply_state(true)
		await get_tree().create_timer(randf_range(flicker_on_time_min, flicker_on_time_max)).timeout
		_apply_state(false)
		await get_tree().create_timer(randf_range(flicker_off_time_min, flicker_off_time_max)).timeout

	# Brief pause then settle into final state
	await get_tree().create_timer(flicker_settle_delay).timeout
	_apply_state(_is_on)
	_flickering = false

func _apply_state(is_on: bool) -> void:
	for l in lamp_lights:
		l.visible = is_on
	if _ceiling_mat is StandardMaterial3D:
		var mat := _ceiling_mat as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = emission_on_color if is_on else emission_off_color
		mat.emission_energy_multiplier = emission_energy_on if is_on else emission_energy_off
	elif _ceiling_mat is ShaderMaterial:
		var shader_mat := _ceiling_mat as ShaderMaterial
		shader_mat.set_shader_parameter("emission_tint", emission_on_color if is_on else emission_off_color)
		shader_mat.set_shader_parameter("emission_strength", emission_energy_on if is_on else emission_energy_off)
		shader_mat.set_shader_parameter("albedo_boost", ceiling_albedo_boost_on if is_on else ceiling_albedo_boost_off)

func _populate_lamp_lights_if_needed() -> void:
	if not auto_collect_lamp_lights or not lamp_lights.is_empty():
		return
	var discovered := _collect_switch_lights(self)
	for light in discovered:
		lamp_lights.append(light)

func _collect_switch_lights(node: Node) -> Array[Light3D]:
	var result: Array[Light3D] = []
	for child in node.get_children():
		if child is OmniLight3D or child is SpotLight3D or child is DirectionalLight3D:
			result.append(child as Light3D)
		if child is Node:
			result.append_array(_collect_switch_lights(child))
	return result


func get_save_state() -> Dictionary:
	return {
		"is_on": _is_on
	}


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var target_on := bool(state.get("is_on", false))
	_is_on = target_on
	_flickering = false
	_apply_state(target_on)


func _ensure_audio_player() -> void:
	if _lamp_on_player != null:
		return
	_lamp_on_player = AudioStreamPlayer3D.new()
	_lamp_on_player.name = "LampOnAudio"
	_lamp_on_player.stream = lamp_on_sound
	_lamp_on_player.volume_db = lamp_on_volume_db
	_lamp_on_player.max_distance = 18.0
	_lamp_on_player.bus = _resolve_sfx_bus_name()
	add_child(_lamp_on_player)


func _play_lamp_on_sound() -> void:
	if lamp_on_sound == null:
		return
	_ensure_audio_player()
	_lamp_on_player.global_position = _get_lamp_audio_origin()
	_lamp_on_player.stream = lamp_on_sound
	_lamp_on_player.volume_db = lamp_on_volume_db
	_lamp_on_player.pitch_scale = randf_range(0.98, 1.02)
	_lamp_on_player.play()


func _resolve_sfx_bus_name() -> String:
	return "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"


func _get_lamp_audio_origin() -> Vector3:
	if not lamp_lights.is_empty():
		var sum := Vector3.ZERO
		var count := 0
		for light in lamp_lights:
			if light == null:
				continue
			sum += light.global_position
			count += 1
		if count > 0:
			return sum / float(count)
	if light_switch != null:
		return light_switch.global_position
	return global_position
