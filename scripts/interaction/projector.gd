extends InteractionBehavior
class_name ProjectorBehavior

const BUTTON_SFX = preload("res://assets/sound/projector-button.mp3")
const SLIDE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/historical/history_0.png"),
	preload("res://assets/textures/historical/history_1.png"),
	preload("res://assets/textures/historical/history_2.png"),
	preload("res://assets/textures/historical/history_3.png"),
	preload("res://assets/textures/historical/history_4.png"),
]

## Set in workshop_details.tscn — points to the projection screen MeshInstance3D.
@export var projection_mesh: MeshInstance3D

## Path to the room LightSwitch, relative to the scene root.
## Leave blank to use the default workshop path "workshop/lights/LightSwitch".
@export var room_light_switch_path: NodePath = NodePath("")

@onready var _indicator_led: MeshInstance3D = $indicator_led

var _slide_index: int = -1  # -1 = off, 0-4 = slide index
var _light_switch_ref: LightSwitch = null
var _sfx_player: AudioStreamPlayer3D
var _projection_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("save_state_provider")
	_ensure_sfx_player()
	_init_projection_material()
	_update_visuals()
	# Defer so sibling arch scene (and its LightSwitch) is fully in the tree
	call_deferred("_connect_room_light")


func on_interacted(_actor: Node) -> void:
	_play_button_sfx()
	_slide_index += 1
	if _slide_index >= SLIDE_TEXTURES.size():
		_slide_index = -1
	_update_visuals()


func _connect_room_light() -> void:
	var ls := _find_light_switch()
	if ls == null:
		return
	_light_switch_ref = ls
	ls.toggled.connect(_on_room_light_toggled)
	_update_visuals()


func _find_light_switch() -> LightSwitch:
	if room_light_switch_path != NodePath(""):
		return get_node_or_null(room_light_switch_path) as LightSwitch
	# Relative path from projector up to station root, then into the arch sibling:
	# projector -> items -> WorkshopDetails -> station -> workshop -> lights -> LightSwitch
	return get_node_or_null("../../../workshop/lights/LightSwitch") as LightSwitch


func _on_room_light_toggled(_is_on: bool) -> void:
	_update_visuals()


func _update_visuals() -> void:
	var is_on := _slide_index >= 0

	if _indicator_led != null:
		_indicator_led.visible = is_on

	if projection_mesh == null:
		return

	if is_on:
		if _projection_mat != null:
			_projection_mat.emission_texture = SLIDE_TEXTURES[_slide_index]
		# Read light state directly — never stale, immune to save-load signal skip
		var room_light_on := _light_switch_ref != null and _light_switch_ref.is_on
		projection_mesh.visible = not room_light_on
	else:
		projection_mesh.visible = false


func _init_projection_material() -> void:
	if projection_mesh == null:
		return
	var mat := projection_mesh.get_surface_override_material(0)
	if mat == null and projection_mesh.mesh != null:
		mat = projection_mesh.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		_projection_mat = (mat as StandardMaterial3D).duplicate()
		projection_mesh.set_surface_override_material(0, _projection_mat)


func _ensure_sfx_player() -> void:
	_sfx_player = AudioStreamPlayer3D.new()
	_sfx_player.name = "ProjectorSfx"
	_sfx_player.stream = BUTTON_SFX
	_sfx_player.volume_db = -3.0
	_sfx_player.max_distance = 10.0
	_sfx_player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(_sfx_player)


func _play_button_sfx() -> void:
	if _sfx_player == null or _sfx_player.stream == null:
		return
	_sfx_player.stop()
	_sfx_player.play()


func get_save_state() -> Dictionary:
	return {"slide": _slide_index}


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_slide_index = int(state.get("slide", -1))
	_update_visuals()
