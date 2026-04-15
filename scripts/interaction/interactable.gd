extends Area3D
class_name Interactable

const DROP_SURFACE_COLLISION_MASK := (1 << 0) | (1 << 1)

signal interacted(interactable: Interactable, actor: Node)
signal clicked(interactable: Interactable, actor: Node)
signal picked_up(interactable: Interactable, actor: Node)
signal dropped(interactable: Interactable, actor: Node)

enum InteractionType {
	CLICK,
	PICKUP,
}

enum ItemKind {
	NONE,
	CARD,
}

enum VisualState {
	IDLE,
	HOVERED,
	IN_RANGE,
	BLOCKED,
	HELD,
}

@export_group("Interaction")
@export var interaction_type: InteractionType = InteractionType.CLICK
@export var display_name := ""
@export var prompt_action := ""
@export var interaction_range := 2.6
@export var requires_line_of_sight := true
@export var focus_offset := Vector3.ZERO

@export_group("Pickup")
@export var item_kind: ItemKind = ItemKind.NONE
@export var item_id := ""
@export var hold_offset := Vector3(0.0, -0.1, 0.35)
@export var hold_rotation_degrees := Vector3.ZERO

@export_group("Advanced")
@export var visual_root_path: NodePath
@export var pickup_root_path: NodePath
@export var save_key_override := ""
@export var hover_color := Color(1.0, 0.83, 0.25, 0.55)
@export var in_range_color := Color(0.33, 0.95, 0.48, 0.48)
@export var blocked_color := Color(0.96, 0.3, 0.3, 0.6)
@export_group("")

var _visual_root: Node3D
var _pickup_root: Node3D
var _mesh_nodes: Array[MeshInstance3D] = []
var _state_materials: Dictionary = {}
var _current_state: VisualState = VisualState.IDLE
var _saved_area_layer := 0
var _saved_area_mask := 0
var _saved_pickup_layer := 0
var _saved_pickup_mask := 0
var _has_saved_pickup_collision := false
var _interaction_enabled := true
var _is_currently_held := false
var _initial_save_key := ""


func _ready() -> void:
	add_to_group("save_state_provider")
	_pickup_root = _resolve_target_root(pickup_root_path)
	if _pickup_root == null:
		_pickup_root = get_parent() as Node3D

	_visual_root = _resolve_target_root(visual_root_path)
	if _visual_root == null:
		_visual_root = _pickup_root

	_collect_meshes(_visual_root)
	_build_materials()
	_saved_area_layer = collision_layer
	_saved_area_mask = collision_mask
	_initial_save_key = str(get_path())
	_apply_smart_defaults()
	_set_visual_state(VisualState.IDLE)


func get_focus_position() -> Vector3:
	return _pickup_root.global_position + _pickup_root.global_basis * focus_offset


func can_interact_from(player_position: Vector3) -> bool:
	return player_position.distance_to(get_focus_position()) <= interaction_range


func get_hold_transform() -> Transform3D:
	var basis := Basis.from_euler(Vector3(
		deg_to_rad(hold_rotation_degrees.x),
		deg_to_rad(hold_rotation_degrees.y),
		deg_to_rad(hold_rotation_degrees.z)
	))
	return Transform3D(basis, hold_offset)


func get_pickup_root() -> Node3D:
	return _pickup_root


func is_card() -> bool:
	return item_kind == ItemKind.CARD


func set_interaction_enabled(is_enabled: bool) -> void:
	_interaction_enabled = is_enabled
	if _interaction_enabled:
		collision_layer = _saved_area_layer
		collision_mask = _saved_area_mask
	else:
		collision_layer = 0
		collision_mask = 0


func interact(actor: Node) -> void:
	emit_signal("interacted", self, actor)
	if interaction_type == InteractionType.CLICK:
		emit_signal("clicked", self, actor)
	elif interaction_type == InteractionType.PICKUP:
		emit_signal("picked_up", self, actor)


func drop(actor: Node) -> void:
	if interaction_type == InteractionType.PICKUP:
		emit_signal("dropped", self, actor)


