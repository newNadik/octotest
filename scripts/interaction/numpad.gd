extends Node3D
class_name Numpad

const INTERACTABLE_SCRIPT := preload("res://scripts/interaction/interactable.gd")

signal code_submitted(text: String)
signal input_changed

@export var max_input_length := 4

var _display_label: Label3D
var _focus_target: Node3D
var _entry_interactable
var _button_interactables: Array = []
var _input_text := ""
var _locked := false


func _ready() -> void:
	_display_label = get_node_or_null("display_text") as Label3D
	_focus_target = get_node_or_null("FocusTarget")
	_entry_interactable = get_node_or_null("Interactable")
	_setup_buttons()
	_update_display()
	_set_buttons_enabled(false)
	set_process(true)


func _process(_delta: float) -> void:
	_set_buttons_enabled(not _locked and _is_focus_active())


func _setup_buttons() -> void:
	var buttons_node := get_node_or_null("Node3D/Buttons")
	if buttons_node != null:
		for i in range(10):
			var btn := buttons_node.get_node_or_null("Button_%d" % i) as MeshInstance3D
			if btn != null:
				_button_interactables.append(_attach_button_interactable(btn, str(i)))

	var enter_btn := get_node_or_null("Node3D/E/button_enter") as MeshInstance3D
	if enter_btn != null:
		_button_interactables.append(_attach_button_interactable(enter_btn, "E"))

	var clear_btn := get_node_or_null("Node3D/C/button_clear") as MeshInstance3D
	if clear_btn != null:
		_button_interactables.append(_attach_button_interactable(clear_btn, "C"))


func _attach_button_interactable(button_mesh: MeshInstance3D, key: String):
	# Glow mesh must exist before the Interactable's _ready() so the reveal system finds it.
	var glow := _create_glow_mesh(button_mesh)
	button_mesh.add_child(glow)

	var area = INTERACTABLE_SCRIPT.new()
	area.name = "Interactable"
	area.collision_layer = 8
	area.collision_mask = 0
	area.display_name = key
	area.prompt_action = "Press"
	area.show_indicator = false
	area.interaction_range = 2.5
	area.requires_line_of_sight = false
	area.highlight_mode = 1  # REVEAL_MESHES
	var glow_paths: Array[NodePath] = [NodePath("../GlowMesh")]
	area.highlight_visible_paths = glow_paths
	button_mesh.add_child(area)  # _ready() runs here and picks up GlowMesh

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	if button_mesh.mesh != null:
		var aabb := button_mesh.mesh.get_aabb()
		shape.size = Vector3(aabb.size.x + 0.04, maxf(aabb.size.y, 0.08), aabb.size.z + 0.04)
		col.position = aabb.get_center()
	else:
		shape.size = Vector3(0.22, 0.08, 0.14)
	col.shape = shape
	area.add_child(col)

	area.clicked.connect(_on_button_clicked.bind(key))
	return area


func _create_glow_mesh(button_mesh: MeshInstance3D) -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	glow.name = "GlowMesh"
	glow.mesh = button_mesh.mesh
	glow.visible = false

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.85, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.albedo_color = Color(0.55, 0.85, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.material_override = mat
	return glow


func _on_button_clicked(_interactable, _actor: Node, key: String) -> void:
	if not _is_focus_active() or _locked:
		return

	if key == "E":
		var submitted := _input_text
		_input_text = ""
		_update_display()
		code_submitted.emit(submitted)
		return

	if key == "C":
		_input_text = ""
		_update_display()
		input_changed.emit()
		return

	if _input_text.length() >= max_input_length:
		return

	_input_text += key
	_update_display()
	input_changed.emit()


func _update_display() -> void:
	if _display_label == null:
		return
	if _input_text.is_empty():
		_display_label.text = tr("ENTER CODE")
		return
	_display_label.text = _input_text


func set_display_text(text: String) -> void:
	if _display_label != null:
		_display_label.text = text


func clear_input() -> void:
	_input_text = ""
	_update_display()


func set_locked(locked: bool) -> void:
	_locked = locked
	if locked:
		_input_text = ""
		_update_display()


func _set_buttons_enabled(enabled: bool) -> void:
	if _entry_interactable != null:
		_entry_interactable.set_interaction_enabled(not enabled)
	for area in _button_interactables:
		if area != null:
			area.set_interaction_enabled(enabled)


func _is_focus_active() -> bool:
	if _focus_target == null:
		return false
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("is_focus_target_active"):
		return false
	return bool(scene.call("is_focus_target_active", _focus_target))
