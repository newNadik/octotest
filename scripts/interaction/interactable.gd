extends Area3D
class_name Interactable

const DROP_SURFACE_COLLISION_MASK := (1 << 0) | (1 << 1)
const OUTLINE_SHADER := preload("res://assets/shaders/interaction_outline.gdshader")

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
@export var show_indicator := true
@export var hover_color := Color(1.0, 1.0, 1.0, 0.0)
@export var in_range_color := Color(1.0, 1.0, 1.0, 0.9)
@export var blocked_color := Color(1.0, 1.0, 1.0, 0.0)
@export var click_color := Color(1.0, 1.0, 1.0, 0.96)
@export var click_feedback_duration := 0.14
@export_group("")

var _visual_root: Node3D
var _pickup_root: Node3D
var _source_mesh_nodes: Array[MeshInstance3D] = []
var _current_state: VisualState = VisualState.IDLE
var _outline_next_pass_materials: Dictionary = {}
var _original_surface_overrides: Dictionary = {}
var _outlined_surface_overrides_cache: Dictionary = {}
var _saved_area_layer := 0
var _saved_area_mask := 0
var _saved_pickup_layer := 0
var _saved_pickup_mask := 0
var _has_saved_pickup_collision := false
var _interaction_enabled := true
var _is_currently_held := false
var _initial_save_key := ""
var _indicator_root: Node3D
var _indicator_dot: Sprite3D
var _indicator_override_enabled := false
var _indicator_override_world_position := Vector3.ZERO
var _click_feedback_time_left := 0.0


func _ready() -> void:
	add_to_group("save_state_provider")
	_pickup_root = _resolve_target_root(pickup_root_path)
	if _pickup_root == null:
		_pickup_root = get_parent() as Node3D

	_visual_root = _resolve_target_root(visual_root_path)
	if _visual_root == null:
		_visual_root = _pickup_root

	_collect_meshes(_visual_root)
	_cache_original_surface_overrides()
	_build_outline_next_pass_materials()
	_build_interaction_indicator()
	_saved_area_layer = collision_layer
	_saved_area_mask = collision_mask
	_initial_save_key = str(get_path())
	_apply_smart_defaults()
	_set_visual_state(VisualState.IDLE)
	set_process(true)


func _process(delta: float) -> void:
	if _click_feedback_time_left > 0.0:
		_click_feedback_time_left = maxf(0.0, _click_feedback_time_left - delta)
		if _click_feedback_time_left <= 0.0:
			_apply_visuals()
	_update_indicator_world_position()


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
	_refresh_indicator_visuals()


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
	_apply_visuals()
	_refresh_indicator_visuals()


func trigger_click_feedback() -> void:
	if click_feedback_duration <= 0.0:
		return
	_click_feedback_time_left = click_feedback_duration
	_apply_visuals()


func _apply_visuals() -> void:
	var outline_state := ""
	if _click_feedback_time_left > 0.0:
		outline_state = "click"
	else:
		match _current_state:
			VisualState.IN_RANGE:
				outline_state = "in_range"
			VisualState.HOVERED:
				outline_state = "in_range"
			VisualState.HELD:
				outline_state = ""
			_:
				outline_state = ""
	_apply_outline_state(outline_state)


func _collect_meshes(node: Node) -> void:
	if node == null:
		return

	if node is MeshInstance3D:
		_source_mesh_nodes.append(node as MeshInstance3D)

	for child: Node in node.get_children():
		_collect_meshes(child)


func _build_outline_next_pass_materials() -> void:
	_outline_next_pass_materials.clear()
	_outline_next_pass_materials["in_range"] = _make_outline_next_pass_material(in_range_color, 4.0)
	_outline_next_pass_materials["click"] = _make_outline_next_pass_material(click_color, 6.0)