func set_held(is_held: bool) -> void:
	_is_currently_held = is_held
	if is_held:
		_set_visual_state(VisualState.HELD)
	else:
		set_interaction_enabled(_interaction_enabled)
		_set_visual_state(VisualState.IDLE)

	if _pickup_root == null:
		return

	if _pickup_root is CollisionObject3D:
		var collision := _pickup_root as CollisionObject3D
		if not _has_saved_pickup_collision:
			_saved_pickup_layer = collision.collision_layer
			_saved_pickup_mask = collision.collision_mask
			_has_saved_pickup_collision = true

		if is_held:
			collision.collision_layer = 0
			collision.collision_mask = 0
		else:
			collision.collision_layer = _saved_pickup_layer
			collision.collision_mask = _saved_pickup_mask

	if _pickup_root is RigidBody3D:
		var body := _pickup_root as RigidBody3D
		body.freeze = is_held
		if is_held:
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO


func set_visual_state(state: VisualState) -> void:
	_set_visual_state(state)


func get_visual_state() -> VisualState:
	return _current_state


func _set_visual_state(state: VisualState) -> void:
	if _current_state == state:
		return

	_current_state = state
	var overlay_material: Material = null
	match state:
		VisualState.HOVERED:
			overlay_material = _state_materials.get("hover")
		VisualState.IN_RANGE:
			overlay_material = _state_materials.get("in_range")
		VisualState.BLOCKED:
			overlay_material = _state_materials.get("blocked")
		_:
			overlay_material = null

	for mesh in _mesh_nodes:
		mesh.material_overlay = overlay_material


func _collect_meshes(node: Node) -> void:
	if node == null:
		return

	if node is MeshInstance3D:
		_mesh_nodes.append(node as MeshInstance3D)

	for child: Node in node.get_children():
		_collect_meshes(child)


func _build_materials() -> void:
	_state_materials["hover"] = _make_overlay_material(hover_color)
	_state_materials["in_range"] = _make_overlay_material(in_range_color)
	_state_materials["blocked"] = _make_overlay_material(blocked_color)


func _make_overlay_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = false
	return material


func _resolve_target_root(path: NodePath) -> Node3D:
	if path == NodePath(""):
		return null
	return get_node_or_null(path) as Node3D


func _apply_smart_defaults() -> void:
	if display_name.strip_edges().is_empty():
		var source_name = ""
		if _pickup_root != null:
			source_name = _pickup_root.name
		elif get_parent() != null:
			source_name = get_parent().name
		display_name = source_name.replace("_", " ")

	if prompt_action.strip_edges().is_empty():
		if interaction_type == InteractionType.PICKUP:
			prompt_action = "Pick up"
		else:
			prompt_action = "Interact"


func get_save_key() -> String:
	var key = save_key_override.strip_edges()
	if not key.is_empty():
		return key
	return _initial_save_key


func get_save_state() -> Dictionary:
	var result := {
		"interaction_enabled": _interaction_enabled,
		"is_held": _is_currently_held
	}
	if interaction_type == InteractionType.PICKUP and _pickup_root != null:
		result["pickup_transform"] = _serialize_transform(_pickup_root.global_transform)
	return result


func apply_save_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	if state.has("interaction_enabled"):
		set_interaction_enabled(bool(state["interaction_enabled"]))
	if interaction_type != InteractionType.PICKUP or _pickup_root == null:
		return
	var was_held := bool(state.get("is_held", false))
	if state.has("pickup_transform"):
		var restored = _deserialize_transform(state["pickup_transform"])
		if restored != null:
			_pickup_root.global_transform = restored as Transform3D
	if was_held:
		_restore_saved_held_item_as_dropped()
	if _pickup_root is RigidBody3D:
		var body := _pickup_root as RigidBody3D
		body.freeze = false
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	set_held(false)


func _serialize_transform(t: Transform3D) -> Array:
	return [
		t.basis.x.x, t.basis.x.y, t.basis.x.z,
		t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z,
		t.origin.x, t.origin.y, t.origin.z
	]


func _deserialize_transform(data: Variant):
	if not (data is Array):
		return null
	var values := data as Array
	if values.size() != 12:
		return null
	var basis := Basis(
		Vector3(float(values[0]), float(values[1]), float(values[2])),
		Vector3(float(values[3]), float(values[4]), float(values[5])),
		Vector3(float(values[6]), float(values[7]), float(values[8]))
	)
	var origin := Vector3(float(values[9]), float(values[10]), float(values[11]))
	return Transform3D(basis, origin)


