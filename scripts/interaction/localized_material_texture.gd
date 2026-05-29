@tool
extends MeshInstance3D
class_name LocalizedMaterialTexture

@export var texture_en: Texture2D:
	set(value):
		texture_en = value
		_apply_texture()
@export var texture_ua: Texture2D:
	set(value):
		texture_ua = value
		_apply_texture()
@export var apply_to_all_surfaces := false

var _last_locale := ""


func _ready() -> void:
	_last_locale = TranslationServer.get_locale()
	_apply_texture()
	if Engine.is_editor_hint():
		set_process(true)
	else:
		var _screen_enabler := VisibleOnScreenEnabler3D.new()
		add_child(_screen_enabler)


func _process(_delta: float) -> void:
	var locale := TranslationServer.get_locale()
	if locale == _last_locale and not Engine.is_editor_hint():
		return
	_last_locale = locale
	_apply_texture()


func _apply_texture() -> void:
	var texture_to_use := _get_texture_for_locale()
	if texture_to_use == null:
		return
	_apply_texture_to_mesh(self, texture_to_use)


func _get_texture_for_locale() -> Texture2D:
	var locale := TranslationServer.get_locale()
	if locale.begins_with("uk") and texture_ua != null:
		return texture_ua
	return texture_en


func _apply_texture_to_mesh(target_mesh: MeshInstance3D, texture_to_use: Texture2D) -> void:
	if target_mesh.mesh == null:
		return
	var surface_count := target_mesh.mesh.get_surface_count()
	if surface_count <= 0:
		return

	if apply_to_all_surfaces:
		for i in range(surface_count):
			_set_surface_texture(target_mesh, i, texture_to_use)
		return
	_set_surface_texture(target_mesh, 0, texture_to_use)


func _set_surface_texture(target_mesh: MeshInstance3D, surface_index: int, texture_to_use: Texture2D) -> void:
	var current := target_mesh.get_active_material(surface_index)
	var material := current as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
	else:
		material = material.duplicate()
	material.albedo_texture = texture_to_use
	target_mesh.set_surface_override_material(surface_index, material)
