@tool
extends Node3D

const ORIGINAL_TRANSFORM_META := "_hoberman_original_transform"
const GROUP_CAP_INNER := &"hoberman_cap_inner"
const GROUP_CAP_OUTER := &"hoberman_cap_outer"
const GROUP_BRANCH_PIN := &"hoberman_branch_pin"
const GROUP_BRANCH_ALL := &"hoberman_branch_all"
const GROUP_BRANCH_YELLOW := &"hoberman_branch_yellow"
const GROUP_BRANCH_PINK := &"hoberman_branch_pink"
const GROUP_BRANCH_GB_INNER := &"hoberman_branch_gb_inner"
const GROUP_BRANCH_GB_UPPER := &"hoberman_branch_gb_upper"

@export_group("Preview")
@export var preview_enabled := true:
	set(value):
		preview_enabled = value
		_queue_apply()

@export var apply_in_game := true
@export var play_animation_on_interact := true
@export var hold_mouse_to_play := true

@export var restore_original_pose := false:
	set(value):
		restore_original_pose = false
		if value:
			_restore_original_pose()

@export_group("Group Visibility")
@export var show_inner_caps := true:
	set(value):
		show_inner_caps = value
		_queue_apply()

@export var show_outer_caps := true:
	set(value):
		show_outer_caps = value
		_queue_apply()

@export var show_yellow_branches := true:
	set(value):
		show_yellow_branches = value
		_queue_apply()

@export var show_pink_branches := true:
	set(value):
		show_pink_branches = value
		_queue_apply()

@export var show_gb_inner_branches := true:
	set(value):
		show_gb_inner_branches = value
		_queue_apply()

@export var show_gb_upper_branches := true:
	set(value):
		show_gb_upper_branches = value
		_queue_apply()

@export var show_branch_pins := true:
	set(value):
		show_branch_pins = value
		_queue_apply()

@export_range(0.0, 0.2, 0.001, "suffix:m") var inner_cap_radius := 0.13:
	set(value):
		inner_cap_radius = value
		_rebuild_part_cache()
		_queue_apply()

@export_range(0.0, 0.1, 0.001, "suffix:m") var min_branch_length := 0.02:
	set(value):
		min_branch_length = value
		_rebuild_part_cache()
		_queue_apply()

@export_group("Caps To Center")
@export_range(0.0, 1.0, 0.01) var inner_caps_to_center := 0.0:
	set(value):
		inner_caps_to_center = value
		_queue_apply()

@export_range(0.0, 1.0, 0.01) var outer_caps_to_center := 0.0:
	set(value):
		outer_caps_to_center = value
		_queue_apply()

@export_group("Branches Global")
@export_range(0.0, 1.0, 0.01) var branch_to_center := 0.0:
	set(value):
		branch_to_center = value
		_queue_apply()

@export_range(-180.0, 180.0, 1.0, "suffix:deg") var branch_rotation_degrees := 0.0:
	set(value):
		branch_rotation_degrees = value
		_queue_apply()

@export_group("Branch Group To Center")
@export_range(-1.0, 1.0, 0.01) var yellow_to_center_offset := 0.0:
	set(value):
		yellow_to_center_offset = value
		_queue_apply()

@export_range(-1.0, 1.0, 0.01) var pink_to_center_offset := 0.0:
	set(value):
		pink_to_center_offset = value
		_queue_apply()

@export_range(-1.0, 1.0, 0.01) var gb_inner_to_center_offset := 0.0:
	set(value):
		gb_inner_to_center_offset = value
		_queue_apply()

@export_range(-1.0, 1.0, 0.01) var gb_upper_to_center_offset := 0.0:
	set(value):
		gb_upper_to_center_offset = value
		_queue_apply()

@export_group("Branch Group Cap Position")
@export_range(-0.2, 0.2, 0.001, "suffix:m") var yellow_cap_offset := 0.0:
	set(value):
		yellow_cap_offset = value
		_queue_apply()

@export_range(-0.2, 0.2, 0.001, "suffix:m") var pink_cap_offset := 0.0:
	set(value):
		pink_cap_offset = value
		_queue_apply()

@export_range(-0.2, 0.2, 0.001, "suffix:m") var gb_inner_cap_offset := 0.0:
	set(value):
		gb_inner_cap_offset = value
		_queue_apply()

