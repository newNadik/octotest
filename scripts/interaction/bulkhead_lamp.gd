extends Node3D
class_name BulkheadLamp

@export var beacon_rpm: float = 45.0

var _light: SpotLight3D
var _light2: SpotLight3D
var _light_base_basis: Basis
var _beacon_angle := 0.0
var _is_beacon := false
@onready var bulb: MeshInstance3D = $bulb
var _bulb_mat: StandardMaterial3D


func _ready() -> void:
	_light = get_node_or_null("SpotLight3D")
	if _light:
		_light_base_basis = _light.transform.basis
		_light2 = _light.duplicate() as SpotLight3D
		_light2.name = "SpotLight3D_2"
		add_child(_light2)

	if bulb:
		_bulb_mat = bulb.get_active_material(0).duplicate() as StandardMaterial3D
		_bulb_mat.emission_enabled = true
		bulb.material_override = _bulb_mat
		
	set_process(false)


func _process(delta: float) -> void:
	if _light == null:
		return
	_beacon_angle = fmod(_beacon_angle + beacon_rpm * 6.0 * delta, 360.0)
	_light.transform.basis = _light_base_basis * Basis(Vector3.UP, deg_to_rad(_beacon_angle))
	if _light2:
		_light2.transform.basis = _light_base_basis * Basis(Vector3.UP, deg_to_rad(_beacon_angle + 180.0))


# --- Public API ---

func set_off() -> void:
	_is_beacon = false
	set_process(false)
	if _light:
		_light.visible = false
	if _light2:
		_light2.visible = false
	_set_bulb_color(Color.BLACK, false)


func set_steady(color: Color) -> void:
	_is_beacon = false
	set_process(false)
	if _light:
		_light.transform.basis = _light_base_basis
		_light.light_color = color
		_light.visible = true
	if _light2:
		_light2.visible = false
	_set_bulb_color(color)


func set_beacon(color: Color) -> void:
	_is_beacon = true
	if _light:
		_light.light_color = color
		_light.visible = true
	if _light2:
		_light2.light_color = color
		_light2.visible = true
	_set_bulb_color(color)
	set_process(true)


func _set_bulb_color(color: Color, emissive: bool = true) -> void:
	if _bulb_mat == null:
		return
	_bulb_mat.emission_enabled = emissive
	if emissive:
		_bulb_mat.emission = color
		_bulb_mat.emission_energy_multiplier = 2.0
