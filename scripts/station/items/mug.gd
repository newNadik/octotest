extends StaticBody3D

const DEFAULT_DECAL_TEXTURE := preload("res://assets/ui/Icon_BCRC1024.png")

@export_group("Decals")
@export var front_decal_texture: Texture2D = DEFAULT_DECAL_TEXTURE:
	set(value):
		front_decal_texture = value
		_apply_front_decal_texture()

@export var back_decal_texture: Texture2D = DEFAULT_DECAL_TEXTURE:
	set(value):
		back_decal_texture = value
		_apply_back_decal_texture()

@onready var _front_decal: Decal = $Decal
@onready var _back_decal: Decal = $Decal2

func _ready() -> void:
	_apply_front_decal_texture()
	_apply_back_decal_texture()

func _apply_front_decal_texture() -> void:
	if not is_instance_valid(_front_decal):
		return
	_front_decal.texture_albedo = front_decal_texture

func _apply_back_decal_texture() -> void:
	if not is_instance_valid(_back_decal):
		return
	_back_decal.texture_albedo = back_decal_texture
