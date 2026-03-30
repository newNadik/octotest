extends Node3D


func _ready() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return
	_apply(bool(settings.call("get_god_rays_enabled")))
	settings.god_rays_enabled_changed.connect(_apply)


func _apply(enabled: bool) -> void:
	visible = enabled
	var world := get_world_3d()
	if world != null and world.environment != null:
		world.environment.volumetric_fog_enabled = enabled