@export_range(-0.2, 0.2, 0.001, "suffix:m") var gb_upper_cap_offset := 0.0:
	set(value):
		gb_upper_cap_offset = value
		_queue_apply()

@export_group("Branch Group Rotation")
@export_range(-180.0, 180.0, 1.0, "suffix:deg") var yellow_rotation_offset := 0.0:
	set(value):
		yellow_rotation_offset = value
		_queue_apply()

@export_range(-180.0, 180.0, 1.0, "suffix:deg") var pink_rotation_offset := 0.0:
	set(value):
		pink_rotation_offset = value
		_queue_apply()

@export_range(-180.0, 180.0, 1.0, "suffix:deg") var gb_inner_rotation_offset := 0.0:
	set(value):
		gb_inner_rotation_offset = value
		_queue_apply()

@export_range(-180.0, 180.0, 1.0, "suffix:deg") var gb_upper_rotation_offset := 0.0:
	set(value):
		gb_upper_rotation_offset = value
		_queue_apply()

var _parts: Array[Dictionary] = []
var _cap_center_by_branch_group: Dictionary = {}
var _apply_queued := false
var _is_applying := false
var _animation_player: AnimationPlayer
var _interactable: Interactable
var _last_interaction_play_msec := 0
var _is_pointer_holding := false


func _ready() -> void:
	_rebuild_part_cache()
	_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	_interactable = get_node_or_null("Interactable") as Interactable
	if _interactable != null:
		if not _interactable.clicked.is_connected(_on_interactable_clicked):
			_interactable.clicked.connect(_on_interactable_clicked)
		if not _interactable.input_event.is_connected(_on_interactable_input_event):
			_interactable.input_event.connect(_on_interactable_input_event)
	_queue_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_apply_preview()


func _queue_apply() -> void:
	if not is_inside_tree():
		return

	if _apply_queued:
		return

	_apply_queued = true
	call_deferred("_apply_preview")


func _rebuild_part_cache() -> void:
	_parts.clear()

	if not is_inside_tree():
		return

	var model_root := get_node_or_null("Node3D")
	if model_root == null:
		return

	_collect_parts(model_root)


