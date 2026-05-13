# RoomLighting.gd
extends Node3D

const LAMP_ON_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/lamp-on.wav")

@export var light_switch: LightSwitch
@export var ceiling_mesh: MeshInstance3D
@export var ceiling_surface := 0
@export var emission_on_color := Color(0.95, 0.97, 1.0)
@export var emission_off_color := Color(0x82a6b3ff)
@export var emission_energy_on := 0.3
@export var emission_energy_off := 0.05
@export var ceiling_albedo_boost_on := 1.0
@export var ceiling_albedo_boost_off := 1.0
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

@export_group("Random LED Flicker")
@export var random_led_flicker_enabled := true
@export var random_led_group: StringName = &"led_random"
@export var random_led_root: NodePath = NodePath("lights/led_random")
@export var random_led_intensity_min := 1.0
@export var random_led_intensity_max := 2.0
@export var random_led_dip_chance := 0.12
@export var random_led_dip_intensity_min := 0.15
@export var random_led_dip_intensity_max := 0.35
@export var random_led_change_interval_min := 0.01
@export var random_led_change_interval_max := 0.5
@export var random_led_blend_speed := 7.0
@export var led_blink_default_interval := 0.35
@export var led_blink_interval_5 := 0.35
@export var led_blink_interval_6 := 0.42
@export var led_blink_interval_7 := 0.5

var _ceiling_mat: Material
var _is_on := false
var _flickering := false
var _lamp_on_player: AudioStreamPlayer3D
var _allow_runtime_toggle_fx := false
var _random_led_states: Dictionary = {}

func _ready() -> void:
	add_to_group("save_state_provider")
	_make_ceiling_material_unique()
	_populate_lamp_lights_if_needed()
	_setup_random_led_flicker()
	_ensure_audio_player()
	if light_switch != null:
		light_switch.toggled.connect(_on_switch_toggled)
		_on_switch_toggled(light_switch.start_on)
	else:
		_on_switch_toggled(false)
	_allow_runtime_toggle_fx = true
	set_process(random_led_flicker_enabled and not _random_led_states.is_empty())


func _process(delta: float) -> void:
	if not random_led_flicker_enabled:
		return
	for led_key in _random_led_states.keys():
		var led := led_key as OmniLight3D
		if led == null:
			continue
		if not is_instance_valid(led):
			continue
		var state: Dictionary = _random_led_states[led]
		var smooth := bool(state.get("smooth", false))
		var timer := float(state.get("timer", 0.0)) - delta
		var current := float(state.get("current", 1.0))
		if timer <= 0.0:
			if bool(state.get("always_on", false)):
				state["target"] = 1.0
				timer = float(state.get("interval", led_blink_default_interval))
			elif smooth:
				state["target"] = _pick_random_led_multiplier()
				timer = randf_range(random_led_change_interval_min, random_led_change_interval_max)
			else:
				state["target"] = 0.0 if current >= 0.5 else 1.0
				timer = float(state.get("interval", led_blink_default_interval))

		if smooth:
			current = move_toward(
				current,
				float(state.get("target", 1.0)),
				random_led_blend_speed * delta
			)
		else:
			current = float(state.get("target", 1.0))

		state["timer"] = timer
		state["current"] = current
		var base_energy := float(state.get("base_energy", led.light_energy))
		led.light_energy = base_energy * current
		_random_led_states[led] = state

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
	if _allow_runtime_toggle_fx and is_on and flicker_on_startup:
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
		if l != null: 
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


func _setup_random_led_flicker() -> void:
	_random_led_states.clear()
	var discovered: Array[OmniLight3D] = []
	if random_led_group != StringName():
		for node in get_tree().get_nodes_in_group(random_led_group):
			if node is OmniLight3D:
				discovered.append(node as OmniLight3D)
			elif node is Node:
				discovered.append_array(_collect_omni_lights(node))
	if discovered.is_empty() and not random_led_root.is_empty():
		var root := get_node_or_null(random_led_root)
		if root is Node:
			discovered.append_array(_collect_omni_lights(root))

	var seen: Dictionary = {}
	for led in discovered:
		if led == null:
			continue
		var led_id := led.get_instance_id()
		if seen.has(led_id):
			continue
		seen[led_id] = true
		var is_smooth := _is_server_led(led.name)
		var always_on := _is_always_on_led(led.name)
		var led_interval := _get_led_step_interval(led.name)
		var starts_on := randf() < 0.5
		var initial_mult := _pick_random_led_multiplier() if is_smooth and not always_on else (1.0 if always_on or starts_on else 0.0)
		_random_led_states[led] = {
			"base_energy": led.light_energy,
			"smooth": is_smooth,
			"always_on": always_on,
			"interval": led_interval,
			"current": initial_mult,
			"target": initial_mult,
			"timer": randf_range(random_led_change_interval_min, random_led_change_interval_max) if is_smooth else led_interval
		}
		led.light_energy *= initial_mult


func _collect_omni_lights(root: Node) -> Array[OmniLight3D]:
	var result: Array[OmniLight3D] = []
	if root is OmniLight3D:
		result.append(root as OmniLight3D)
	for child in root.get_children():
		if child is Node:
			result.append_array(_collect_omni_lights(child))
	return result


func _pick_random_led_multiplier() -> float:
	if randf() < random_led_dip_chance:
		return randf_range(random_led_dip_intensity_min, random_led_dip_intensity_max)
	return randf_range(random_led_intensity_min, random_led_intensity_max)


func _is_server_led(led_name: String) -> bool:
	return led_name == "LEDglow" or led_name == "LEDglow2" or led_name == "LEDglow3" or led_name == "LEDglow4"


func _is_always_on_led(led_name: String) -> bool:
	return led_name == "LEDglow8"


func _get_led_step_interval(led_name: String) -> float:
	if led_name == "LEDglow5":
		return led_blink_interval_5
	if led_name == "LEDglow6":
		return led_blink_interval_6
	if led_name == "LEDglow7":
		return led_blink_interval_7
	return led_blink_default_interval


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
