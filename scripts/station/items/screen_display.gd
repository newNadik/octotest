@tool
extends Node3D

@export var screen_image: Texture2D:
	set(value):
		screen_image = value
		_update_screen()
@export var screen_image_ua: Texture2D:
	set(value):
		screen_image_ua = value
		_update_screen()

var _last_locale := ""


func _ready() -> void:
	_last_locale = TranslationServer.get_locale()
	_update_screen()


func _process(_delta: float) -> void:
	var locale := TranslationServer.get_locale()
	if locale == _last_locale and not Engine.is_editor_hint():
		return
	_last_locale = locale
	_update_screen()


func _update_screen() -> void:
	if not is_inside_tree():
		return
	var mesh: MeshInstance3D = get_node_or_null("screen_mesh")
	var texture := _get_texture_for_locale()
	if not mesh or not texture:
		return
	var mat := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	if not mat:
		return
	mat.albedo_texture = texture
	mat.emission_texture = texture
	mesh.set_surface_override_material(0, mat)


func _get_texture_for_locale() -> Texture2D:
	var locale := TranslationServer.get_locale()
	if locale.begins_with("uk") and screen_image_ua != null:
		return screen_image_ua
	return screen_image