func _make_outline_next_pass_material(color: Color, width: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	material.set_shader_parameter("outline_color", color)
	material.set_shader_parameter("outline_width", width)
	return material


func _cache_original_surface_overrides() -> void:
	_original_surface_overrides.clear()
	for source_mesh in _source_mesh_nodes:
		if source_mesh == null or source_mesh.mesh == null:
			continue
		var mesh_id := source_mesh.get_instance_id()
		var surface_count := source_mesh.mesh.get_surface_count()
		var originals: Array = []
		originals.resize(surface_count)
		for i in range(surface_count):
			originals[i] = source_mesh.get_surface_override_material(i)
		_original_surface_overrides[mesh_id] = originals


func _apply_outline_state(state_name: String) -> void:
	for source_mesh in _source_mesh_nodes:
		if source_mesh == null or source_mesh.mesh == null:
			continue
		var mesh_id := source_mesh.get_instance_id()
		var surface_count := source_mesh.mesh.get_surface_count()
		if state_name.is_empty():
			var originals: Array = _original_surface_overrides.get(mesh_id, [])
			for i in range(surface_count):
				var original_override = null
				if i < originals.size():
					original_override = originals[i]
				source_mesh.set_surface_override_material(i, original_override)
			continue
		var outlined: Array = _get_or_build_surface_overrides_for_state(source_mesh, state_name)
		for i in range(surface_count):
			var mat: Material = null
			if i < outlined.size():
				mat = outlined[i]
			source_mesh.set_surface_override_material(i, mat)


func _get_or_build_surface_overrides_for_state(source_mesh: MeshInstance3D, state_name: String) -> Array:
	var mesh_id := source_mesh.get_instance_id()
	if not _outlined_surface_overrides_cache.has(mesh_id):
		_outlined_surface_overrides_cache[mesh_id] = {}
	var mesh_cache: Dictionary = _outlined_surface_overrides_cache[mesh_id]
	if mesh_cache.has(state_name):
		return mesh_cache[state_name]

	var surface_count := source_mesh.mesh.get_surface_count()
	var originals: Array = _original_surface_overrides.get(mesh_id, [])
	var result: Array = []
	result.resize(surface_count)
	var next_pass_material: Material = _outline_next_pass_materials.get(state_name)
	for i in range(surface_count):
		var base: Material = null
		if i < originals.size():
			base = originals[i]
		if base == null:
			base = source_mesh.get_active_material(i)
		if base == null:
			result[i] = null
			continue
		var duplicated: Material = base.duplicate(true)
		duplicated.set("next_pass", next_pass_material)
		result[i] = duplicated
	mesh_cache[state_name] = result
	_outlined_surface_overrides_cache[mesh_id] = mesh_cache
	return result


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


func _build_interaction_indicator() -> void:
	if _pickup_root == null:
		return

	_indicator_root = Node3D.new()
	_indicator_root.name = "InteractionIndicator"
	_indicator_root.top_level = true
	_indicator_root.position = focus_offset + Vector3(0.0, 0.08, 0.0)
	add_child(_indicator_root)

	_indicator_dot = Sprite3D.new()
	_indicator_dot.name = "Dot"
	_indicator_dot.texture = _make_dot_texture(64, 0.28, 0.11)
	_indicator_dot.modulate = Color(1.0, 1.0, 1.0, 0.86)
	_indicator_dot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_indicator_dot.shaded = false
	# Show above the interactable's own geometry. Occlusion by other objects is handled via LOS raycast.
	_indicator_dot.no_depth_test = true
	_indicator_dot.pixel_size = 0.0028
	_indicator_root.add_child(_indicator_dot)

	_refresh_indicator_visuals()


func _refresh_indicator_visuals() -> void:
	if _indicator_root == null:
		return

	_indicator_root.position = focus_offset + Vector3(0.0, 0.08, 0.0)
	var should_show_base = show_indicator and _interaction_enabled and not _is_currently_held
	_update_indicator_world_position()
	if not should_show_base:
		_indicator_root.visible = false
		return

	var dot_alpha = 0.88
	match _current_state:
		VisualState.HOVERED:
			dot_alpha = 1.0
		VisualState.IN_RANGE:
			dot_alpha = 1.0
		VisualState.BLOCKED:
			dot_alpha = 0.78
		VisualState.HELD:
			dot_alpha = 0.0
		_:
			dot_alpha = 0.88

	if _indicator_dot != null:
		_indicator_dot.modulate = Color(1.0, 1.0, 1.0, dot_alpha)


func _update_indicator_world_position() -> void:
	if _indicator_root == null:
		return
	var target_world_position = get_focus_position() + Vector3(0.0, 0.08, 0.0)
	if _indicator_override_enabled:
		target_world_position = _indicator_override_world_position
	_indicator_root.global_position = target_world_position
	var should_show = show_indicator and _interaction_enabled and not _is_currently_held
	if should_show and _is_indicator_occluded_by_world(target_world_position):
		should_show = false
	_indicator_root.visible = should_show


func _is_indicator_occluded_by_world(target_world_position: Vector3) -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var camera := viewport.get_camera_3d()
	if camera == null:
		return false
	var world := get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target_world_position)
	query.collide_with_areas = false
	query.exclude = [self]
	var hit = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider = hit.get("collider")
	if collider == null:
		return true
	if collider == self:
		return false
	if collider is Node:
		var collider_node := collider as Node
		if _is_same_interactable_object(collider_node):
			return false
	return true


func _is_same_interactable_object(collider_node: Node) -> bool:
	if collider_node == self or is_ancestor_of(collider_node) or collider_node.is_ancestor_of(self):
		return true
	if _pickup_root != null and (collider_node == _pickup_root or _pickup_root.is_ancestor_of(collider_node) or collider_node.is_ancestor_of(_pickup_root)):
		return true
	var parent_node := get_parent()
	if parent_node != null and (parent_node == collider_node or parent_node.is_ancestor_of(collider_node) or collider_node.is_ancestor_of(parent_node)):
		return true
	return false


func _make_dot_texture(size: int, radius: float, softness: float) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var uv = Vector2((float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size))
			var p = uv * 2.0 - Vector2.ONE
			var d = p.length()
			var alpha = 1.0 - smoothstep(radius, radius + maxf(0.001, softness), d)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func set_indicator_visible(is_visible: bool) -> void:
	show_indicator = is_visible
	_refresh_indicator_visuals()


func set_indicator_world_position_override(world_position: Vector3, enabled: bool = true) -> void:
	_indicator_override_enabled = enabled
	_indicator_override_world_position = world_position
	_refresh_indicator_visuals()


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
		set_interaction_enabled(true)
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
