@tool
extends Node3D

@export var sign_texture: Texture2D:
	set(value):
		sign_texture = value
		_apply_texture()


func _ready() -> void:
	_apply_texture()


func _apply_texture() -> void:
	var front := get_node_or_null("Sprite3D") as Sprite3D
	if front != null:
		front.texture = sign_texture

	var back := get_node_or_null("Sprite3D2") as Sprite3D
	if back != null:
		back.texture = sign_texture