func _collect_parts(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var original_transform := _get_original_transform(mesh_instance)
		var part_kind := _get_part_kind(mesh_instance, original_transform)
		var branch_group := _get_branch_group(mesh_instance)
		var local_axis := _get_local_long_axis(mesh_instance)
		var pivot_local := _get_outer_pivot_local(mesh_instance, original_transform)

		_assign_groups(mesh_instance, part_kind, branch_group)

		_parts.append({
			"node": mesh_instance,
			"original_transform": original_transform,
			"kind": part_kind,
			"branch_group": branch_group,
			"local_axis": local_axis,
			"pivot_local": pivot_local,
		})

	for child in node.get_children():
		_collect_parts(child)


func _get_original_transform(node: Node3D) -> Transform3D:
	if node.has_meta(ORIGINAL_TRANSFORM_META):
		var meta_value = node.get_meta(ORIGINAL_TRANSFORM_META)
		if meta_value is Transform3D:
			return meta_value

	node.set_meta(ORIGINAL_TRANSFORM_META, node.transform)
	return node.transform


func _get_part_kind(node: MeshInstance3D, original_transform: Transform3D) -> StringName:
	var node_name := node.name.to_lower()

	if node_name.begins_with("button"):
		if original_transform.origin.length() < inner_cap_radius:
			return GROUP_CAP_INNER
		return GROUP_CAP_OUTER

	if node_name.begins_with("branch"):
		if _is_long_branch(node):
			return GROUP_BRANCH_ALL
		return GROUP_BRANCH_PIN

	return &"hoberman_other"


func _assign_groups(node: Node, part_kind: StringName, branch_group: StringName) -> void:
	var hoberman_groups := [
		GROUP_CAP_INNER,
		GROUP_CAP_OUTER,
		GROUP_BRANCH_PIN,
		GROUP_BRANCH_ALL,
		GROUP_BRANCH_YELLOW,
		GROUP_BRANCH_PINK,
		GROUP_BRANCH_GB_INNER,
		GROUP_BRANCH_GB_UPPER,
	]

	for group_name in hoberman_groups:
		if node.is_in_group(group_name):
			node.remove_from_group(group_name)

	if part_kind != &"hoberman_other":
		node.add_to_group(part_kind, true)

	if part_kind == GROUP_BRANCH_ALL or part_kind == GROUP_BRANCH_PIN:
		node.add_to_group(branch_group, true)


func _is_long_branch(node: MeshInstance3D) -> bool:
	if node.mesh == null:
		return false

	var size := node.mesh.get_aabb().size
	return max(size.x, max(size.y, size.z)) >= min_branch_length


func _get_local_long_axis(node: MeshInstance3D) -> Vector3:
	if node.mesh == null:
		return Vector3.RIGHT

	var aabb := node.mesh.get_aabb()
	var size := aabb.size
	var axis := Vector3.RIGHT
	var min_value := aabb.position.x
	var max_value := aabb.position.x + size.x

	if size.y > size.x and size.y >= size.z:
		axis = Vector3.UP
		min_value = aabb.position.y
		max_value = aabb.position.y + size.y
	elif size.z > size.x and size.z > size.y:
		axis = Vector3.FORWARD
		min_value = aabb.position.z
		max_value = aabb.position.z + size.z

	if abs(min_value) > abs(max_value):
		return -axis

	return axis


func _get_outer_pivot_local(node: MeshInstance3D, original_transform: Transform3D) -> Vector3:
	if node.mesh == null:
		return Vector3.ZERO

	var aabb := node.mesh.get_aabb()
	var size := aabb.size
	var axis_index := 0

	if size.y > size.x and size.y >= size.z:
		axis_index = 1
	elif size.z > size.x and size.z > size.y:
		axis_index = 2

	var endpoint_a := aabb.get_center()
	var endpoint_b := aabb.get_center()

	match axis_index:
		0:
			endpoint_a.x = aabb.position.x
			endpoint_b.x = aabb.position.x + size.x
		1:
			endpoint_a.y = aabb.position.y
			endpoint_b.y = aabb.position.y + size.y
		2:
			endpoint_a.z = aabb.position.z
			endpoint_b.z = aabb.position.z + size.z

	var world_a := original_transform * endpoint_a
	var world_b := original_transform * endpoint_b

	if world_a.length_squared() >= world_b.length_squared():
		return endpoint_a

	return endpoint_b


func _get_branch_group(node: MeshInstance3D) -> StringName:
	if node.is_in_group(GROUP_BRANCH_YELLOW):
		return GROUP_BRANCH_YELLOW
	if node.is_in_group(GROUP_BRANCH_PINK):
		return GROUP_BRANCH_PINK
	if node.is_in_group(GROUP_BRANCH_GB_INNER):
		return GROUP_BRANCH_GB_INNER
	if node.is_in_group(GROUP_BRANCH_GB_UPPER):
		return GROUP_BRANCH_GB_UPPER

	var material_name := _get_material_name(node)

	match material_name:
		"yellow":
			return GROUP_BRANCH_YELLOW
		"pink":
			return GROUP_BRANCH_PINK
		"green":
			return GROUP_BRANCH_GB_INNER
		"blue":
			return GROUP_BRANCH_GB_UPPER

	return GROUP_BRANCH_PIN


func _get_material_name(node: MeshInstance3D) -> String:
	var material := node.get_active_material(0)
	if material == null and node.mesh != null and node.mesh.get_surface_count() > 0:
		material = node.mesh.surface_get_material(0)

	if material == null:
		return ""

	return material.resource_name.to_lower()


func _apply_preview() -> void:
	_apply_queued = false

	if _is_applying:
		return

	if not is_inside_tree():
		return

	if not Engine.is_editor_hint() and not apply_in_game:
		return

	if _parts.is_empty():
		_rebuild_part_cache()

	_is_applying = true
	_update_cap_centers()

	for part in _parts:
		var node := part["node"] as MeshInstance3D
		var original_transform := part["original_transform"] as Transform3D

		if node == null:
			continue

		var kind := part["kind"] as StringName
		var branch_group := _get_current_branch_group(node, part["branch_group"] as StringName)
		node.visible = _is_part_visible(kind, branch_group)

		if not preview_enabled:
			node.transform = original_transform
			continue

		match kind:
			GROUP_CAP_INNER:
				node.transform = _move_transform_to_center(original_transform, inner_caps_to_center)
			GROUP_CAP_OUTER:
				node.transform = _move_transform_to_center(original_transform, outer_caps_to_center)
			GROUP_BRANCH_ALL:
				var local_axis := part["local_axis"] as Vector3
				var pivot_local := part["pivot_local"] as Vector3
				node.transform = _apply_branch_transform(
					original_transform,
					local_axis,
					pivot_local,
					branch_group
				)
			GROUP_BRANCH_PIN:
				var pin_group := part["branch_group"] as StringName
				node.transform = _move_transform_to_center(original_transform, _get_branch_to_center(pin_group))
			_:
				node.transform = original_transform

	_is_applying = false


func _is_part_visible(part_kind: StringName, branch_group: StringName) -> bool:
	match part_kind:
		GROUP_CAP_INNER:
			return show_inner_caps
		GROUP_CAP_OUTER:
			return show_outer_caps
		GROUP_BRANCH_PIN:
			return show_branch_pins
		GROUP_BRANCH_ALL:
			match branch_group:
				GROUP_BRANCH_YELLOW:
					return show_yellow_branches
				GROUP_BRANCH_PINK:
					return show_pink_branches
				GROUP_BRANCH_GB_INNER:
					return show_gb_inner_branches
				GROUP_BRANCH_GB_UPPER:
					return show_gb_upper_branches

	return true


func _get_current_branch_group(node: Node, fallback_group: StringName) -> StringName:
	if node.is_in_group(GROUP_BRANCH_YELLOW):
		return GROUP_BRANCH_YELLOW
	if node.is_in_group(GROUP_BRANCH_PINK):
		return GROUP_BRANCH_PINK
	if node.is_in_group(GROUP_BRANCH_GB_INNER):
		return GROUP_BRANCH_GB_INNER
	if node.is_in_group(GROUP_BRANCH_GB_UPPER):
		return GROUP_BRANCH_GB_UPPER

	return fallback_group


func _restore_original_pose() -> void:
	if _parts.is_empty():
		_rebuild_part_cache()

	for part in _parts:
		var node := part["node"] as MeshInstance3D
		if node != null:
			node.visible = true
			node.transform = part["original_transform"] as Transform3D


func _move_transform_to_center(original_transform: Transform3D, amount: float) -> Transform3D:
	var adjusted := original_transform
	adjusted.origin = original_transform.origin.lerp(Vector3.ZERO, clampf(amount, 0.0, 1.0))
	return adjusted


func _apply_branch_transform(
	original_transform: Transform3D,
	local_axis: Vector3,
	pivot_local: Vector3,
	branch_group: StringName
) -> Transform3D:
	var to_center := _get_branch_to_center(branch_group)
	var adjusted := original_transform
	var current_direction := (original_transform.basis * local_axis).normalized()
	var radial_direction := original_transform.origin.normalized()

	if current_direction.is_zero_approx() or radial_direction.is_zero_approx():
		return adjusted

	if current_direction.dot(radial_direction) < current_direction.dot(-radial_direction):
		radial_direction = -radial_direction

	var rotation_axis := current_direction.cross(radial_direction)
	if rotation_axis.is_zero_approx():
		return adjusted

	var rotation_degrees := branch_rotation_degrees + _get_branch_rotation_offset(branch_group)
	var rotation_basis := Basis(rotation_axis.normalized(), deg_to_rad(rotation_degrees))
	var original_pivot := original_transform * pivot_local
	var moved_origin := original_transform.origin.lerp(Vector3.ZERO, clampf(to_center, 0.0, 1.0))
	var moved_pivot := original_pivot.lerp(Vector3.ZERO, clampf(to_center, 0.0, 1.0))
	var cap_offset := _get_branch_cap_offset(branch_group)
	var cap_offset_vector := _get_cap_anchor_direction(branch_group, moved_pivot) * cap_offset

	adjusted.basis = rotation_basis * original_transform.basis
	adjusted.origin = moved_pivot + rotation_basis * (moved_origin - moved_pivot) + cap_offset_vector
	return adjusted


func _get_branch_to_center(branch_group: StringName) -> float:
	var offset := 0.0

	match branch_group:
		GROUP_BRANCH_YELLOW:
			offset = yellow_to_center_offset
		GROUP_BRANCH_PINK:
			offset = pink_to_center_offset
		GROUP_BRANCH_GB_INNER:
			offset = gb_inner_to_center_offset
		GROUP_BRANCH_GB_UPPER:
			offset = gb_upper_to_center_offset

	return clampf(branch_to_center + offset, 0.0, 1.0)


func _get_branch_rotation_offset(branch_group: StringName) -> float:
	match branch_group:
		GROUP_BRANCH_YELLOW:
			return yellow_rotation_offset
		GROUP_BRANCH_PINK:
			return pink_rotation_offset
		GROUP_BRANCH_GB_INNER:
			return gb_inner_rotation_offset
		GROUP_BRANCH_GB_UPPER:
			return gb_upper_rotation_offset

	return 0.0


func _get_branch_cap_offset(branch_group: StringName) -> float:
	match branch_group:
		GROUP_BRANCH_YELLOW:
			return yellow_cap_offset
		GROUP_BRANCH_PINK:
			return pink_cap_offset
		GROUP_BRANCH_GB_INNER:
			return gb_inner_cap_offset
		GROUP_BRANCH_GB_UPPER:
			return gb_upper_cap_offset

	return 0.0


func _update_cap_centers() -> void:
	_cap_center_by_branch_group.clear()

	var cap_positions: Array[Vector3] = []
	for part in _parts:
		var kind := part["kind"] as StringName
		if kind != GROUP_CAP_OUTER:
			continue

		var node := part["node"] as MeshInstance3D
		if node != null:
			cap_positions.append(node.transform.origin)

	for group_name in [
		GROUP_BRANCH_YELLOW,
		GROUP_BRANCH_PINK,
		GROUP_BRANCH_GB_INNER,
		GROUP_BRANCH_GB_UPPER,
	]:
		var sum := Vector3.ZERO
		var count := 0

		for part in _parts:
			var node := part["node"] as MeshInstance3D
			if node == null:
				continue
			if not node.is_in_group(group_name):
				continue

			var original_transform := part["original_transform"] as Transform3D
			var nearest_cap = _find_nearest_cap(original_transform.origin, cap_positions)
			if nearest_cap == null:
				continue

			sum += nearest_cap
			count += 1

		if count > 0:
			_cap_center_by_branch_group[group_name] = sum / float(count)


func _find_nearest_cap(point: Vector3, cap_positions: Array[Vector3]):
	if cap_positions.is_empty():
		return null

	var nearest := cap_positions[0]
	var nearest_distance := point.distance_squared_to(nearest)

	for index in range(1, cap_positions.size()):
		var cap_position := cap_positions[index]
		var distance := point.distance_squared_to(cap_position)
		if distance < nearest_distance:
			nearest = cap_position
			nearest_distance = distance

	return nearest


func _get_cap_anchor_direction(branch_group: StringName, pivot_position: Vector3) -> Vector3:
	if not _cap_center_by_branch_group.has(branch_group):
		return Vector3.ZERO

	var cap_center := _cap_center_by_branch_group[branch_group] as Vector3
	var direction := cap_center - pivot_position

	if direction.is_zero_approx():
		return Vector3.ZERO

	return direction.normalized()


func _on_interactable_clicked(_interactable_ref: Interactable, _actor: Node) -> void:
	if hold_mouse_to_play:
		return
	_play_interaction_animation()


func _on_interactable_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_pointer_play()
		else:
			_end_pointer_play()
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_pointer_play()
		else:
			_end_pointer_play()


func _input(event: InputEvent) -> void:
	if not _is_pointer_holding:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_end_pointer_play()
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if not touch_event.pressed:
			_end_pointer_play()


func _begin_pointer_play() -> void:
	_is_pointer_holding = true
	_play_interaction_animation()


func _end_pointer_play() -> void:
	_is_pointer_holding = false
	_pause_interaction_animation()


func _play_interaction_animation() -> void:
	if not play_animation_on_interact:
		return

	var now := Time.get_ticks_msec()
	if now - _last_interaction_play_msec < 80:
		return
	_last_interaction_play_msec = now

	if _animation_player == null:
		_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _animation_player == null:
		return

	if not hold_mouse_to_play:
		_animation_player.stop()
		_animation_player.speed_scale = 1.0
		_animation_player.play(&"expand_contract")
		return

	_animation_player.speed_scale = 1.0
	if _animation_player.current_animation != &"expand_contract" or not _animation_player.is_playing():
		_animation_player.play(&"expand_contract")


func _pause_interaction_animation() -> void:
	if _animation_player == null:
		_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _animation_player == null:
		return

	_animation_player.speed_scale = 0.0
