extends InteractionBehavior
class_name Lever

signal lever_pulled

@export_range(-180.0, 180.0) var pulled_rotation_x: float = 180.0
@export var pull_duration: float = 1.0
@export var return_duration: float = 0.9
@export var interactable_path: NodePath

var _lever_arm: Node3D
var _indicator: MeshInstance3D
var _interactable
var _focus_target: Node3D

var _lever_installed := false
var _is_down := false
var _enabled := false
var _pull_tween: Tween
var _flash_tween: Tween

var _mat_off: StandardMaterial3D
var _mat_blue: StandardMaterial3D
var _mat_orange: StandardMaterial3D
var _mat_red: StandardMaterial3D


func _ready() -> void:
	add_to_group("save_state_provider")
	_lever_arm = get_node_or_null("Node3D/lever")
	_indicator  = get_node_or_null("Node3D/indicator")
	_focus_target = get_node_or_null("FocusTarget")

	if interactable_path:
		_interactable = get_node_or_null(interactable_path)
	if _interactable == null:
		_interactable = get_node_or_null("Interactable")

	_build_indicator_materials()
	_apply_installed_state()
	set_enabled(false)
	set_indicator_off()


func _apply_installed_state() -> void:
	if _lever_arm:
		_lever_arm.visible = _lever_installed
	if _interactable:
		if _lever_installed:
			_interactable.prompt_action = tr("Pull")
			if _focus_target:
				_focus_target.queue_free()
				_focus_target = null
		else:
			_interactable.prompt_action = tr("Inspect")


# --- InteractionBehavior overrides (focus mode item application) ---

func can_receive_item(item) -> bool:
	return not _lever_installed and item != null and item.item_id == "spare_lever"


func receive_item(_item) -> bool:
	_install_lever()
	return true


func should_consume_received_item(_item) -> bool:
	return true


func _install_lever() -> void:
	_lever_installed = true
	_apply_installed_state()


# --- Save state ---

func get_save_key() -> String:
	return "lever_installed:" + str(get_path())


func get_save_state() -> Dictionary:
	return {"installed": _lever_installed}


func apply_save_state(state: Dictionary) -> void:
	_lever_installed = bool(state.get("installed", false))
	_apply_installed_state()


# --- Public API for controller ---

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _interactable != null:
		_interactable.set_interaction_enabled(_lever_installed and enabled and not _is_down)


func return_to_up(duration: float = -1.0, auto_enable: bool = true) -> void:
	if _lever_arm == null:
		return
	_is_down = false
	if _pull_tween:
		_pull_tween.kill()
	var actual_duration := return_duration if duration < 0.0 else duration
	_pull_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_pull_tween.tween_property(_lever_arm, "rotation_degrees:x", 0.0, actual_duration)
	if auto_enable:
		_pull_tween.tween_callback(func(): set_enabled(true))


func set_indicator_off() -> void:
	_stop_flash()
	if _indicator:
		_indicator.material_override = _mat_off


func set_indicator_blue_flash() -> void:
	_start_flash(_mat_blue)


func set_indicator_orange() -> void:
	_stop_flash()
	if _indicator:
		_indicator.material_override = _mat_orange


func set_indicator_red_flash() -> void:
	_start_flash(_mat_red)


# --- Internal ---

func _build_indicator_materials() -> void:
	_mat_off    = _make_mat(Color(0.12, 0.12, 0.14), false)
	_mat_blue   = _make_mat(Color(0.3,  0.6,  1.0),  true)
	_mat_orange = _make_mat(Color(1.0,  0.55, 0.1),  true)
	_mat_red    = _make_mat(Color(0.9,  0.15, 0.15), true)


func _make_mat(color: Color, emissive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
	return mat


func _pull_down() -> void:
	if _lever_arm == null or _is_down or not _enabled or not _lever_installed:
		return
	_is_down = true
	set_enabled(false)
	if _pull_tween:
		_pull_tween.kill()
	_pull_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_pull_tween.tween_property(_lever_arm, "rotation_degrees:x", pulled_rotation_x, pull_duration)
	_pull_tween.tween_callback(func(): lever_pulled.emit())


func _start_flash(mat: StandardMaterial3D) -> void:
	_stop_flash()
	_flash_tween = create_tween().set_loops()
	_flash_tween.tween_callback(func():
		if _indicator: _indicator.material_override = mat)
	_flash_tween.tween_interval(0.45)
	_flash_tween.tween_callback(func():
		if _indicator: _indicator.material_override = _mat_off)
	_flash_tween.tween_interval(0.45)


func _stop_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
		_flash_tween = null


func _on_interactable_clicked(_source, _actor: Node) -> void:
	_pull_down()
