extends RefCounted
class_name InteractionGeometry


static func estimate_drop_base_offset(root: Node3D) -> float:
	if root == null:
		return 0.0
	var collision_offset := estimate_drop_base_offset_from_collision(root)
	if collision_offset >= 0.0:
		return collision_offset
	var min_y := INF
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null and mesh_instance.is_visible_in_tree():
				var aabb := mesh_instance.mesh.get_aabb()
				for corner in _aabb_corners(aabb):
					var world_corner: Vector3 = mesh_instance.global_transform * corner
					min_y = minf(min_y, world_corner.y)
					found = true
		for child in node.get_children():
			stack.append(child)
	if not found:
		return 0.0
	return maxf(0.0, root.global_position.y - min_y)


static func estimate_drop_horizontal_width(root: Node3D) -> float:
	if root == null:
		return 0.4
	var collision_width := estimate_drop_horizontal_width_from_collision(root)
	if collision_width > 0.0:
		return collision_width
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null and mesh_instance.is_visible_in_tree():
				var aabb := mesh_instance.mesh.get_aabb()
				for corner in _aabb_corners(aabb):
					var world_corner: Vector3 = mesh_instance.global_transform * corner
					min_x = minf(min_x, world_corner.x)
					max_x = maxf(max_x, world_corner.x)
					min_z = minf(min_z, world_corner.z)
					max_z = maxf(max_z, world_corner.z)
					found = true
		for child in node.get_children():
			stack.append(child)
	if not found:
		return 0.4
	return maxf(0.2, maxf(max_x - min_x, max_z - min_z))


static func estimate_drop_base_offset_from_collision(root: Node3D) -> float:
	var min_y := INF
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionShape3D:
			var cs := node as CollisionShape3D
			var half := shape_half_extents(cs.shape)
			if half != Vector3.ZERO:
				var world_extents := basis_abs_mul(cs.global_basis, half)
				min_y = minf(min_y, cs.global_position.y - world_extents.y)
				found = true
		for child in node.get_children():
			if not (child is Area3D):
				stack.append(child)
	if not found:
		return -1.0
	return maxf(0.0, root.global_position.y - min_y)


static func estimate_drop_horizontal_width_from_collision(root: Node3D) -> float:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var found := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionShape3D:
			var cs := node as CollisionShape3D
			var half := shape_half_extents(cs.shape)
			if half != Vector3.ZERO:
				var world_extents := basis_abs_mul(cs.global_basis, half)
				min_x = minf(min_x, cs.global_position.x - world_extents.x)
				max_x = maxf(max_x, cs.global_position.x + world_extents.x)
				min_z = minf(min_z, cs.global_position.z - world_extents.z)
				max_z = maxf(max_z, cs.global_position.z + world_extents.z)
				found = true
		for child in node.get_children():
			if not (child is Area3D):
				stack.append(child)
	if not found:
		return -1.0
	return maxf(0.2, maxf(max_x - min_x, max_z - min_z))


static func shape_half_extents(shape: Shape3D) -> Vector3:
	if shape == null:
		return Vector3.ZERO
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size * 0.5
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return Vector3(r, r, r)
	if shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		return Vector3(c.radius, c.height * 0.5 + c.radius, c.radius)
	if shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		return Vector3(c.radius, c.height * 0.5, c.radius)
	return Vector3.ZERO


static func basis_abs_mul(basis: Basis, v: Vector3) -> Vector3:
	return Vector3(
		absf(basis.x.x) * v.x + absf(basis.y.x) * v.y + absf(basis.z.x) * v.z,
		absf(basis.x.y) * v.x + absf(basis.y.y) * v.y + absf(basis.z.y) * v.z,
		absf(basis.x.z) * v.x + absf(basis.y.z) * v.y + absf(basis.z.z) * v.z
	)


static func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	return [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.end.x,      aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.end.y,      aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.end.x,      aabb.end.y,      aabb.position.z),
		Vector3(aabb.end.x,      aabb.position.y, aabb.end.z),
		Vector3(aabb.position.x, aabb.end.y,      aabb.end.z),
		Vector3(aabb.end.x,      aabb.end.y,      aabb.end.z),
	]
