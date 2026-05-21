@tool
extends Area3D

const HEIGHT := 5.0

@export var area_width := 4.0:
	set(value):
		area_width = maxf(0.1, value)
		_update_shape()

@export var area_length := 4.0:
	set(value):
		area_length = maxf(0.1, value)
		_update_shape()

@export var light_energy := 1.0
@export var light_range := 0.0  # 0 = auto from area size
@export var fade_in_time := 0.3
@export var stay_on_time := 5.0
@export var fade_out_time := 1.0

var _player_inside := false
var _stay_timer: Timer
var _tween: Tween


func _ready() -> void:
	var viz := get_node_or_null("EditorViz") as MeshInstance3D
	if viz != null:
		viz.visible = Engine.is_editor_hint()
	if Engine.is_editor_hint():
		_update_shape()
		return
	add_to_group("save_state_provider")
	_stay_timer = Timer.new()
	_stay_timer.one_shot = true
	_stay_timer.timeout.connect(_on_stay_timer_timeout)
	add_child(_stay_timer)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_save_key() -> String:
	return str(get_path())


func get_save_state() -> Dictionary:
	var light := get_node_or_null("OmniLight3D") as OmniLight3D
	return {
		"player_inside": _player_inside,
		"light_energy": light.light_energy if light != null else 0.0,
	}


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_player_inside = bool(state.get("player_inside", false))
	var light := get_node_or_null("OmniLight3D") as OmniLight3D
	if light != null:
		light.light_energy = float(state.get("light_energy", 0.0))
	if _player_inside:
		_stay_timer.stop()


func _update_shape() -> void:
	var box_size := Vector3(area_width, HEIGHT, area_length)
	var center := Vector3(0.0, HEIGHT * 0.5, 0.0)

	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs != null:
		var box := cs.shape as BoxShape3D
		if box == null:
			box = BoxShape3D.new()
			cs.shape = box
		box.size = box_size
		cs.position = center

	var viz := get_node_or_null("EditorViz") as MeshInstance3D
	if viz != null:
		var box_mesh := viz.mesh as BoxMesh
		if box_mesh == null:
			box_mesh = BoxMesh.new()
			viz.mesh = box_mesh
		box_mesh.size = box_size
		viz.position = center

	var light := get_node_or_null("OmniLight3D") as OmniLight3D
	if light != null:
		light.position = Vector3(0.0, HEIGHT, 0.0)
		if light_range > 0.0:
			light.omni_range = light_range
		else:
			var half_w := area_width * 0.5
			var half_l := area_length * 0.5
			light.omni_range = sqrt(half_w * half_w + HEIGHT * HEIGHT + half_l * half_l) * 1.1


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_player_inside = true
	_stay_timer.stop()
	_fade_light(true)


func _on_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	_player_inside = false
	if stay_on_time > 0.0:
		_stay_timer.wait_time = stay_on_time
		_stay_timer.start()
	else:
		_fade_light(false)


func _on_stay_timer_timeout() -> void:
	if not _player_inside:
		_fade_light(false)


func _fade_light(turn_on: bool) -> void:
	var light := get_node_or_null("OmniLight3D") as OmniLight3D
	if light == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var target := light_energy if turn_on else 0.0
	var duration := fade_in_time if turn_on else fade_out_time
	_tween.tween_property(light, "light_energy", target, duration)