func _restore_saved_held_item_as_dropped() -> void:
	var player = _find_player_for_restore()
	if player == null:
		return

	var forward = -player.global_basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var item_width = _estimate_drop_horizontal_width(_pickup_root)
	var desired_position = _find_restore_drop_position(player, forward, item_width)
	_pickup_root.global_position = desired_position


func _find_player_for_restore() -> CharacterBody3D:
	var tree := get_tree()
	if tree == null:
		return null
	var scene := tree.current_scene
	if scene == null:
		return null
	var direct = scene.get_node_or_null("Player")
	if direct is CharacterBody3D:
		return direct as CharacterBody3D
	var found = scene.find_child("Player", true, false)
	if found is CharacterBody3D:
		return found as CharacterBody3D
	return null


func _resolve_floor_position(desired_position: Vector3) -> Vector3:
	var world := _pickup_root.get_world_3d()
	if world == null:
		return desired_position

	var from = desired_position + Vector3.UP * 1.2
	var to = desired_position + Vector3.DOWN * 2.4
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = DROP_SURFACE_COLLISION_MASK
	query.collide_with_areas = false
	query.exclude = [_pickup_root]
	var result = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return desired_position

	var floor_position = result.position as Vector3
	var base_offset = _estimate_drop_base_offset(_pickup_root)
	return Vector3(desired_position.x, floor_position.y + base_offset, desired_position.z)


func _find_restore_drop_position(player: CharacterBody3D, forward: Vector3, item_width: float) -> Vector3:
	var drop_distance = maxf(0.45, item_width * 2.0)
	var spacing = maxf(0.35, item_width * 1.05)
	var right = forward.cross(Vector3.UP)
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()

	var occupied_positions = _collect_other_pickup_positions()
	var lateral_slots = [0, -1, 1, -2, 2, -3, 3]
	var row_multipliers = [1.0, 1.55, 2.1]
	for row_scale in row_multipliers:
		for lateral_slot in lateral_slots:
			var candidate = player.global_position + forward * (drop_distance * float(row_scale)) + right * (spacing * float(lateral_slot))
			var floor_candidate = _resolve_floor_position(candidate)
			if _is_restore_position_clear(floor_candidate, occupied_positions, spacing * 0.9):
				return floor_candidate

	return _resolve_floor_position(player.global_position + forward * drop_distance)


func _collect_other_pickup_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var tree := get_tree()
	if tree == null:
		return positions
	for node in tree.get_nodes_in_group("save_state_provider"):
		if not (node is Interactable):
			continue
		var other = node as Interactable
		if other == self or other.interaction_type != InteractionType.PICKUP:
			continue
		var root = other.get_pickup_root()
		if root == null:
			continue
		positions.append(root.global_position)
	return positions


func _is_restore_position_clear(candidate: Vector3, occupied_positions: Array[Vector3], min_spacing: float) -> bool:
	var min_spacing_sq = min_spacing * min_spacing
	for position in occupied_positions:
		var delta = candidate - position
		delta.y = 0.0
		if delta.length_squared() < min_spacing_sq:
			return false
	return true


func _estimate_drop_base_offset(root: Node3D) -> float:
	if root == null:
		return 0.0
	var min_y = INF
	var found = false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance = node as MeshInstance3D
			if mesh_instance.mesh != null:
				var aabb = mesh_instance.mesh.get_aabb()
				var corners = [
					Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
					Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
					Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
					Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
					Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
					Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
					Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
					Vector3(aabb.end.x, aabb.end.y, aabb.end.z),
				]
				for corner in corners:
					var world_corner = mesh_instance.global_transform * corner
					min_y = minf(min_y, world_corner.y)
					found = true
		for child in node.get_children():
			stack.append(child)
	if not found:
		return 0.0
	return maxf(0.0, root.global_position.y - min_y)


func _estimate_drop_horizontal_width(root: Node3D) -> float:
	if root == null:
		return 0.4
	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF
	var found = false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance = node as MeshInstance3D
			if mesh_instance.mesh != null:
				var aabb = mesh_instance.mesh.get_aabb()
				var corners = [
					Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
					Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
					Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
					Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
					Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
					Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
					Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
					Vector3(aabb.end.x, aabb.end.y, aabb.end.z),
				]
				for corner in corners:
					var world_corner = mesh_instance.global_transform * corner
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
