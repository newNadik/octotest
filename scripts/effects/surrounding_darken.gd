extends Node3D

## Multiplies albedo_color on all StandardMaterial3D surfaces in the surrounding scene.
## Adjust in the Inspector — no need to touch individual GLB materials.
@export_range(0.0, 1.0) var brightness: float = 0.55

func _ready() -> void:
	_apply(self)

func _apply(node: Node) -> void:
	if node is MeshInstance3D:
		for i in node.mesh.get_surface_count():
			var mat: Material = node.get_active_material(i)
			if mat is StandardMaterial3D:
				var m := mat.duplicate() as StandardMaterial3D
				m.albedo_color = Color(
					m.albedo_color.r * brightness,
					m.albedo_color.g * brightness,
					m.albedo_color.b * brightness,
					m.albedo_color.a
				)
				node.set_surface_override_material(i, m)
	for child in node.get_children():
		_apply(child)
