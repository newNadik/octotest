extends StaticBody3D
class_name CodePanel

const INTERACTABLE_SCRIPT := preload("res://scripts/interaction/interactable.gd")
const FOCUS_TARGET_SCRIPT := preload("res://scripts/interaction/focus_target.gd")

@export var required_code := "1234"
@export var max_input_length := 8

var _display_label: Label3D
var _led_mesh: MeshInstance3D
var _focus_target
var _entry_interactable
var _button_areas: Array = []
var _input_text := ""
var _buttons_enabled := false
var _granted_latched := false

var _body_material: StandardMaterial3D
var _button_material: StandardMaterial3D
var _display_material: StandardMaterial3D
var _led_idle_material: StandardMaterial3D
var _led_fail_material: StandardMaterial3D
var _led_success_material: StandardMaterial3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_create_materials()
	_build_panel()
	_update_display()
	_set_led_idle()
	_set_buttons_enabled(false)
	set_process(true)


func _process(_delta: float) -> void:
	_set_buttons_enabled(_is_focus_active())


func _create_materials() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.18, 0.2, 0.24, 1.0)
	_body_material.roughness = 0.45

	_button_material = StandardMaterial3D.new()
	_button_material.albedo_color = Color(0.28, 0.31, 0.37, 1.0)
	_button_material.roughness = 0.35

	_display_material = StandardMaterial3D.new()
	_display_material.albedo_color = Color(0.06, 0.08, 0.1, 1.0)
	_display_material.roughness = 0.2

	_led_idle_material = _make_led_material(Color(0.96, 0.84, 0.2, 1.0))
	_led_fail_material = _make_led_material(Color(0.9, 0.2, 0.2, 1.0))
	_led_success_material = _make_led_material(Color(0.2, 0.92, 0.3, 1.0))


func _build_panel() -> void:
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	var body_box := BoxMesh.new()
	body_box.size = Vector3(1.75, 2.45, 0.14)
	body_mesh.mesh = body_box
	body_mesh.material_override = _body_material
	add_child(body_mesh)

	var body_collision := CollisionShape3D.new()
	body_collision.name = "CollisionShape3D"
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(1.75, 2.45, 0.14)
	body_collision.shape = body_shape
	add_child(body_collision)

	var display_mesh := MeshInstance3D.new()
	display_mesh.name = "Display"
	display_mesh.position = Vector3(0.0, 0.86, -0.08)
	var display_box := BoxMesh.new()
	display_box.size = Vector3(1.35, 0.42, 0.04)
	display_mesh.mesh = display_box
	display_mesh.material_override = _display_material
	add_child(display_mesh)

	_display_label = Label3D.new()
	_display_label.name = "DisplayLabel"
	_display_label.position = Vector3(0.0, 0.86, -0.115)
	_display_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_display_label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_display_label.text = ""
	_display_label.modulate = Color(0.45, 0.98, 0.55, 1.0)
	_display_label.pixel_size = 0.006
	_display_label.font_size = 30
	_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_display_label)

	_led_mesh = MeshInstance3D.new()
	_led_mesh.name = "StatusLed"
	_led_mesh.position = Vector3(0.67, 0.86, -0.08)
	var led_box := BoxMesh.new()
	led_box.size = Vector3(0.17, 0.17, 0.04)
	_led_mesh.mesh = led_box
	add_child(_led_mesh)

	_focus_target = FOCUS_TARGET_SCRIPT.new()
	_focus_target.name = "FocusTarget"
	_focus_target.position = Vector3(0.0, 0.12, -0.12)
	_focus_target.auto_exit_on_solved = false
	add_child(_focus_target)

	_entry_interactable = INTERACTABLE_SCRIPT.new()
	_entry_interactable.name = "Interactable"
	_entry_interactable.collision_layer = 8
	_entry_interactable.collision_mask = 0
	_entry_interactable.display_name = "Code Panel"
	_entry_interactable.prompt_action = "Use Keypad"
	_entry_interactable.interaction_range = 2.9
	_entry_interactable.focus_offset = Vector3(0.0, 0.12, 0.0)
	add_child(_entry_interactable)

	var panel_area_collision := CollisionShape3D.new()
	panel_area_collision.name = "CollisionShape3D"
	panel_area_collision.position = Vector3(0.0, 0.35, 0.0)
	var panel_area_shape := BoxShape3D.new()
	panel_area_shape.size = Vector3(1.92, 1.8, 0.56)
	panel_area_collision.shape = panel_area_shape
	_entry_interactable.add_child(panel_area_collision)

	_build_keypad()


