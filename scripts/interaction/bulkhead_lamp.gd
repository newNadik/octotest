extends Node3D
class_name BulkheadLamp

@export var beacon_rpm: float = 45.0

var _light: SpotLight3D
var _light_base_basis: Basis
var _beacon_angle := 0.0
var _is_beacon := false


func _ready() -> void:
	_light = get_node_or_null("SpotLight3D")
	if _light:
		_light_base_basis = _light.transform.basis
		
	set_process(false)
	#set_steady(Color(0.2, 0.5, 1.0))   # blue — standby drained
	#set_steady(Color(0.1, 0.9, 0.3))   # green — standby flooded
	set_beacon(Color(1.0, 0.55, 0.1))  # orange — running
	#set_beacon(Color(0.2, 0.5, 1.0))   # blue — armed
	#set_beacon(Color(0.9, 0.15, 0.15)) # red — sealed



func _process(delta: float) -> void:
	if _light == null:
		return
	_beacon_angle = fmod(_beacon_angle + beacon_rpm * 6.0 * delta, 360.0)
	_light.transform.basis = _light_base_basis * Basis(Vector3.UP, deg_to_rad(_beacon_angle))


# --- Public API ---

func set_off() -> void:
	_is_beacon = false
	set_process(false)
	if _light:
		_light.visible = false


func set_steady(color: Color) -> void:
	_is_beacon = false
	set_process(false)
	if _light:
		_light.transform.basis = _light_base_basis
		_light.light_color = color
		_light.visible = true


func set_beacon(color: Color) -> void:
	_is_beacon = true
	if _light:
		_light.light_color = color
		_light.visible = true
	set_process(true)
