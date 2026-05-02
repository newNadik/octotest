extends StaticBody3D

@export_group("Interaction")
@export var interaction_enabled := true:
	set(value):
		interaction_enabled = value
		_apply_interaction_enabled()

@export_group("Label")
@export var label_albedo_texture: Texture2D:
	set(value):
		label_albedo_texture = value
		_apply_label_albedo_texture()
@export_range(0.5, 2.0, 0.01) var label_brightness := 2.0:
	set(value):
		label_brightness = value
		_apply_label_albedo_texture()

@onready var _mesh_instance: MeshInstance3D = _find_mesh_instance()
@onready var _interactable: Interactable = get_node_or_null("Interactable") as Interactable
var _base_material: StandardMaterial3D
var _base_albedo_texture: Texture2D
var _working_mesh: ArrayMesh


func _ready() -> void:
	_cache_base_material_state()
	_apply_interaction_enabled()
	_apply_label_albedo_texture()


func _apply_interaction_enabled() -> void:
	if _interactable == null:
		return
	_interactable.set_interaction_enabled(interaction_enabled)


func _apply_label_albedo_texture() -> void:
	if _mesh_instance == null or _base_material == null:
		return
	_ensure_working_mesh()
	if _working_mesh == null:
		return
	var local_material := _base_material.duplicate() as StandardMaterial3D
	local_material.albedo_texture = label_albedo_texture if label_albedo_texture != null else _base_albedo_texture
	local_material.albedo_color = Color(label_brightness, label_brightness, label_brightness, 1.0)
	_working_mesh.surface_set_material(0, local_material)
	# Interactable highlight logic uses temporary surface overrides.
	# Keep base override empty so held/hover transitions preserve this mesh material.
	_mesh_instance.set_surface_override_material(0, null)


func _find_mesh_instance() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


func _cache_base_material_state() -> void:
	if _mesh_instance == null:
		return
	var active_material := _mesh_instance.get_active_material(0) as StandardMaterial3D
	if active_material == null:
		var mesh := _mesh_instance.mesh
		if mesh is ArrayMesh:
			active_material = (mesh as ArrayMesh).surface_get_material(0) as StandardMaterial3D
	if active_material == null:
		return
	_base_material = active_material
	_base_albedo_texture = active_material.albedo_texture


func _ensure_working_mesh() -> void:
	if _mesh_instance == null:
		return
	if _working_mesh != null and _mesh_instance.mesh == _working_mesh:
		return
	var source_mesh := _mesh_instance.mesh as ArrayMesh
	if source_mesh == null:
		return
	_working_mesh = source_mesh.duplicate() as ArrayMesh
	_mesh_instance.mesh = _working_mesh