func _build_keypad() -> void:
	var buttons := Node3D.new()
	buttons.name = "Buttons"
	add_child(buttons)

	var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<<", "0", "OK"]
	var positions := {
		"1": Vector3(0.4, 0.33, -0.08),
		"2": Vector3(0.0, 0.33, -0.08),
		"3": Vector3(-0.4, 0.33, -0.08),
		"4": Vector3(0.4, -0.06, -0.08),
		"5": Vector3(0.0, -0.06, -0.08),
		"6": Vector3(-0.4, -0.06, -0.08),
		"7": Vector3(0.4, -0.45, -0.08),
		"8": Vector3(0.0, -0.45, -0.08),
		"9": Vector3(-0.4, -0.45, -0.08),
		"<<": Vector3(0.4, -0.84, -0.08),
		"0": Vector3(0.0, -0.84, -0.08),
		"OK": Vector3(-0.4, -0.84, -0.08),
	}

	for key in keys:
		var button := _create_button(key, positions[key])
		buttons.add_child(button)


func _create_button(key: String, local_pos: Vector3) -> StaticBody3D:
	var button := StaticBody3D.new()
	button.name = "Button%s" % key
	button.position = local_pos
	button.collision_layer = 1
	button.collision_mask = 0

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.31, 0.26, 0.05)
	mesh.mesh = box
	mesh.material_override = _button_material
	button.add_child(mesh)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.31, 0.26, 0.05)
	collision.shape = shape
	button.add_child(collision)

	var label := Label3D.new()
	label.name = "Label"
	label.position = Vector3(0.0, 0.0, -0.045)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	label.text = key
	label.font_size = 34
	label.pixel_size = 0.007
	label.modulate = Color(0.9, 0.92, 0.96, 1.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(label)

	var area := INTERACTABLE_SCRIPT.new()
	area.name = "Interactable"
	area.collision_layer = 8
	area.collision_mask = 0
	area.display_name = key
	area.prompt_action = "Press"
	area.interaction_range = 2.9
	# Push focus point in front of panel so line-of-sight checks do not hit panel collision first.
	area.focus_offset = Vector3(0.0, 0.0, -0.22)
	button.add_child(area)
	_button_areas.append(area)

	var area_collision := CollisionShape3D.new()
	area_collision.name = "CollisionShape3D"
	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(0.38, 0.34, 0.34)
	area_collision.shape = area_shape
	area.add_child(area_collision)

	area.clicked.connect(_on_button_clicked.bind(key))
	return button


func _on_button_clicked(_interactable, _actor: Node, key: String) -> void:
	if not _is_focus_active():
		return

	if _granted_latched and key != "OK":
		_granted_latched = false
		_input_text = ""
		_set_led_idle()

	if key == "<<":
		if _input_text.length() > 0:
			_input_text = _input_text.substr(0, _input_text.length() - 1)
		_update_display()
		_set_led_idle()
		return

	if key == "OK":
		_submit_code()
		return

	if _input_text.length() >= max_input_length:
		return

	_input_text += key
	_update_display()
	_set_led_idle()


func _submit_code() -> void:
	if _input_text == required_code:
		_granted_latched = true
		_led_mesh.material_override = _led_success_material
		_input_text = ""
		_update_display()
		return

	_granted_latched = false
	_display_label.text = tr("DENIED")
	_led_mesh.material_override = _led_fail_material

	await get_tree().create_timer(1.1).timeout
	_input_text = ""
	_update_display()
	_set_led_idle()


func _update_display() -> void:
	if _granted_latched:
		_display_label.text = tr("GRANTED")
		return

	if _input_text.is_empty():
		_display_label.text = tr("ENTER CODE")
		return

	var masked := ""
	for i in range(_input_text.length()):
		masked += "*"
	_display_label.text = masked


func _set_led_idle() -> void:
	_led_mesh.material_override = _led_idle_material


func _set_buttons_enabled(enabled: bool) -> void:
	if _entry_interactable != null:
		# In focus mode, disable main panel hit area so keypad buttons receive clicks.
		_entry_interactable.set_interaction_enabled(not enabled)

	if _buttons_enabled == enabled:
		return
	_buttons_enabled = enabled
	for area in _button_areas:
		if area != null:
			area.set_interaction_enabled(enabled)


func _is_focus_active() -> bool:
	if _focus_target == null:
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return false
	if not scene.has_method("is_focus_target_active"):
		return false
	return bool(scene.call("is_focus_target_active", _focus_target))


func _make_led_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	material.roughness = 0.35
	return material
